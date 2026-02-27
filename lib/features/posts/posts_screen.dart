import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  static const _quickLinks = [
    _QuickLinkItem(label: 'Talento', icon: Icons.lightbulb_outline, route: '/talento'),
    _QuickLinkItem(label: 'BiblioCircular', icon: Icons.menu_book_outlined, route: '/biblio'),
    _QuickLinkItem(label: 'Veteranos', icon: Icons.groups_2_outlined, route: '/veteranos'),
    _QuickLinkItem(label: 'Primer Día', icon: Icons.celebration_outlined, route: '/bienvenida'),
    _QuickLinkItem(label: 'Red de Confianza', icon: Icons.verified_user_outlined, route: '/confianza'),
  ];

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
        'website': result.website,
        'linkedin': result.linkedin,
        'instagram': result.instagram,
        'facebook': result.facebook,
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

  Future<void> _openEditor(String schoolId, String postId, Map<String, dynamic> data) async {
    final result = await showModalBottomSheet<_PostDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PostComposerSheet(initialData: data),
    );
    if (result == null) return;
    try {
      await FirebaseFirestore.instance.doc('schools/$schoolId/posts/$postId').update({
        'type': result.type,
        'category': result.category,
        'title': result.title,
        'body': result.body,
        'website': result.website,
        'linkedin': result.linkedin,
        'instagram': result.instagram,
        'facebook': result.facebook,
        'updatedAt': Timestamp.now(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Publicación actualizada.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo actualizar: $e')));
    }
  }

  Future<void> _deletePost(String schoolId, String postId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar publicación'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance.doc('schools/$schoolId/posts/$postId').delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Publicación eliminada.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
    }
  }

  Future<void> _openPostDetails({
    required String schoolId,
    required String postId,
    required Map<String, dynamic> data,
    required String authorName,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PostDetailsSheet(
        schoolId: schoolId,
        postId: postId,
        data: data,
        authorName: authorName,
        relativeDate: _relativeDate,
        onEdit: () => _openEditor(schoolId, postId, data),
        onDelete: () => _deletePost(schoolId, postId),
      ),
    );
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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _quickLinks
                  .map(
                    (item) => _QuickAccessTile(
                      item: item,
                      onTap: () => context.push(item.route),
                    ),
                  )
                  .toList(),
            ),
          ),
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
                    final postId = doc.id;
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
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _openPostDetails(
                          schoolId: schoolId,
                          postId: postId,
                          data: data,
                          authorName: authorName,
                        ),
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
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
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
                              const SizedBox(height: 4),
                              Text(
                                'Toca para ver más detalles y valorar.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
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

class _QuickLinkItem {
  const _QuickLinkItem({required this.label, required this.icon, required this.route});

  final String label;
  final IconData icon;
  final String route;
}

class _QuickAccessTile extends StatelessWidget {
  const _QuickAccessTile({required this.item, required this.onTap});

  final _QuickLinkItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 148,
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(item.icon, size: 18, color: scheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PostDraft {
  const _PostDraft({
    required this.type,
    required this.category,
    required this.title,
    required this.body,
    required this.website,
    required this.linkedin,
    required this.instagram,
    required this.facebook,
  });

  final String type;
  final String category;
  final String title;
  final String body;
  final String website;
  final String linkedin;
  final String instagram;
  final String facebook;
}

class _PostComposerSheet extends StatefulWidget {
  const _PostComposerSheet({this.initialData});

  final Map<String, dynamic>? initialData;

  @override
  State<_PostComposerSheet> createState() => _PostComposerSheetState();
}

class _PostComposerSheetState extends State<_PostComposerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _category = TextEditingController(text: 'general');
  final _website = TextEditingController();
  final _linkedin = TextEditingController();
  final _instagram = TextEditingController();
  final _facebook = TextEditingController();
  String _type = 'busco';

  @override
  void initState() {
    super.initState();
    final initial = widget.initialData;
    if (initial == null) return;
    _type = (initial['type'] as String? ?? 'busco').trim();
    _category.text = (initial['category'] as String? ?? 'general').trim();
    _title.text = (initial['title'] as String? ?? '').trim();
    _body.text = (initial['body'] as String? ?? '').trim();
    _website.text = (initial['website'] as String? ?? '').trim();
    _linkedin.text = (initial['linkedin'] as String? ?? '').trim();
    _instagram.text = (initial['instagram'] as String? ?? '').trim();
    _facebook.text = (initial['facebook'] as String? ?? '').trim();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _category.dispose();
    _website.dispose();
    _linkedin.dispose();
    _instagram.dispose();
    _facebook.dispose();
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
                widget.initialData == null ? 'Nueva publicación' : 'Editar publicación',
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
              const SizedBox(height: 8),
              TextFormField(
                controller: _website,
                decoration: const InputDecoration(labelText: 'Web (opcional)'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _linkedin,
                decoration: const InputDecoration(labelText: 'LinkedIn (opcional)'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _instagram,
                decoration: const InputDecoration(labelText: 'Instagram (opcional)'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _facebook,
                decoration: const InputDecoration(labelText: 'Facebook (opcional)'),
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
                            website: _website.text.trim(),
                            linkedin: _linkedin.text.trim(),
                            instagram: _instagram.text.trim(),
                            facebook: _facebook.text.trim(),
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

class _PostDetailsSheet extends ConsumerWidget {
  const _PostDetailsSheet({
    required this.schoolId,
    required this.postId,
    required this.data,
    required this.authorName,
    required this.relativeDate,
    required this.onEdit,
    required this.onDelete,
  });

  final String schoolId;
  final String postId;
  final Map<String, dynamic> data;
  final String authorName;
  final String Function(Timestamp?) relativeDate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final authorUid = (data['authorUid'] as String? ?? '').trim();
    final isOwner = authorUid.isNotEmpty && authorUid == currentUid;
    final website = (data['website'] as String? ?? '').trim();
    final linkedin = (data['linkedin'] as String? ?? '').trim();
    final instagram = (data['instagram'] as String? ?? '').trim();
    final facebook = (data['facebook'] as String? ?? '').trim();
    final createdAt = data['createdAt'] as Timestamp?;

    final votesRef = FirebaseFirestore.instance
        .collection('schools/$schoolId/posts/$postId/votes')
        .snapshots();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return Material(
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (data['title'] as String? ?? 'Sin título').trim(),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (isOwner)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        Navigator.of(context).pop();
                        if (value == 'edit') onEdit();
                        if (value == 'delete') onDelete();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Editar')),
                        PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text((data['body'] as String? ?? 'Sin descripción').trim()),
              const SizedBox(height: 8),
              Text('Publicado por: ${authorName.isNotEmpty ? authorName : 'Familia'} · ${relativeDate(createdAt)}'),
              const Divider(height: 22),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _SocialLink(icon: Icons.public, label: 'Web', url: website),
                  _SocialLink(icon: Icons.business, label: 'LinkedIn', url: linkedin),
                  _SocialLink(icon: Icons.camera_alt_outlined, label: 'Instagram', url: instagram),
                  _SocialLink(icon: Icons.facebook, label: 'Facebook', url: facebook),
                ],
              ),
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: votesRef,
                builder: (context, snapshot) {
                  final votes = snapshot.data?.docs ?? const [];
                  var sum = 0;
                  var fail = 0;
                  for (final voteDoc in votes) {
                    final score = (voteDoc.data()['score'] as num?)?.toInt() ?? 0;
                    sum += score;
                    if (score <= 4) fail++;
                  }
                  final avg = votes.isEmpty ? 0 : sum / votes.length;

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Puntuación comunitaria', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 6),
                          Text('Media: ${avg.toStringAsFixed(1)} / 10 · Votos: ${votes.length}'),
                          Text('Suspensos (0-4): $fail'),
                          if (fail >= 5)
                            Text(
                              'Este contenido alcanza el umbral y ha sido marcado para revisión root.',
                              style: TextStyle(color: Theme.of(context).colorScheme.error),
                            ),
                          const SizedBox(height: 8),
                          _VoteButton(schoolId: schoolId, postId: postId),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              const Text('Campo de imagen: reservado para próxima iteración.'),
            ],
          ),
        );
      },
    );
  }
}

class _VoteButton extends StatefulWidget {
  const _VoteButton({required this.schoolId, required this.postId});

  final String schoolId;
  final String postId;

  @override
  State<_VoteButton> createState() => _VoteButtonState();
}

class _VoteButtonState extends State<_VoteButton> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: _saving
          ? null
          : () async {
            final messenger = ScaffoldMessenger.of(context);
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid == null) return;
              final controller = TextEditingController();
              final score = await showDialog<int>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Valorar publicación (0-10)'),
                  content: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'Ejemplo: 8'),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                    FilledButton(
                      onPressed: () {
                        final parsed = int.tryParse(controller.text.trim());
                        if (parsed == null || parsed < 0 || parsed > 10) return;
                        Navigator.of(context).pop(parsed);
                      },
                      child: const Text('Guardar'),
                    ),
                  ],
                ),
              );
              if (score == null) return;
              setState(() => _saving = true);
              try {
                final voteRef = FirebaseFirestore.instance
                    .doc('schools/${widget.schoolId}/posts/${widget.postId}/votes/$uid');
                await voteRef.set({
                  'uid': uid,
                  'score': score,
                  'updatedAt': Timestamp.now(),
                }, SetOptions(merge: true));

                if (score <= 4) {
                  await FirebaseFirestore.instance.doc('schools/${widget.schoolId}/reports/post_${widget.postId}_$uid').set({
                    'reporterUid': uid,
                    'targetPath': 'schools/${widget.schoolId}/posts/${widget.postId}',
                    'targetType': 'post',
                    'reason': 'Calificado como suspenso por la comunidad (0-4).',
                    'createdAt': Timestamp.now(),
                    'status': 'pending',
                  }, SetOptions(merge: true));
                }
                if (!mounted) return;
                messenger.showSnackBar(const SnackBar(content: Text('Gracias por tu valoración.')));
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(SnackBar(content: Text('No se pudo registrar el voto: $e')));
              } finally {
                if (mounted) setState(() => _saving = false);
              }
            },
      icon: const Icon(Icons.grade_outlined),
      label: Text(_saving ? 'Guardando...' : 'Valorar'),
    );
  }
}

class _SocialLink extends StatelessWidget {
  const _SocialLink({required this.icon, required this.label, required this.url});

  final IconData icon;
  final String label;
  final String url;

  String _normalizedUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    final hasScheme = trimmed.startsWith('http://') || trimmed.startsWith('https://');
    return hasScheme ? trimmed : 'https://$trimmed';
  }

  @override
  Widget build(BuildContext context) {
    final normalized = _normalizedUrl(url);
    final enabled = normalized.isNotEmpty;

    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(enabled ? label : '$label no configurado'),
      onPressed: !enabled
          ? null
          : () async {
              final messenger = ScaffoldMessenger.of(context); // capture before async work
              await Clipboard.setData(ClipboardData(text: normalized));
              messenger.showSnackBar(
                SnackBar(content: Text('Enlace copiado: $normalized')),
              );
            },
    );
  }
}
