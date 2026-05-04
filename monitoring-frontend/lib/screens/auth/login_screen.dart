import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/hover_link.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/loading_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await _authService.login(
            _usernameController.text, _passwordController.text);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Login Berhasil"), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text("Error: ${e.toString()}"),
                backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 450,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextField(
                    label: "Username",
                    controller: _usernameController,
                    prefixIcon: const Icon(Icons.person_outline),
                    isRequired: true,
                  ),
                  const SizedBox(height: 20),
                  AppTextField(
                    label: "Password",
                    controller: _passwordController,
                    prefixIcon: const Icon(Icons.lock_outline),
                    obscureText: true,
                    validator: (val) =>
                        val == null || val.length < 6 ? "Terlalu pendek" : null,
                  ),
                  const SizedBox(height: 32),
                  LoadingButton(
                    isLoading: _isLoading,
                    onPressed: _handleLogin,
                    label: "Log In",
                    height: 50,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      HoverLink(
                        text: "Register",
                        icon: Icons.arrow_forward_sharp,
                        onTap: () => Navigator.pushNamed(context, '/register'),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
