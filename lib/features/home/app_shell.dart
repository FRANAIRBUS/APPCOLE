import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/session_provider.dart';
import '../../widgets/app_logo.dart';

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
      final lastMessageMs =
          lastMessageAt is Timestamp ? lastMessageAt.millisecondsSinceEpoch : 0;
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

  final userRef = FirebaseFirestore.instance.doc('schools/$schoolId/users/$uid');

  final controller = StreamController<int>();
  Timestamp since = Timestamp.fromMillisecondsSinceEpoch(0);

  StreamSubscription? userSub;
  StreamSubscription? eventsSub;

  void subscribeEvents() {
    eventsSub?.cancel();
    final q = FirebaseFirestore.instance
        .collection('schools/$schoolId/events')
        .where('status', isEqualTo: 'active')
        .where('createdAt', isGreaterThan: since)
        .orderBy('createdAt', descending: true)
        .limit(100);

    eventsSub = q.snapshots().listen(
      (snapshot) => controller.add(snapshot.size),
      onError: (_) => controller.add(0),
    );
  }

  userSub = userRef.snapshots().listen(
    (snap) {
      final data = snap.data();
      final lastViewed = data?['eventsLastViewedAt'] as Timestamp?;
      since = lastViewed ?? Timestamp.fromMillisecondsSinceEpoch(0);
      subscribeEvents();
    },
    onError: (_) => controller.add(0),
  );

  subscribeEvents();

  ref.onDispose(() {
    userSub?.cancel();
    eventsSub?.cancel();
    controller.close();
  });

  return controller.stream;
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

  static const _expandedHeaderHeight = 252.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = navigationShell.currentIndex.clamp(0, _titles.length - 1);
    final unreadChats = ref.watch(unreadChatsCountProvider).valueOrNull ?? 0;
    final unreadEvents = ref.watch(unreadEventsCountProvider).valueOrNull ?? 0;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bg = theme.scaffoldBackgroundColor;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              pinned: true,
              expandedHeight: _expandedHeaderHeight,
              automaticallyImplyLeading: false,
              backgroundColor: bg,
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Column(
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: cs.outlineVariant),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(kPersistentLogoCardPadding),
                            child: AppLogo(
                              width: 400,
                              height: kPersistentLogoImageHeight,
                              borderRadius: 10,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(52),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _titles[current],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _subtitles[current],
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ];
        },
        body: navigationShell,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        left: false,
        right: false,
        maintainBottomViewPadding: true,
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) => navigationShell.goBranch(index),
          destinations: [
            const NavigationDestination(icon: Icon(Icons.swap_horiz), label: 'Busco'),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: unreadEvents > 0,
                label: Text(unreadEvents > 99 ? '99+' : '$unreadEvents'),
                child: const Icon(Icons.event),
              ),
              label: 'Padres',
            ),
            const NavigationDestination(icon: Icon(Icons.groups), label: 'Mi Clase'),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: unreadChats > 0,
                label: Text(unreadChats > 99 ? '99+' : '$unreadChats'),
                child: const Icon(Icons.chat_bubble_outline),
              ),
              label: 'Chat',
            ),
            const NavigationDestination(icon: Icon(Icons.person_outline), label: 'Perfil'),
          ],
        ),
      ),
    );
  }
}
