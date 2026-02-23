import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/session_provider.dart';
import '../../services/chat_service.dart';

class MatchingScreen extends ConsumerWidget {
  const MatchingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolId = ref.watch(schoolIdProvider).valueOrNull;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (schoolId == null || uid == null) return const Center(child: CircularProgressIndicator());

    final meDoc = FirebaseFirestore.instance.doc('schools/$schoolId/users/$uid').snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: meDoc,
      builder: (context, meSnapshot) {
        final myClassIds = (meSnapshot.data?.data()?['classIds'] as List?)?.cast<String>() ?? const [];
        if (myClassIds.isEmpty) return const Center(child: Text('Aún no tienes clases asignadas.'));

        final peersQuery = FirebaseFirestore.instance
            .collection('schools/$schoolId/users')
            .where('classIds', arrayContainsAny: myClassIds)
            .limit(50)
            .snapshots();

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: peersQuery,
          builder: (context, snapshot) {
            final peers = snapshot.data?.docs.where((d) => d.id != uid).toList() ?? [];
            peers.sort((a, b) {
              int overlap(Map<String, dynamic> data) {
                final classIds = (data['classIds'] as List?)?.cast<String>() ?? const [];
                return classIds.where(myClassIds.contains).length;
              }

              return overlap(b.data()).compareTo(overlap(a.data()));
            });

            Future<void> openChat(String peerUid) async {
              try {
                final chatId = await ChatService(FirebaseFunctions.instance).getOrCreateChat(
                  schoolId: schoolId,
                  peerUid: peerUid,
                );
                if (context.mounted) context.go('/chat/$chatId');
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('No se pudo abrir el chat: $e')),
                );
              }
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Mi Clase', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  'Matching por clase. Contacto por chat interno 1:1 (sin teléfonos).',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                ...peers.map(
                  (peer) {
                    final data = peer.data();
                    final peerClasses = (data['classIds'] as List?)?.cast<String>() ?? const [];
                    final shared = peerClasses.where(myClassIds.contains).length;

                    return Card(
                      child: ListTile(
                        title: Text(data['displayName'] ?? 'Familia'),
                        subtitle: Text('Clases en común: $shared'),
                        trailing: FilledButton(
                          onPressed: () => openChat(peer.id),
                          child: const Text('Mensaje'),
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
