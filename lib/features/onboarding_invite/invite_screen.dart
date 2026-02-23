import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/invite_service.dart';

final inviteServiceProvider = Provider<InviteService>((ref) => InviteService(FirebaseFunctions.instance));

class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({super.key});

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _child = TextEditingController();
  final _age = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _child.dispose();
    _age.dispose();
    super.dispose();
  }

  String? _validateCode(String? value) {
    final code = (value ?? '').trim();
    if (code.isEmpty) return 'Introduce el código.';
    if (code.length < 4) return 'Código inválido.';
    return null;
  }

  String? _validateChildName(String? value) {
    final name = (value ?? '').trim();
    if (name.isEmpty) return 'Introduce el nombre del menor.';
    if (name.length < 2) return 'Nombre demasiado corto.';
    return null;
  }

  String? _validateAge(String? value) {
    final age = int.tryParse((value ?? '').trim());
    if (age == null) return 'Edad no válida.';
    if (age <= 0 || age > 20) return 'Introduce una edad válida.';
    return null;
  }

  String _friendlyError(Object error) {
    if (error is FirebaseFunctionsException) {
      switch (error.code) {
        case 'not-found':
          return 'El código no existe.';
        case 'failed-precondition':
          return error.message ?? 'Código inválido o expirado.';
        case 'invalid-argument':
          return 'Revisa los datos del formulario.';
        case 'unauthenticated':
          return 'Tu sesión expiró. Vuelve a iniciar sesión.';
        default:
          return error.message ?? 'No se pudo validar el código.';
      }
    }
    return error.toString();
  }

  Future<void> _redeem() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(inviteServiceProvider).redeemInviteCode(
            code: _code.text.trim().toUpperCase(),
            childName: _child.text.trim(),
            childAge: int.parse(_age.text.trim()),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código validado. Accediendo...')),
      );
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Código del colegio')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Vincular cuenta al colegio',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Introduce el código entregado por tu colegio y los datos del menor.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _code,
                        validator: _validateCode,
                        enabled: !_submitting,
                        textCapitalization: TextCapitalization.characters,
                        onChanged: (value) {
                          final upper = value.toUpperCase();
                          if (upper != value) {
                            _code.value = _code.value.copyWith(
                              text: upper,
                              selection: TextSelection.collapsed(offset: upper.length),
                            );
                          }
                        },
                        decoration: const InputDecoration(labelText: 'Código de invitación'),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _child,
                        validator: _validateChildName,
                        enabled: !_submitting,
                        decoration: const InputDecoration(labelText: 'Nombre del menor'),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _age,
                        validator: _validateAge,
                        enabled: !_submitting,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Edad'),
                        onFieldSubmitted: (_) => _submitting ? null : _redeem(),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _submitting ? null : _redeem,
                        child: Text(_submitting ? 'Validando...' : 'Validar y continuar'),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
