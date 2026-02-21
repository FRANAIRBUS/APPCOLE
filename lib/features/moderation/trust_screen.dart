import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../router/app_router.dart';

class TrustScreen extends ConsumerWidget {
  const TrustScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolId = ref.watch(schoolIdProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Red de Confianza')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Normas: respeto, utilidad, privacidad. Prohibidas fotos con menores.'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: schoolId == null
                ? null
                : () => FirebaseFirestore.instance.collection('schools/$schoolId/reports').add({
                      'targetType': 'post',
                      'targetPath': 'schools/$schoolId/posts/demo',
                      'reason': 'Contenido inadecuado',
                      'reporterUid': FirebaseAuth.instance.currentUser?.uid,
                      'createdAt': FieldValue.serverTimestamp(),
                      'status': 'open',
                    }),
            child: const Text('Reportar contenido (demo)'),
          )
        ],
      ),
    );
  }
}
