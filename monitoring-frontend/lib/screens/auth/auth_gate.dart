import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../main_layout.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _authService = AuthService();
  late Future<bool> _initialSession;

  @override
  void initState() {
    super.initState();
    _initialSession = _authService.hasValidSession();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _initialSession,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return StreamBuilder<bool>(
          stream: _authService.authStateChanges,
          initialData: snapshot.data ?? false,
          builder: (context, streamSnapshot) {
            final isLoggedIn = streamSnapshot.data ?? false;

            if (isLoggedIn) {
              return const MainLayout();
            } else {
              return const LoginScreen();
            }
          },
        );
      },
    );
  }
}
