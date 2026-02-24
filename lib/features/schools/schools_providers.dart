import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_provider.dart';
import '../../models/school.dart';
import 'schools_repository.dart';

final schoolsRepositoryProvider = Provider<SchoolsRepository>((ref) {
  return SchoolsRepository(ref.watch(firestoreProvider));
});

class SchoolLookupRequest {
  const SchoolLookupRequest({
    required this.province,
    required this.locality,
    required this.namePrefix,
    this.limit = 10,
  });

  final String province;
  final String locality;
  final String namePrefix;
  final int limit;

  @override
  bool operator ==(Object other) {
    return other is SchoolLookupRequest &&
        province == other.province &&
        locality == other.locality &&
        namePrefix == other.namePrefix &&
        limit == other.limit;
  }

  @override
  int get hashCode => Object.hash(province, locality, namePrefix, limit);
}

class PrefixLookupRequest {
  const PrefixLookupRequest({
    required this.prefix,
    this.limit = 20,
  });

  final String prefix;
  final int limit;

  @override
  bool operator ==(Object other) {
    return other is PrefixLookupRequest &&
        prefix == other.prefix &&
        limit == other.limit;
  }

  @override
  int get hashCode => Object.hash(prefix, limit);
}

class LocalityLookupRequest {
  const LocalityLookupRequest({
    required this.province,
    required this.prefix,
    this.limit = 20,
  });

  final String province;
  final String prefix;
  final int limit;

  @override
  bool operator ==(Object other) {
    return other is LocalityLookupRequest &&
        province == other.province &&
        prefix == other.prefix &&
        limit == other.limit;
  }

  @override
  int get hashCode => Object.hash(province, prefix, limit);
}

final provinceOptionsProvider =
    FutureProvider.autoDispose.family<List<String>, PrefixLookupRequest>(
  (ref, request) {
    return ref.read(schoolsRepositoryProvider).searchProvinces(
          prefix: request.prefix,
          limit: request.limit,
        );
  },
);

final localityOptionsProvider =
    FutureProvider.autoDispose.family<List<String>, LocalityLookupRequest>(
  (ref, request) {
    return ref.read(schoolsRepositoryProvider).searchLocalities(
          province: request.province,
          prefix: request.prefix,
          limit: request.limit,
        );
  },
);

final schoolLookupProvider =
    FutureProvider.autoDispose.family<List<School>, SchoolLookupRequest>(
  (ref, request) {
    return ref.read(schoolsRepositoryProvider).searchSchools(
          province: request.province,
          locality: request.locality,
          namePrefix: request.namePrefix,
          limit: request.limit,
        );
  },
);
