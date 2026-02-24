import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/school.dart';
import 'schools_providers.dart';

class RootSchoolsAdminScreen extends ConsumerStatefulWidget {
  const RootSchoolsAdminScreen({super.key});

  @override
  ConsumerState<RootSchoolsAdminScreen> createState() =>
      _RootSchoolsAdminScreenState();
}

class _RootSchoolsAdminScreenState
    extends ConsumerState<RootSchoolsAdminScreen> {
  final _nameCtrl = TextEditingController();
  final _provinceCtrl = TextEditingController();
  final _localityCtrl = TextEditingController();

  final List<School> _schools = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _loading = false;
  bool _hasMore = true;
  bool? _activeFilter;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _provinceCtrl.dispose();
    _localityCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _lastDoc = null;
      _hasMore = true;
      _schools.clear();
    });

    try {
      final page =
          await ref.read(schoolsRepositoryProvider).listSchoolsForRoot(
                namePrefix: _nameCtrl.text,
                provincePrefix: _provinceCtrl.text,
                localityPrefix: _localityCtrl.text,
                activo: _activeFilter,
                startAfter: null,
                limit: 20,
              );
      if (!mounted) return;
      setState(() {
        _schools
          ..clear()
          ..addAll(page.items);
        _lastDoc = page.lastDoc;
        _hasMore = page.hasMore;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final page =
          await ref.read(schoolsRepositoryProvider).listSchoolsForRoot(
                namePrefix: _nameCtrl.text,
                provincePrefix: _provinceCtrl.text,
                localityPrefix: _localityCtrl.text,
                activo: _activeFilter,
                startAfter: _lastDoc,
                limit: 20,
              );
      if (!mounted) return;
      setState(() {
        _schools.addAll(page.items);
        _lastDoc = page.lastDoc;
        _hasMore = page.hasMore;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreateDialog() async {
    final input = await _showSchoolDialog();
    if (input == null) return;
    await _saveSchool(input: input, creating: true);
  }

  Future<void> _openEditDialog(School school) async {
    final input = await _showSchoolDialog(existing: school);
    if (input == null) return;
    await _saveSchool(input: input, creating: false);
  }

  Future<void> _saveSchool({
    required SchoolUpsertInput input,
    required bool creating,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _loading = true);
    try {
      final repo = ref.read(schoolsRepositoryProvider);
      if (creating) {
        await repo.createSchool(updatedBy: uid, input: input);
      } else {
        await repo.updateSchool(updatedBy: uid, input: input);
      }
      if (!mounted) return;
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            creating ? 'Colegio creado.' : 'Colegio actualizado.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $e')),
      );
    }
  }

  Future<void> _toggleActive(School school, bool active) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _loading = true);
    try {
      await ref.read(schoolsRepositoryProvider).setSchoolActive(
            codigoCentro: school.codigoCentro,
            active: active,
            updatedBy: uid,
          );
      if (!mounted) return;
      await _reload();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar estado: $e')),
      );
    }
  }

  Future<SchoolUpsertInput?> _showSchoolDialog({School? existing}) async {
    final codeCtrl = TextEditingController(text: existing?.codigoCentro ?? '');
    final nameCtrl = TextEditingController(text: existing?.nombre ?? '');
    final localityCtrl = TextEditingController(text: existing?.localidad ?? '');
    final provinceCtrl = TextEditingController(text: existing?.provincia ?? '');
    var active = existing?.activo ?? true;
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<SchoolUpsertInput>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(existing == null ? 'Nuevo colegio' : 'Editar colegio'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: codeCtrl,
                    readOnly: existing != null,
                    decoration: const InputDecoration(labelText: 'codigoCentro'),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Obligatorio';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Nombre del colegio'),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Obligatorio';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: localityCtrl,
                    decoration: const InputDecoration(labelText: 'Localidad'),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Obligatorio';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: provinceCtrl,
                    decoration: const InputDecoration(labelText: 'Provincia'),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Obligatorio';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  StatefulBuilder(
                    builder: (context, setInnerState) {
                      return SwitchListTile(
                        value: active,
                        onChanged: (value) => setInnerState(() => active = value),
                        title: const Text('Activo'),
                        contentPadding: EdgeInsets.zero,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.of(context).pop(
                  SchoolUpsertInput(
                    codigoCentro: codeCtrl.text.trim(),
                    nombre: nameCtrl.text.trim(),
                    localidad: localityCtrl.text.trim(),
                    provincia: provinceCtrl.text.trim(),
                    activo: active,
                  ),
                );
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    codeCtrl.dispose();
    nameCtrl.dispose();
    localityCtrl.dispose();
    provinceCtrl.dispose();

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin colegios'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Buscar por nombre (prefijo)',
                      ),
                      onSubmitted: (_) => _reload(),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _provinceCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Provincia (prefijo)',
                            ),
                            onSubmitted: (_) => _reload(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _localityCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Localidad (prefijo)',
                            ),
                            onSubmitted: (_) => _reload(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<bool?>(
                            initialValue: _activeFilter,
                            decoration: const InputDecoration(
                              labelText: 'Estado',
                            ),
                            items: const [
                              DropdownMenuItem<bool?>(
                                value: null,
                                child: Text('Todos'),
                              ),
                              DropdownMenuItem<bool?>(
                                value: true,
                                child: Text('Activos'),
                              ),
                              DropdownMenuItem<bool?>(
                                value: false,
                                child: Text('Inactivos'),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _activeFilter = value),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _loading ? null : _reload,
                          icon: const Icon(Icons.search),
                          label: const Text('Buscar'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _loading ? null : _openCreateDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Nuevo colegio'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_error != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _reload,
                child: ListView.builder(
                  itemCount: _schools.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _schools.length) {
                      if (_schools.isEmpty && !_loading) {
                        return const ListTile(
                          title: Text('No hay resultados.'),
                        );
                      }
                      if (!_hasMore) {
                        return const SizedBox(height: 12);
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: _loading
                              ? const CircularProgressIndicator()
                              : OutlinedButton(
                                  onPressed: _loadMore,
                                  child: const Text('Cargar más'),
                                ),
                        ),
                      );
                    }

                    final school = _schools[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(school.nombre),
                        subtitle: Text(
                          '${school.codigoCentro} · ${school.localidad}, ${school.provincia}',
                        ),
                        trailing: SizedBox(
                          width: 168,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Switch(
                                value: school.activo,
                                onChanged: _loading
                                    ? null
                                    : (value) => _toggleActive(school, value),
                              ),
                              IconButton(
                                onPressed:
                                    _loading ? null : () => _openEditDialog(school),
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'Editar',
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
