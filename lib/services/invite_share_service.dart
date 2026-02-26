import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../utils/text_normalizer.dart';

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

  Future<String> _resolveInviteSchoolIdForLink({
    required String schoolId,
    required User user,
  }) async {
    final raw = schoolId.trim();
    if (raw.isEmpty) {
      throw StateError('No hay colegio válido para generar la invitación.');
    }

    final colegios = _firestore.collection('colegios');

    final direct = await colegios.doc(raw).get();
    if (direct.exists) return direct.id;

    final byCode = await colegios.where('codigoCentro', isEqualTo: raw).limit(1).get();
    if (byCode.docs.isNotEmpty) return byCode.docs.first.id;

    final legacySchoolDoc = await _firestore.collection('schools').doc(raw).get();
    final legacyData = legacySchoolDoc.data() ?? const <String, dynamic>{};
    final legacyCode = (legacyData['codigoCentro'] as String? ?? '').trim();
    if (legacyCode.isNotEmpty) {
      final byLegacyCode = await colegios.doc(legacyCode).get();
      if (byLegacyCode.exists) return byLegacyCode.id;
    }

    final globalData =
        (await _firestore.collection('users').doc(user.uid).get()).data() ?? const <String, dynamic>{};
    final schoolName = normalizeForSearch((globalData['schoolName'] as String? ?? '').trim());
    final schoolLocalidad = normalizeForSearch((globalData['schoolLocalidad'] as String? ?? '').trim());
    final schoolProvincia = normalizeForSearch((globalData['schoolProvincia'] as String? ?? '').trim());

    if (schoolName.isNotEmpty && schoolLocalidad.isNotEmpty && schoolProvincia.isNotEmpty) {
      final bySnapshot = await colegios
          .where('activo', isEqualTo: true)
          .where('nombre_normalizado', isEqualTo: schoolName)
          .where('localidad_normalizada', isEqualTo: schoolLocalidad)
          .where('provincia_normalizada', isEqualTo: schoolProvincia)
          .limit(1)
          .get();
      if (bySnapshot.docs.isNotEmpty) return bySnapshot.docs.first.id;
    }

    return raw;
  }

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

    final inviteSchoolId = await _resolveInviteSchoolIdForLink(
      schoolId: schoolId,
      user: user,
    );

    final link = Uri.https('coleconecta.app', '/invite', {
      'schoolId': inviteSchoolId,
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
