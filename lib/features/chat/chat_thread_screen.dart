import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/session_provider.dart';
import '../../services/chat_service.dart';

class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  String _hourLabel(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send({required String schoolId}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    if (text.length > 600) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El mensaje es demasiado largo (máx. 600).')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await ref.read(chatServiceProvider).sendMessage(
            schoolId: schoolId,
            chatId: widget.chatId,
            text: text,
          );
      if (!mounted) return;
      _msgCtrl.clear();
      // Empuja el scroll hacia abajo (best-effort).
      await Future<void>.delayed(const Duration(milliseconds: 60));
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo enviar: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(schoolIdProvider).valueOrNull;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (schoolId == null || uid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final chatRef = FirebaseFirestore.instance.doc('schools/$schoolId/chats/${widget.chatId}');
    final chatStream = chatRef.snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: chatStream,
      builder: (context, chatSnap) {
        final chatData = chatSnap.data?.data();
        final participants = (chatData?['participants'] as List?)?.cast<String>() ?? const <String>[];
        final peerUid = participants.firstWhere((p) => p != uid, orElse: () => '');
        final peerStream = peerUid.isEmpty
            ? const Stream<DocumentSnapshot<Map<String, dynamic>>>.empty()
            : FirebaseFirestore.instance.doc('schools/$schoolId/users/$peerUid').snapshots();

        final messagesStream = chatRef
            .collection('messages')
            .orderBy('createdAt', descending: true)
            .limit(200)
            .snapshots();

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: peerStream,
          builder: (context, peerSnap) {
            final peerName = peerSnap.data?.data()?['displayName'] as String?;
            final title = (peerName?.trim().isNotEmpty == true) ? peerName!.trim() : (peerUid.isEmpty ? 'Chat' : peerUid);

            return Scaffold(
              appBar: AppBar(title: Text(title)),
              body: Column(
                children: [
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: messagesStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(child: Text('No se pudo cargar el chat: ${snapshot.error}'));
                        }
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final docs = snapshot.data?.docs ?? const [];
                        if (docs.isEmpty) {
                          return const Center(child: Text('Sin mensajes todavía'));
                        }

                        return ListView.builder(
                          controller: _scrollCtrl,
                          reverse: true,
                          padding: const EdgeInsets.all(12),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final data = docs[index].data();
                            final mine = data['senderUid'] == uid;
                            final status = data['status'] as String?;
                            final rawText = (data['text'] as String?) ?? '';
                            final text = (status == 'deleted' || rawText.isEmpty) ? 'Mensaje eliminado' : rawText;
                            final createdAt = data['createdAt'] as Timestamp?;

                            return Align(
                              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 360),
                                child: Card(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(text),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _hourLabel(createdAt),
                                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _msgCtrl,
                              minLines: 1,
                              maxLines: 3,
                              maxLength: 600,
                              decoration: const InputDecoration(
                                labelText: 'Escribe un mensaje',
                                border: OutlineInputBorder(),
                              ),
                              onSubmitted: (_) => _sending ? null : _send(schoolId: schoolId),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _sending ? null : () => _send(schoolId: schoolId),
                            child: Text(_sending ? '...' : 'Enviar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
