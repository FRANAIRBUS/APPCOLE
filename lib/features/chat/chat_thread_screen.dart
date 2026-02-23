import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_provider.dart';

class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _msgCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _send({required String schoolId, required String uid}) async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      final chatRef = FirebaseFirestore.instance.doc('schools/$schoolId/chats/${widget.chatId}');
      await chatRef.collection('messages').add({
        'senderUid': uid,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await chatRef.update({
        'lastMessage': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
      _msgCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(schoolIdProvider).valueOrNull;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (schoolId == null || uid == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final stream = FirebaseFirestore.instance
        .collection('schools/$schoolId/chats/${widget.chatId}/messages')
        .orderBy('createdAt')
        .limit(150)
        .snapshots();

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Volver',
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Chat',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? const [];
                if (docs.isEmpty) {
                  return const Center(child: Text('Sin mensajes todavía'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final mine = data['senderUid'] == uid;
                    final text = data['text'] as String? ?? '';

                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text(text),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Escribe un mensaje',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _send(schoolId: schoolId, uid: uid),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _sending ? null : () => _send(schoolId: schoolId, uid: uid),
                  child: Text(_sending ? '...' : 'Enviar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
