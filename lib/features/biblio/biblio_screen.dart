import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_provider.dart';
import '../posts/module_feed.dart';

class BiblioScreen extends ConsumerWidget {
  const BiblioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolId = ref.watch(schoolIdProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('BiblioCircular'),
      ),
      body: schoolId == null
          ? const Center(child: CircularProgressIndicator())
          : ModuleFeed(
              schoolId: schoolId,
              module: 'biblio',
              emptyHint: 'Aún no hay publicaciones. Publica un intercambio.',
            ),
      floatingActionButton: schoolId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showPostComposerBottomSheet(
                context: context,
                schoolId: schoolId,
                module: 'biblio',
                defaultType: 'intercambio',
                allowedTypes: const ['intercambio', 'vendo', 'regalo', 'presto'],
                titleHint: 'Nueva publicación BiblioCircular',
              ),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo'),
            ),
    );
  }
}
