import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ModuleFeed extends StatelessWidget {
  const ModuleFeed({
    super.key,
    required this.schoolId,
    required this.module,
    required this.emptyHint,
  });

  final String schoolId;
  final String module;
  final String emptyHint;

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('schools/$schoolId/posts')
        .where('module', isEqualTo: module)
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text('Error cargando publicaciones: ${snapshot.error}'),
          );
        }

        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(child: Text(emptyHint)),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final title = (data['title'] as String?)?.trim() ?? '';
            final body = (data['body'] as String?)?.trim() ?? '';
            final type = (data['type'] as String?)?.trim();
            final ts = data['createdAt'];
            final dt = ts is Timestamp ? ts.toDate() : null;

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title.isEmpty ? 'Sin título' : title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (type != null && type.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(type, style: Theme.of(context).textTheme.labelMedium),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(body, style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 16, color: Theme.of(context).colorScheme.outline),
                        const SizedBox(width: 6),
                        Text(
                          dt == null ? 'Publicando...' : _formatDateTime(dt),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
                        ),
                      ],
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
}

Future<void> showPostComposerBottomSheet({
  required BuildContext context,
  required String schoolId,
  required String module,
  required String defaultType,
  required List<String> allowedTypes,
  String? titleHint,
}) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  final titleCtrl = TextEditingController();
  final bodyCtrl = TextEditingController();
  var type = defaultType;
  var sending = false;

  Future<void> submit(StateSetter setModalState) async {
    final title = titleCtrl.text.trim();
    final body = bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) return;

    setModalState(() => sending = true);
    try {
      await FirebaseFirestore.instance.collection('schools/$schoolId/posts').add({
        'module': module,
        'type': type,
        'title': title,
        'body': body,
        'authorUid': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
        'status': 'active',
      });

      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo publicar: $e')),
      );
    } finally {
      if (context.mounted) {
        setModalState(() => sending = false);
      }
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
                    titleHint ?? 'Nueva publicación',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Recuerda: sin teléfonos y sin fotos de menores.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  if (allowedTypes.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: type,
                      items: allowedTypes
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(t),
                              ))
                          .toList(),
                      onChanged: sending
                          ? null
                          : (v) {
                              if (v == null) return;
                              setModalState(() => type = v);
                            },
                      decoration: const InputDecoration(
                        labelText: 'Tipo',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  if (allowedTypes.isNotEmpty) const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Título',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bodyCtrl,
                    minLines: 3,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Mensaje',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: sending ? null : () => submit(setModalState),
                    icon: const Icon(Icons.send),
                    label: Text(sending ? 'Publicando...' : 'Publicar'),
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

String _formatDateTime(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
}
