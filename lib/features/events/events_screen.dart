import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/session_provider.dart';

class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolId = ref.watch(schoolIdProvider).valueOrNull;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (schoolId == null || uid == null) return const Center(child: CircularProgressIndicator());

    final stream = FirebaseFirestore.instance
        .collection('schools/$schoolId/events')
        .where('status', isEqualTo: 'active')
        .orderBy('dateTime')
        .limit(40)
        .snapshots();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
      children: [
        Text(
          'Entre Padres',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Eventos y planes entre familias del colegio.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _showEventComposer(context: context, schoolId: schoolId, organizerUid: uid),
          icon: const Icon(Icons.add),
          label: const Text('Nuevo evento'),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Text('Error cargando eventos: ${snapshot.error}'),
              );
            }

            final docs = snapshot.data?.docs ?? const [];
            if (docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('Aún no hay eventos. Crea el primero.')),
              );
            }

            return Column(
              children: docs
                  .map(
                    (doc) {
                      final data = doc.data();
                      final title = (data['title'] as String?)?.trim() ?? '';
                      final place = (data['place'] as String?)?.trim() ?? '';
                      final desc = (data['description'] as String?)?.trim() ?? '';
                      final ts = data['dateTime'];
                      final dt = ts is Timestamp ? ts.toDate() : null;

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title.isEmpty ? 'Evento' : title,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.place, size: 16, color: Theme.of(context).colorScheme.outline),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      place.isEmpty ? 'Lugar por definir' : place,
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.schedule, size: 16, color: Theme.of(context).colorScheme.outline),
                                  const SizedBox(width: 6),
                                  Text(dt == null ? '...' : _formatDateTime(dt), style: Theme.of(context).textTheme.bodySmall),
                                ],
                              ),
                              if (desc.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(desc, style: Theme.of(context).textTheme.bodyMedium),
                              ]
                            ],
                          ),
                        ),
                      );
                    },
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

Future<void> _showEventComposer({
  required BuildContext context,
  required String schoolId,
  required String organizerUid,
}) async {
  final titleCtrl = TextEditingController();
  final placeCtrl = TextEditingController();
  final descCtrl = TextEditingController();

  DateTime date = DateTime.now().add(const Duration(days: 2));
  TimeOfDay time = const TimeOfDay(hour: 17, minute: 0);
  bool sending = false;

  Future<void> pickDate(StateSetter setModalState) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: date,
    );
    if (picked == null) return;
    setModalState(() => date = DateTime(picked.year, picked.month, picked.day, date.hour, date.minute));
  }

  Future<void> pickTime(StateSetter setModalState) async {
    final picked = await showTimePicker(context: context, initialTime: time);
    if (picked == null) return;
    setModalState(() => time = picked);
  }

  Future<void> submit(StateSetter setModalState) async {
    final title = titleCtrl.text.trim();
    final place = placeCtrl.text.trim();
    final desc = descCtrl.text.trim();

    if (title.isEmpty || place.isEmpty) return;

    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);

    setModalState(() => sending = true);
    try {
      await FirebaseFirestore.instance.collection('schools/$schoolId/events').add({
        'title': title,
        'description': desc,
        'dateTime': Timestamp.fromDate(dt),
        'place': place,
        'organizerUid': organizerUid,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo crear el evento: $e')),
      );
    } finally {
      if (context.mounted) setModalState(() => sending = false);
    }
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Nuevo evento',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    maxLength: 70,
                    decoration: const InputDecoration(
                      labelText: 'Título',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: placeCtrl,
                    maxLength: 70,
                    decoration: const InputDecoration(
                      labelText: 'Lugar',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: sending ? null : () => pickDate(setModalState),
                          icon: const Icon(Icons.calendar_month),
                          label: Text(_formatDate(date)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: sending ? null : () => pickTime(setModalState),
                          icon: const Icon(Icons.schedule),
                          label: Text(time.format(context)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    minLines: 2,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Descripción (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: sending ? null : () => submit(setModalState),
                    icon: const Icon(Icons.check),
                    label: Text(sending ? 'Guardando...' : 'Crear evento'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

String _formatDate(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.day)}/${two(dt.month)}/${dt.year}';
}

String _formatDateTime(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
}
