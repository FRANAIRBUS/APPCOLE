import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _titles = [
    'Busco / Ofrezco',
    'Entre Padres',
    'Mi Clase',
    'Chat',
    'Perfil',
  ];

  static const _subtitles = [
    'Ayuda y recursos entre familias.',
    'Eventos y coordinación.',
    'Familias con clases en común.',
    'Mensajería interna privada.',
    'Cuenta, privacidad y seguridad.',
  ];

  @override
  Widget build(BuildContext context) {
    final current = navigationShell.currentIndex.clamp(0, _titles.length - 1);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Text(
          _titles[current],
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                _subtitles[current],
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ),
        ),
      ),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(index),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.swap_horiz), label: 'Busco/Ofrezco'),
          NavigationDestination(icon: Icon(Icons.event), label: 'Entre Padres'),
          NavigationDestination(icon: Icon(Icons.groups), label: 'Mi Clase'),
          NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), label: 'Perfil'),
        ],
      ),
    );
  }
}
