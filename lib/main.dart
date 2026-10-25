import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/inicio_page.dart';

void main() {
  runApp(const ProviderScope(child: ColecaoApp()));
}

class ColecaoApp extends StatelessWidget {
  const ColecaoApp({super.key});

  @override
  Widget build(BuildContext context) {
    const semente = Color(0xFF2E6B3F);
    return MaterialApp(
      title: 'DXA Coleções',
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: semente),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: semente,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const InicioPage(),
    );
  }
}
