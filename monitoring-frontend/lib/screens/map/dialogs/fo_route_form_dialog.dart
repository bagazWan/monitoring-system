import 'package:flutter/material.dart';
import '../../../models/fo_route.dart';
import '../../../models/network_node.dart';
import '../../../services/map_service.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/common/loading_button.dart';

class FORouteFormDialog extends StatefulWidget {
  final FORoute? route;
  const FORouteFormDialog({super.key, this.route});

  @override
  State<FORouteFormDialog> createState() => _FORouteFormDialogState();
}

class _FORouteFormDialogState extends State<FORouteFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _service = MapService();
  bool _isLoading = false;
  bool _fetchingNodes = true;

  late TextEditingController _lengthController;
  late TextEditingController _descController;

  int? _startNodeId;
  int? _endNodeId;
  List<NetworkNode> _nodes = [];

  @override
  void initState() {
    super.initState();
    final r = widget.route;
    _lengthController = TextEditingController(text: r?.length.toString() ?? "");
    _descController = TextEditingController(text: r?.description ?? "");
    _startNodeId = r?.startNodeId;
    _endNodeId = r?.endNodeId;

    _loadNodes();
  }

  @override
  void dispose() {
    _lengthController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadNodes() async {
    try {
      final nodes = await _service.getNetworkNodes();
      if (mounted) {
        setState(() {
          _nodes = nodes;
          _fetchingNodes = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal memuat node: $e")),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startNodeId == null || _endNodeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pilih node awal dan akhir")),
      );
      return;
    }

    if (_startNodeId == _endNodeId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Node awal dan akhir tidak bisa sama")),
      );
      return;
    }

    setState(() => _isLoading = true);

    final data = {
      "start_node_id": _startNodeId,
      "end_node_id": _endNodeId,
      "length_m": double.tryParse(_lengthController.text) ?? 0.0,
      "description": _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
    };

    try {
      if (widget.route == null) {
        await _service.createFORoute(data);
      } else {
        await _service.updateFORoute(widget.route!.id, data);
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
    final isEdit = widget.route != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(isEdit ? "Edit Jalur FO" : "Tambah Jalur FO"),
      content: SizedBox(
        width: 500,
        child: _fetchingNodes
            ? const SizedBox(
                height: 100, child: Center(child: CircularProgressIndicator()))
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildNodeDropdown("Node Awal", _startNodeId, (val) {
                        setState(() => _startNodeId = val);
                      }),
                      const SizedBox(height: 16),
                      _buildNodeDropdown("Node Akhir", _endNodeId, (val) {
                        setState(() => _endNodeId = val);
                      }),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: "Panjang (meter)",
                        controller: _lengthController,
                        isRequired: true,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: "Deskripsi",
                        controller: _descController,
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal")),
        LoadingButton(
          isLoading: _isLoading,
          onPressed: _submit,
          label: isEdit ? "Simpan Perubahan" : "Buat Garis Jalur",
          width: 180,
          height: 40,
        ),
      ],
    );
  }

  Widget _buildNodeDropdown(
      String label, int? value, Function(int?) onChanged) {
    return DropdownButtonFormField<int>(
      value: value,
      items: _nodes
          .map((node) => DropdownMenuItem(
                value: node.id,
                child: Text(node.name ?? "Node #${node.id}",
                    style: const TextStyle(fontSize: 14)),
              ))
          .toList(),
      onChanged: onChanged,
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
