import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/auth_service.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final authServiceProvider = Provider<AuthService>((ref) => AuthService(ref.read(firebaseAuthProvider)));
final authStateProvider = StreamProvider<User?>((ref) => ref.read(authServiceProvider).authStateChanges());

final userMembershipDocsProvider = StreamProvider.family<List<QueryDocumentSnapshot<Map<String, dynamic>>>, String>((ref, uid) {
  return ref
      .read(firestoreProvider)
      .collectionGroup('users')
      .where(FieldPath.documentId, isEqualTo: uid)
      .snapshots()
      .map((snap) {
        final docs = [...snap.docs];
        docs.sort((a, b) {
          final aTs = _timestampFrom(a.data()['lastActiveAt']) ?? _timestampFrom(a.data()['createdAt']);
          final bTs = _timestampFrom(b.data()['lastActiveAt']) ?? _timestampFrom(b.data()['createdAt']);
          final aMicros = aTs?.microsecondsSinceEpoch ?? 0;
          final bMicros = bTs?.microsecondsSinceEpoch ?? 0;
          return bMicros.compareTo(aMicros);
        });
        return docs;
      });
});

final sessionStateProvider = Provider<AsyncValue<SessionState>>((ref) {
  final authAsync = ref.watch(authStateProvider);

  return authAsync.when(
    loading: () => const AsyncLoading(),
    error: (error, stackTrace) => AsyncError(error, stackTrace),
    data: (user) {
      if (user == null) {
        return const AsyncData(SessionState.unauthenticated());
      }

      final membershipsAsync = ref.watch(userMembershipDocsProvider(user.uid));
      return membershipsAsync.when(
        loading: () => const AsyncLoading(),
        error: (error, stackTrace) => AsyncError(error, stackTrace),
        data: (docs) {
          if (docs.isEmpty) {
            return AsyncData(SessionState.needsInvite(user));
          }

          final schoolId = docs.first.reference.parent.parent?.id;
          if (schoolId == null || schoolId.isEmpty) {
            return AsyncData(SessionState.needsInvite(user));
          }

          return AsyncData(SessionState.ready(user: user, schoolId: schoolId));
        },
      );
    },
  );
});

final schoolIdProvider = Provider<AsyncValue<String?>>((ref) {
  final sessionAsync = ref.watch(sessionStateProvider);
  return sessionAsync.whenData((session) => session.schoolId);
});

Timestamp? _timestampFrom(dynamic value) {
  if (value is Timestamp) return value;
  return null;
}

enum SessionStatus { unauthenticated, needsInvite, ready }

class SessionState {
  const SessionState._({
    required this.status,
    this.user,
    this.schoolId,
  });

  const SessionState.unauthenticated()
      : this._(
          status: SessionStatus.unauthenticated,
        );

  SessionState.needsInvite(User user)
      : this._(
          status: SessionStatus.needsInvite,
          user: user,
        );

  SessionState.ready({required User user, required String schoolId})
      : this._(
          status: SessionStatus.ready,
          user: user,
          schoolId: schoolId,
        );

  final SessionStatus status;
  final User? user;
  final String? schoolId;
}
