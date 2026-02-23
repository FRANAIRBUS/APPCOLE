import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/session_provider.dart';
import '../features/biblio/biblio_screen.dart';
import '../features/bienvenida/bienvenida_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/events/events_screen.dart';
import '../features/home/app_shell.dart';
import '../features/matching/matching_screen.dart';
import '../features/moderation/trust_screen.dart';
import '../features/onboarding_invite/invite_screen.dart';
import '../features/posts/posts_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/talento/talento_screen.dart';
import '../features/veteranos/veteranos_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final sessionAsync = ref.watch(sessionStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final path = state.matchedLocation;
      final onSplash = path == '/splash';
      final onLogin = path == '/login';
      final onInvite = path == '/invite';

      if (sessionAsync.isLoading) {
        return onSplash ? null : '/splash';
      }

      if (sessionAsync.hasError) {
        return onLogin ? null : '/login';
      }

      final session = sessionAsync.valueOrNull;
      if (session == null) {
        return onSplash ? null : '/splash';
      }

      switch (session.status) {
        case SessionStatus.unauthenticated:
          return onLogin ? null : '/login';
        case SessionStatus.needsInvite:
          return onInvite ? null : '/invite';
        case SessionStatus.ready:
          if (onLogin || onInvite || onSplash) return '/posts';
          return null;
      }
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const _SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/invite', builder: (_, __) => const InviteScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/posts', builder: (_, __) => const PostsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/events', builder: (_, __) => const EventsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/matching', builder: (_, __) => const MatchingScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/chat', builder: (_, __) => const ChatScreen())]),
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

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
