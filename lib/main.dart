import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/app_state.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  final app = await AppState.create();
  runApp(AppScope(state: app, child: const PrismApp()));
}

class PrismApp extends StatefulWidget {
  const PrismApp({super.key});

  @override
  State<PrismApp> createState() => _PrismAppState();
}

class _PrismAppState extends State<PrismApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final app = AppState.read(context);
    if (state == AppLifecycleState.resumed) {
      app.feedback.resumeMusic();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      app.feedback.pauseMusic();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.of(context);
    return MaterialApp(
      title: 'Prism Blocks',
      debugShowCheckedModeBanner: false,
      themeMode: app.themeMode,
      theme: AppTheme.build(Brightness.light),
      darkTheme: AppTheme.build(Brightness.dark),
      home: const HomeScreen(),
    );
  }
}
