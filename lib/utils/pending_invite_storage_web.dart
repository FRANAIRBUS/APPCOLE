// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

import 'pending_invite_storage.dart';

/// Web: usa sessionStorage para sobrevivir al redirect de Google Sign-In.
/// Evita dependencias (shared_preferences) y no rompe builds mobile.
class PendingInviteStorage {
  PendingInviteStorage._();

  static final PendingInviteStorage instance = PendingInviteStorage._();

  static const _key = 'cc_pending_invite_v1';

  PendingInvite? load() {
    final raw = html.window.sessionStorage[_key];
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      final schoolId = (map['schoolId'] as String? ?? '').trim();
      if (schoolId.isEmpty) return null;
      final referrerUid = (map['referrerUid'] as String?)?.trim();
      return PendingInvite(
        schoolId: schoolId,
        referrerUid: (referrerUid?.isNotEmpty == true) ? referrerUid : null,
      );
    } catch (_) {
      return null;
    }
  }

  void save(PendingInvite invite) {
    final schoolId = invite.schoolId.trim();
    if (schoolId.isEmpty) return;
    final payload = <String, dynamic>{
      'schoolId': schoolId,
      if (invite.referrerUid != null && invite.referrerUid!.trim().isNotEmpty)
        'referrerUid': invite.referrerUid!.trim(),
    };
    html.window.sessionStorage[_key] = jsonEncode(payload);
  }

  void clear() {
    html.window.sessionStorage.remove(_key);
  }
}
