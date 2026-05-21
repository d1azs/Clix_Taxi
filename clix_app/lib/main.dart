import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'services/api_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/role_selector_screen.dart';
import 'screens/passenger/passenger_main_screen.dart';
import 'screens/driver/driver_main_screen.dart';
import 'screens/dispatcher/dispatcher_home_screen.dart';
import 'screens/shared/history_screen.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint("CRITICAL_FLUTTER_ERROR: ${details.exception}");
    debugPrint("CRITICAL_STACK_TRACE: ${details.stack}");
  };
  await dotenv.load(fileName: '.env');
  
  if (args.contains('--fresh')) {
    await ApiService().logout();
  }
  
  runApp(const CLIXApp());
}

class CLIXApp extends StatelessWidget {
  const CLIXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider()..tryRestoreSession(),
      child: MaterialApp(
        title: 'CLIX — Таксі в один клік',
        debugShowCheckedModeBanner: false,
        theme: CLIXTheme.lightTheme,
        home: const _AuthGate(),
        routes: {
          '/login': (_) => const LoginScreen(),
          '/select-role': (_) => const RoleSelectorScreen(),
          '/passenger': (_) => const PassengerMainScreen(),
          '/driver': (_) => const DriverMainScreen(),
          '/dispatcher': (_) => const DispatcherHomeScreen(),
          '/history': (_) => const HistoryScreen(),
        },
      ),
    );
  }
}

/// Окремий віджет для навігації — НЕ перебудовує MaterialApp
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    try {
      final file = File('/Users/tohqa/.gemini/antigravity/brain/f4bbc341-4a35-4b24-9643-4d7bf28829a9/scratch/auth_gate.log');
      file.writeAsStringSync(
        '${DateTime.now().toIso8601String()} - isLoggedIn: ${auth.isLoggedIn}, activeRole: ${auth.activeRole}\n',
        mode: FileMode.append,
      );
    } catch (e) {
      // ignore
    }
    print('DEBUG: _AuthGate build - isLoggedIn: ${auth.isLoggedIn}, activeRole: ${auth.activeRole}');

    // Не залогінений — показуємо логін
    if (!auth.isLoggedIn) {
      print('DEBUG: _AuthGate - returning LoginScreen');
      return const LoginScreen();
    }

    // Кілька ролей і ще не обрано — вибір ролі
    if (auth.user!.hasMultipleRoles && auth.activeRole == null) {
      return const RoleSelectorScreen();
    }

    // Навігація за роллю
    switch (auth.activeRole) {
      case 'DRIVER':
        return const DriverMainScreen();
      case 'DISPATCHER':
        return const DispatcherHomeScreen();
      case 'PASSENGER':
      default:
        return const PassengerMainScreen();
    }
  }
}
