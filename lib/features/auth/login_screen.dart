import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/session_provider.dart';
import '../../widgets/app_logo.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isRegister = false;
  bool _busy = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Introduce tu email.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Email no válido.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = (value ?? '').trim();
    if (password.isEmpty) return 'Introduce tu contraseña.';
    if (_isRegister && password.length < 6) {
      return 'Debe tener al menos 6 caracteres.';
    }
    return null;
  }

  String _friendlyAuthError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'invalid-email':
        case 'user-not-found':
          return 'Credenciales no válidas.';
        case 'email-already-in-use':
          return 'Ese email ya está registrado.';
        case 'weak-password':
          return 'La contraseña es demasiado débil.';
        case 'network-request-failed':
          return 'Sin conexión. Revisa internet e inténtalo otra vez.';
        case 'popup-closed-by-user':
          return 'Se cerró la ventana de acceso.';
        default:
          return error.message ?? 'No se pudo completar el acceso.';
      }
    }
    return error.toString();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = ref.read(authServiceProvider);
      if (_isRegister) {
        await auth.signUpWithEmail(
            email: _email.text, password: _password.text);
      } else {
        await auth.signInWithEmail(
            email: _email.text, password: _password.text);
      }

      // Si venimos de un deep-link (p.ej. invitación) preserva el destino.
      // Importante: esto debe ocurrir *después* del login para no perder query params.
      if (mounted) {
        final next = GoRouterState.of(context).uri.queryParameters['next'];
        if (next != null && next.trim().isNotEmpty) {
          context.go(next);
        }
      }
    } catch (e) {
      setState(() => _error = _friendlyAuthError(e));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _socialSignIn(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) {
        final next = GoRouterState.of(context).uri.queryParameters['next'];
        if (next != null && next.trim().isNotEmpty) {
          context.go(next);
        }
      }
    } catch (e) {
      setState(() => _error = _friendlyAuthError(e));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(
                            child: AppLogo(
                              width: 280,
                              height: 84,
                              borderRadius: 10,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _isRegister ? 'Crear cuenta' : 'Acceder',
                            style: theme.textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _email,
                            validator: _validateEmail,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(labelText: 'Email'),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _password,
                            validator: _validatePassword,
                            obscureText: _obscurePassword,
                            autofillHints: _isRegister
                                ? const [AutofillHints.newPassword]
                                : const [AutofillHints.password],
                            onFieldSubmitted: (_) => _busy ? null : _submit(),
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                                icon: Icon(_obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _busy ? null : _submit,
                            child: Text(_busy
                                ? 'Procesando...'
                                : (_isRegister ? 'Registrarme' : 'Entrar')),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() {
                                      _isRegister = !_isRegister;
                                      _error = null;
                                    }),
                            child: Text(_isRegister
                                ? 'Ya tengo cuenta'
                                : 'Crear nueva cuenta'),
                          ),
                          OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => _socialSignIn(() => ref
                                    .read(authServiceProvider)
                                    .signInWithGoogle()),
                            child: const Text('Continuar con Google'),
                          ),
                          OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => _socialSignIn(() => ref
                                    .read(authServiceProvider)
                                    .signInWithApple()),
                            child: const Text('Continuar con Apple'),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 8),
                            Text(_error!,
                                style: TextStyle(color: theme.colorScheme.error)),
                          ],
                        ],
                      ),
                    ),
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
