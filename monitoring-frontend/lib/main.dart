import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/auth_gate.dart';
import 'screens/devices/register_node_screen.dart';
import 'widgets/visual_feedback.dart';
import 'screens/map/location_management_screen.dart';

void main() {
  usePathUrlStrategy();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Network Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.light,
        ),
      ),
      home: const ErrorBoundary(child: AuthGate()),
      routes: {
        '/register': (context) => const RegisterScreen(),
        '/register-node': (context) => const RegisterNodeScreen(),
        '/location-management': (context) => const LocationManagementScreen(),
      },
    );
  }
}
