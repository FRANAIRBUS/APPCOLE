import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/session_provider.dart';
import '../../services/chat_service.dart';

final chatServiceProvider = Provider<ChatService>((ref) => ChatService(FirebaseFunctions.instance));

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _peerUidCtrl = TextEditingController();
  bool _creatingChat = false;

  @override
  void dispose() {
    _peerUidCtrl.dispose();
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
      _peerUidCtrl.clear();
      context.go('/chat/$chatId');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el chat: $e')),
      );
    } finally {
      if (mounted) setState(() => _creatingChat = false);
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Chat', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          'Privado 1:1 dentro del colegio. No compartas teléfonos ni fotos de menores.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _peerUidCtrl,
                    decoration: const InputDecoration(
                      labelText: 'UID de la otra familia (MVP)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _creatingChat ? null : () => _startChat(schoolId),
                  child: Text(_creatingChat ? '...' : 'Abrir'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
              return const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: Text('Aún no tienes chats. Usa “Mi Clase” o Talento para iniciar uno.')),
              );
            }

            return Column(
              children: docs
                  .map(
                    (d) {
                      final data = d.data();
                      final participants = (data['participants'] as List?)?.cast<String>() ?? const [];
                      final peer = participants.where((p) => p != uid).join(', ');
                      final last = (data['lastMessage'] as String?)?.trim();

                      return Card(
                        child: ListTile(
                          title: Text(peer.isEmpty ? 'Chat' : peer),
                          subtitle: Text(
                            (last != null && last.isNotEmpty) ? last : 'Sin mensajes',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.go('/chat/${d.id}'),
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
