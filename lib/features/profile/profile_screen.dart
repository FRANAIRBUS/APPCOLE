import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../router/app_router.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    final schoolId = ref.watch(schoolIdProvider).valueOrNull;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Perfil', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text('Cuenta: ${user?.email ?? user?.uid ?? ''}'),
        const ListTile(
          title: Text('Privacidad'),
          subtitle: Text('No compartas teléfonos ni fotos con menores.'),
        ),
        FilledButton(
          onPressed: () => ref.read(authServiceProvider).signOut(),
          child: const Text('Cerrar sesión'),
        ),
        if (schoolId != null)
          OutlinedButton(
            onPressed: () async {
              await FirebaseFunctions.instance.httpsCallable('deleteMyAccount').call({'schoolId': schoolId});
            },
            child: const Text('Borrar cuenta (GDPR)'),
          ),
      ],
    );
  }
}
