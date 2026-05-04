import 'package:flutter/material.dart';
import '../../../models/location.dart';

class LocationSearchPickerDialog extends StatefulWidget {
  final List<Location> locations;
  const LocationSearchPickerDialog({super.key, required this.locations});

  @override
  State<LocationSearchPickerDialog> createState() =>
      _LocationSearchPickerDialogState();
}

class _LocationSearchPickerDialogState
    extends State<LocationSearchPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  late List<Location> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.locations;
    _searchController.addListener(_applyFilter);
  }

  void _applyFilter() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = widget.locations;
      } else {
        _filtered = widget.locations.where((location) {
          final name = location.name.toLowerCase();
          final group = (location.groupName ?? '').toLowerCase();
          return name.contains(q) || group.contains(q);
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Pilih Lokasi"),
      content: SizedBox(
        width: 520,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: "Cari lokasi atau group...",
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(child: Text("Tidak ada lokasi yang sesuai"))
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final location = _filtered[index];
                        return ListTile(
                          title: Text(location.name),
                          subtitle: (location.groupName ?? '').isNotEmpty
                              ? Text(location.groupName!)
                              : null,
                          onTap: () => Navigator.pop(context, location.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Batal"),
        ),
      ],
    );
  }
}
