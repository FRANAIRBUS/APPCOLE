import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../router/app_router.dart';

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

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Mi Clase', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ...peers.map((peer) => Card(
                      child: ListTile(
                        title: Text(peer.data()['displayName'] ?? 'Familia'),
                        subtitle: Text('Clases en común: ${((peer.data()['classIds'] as List?) ?? []).where(myClassIds.contains).length}'),
                        trailing: OutlinedButton(
                          onPressed: () => FirebaseFirestore.instance.collection('schools/$schoolId/connections').add({
                            'fromUid': uid,
                            'toUid': peer.id,
                            'status': 'pending',
                            'createdAt': FieldValue.serverTimestamp(),
                          }),
                          child: const Text('Conectar'),
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
