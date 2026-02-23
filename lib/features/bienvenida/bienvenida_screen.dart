import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_provider.dart';

class BienvenidaScreen extends ConsumerWidget {
  const BienvenidaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolId = ref.watch(schoolIdProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Primer Día, Cero Dudas'),
      ),
      body: schoolId == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.doc('schools/$schoolId/pages/bienvenida').snapshots(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data();
                final title = (data?['title'] as String?)?.trim();
                final sections = (data?['sections'] as List?)?.cast<Map>() ?? const [];

                final effectiveSections = sections.isNotEmpty
                    ? sections
                        .map((s) => {
                              'title': (s['title'] as String?)?.trim() ?? '',
                              'body': (s['body'] as String?)?.trim() ?? '',
                            })
                        .toList()
                    : _fallbackSections;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
                  children: [
                    Text(
                      title?.isNotEmpty == true ? title! : 'Guía rápida para empezar',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Contenido curado por el colegio. Si algo no está claro, publícalo en “Veteranos” o pregunta por chat.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 14),
                    ...effectiveSections.map(
                      (s) => Card(
                        child: ExpansionTile(
                          title: Text(
                            (s['title'] as String).isEmpty ? 'Información' : s['title'] as String,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                s['body'] as String,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Card(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Padding(
                        padding: EdgeInsets.all(14),
                        child: Text(
                          'Privacidad: no publiques teléfonos. No subas fotos de menores. Usa el chat interno 1:1 para coordinar.',
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

final List<Map<String, String>> _fallbackSections = [
  {
    'title': 'Qué llevo el primer día',
    'body': 'Lo básico: agua, muda de emergencia si aplica, autorización firmada si el cole la pide y etiqueta todo (ropa, botellas, material).',
  },
  {
    'title': 'Llegadas y recogidas',
    'body': 'Confirma puerta y horarios. Si hay autorización de recogida, revisa el procedimiento del cole (DNI, listado, etc.).',
  },
  {
    'title': 'Comunicación con tutores',
    'body': 'Usa los canales oficiales del centro para temas académicos. ColeConecta es para coordinación entre familias.',
  },
  {
    'title': 'Normas rápidas de la comunidad',
    'body': 'Sé útil y respetuoso. Nada de datos sensibles. Reporta contenido inadecuado. Esta red es privada, no es una red social.',
  },
];
