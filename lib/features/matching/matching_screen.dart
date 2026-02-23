import 'package:cloud_firestore/cloud_firestore.dart';
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
        if (meSnapshot.hasError) {
          return Center(child: Text('No se pudo cargar tu perfil: ${meSnapshot.error}'));
        }
        if (meSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final myClassIds = (meSnapshot.data?.data()?['classIds'] as List?)?.cast<String>() ?? const [];
        if (myClassIds.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Aún no tienes clases asignadas. Pide al colegio que complete tu perfil.'),
            ),
          );
        }

        final peersQuery = FirebaseFirestore.instance
            .collection('schools/$schoolId/users')
            .where('classIds', arrayContainsAny: myClassIds)
            .limit(50)
            .snapshots();

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: peersQuery,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('No se pudo cargar familias de tu clase: ${snapshot.error}'));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final peers = snapshot.data?.docs.where((d) => d.id != uid).toList() ?? [];
            peers.sort((a, b) {
              int overlap(Map<String, dynamic> data) {
                final classIds = (data['classIds'] as List?)?.cast<String>() ?? const [];
                return classIds.where(myClassIds.contains).length;
              }

              return overlap(b.data()).compareTo(overlap(a.data()));
            });

            if (peers.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Todavía no hay otras familias con clases en común.'),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Mi Clase',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Encuentra familias con aulas en común y abre chat directo.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                ...peers.map((peer) => Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            (((peer.data()['displayName'] as String?) ?? 'F').trim().isEmpty
                                    ? 'F'
                                    : ((peer.data()['displayName'] as String?) ?? 'F').trim().substring(0, 1))
                                .toUpperCase(),
                          ),
                        ),
                        title: Text(peer.data()['displayName'] ?? 'Familia'),
                        subtitle:
                            Text('Clases en común: ${((peer.data()['classIds'] as List?) ?? []).where(myClassIds.contains).length}'),
                        trailing: OutlinedButton(
                          onPressed: () async {
                            try {
                              final chatId = await ref.read(chatServiceProvider).getOrCreateChat(
                                    schoolId: schoolId,
                                    peerUid: peer.id,
                                  );
                              if (!context.mounted) return;
                              context.go('/chat/$chatId');
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('No se pudo abrir el chat: $e')),
                              );
                            }
                          },
                          child: const Text('Mensaje'),
                        ),
                      ),
                    ))
              ],
            );
          },
        );
      },
    );
  }
}
