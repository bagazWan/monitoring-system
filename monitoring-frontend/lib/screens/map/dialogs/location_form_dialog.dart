import 'package:flutter/material.dart';
import '../../../models/location.dart';
import '../../../services/map_service.dart';

class LocationFormDialog extends StatefulWidget {
  final Location? location;
  const LocationFormDialog({super.key, this.location});

  @override
  State<LocationFormDialog> createState() => _LocationFormDialogState();
}

class _LocationFormDialogState extends State<LocationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _service = MapService();
  bool _isLoading = false;

  late TextEditingController _nameController;
  late TextEditingController _addrController;
  late TextEditingController _latController;
  late TextEditingController _lngController;
  late TextEditingController _descController;
  late TextEditingController _typeController;

  @override
  void initState() {
    super.initState();
    final l = widget.location;
    _nameController = TextEditingController(text: l?.name ?? "");
    _addrController = TextEditingController(text: l?.address ?? "");
    _latController = TextEditingController(text: l?.latitude.toString());
    _lngController = TextEditingController(text: l?.longitude.toString());
    _descController = TextEditingController(text: l?.description ?? "");
    _typeController = TextEditingController(text: l?.type ?? "");
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addrController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _descController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final data = {
      "name": _nameController.text.trim(),
      "address": _addrController.text.trim(),
      "latitude": double.tryParse(_latController.text) ?? 0.0,
      "longitude": double.tryParse(_lngController.text) ?? 0.0,
      "location_type": _typeController.text.trim(),
      "description": _descController.text.trim(),
    };

    try {
      if (widget.location == null) {
        await _service.createLocation(data);
      } else {
        await _service.updateLocation(widget.location!.id, data);
      }
      if (mounted) Navigator.pop(context, true);
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
    final isEdit = widget.location != null;
    return AlertDialog(
      title: Text(isEdit ? "Edit Location" : "Add Location"),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildField("Location Name", _nameController, required: true),
                const SizedBox(height: 16),
                _buildField("Address", _addrController),
                const SizedBox(height: 16),
                _buildField("Type", _typeController),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: _buildField("Latitude", _latController,
                            keyboard: TextInputType.number)),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _buildField("Longitude", _lngController,
                            keyboard: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildField("Description", _descController, maxLines: 3),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel")),
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
              : Text(isEdit ? "Save Changes" : "Create Location"),
        ),
      ],
    );
  }

  Widget _buildField(String label, TextEditingController ctrl,
      {bool required = false,
      int maxLines = 1,
      TextInputType keyboard = TextInputType.text}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboard,
      validator: required ? (v) => v!.isEmpty ? "Required" : null : null,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey[50],
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!)),
      ),
    );
  }
}
