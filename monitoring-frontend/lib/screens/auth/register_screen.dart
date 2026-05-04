import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/hover_link.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/loading_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  bool _isLoading = false;

  void _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await _authService.register(
          username: _usernameController.text,
          email: _emailController.text,
          password: _passwordController.text,
          fullName: _fullNameController.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Registrasi berhasil"),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(e.toString()), backgroundColor: Colors.red));
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
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                      child: Text("Buat Akun",
                          style: TextStyle(
                              fontSize: 28, fontWeight: FontWeight.bold))),
                  const SizedBox(height: 32),
                  AppTextField(
                    label: "Nama Lengkap",
                    controller: _fullNameController,
                    isRequired: true,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: "Username",
                    controller: _usernameController,
                    isRequired: true,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: "Email",
                    controller: _emailController,
                    isRequired: true,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: "Password",
                    controller: _passwordController,
                    obscureText: true,
                    validator: (val) => val == null || val.length < 6
                        ? "Minimum 6 karakter"
                        : null,
                  ),
                  const SizedBox(height: 32),
                  LoadingButton(
                    isLoading: _isLoading,
                    onPressed: _handleRegister,
                    label: "Register",
                    height: 50,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      HoverLink(
                        text: "Login",
                        icon: Icons.arrow_back_sharp,
                        onTap: () => Navigator.pop(context),
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
