import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'data/app_store.dart';
import 'screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'ro';
  await initializeDateFormatting('ro');
  final store = AppStore();
  await store.init();
  runApp(
    ChangeNotifierProvider.value(value: store, child: const PescarDeltaApp()),
  );
}

class PescarDeltaApp extends StatelessWidget {
  const PescarDeltaApp({super.key});

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness b) => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1E6F6A),
        brightness: b,
      ),
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        isDense: true,
      ),
    );
    return MaterialApp(
      title: 'Pescar Deltă',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      locale: const Locale('ro'),
      supportedLocales: const [Locale('ro'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomeShell(),
    );
  }
}
