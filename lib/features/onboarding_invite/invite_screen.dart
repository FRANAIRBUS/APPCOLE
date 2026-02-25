import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/school.dart';
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
  String? _inviteSchoolId;
  String? _inviteReferrerUid;
  bool _prefillLoading = false;

  @override
  void dispose() {
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
    _inviteSchoolId = uri.queryParameters['schoolId']?.trim();
    _inviteReferrerUid = uri.queryParameters['referrerUid']?.trim();

    // Si el deep-link trae schoolId, precarga y preselecciona el cole.
    final schoolId = _inviteSchoolId;
    if (schoolId != null && schoolId.isNotEmpty) {
      _prefillFromSchoolId(schoolId);
    }
  }

  Future<void> _prefillFromSchoolId(String schoolId) async {
    setState(() {
      _prefillLoading = true;
      _error = null;
    });
    try {
      // No usamos el repositorio aquí: el deep-link debe poder preseleccionar
      // el colegio incluso si el repositorio cambia. La colección canónica
      // del catálogo es 'colegios'.
      final doc = await FirebaseFirestore.instance.collection('colegios').doc(schoolId).get();
      if (!doc.exists) {
        if (!mounted) return;
        setState(() => _error = 'La invitación apunta a un colegio que ya no existe.');
        return;
      }

      final school = School.fromDoc(doc);
      if (!mounted) return;
      setState(() {
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _prefillLoading = false);
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
