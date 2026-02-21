import 'package:flutter/material.dart';

class BienvenidaScreen extends StatelessWidget {
  const BienvenidaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Primer Día, Cero Dudas: contenido estático por colegio desde Firestore/JSON.')),
    );
  }
}
