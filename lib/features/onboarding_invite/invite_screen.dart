import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/school.dart';
import '../../utils/pending_invite_storage.dart';
import '../../utils/text_normalizer.dart';
import '../auth/session_provider.dart';
import '../schools/schools_providers.dart';

class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({super.key});

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  final _provinceCtrl = TextEditingController();
  final _localityCtrl = TextEditingController();
  final _schoolNameCtrl = TextEditingController();

  Timer? _provinceDebounce;
  Timer? _localityDebounce;
  Timer? _schoolDebounce;
  StreamSubscription<User?>? _authSub;

  List<String> _provinceOptions = const [];
  List<String> _localityOptions = const [];
  List<School> _schoolOptions = const [];

  String? _selectedProvince;
  String? _selectedLocality;
  School? _selectedSchool;

  bool _loadingProvinces = false;
  bool _loadingLocalities = false;
  bool _loadingSchools = false;
  bool _saving = false;
  String? _error;

  bool _parsedDeepLink = false;
  bool _prefillInFlight = false;
  String? _inviteSchoolId;
  String? _inviteReferrerUid;

  @override
  void initState() {
    super.initState();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((next) {
      if (next == null || _selectedSchool != null || _prefillInFlight) return;
        final inviteToken = (_inviteSchoolId ?? '').trim();
        if (inviteToken.isEmpty) return;
        unawaited(_prefillFromInviteToken(inviteToken));
      });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _provinceDebounce?.cancel();
    _localityDebounce?.cancel();
    _schoolDebounce?.cancel();
    _provinceCtrl.dispose();
    _localityCtrl.dispose();
    _schoolNameCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_parsedDeepLink) return;
    _parsedDeepLink = true;

    final uri = GoRouterState.of(context).uri;
    final fromQuerySchoolId = uri.queryParameters['schoolId']?.trim();
    final fromQueryReferrer = uri.queryParameters['referrerUid']?.trim();

    // Caso 1: deep-link normal con query params.
    if (fromQuerySchoolId != null && fromQuerySchoolId.isNotEmpty) {
      _inviteSchoolId = fromQuerySchoolId;
      _inviteReferrerUid = fromQueryReferrer;
      savePendingInvite(
        PendingInvite(schoolId: fromQuerySchoolId, referrerUid: fromQueryReferrer),
      );
    } else {
      // Caso 2: Google Sign-In en Safari/iOS (web) hace redirect y puede perder
      // los query params. Recuperamos desde sessionStorage.
      final pending = loadPendingInvite();
      if (pending != null) {
        _inviteSchoolId = pending.schoolId.trim();
        _inviteReferrerUid = pending.referrerUid?.trim();
      }
    }

    // Si el deep-link trae schoolId, precarga y preselecciona el cole.
    final schoolId = _inviteSchoolId;
    if (schoolId != null && schoolId.isNotEmpty) {
      // Intenta resolver aunque no haya sesión (colegios es público de lectura).
      // Si requiere legacy lookup, lo reintentará al autenticarse vía _authSub.
      unawaited(_prefillFromInviteToken(schoolId));
    }
  }

  Future<School?> _resolveInviteSchoolFromToken(String schoolToken) async {
    final token = schoolToken.trim();
    if (token.isEmpty) return null;

    final firestore = FirebaseFirestore.instance;
    final colegios = firestore.collection('colegios');

    final directDoc = await colegios.doc(token).get();
    if (directDoc.exists) return School.fromDoc(directDoc);

    final byCode = await colegios.where('codigoCentro', isEqualTo: token).limit(1).get();
    if (byCode.docs.isNotEmpty) return School.fromDoc(byCode.docs.first);

    if (FirebaseAuth.instance.currentUser == null) return null;

    final legacySchool = await firestore.collection('schools').doc(token).get();
    final legacyData = legacySchool.data() ?? const <String, dynamic>{};

    final legacyCode = (legacyData['codigoCentro'] as String? ?? '').trim();
    if (legacyCode.isNotEmpty) {
      final byLegacyCode = await colegios.doc(legacyCode).get();
      if (byLegacyCode.exists) return School.fromDoc(byLegacyCode);
    }

    final legacyName = normalizeForSearch((legacyData['name'] as String? ?? legacyData['nombre'] as String? ?? '').trim());
    final legacyLocalidad = normalizeForSearch((legacyData['localidad'] as String? ?? '').trim());
    final legacyProvincia = normalizeForSearch((legacyData['provincia'] as String? ?? '').trim());
    if (legacyName.isEmpty || legacyLocalidad.isEmpty || legacyProvincia.isEmpty) {
      return null;
    }

    final bySnapshot = await colegios
        .where('activo', isEqualTo: true)
        .where('nombre_normalizado', isEqualTo: legacyName)
        .where('localidad_normalizada', isEqualTo: legacyLocalidad)
        .where('provincia_normalizada', isEqualTo: legacyProvincia)
        .limit(1)
        .get();
    if (bySnapshot.docs.isNotEmpty) return School.fromDoc(bySnapshot.docs.first);

    return null;
  }

  Future<void> _prefillFromInviteToken(String schoolToken) async {
    if (_prefillInFlight) return;
    _prefillInFlight = true;
    setState(() => _error = null);
    try {
      final school = await _resolveInviteSchoolFromToken(schoolToken);
      if (school == null) {
        if (!mounted) return;
        setState(() => _error = 'La invitación no se pudo vincular automáticamente a un colegio válido.');
        return;
      }

      if (!mounted) return;
      setState(() {
        _inviteSchoolId = school.codigoCentro;
        _selectedSchool = school;
        _selectedProvince = school.provincia;
        _selectedLocality = school.localidad;
        _provinceCtrl.text = school.provincia;
        _localityCtrl.text = school.localidad;
        _schoolNameCtrl.text = school.nombre;
        _provinceOptions = const [];
        _localityOptions = const [];
        _schoolOptions = [school];
      });

      // Canonicaliza y persiste por si hay redirect/reload posterior.
      savePendingInvite(
        PendingInvite(schoolId: school.codigoCentro, referrerUid: _inviteReferrerUid),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      _prefillInFlight = false;
    }
  }

  void _resetLocalityAndSchool() {
    _localityCtrl.clear();
    _schoolNameCtrl.clear();
    _selectedLocality = null;
    _selectedSchool = null;
    _localityOptions = const [];
    _schoolOptions = const [];
  }

  void _resetSchool() {
    _schoolNameCtrl.clear();
    _selectedSchool = null;
    _schoolOptions = const [];
  }

  void _onProvinceChanged(String value) {
    setState(() {
      _selectedProvince = null;
      _resetLocalityAndSchool();
      _error = null;
    });
    _provinceDebounce?.cancel();
    _provinceDebounce = Timer(const Duration(milliseconds: 280), () async {
      if (!mounted) return;
      setState(() => _loadingProvinces = true);
      try {
        final options = await ref.read(schoolsRepositoryProvider).searchProvinces(
              prefix: value,
              limit: 20,
            );
        if (!mounted) return;
        setState(() => _provinceOptions = options);
      } catch (e) {
        if (!mounted) return;
        setState(() => _error = e.toString());
      } finally {
        if (mounted) setState(() => _loadingProvinces = false);
      }
    });
  }

  void _onLocalityChanged(String value) {
    setState(() {
      _selectedLocality = null;
      _resetSchool();
      _error = null;
    });
    final province = _selectedProvince;
    if (province == null || province.isEmpty) return;

    _localityDebounce?.cancel();
    _localityDebounce = Timer(const Duration(milliseconds: 280), () async {
      if (!mounted) return;
      setState(() => _loadingLocalities = true);
      try {
        final options = await ref.read(schoolsRepositoryProvider).searchLocalities(
              province: province,
              prefix: value,
              limit: 20,
            );
        if (!mounted) return;
        setState(() => _localityOptions = options);
      } catch (e) {
        if (!mounted) return;
        setState(() => _error = e.toString());
      } finally {
        if (mounted) setState(() => _loadingLocalities = false);
      }
    });
  }

  void _onSchoolNameChanged(String value) {
    setState(() {
      _selectedSchool = null;
      _error = null;
    });

    final province = _selectedProvince;
    final locality = _selectedLocality;
    if (province == null || locality == null) return;

    _schoolDebounce?.cancel();
    _schoolDebounce = Timer(const Duration(milliseconds: 280), () async {
      if (!mounted) return;
      setState(() => _loadingSchools = true);
      try {
        final options = await ref.read(schoolsRepositoryProvider).searchSchools(
              province: province,
              locality: locality,
              namePrefix: value,
              limit: 10,
            );
        if (!mounted) return;
        setState(() => _schoolOptions = options);
      } catch (e) {
        if (!mounted) return;
        setState(() => _error = e.toString());
      } finally {
        if (mounted) setState(() => _loadingSchools = false);
      }
    });
  }

  Future<void> _saveSelection() async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    final school = _selectedSchool;
    if (uid == null || school == null) {
      setState(() => _error = 'Selecciona un colegio válido para continuar.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(schoolsRepositoryProvider).saveUserSchoolSelection(
            uid: uid,
            school: school,
            displayName: user?.displayName ?? user?.email,
            photoUrl: user?.photoURL,
          );

      // Ya está aplicada, no tiene sentido mantener la invitación viva.
      clearPendingInvite();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Colegio guardado. Accediendo...')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _goToLoginPreservingInvite() {
    final current = GoRouterState.of(context).uri;
    final next = current.toString();
    final loginUri = Uri(path: '/login', queryParameters: {'next': next}).toString();
    context.go(loginUri);
  }

  Future<void> _showNotFoundDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No encuentro mi colegio'),
        content: const Text(
          'Si tu centro no aparece, pide al administrador root que lo añada en el catálogo.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _chooseAnotherSchool() {
    setState(() {
      _selectedSchool = null;
      _error = null;
      _schoolNameCtrl.clear();
      _schoolOptions = const [];
      _inviteSchoolId = null;
    });

    // Si el usuario decide ignorar la invitación, no la resucites tras reload.
    clearPendingInvite();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isSignedIn = user != null;
    final canSearchLocality = _selectedProvince != null;
    final canSearchSchool = _selectedProvince != null && _selectedLocality != null;
    final canContinue = _selectedSchool != null && !_saving;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Selecciona tu colegio'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: (_saving || !isSignedIn)
                ? null
                : () async {
                    await ref.read(authServiceProvider).signOut();
                  },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!isSignedIn) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Invitación detectada',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Para aceptar la invitación y entrar en el colegio, primero inicia sesión o crea tu cuenta.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        if (_inviteSchoolId != null && _inviteSchoolId!.isNotEmpty)
                          Text(
                            'Colegio de la invitación: ${_selectedSchool?.nombre.isNotEmpty == true ? _selectedSchool!.nombre : _inviteSchoolId}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        if (_inviteReferrerUid != null && _inviteReferrerUid!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Referente: $_inviteReferrerUid',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        const SizedBox(height: 14),
                        FilledButton(
                          onPressed: _goToLoginPreservingInvite,
                          child: const Text('Iniciar sesión / Registrarme'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_inviteSchoolId != null && _inviteSchoolId!.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Has recibido una invitación para unirte a este colegio',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _selectedSchool?.nombre.isNotEmpty == true
                                    ? 'Colegio invitado: ${_selectedSchool!.nombre}'
                                    : 'Colegio invitado: $_inviteSchoolId',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Si eres padre/madre de un alumno de este colegio, continúa con esta selección. Si no corresponde, busca el colegio correcto.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: _saving ? null : _chooseAnotherSchool,
                                  icon: const Icon(Icons.search),
                                  label: const Text('Buscar otro colegio'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        'Registro: colegio obligatorio',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Busca por provincia, localidad y nombre. Debes elegir un colegio existente.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _provinceCtrl,
                        enabled: !_saving,
                        decoration: InputDecoration(
                          labelText: '1) Provincia',
                          suffixIcon: _loadingProvinces
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : null,
                        ),
                        onChanged: _onProvinceChanged,
                      ),
                      if (_provinceOptions.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _provinceOptions
                              .map(
                                (province) => ChoiceChip(
                                  label: Text(province),
                                  selected: _selectedProvince == province,
                                  onSelected: _saving
                                      ? null
                                      : (_) {
                                          setState(() {
                                            _selectedProvince = province;
                                            _provinceCtrl.text = province;
                                            _provinceOptions = const [];
                                            _resetLocalityAndSchool();
                                          });
                                        },
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: _localityCtrl,
                        enabled: canSearchLocality && !_saving,
                        decoration: InputDecoration(
                          labelText: '2) Localidad',
                          suffixIcon: _loadingLocalities
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : null,
                        ),
                        onChanged: _onLocalityChanged,
                      ),
                      if (_localityOptions.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _localityOptions
                              .map(
                                (locality) => ChoiceChip(
                                  label: Text(locality),
                                  selected: _selectedLocality == locality,
                                  onSelected: _saving
                                      ? null
                                      : (_) {
                                          setState(() {
                                            _selectedLocality = locality;
                                            _localityCtrl.text = locality;
                                            _localityOptions = const [];
                                            _resetSchool();
                                          });
                                        },
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: _schoolNameCtrl,
                        enabled: canSearchSchool && !_saving,
                        decoration: InputDecoration(
                          labelText: '3) Colegio (prefijo)',
                          suffixIcon: _loadingSchools
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : null,
                        ),
                        onChanged: _onSchoolNameChanged,
                      ),
                      const SizedBox(height: 10),
                      if (_schoolOptions.isEmpty &&
                          _schoolNameCtrl.text.trim().isNotEmpty &&
                          !_loadingSchools)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _showNotFoundDialog,
                            icon: const Icon(Icons.help_outline),
                            label: const Text('No encuentro mi colegio'),
                          ),
                        ),
                      if (_schoolOptions.isNotEmpty)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 320),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _schoolOptions.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final school = _schoolOptions[index];
                              final selected =
                                  _selectedSchool?.codigoCentro == school.codigoCentro;
                              return Card(
                                margin: EdgeInsets.zero,
                                child: ListTile(
                                  selected: selected,
                                  selectedTileColor: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                      .withValues(alpha: 0.25),
                                  title: Text(school.nombre),
                                  subtitle: Text(
                                    '${school.localidad}, ${school.provincia} · ${school.codigoCentro}',
                                  ),
                                  trailing: selected
                                      ? const Icon(Icons.check_circle_outline)
                                      : null,
                                  onTap: _saving
                                      ? null
                                      : () {
                                          setState(() => _selectedSchool = school);
                                        },
                                ),
                              );
                            },
                          ),
                        ),
                      if (_selectedSchool != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Seleccionado: ${_selectedSchool!.nombre} (${_selectedSchool!.codigoCentro})',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: isSignedIn && canContinue ? _saveSelection : null,
                        child: Text(_saving
                            ? 'Guardando...'
                            : 'Continuar con este colegio'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
