import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/record_provider.dart';
import 'services/auth_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Try to initialize Firebase if configured, but gracefully allow offline / local mode
  await AuthService.initializeFirebase();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => RecordProvider()..fetchRecords()),
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vector Printing',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0284C7), // Vibrant printing cyan/blue
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: Consumer<AuthService>(
        builder: (context, auth, _) {
          if (auth.isAuthenticated) {
            return const MainNavigationScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
