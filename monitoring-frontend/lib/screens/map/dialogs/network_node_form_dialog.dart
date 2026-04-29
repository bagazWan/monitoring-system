import 'package:flutter/material.dart';
import '../../../models/network_node.dart';
import '../../../models/location.dart';
import '../../../services/map_service.dart';
import '../../../services/device_service.dart';
import '../../../widgets/location_search_picker_dialog.dart';

class NetworkNodeFormDialog extends StatefulWidget {
  final NetworkNode? node;
  const NetworkNodeFormDialog({super.key, this.node});

  @override
  State<NetworkNodeFormDialog> createState() => _NetworkNodeFormDialogState();
}

class _NetworkNodeFormDialogState extends State<NetworkNodeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _service = MapService();
  bool _isLoading = false;
  bool _fetchingLocations = true;

  late TextEditingController _nameController;
  late TextEditingController _typeController;
  late TextEditingController _descController;

  int? _selectedLocationId;
  List<Location> _locations = [];

  @override
  void initState() {
    super.initState();
    final n = widget.node;
    _nameController = TextEditingController(text: n?.name ?? "");
    _typeController = TextEditingController(text: n?.type ?? "");
    _descController = TextEditingController(text: n?.description ?? "");
    _selectedLocationId = n?.locationId;
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    try {
      final locs = await DeviceService().getAllLocationOptions();

      if (mounted) {
        setState(() {
          _locations = locs;
          _fetchingLocations = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal memuat lokasi: $e")),
        );
      }
    }
  }

  String _getSelectedLocationName() {
    if (_selectedLocationId == null) return "Pilih lokasi...";
    try {
      return _locations.firstWhere((l) => l.id == _selectedLocationId).name;
    } catch (e) {
      return "Lokasi tidak diketahui";
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLocationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pilih lokasi")),
      );
      return;
    }

    setState(() => _isLoading = true);

    final data = {
      "name": _nameController.text.trim(),
      "node_type": _typeController.text.trim(),
      "location_id": _selectedLocationId,
      "description": _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
    };

    try {
      if (widget.node == null) {
        await _service.createNetworkNode(data);
      } else {
        await _service.updateNetworkNode(widget.node!.id, data);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.node != null;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(isEdit ? "Edit Node Jaringan" : "Tambah Node Jaringan"),
      content: SizedBox(
        width: 500,
        child: _fetchingLocations
            ? const SizedBox(
                height: 100, child: Center(child: CircularProgressIndicator()))
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildField("Nama Node", _nameController, required: true),
                      const SizedBox(height: 16),
                      _buildLocationPicker(),
                      const SizedBox(height: 16),
                      _buildField(
                          "Tipe Node (contoh:ODP, Pole)", _typeController,
                          required: true),
                      const SizedBox(height: 16),
                      _buildField("Deskripsi", _descController, maxLines: 3),
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
              : Text(isEdit ? "Simpan" : "Buat Lokasi"),
        ),
      ],
    );
  }

  Widget _buildField(String label, TextEditingController ctrl,
      {bool required = false, int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14),
      validator:
          required ? (v) => (v == null || v.isEmpty) ? "Required" : null : null,
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

  Widget _buildLocationPicker() {
    return InkWell(
      onTap: () async {
        final selectedId = await showDialog<int>(
          context: context,
          builder: (context) =>
              LocationSearchPickerDialog(locations: _locations),
        );

        if (selectedId != null) {
          setState(() {
            _selectedLocationId = selectedId;
          });
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: "Lokasi",
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                _getSelectedLocationName(),
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.search, size: 20, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
