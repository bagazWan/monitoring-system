import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AnalyticsSidebar extends StatelessWidget {
  final List<String> allLocations;
  final String? locationA;
  final String? locationB;
  final Function(String?) onLocationAChanged;
  final Function(String?) onLocationBChanged;
  final DateTimeRange dateRange;
  final VoidCallback onDateRangePressed;
  final String selectedMetric;
  final Function(String) onMetricChanged;

  const AnalyticsSidebar({
    super.key,
    required this.allLocations,
    required this.locationA,
    required this.locationB,
    required this.onLocationAChanged,
    required this.onLocationBChanged,
    required this.dateRange,
    required this.onDateRangePressed,
    required this.selectedMetric,
    required this.onMetricChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Lokasi",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          _buildDropdown("Lokasi 1", locationA, onLocationAChanged),
          const SizedBox(height: 16),
          _buildDropdown("Lokasi 2", locationB, onLocationBChanged),
          const SizedBox(height: 32),
          const Text("Periode Waktu",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.date_range, size: 18),
              label: Text(
                "${DateFormat('dd/MM/yy').format(dateRange.start)} - ${DateFormat('dd/MM/yy').format(dateRange.end)}",
                style: const TextStyle(fontSize: 13),
              ),
              onPressed: onDateRangePressed,
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text("Metrik",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: selectedMetric,
                items: const [
                  DropdownMenuItem(
                      value: 'inbound', child: Text('Inbound (Mbps)')),
                  DropdownMenuItem(
                      value: 'outbound', child: Text('Outbound (Mbps)')),
                  DropdownMenuItem(
                      value: 'latency', child: Text('Latensi (ms)')),
                ],
                onChanged: (val) {
                  if (val != null) onMetricChanged(val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
      String label, String? value, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              items: allLocations.map((loc) {
                return DropdownMenuItem(
                  value: loc,
                  child: Text(loc, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
