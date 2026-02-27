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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadChats = ref.watch(unreadChatsCountProvider).valueOrNull ?? 0;
    final unreadEvents = ref.watch(unreadEventsCountProvider).valueOrNull ?? 0;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const AppLogo(
          width: 128,
          height: 36,
          borderRadius: 6,
          fit: BoxFit.contain,
        ),
      ),
      body: navigationShell,
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
