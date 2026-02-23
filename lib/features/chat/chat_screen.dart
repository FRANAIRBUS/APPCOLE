import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../router/app_router.dart';
import '../../services/chat_service.dart';

final chatServiceProvider = Provider<ChatService>((ref) => ChatService(FirebaseFunctions.instance));

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _peerUidCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  bool _creatingChat = false;
  bool _sending = false;
  String? _selectedChatId;

  @override
  void dispose() {
    _peerUidCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _startChat(String schoolId) async {
    final peerUid = _peerUidCtrl.text.trim();
    if (peerUid.isEmpty) return;

    setState(() => _creatingChat = true);
    try {
      final chatId = await ref.read(chatServiceProvider).getOrCreateChat(
            schoolId: schoolId,
            peerUid: peerUid,
          );
      if (!mounted) return;
      setState(() => _selectedChatId = chatId);
      _peerUidCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el chat: $e')),
      );
    } finally {
      if (mounted) setState(() => _creatingChat = false);
    }
  }

  Future<void> _sendMessage({required String schoolId, required String chatId, required String uid}) async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      final chatRef = FirebaseFirestore.instance.doc('schools/$schoolId/chats/$chatId');
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

    final chatsStream = FirebaseFirestore.instance
        .collection('schools/$schoolId/chats')
        .where('participants', arrayContains: uid)
        .snapshots();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Chat interno', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _peerUidCtrl,
                  decoration: const InputDecoration(
                    labelText: 'UID de la otra familia',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _creatingChat ? null : () => _startChat(schoolId),
                child: Text(_creatingChat ? '...' : 'Abrir chat'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Card(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: chatsStream,
                      builder: (context, snapshot) {
                        final docs = [...(snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[])];
                        docs.sort((a, b) {
                          final aTs = a.data()['lastMessageAt'];
                          final bTs = b.data()['lastMessageAt'];
                          final aMs = aTs is Timestamp ? aTs.millisecondsSinceEpoch : 0;
                          final bMs = bTs is Timestamp ? bTs.millisecondsSinceEpoch : 0;
                          return bMs.compareTo(aMs);
                        });

                        if (docs.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('Aún no tienes chats. Abre uno usando el UID de otra familia.'),
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final data = docs[index].data();
                            final participants = (data['participants'] as List?)?.cast<String>() ?? const [];
                            final peer = participants.where((p) => p != uid).join(', ');
                            final isSelected = docs[index].id == _selectedChatId;

                            return ListTile(
                              selected: isSelected,
                              title: Text(peer.isEmpty ? 'Chat' : peer),
                              subtitle: Text(
                                (data['lastMessage'] as String?)?.trim().isNotEmpty == true
                                    ? data['lastMessage'] as String
                                    : 'Sin mensajes',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => setState(() => _selectedChatId = docs[index].id),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 6,
                  child: Card(
                    child: _selectedChatId == null
                        ? const Center(child: Text('Selecciona un chat para ver mensajes'))
                        : _MessagesPanel(
                            schoolId: schoolId,
                            chatId: _selectedChatId!,
                            currentUid: uid,
                            messageController: _msgCtrl,
                            sending: _sending,
                            onSend: () => _sendMessage(
                              schoolId: schoolId,
                              chatId: _selectedChatId!,
                              uid: uid,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessagesPanel extends StatelessWidget {
  const _MessagesPanel({
    required this.schoolId,
    required this.chatId,
    required this.currentUid,
    required this.messageController,
    required this.sending,
    required this.onSend,
  });

  final String schoolId;
  final String chatId;
  final String currentUid;
  final TextEditingController messageController;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('schools/$schoolId/chats/$chatId/messages')
        .orderBy('createdAt')
        .limit(100)
        .snapshots();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Chat: $chatId', style: Theme.of(context).textTheme.titleSmall),
          ),
        ),
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
                  final mine = data['senderUid'] == currentUid;
                  final text = data['text'] as String? ?? '';

                  return Align(
                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
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
                  controller: messageController,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Escribe un mensaje',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: sending ? null : onSend,
                child: Text(sending ? '...' : 'Enviar'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
