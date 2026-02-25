import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/session_provider.dart';
import '../../services/invite_share_service.dart';

const List<String> _classOptions = [
  'Hasta 2 Años',
  'K1',
  'K2',
  'K3',
  '1P',
  '2P',
  '3P',
  '4P',
  '5P',
  '6P',
  '1S',
  '2S',
  '3S',
  '4S',
  '1B',
  '2B',
  'Otros',
];

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _busy = false;

  Future<void> _editProfile(String schoolId, String uid) async {
    final userRef = FirebaseFirestore.instance.doc('schools/$schoolId/users/$uid');
    final snap = await userRef.get();
    final data = snap.data() ?? <String, dynamic>{};

    final displayNameController = TextEditingController(
      text: (data['displayName'] as String? ?? '').trim(),
    );

    final rawChildren = (data['children'] as List?) ?? const [];
    final children = rawChildren
        .whereType<Map>()
        .map(
          (child) => _EditableChild(
            name: (child['name'] as String? ?? '').trim(),
            classId: (child['classId'] as String? ?? '').trim(),
          ),
        )
        .where((child) => child.name.isNotEmpty || child.classId.isNotEmpty)
        .toList();

    if (children.isEmpty) {
      children.add(const _EditableChild(name: '', classId: ''));
    }

    final extraGroups = ((data['extraGroupIds'] as List?) ?? const [])
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toList();

    if (extraGroups.isEmpty) {
      extraGroups.add('');
    }

    final formKey = GlobalKey<FormState>();
    final updated = await showModalBottomSheet<_ProfileDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _EditProfileSheet(
        formKey: formKey,
        displayNameController: displayNameController,
        initialChildren: children,
        initialExtraGroups: extraGroups,
      ),
    );

    if (updated == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await userRef.update({
        'displayName': updated.displayName,
        'children': updated.children
            .map((child) => {'name': child.name, 'classId': child.classId})
            .toList(),
        'classIds': updated.classIds,
        'extraGroupIds': updated.extraGroupIds,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar el perfil: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      displayNameController.dispose();
    }
  }


  Future<void> _shareInviteCard(String schoolId) async {
    setState(() => _busy = true);
    try {
      await ref.read(inviteShareServiceProvider).shareInviteCard(
            schoolId: schoolId,
            source: 'profile',
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tarjeta copiada. Compártela por WhatsApp o email.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo compartir la invitación: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    try {
      await ref.read(authServiceProvider).signOut();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAccount(String schoolId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar borrado'),
        content: const Text(
          'Esta acción elimina tu perfil y datos asociados. No se puede deshacer.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí, borrar')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _busy = true);
    try {
      await FirebaseFunctions.instance.httpsCallable('deleteMyAccount').call({'schoolId': schoolId});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cuenta eliminada.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo borrar la cuenta: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final schoolId = ref.watch(schoolIdProvider).valueOrNull;
    final globalUser = ref.watch(globalUserProvider).valueOrNull;
    final isRoot = ref.watch(isRootClaimProvider).valueOrNull ?? false;
    final email = user?.email ?? '';
    final uid = user?.uid ?? '';
    final schoolName = (globalUser?['schoolName'] as String? ?? '').trim();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Perfil',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email.isNotEmpty ? email : uid,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  schoolId == null
                      ? 'Colegio: Pendiente de vinculación'
                      : (schoolName.isNotEmpty
                          ? 'Colegio: $schoolName ($schoolId)'
                          : 'Colegio: $schoolId'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Privacidad', style: TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(height: 8),
                Text('No compartas teléfonos ni fotos de menores. Usa siempre el chat interno.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: (_busy || schoolId == null || uid.isEmpty) ? null : () => _editProfile(schoolId, uid),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Editar perfil y alumnos'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: (_busy || schoolId == null) ? null : () => _shareInviteCard(schoolId),
          icon: const Icon(Icons.share_outlined),
          label: const Text('Invitar a padres al colegio'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _busy ? null : _signOut,
          icon: const Icon(Icons.logout),
          label: Text(_busy ? 'Procesando...' : 'Cerrar sesión'),
        ),
        if (isRoot) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => context.push('/root/colegios'),
            icon: const Icon(Icons.admin_panel_settings_outlined),
            label: const Text('Administrar colegios'),
          ),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: (_busy || schoolId == null) ? null : () => _deleteAccount(schoolId),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Borrar cuenta (GDPR)'),
        ),
      ],
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({
    required this.formKey,
    required this.displayNameController,
    required this.initialChildren,
    required this.initialExtraGroups,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController displayNameController;
  final List<_EditableChild> initialChildren;
  final List<String> initialExtraGroups;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final List<_ChildControllers> _children;
  late final List<TextEditingController> _extraGroups;

  @override
  void initState() {
    super.initState();
    _children = widget.initialChildren
        .map((child) => _ChildControllers(name: child.name, classId: child.classId))
        .toList();
    _extraGroups = widget.initialExtraGroups.map((group) => TextEditingController(text: group)).toList();
  }

  @override
  void dispose() {
    for (final child in _children) {
      child.dispose();
    }
    for (final group in _extraGroups) {
      group.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: widget.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Editar perfil',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: widget.displayNameController,
                  decoration: const InputDecoration(labelText: 'Nombre visible (padre/madre)'),
                  validator: (value) {
                    final trimmed = (value ?? '').trim();
                    if (trimmed.length < 2) return 'Introduce un nombre válido.';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                Text('Datos del alumno', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ..._buildChildren(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _children.add(_ChildControllers(name: '', classId: ''))),
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar alumno'),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Grupos o cursos extraescolares', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ..._buildGroups(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _extraGroups.add(TextEditingController())),
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar grupo'),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    if (!widget.formKey.currentState!.validate()) return;

                    final children = _children
                        .map(
                          (child) => _EditableChild(
                            name: child.name.text.trim(),
                            classId: child.classId.trim(),
                          ),
                        )
                        .where((child) => child.name.isNotEmpty || child.classId.isNotEmpty)
                        .toList();

                    if (children.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Agrega al menos un alumno.')),
                      );
                      return;
                    }

                    final extraGroupIds = _extraGroups
                        .map((controller) => controller.text.trim())
                        .where((value) => value.isNotEmpty)
                        .toSet()
                        .toList();
                    final classIds = {
                      ...children.map((child) => child.classId).where((id) => id.isNotEmpty),
                      ...extraGroupIds,
                    }.toList();

                    Navigator.of(context).pop(_ProfileDraft(
                      displayName: widget.displayNameController.text.trim(),
                      children: children,
                      classIds: classIds,
                      extraGroupIds: extraGroupIds,
                    ));
                  },
                  child: const Text('Guardar cambios'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildChildren() {
    return List.generate(_children.length, (index) {
      final child = _children[index];
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              TextFormField(
                controller: child.name,
                decoration: InputDecoration(labelText: 'Nombre del alumno ${index + 1}'),
                validator: (value) {
                  final name = (value ?? '').trim();
                  final classValue = child.classId.trim();
                  if (name.isEmpty && classValue.isEmpty) return null;
                  if (name.length < 2) return 'Nombre demasiado corto.';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: child.classId.isEmpty ? null : child.classId,
                decoration: const InputDecoration(labelText: 'Curso / clase'),
                items: _classOptions
                    .map(
                      (classId) => DropdownMenuItem<String>(
                        value: classId,
                        child: Text(classId),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => child.classId = value ?? ''),
                validator: (value) {
                  final classValue = (value ?? '').trim();
                  final name = child.name.text.trim();
                  if (name.isEmpty && classValue.isEmpty) return null;
                  if (classValue.isEmpty) return 'Selecciona el curso.';
                  return null;
                },
              ),
              if (_children.length > 1)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      setState(() {
                        _children.removeAt(index).dispose();
                      });
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

  List<Widget> _buildGroups() {
    return List.generate(_extraGroups.length, (index) {
      final group = _extraGroups[index];
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextFormField(
          controller: group,
          decoration: InputDecoration(
            labelText: 'Grupo extraescolar ${index + 1}',
            suffixIcon: _extraGroups.length > 1
                ? IconButton(
                    onPressed: () {
                      setState(() {
                        _extraGroups.removeAt(index).dispose();
                      });
                    },
                    icon: const Icon(Icons.close),
                  )
                : null,
          ),
        ),
      );
    });
  }
}

class _EditableChild {
  const _EditableChild({required this.name, required this.classId});

  final String name;
  final String classId;
}

class _ChildControllers {
  _ChildControllers({required String name, required String classId})
      : name = TextEditingController(text: name),
        classId = _classOptions.contains(classId) ? classId : (classId.isEmpty ? '' : 'Otros');

  final TextEditingController name;
  String classId;

  void dispose() {
    name.dispose();
  }
}

class _ProfileDraft {
  const _ProfileDraft({
    required this.displayName,
    required this.children,
    required this.classIds,
    required this.extraGroupIds,
  });

  final String displayName;
  final List<_EditableChild> children;
  final List<String> classIds;
  final List<String> extraGroupIds;
}
