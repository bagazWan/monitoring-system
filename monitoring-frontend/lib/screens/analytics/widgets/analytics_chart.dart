import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../models/analytics_data_point.dart';

class AnalyticsLineChart extends StatelessWidget {
  final List<AnalyticsDataPoint> dataA;
  final List<AnalyticsDataPoint> dataB;
  final String? locationA;
  final String? locationB;
  final DateTimeRange dateRange;
  final String metric;
  final bool isLoading;

  const AnalyticsLineChart({
    super.key,
    required this.dataA,
    required this.dataB,
    required this.locationA,
    required this.locationB,
    required this.dateRange,
    required this.metric,
    required this.isLoading,
  });

  double _getMetricValue(AnalyticsDataPoint point) {
    switch (metric) {
      case 'inbound':
        return point.inboundMbps;
      case 'outbound':
        return point.outboundMbps;
      case 'latency':
        return point.latencyMs ?? 0.0;
      default:
        return 0.0;
    }
  }

  List<FlSpot> _getSpots(List<AnalyticsDataPoint> data) {
    return data
        .map((d) => FlSpot(
              d.timestamp.millisecondsSinceEpoch.toDouble(),
              _getMetricValue(d),
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasLocA = locationA != null && locationA != "-";
    final hasLocB = locationB != null && locationB != "-";

    if (!hasLocA && !hasLocB) {
      return const Center(child: Text("Select a location to view metrics."));
    }

    final spotsA = _getSpots(dataA);
    final spotsB = _getSpots(dataB);

    if (spotsA.isEmpty && spotsB.isEmpty) {
      return const Center(
          child: Text("No historical data found for this period."));
    }

    final minX = DateTime(
            dateRange.start.year, dateRange.start.month, dateRange.start.day)
        .millisecondsSinceEpoch
        .toDouble();
    final maxX = DateTime(dateRange.end.year, dateRange.end.month,
            dateRange.end.day, 23, 59, 59)
        .millisecondsSinceEpoch
        .toDouble();

    final durationDays = dateRange.end.difference(dateRange.start).inDays;
    double xInterval;
    if (durationDays <= 1) {
      xInterval = 2 * 3600 * 1000;
    } else if (durationDays <= 3) {
      xInterval = 6 * 3600 * 1000;
    } else if (durationDays <= 7) {
      xInterval = 24 * 3600 * 1000;
    } else {
      xInterval = 2 * 24 * 3600 * 1000;
    }

    double maxY = 10;
    for (var spot in [...spotsA, ...spotsB]) {
      if (spot.y > maxY) maxY = spot.y;
    }
    double niceMaxY = (maxY / 10).ceil() * 10.0;
    if (niceMaxY < 10) niceMaxY = 10;
    double yInterval = niceMaxY / 5;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (hasLocA) ...[
              Container(width: 12, height: 12, color: Colors.blue),
              const SizedBox(width: 8),
              Text(locationA!.replaceAll('↳', '').trim(),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
            if (hasLocA && hasLocB) const SizedBox(width: 24),
            if (hasLocB) ...[
              Container(width: 12, height: 12, color: Colors.orange),
              const SizedBox(width: 8),
              Text(locationB!.replaceAll('↳', '').trim(),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ],
        ),
        const SizedBox(height: 32),
        Expanded(
          child: LineChart(
            LineChartData(
              minX: minX,
              maxX: maxX,
              minY: 0,
              maxY: niceMaxY,
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final date =
                          DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
                      final timeStr = DateFormat('dd/MM HH:mm').format(date);
                      return LineTooltipItem(
                        '$timeStr\n${spot.y.toStringAsFixed(2)}',
                        TextStyle(
                          color: spot.bar.color ?? Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
              lineBarsData: [
                if (spotsA.isNotEmpty)
                  LineChartBarData(
                    spots: spotsA,
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                  ),
                if (spotsB.isNotEmpty)
                  LineChartBarData(
                    spots: spotsB,
                    isCurved: true,
                    color: Colors.orange,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                  ),
              ],
              titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: yInterval,
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: xInterval,
                    getTitlesWidget: (value, meta) {
                      if (value == maxX || value == minX) {
                        return const SizedBox.shrink();
                      }
                      final date =
                          DateTime.fromMillisecondsSinceEpoch(value.toInt());
                      final text = durationDays > 1
                          ? DateFormat('dd/MM').format(date)
                          : DateFormat('HH:mm').format(date);
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(text,
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey)),
                      );
                    },
                  ),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                horizontalInterval: yInterval,
                verticalInterval: xInterval,
              ),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
      ],
    );
  }
}
