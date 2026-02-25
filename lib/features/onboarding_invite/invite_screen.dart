import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
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

  bool _processedLink = false;
  School? _invitedSchool;
  String? _invitedSchoolId;
  String? _referrerUid;

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
    // Deep-link: /invite?schoolId=...&referrerUid=...
    if (!_processedLink) {
      _processedLink = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final qp = GoRouterState.of(context).uri.queryParameters;
        final schoolId = (qp['schoolId'] ?? '').trim();
        final referrerUid = (qp['referrerUid'] ?? '').trim();
        if (schoolId.isEmpty) return;

        setState(() {
          _invitedSchoolId = schoolId;
          _referrerUid = referrerUid.isEmpty ? null : referrerUid;
        });

        try {
          final school = await ref.read(schoolsRepositoryProvider).getActiveSchoolById(schoolId);
          if (!mounted) return;
          if (school == null) {
            setState(() => _error = 'El colegio de la invitación no existe o está inactivo.');
            return;
          }
          setState(() {
            _invitedSchool = school;
            // Preselección automática; el usuario puede cambiarlo.
            _selectedProvince = school.provincia;
            _selectedLocality = school.localidad;
            _selectedSchool = school;
            _provinceCtrl.text = school.provincia;
            _localityCtrl.text = school.localidad;
            _schoolNameCtrl.text = school.nombre;
          });
        } catch (e) {
          if (!mounted) return;
          setState(() => _error = e.toString());
        }
      });
    }

    final canSearchLocality = _selectedProvince != null;
    final canSearchSchool = _selectedProvince != null && _selectedLocality != null;
    final canContinue = _selectedSchool != null && !_saving;

    final user = FirebaseAuth.instance.currentUser;
    final mustLogin = user == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Selecciona tu colegio'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: _saving
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
              if (_invitedSchool != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Invitación al colegio',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_invitedSchool!.nombre}\n${_invitedSchool!.localidad}, ${_invitedSchool!.provincia} · ${_invitedSchool!.codigoCentro}',
                        ),
                        const SizedBox(height: 12),
                        if (mustLogin)
                          FilledButton.icon(
                            onPressed: () {
                              final uri = Uri(
                                path: '/login',
                                queryParameters: {
                                  if (_invitedSchoolId != null) 'schoolId': _invitedSchoolId!,
                                  if (_referrerUid != null) 'referrerUid': _referrerUid!,
                                  'redirect': '/invite',
                                },
                              );
                              context.go(uri.toString());
                            },
                            icon: const Icon(Icons.login),
                            label: const Text('Inicia sesión para aceptar'),
                          )
                        else
                          FilledButton.icon(
                            onPressed: canContinue ? _saveSelection : null,
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Usar este colegio'),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          'Puedes usar el colegio de la invitación o buscar otro en el catálogo.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              if (mustLogin)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Inicia sesión para seleccionar y guardar tu colegio. Si has abierto un enlace de invitación, el colegio se preseleccionará automáticamente tras el login.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
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
                        onPressed: mustLogin ? null : (canContinue ? _saveSelection : null),
                        child: Text(
                          mustLogin
                              ? 'Inicia sesión para continuar'
                              : (_saving ? 'Guardando...' : 'Continuar con este colegio'),
                        ),
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
