import 'package:cloud_firestore/cloud_firestore.dart';

class School {
  const School({
    required this.codigoCentro,
    required this.nombre,
    required this.localidad,
    required this.provincia,
    required this.nombreNormalizado,
    required this.localidadNormalizada,
    required this.provinciaNormalizada,
    required this.activo,
    this.updatedAt,
    this.updatedBy,
  });

  final String codigoCentro;
  final String nombre;
  final String localidad;
  final String provincia;
  final String nombreNormalizado;
  final String localidadNormalizada;
  final String provinciaNormalizada;
  final bool activo;
  final Timestamp? updatedAt;
  final String? updatedBy;

  factory School.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return School(
      codigoCentro: (data['codigoCentro'] as String? ?? doc.id).trim(),
      nombre: (data['nombre'] as String? ?? '').trim(),
      localidad: (data['localidad'] as String? ?? '').trim(),
      provincia: (data['provincia'] as String? ?? '').trim(),
      nombreNormalizado: (data['nombre_normalizado'] as String? ?? '').trim(),
      localidadNormalizada: (data['localidad_normalizada'] as String? ?? '').trim(),
      provinciaNormalizada: (data['provincia_normalizada'] as String? ?? '').trim(),
      activo: data['activo'] as bool? ?? true,
      updatedAt: data['updatedAt'] as Timestamp?,
      updatedBy: (data['updatedBy'] as String?)?.trim(),
    );
  }
}

class SchoolUpsertInput {
  const SchoolUpsertInput({
    required this.codigoCentro,
    required this.nombre,
    required this.localidad,
    required this.provincia,
    this.activo = true,
  });

  final String codigoCentro;
  final String nombre;
  final String localidad;
  final String provincia;
  final bool activo;
}

class RootSchoolsPage {
  const RootSchoolsPage({
    required this.items,
    required this.hasMore,
    this.lastDoc,
  });

  final List<School> items;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
}
