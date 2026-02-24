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

  Future<List<String>> searchProvinces({
    required String prefix,
    int limit = 20,
  }) async {
    final normalized = normalizeForSearch(prefix);
    Query<Map<String, dynamic>> query = _schools
        .where('activo', isEqualTo: true)
        .orderBy('provincia_normalizada');

    if (normalized.isNotEmpty) {
      query = query
          .startAt([normalized]).endAt(['$normalized\uf8ff']);
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
      query = query
          .startAt([normalized]).endAt(['$normalized\uf8ff']);
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
    Query<Map<String, dynamic>> query = _schools
        .where('activo', isEqualTo: true)
        .where('provincia_normalizada', isEqualTo: provinceNormalized)
        .where('localidad_normalizada', isEqualTo: localityNormalized)
        .orderBy('nombre_normalizado');

    if (normalizedName.isNotEmpty) {
      query = query
          .startAt([normalizedName]).endAt(['$normalizedName\uf8ff']);
    }

    final snap = await query.limit(limit).get();
    return snap.docs.map(School.fromDoc).toList();
  }

  Future<void> saveUserSchoolSelection({
    required String uid,
    required School school,
    String? displayName,
    String? photoUrl,
  }) async {
    final batch = _firestore.batch();
    batch.set(
      _userRef(uid),
      {
        'schoolId': school.codigoCentro,
        'schoolName': school.nombre,
        'schoolLocalidad': school.localidad,
        'schoolProvincia': school.provincia,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(
      _firestore.doc('schools/${school.codigoCentro}/users/$uid'),
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
      query = query
          .startAt([prefixValue]).endAt(['$prefixValue\uf8ff']);
    }

    if (startAfter != null) {
      final orderValue = (startAfter.data()?[orderField] as String? ?? '').trim();
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
