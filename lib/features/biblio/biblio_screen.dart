import 'package:flutter/material.dart';

class BiblioScreen extends StatelessWidget {
  const BiblioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      ('Libro Matemáticas 5º', 'Se presta', 'Buen estado'),
      ('Uniforme talla 8', 'Se regala', 'Recoger en portería'),
      ('Diccionario inglés', 'Se vende', '5€'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('BiblioCircular')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Intercambio escolar',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Comparte libros y material para reducir gasto familiar.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text(item.$1),
                subtitle: Text(item.$3),
                trailing: Chip(label: Text(item.$2)),
              ),
            ),
          ),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Consejo: evita datos sensibles en publicaciones. Coordina entrega por chat interno.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
