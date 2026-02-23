import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;
            final padding = wide ? const EdgeInsets.symmetric(horizontal: 48, vertical: 28) : const EdgeInsets.all(20);

            final content = _WelcomeContent(
              onLogin: () => context.go('/login'),
            );

            if (!wide) return Padding(padding: padding, child: content);

            return Padding(
              padding: padding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(flex: 6, child: _HeroPanel()),
                  const SizedBox(width: 36),
                  Expanded(flex: 5, child: content),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primaryContainer, cs.secondaryContainer],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school_outlined, size: 28, color: cs.onPrimaryContainer),
              const SizedBox(width: 10),
              Text(
                'ColeConecta',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800, color: cs.onPrimaryContainer),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'La red privada de confianza entre familias del mismo colegio.',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: cs.onPrimaryContainer.withValues(alpha: 0.95)),
          ),
          const SizedBox(height: 18),
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Pill(icon: Icons.lock_outline, label: 'Privada por invitación'),
              _Pill(icon: Icons.domain_verification_outlined, label: 'Multi-colegio aislado'),
              _Pill(icon: Icons.no_cell_outlined, label: 'Sin teléfonos visibles'),
              _Pill(icon: Icons.chat_bubble_outline, label: 'Chat 1:1 interno'),
            ],
          ),
          const SizedBox(height: 22),
          const Divider(height: 1),
          const SizedBox(height: 18),
          Text(
            'Cómo funciona',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700, color: cs.onPrimaryContainer),
          ),
          const SizedBox(height: 10),
          const _StepRow(index: 1, text: 'Inicia sesión o crea tu cuenta.'),
          const SizedBox(height: 8),
          const _StepRow(index: 2, text: 'Introduce el código de invitación del colegio.'),
          const SizedBox(height: 8),
          const _StepRow(index: 3, text: 'Accede a tu clase y conecta con otras familias.'),
          const SizedBox(height: 18),
          Text(
            'ColeConecta no es una red social. Es un entorno privado para ayudar, compartir y coordinarte con familias del mismo colegio.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onPrimaryContainer.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.onSurface),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
          ),
          child: Text(
            '$index',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800, color: cs.primary),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
      ],
    );
  }
}

class _WelcomeContent extends StatelessWidget {
  const _WelcomeContent({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (MediaQuery.of(context).size.width < 980) ...[
          Row(
            children: [
              Icon(Icons.school_outlined, color: cs.primary),
              const SizedBox(width: 8),
              Text('ColeConecta', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Red privada de familias por colegio.',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Accede por invitación. Sin teléfonos visibles. Sin fotos de menores. Chat interno y módulos útiles para el día a día.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Módulos del MVP', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                const _ModuleTile(icon: Icons.handshake_outlined, title: 'Busco / Ofrezco', desc: 'Ayuda rápida entre familias.'),
                const _ModuleTile(icon: Icons.event_outlined, title: 'Entre Padres', desc: 'Eventos y quedadas.'),
                const _ModuleTile(icon: Icons.groups_outlined, title: 'Mi Clase', desc: 'Matching por clase (classIds).'),
                const _ModuleTile(icon: Icons.chat_bubble_outline, title: 'Chat interno', desc: 'Conversaciones 1:1 sin exponer teléfonos.'),
                const Divider(height: 22),
                const _ModuleTile(icon: Icons.star_border, title: 'Talento del Cole', desc: 'Comparte oficios/habilidades (adultos).'),
                const _ModuleTile(icon: Icons.menu_book_outlined, title: 'BiblioCircular', desc: 'Libros que rotan: presta/recibe.'),
                const _ModuleTile(icon: Icons.lightbulb_outline, title: 'Trucos de Veteranos', desc: 'Consejos prácticos y experiencias.'),
                const _ModuleTile(icon: Icons.flag_outlined, title: 'Primer Día, Cero Dudas', desc: 'Checklist y guía de inicio.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Privacidad (no negociable)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                const _Bullet(text: 'Acceso solo por invitación del colegio.'),
                const _Bullet(text: 'Aislamiento estricto por schoolId (multi-colegio).'),
                const _Bullet(text: 'No teléfonos visibles, no fotos de menores.'),
                const _Bullet(text: 'Borrado completo de cuenta (deleteMyAccount).'),
              ],
            ),
          ),
        ),
        const Spacer(),
        FilledButton.icon(
          onPressed: onLogin,
          icon: const Icon(Icons.login),
          label: const Text('Entrar / Crear cuenta'),
        ),
        const SizedBox(height: 8),
        Text(
          'Al iniciar sesión podrás introducir el código de invitación del colegio.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({required this.icon, required this.title, required this.desc});

  final IconData icon;
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.primary.withValues(alpha: 0.22)),
            ),
            child: Icon(icon, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(desc, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
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
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, size: 18, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
