import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_provider.dart';
import '../../services/chat_service.dart';

final chatServiceProvider = Provider<ChatService>((ref) => ChatService(FirebaseFunctions.instance));

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageCtrl = TextEditingController();

  String? _selectedChatId;
  String? _selectedPeerUid;
  String? _selectedPeerName;
  String? _error;
  bool _openingChat = false;
  bool _sendingMessage = false;

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _openChat({required String schoolId, required String peerUid, required String peerName}) async {
    setState(() {
      _openingChat = true;
      _error = null;
    });

    try {
      final chatId = await ref.read(chatServiceProvider).getOrCreateChat(
            schoolId: schoolId,
            peerUid: peerUid,
          );
      if (!mounted) return;
      setState(() {
        _selectedChatId = chatId;
        _selectedPeerUid = peerUid;
        _selectedPeerName = peerName;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _openingChat = false);
      }
    }
  }

  Future<void> _sendMessage({required String schoolId, required String uid}) async {
    final chatId = _selectedChatId;
    final text = _messageCtrl.text.trim();
    if (chatId == null || text.isEmpty) return;

    setState(() {
      _sendingMessage = true;
      _error = null;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final chatRef = firestore.doc('schools/$schoolId/chats/$chatId');
      final msgRef = firestore.collection('schools/$schoolId/chats/$chatId/messages').doc();
      final batch = firestore.batch();

      batch.set(msgRef, {
        'senderUid': uid,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(chatRef, {
        'lastMessage': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      _messageCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _sendingMessage = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(schoolIdProvider).valueOrNull;
    final currentUser = FirebaseAuth.instance.currentUser;
    final uid = currentUser?.uid;

    if (schoolId == null || uid == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final peersStream = FirebaseFirestore.instance
        .collection('schools/$schoolId/users')
        .orderBy('displayName')
        .limit(100)
        .snapshots();

    final messagesStream = _selectedChatId == null
        ? null
        : FirebaseFirestore.instance
            .collection('schools/$schoolId/chats/${_selectedChatId!}/messages')
            .orderBy('createdAt')
            .limit(200)
            .snapshots();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Chat interno', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Sin teléfonos visibles. Solo familias del mismo colegio.'),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: peersStream,
              builder: (context, snapshot) {
                final peers = (snapshot.data?.docs ?? const [])
                    .where((doc) => doc.id != uid)
                    .toList();

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (peers.isEmpty) {
                  return const Card(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('No hay otras familias disponibles todavía.'),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: peers.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final peer = peers[index];
                    final data = peer.data();
                    final peerName = (data['displayName'] as String?)?.trim();
                    final classes = ((data['classIds'] as List?) ?? const []).cast<dynamic>().join(', ');
                    final isSelected = _selectedPeerUid == peer.id;

                    return SizedBox(
                      width: 260,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                peerName == null || peerName.isEmpty ? 'Familia' : peerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                classes.isEmpty ? 'Sin clase visible' : 'Clases: $classes',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Spacer(),
                              FilledButton.icon(
                                onPressed: _openingChat
                                    ? null
                                    : () => _openChat(
                                          schoolId: schoolId,
                                          peerUid: peer.id,
                                          peerName: peerName == null || peerName.isEmpty ? 'Familia' : peerName,
                                        ),
                                icon: _openingChat && isSelected
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.chat_bubble_outline),
                                label: Text(isSelected ? 'Abierto' : 'Abrir chat'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _selectedChatId == null || messagesStream == null
                    ? const Center(child: Text('Selecciona una familia para iniciar el chat.'))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Conversación con ${_selectedPeerName ?? 'Familia'}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: messagesStream,
                              builder: (context, snapshot) {
                                final docs = snapshot.data?.docs ?? const [];
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator());
                                }
                                if (docs.isEmpty) {
                                  return const Center(child: Text('No hay mensajes aún.'));
                                }

                                return ListView.builder(
                                  itemCount: docs.length,
                                  itemBuilder: (context, index) {
                                    final data = docs[index].data();
                                    final isMine = data['senderUid'] == uid;
                                    final text = (data['text'] as String?) ?? '';
                                    return Align(
                                      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 340),
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
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _messageCtrl,
                                  maxLines: 3,
                                  minLines: 1,
                                  decoration: const InputDecoration(
                                    hintText: 'Escribe un mensaje…',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: _sendingMessage ? null : () => _sendMessage(schoolId: schoolId, uid: uid),
                                child: _sendingMessage
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text('Enviar'),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
