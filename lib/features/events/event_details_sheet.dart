import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class EventDetailsSheet extends StatefulWidget {
  const EventDetailsSheet({
    super.key,
    required this.schoolId,
    required this.eventId,
    required this.initialCommentsCount,
  });

  final String schoolId;
  final String eventId;
  final int initialCommentsCount;

  @override
  State<EventDetailsSheet> createState() => _EventDetailsSheetState();
}

class _EventDetailsSheetState extends State<EventDetailsSheet> {
  final _commentCtrl = TextEditingController();
  bool _sending = false;
  int? _syncedCommentsCount;

  String _prettyDate(Timestamp? ts) {
    if (ts == null) return 'Sin fecha';
    final date = ts.toDate();
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  DocumentReference<Map<String, dynamic>> _eventRef() {
    return FirebaseFirestore.instance.doc('schools/${widget.schoolId}/events/${widget.eventId}');
  }

  DocumentReference<Map<String, dynamic>> _readRef(String uid) {
    return FirebaseFirestore.instance
        .doc('schools/${widget.schoolId}/users/$uid/eventReads/${widget.eventId}');
  }

  Future<void> _markRead({required String uid, required int commentsCount}) async {
    try {
      await _readRef(uid).set(
        {
          'lastOpenedAt': FieldValue.serverTimestamp(),
          'lastSeenCommentsCount': commentsCount,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Silencio: si falla por rules o red, no rompemos la vista.
    }
  }

  Future<void> _sendComment({required String uid}) async {
    final body = _commentCtrl.text.trim();
    if (body.isEmpty) return;
    if (body.length > 700) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Comentario demasiado largo (máx 700).')));
      return;
    }

    setState(() => _sending = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('addEventComment');
      final res = await callable.call({
        'schoolId': widget.schoolId,
        'eventId': widget.eventId,
        'body': body,
      });
      _commentCtrl.clear();

      final data = (res.data is Map) ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
      final newCount = (data['commentsCount'] as num?)?.toInt();
      if (newCount != null) {
        _syncedCommentsCount = newCount;
        await _markRead(uid: uid, commentsCount: newCount);
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      final details = (e.details == null) ? '' : ' (${e.details})';
      final msg = (e.message ?? 'No se pudo enviar el comentario.').trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('[${e.code}] $msg$details')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo enviar el comentario: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _syncedCommentsCount = widget.initialCommentsCount;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      // Al abrir la tarjeta, ya se considera leído.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _markRead(uid: uid, commentsCount: widget.initialCommentsCount);
      });
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    final commentsQuery = _eventRef()
        .collection('comments')
        .orderBy('createdAt', descending: false)
        // Cost control: cargamos solo lo más reciente. Si quieres paginación, se hace luego.
        .limit(80)
        .snapshots();

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.9,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Detalle del evento',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      tooltip: 'Cerrar',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _eventRef().snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Center(child: Text('No se pudo cargar el evento: ${snap.error}'));
                    }
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final doc = snap.data!;
                    if (!doc.exists) {
                      return const Center(child: Text('Evento no disponible.'));
                    }

                    final data = doc.data() ?? {};
                    final title = (data['title'] as String?)?.trim();
                    final description = (data['description'] as String?)?.trim();
                    final place = (data['place'] as String?)?.trim();
                    final category = (data['category'] as String?)?.trim() ?? 'general';
                    final dateTime = data['dateTime'] as Timestamp?;
                    final organizerName = (data['organizerName'] as String?)?.trim();
                    final commentsCount = (data['commentsCount'] as num?)?.toInt() ?? 0;

                    if (uid != null && (_syncedCommentsCount == null || commentsCount != _syncedCommentsCount)) {
                      _syncedCommentsCount = commentsCount;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _markRead(uid: uid, commentsCount: commentsCount);
                      });
                    }

                    return Column(
                      children: [
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            children: [
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title?.isNotEmpty == true ? title! : 'Evento',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(fontWeight: FontWeight.w800),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(description?.isNotEmpty == true ? description! : 'Sin descripción'),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          Chip(label: Text(category)),
                                          Chip(label: Text(place?.isNotEmpty == true ? place! : 'Sin ubicación')),
                                          Chip(label: Text(_prettyDate(dateTime))),
                                          Chip(label: Text('Comentarios: $commentsCount')),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Publicado por: ${organizerName?.isNotEmpty == true ? organizerName! : 'Familia'}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Comentarios',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                stream: commentsQuery,
                                builder: (context, commentsSnap) {
                                  if (commentsSnap.hasError) {
                                    return Text('No se pudieron cargar comentarios: ${commentsSnap.error}');
                                  }
                                  if (!commentsSnap.hasData) {
                                    return const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Center(child: CircularProgressIndicator()),
                                    );
                                  }

                                  final commentDocs = commentsSnap.data?.docs ?? const [];
                                  if (commentDocs.isEmpty) {
                                    return const Card(
                                      child: Padding(
                                        padding: EdgeInsets.all(14),
                                        child: Text('Todavía no hay comentarios.'),
                                      ),
                                    );
                                  }

                                  return Column(
                                    children: commentDocs.map((c) {
                                      final cd = c.data();
                                      final authorName = (cd['authorName'] as String?)?.trim();
                                      final body = (cd['body'] as String?)?.trim();
                                      final createdAt = cd['createdAt'] as Timestamp?;
                                      return Card(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      authorName?.isNotEmpty == true ? authorName! : 'Familia',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.copyWith(fontWeight: FontWeight.w700),
                                                    ),
                                                  ),
                                                  Text(
                                                    _prettyDate(createdAt),
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: Theme.of(context)
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(body?.isNotEmpty == true ? body! : ''),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                              const SizedBox(height: 72),
                            ],
                          ),
                        ),
                        if (uid == null)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Inicia sesión para comentar.'),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _commentCtrl,
                                    minLines: 1,
                                    maxLines: 4,
                                    textInputAction: TextInputAction.newline,
                                    decoration: const InputDecoration(
                                      labelText: 'Escribe un comentario',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                FilledButton.icon(
                                  onPressed: _sending ? null : () => _sendComment(uid: uid),
                                  icon: _sending
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.send),
                                  label: const Text('Enviar'),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
