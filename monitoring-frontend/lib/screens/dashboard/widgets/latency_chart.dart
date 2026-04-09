import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../models/dashboard_stats.dart';

class LatencyChart extends StatelessWidget {
  final List<DashboardTraffic> data;
  final bool isLoading;

  const LatencyChart({
    super.key,
    required this.data,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Average Network Latency",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _buildChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    if (data.isEmpty) {
      return Center(
        child:
            Text("No latency data", style: TextStyle(color: Colors.grey[500])),
      );
    }

    final hasValidData = data.any((e) => e.latencyMs != null);
    if (!hasValidData) {
      return Center(
        child: Text("Waiting for ping data...",
            style: TextStyle(color: Colors.grey[500])),
      );
    }

    final spots = data.asMap().entries.map((e) {
      final y = e.value.latencyMs;
      return y == null ? FlSpot.nullSpot : FlSpot(e.key.toDouble(), y);
    }).toList();

    double labelInterval = 1;
    if (data.length > 5) {
      labelInterval = (data.length / 5).ceilToDouble();
    }

    return LineChart(
      LineChartData(
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => Colors.blueGrey.withOpacity(0.9),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            tooltipPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              return touchedSpots.map((spot) {
                if (spot.isNull()) return null;

                final index = spot.x.toInt();
                if (index < 0 || index >= data.length) return null;

                final time = data[index].timestamp.toLocal();
                final timeStr =
                    "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";

                return LineTooltipItem(
                  '$timeStr\n',
                  const TextStyle(color: Colors.white, fontSize: 10),
                  children: [
                    TextSpan(
                      text: '${spot.y.toStringAsFixed(2)} ms',
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
        minY: 0,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: labelInterval,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();

                if (index < 0 || index >= data.length) {
                  return const SizedBox.shrink();
                }

                final time = data[index].timestamp.toLocal();
                final timeStr =
                    "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";

                return SideTitleWidget(
                  meta: meta,
                  space: 8.0,
                  child: Text(
                    timeStr,
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: Colors.orange,
            barWidth: 2,
            dotData: FlDotData(
              show: true,
              checkToShowDot: (spot, barData) => !spot.isNull(),
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                radius: 4,
                color: Colors.orange,
                strokeWidth: 2,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.orange.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }
}
