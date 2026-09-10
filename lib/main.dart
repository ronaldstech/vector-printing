import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/record_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/security_provider.dart';
import 'services/auth_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/security/app_lock_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Try to initialize Firebase if configured, but gracefully allow offline / local mode
  await AuthService.initializeFirebase();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => RecordProvider()..fetchRecords()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SecurityProvider()),
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
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
    super.didChangeAppLifecycleState(state);
    final security = Provider.of<SecurityProvider>(context, listen: false);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      security.handleAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      security.handleAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) => MaterialApp(
        title: 'Vector Printing',
        debugShowCheckedModeBanner: false,
        themeMode: themeProvider.themeMode,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        home: Consumer2<AuthService, SecurityProvider>(
          builder: (context, auth, security, _) {
            Widget currentScreen;
            if (auth.isAuthenticated) {
              currentScreen = const MainNavigationScreen();
            } else {
              currentScreen = const LoginScreen();
            }

            // If security lock is active, show the lock screen over the app
            if (auth.isAuthenticated && security.isSecurityEnabled && security.isLocked) {
              return const AppLockScreen();
            }

            return currentScreen;
          },
        ),
      ),
    );
  }

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0284C7),
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: brightness == Brightness.dark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      dividerColor: scheme.outlineVariant,
    );
  }
}
