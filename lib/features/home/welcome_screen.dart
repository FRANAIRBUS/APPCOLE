import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget featureCard({required IconData icon, required String title, required String body}) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(body, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.school, color: theme.colorScheme.onPrimaryContainer),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ColeConecta', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(
                              'Red privada de confianza entre familias del mismo colegio. Sin teléfonos, sin exposición, sin ruido.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 0,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cómo funciona', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 10),
                          _StepRow(index: '1', text: 'Creas tu cuenta (email, Google o Apple).'),
                          _StepRow(index: '2', text: 'Introduces el código de invitación del colegio.'),
                          _StepRow(index: '3', text: 'Accedes a tu comunidad: publicaciones, eventos, mi clase y chat 1:1.'),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              FilledButton.icon(
                                onPressed: () => context.go('/login'),
                                icon: const Icon(Icons.login),
                                label: const Text('Entrar'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => context.go('/login'),
                                icon: const Icon(Icons.person_add_alt),
                                label: const Text('Crear cuenta'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Módulos del MVP', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  featureCard(
                    icon: Icons.swap_horiz,
                    title: 'Busco / Ofrezco',
                    body: 'Ayuda entre familias: recogidas, intercambios, recomendaciones y necesidades puntuales.',
                  ),
                  featureCard(
                    icon: Icons.event,
                    title: 'Entre Padres',
                    body: 'Eventos y planes entre familias: quedadas, parques, celebraciones, avisos de interés.',
                  ),
                  featureCard(
                    icon: Icons.groups,
                    title: 'Mi Clase',
                    body: 'Matching por clase: encuentra familias con hijos en tus clases, sin compartir teléfonos.',
                  ),
                  featureCard(
                    icon: Icons.work_outline,
                    title: 'Talento del Cole',
                    body: 'Directorio profesional interno + anuncios (servicios, oficios, clases particulares).',
                  ),
                  featureCard(
                    icon: Icons.auto_stories_outlined,
                    title: 'BiblioCircular',
                    body: 'Intercambio de libros y material escolar dentro del colegio.',
                  ),
                  featureCard(
                    icon: Icons.tips_and_updates_outlined,
                    title: 'Trucos de los Veteranos',
                    body: 'Consejos reales: qué llevar, qué evitar, cómo sobrevivir al primer mes.',
                  ),
                  const SizedBox(height: 14),
                  Text('Privacidad (no negociable)', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Bullet(text: 'No se muestran teléfonos.'),
                          _Bullet(text: 'No se permiten fotos de menores.'),
                          _Bullet(text: 'Aislamiento estricto por colegio (schoolId).'),
                          _Bullet(text: 'Borrado completo de cuenta (GDPR).'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.index, required this.text});

  final String index;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(
              child: Text(
                index,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, size: 18, color: theme.colorScheme.tertiary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
