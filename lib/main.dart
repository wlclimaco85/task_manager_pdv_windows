import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'screens/login_operador_screen.dart';
import 'services/api_service.dart';
import 'services/pdv_state_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService().init();

  runApp(const PdvApp());
}

class PdvApp extends StatefulWidget {
  const PdvApp({super.key});

  @override
  State<PdvApp> createState() => _PdvAppState();
}

class _PdvAppState extends State<PdvApp> {
  final PdvStateNotifier _notifier = PdvStateNotifier();

  @override
  void dispose() {
    _notifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDV Supermercado NFC-e - App Academia',
      debugShowCheckedModeBanner: false,
      theme: PdvTheme.theme,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: LoginOperadorScreen(notifier: _notifier),
    );
  }
}
