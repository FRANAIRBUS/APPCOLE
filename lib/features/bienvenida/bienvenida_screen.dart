import 'package:flutter/material.dart';

class BienvenidaScreen extends StatefulWidget {
  const BienvenidaScreen({super.key});

  @override
  State<BienvenidaScreen> createState() => _BienvenidaScreenState();
}

class _BienvenidaScreenState extends State<BienvenidaScreen> {
  final Map<String, bool> _checklist = {
    'Uniforme preparado': false,
    'Material escolar completo': false,
    'Documentación firmada': false,
    'Ruta de llegada planificada': false,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Primer Día, Cero Dudas')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Checklist de bienvenida',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Marca lo que ya tienes listo para empezar con tranquilidad.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          ..._checklist.keys.map(
            (item) => CheckboxListTile(
              value: _checklist[item],
              title: Text(item),
              onChanged: (value) => setState(() => _checklist[item] = value ?? false),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text('Progreso: ${_checklist.values.where((v) => v).length}/${_checklist.length} completado.'),
            ),
          ),
        ],
      ),
    );
  }
}
