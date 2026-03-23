import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/role_selector_screen.dart';
import 'screens/passenger/passenger_main_screen.dart';
import 'screens/driver/driver_main_screen.dart';
import 'screens/dispatcher/dispatcher_home_screen.dart';
import 'screens/shared/history_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
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

    // Не залогінений — показуємо логін
    if (!auth.isLoggedIn) {
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
