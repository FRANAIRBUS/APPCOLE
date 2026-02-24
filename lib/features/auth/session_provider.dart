import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/auth_service.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final authServiceProvider = Provider<AuthService>((ref) => AuthService(ref.read(firebaseAuthProvider)));
final authStateProvider = StreamProvider<User?>((ref) => ref.read(authServiceProvider).authStateChanges());

Stream<String?> _resolveSchoolIdStream(FirebaseFirestore firestore, String uid) async* {
  await for (final userSnap in firestore.collection('users').doc(uid).snapshots()) {
    final schoolId = (userSnap.data()?['schoolId'] as String?)?.trim();
    if (schoolId == null || schoolId.isEmpty) {
      yield null;
      continue;
    }
    yield schoolId;
  }
}

final schoolIdProvider = StreamProvider<String?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(null);

  return _resolveSchoolIdStream(ref.read(firestoreProvider), user.uid);
});

final isRootClaimProvider = StreamProvider<bool>((ref) {
  final auth = ref.read(firebaseAuthProvider);
  return auth.idTokenChanges().asyncMap((user) async {
    if (user == null) return false;
    final token = await user.getIdTokenResult();
    return token.claims?['role'] == 'root';
  });
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
