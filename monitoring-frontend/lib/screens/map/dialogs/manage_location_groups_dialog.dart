import 'package:flutter/material.dart';
import '../../../models/location.dart';
import '../../../services/map_service.dart';

class ManageLocationGroupsDialog extends StatefulWidget {
  const ManageLocationGroupsDialog({super.key});

  @override
  State<ManageLocationGroupsDialog> createState() =>
      _ManageLocationGroupsDialogState();
}

class _ManageLocationGroupsDialogState
    extends State<ManageLocationGroupsDialog> {
  final MapService _service = MapService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  List<LocationGroup> _groups = [];
  LocationGroup? _editing;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() => _isLoading = true);
    try {
      final data = await _service.getLocationGroups();
      if (!mounted) return;
      setState(() {
        _groups = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed loading groups: $e")),
      );
    }
  }

  void _bindEdit(LocationGroup group) {
    setState(() {
      _editing = group;
      _nameController.text = group.name;
      _descController.text = group.description ?? "";
    });
  }

  void _clearForm() {
    setState(() {
      _editing = null;
      _nameController.clear();
      _descController.clear();
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Group name is required")),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final payload = {
        "name": name,
        "description": _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
      };

      if (_editing == null) {
        await _service.createLocationGroup(payload);
      } else {
        await _service.updateLocationGroup(_editing!.groupId, payload);
      }

      _hasChanges = true;
      _clearForm();
      await _loadGroups();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_editing == null ? "Group added" : "Group updated"),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Save failed: $e")));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete(LocationGroup group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Group?"),
        content: Text("Delete '${group.name}'?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _service.deleteLocationGroup(group.groupId);
      _hasChanges = true;
      await _loadGroups();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Group deleted")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Delete failed: $e")));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Manage Location Groups"),
      content: SizedBox(
        width: 760,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.white,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: _nameController,
                            decoration:
                                const InputDecoration(labelText: "Group Name"),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _descController,
                            maxLines: 3,
                            decoration:
                                const InputDecoration(labelText: "Description"),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: _isSaving ? null : _save,
                                icon: const Icon(Icons.save),
                                label: Text(_editing == null
                                    ? "Add Group"
                                    : "Update Group"),
                              ),
                              if (_editing != null) ...[
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: _isSaving ? null : _clearForm,
                                  child: const Text("Cancel Edit"),
                                ),
                              ]
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 6,
                    child: Container(
                      height: 360,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.white,
                      ),
                      child: ListView.separated(
                        itemCount: _groups.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final group = _groups[i];
                          return ListTile(
                            title: Text(group.name),
                            subtitle: Text(group.description ?? "-"),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.blue),
                                  onPressed: () => _bindEdit(group),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () => _delete(group),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _hasChanges),
          child: const Text("Close"),
        ),
      ],
    );
  }
}
