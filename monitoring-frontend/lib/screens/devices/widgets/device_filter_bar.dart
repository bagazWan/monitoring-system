import 'package:flutter/material.dart';
import '../../../widgets/filter_dropdown.dart';

class DeviceFilterBar extends StatelessWidget {
  final String? selectedType;
  final String? selectedLocation;
  final String? selectedStatus;
  final List<String> deviceTypes;
  final List<String> locations;
  final List<String> statusOptions;
  final void Function(String?) onTypeChanged;
  final void Function(String?) onLocationChanged;
  final void Function(String?) onStatusChanged;
  final VoidCallback onClearFilters;

  const DeviceFilterBar({
    super.key,
    this.selectedType,
    this.selectedLocation,
    this.selectedStatus,
    required this.deviceTypes,
    required this.locations,
    this.statusOptions = const ['online', 'offline'],
    required this.onTypeChanged,
    required this.onLocationChanged,
    required this.onStatusChanged,
    required this.onClearFilters,
  });

  bool get hasActiveFilters =>
      selectedType != null ||
      selectedLocation != null ||
      selectedStatus != null;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilterDropdown(
          label: 'Type',
          value: selectedType,
          items: deviceTypes,
          onChanged: onTypeChanged,
        ),
        FilterDropdown(
          label: 'Location',
          value: selectedLocation,
          items: locations,
          onChanged: onLocationChanged,
        ),
        FilterDropdown(
          label: 'Status',
          value: selectedStatus,
          items: statusOptions,
          onChanged: onStatusChanged,
        ),
        if (hasActiveFilters)
          SizedBox(
            height: 36,
            child: TextButton.icon(
              onPressed: onClearFilters,
              icon: const Icon(Icons.clear_all, size: 16),
              label: const Text('Clear', style: TextStyle(fontSize: 13)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red[700],
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ),
      ],
    );
  }
}
