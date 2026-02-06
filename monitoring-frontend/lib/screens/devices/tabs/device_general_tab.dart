import 'package:flutter/material.dart';
import '../../../models/device.dart';
import '../../../models/location.dart';

typedef SaveCallback = Future<void> Function(
    String name, String ip, int? locId, String? desc);
typedef DangerActionCallback = Future<void> Function(String action);

class DeviceGeneralTab extends StatefulWidget {
  final BaseNode node;
  final List<Location> locations;
  final int? currentLibreNmsId;
  final SaveCallback onSave;
  final DangerActionCallback onDangerAction;

  const DeviceGeneralTab({
    super.key,
    required this.node,
    required this.locations,
    required this.currentLibreNmsId,
    required this.onSave,
    required this.onDangerAction,
  });

  @override
  State<DeviceGeneralTab> createState() => _DeviceGeneralTabState();
}

class _DeviceGeneralTabState extends State<DeviceGeneralTab> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _ipController;
  late TextEditingController _descController;
  int? _selectedLocationId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.node.name);
    _ipController = TextEditingController(text: widget.node.ipAddress);
    _descController =
        TextEditingController(text: widget.node.description ?? "");
    _selectedLocationId = widget.node.locationId;
  }

  @override
  void didUpdateWidget(covariant DeviceGeneralTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node != widget.node) {
      _nameController.text = widget.node.name;
      _ipController.text = widget.node.ipAddress;
      _descController.text = widget.node.description ?? "";
      _selectedLocationId = widget.node.locationId;
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await widget.onSave(
      _nameController.text.trim(),
      _ipController.text.trim(),
      _selectedLocationId,
      _descController.text.trim().isEmpty ? null : _descController.text.trim(),
    );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionCard("Identity Information", [
              _buildTextField("Display Name", _nameController),
              const SizedBox(height: 16),
              _buildTextField("IP Address", _ipController),
            ]),
            const SizedBox(height: 24),
            _buildSectionCard("Location & Details", [
              DropdownButtonFormField<int>(
                value: _selectedLocationId,
                items: widget.locations
                    .map((l) =>
                        DropdownMenuItem(value: l.id, child: Text(l.name)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedLocationId = val),
                decoration: _inputDecoration("Location"),
              ),
              const SizedBox(height: 16),
              _buildTextField("Description", _descController,
                  maxLines: 3, required: false),
            ]),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: _saving ? const SizedBox() : const Icon(Icons.save),
                label: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("SAVE CHANGES",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
                onPressed: _saving ? null : _handleSave,
              ),
            ),
            const SizedBox(height: 40),
            _buildDangerZone(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title.toUpperCase(),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                  letterSpacing: 1.0)),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildDangerZone() {
    final isUnmonitored = widget.currentLibreNmsId == null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          if (isUnmonitored) ...[
            _buildRealButton(
              title: "Reconnect to monitoring",
              subtitle: "Restores monitoring for this device in LibreNMS.",
              icon: Icons.link,
              color: Colors.green,
              onTap: () => widget.onDangerAction('reconnect'),
              isFilled: true,
            ),
          ] else ...[
            _buildRealButton(
              title: "Unregister (stop monitoring)",
              subtitle:
                  "Keeps the record in database but stops collecting data.",
              icon: Icons.link_off,
              color: Colors.orange,
              onTap: () => widget.onDangerAction('unregister'),
              isFilled: false,
            ),
          ],
          const SizedBox(height: 12),
          _buildRealButton(
            title: "Delete device completely",
            subtitle: "Permanently removes this device and all its history.",
            icon: Icons.delete_forever,
            color: Colors.red,
            onTap: () => widget.onDangerAction('delete'),
            isFilled: true,
          ),
        ],
      ),
    );
  }

  Widget _buildRealButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required MaterialColor color,
    required VoidCallback onTap,
    required bool isFilled,
  }) {
    final childContent = Row(
      children: [
        Icon(icon, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.normal,
                      color: isFilled ? Colors.white70 : Colors.grey[700])),
            ],
          ),
        ),
      ],
    );

    if (isFilled) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 1,
          ),
          onPressed: onTap,
          child: childContent,
        ),
      );
    } else {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: color[800],
            backgroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            side: BorderSide(color: color[300]!, width: 1.5),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: onTap,
          child: childContent,
        ),
      );
    }
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {int maxLines = 1, bool required = true}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: (v) =>
          (required && (v == null || v.isEmpty)) ? "Required" : null,
      decoration: _inputDecoration(label),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.grey[50],
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
