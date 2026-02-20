import 'package:flutter/material.dart';
import '../../../models/dashboard_stats.dart';
import '../../../widgets/filter_dropdown.dart';

class DashboardTopDown extends StatelessWidget {
  final DashboardStats stats;
  final int selectedWindowDays;
  final ValueChanged<int> onWindowChanged;

  const DashboardTopDown({
    super.key,
    required this.stats,
    required this.selectedWindowDays,
    required this.onWindowChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = <int, String>{
      7: "Last 7 days",
      30: "Last 30 days",
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                "Top Down Locations",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(
              width: 170,
              child: FilterDropdown(
                label: "Window",
                value: options[selectedWindowDays],
                items: options.values.toList(),
                showAllOption: false,
                onChanged: (value) {
                  final entry =
                      options.entries.firstWhere((e) => e.value == value);
                  onWindowChanged(entry.key);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (stats.topDownLocations.isEmpty)
          _buildInfoCard("No down locations in this period.")
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: stats.topDownLocations.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (context, index) {
                final item = stats.topDownLocations[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red.withOpacity(0.12),
                    child: Text("${index + 1}",
                        style: const TextStyle(color: Colors.red)),
                  ),
                  title: Text(item.locationName),
                  trailing: Text(
                    "${item.offlineCount} issues",
                    style: const TextStyle(
                        color: Colors.redAccent, fontWeight: FontWeight.w600),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildInfoCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(message),
    );
  }
}
