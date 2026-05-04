import 'package:flutter/material.dart';
import '../../../widgets/components/filter_dropdown.dart';

class DashboardFilters extends StatelessWidget {
  final bool isLoading;
  final List<String> locationFilters;
  final String? selectedLocationFilter;
  final ValueChanged<String?> onLocationChanged;

  const DashboardFilters({
    super.key,
    required this.isLoading,
    required this.locationFilters,
    required this.selectedLocationFilter,
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

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        SizedBox(
          width: 260,
          child: FilterDropdown(
            label: "Lokasi",
            value: selectedLocationFilter,
            items: locationFilters,
            onChanged: onLocationChanged,
          ),
        ),
      ],
    );
  }
}
