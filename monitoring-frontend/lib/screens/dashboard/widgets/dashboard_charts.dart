import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'network_activity_chart.dart';
import '../../../models/dashboard_stats.dart';

class DashboardCharts extends StatelessWidget {
  final List<NetworkActivityData> trafficData;
  final bool isTrafficLoading;
  final List<UptimeTrendPoint> uptimeData;
  final bool isUptimeLoading;

  const DashboardCharts({
    super.key,
    required this.trafficData,
    required this.isTrafficLoading,
    required this.uptimeData,
    required this.isUptimeLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Performance Chart",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1000;

            if (isWide) {
              const double cardHeight = 312;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: cardHeight,
                      child: NetworkActivityChart(
                        data: trafficData,
                        isLoading: isTrafficLoading,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: cardHeight,
                      child: _UptimeTrendChart(
                        data: uptimeData,
                        isLoading: isUptimeLoading,
                      ),
                    ),
                  ),
                ],
              );
            }

            const double stackedHeight = 320;

            return Column(
              children: [
                SizedBox(
                  height: stackedHeight,
                  child: NetworkActivityChart(
                    data: trafficData,
                    isLoading: isTrafficLoading,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: stackedHeight,
                  child: _UptimeTrendChart(
                    data: uptimeData,
                    isLoading: isUptimeLoading,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _UptimeTrendChart extends StatelessWidget {
  final List<UptimeTrendPoint> data;
  final bool isLoading;

  const _UptimeTrendChart({
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
            "Devices Uptime/Availability",
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
        child: Text(
          "No uptime data",
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: 100,
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 20,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 20,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= data.length) {
                  return const SizedBox.shrink();
                }
                final label = data[idx].date.toIso8601String().substring(5, 10);
                return Text(
                  label,
                  style: TextStyle(fontSize: 9, color: Colors.grey[600]),
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
            spots: data
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value.uptimePercentage))
                .toList(),
            isCurved: true,
            curveSmoothness: 0.3,
            color: Colors.green,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.green.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }
}
