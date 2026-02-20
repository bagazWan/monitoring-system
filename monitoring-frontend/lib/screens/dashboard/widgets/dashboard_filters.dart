import 'package:flutter/material.dart';
import '../../../models/location.dart';
import '../../../widgets/filter_dropdown.dart';

class DashboardFilters extends StatelessWidget {
  final bool isLoading;
  final List<Location> locations;
  final String? selectedLocationName;
  final ValueChanged<String?> onLocationChanged;

  const DashboardFilters({
    super.key,
    required this.isLoading,
    required this.locations,
    required this.selectedLocationName,
    required this.onLocationChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: 36,
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final locationNames = locations.map((e) => e.name).toList();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        SizedBox(
          width: 220,
          child: FilterDropdown(
            label: "Location",
            value: selectedLocationName,
            items: locationNames,
            onChanged: onLocationChanged,
          ),
        ),
      ],
    );
  }
}
