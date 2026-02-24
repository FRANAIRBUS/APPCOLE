import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/session_provider.dart';
import '../../services/chat_service.dart';
import '../../services/invite_share_service.dart';

class MatchingScreen extends ConsumerWidget {
  const MatchingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolId = ref.watch(schoolIdProvider).valueOrNull;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (schoolId == null || uid == null) return const Center(child: CircularProgressIndicator());

    final meDoc = FirebaseFirestore.instance.doc('schools/$schoolId/users/$uid').snapshots();

    Future<void> shareInviteCard() async {
      try {
        await ref.read(inviteShareServiceProvider).shareInviteCard(
              schoolId: schoolId,
              source: 'matching',
            );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tarjeta copiada. Compártela por WhatsApp o email.')),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo compartir la invitación: $e')),
        );
      }
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: meDoc,
      builder: (context, meSnapshot) {
        if (meSnapshot.hasError) {
          return Center(child: Text('No se pudo cargar tu perfil: ${meSnapshot.error}'));
        }
        if (meSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final meData = meSnapshot.data?.data() ?? const <String, dynamic>{};
        final myClassIds = (meData['classIds'] as List?)?.map((e) => e.toString()).toList() ?? const [];
        final myExtraGroupIds = (meData['extraGroupIds'] as List?)?.map((e) => e.toString()).toList() ?? const [];
        final myMatchIds = [...{...myClassIds, ...myExtraGroupIds}].where((id) => id.trim().isNotEmpty).toList();

        if (myMatchIds.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Mi Clase',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Aún no tienes clases o grupos asignados. Completa tu perfil y comparte tu invitación con otras familias.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: shareInviteCard,
                icon: const Icon(Icons.share_outlined),
                label: const Text('Invitar a padres al colegio'),
              ),
            ],
          );
        }

        final peersQuery = FirebaseFirestore.instance
            .collection('schools/$schoolId/users')
            .where('classIds', arrayContainsAny: myMatchIds.take(30).toList())
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
                final classIds = (data['classIds'] as List?)?.map((e) => e.toString()).toList() ?? const [];
                final extraGroupIds = (data['extraGroupIds'] as List?)?.map((e) => e.toString()).toList() ?? const [];
                final matchIds = [...{...classIds, ...extraGroupIds}];
                return matchIds.where(myMatchIds.contains).length;
              }

              return overlap(b.data()).compareTo(overlap(a.data()));
            });

            if (peers.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Mi Clase',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Todavía no hay otras familias con clases en común.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: shareInviteCard,
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Invitar a padres al colegio'),
                  ),
                ],
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
                  'Encuentra familias con clases o grupos en común y abre chat directo.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: shareInviteCard,
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Invitar a padres al colegio'),
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
                        subtitle: Text(
                          'Coincidencias: ${([
                            ...(((peer.data()['classIds'] as List?) ?? const []).map((e) => e.toString())),
                            ...(((peer.data()['extraGroupIds'] as List?) ?? const []).map((e) => e.toString())),
                          ]).where(myMatchIds.contains).toSet().length}',
                        ),
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
