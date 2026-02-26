import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/session_provider.dart';

final unreadChatsCountProvider = StreamProvider<int>((ref) {
  final schoolId = ref.watch(schoolIdProvider).valueOrNull;
  final uid = FirebaseAuth.instance.currentUser?.uid;

  if (schoolId == null || uid == null) {
    return Stream<int>.value(0);
  }

  return FirebaseFirestore.instance
      .collection('schools/$schoolId/chats')
      .where('participants', arrayContains: uid)
      .snapshots()
      .map((snapshot) {
    int unread = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final lastSender = (data['lastMessageSenderUid'] as String?)?.trim() ?? '';
      if (lastSender.isEmpty || lastSender == uid) continue;

      final lastMessageAt = data['lastMessageAt'];
      final lastMessageMs = lastMessageAt is Timestamp ? lastMessageAt.millisecondsSinceEpoch : 0;
      if (lastMessageMs <= 0) continue;

      final lastReadMap = data['lastReadAt'];
      final myRead = (lastReadMap is Map<String, dynamic>) ? lastReadMap[uid] : null;
      final myReadMs = myRead is Timestamp ? myRead.millisecondsSinceEpoch : 0;
      if (myReadMs < lastMessageMs) unread++;
    }
    return unread;
  });
});

final unreadEventsCountProvider = StreamProvider<int>((ref) {
  final schoolId = ref.watch(schoolIdProvider).valueOrNull;
  final uid = FirebaseAuth.instance.currentUser?.uid;

  if (schoolId == null || uid == null) {
    return Stream<int>.value(0);
  }

  final userDocStream = FirebaseFirestore.instance
      .doc('schools/$schoolId/users/$uid')
      .snapshots();

  return userDocStream.asyncExpand((userSnap) {
    final data = userSnap.data() ?? const <String, dynamic>{};
    final lastViewed = data['eventsLastViewedAt'];
    final lastViewedTs = (lastViewed is Timestamp)
        ? lastViewed
        : Timestamp.fromMillisecondsSinceEpoch(0);

    return FirebaseFirestore.instance
        .collection('schools/$schoolId/events')
        .where('status', isEqualTo: 'active')
        .where('createdAt', isGreaterThan: lastViewedTs)
        .orderBy('createdAt', descending: true)
        .limit(99)
        .snapshots()
        .map((snapshot) => snapshot.size);
  });
});

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _titles = [
    'Busco / Ofrezco',
    'Entre Padres',
    'Mi Clase',
    'Chat',
    'Perfil',
  ];

  static const _subtitles = [
    'Ayuda y recursos entre familias.',
    'Eventos y coordinación.',
    'Familias con clases en común.',
    'Mensajería interna privada.',
    'Cuenta, privacidad y seguridad.',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = navigationShell.currentIndex.clamp(0, _titles.length - 1);
    final unreadChats = ref.watch(unreadChatsCountProvider).valueOrNull ?? 0;
    final unreadEvents = ref.watch(unreadEventsCountProvider).valueOrNull ?? 0;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Text(
          _titles[current],
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                _subtitles[current],
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ),
        ),
      ),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(index),
        destinations: [
          NavigationDestination(
              icon: Icon(Icons.swap_horiz), label: 'Busco'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unreadEvents > 0,
              label: Text(unreadEvents > 99 ? '99+' : '$unreadEvents'),
              child: const Icon(Icons.event),
            ),
            label: 'Padres',
          ),
          NavigationDestination(icon: Icon(Icons.groups), label: 'Mi Clase'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unreadChats > 0,
              label: Text(unreadChats > 99 ? '99+' : '$unreadChats'),
              child: const Icon(Icons.chat_bubble_outline),
            ),
            label: 'Chat',
          ),
          NavigationDestination(
              icon: Icon(Icons.person_outline), label: 'Perfil'),
        ],
      ),
    );
  }
}
