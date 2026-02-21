import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router/app_router.dart';

class PostsScreen extends ConsumerWidget {
  const PostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolId = ref.watch(schoolIdProvider).valueOrNull;
    if (schoolId == null) return const Center(child: CircularProgressIndicator());

    final posts = FirebaseFirestore.instance
        .collection('schools/$schoolId/posts')
        .where('module', isEqualTo: 'busco_ofrezco')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Busco / Ofrezco', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(onPressed: () => context.push('/talento'), child: const Text('Talento')),
            FilledButton(onPressed: () => context.push('/biblio'), child: const Text('BiblioCircular')),
            FilledButton(onPressed: () => context.push('/veteranos'), child: const Text('Veteranos')),
            FilledButton(onPressed: () => context.push('/bienvenida'), child: const Text('Primer Día')),
            FilledButton(onPressed: () => context.push('/confianza'), child: const Text('Red de Confianza')),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () async {
            await FirebaseFirestore.instance.collection('schools/$schoolId/posts').add({
              'module': 'busco_ofrezco',
              'type': 'busco',
              'category': 'general',
              'title': 'Necesito ayuda con recogida',
              'body': '¿Alguien puede recoger hoy?',
              'authorUid': FirebaseAuth.instance.currentUser!.uid,
              'createdAt': FieldValue.serverTimestamp(),
              'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 14))),
              'status': 'active',
              'reportsCount': 0,
            });
          },
          icon: const Icon(Icons.add),
          label: const Text('Crear post de ejemplo'),
        ),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: posts,
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? const [];
            return Column(
              children: docs
                  .map((d) => Card(
                        child: ListTile(
                          title: Text(d.data()['title'] ?? ''),
                          subtitle: Text(d.data()['body'] ?? ''),
                        ),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}
