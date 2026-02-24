import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

final inviteShareServiceProvider = Provider<InviteShareService>(
  (ref) => InviteShareService(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
  ),
);

class InviteShareService {
  InviteShareService({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<String> shareInviteCard({
    required String schoolId,
    required String source,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No hay sesión activa para compartir invitación.');
    }

    final userSnap = await _firestore.doc('schools/$schoolId/users/${user.uid}').get();
    final data = userSnap.data() ?? <String, dynamic>{};

    final displayName =
        (data['displayName'] as String?)?.trim().isNotEmpty == true ? (data['displayName'] as String).trim() : (user.displayName?.trim().isNotEmpty == true ? user.displayName!.trim() : (user.email ?? 'Una familia del cole'));

    final classIds = ((data['classIds'] as List?) ?? const [])
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();

    final link = Uri.https('coleconecta.app', '/invite', {
      'schoolId': schoolId,
      'referrerUid': user.uid,
      'source': source,
    }).toString();

    final classesSummary = classIds.isEmpty
        ? ''
        : '\nReferencia de clase/grupo: ${classIds.take(3).join(', ')}${classIds.length > 3 ? ' +' : ''}';

    final message = '''
Tarjeta presentación · ColeConecta

Hola, soy $displayName.
Te invito a unirte a ColeConecta y vincularte a nuestro colegio.$classesSummary

Enlace directo al colegio:
$link
''';

    final inviteCard = message.trim();
    await Clipboard.setData(ClipboardData(text: inviteCard));
    return inviteCard;
  }
}
