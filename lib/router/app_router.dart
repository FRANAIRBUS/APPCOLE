import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/session_provider.dart';
import '../features/biblio/biblio_screen.dart';
import '../features/bienvenida/bienvenida_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/chat/chat_thread_screen.dart';
import '../features/events/events_screen.dart';
import '../features/home/app_shell.dart';
import '../features/home/welcome_screen.dart';
import '../features/matching/matching_screen.dart';
import '../features/moderation/trust_screen.dart';
import '../features/onboarding_invite/invite_screen.dart';
import '../features/posts/posts_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/schools/root_schools_admin_screen.dart';
import '../features/talento/talento_screen.dart';
import '../features/veteranos/veteranos_screen.dart';

export '../features/auth/session_provider.dart'
    show
        authServiceProvider,
        authStateProvider,
        isRootClaimProvider,
        schoolIdProvider,
        sessionStateProvider,
        SessionPhase,
        SessionState;

final appRouterProvider = Provider<GoRouter>((ref) {
  final sessionAsync = ref.watch(sessionStateProvider);
  final isRootAsync = ref.watch(isRootClaimProvider);

  return GoRouter(
    // En web se abre normalmente en '/', y si no existe ruta se muestra pantalla en blanco.
    // Mantén '/' como landing pública y usa '/splash' solo para loading.
    initialLocation: '/',
    redirect: (context, state) {
      final location = state.matchedLocation;
      final onWelcome = location == '/' || location == '/welcome';
      final onLogin = location == '/login';
      final onInvite = location == '/invite';
      final onSplash = location == '/splash';
      final onRootArea = location.startsWith('/root');

      if (sessionAsync.isLoading) return onSplash ? null : '/splash';
      if (sessionAsync.hasError) return onSplash ? null : '/splash';

      final session = sessionAsync.value!;
      switch (session.phase) {
        case SessionPhase.unauthenticated:
          // App pública: landing informativa + acceso a login.
          if (onWelcome || onLogin) return null;
          return '/';
        case SessionPhase.needsInvite:
          return onInvite ? null : '/invite';
        case SessionPhase.ready:
          if (onRootArea) {
            if (isRootAsync.isLoading) return onSplash ? null : '/splash';
            final isRoot = isRootAsync.valueOrNull ?? false;
            if (!isRoot) return '/posts';
          }
          if (onWelcome || onLogin || onInvite || onSplash) return '/posts';
          return null;
      }
    },
    errorBuilder: (context, state) => _RouterErrorScreen(state.error),
    routes: [
      GoRoute(path: '/', builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: '/splash', builder: (_, __) => const _RouterSplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/invite', builder: (_, __) => const InviteScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/posts', builder: (_, __) => const PostsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/events', builder: (_, __) => const EventsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/matching', builder: (_, __) => const MatchingScreen())]),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chat',
                builder: (_, __) => const ChatScreen(),
                routes: [
                  GoRoute(
                    path: ':chatId',
                    builder: (_, state) => ChatThreadScreen(chatId: state.pathParameters['chatId']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen())]),
        ],
      ),
      GoRoute(path: '/talento', builder: (_, __) => const TalentoScreen()),
      GoRoute(path: '/biblio', builder: (_, __) => const BiblioScreen()),
      GoRoute(path: '/veteranos', builder: (_, __) => const VeteranosScreen()),
      GoRoute(path: '/bienvenida', builder: (_, __) => const BienvenidaScreen()),
      GoRoute(path: '/confianza', builder: (_, __) => const TrustScreen()),
      GoRoute(path: '/root/colegios', builder: (_, __) => const RootSchoolsAdminScreen()),
    ],
  );
});

class _RouterSplashScreen extends ConsumerWidget {
  const _RouterSplashScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionStateProvider);

    if (sessionAsync.hasError) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Error de sesión:\n${sessionAsync.error}',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _RouterErrorScreen extends StatelessWidget {
  const _RouterErrorScreen(this.error);

  final Exception? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Página no disponible',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                error?.toString() ?? 'Ruta no encontrada.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Ir al inicio'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
