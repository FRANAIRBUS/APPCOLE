import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/session_provider.dart';
import 'module_feed.dart';

class PostsScreen extends ConsumerWidget {
  const PostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolId = ref.watch(schoolIdProvider).valueOrNull;
    if (schoolId == null) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
      children: [
        Text(
          'Busco / Ofrezco',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Ayuda y colaboración entre familias del mismo colegio. Sin teléfonos. Sin fotos de menores.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 14),
        _ModuleGrid(
          onOpen: (route, isTab) => isTab ? context.go(route) : context.push(route),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                'Últimas publicaciones',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            FilledButton.icon(
              onPressed: () => showPostComposerBottomSheet(
                context: context,
                schoolId: schoolId,
                module: 'busco_ofrezco',
                defaultType: 'busco',
                allowedTypes: const ['busco', 'ofrezco'],
                titleHint: 'Nuevo Busco/Ofrezco',
              ),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 520,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              child: ModuleFeed(
                schoolId: schoolId,
                module: 'busco_ofrezco',
                emptyHint: 'Aún no hay publicaciones. Crea la primera.',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ModuleGrid extends StatelessWidget {
  const _ModuleGrid({required this.onOpen});

  final void Function(String route, bool isTab) onOpen;

  @override
  Widget build(BuildContext context) {
    final items = <_ModuleItem>[
      _ModuleItem(
        title: 'Talento del Cole',
        subtitle: 'Directorio + anuncios',
        icon: Icons.work_outline,
        route: '/talento',
      ),
      _ModuleItem(
        title: 'Entre Padres',
        subtitle: 'Eventos',
        icon: Icons.event,
        route: '/events',
        isTab: true,
      ),
      _ModuleItem(
        title: 'Mi Clase',
        subtitle: 'Matching',
        icon: Icons.groups,
        route: '/matching',
        isTab: true,
      ),
      _ModuleItem(
        title: 'BiblioCircular',
        subtitle: 'Intercambio',
        icon: Icons.auto_stories_outlined,
        route: '/biblio',
      ),
      _ModuleItem(
        title: 'Veteranos',
        subtitle: 'Trucos y consejos',
        icon: Icons.tips_and_updates_outlined,
        route: '/veteranos',
      ),
      _ModuleItem(
        title: 'Primer Día',
        subtitle: 'Cero dudas',
        icon: Icons.lightbulb_outline,
        route: '/bienvenida',
      ),
      _ModuleItem(
        title: 'Red de Confianza',
        subtitle: 'Normas y reporte',
        icon: Icons.verified_user_outlined,
        route: '/confianza',
      ),
    ];

    final width = MediaQuery.of(context).size.width;
    final columns = width >= 900 ? 4 : (width >= 600 ? 3 : 2);

    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.2,
      children: items
          .map(
            (m) => InkWell(
              onTap: () => onOpen(m.route, m.isTab),
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(m.icon, size: 26),
                      const Spacer(),
                      Text(m.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(m.subtitle, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ModuleItem {
  _ModuleItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    this.isTab = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final bool isTab;
}
