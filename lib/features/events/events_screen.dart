import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../router/app_router.dart';

class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolId = ref.watch(schoolIdProvider).valueOrNull;
    if (schoolId == null) return const Center(child: CircularProgressIndicator());

    final stream = FirebaseFirestore.instance
        .collection('schools/$schoolId/events')
        .where('status', isEqualTo: 'active')
        .orderBy('dateTime')
        .limit(20)
        .snapshots();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Entre Padres', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        FilledButton(
          onPressed: () async {
            await FirebaseFirestore.instance.collection('schools/$schoolId/events').add({
              'title': 'Quedada parque',
              'description': 'Encuentro familiar',
              'dateTime': Timestamp.fromDate(DateTime.now().add(const Duration(days: 2))),
              'place': 'Parque central',
              'category': 'social',
              'organizerUid': FirebaseAuth.instance.currentUser!.uid,
              'createdAt': FieldValue.serverTimestamp(),
              'status': 'active',
              'reportsCount': 0,
            });
          },
          child: const Text('Crear evento de ejemplo'),
        ),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? const [];
            return Column(
              children: docs
                  .map((doc) => Card(
                        child: ListTile(
                          title: Text(doc.data()['title'] ?? ''),
                          subtitle: Text(doc.data()['place'] ?? ''),
                        ),
                      ))
                  .toList(),
            );
          },
        )
      ],
    );
  }
}
