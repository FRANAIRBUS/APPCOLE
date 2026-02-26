import 'pending_invite_storage_stub.dart'
    if (dart.library.html) 'pending_invite_storage_web.dart';

/// Persistencia ligera de invitación para sobrevivir al redirect de Google
/// en Safari/iOS (web). En mobile/desktop normalmente no hace falta.
///
/// - Web: sessionStorage (se limpia al cerrar la pestaña)
/// - No-web: stub in-memory
class PendingInvite {
  const PendingInvite({required this.schoolId, this.referrerUid});

  final String schoolId;
  final String? referrerUid;
}

PendingInvite? loadPendingInvite() => PendingInviteStorage.instance.load();

void savePendingInvite(PendingInvite invite) =>
    PendingInviteStorage.instance.save(invite);

void clearPendingInvite() => PendingInviteStorage.instance.clear();
