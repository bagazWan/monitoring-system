import 'package:flutter/material.dart';
import '../../../models/location.dart';
import '../../../services/device_service.dart';

class QuickAddLocationDialog extends StatefulWidget {
  final DeviceService service;
  const QuickAddLocationDialog({super.key, required this.service});

  @override
  State<QuickAddLocationDialog> createState() => _QuickAddLocationDialogState();
}

class _QuickAddLocationDialogState extends State<QuickAddLocationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _typeController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  bool _isLoading = false;
  List<LocationGroup> _groups = [];
  int? _selectedGroupId;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      final groups = await widget.service.getLocationGroups();
      if (!mounted) return;
      setState(() => _groups = groups);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed loading groups: $e")),
      );
    }
  }

  List<LocationGroup> _getSortedDisplayGroups() {
    List<LocationGroup> display = [];

    final parents = _groups.where((g) => g.parentId == null).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    for (var p in parents) {
      display.add(p);
      final children = _groups.where((g) => g.parentId == p.groupId).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      display.addAll(children);
    }

    final accounted = display.map((e) => e.groupId).toSet();
    display.addAll(_groups.where((g) => !accounted.contains(g.groupId)));

    return display;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final typeRaw = _typeController.text.trim();
    if (_selectedGroupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a Parent Section / Group")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final created = await widget.service.createLocationQuick({
        "name": _nameController.text.trim(),
        "address": _nameController.text.trim(),
        "location_type": typeRaw,
        "latitude": double.tryParse(_latController.text.trim()) ?? 0.0,
        "longitude": double.tryParse(_lngController.text.trim()) ?? 0.0,
        "group_id": _selectedGroupId,
      });

      if (!mounted) return;
      Navigator.pop(context, created);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to create location: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayGroups = _getSortedDisplayGroups();
    return AlertDialog(
      title: const Text("Add Location"),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? "Required" : null,
                decoration: const InputDecoration(labelText: "Display Name"),
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
                items: displayGroups.map((g) {
                  final isChild = g.parentId != null;
                  return DropdownMenuItem<int>(
                    value: g.groupId,
                    child: Padding(
                      padding: EdgeInsets.only(left: isChild ? 16.0 : 0.0),
                      child: Text(
                        g.name,
                        style: TextStyle(
                          fontWeight:
                              isChild ? FontWeight.normal : FontWeight.bold,
                          color: isChild ? Colors.black87 : Colors.blueAccent,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedGroupId = v),
                decoration:
                    const InputDecoration(labelText: "Parent Section / Group"),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Latitude"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lngController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Longitude"),
                    ),
                  ),
                ],
              ),
            ],
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
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text("Create"),
        ),
      ],
    );
  }
}
