import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../widgets/filter_dropdown.dart';

class AlertFilterBar extends StatelessWidget {
  final VoidCallback? onRefresh;
  final String? selectedSeverity;
  final ValueChanged<String?>? onSeverityChanged;
  final VoidCallback? onClear;

  // alert log tab filter
  final DateTimeRange? selectedDateRange;
  final ValueChanged<DateTimeRange?>? onDateRangeChanged;
  final String? selectedStatus;
  final ValueChanged<String?>? onStatusChanged;

  // active alert tab filter
  final String? selectedLocation;
  final List<String>? locations;
  final ValueChanged<String?>? onLocationChanged;

  final Widget? trailingAction;

  const AlertFilterBar({
    super.key,
    this.onRefresh,
    this.selectedSeverity,
    this.onSeverityChanged,
    this.selectedDateRange,
    this.onDateRangeChanged,
    this.selectedStatus,
    this.onStatusChanged,
    this.selectedLocation,
    this.locations,
    this.onLocationChanged,
    this.onClear,
    this.trailingAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (onDateRangeChanged != null)
            Container(
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextButton.icon(
                icon: const Icon(Icons.calendar_month, size: 18),
                label: Text(
                  selectedDateRange == null
                      ? "Filter Date"
                      : "${DateFormat('dd/MM').format(selectedDateRange!.start)} - ${DateFormat('dd/MM').format(selectedDateRange!.end)}",
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2023),
                    lastDate: DateTime.now(),
                    initialDateRange: selectedDateRange,
                  );
                  if (picked != null) onDateRangeChanged!(picked);
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          if (onSeverityChanged != null)
            FilterDropdown(
              label: "Severity",
              value: selectedSeverity,
              items: const ["critical", "warning", "info"],
              onChanged: onSeverityChanged!,
            ),
          if (onStatusChanged != null)
            FilterDropdown(
              label: "Status",
              value: selectedStatus,
              items: const ["active", "cleared"],
              onChanged: onStatusChanged!,
            ),
          if (onLocationChanged != null)
            FilterDropdown(
              label: "Location",
              value: selectedLocation,
              items: locations ?? [],
              onChanged: onLocationChanged!,
            ),
          if (onRefresh != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: onRefresh,
            ),
          if (onClear != null)
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.clear_all, size: 16),
              label: const Text("Clear"),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red[700],
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          if (trailingAction != null) trailingAction!,
        ],
      ),
    );
  }
}
