import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AlertLogFilterBar extends StatelessWidget {
  final DateTimeRange? selectedDateRange;
  final ValueChanged<DateTimeRange?> onDateRangeChanged;
  final VoidCallback onRefresh;

  const AlertLogFilterBar({
    super.key,
    required this.selectedDateRange,
    required this.onDateRangeChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.white,
      child: Row(
        children: [
          TextButton.icon(
            icon: const Icon(Icons.calendar_month, size: 18),
            label: Text(
              selectedDateRange == null
                  ? "Filter Date"
                  : "${DateFormat('dd/MM').format(selectedDateRange!.start)} - ${DateFormat('dd/MM').format(selectedDateRange!.end)}",
              style: const TextStyle(fontSize: 12),
            ),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2023),
                lastDate: DateTime.now(),
              );
              if (picked != null) onDateRangeChanged(picked);
            },
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}
