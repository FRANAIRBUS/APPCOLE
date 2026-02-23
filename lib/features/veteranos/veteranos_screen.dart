import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_provider.dart';
import '../posts/module_feed.dart';

class VeteranosScreen extends ConsumerWidget {
  const VeteranosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolId = ref.watch(schoolIdProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trucos de los Veteranos'),
      ),
      body: schoolId == null
          ? const Center(child: CircularProgressIndicator())
          : ModuleFeed(
              schoolId: schoolId,
              module: 'veteranos',
              emptyHint: 'Aún no hay consejos. Publica el primero.',
            ),
      floatingActionButton: schoolId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showPostComposerBottomSheet(
                context: context,
                schoolId: schoolId,
                module: 'veteranos',
                defaultType: 'truco',
                allowedTypes: const ['truco', 'aviso', 'recomendación'],
                titleHint: 'Nuevo consejo',
              ),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo'),
            ),
    );
  }
}
