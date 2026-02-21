import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PostsScreen extends StatelessWidget {
  const PostsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Busco / Ofrezco', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        FilledButton(onPressed: () => context.push('/talento'), child: const Text('Talento del Cole')),
        FilledButton(onPressed: () => context.push('/biblio'), child: const Text('BiblioCircular')),
        FilledButton(onPressed: () => context.push('/veteranos'), child: const Text('Trucos de los Veteranos')),
      ],
    );
  }
}
