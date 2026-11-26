import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app/palette.dart';
import 'providers/analysis_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/tickets_provider.dart';
import 'features/resolve/cases_store.dart';
import 'services/api_service.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Pal.nav,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  await ApiService.load();
  runApp(const HTHApp());
}

class HTHApp extends StatelessWidget {
  const HTHApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TicketsProvider()),
        ChangeNotifierProvider(create: (_) => AnalysisProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => CasesStore()..load()),
      ],
      child: MaterialApp(
        title: 'HTH Support AI',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: Pal.bg,
          colorScheme: const ColorScheme.dark(
            primary: Pal.blue,
            surface: Pal.bg,
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}