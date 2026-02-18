import 'package:flutter/material.dart';
import '../../../models/user.dart';
import '../../../services/user_service.dart';

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
                Text(widget.user == null ? "User created" : "User updated")));
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
      title: Text(isEdit ? "Edit User" : "Add New User"),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField("Username", _usernameController,
                    required: true),
                const SizedBox(height: 16),
                _buildTextField("Full Name", _fullNameController),
                const SizedBox(height: 16),
                _buildTextField("Email", _emailController, email: true),
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
                  decoration: _inputDecoration("Role"),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  isEdit
                      ? "Password (Leave blank to keep current)"
                      : "Password",
                  _passwordController,
                  required: !isEdit,
                  obscure: true,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[700],
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(isEdit ? "Save Changes" : "Create User"),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {bool required = false, bool obscure = false, bool email = false}) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: (v) {
        if (required && (v == null || v.isEmpty)) return "Required";
        if (email && v != null && v.isNotEmpty && !v.contains('@'))
          return "Invalid Email";
        return null;
      },
      decoration: _inputDecoration(label),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.grey[50],
      isDense: true,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.blue, width: 1.5)),
    );
  }
}
