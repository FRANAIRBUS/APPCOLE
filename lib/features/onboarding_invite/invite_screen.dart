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
  final _code = TextEditingController();
  final _child = TextEditingController();
  final _age = TextEditingController();
  String? _error;

  Future<void> _redeem() async {
    try {
      await ref.read(inviteServiceProvider).redeemInviteCode(
            code: _code.text,
            childName: _child.text,
            childAge: int.tryParse(_age.text) ?? 0,
          );
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Código del colegio')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _code, decoration: const InputDecoration(labelText: 'Código de invitación')),
            TextField(controller: _child, decoration: const InputDecoration(labelText: 'Nombre del menor')),
            TextField(controller: _age, decoration: const InputDecoration(labelText: 'Edad'), keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            FilledButton(onPressed: _redeem, child: const Text('Validar y continuar')),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}
