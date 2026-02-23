import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/session_provider.dart';

class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key});

  String _relativeDate(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final diff = DateTime.now().difference(timestamp.toDate());
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolId = ref.watch(schoolIdProvider).valueOrNull;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (schoolId == null || uid == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final chatsStream = FirebaseFirestore.instance
        .collection('schools/$schoolId/chats')
        .where('participants', arrayContains: uid)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: chatsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('No se pudieron cargar tus chats: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

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
              padding: EdgeInsets.all(16),
              child: Text('Aún no tienes chats. Abre uno desde “Mi Clase” o desde el perfil de otra familia.'),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final chatId = docs[index].id;
            final data = docs[index].data();
            final participants = (data['participants'] as List?)?.cast<String>() ?? const <String>[];
            final peerUid = participants.firstWhere((p) => p != uid, orElse: () => '');
            final lastMessage = (data['lastMessage'] as String?)?.trim() ?? '';
            final lastMessageAt = data['lastMessageAt'] as Timestamp?;

            final peerStream = peerUid.isEmpty
                ? const Stream<DocumentSnapshot<Map<String, dynamic>>>.empty()
                : FirebaseFirestore.instance.doc('schools/$schoolId/users/$peerUid').snapshots();

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: peerStream,
              builder: (context, peerSnap) {
                final peerName = peerSnap.data?.data()?['displayName'] as String?;
                final title = (peerName?.trim().isNotEmpty == true) ? peerName!.trim() : (peerUid.isEmpty ? 'Chat' : peerUid);

                return ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      (title.trim().isEmpty ? 'C' : title.trim().substring(0, 1)).toUpperCase(),
                    ),
                  ),
                  title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    lastMessage.isEmpty ? 'Sin mensajes' : lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    _relativeDate(lastMessageAt),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  onTap: () => context.push('/chat/$chatId'),
                );
              },
            );
          },
        );
      },
    );
  }
}
