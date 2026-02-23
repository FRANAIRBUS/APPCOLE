import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_provider.dart';
import '../posts/module_feed.dart';
import '../../services/chat_service.dart';

class TalentoScreen extends ConsumerWidget {
  const TalentoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolId = ref.watch(schoolIdProvider).valueOrNull;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Talento del Cole'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Profesionales'),
              Tab(text: 'Anuncios'),
            ],
          ),
        ),
        body: (schoolId == null || uid == null)
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _ProfessionalsTab(schoolId: schoolId, myUid: uid),
                  _TalentoPostsTab(schoolId: schoolId),
                ],
              ),
      ),
    );
  }
}

class _TalentoPostsTab extends StatelessWidget {
  const _TalentoPostsTab({required this.schoolId});

  final String schoolId;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ModuleFeed(
          schoolId: schoolId,
          module: 'talento',
          emptyHint: 'Publica un anuncio (servicios, clases, oficios, etc.).',
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () => showPostComposerBottomSheet(
              context: context,
              schoolId: schoolId,
              module: 'talento',
              defaultType: 'ofrezco',
              allowedTypes: const ['ofrezco', 'busco'],
              titleHint: 'Nuevo anuncio',
            ),
            icon: const Icon(Icons.add),
            label: const Text('Nuevo'),
          ),
        ),
      ],
    );
  }
}

class _ProfessionalsTab extends StatefulWidget {
  const _ProfessionalsTab({required this.schoolId, required this.myUid});

  final String schoolId;
  final String myUid;

  @override
  State<_ProfessionalsTab> createState() => _ProfessionalsTabState();
}

class _ProfessionalsTabState extends State<_ProfessionalsTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('schools/${widget.schoolId}/users')
        .orderBy('displayName')
        .limit(200)
        .snapshots();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Buscar por nombre o profesión',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final docs = snapshot.data?.docs ?? const [];
              final people = docs
                  .where((d) {
                    if (d.id == widget.myUid) return false;
                    final prof = (d.data()['professional'] as String?)?.trim() ?? '';
                    return prof.isNotEmpty;
                  })
                  .where((d) {
                    if (_query.isEmpty) return true;
                    final name = (d.data()['displayName'] as String?)?.toLowerCase() ?? '';
                    final prof = (d.data()['professional'] as String?)?.toLowerCase() ?? '';
                    return name.contains(_query) || prof.contains(_query);
                  })
                  .toList();

              if (people.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Aún no hay profesionales publicados. Edita tu perfil y añade tu profesión.'),
                  ),
                );
              }

              Future<void> openChat(String peerUid) async {
                try {
                  final chatId = await ChatService(FirebaseFunctions.instance).getOrCreateChat(
                    schoolId: widget.schoolId,
                    peerUid: peerUid,
                  );
                  if (context.mounted) context.go('/chat/$chatId');
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('No se pudo abrir el chat: $e')),
                  );
                }
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: people.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final d = people[index];
                  final data = d.data();
                  final name = (data['displayName'] as String?)?.trim();
                  final professional = (data['professional'] as String?)?.trim() ?? '';

                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(name?.isNotEmpty == true ? name! : 'Familia'),
                      subtitle: Text(professional),
                      trailing: FilledButton(
                        onPressed: () => openChat(d.id),
                        child: const Text('Mensaje'),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
