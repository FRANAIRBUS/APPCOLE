import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/auth_service.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final authServiceProvider = Provider<AuthService>((ref) => AuthService(ref.read(firebaseAuthProvider)));
final authStateProvider = StreamProvider<User?>((ref) => ref.read(authServiceProvider).authStateChanges());

Future<String?> _resolveLegacySchoolId(FirebaseFirestore firestore, String uid) async {
  final schoolsSnap = await firestore.collection('schools').get();
  if (schoolsSnap.docs.isEmpty) return null;

  final checks = await Future.wait(
    schoolsSnap.docs.map((schoolDoc) async {
      final userDoc = await schoolDoc.reference.collection('users').doc(uid).get();
      if (!userDoc.exists) return (schoolId: null as String?, lastActiveMs: 0);

      final ts = userDoc.data()?['lastActiveAt'];
      final ms = ts is Timestamp ? ts.millisecondsSinceEpoch : 0;
      return (schoolId: schoolDoc.id, lastActiveMs: ms);
    }),
  );

  checks.sort((a, b) => b.lastActiveMs.compareTo(a.lastActiveMs));
  final match = checks.firstWhere(
    (entry) => entry.schoolId != null,
    orElse: () => (schoolId: null, lastActiveMs: 0),
  );
  return match.schoolId;
}

Future<bool> _ensureSchoolMembership({
  required FirebaseFirestore firestore,
  required User user,
  required String schoolId,
}) async {
  final membershipRef = firestore.collection('schools').doc(schoolId).collection('users').doc(user.uid);
  final membershipSnap = await membershipRef.get();
  if (membershipSnap.exists) return true;

  final fallbackName = (user.displayName ?? '').trim().isNotEmpty
      ? user.displayName!.trim()
      : ((user.email ?? '').trim().isNotEmpty ? user.email!.trim() : 'Familia');
  final photoUrl = (user.photoURL ?? '').trim();

  try {
    await membershipRef.set(
      {
        'displayName': fallbackName,
        'photoUrl': photoUrl.isEmpty ? null : photoUrl,
        'role': 'parent',
        'children': const [],
        'classIds': const [],
        'createdAt': FieldValue.serverTimestamp(),
        'lastActiveAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    return true;
  } catch (_) {
    return false;
  }
}

Stream<String?> _resolveSchoolIdStream(FirebaseFirestore firestore, User user) async* {
  final uid = user.uid;
  String? lastResolvedSchoolId;
  await for (final userSnap in firestore.collection('users').doc(uid).snapshots()) {
    final schoolId = (userSnap.data()?['schoolId'] as String?)?.trim();
    if (schoolId != null && schoolId.isNotEmpty) {
      final existingMembership = await firestore
          .collection('schools')
          .doc(schoolId)
          .collection('users')
          .doc(uid)
          .get();

      if (existingMembership.exists) {
        lastResolvedSchoolId = schoolId;
        yield schoolId;
        continue;
      }

      final legacySchoolId = await _resolveLegacySchoolId(firestore, uid);
      if (legacySchoolId != null && legacySchoolId.isNotEmpty) {
        lastResolvedSchoolId = legacySchoolId;
        yield legacySchoolId;
        continue;
      }

      final repairedMembership = await _ensureSchoolMembership(
        firestore: firestore,
        user: user,
        schoolId: schoolId,
      );
      if (repairedMembership) {
        lastResolvedSchoolId = schoolId;
        yield schoolId;
        continue;
      }

      yield lastResolvedSchoolId;
      continue;
    }

    final legacySchoolId = await _resolveLegacySchoolId(firestore, uid);
    if (legacySchoolId != null && legacySchoolId.isNotEmpty) {
      lastResolvedSchoolId = legacySchoolId;
      yield legacySchoolId;
      continue;
    }

    yield lastResolvedSchoolId;
  }
}

final schoolIdProvider = StreamProvider<String?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(null);

  return _resolveSchoolIdStream(ref.read(firestoreProvider), user);
});

final isRootClaimProvider = StreamProvider<bool>((ref) {
  final auth = ref.read(firebaseAuthProvider);
  return auth.idTokenChanges().asyncMap((user) async {
    if (user == null) return false;
    final token = await user.getIdTokenResult();
    return token.claims?['role'] == 'root';
  });
});

final globalUserProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(null);
  return ref
      .read(firestoreProvider)
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((snap) => snap.data());
});

final schoolCatalogProvider =
    StreamProvider.family<Map<String, dynamic>?, String>((ref, schoolId) {
  final trimmed = schoolId.trim();
  if (trimmed.isEmpty) return Stream.value(null);
  return ref
      .read(firestoreProvider)
      .collection('colegios')
      .doc(trimmed)
      .snapshots()
      .map((snap) => snap.data());
});

    final schoolCatalogByCodeProvider =
        StreamProvider.family<Map<String, dynamic>?, String>((ref, schoolId) {
      final trimmed = schoolId.trim();
      if (trimmed.isEmpty) return Stream.value(null);
      return ref
      .read(firestoreProvider)
      .collection('colegios')
      .where('codigoCentro', isEqualTo: trimmed)
      .limit(1)
      .snapshots()
      .map((snap) => snap.docs.isEmpty ? null : snap.docs.first.data());
    });

enum SessionPhase { unauthenticated, needsInvite, ready }

class SessionState {
  const SessionState._({
    required this.phase,
    this.user,
    this.schoolId,
  });

  const SessionState.unauthenticated() : this._(phase: SessionPhase.unauthenticated);

  const SessionState.needsInvite(User user)
      : this._(phase: SessionPhase.needsInvite, user: user);

  const SessionState.ready({required User user, required String schoolId})
      : this._(phase: SessionPhase.ready, user: user, schoolId: schoolId);

  final SessionPhase phase;
  final User? user;
  final String? schoolId;

  bool get isAuthenticated => user != null;
}

final sessionStateProvider = Provider<AsyncValue<SessionState>>((ref) {
  final authAsync = ref.watch(authStateProvider);

  return authAsync.when(
    loading: () => const AsyncLoading(),
    error: (error, stack) => AsyncError(error, stack),
    data: (user) {
      if (user == null) return const AsyncData(SessionState.unauthenticated());

      final schoolAsync = ref.watch(schoolIdProvider);
      return schoolAsync.when(
        loading: () => const AsyncLoading(),
        error: (error, stack) => AsyncError(error, stack),
        data: (schoolId) {
          if (schoolId == null) {
            return AsyncData(SessionState.needsInvite(user));
          }
          return AsyncData(SessionState.ready(user: user, schoolId: schoolId));
        },
      );
    },
  );
});
