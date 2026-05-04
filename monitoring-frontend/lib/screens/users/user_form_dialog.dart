import 'package:flutter/material.dart';
import '../../../models/user.dart';
import '../../../services/user_service.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/common/loading_button.dart';

class UserFormDialog extends StatefulWidget {
  final User? user;
  const UserFormDialog({super.key, this.user});

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _userService = UserService();
  bool _isLoading = false;

  late TextEditingController _usernameController;
  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  String _selectedRole = 'viewer';

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _usernameController = TextEditingController(text: u?.username ?? "");
    _fullNameController = TextEditingController(text: u?.fullName ?? "");
    _emailController = TextEditingController(text: u?.email ?? "");
    _passwordController = TextEditingController();
    if (u != null) {
      _selectedRole = u.role;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final data = {
        "username": _usernameController.text.trim(),
        "full_name": _fullNameController.text.trim(),
        "email": _emailController.text.trim(),
        "role": _selectedRole,
      };

      if (widget.user == null || _passwordController.text.isNotEmpty) {
        data["password"] = _passwordController.text;
      }

      if (widget.user == null) {
        await _userService.createUser(data);
      } else {
        await _userService.updateUser(widget.user!.id, data);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(widget.user == null ? "User dibuat" : "User diperbarui")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.user != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(isEdit ? "Edit User" : "Tambah User Baru"),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  label: "Username",
                  controller: _usernameController,
                  isRequired: true,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: "Nama Lengkap",
                  controller: _fullNameController,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: "Email",
                  controller: _emailController,
                  validator: (v) {
                    if (v != null && v.isNotEmpty && !v.contains('@')) {
                      return "Email invalid";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  items: ['admin', 'teknisi', 'viewer']
                      .map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(r.toUpperCase()),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedRole = v!),
                  decoration: InputDecoration(
                    labelText: "Role",
                    filled: true,
                    fillColor: Colors.grey[50],
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 16),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: Colors.blue, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: isEdit
                      ? "Password (Kosongkan untuk menggunakan data saat ini)"
                      : "Password",
                  controller: _passwordController,
                  isRequired: !isEdit,
                  obscureText: true,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Batal"),
        ),
        LoadingButton(
          isLoading: _isLoading,
          onPressed: _submit,
          label: isEdit ? "Simpan" : "Buat User",
          width: 120,
          height: 40,
        ),
      ],
    );
  }
}
