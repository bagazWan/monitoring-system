import 'package:flutter/material.dart';
import '../../../models/dashboard_stats.dart';
import '../../../widgets/components/filter_dropdown.dart';

class DashboardTopDown extends StatefulWidget {
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
  State<DashboardTopDown> createState() => _DashboardTopDownState();
}

class _DashboardTopDownState extends State<DashboardTopDown> {
  bool _onlyTollGates = true;

  @override
  Widget build(BuildContext context) {
    final options = <int, String>{
      7: "7 hari terakhir",
      30: "30 hari terakhir",
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(
              child: Text(
                "List Lokasi Sering Gangguan",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            FilterChip(
              label: const Text("Gerbang Tol"),
              selected: _onlyTollGates,
              backgroundColor: Colors.white,
              selectedColor: Colors.white,
              side: const BorderSide(color: Colors.black12),
              onSelected: (v) => setState(() => _onlyTollGates = v),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 150,
              child: FilterDropdown(
                label: "Window",
                value: options[widget.selectedWindowDays],
                items: options.values.toList(),
                showAllOption: false,
                onChanged: (value) {
                  final entry =
                      options.entries.firstWhere((e) => e.value == value);
                  widget.onWindowChanged(entry.key);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (widget.stats.topDownLocations.isEmpty)
          _buildInfoCard("Tidak ada alert critical pada periode ini.")
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.stats.topDownLocations.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Colors.grey.shade200),
                itemBuilder: (context, index) {
                  final item = widget.stats.topDownLocations[index];
                  final hasChildren =
                      item.children != null && item.children!.isNotEmpty;

                  final leading = CircleAvatar(
                    backgroundColor: Colors.red.withOpacity(0.12),
                    child: Text("${index + 1}",
                        style: const TextStyle(color: Colors.red)),
                  );
                  final title = Text(item.locationName,
                      style: const TextStyle(fontWeight: FontWeight.bold));
                  final trailing = Text(
                    "${item.offlineCount} masalah",
                    style: const TextStyle(
                        color: Colors.redAccent, fontWeight: FontWeight.w600),
                  );

                  if (!hasChildren) {
                    return ListTile(
                        leading: leading, title: title, trailing: trailing);
                  }

                  final filteredChildren = item.children!.where((child) {
                    if (!_onlyTollGates) return true;
                    return child.locationName.toLowerCase().contains('gerbang');
                  }).toList();

                  if (filteredChildren.isEmpty) {
                    return ListTile(
                        leading: leading, title: title, trailing: trailing);
                  }

                  return ExpansionTile(
                    leading: leading,
                    title: title,
                    trailing: trailing,
                    children: filteredChildren.asMap().entries.map((entry) {
                      int childIndex = entry.key + 1;
                      LocationDownSummary child = entry.value;

                      return Container(
                        color: Colors.grey[50],
                        child: ListTile(
                          contentPadding:
                              const EdgeInsets.only(left: 72, right: 16),
                          title: Text("$childIndex. ${child.locationName}",
                              style: const TextStyle(fontSize: 14)),
                          trailing: Text(
                            "${child.offlineCount} masalah",
                            style: const TextStyle(
                                color: Colors.redAccent, fontSize: 13),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
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
