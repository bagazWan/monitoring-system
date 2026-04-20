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

  int? _selectedGroupId;
  List<LocationGroup> _groups = [];

  @override
  void initState() {
    super.initState();
    final location = widget.location;
    _nameController = TextEditingController(text: location?.name ?? "");
    _addrController = TextEditingController(text: location?.address ?? "");
    _latController = TextEditingController(
      text: location != null ? location.latitude.toString() : "",
    );
    _lngController = TextEditingController(
      text: location != null ? location.longitude.toString() : "",
    );
    _descController = TextEditingController(text: location?.description ?? "");
    _typeController = TextEditingController(text: location?.type ?? "");
    _selectedGroupId = location?.groupId;
    _loadGroups();
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

  Future<void> _loadGroups() async {
    final data = await _service.getLocationGroups();
    if (!mounted) return;
    setState(() => _groups = data);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final payload = {
      "name": _nameController.text.trim(),
      "address": _addrController.text.trim(),
      "latitude": double.tryParse(_latController.text.trim()) ?? 0.0,
      "longitude": double.tryParse(_lngController.text.trim()) ?? 0.0,
      "location_type": _typeController.text.trim(),
      "description": _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      "group_id": _selectedGroupId,
    };

    try {
      if (widget.location == null) {
        await _service.createLocation(payload);
      } else {
        await _service.updateLocation(widget.location!.id, payload);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
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
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? "Required" : null,
                  decoration: const InputDecoration(labelText: "Location Name"),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addrController,
                  decoration: const InputDecoration(labelText: "Address"),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _typeController,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? "Required" : null,
                  decoration: const InputDecoration(labelText: "Location Type"),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _selectedGroupId,
                  items: _groups
                      .map(
                        (group) => DropdownMenuItem<int>(
                          value: group.groupId,
                          child: Text(group.name),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedGroupId = v),
                  decoration:
                      const InputDecoration(labelText: "Group (Optional)"),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latController,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: "Latitude"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lngController,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: "Longitude"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: "Description"),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEdit ? "Save Changes" : "Create Location"),
        ),
      ],
    );
  }
}
