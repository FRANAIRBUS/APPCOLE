import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'firebase_options.dart';
import 'router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    // Necesario para que los enlaces tipo https://coleconecta.app/invite?... funcionen
    // (sin #/). Firebase Hosting ya reescribe a /index.html.
    usePathUrlStrategy();
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: ColeConectaApp()));
}

class ColeConectaApp extends ConsumerWidget {
  const ColeConectaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final base = ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6E7CFF),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );
    return MaterialApp.router(
      title: 'ColeConecta',
      theme: base.copyWith(
        scaffoldBackgroundColor: const Color(0xFF10131A),
        canvasColor: const Color(0xFF10131A),
        visualDensity: VisualDensity.standard,
        appBarTheme: AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          backgroundColor: const Color(0xFF10131A),
          foregroundColor: base.colorScheme.onSurface,
          titleTextStyle:
              base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: base.colorScheme.surfaceContainerLow,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: base.colorScheme.outlineVariant),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: base.colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: base.colorScheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: base.colorScheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: base.colorScheme.primary, width: 1.4),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: base.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            side: BorderSide(color: base.colorScheme.outlineVariant),
            textStyle: base.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          elevation: 0,
          backgroundColor: base.colorScheme.surfaceContainerLow,
          indicatorColor: base.colorScheme.primary.withValues(alpha: 0.12),
          labelTextStyle: WidgetStatePropertyAll(
              base.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
        ),
        chipTheme: base.chipTheme.copyWith(
          backgroundColor: base.colorScheme.surfaceContainerHighest,
          side: BorderSide(color: base.colorScheme.outlineVariant),
          labelStyle: base.textTheme.labelLarge?.copyWith(
            color: base.colorScheme.onSurface,
          ),
        ),
        dividerTheme: DividerThemeData(color: base.colorScheme.outlineVariant),
      ),
      builder: (context, child) {
        final bg = Theme.of(context).scaffoldBackgroundColor;
        return ColoredBox(color: bg, child: child ?? const SizedBox.shrink());
      },
      routerConfig: router,
    );
  }
}
