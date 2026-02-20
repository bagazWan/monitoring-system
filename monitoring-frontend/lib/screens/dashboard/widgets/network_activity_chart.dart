import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class NetworkActivityData {
  final DateTime timestamp;
  final double inbound; // Mbps
  final double outbound; // Mbps

  NetworkActivityData({
    required this.timestamp,
    required this.inbound,
    required this.outbound,
  });
}

class NetworkActivityChart extends StatefulWidget {
  final List<NetworkActivityData> data;
  final bool isLoading;

  const NetworkActivityChart({
    super.key,
    required this.data,
    this.isLoading = false,
  });

  @override
  State<NetworkActivityChart> createState() => _NetworkActivityChartState();
}

class _NetworkActivityChartState extends State<NetworkActivityChart> {
  bool _showInbound = true;
  bool _showOutbound = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildLegend(),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: widget.isLoading ? _buildLoadingState() : _buildChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Network Traffic',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          'Last 30 minutes',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Row(
      children: [
        _buildLegendItem(
          color: Colors.blue,
          label: 'Inbound',
          isActive: _showInbound,
          onTap: () => setState(() => _showInbound = !_showInbound),
        ),
        const SizedBox(width: 16),
        _buildLegendItem(
          color: Colors.green,
          label: 'Outbound',
          isActive: _showOutbound,
          onTap: () => setState(() => _showOutbound = !_showOutbound),
        ),
        const Spacer(),
        if (widget.data.isNotEmpty) _buildCurrentStats(),
      ],
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: isActive ? color : color.withOpacity(0.3),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? Colors.black87 : Colors.grey[400],
              decoration: isActive ? null : TextDecoration.lineThrough,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStats() {
    if (widget.data.isEmpty) return const SizedBox.shrink();

    final latest = widget.data.last;
    return Row(
      children: [
        _buildStatChip(
          icon: Icons.arrow_downward,
          value: '${latest.inbound.toStringAsFixed(1)} Mbps',
          color: Colors.blue,
        ),
        const SizedBox(width: 8),
        _buildStatChip(
          icon: Icons.arrow_upward,
          value: '${latest.outbound.toStringAsFixed(1)} Mbps',
          color: Colors.green,
        ),
      ],
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }

  Widget _buildChart() {
    if (widget.data.isEmpty) {
      return Center(
        child: Text(
          'No traffic data available',
          style: TextStyle(color: Colors.grey[500], fontSize: 14),
        ),
      );
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _calculateInterval(),
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey[200]!,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: _getTimeInterval(),
              getTitlesWidget: (value, meta) => _buildBottomTitle(value, meta),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: _calculateInterval(),
              getTitlesWidget: (value, meta) => _buildLeftTitle(value, meta),
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          if (_showInbound) _buildInboundLine(),
          if (_showOutbound) _buildOutboundLine(),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => Colors.blueGrey.withOpacity(0.8),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final isInbound = spot.barIndex == 0 && _showInbound;
                return LineTooltipItem(
                  '${spot.y.toStringAsFixed(1)} Mbps',
                  TextStyle(
                    color: isInbound ? Colors.blue[100] : Colors.green[100],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                );
              }).toList();
            },
          ),
        ),
        minY: 0,
      ),
    );
  }

  LineChartBarData _buildInboundLine() {
    return LineChartBarData(
      spots: widget.data.asMap().entries.map((entry) {
        return FlSpot(entry.key.toDouble(), entry.value.inbound);
      }).toList(),
      isCurved: true,
      curveSmoothness: 0.3,
      color: Colors.blue,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: Colors.blue.withOpacity(0.1),
      ),
    );
  }

  LineChartBarData _buildOutboundLine() {
    return LineChartBarData(
      spots: widget.data.asMap().entries.map((entry) {
        return FlSpot(entry.key.toDouble(), entry.value.outbound);
      }).toList(),
      isCurved: true,
      curveSmoothness: 0.3,
      color: Colors.green,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: Colors.green.withOpacity(0.1),
      ),
    );
  }

  double _calculateInterval() {
    if (widget.data.isEmpty) return 10;
    double maxValue = 0;
    for (var d in widget.data) {
      if (d.inbound > maxValue) maxValue = d.inbound;
      if (d.outbound > maxValue) maxValue = d.outbound;
    }
    if (maxValue <= 10) return 2;
    if (maxValue <= 50) return 10;
    if (maxValue <= 100) return 20;
    return (maxValue / 5).roundToDouble();
  }

  double _getTimeInterval() {
    final count = widget.data.length;
    if (count <= 10) return 1;
    if (count <= 20) return 3;
    return 5;
  }

  Widget _buildBottomTitle(double value, TitleMeta meta) {
    final index = value.toInt();
    if (index < 0 || index >= widget.data.length) {
      return const SizedBox.shrink();
    }

    final time = widget.data[index].timestamp.toLocal();
    final label =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
      ),
    );
  }

  Widget _buildLeftTitle(double value, TitleMeta meta) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Text(
        value.toInt().toString(),
        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
      ),
    );
  }
}
