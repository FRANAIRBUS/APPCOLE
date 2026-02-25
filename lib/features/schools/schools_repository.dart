import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/school.dart';
import '../../utils/text_normalizer.dart';

class SchoolsRepository {
  SchoolsRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _schools =>
      _firestore.collection('colegios');

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _firestore.collection('users').doc(uid);

  Future<DocumentSnapshot<Map<String, dynamic>>> _resolveCatalogSchoolDoc(
    School school,
  ) async {
    final direct = await _schools.doc(school.codigoCentro).get();
    if (direct.exists) return direct;

    final byCode = await _schools
        .where('codigoCentro', isEqualTo: school.codigoCentro)
        .limit(1)
        .get();
    if (byCode.docs.isNotEmpty) {
      return byCode.docs.first;
    }

    throw StateError('No se encontró el colegio seleccionado en el catálogo.');
  }

  Future<List<String>> searchProvinces({
    required String prefix,
    int limit = 20,
  }) async {
    final normalized = normalizeForSearch(prefix);
    Query<Map<String, dynamic>> query = _schools
        .where('activo', isEqualTo: true)
        .orderBy('provincia_normalizada');

    if (normalized.isNotEmpty) {
      query = query.startAt([normalized]).endAt(['$normalized\uf8ff']);
    }

    final snap = await query.limit(limit).get();
    final unique = <String>{};
    for (final doc in snap.docs) {
      final value = (doc.data()['provincia'] as String? ?? '').trim();
      if (value.isNotEmpty) unique.add(value);
    }
    return unique.toList()..sort();
  }

  Future<List<String>> searchLocalities({
    required String province,
    required String prefix,
    int limit = 20,
  }) async {
    final provinceNormalized = normalizeForSearch(province);
    if (provinceNormalized.isEmpty) return const [];

    final normalized = normalizeForSearch(prefix);
    Query<Map<String, dynamic>> query = _schools
        .where('activo', isEqualTo: true)
        .where('provincia_normalizada', isEqualTo: provinceNormalized)
        .orderBy('localidad_normalizada');

    if (normalized.isNotEmpty) {
      query = query.startAt([normalized]).endAt(['$normalized\uf8ff']);
    }

    final snap = await query.limit(limit).get();
    final unique = <String>{};
    for (final doc in snap.docs) {
      final value = (doc.data()['localidad'] as String? ?? '').trim();
      if (value.isNotEmpty) unique.add(value);
    }
    return unique.toList()..sort();
  }

  Future<List<School>> searchSchools({
    required String province,
    required String locality,
    required String namePrefix,
    int limit = 10,
  }) async {
    final provinceNormalized = normalizeForSearch(province);
    final localityNormalized = normalizeForSearch(locality);
    if (provinceNormalized.isEmpty || localityNormalized.isEmpty) {
      return const [];
    }

    final normalizedName = normalizeForSearch(namePrefix);
    final baseQuery = _schools
        .where('activo', isEqualTo: true)
        .where('provincia_normalizada', isEqualTo: provinceNormalized)
        .where('localidad_normalizada', isEqualTo: localityNormalized)
        .orderBy('nombre_normalizado');

    if (normalizedName.isEmpty) {
      final snap = await baseQuery.limit(limit).get();
      return snap.docs.map(School.fromDoc).toList();
    }

    final broadLimit = limit < 20 ? 80 : limit * 4;
    final snap = await baseQuery.limit(broadLimit).get();
    final tokens =
        normalizedName.split(' ').where((t) => t.isNotEmpty).toList();

    final ranked = snap.docs
        .map(School.fromDoc)
        .map((school) {
          final name = school.nombreNormalizado;
          final startsWith = name.startsWith(normalizedName);
          final containsAllTokens = tokens.every(name.contains);
          final containsPhrase = name.contains(normalizedName);
          if (!startsWith && !containsAllTokens && !containsPhrase) {
            return null;
          }

          final score = startsWith ? 0 : (containsPhrase ? 1 : 2);
          return (school: school, score: score);
        })
        .whereType<({School school, int score})>()
        .toList()
      ..sort((a, b) {
        final byScore = a.score.compareTo(b.score);
        if (byScore != 0) return byScore;
        return a.school.nombreNormalizado.compareTo(b.school.nombreNormalizado);
      });

    return ranked.take(limit).map((entry) => entry.school).toList();
  }

