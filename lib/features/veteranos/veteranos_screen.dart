import 'package:flutter/material.dart';

class VeteranosScreen extends StatelessWidget {
  const VeteranosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const tips = [
      ('Entrada al cole', 'Llega 10 minutos antes durante la primera semana.'),
      ('Mochila', 'Prepara todo la noche anterior para reducir estrés.'),
      ('Comedor', 'Etiqueta tupper y botella con nombre y clase.'),
      ('Actividades', 'No apuntes demasiadas extraescolares al inicio.'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Trucos de los Veteranos')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Consejos prácticos por experiencia real',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ...tips.map(
            (tip) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const Icon(Icons.lightbulb_outline),
                title: Text(tip.$1),
                subtitle: Text(tip.$2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
