import 'pending_invite_storage.dart';

/// Fallback no-web: almacenamiento en memoria. Suficiente porque no hay reload
/// completo en el flujo de login nativo.
class PendingInviteStorage {
  PendingInviteStorage._();

  static final PendingInviteStorage instance = PendingInviteStorage._();

  PendingInvite? _cache;

  PendingInvite? load() => _cache;

  void save(PendingInvite invite) {
    final schoolId = invite.schoolId.trim();
    if (schoolId.isEmpty) return;
    _cache = PendingInvite(schoolId: schoolId, referrerUid: invite.referrerUid);
  }

  void clear() {
    _cache = null;
  }
}
