import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/session_provider.dart';
import '../../services/chat_service.dart';

class PostsScreen extends ConsumerStatefulWidget {
  const PostsScreen({super.key});

  @override
  ConsumerState<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends ConsumerState<PostsScreen> {
  bool _creating = false;

  String _relativeDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Ahora';
    final diff = DateTime.now().difference(timestamp.toDate());
    if (diff.inMinutes < 1) return 'Hace unos segundos';
    if (diff.inHours < 1) return 'Hace ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'Hace ${diff.inHours} h';
    return 'Hace ${diff.inDays} días';
  }

  Future<void> _openComposer(String schoolId) async {
    final result = await showModalBottomSheet<_PostDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _PostComposerSheet(),
    );
    if (result == null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _creating = true);
    try {
      final now = Timestamp.now();
      await FirebaseFirestore.instance.collection('schools/$schoolId/posts').add({
        'module': 'busco_ofrezco',
        'type': result.type,
        'category': result.category,
        'title': result.title,
        'body': result.body,
        'authorUid': uid,
        // Rules validate createdAt as timestamp.
        'createdAt': now,
        'status': 'active',
        'reportsCount': 0,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Publicación creada.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo publicar: $e')));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(schoolIdProvider).valueOrNull;
    if (schoolId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final posts = FirebaseFirestore.instance
        .collection('schools/$schoolId/posts')
        .orderBy('createdAt', descending: true)
        .limit(120)
        .snapshots();
    final users =
        FirebaseFirestore.instance.collection('schools/$schoolId/users').snapshots();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Busco / Ofrezco',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Pide ayuda o comparte recursos con otras familias del colegio.',
          style:
              Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
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
          onPressed: _creating ? null : () => _openComposer(schoolId),
          icon: const Icon(Icons.add),
          label: Text(_creating ? 'Publicando...' : 'Nueva publicación'),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: users,
          builder: (context, usersSnapshot) {
            final userNames = {
              for (final userDoc in usersSnapshot.data?.docs ?? const [])
                userDoc.id: ((userDoc.data()['displayName'] as String?) ?? '').trim(),
            };

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: posts,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  final message = snapshot.error.toString();
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        message.contains('failed-precondition')
                            ? 'No se pudieron cargar publicaciones por configuración de consulta. Ya se aplicó un fallback; recarga la página.'
                            : 'No se pudieron cargar publicaciones: $message',
                      ),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final docs = (snapshot.data?.docs ?? const []).where((doc) {
                  final data = doc.data();
                  return data['module'] == 'busco_ofrezco' && data['status'] == 'active';
                }).toList();

                if (docs.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Text('Aún no hay publicaciones activas. Crea la primera.'),
                    ),
                  );
                }

                return Column(
                  children: docs.map((doc) {
                    final data = doc.data();
                    final type = (data['type'] as String? ?? 'post').toUpperCase();
                    final category = (data['category'] as String? ?? 'general');
                    final title = (data['title'] as String? ?? '').trim();
                    final body = (data['body'] as String? ?? '').trim();
                    final createdAt = data['createdAt'] as Timestamp?;
                    final authorUid = (data['authorUid'] as String? ?? '').trim();
                    final authorName = (userNames[authorUid] ?? '').trim();
                    final canContact =
                        authorUid.isNotEmpty && authorUid != FirebaseAuth.instance.currentUser?.uid;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                Chip(label: Text(type)),
                                Chip(label: Text(category)),
                                Chip(label: Text(_relativeDate(createdAt))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              title.isEmpty ? 'Sin título' : title,
                              style:
                                  Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              body.isEmpty ? 'Sin descripción' : body,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Publicado por: ${authorName.isNotEmpty ? authorName : 'Familia'}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton.icon(
                                onPressed: canContact
                                    ? () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Solicitar conversación'),
                                            content: const Text(
                                              'Se abrirá un chat 1:1 con el anunciante para continuar por privado.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(context).pop(false),
                                                child: const Text('Cancelar'),
                                              ),
                                              FilledButton(
                                                onPressed: () => Navigator.of(context).pop(true),
                                                child: const Text('Iniciar chat'),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirm != true) return;
                                        try {
                                          final chatId = await ref.read(chatServiceProvider).getOrCreateChat(
                                                schoolId: schoolId,
                                                peerUid: authorUid,
                                              );
                                          if (!context.mounted) return;
                                          context.push('/chat/$chatId');
                                        } catch (e) {
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('No se pudo abrir el chat: $e')),
                                          );
                                        }
                                      }
                                    : null,
                                icon: const Icon(Icons.chat_bubble_outline),
                                label: const Text('Contactar anunciante'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _PostDraft {
  const _PostDraft({
    required this.type,
    required this.category,
    required this.title,
    required this.body,
  });

  final String type;
  final String category;
  final String title;
  final String body;
}

class _PostComposerSheet extends StatefulWidget {
  const _PostComposerSheet();

  @override
  State<_PostComposerSheet> createState() => _PostComposerSheetState();
}

class _PostComposerSheetState extends State<_PostComposerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _category = TextEditingController(text: 'general');
  String _type = 'busco';

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _category.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Nueva publicación',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(value: 'busco', child: Text('Busco')),
                  DropdownMenuItem(value: 'ofrezco', child: Text('Ofrezco')),
                ],
                onChanged: (value) => setState(() => _type = value ?? 'busco'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _category,
                decoration: const InputDecoration(labelText: 'Categoría'),
                validator: (value) => (value ?? '').trim().isEmpty ? 'Introduce categoría.' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: (value) => (value ?? '').trim().length < 4 ? 'Título muy corto.' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _body,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Detalle'),
                validator: (value) => (value ?? '').trim().length < 8 ? 'Describe un poco más.' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) return;
                        Navigator.of(context).pop(
                          _PostDraft(
                            type: _type,
                            category: _category.text.trim(),
                            title: _title.text.trim(),
                            body: _body.text.trim(),
                          ),
                        );
                      },
                      child: const Text('Publicar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
