import 'package:flutter/material.dart';
import '../../../models/setting.dart';

class RuleCard extends StatelessWidget {
  final int index;
  final String deviceType;
  final ThresholdRule rule;
  final ValueChanged<ThresholdRule> onChanged;
  final VoidCallback onDelete;

  const RuleCard({
    super.key,
    required this.index,
    required this.deviceType,
    required this.rule,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Rule #${index + 1}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black54)),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: "Hapus Rule",
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: rule.metricType.isEmpty
                            ? 'latency'
                            : rule.metricType,
                        decoration: const InputDecoration(
                            labelText: "Tipe Metrik",
                            isDense: true,
                            border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(
                              value: 'latency', child: Text("Latency (ms)")),
                          DropdownMenuItem(
                              value: 'bandwidth_in',
                              child: Text("Bandwidth In (Mbps)")),
                          DropdownMenuItem(
                              value: 'bandwidth_out',
                              child: Text("Bandwidth Out (Mbps)")),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            onChanged(ThresholdRule(
                              metricType: val,
                              condition: rule.condition,
                              warningValue: rule.warningValue,
                              criticalValue: rule.criticalValue,
                            ));
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: rule.condition,
                        decoration: const InputDecoration(
                            labelText: "Kondisi Pemicu",
                            isDense: true,
                            border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(
                              value: 'above',
                              child: Text("Melebihi (Lebih besar dari)")),
                          DropdownMenuItem(
                              value: 'below',
                              child: Text("Menurun (Lebih kecil dari)")),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            onChanged(ThresholdRule(
                              metricType: rule.metricType,
                              condition: val,
                              warningValue: rule.warningValue,
                              criticalValue: rule.criticalValue,
                            ));
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('${deviceType}_warning_$index'),
                        initialValue: rule.warningValue.toString(),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: "Batas Warning",
                            isDense: true,
                            border: OutlineInputBorder()),
                        onChanged: (val) {
                          onChanged(ThresholdRule(
                            metricType: rule.metricType,
                            condition: rule.condition,
                            warningValue: double.tryParse(val) ?? 0.0,
                            criticalValue: rule.criticalValue,
                          ));
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('${deviceType}_critical_$index'),
                        initialValue: rule.criticalValue.toString(),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: "Batas Critical",
                            isDense: true,
                            border: OutlineInputBorder()),
                        onChanged: (val) {
                          onChanged(ThresholdRule(
                            metricType: rule.metricType,
                            condition: rule.condition,
                            warningValue: rule.warningValue,
                            criticalValue: double.tryParse(val) ?? 0.0,
                          ));
                        },
                      ),
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
