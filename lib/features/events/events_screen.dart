import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/session_provider.dart';

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  bool _creating = false;

  String _prettyDate(Timestamp? ts) {
    if (ts == null) return 'Sin fecha';
    final date = ts.toDate();
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _createEvent(String schoolId) async {
    final draft = await showModalBottomSheet<_EventDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _EventComposerSheet(),
    );
    if (draft == null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _creating = true);
    try {
      await FirebaseFirestore.instance.collection('schools/$schoolId/events').add({
        'title': draft.title,
        'description': draft.description,
        'dateTime': Timestamp.fromDate(draft.dateTime),
        'place': draft.place,
        'category': draft.category,
        'organizerUid': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',
        'reportsCount': 0,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Evento creado.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo crear el evento: $e')));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(schoolIdProvider).valueOrNull;
    if (schoolId == null) return const Center(child: CircularProgressIndicator());

    final stream = FirebaseFirestore.instance
        .collection('schools/$schoolId/events')
        .orderBy('dateTime')
        .limit(120)
        .snapshots();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Entre Padres',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Coordina quedadas, actividades y avisos importantes entre familias.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _creating ? null : () => _createEvent(schoolId),
          icon: const Icon(Icons.add),
          label: Text(_creating ? 'Guardando...' : 'Nuevo evento'),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              final message = snapshot.error.toString();
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    message.contains('failed-precondition')
                        ? 'No se pudieron cargar eventos por configuración de consulta. Ya se aplicó un fallback; recarga la página.'
                        : 'No se pudieron cargar eventos: $message',
                  ),
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final docs = (snapshot.data?.docs ?? const []).where((doc) {
              final data = doc.data();
              return data['status'] == 'active';
            }).toList();
            if (docs.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('Todavía no hay eventos activos.'),
                ),
              );
            }

            return Column(
              children: docs.map((doc) {
                final data = doc.data();
                final title = (data['title'] as String?)?.trim();
                final description = (data['description'] as String?)?.trim();
                final place = (data['place'] as String?)?.trim();
                final category = (data['category'] as String?)?.trim() ?? 'general';
                final dateTime = data['dateTime'] as Timestamp?;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(title?.isNotEmpty == true ? title! : 'Evento'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(description?.isNotEmpty == true ? description! : 'Sin descripción'),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            Chip(label: Text(category)),
                            Chip(label: Text(place?.isNotEmpty == true ? place! : 'Sin ubicación')),
                            Chip(label: Text(_prettyDate(dateTime))),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _EventDraft {
  const _EventDraft({
    required this.title,
    required this.description,
    required this.place,
    required this.category,
    required this.dateTime,
  });

  final String title;
  final String description;
  final String place;
  final String category;
  final DateTime dateTime;
}

class _EventComposerSheet extends StatefulWidget {
  const _EventComposerSheet();

  @override
  State<_EventComposerSheet> createState() => _EventComposerSheetState();
}

class _EventComposerSheetState extends State<_EventComposerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _place = TextEditingController();
  final _category = TextEditingController(text: 'social');
  DateTime _dateTime = DateTime.now().add(const Duration(days: 1));

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _place.dispose();
    _category.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _dateTime,
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (time == null || !mounted) return;

    setState(() {
      _dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Nuevo evento',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Título'),
                  validator: (value) => (value ?? '').trim().length < 4 ? 'Título muy corto.' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _description,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                  validator: (value) => (value ?? '').trim().length < 8 ? 'Describe el evento.' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _place,
                  decoration: const InputDecoration(labelText: 'Lugar'),
                  validator: (value) => (value ?? '').trim().isEmpty ? 'Indica el lugar.' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _category,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  validator: (value) => (value ?? '').trim().isEmpty ? 'Indica una categoría.' : null,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _pickDateTime,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text('Fecha: ${_dateTime.day}/${_dateTime.month} ${_dateTime.hour}:${_dateTime.minute.toString().padLeft(2, '0')}'),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    if (!_formKey.currentState!.validate()) return;
                    Navigator.of(context).pop(
                      _EventDraft(
                        title: _title.text.trim(),
                        description: _description.text.trim(),
                        place: _place.text.trim(),
                        category: _category.text.trim(),
                        dateTime: _dateTime,
                      ),
                    );
                  },
                  child: const Text('Guardar evento'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
