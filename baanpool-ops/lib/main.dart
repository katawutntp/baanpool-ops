import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'services/auth_state_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use path URL strategy (no /#/ in URLs)
  usePathUrlStrategy();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Initialize auth state (loads current user profile + role)
  await AuthStateService().init();

  runApp(const BaanPoolApp());
}

/// Global Supabase client accessor
final supabase = Supabase.instance.client;

class BaanPoolApp extends StatelessWidget {
  const BaanPoolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'BaanPool Ops',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      routerConfig: appRouter,
    );
  }
}
