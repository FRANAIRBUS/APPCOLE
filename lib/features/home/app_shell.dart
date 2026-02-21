import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../chat/chat_screen.dart';
import '../events/events_screen.dart';
import '../matching/matching_screen.dart';
import '../posts/posts_screen.dart';
import '../posts/talento_screen.dart';
import '../posts/biblio_screen.dart';
import '../posts/veteranos_screen.dart';
import '../profile/profile_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/posts',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/posts', builder: (_, __) => const PostsScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/events', builder: (_, __) => const EventsScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/matching', builder: (_, __) => const MatchingScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/chat', builder: (_, __) => const ChatScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ]),
      ],
    ),
    GoRoute(path: '/talento', builder: (_, __) => const TalentoScreen()),
    GoRoute(path: '/biblio', builder: (_, __) => const BiblioScreen()),
    GoRoute(path: '/veteranos', builder: (_, __) => const VeteranosScreen()),
  ],
);

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ColeConecta')),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.swap_horiz), label: 'Busco/Ofrezco'),
          NavigationDestination(icon: Icon(Icons.event), label: 'Entre Padres'),
          NavigationDestination(icon: Icon(Icons.groups), label: 'Mi Clase'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Perfil'),
        ],
      ),
    );
  }
}
