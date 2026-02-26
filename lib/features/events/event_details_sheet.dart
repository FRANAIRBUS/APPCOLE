import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EventDetailsSheet extends StatefulWidget {
  const EventDetailsSheet({
    super.key,
    required this.schoolId,
    required this.eventId,
    required this.initialEvent,
    required this.organizerName,
  });

  final String schoolId;
  final String eventId;
  final Map<String, dynamic> initialEvent;
  final String organizerName;

  @override
  State<EventDetailsSheet> createState() => _EventDetailsSheetState();
}

class _EventDetailsSheetState extends State<EventDetailsSheet> {
  final _commentCtrl = TextEditingController();
  bool _sending = false;
  int _lastMarkedCommentsCount = -1;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  String _prettyDate(Timestamp? ts) {
    if (ts == null) return 'Sin fecha';
    final date = ts.toDate();
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _markSeenCommentsCount(int commentsCount) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final now = Timestamp.now();
    final ref = FirebaseFirestore.instance
        .doc('schools/${widget.schoolId}/users/$uid/eventReads/${widget.eventId}');

    try {
      await ref.set(
        {
          'lastOpenedAt': now,
          'lastSeenCommentsCount': commentsCount,
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Best-effort.
    }
  }

  Future<void> _sendComment() async {
    final body = _commentCtrl.text.trim();
    if (body.isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _sending = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('addEventComment');
      final res = await callable.call<Map<String, dynamic>>({
        'schoolId': widget.schoolId,
        'eventId': widget.eventId,
        'body': body,
      });

      final newCountRaw = res.data['commentsCount'];
      final newCount = newCountRaw is int
          ? newCountRaw
          : int.tryParse('$newCountRaw') ?? 0;

      _commentCtrl.clear();
      await _markSeenCommentsCount(newCount);

      if (!mounted) return;
      FocusScope.of(context).unfocus();
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message ?? 'No se pudo enviar el comentario.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo enviar el comentario: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventRef = FirebaseFirestore.instance
        .doc('schools/${widget.schoolId}/events/${widget.eventId}');
    final commentsQuery = FirebaseFirestore.instance
        .collection('schools/${widget.schoolId}/events/${widget.eventId}/comments')
        .orderBy('createdAt')
        .limit(200);

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final sheetHeight = MediaQuery.of(context).size.height * 0.85;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(left: 12, right: 12, bottom: 12 + bottomInset, top: 8),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: eventRef.snapshots(),
          builder: (context, eventSnap) {
            final data = eventSnap.data?.data() ?? widget.initialEvent;
            final title = (data['title'] as String?)?.trim();
            final description = (data['description'] as String?)?.trim();
            final place = (data['place'] as String?)?.trim();
            final category = (data['category'] as String?)?.trim() ?? 'general';
            final dateTime = data['dateTime'] as Timestamp?;

            final commentsCount = (data['commentsCount'] is int)
                ? (data['commentsCount'] as int)
                : int.tryParse('${data['commentsCount'] ?? 0}') ?? 0;

            // Align read state, but avoid spamming writes on rebuild.
            if (commentsCount != _lastMarkedCommentsCount) {
              _lastMarkedCommentsCount = commentsCount;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _markSeenCommentsCount(commentsCount);
              });
            }

            return SizedBox(
              height: sheetHeight,
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title?.isNotEmpty == true ? title! : 'Evento',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
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
                    const SizedBox(height: 8),
                    Text(
                      description?.isNotEmpty == true ? description! : 'Sin descripción',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Publicado por: ${widget.organizerName.isNotEmpty ? widget.organizerName : 'Familia'}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const Divider(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Comentarios',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          commentsCount.toString(),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: commentsQuery.snapshots(),
                        builder: (context, commentsSnap) {
                          if (commentsSnap.hasError) {
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text('No se pudieron cargar los comentarios: ${commentsSnap.error}'),
                              ),
                            );
                          }
                          if (commentsSnap.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final docs = commentsSnap.data?.docs ?? const [];
                          if (docs.isEmpty) {
                            return const Align(
                              alignment: Alignment.topLeft,
                              child: Text('Sé el primero en comentar.'),
                            );
                          }

                          return ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: docs.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final c = docs[index].data();
                              final authorName = (c['authorName'] as String?)?.trim();
                              final authorPhotoUrl = (c['authorPhotoUrl'] as String?)?.trim();
                              final body = (c['body'] as String?)?.trim();
                              final createdAt = c['createdAt'] as Timestamp?;

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundImage: (authorPhotoUrl != null && authorPhotoUrl.isNotEmpty)
                                        ? NetworkImage(authorPhotoUrl)
                                        : null,
                                    child: (authorPhotoUrl == null || authorPhotoUrl.isEmpty)
                                        ? const Icon(Icons.person, size: 18)
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
                                                        ?.copyWith(fontWeight: FontWeight.w800),
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
                                            const SizedBox(height: 4),
                                            Text(body?.isNotEmpty == true ? body! : ''),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentCtrl,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sending ? null : _sendComment(),
                            minLines: 1,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: 'Escribe un comentario…',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          onPressed: _sending ? null : _sendComment,
                          child: Text(_sending ? 'Enviando…' : 'Enviar'),
                        ),
                      ],
                    ),
                  ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
