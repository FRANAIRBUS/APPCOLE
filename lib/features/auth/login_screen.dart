import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../router/app_router.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isRegister = false;
  String? _error;

  Future<void> _submit() async {
    try {
      final auth = ref.read(authServiceProvider);
      if (_isRegister) {
        await auth.signUpWithEmail(email: _email.text, password: _password.text);
      } else {
        await auth.signInWithEmail(email: _email.text, password: _password.text);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_isRegister ? 'Crear cuenta' : 'Acceder', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 8),
                TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña')),
                const SizedBox(height: 12),
                FilledButton(onPressed: _submit, child: Text(_isRegister ? 'Registrarme' : 'Entrar')),
                TextButton(
                  onPressed: () => setState(() => _isRegister = !_isRegister),
                  child: Text(_isRegister ? 'Ya tengo cuenta' : 'Crear nueva cuenta'),
                ),
                OutlinedButton(
                  onPressed: () => ref.read(authServiceProvider).signInWithGoogle(),
                  child: const Text('Continuar con Google'),
                ),
                OutlinedButton(
                  onPressed: () => ref.read(authServiceProvider).signInWithApple(),
                  child: const Text('Continuar con Apple'),
                ),
                if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