  Future<void> saveUserSchoolSelection({
    required String uid,
    required School school,
    String? displayName,
    String? photoUrl,
  }) async {
    final catalogDoc = await _resolveCatalogSchoolDoc(school);
    final catalog = catalogDoc.data() ?? const <String, dynamic>{};
    final schoolId = catalogDoc.id;
    final rawSchoolName =
        catalog['nombre'] is String ? catalog['nombre'] as String : school.nombre;
    final rawSchoolLocalidad = catalog['localidad'] is String
        ? catalog['localidad'] as String
        : school.localidad;
    final rawSchoolProvincia = catalog['provincia'] is String
        ? catalog['provincia'] as String
        : school.provincia;

    if (rawSchoolName.trim().isEmpty ||
        rawSchoolLocalidad.trim().isEmpty ||
        rawSchoolProvincia.trim().isEmpty) {
      throw StateError('El catálogo del colegio está incompleto.');
    }

    final batch = _firestore.batch();
    batch.set(
      _userRef(uid),
      {
        'schoolId': schoolId,
        'schoolName': rawSchoolName,
        'schoolLocalidad': rawSchoolLocalidad,
        'schoolProvincia': rawSchoolProvincia,
        'displayName':
            (displayName ?? '').trim().isEmpty ? null : displayName!.trim(),
        'photoUrl': (photoUrl ?? '').trim().isEmpty ? null : photoUrl!.trim(),
        'lastActiveAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(
      _firestore.doc('schools/$schoolId/users/$uid'),
      {
        'displayName': (displayName ?? '').trim().isEmpty
            ? 'Familia'
            : displayName!.trim(),
        'photoUrl': (photoUrl ?? '').trim().isEmpty ? null : photoUrl!.trim(),
        'role': 'parent',
        'children': const [],
        'classIds': const [],
        'createdAt': FieldValue.serverTimestamp(),
        'lastActiveAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<RootSchoolsPage> listSchoolsForRoot({
    String namePrefix = '',
    String provincePrefix = '',
    String localityPrefix = '',
    bool? activo,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 20,
  }) async {
    final normalizedName = normalizeForSearch(namePrefix);
    final normalizedProvince = normalizeForSearch(provincePrefix);
    final normalizedLocality = normalizeForSearch(localityPrefix);

    Query<Map<String, dynamic>> query = _schools;
    if (activo != null) {
      query = query.where('activo', isEqualTo: activo);
    }

    String? prefixField;
    String prefixValue = '';
    if (normalizedName.isNotEmpty) {
      prefixField = 'nombre_normalizado';
      prefixValue = normalizedName;
    } else if (normalizedLocality.isNotEmpty) {
      prefixField = 'localidad_normalizada';
      prefixValue = normalizedLocality;
    } else if (normalizedProvince.isNotEmpty) {
      prefixField = 'provincia_normalizada';
      prefixValue = normalizedProvince;
    }

    final orderField = prefixField ?? 'nombre_normalizado';
    query = query.orderBy(orderField).orderBy(FieldPath.documentId);

    if (prefixField != null) {
      query = query.startAt([prefixValue]).endAt(['$prefixValue\uf8ff']);
    }

    if (startAfter != null) {
      final orderValue =
          (startAfter.data()?[orderField] as String? ?? '').trim();
      query = query.startAfter([orderValue, startAfter.id]);
    }

    final snap = await query.limit(limit).get();
    var items = snap.docs.map(School.fromDoc).toList();

    if (normalizedName.isNotEmpty &&
        normalizedLocality.isNotEmpty &&
        prefixField != 'localidad_normalizada') {
      items = items
          .where((school) =>
              school.localidadNormalizada.startsWith(normalizedLocality))
          .toList();
    }
    if (normalizedName.isNotEmpty &&
        normalizedProvince.isNotEmpty &&
        prefixField != 'provincia_normalizada') {
      items = items
          .where((school) =>
              school.provinciaNormalizada.startsWith(normalizedProvince))
          .toList();
    }
    if (normalizedLocality.isNotEmpty &&
        normalizedProvince.isNotEmpty &&
        prefixField != 'provincia_normalizada') {
      items = items
          .where((school) =>
              school.provinciaNormalizada.startsWith(normalizedProvince))
          .toList();
    }

    return RootSchoolsPage(
      items: items,
      hasMore: snap.docs.length == limit,
      lastDoc: snap.docs.isEmpty ? null : snap.docs.last,
    );
  }

  Future<void> createSchool({
    required String updatedBy,
    required SchoolUpsertInput input,
  }) async {
    final codigoCentro = input.codigoCentro.trim();
    if (codigoCentro.isEmpty) {
      throw StateError('El codigoCentro es obligatorio.');
    }

    final payload = _buildSchoolPayload(input: input, updatedBy: updatedBy);
    final ref = _schools.doc(codigoCentro);

    await _firestore.runTransaction((tx) async {
      final existing = await tx.get(ref);
      if (existing.exists) {
        throw StateError('Ya existe un colegio con ese codigoCentro.');
      }
      tx.set(ref, payload);
    });
  }

  Future<void> updateSchool({
    required String updatedBy,
    required SchoolUpsertInput input,
  }) async {
    final codigoCentro = input.codigoCentro.trim();
    if (codigoCentro.isEmpty) {
      throw StateError('El codigoCentro es obligatorio.');
    }

    final payload = _buildSchoolPayload(input: input, updatedBy: updatedBy);
    await _schools.doc(codigoCentro).set(payload, SetOptions(merge: true));
  }

  Future<void> setSchoolActive({
    required String codigoCentro,
    required bool active,
    required String updatedBy,
  }) async {
    await _schools.doc(codigoCentro.trim()).set(
      {
        'activo': active,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
      },
      SetOptions(merge: true),
    );
  }

  Map<String, dynamic> _buildSchoolPayload({
    required SchoolUpsertInput input,
    required String updatedBy,
  }) {
    final codigoCentro = input.codigoCentro.trim();
    final nombre = input.nombre.trim();
    final localidad = input.localidad.trim();
    final provincia = input.provincia.trim();

    if (nombre.isEmpty || localidad.isEmpty || provincia.isEmpty) {
      throw StateError('Nombre, localidad y provincia son obligatorios.');
    }

    return {
      'codigoCentro': codigoCentro,
      'nombre': nombre,
      'localidad': localidad,
      'provincia': provincia,
      'nombre_normalizado': normalizeForSearch(nombre),
      'localidad_normalizada': normalizeForSearch(localidad),
      'provincia_normalizada': normalizeForSearch(provincia),
      'activo': input.activo,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    };
  }
}
