import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/biblio/biblio_screen.dart';
import '../features/bienvenida/bienvenida_screen.dart';
import '../features/events/events_screen.dart';
import '../features/home/app_shell.dart';
import '../features/matching/matching_screen.dart';
import '../features/moderation/trust_screen.dart';
import '../features/onboarding_invite/invite_screen.dart';
import '../features/posts/posts_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/talento/talento_screen.dart';
import '../features/veteranos/veteranos_screen.dart';
import '../services/auth_service.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final authServiceProvider = Provider<AuthService>((ref) => AuthService(ref.read(firebaseAuthProvider)));
final authStateProvider = StreamProvider<User?>((ref) => ref.read(authServiceProvider).authStateChanges());

final schoolIdProvider = StreamProvider<String?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(null);
  return ref
      .read(firestoreProvider)
      .collectionGroup('users')
      .where(FieldPath.documentId, isEqualTo: user.uid)
      .limit(1)
      .snapshots()
      .map((snap) => snap.docs.isEmpty ? null : snap.docs.first.reference.parent.parent?.id);
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStateProvider).valueOrNull;
  final schoolId = ref.watch(schoolIdProvider).valueOrNull;

  return GoRouter(
    initialLocation: '/posts',
    redirect: (context, state) {
      final onLogin = state.matchedLocation == '/login';
      final onInvite = state.matchedLocation == '/invite';

      if (auth == null) return onLogin ? null : '/login';
      if (schoolId == null) return onInvite ? null : '/invite';
      if (onLogin || onInvite) return '/posts';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/invite', builder: (_, __) => const InviteScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/posts', builder: (_, __) => const PostsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/events', builder: (_, __) => const EventsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/matching', builder: (_, __) => const MatchingScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen())]),
        ],
      ),
      GoRoute(path: '/talento', builder: (_, __) => const TalentoScreen()),
      GoRoute(path: '/biblio', builder: (_, __) => const BiblioScreen()),
      GoRoute(path: '/veteranos', builder: (_, __) => const VeteranosScreen()),
      GoRoute(path: '/bienvenida', builder: (_, __) => const BienvenidaScreen()),
      GoRoute(path: '/confianza', builder: (_, __) => const TrustScreen()),
    ],
  );
});
