import 'package:flutter/material.dart';
import '../../../models/location.dart';
import '../../../services/location_service.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/common/loading_button.dart';

class LocationFormDialog extends StatefulWidget {
  final Location? location;
  const LocationFormDialog({super.key, this.location});

  @override
  State<LocationFormDialog> createState() => _LocationFormDialogState();
}

class _LocationFormDialogState extends State<LocationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _service = LocationService();

  late TextEditingController _nameController;
  late TextEditingController _addrController;
  late TextEditingController _latController;
  late TextEditingController _lngController;
  late TextEditingController _descController;
  late TextEditingController _typeController;

  int? _selectedGroupId;
  bool _isLoadingGroups = true;
  bool _isSaving = false;
  List<LocationGroup> _groups = [];

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadGroups();
  }

  void _initControllers() {
    final d = widget.location;
    _nameController = TextEditingController(text: d?.name ?? "");
    _addrController = TextEditingController(text: d?.address ?? "");
    _latController =
        TextEditingController(text: d != null ? d.latitude.toString() : "");
    _lngController =
        TextEditingController(text: d != null ? d.longitude.toString() : "");
    _descController = TextEditingController(text: d?.description ?? "");
    _typeController = TextEditingController(text: d?.type ?? "");
    _selectedGroupId = d?.groupId;
  }

  Future<void> _loadGroups() async {
    setState(() => _isLoadingGroups = true);
    try {
      final groups = await _service.getLocationGroups();
      if (!mounted) return;

      setState(() {
        _groups = groups;
        _isLoadingGroups = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingGroups = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal memuat group lokasi: $e")));
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

    final d = widget.location;
    final name = _nameController.text.trim();
    final latitude = double.tryParse(_latController.text.trim());
    final longitude = double.tryParse(_lngController.text.trim());

    if (name.isEmpty ||
        latitude == null ||
        longitude == null ||
        _selectedGroupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Isi semua kolom yang diperlukan dan pilih group.")));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final payload = {
        "name": name,
        "address": _addrController.text.trim(),
        "latitude": latitude,
        "longitude": longitude,
        "location_type": _typeController.text.trim(),
        "description": _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        "group_id": _selectedGroupId,
      };

      if (d == null) {
        await _service.createLocation(payload);
      } else {
        await _service.updateLocation(d.id, payload);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(d == null ? "Lokasi dibuat" : "Lokasi diperbarui")));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Save gagal: $e")));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.location != null;
    final displayGroups = _getSortedDisplayGroups();

    return AlertDialog(
      title: Text(isEdit ? "Edit Titik Lokasi" : "Tambah Titik Lokasi"),
      content: SizedBox(
        width: 520,
        child: _isLoadingGroups
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppTextField(
                        label: "Nama Lokasi",
                        controller: _nameController,
                        isRequired: true,
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        label: "Alamat",
                        controller: _addrController,
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        label: "Tipe Lokasi (contoh, gerbang_tol)",
                        controller: _typeController,
                        isRequired: true,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: _selectedGroupId,
                        decoration: InputDecoration(
                          labelText: "Seksi Induk / Group",
                          hintText: "Pilih Seksi/Gerbang",
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
                        ),
                        validator: (v) => v == null ? "Pilih group" : null,
                        items: displayGroups.map((group) {
                          final isChild = group.parentId != null;
                          return DropdownMenuItem<int>(
                            value: group.groupId,
                            child: Padding(
                              padding:
                                  EdgeInsets.only(left: isChild ? 16.0 : 0.0),
                              child: Text(
                                group.name,
                                style: TextStyle(
                                  fontWeight: isChild
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                  color: isChild
                                      ? Colors.black87
                                      : Colors.blueAccent,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setState(() => _selectedGroupId = val),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              label: "Latitude",
                              controller: _latController,
                              keyboardType: TextInputType.number,
                              validator: (v) =>
                                  v == null || double.tryParse(v.trim()) == null
                                      ? "Required"
                                      : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: AppTextField(
                              label: "Longitude",
                              controller: _lngController,
                              keyboardType: TextInputType.number,
                              validator: (v) =>
                                  v == null || double.tryParse(v.trim()) == null
                                      ? "Required"
                                      : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
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
          onPressed: () => Navigator.pop(context, false),
          child: const Text("Batal"),
        ),
        LoadingButton(
          isLoading: _isLoadingGroups || _isSaving,
          onPressed: _submit,
          label: isEdit ? "Simpan Perubahan" : "Buat Lokasi",
          width: 160,
          height: 40,
        ),
      ],
    );
  }
}
