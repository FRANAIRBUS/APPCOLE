import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/session_provider.dart';

class TrustScreen extends ConsumerStatefulWidget {
  const TrustScreen({super.key});

  @override
  ConsumerState<TrustScreen> createState() => _TrustScreenState();
}

class _TrustScreenState extends ConsumerState<TrustScreen> {
  final _reason = TextEditingController(text: 'Contenido inadecuado');
  final _targetPath = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _reason.dispose();
    _targetPath.dispose();
    super.dispose();
  }

  Future<void> _submitReport(String schoolId) async {
    final path = _targetPath.text.trim();
    final reason = _reason.text.trim();
    if (path.isEmpty || reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa ruta y motivo del reporte.')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await FirebaseFirestore.instance.collection('schools/$schoolId/reports').add({
        'targetType': path.contains('/posts/') ? 'post' : 'other',
        'targetPath': path,
        'reason': reason,
        'reporterUid': FirebaseAuth.instance.currentUser?.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'open',
      });
      if (!mounted) return;
      _targetPath.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reporte enviado al equipo de moderación.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar el reporte: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(schoolIdProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Red de Confianza')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Normas de convivencia',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('1. Respeto: no ataques personales ni acoso.'),
                  SizedBox(height: 4),
                  Text('2. Privacidad: no teléfonos ni fotos de menores.'),
                  SizedBox(height: 4),
                  Text('3. Utilidad: publica contenido relevante para familias.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _targetPath,
            enabled: !_sending,
            decoration: const InputDecoration(
              labelText: 'Ruta objetivo',
              hintText: 'schools/{schoolId}/posts/{postId}',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reason,
            enabled: !_sending,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Motivo'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: schoolId == null
                ? null
                : (_sending ? null : () => _submitReport(schoolId)),
            child: Text(_sending ? 'Enviando...' : 'Reportar contenido'),
          ),
        ],
      ),
    );
  }
}
