import 'package:flutter/material.dart';

class TalentoScreen extends StatefulWidget {
  const TalentoScreen({super.key});

  @override
  State<TalentoScreen> createState() => _TalentoScreenState();
}

class _TalentoScreenState extends State<TalentoScreen> {
  final _search = TextEditingController();
  final _samples = const [
    ('Laura M.', 'Diseño gráfico y branding', 'Creativo'),
    ('Carlos P.', 'Clases de matemáticas', 'Educación'),
    ('Marta R.', 'Nutrición familiar', 'Salud'),
    ('Juan A.', 'Reparaciones del hogar', 'Servicios'),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final profiles = _samples.where((p) {
      if (query.isEmpty) return true;
      return p.$1.toLowerCase().contains(query) || p.$2.toLowerCase().contains(query) || p.$3.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Talento del Cole')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Directorio profesional entre familias',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Comparte oficios, servicios y habilidades (solo perfiles de adultos).',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Buscar por nombre, servicio o sector',
            ),
          ),
          const SizedBox(height: 12),
          ...profiles.map(
            (p) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(p.$1),
                subtitle: Text(p.$2),
                trailing: Chip(label: Text(p.$3)),
              ),
            ),
          ),
          if (profiles.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text('No hay resultados para esa búsqueda.'),
              ),
            ),
        ],
      ),
    );
  }
}
