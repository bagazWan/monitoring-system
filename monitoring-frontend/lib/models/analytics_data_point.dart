class AnalyticsDataPoint {
  final DateTime timestamp;
  final double inboundMbps;
  final double outboundMbps;
  final double? latencyMs;

  AnalyticsDataPoint({
    required this.timestamp,
    required this.inboundMbps,
    required this.outboundMbps,
    this.latencyMs,
  });

  factory AnalyticsDataPoint.fromJson(Map<String, dynamic> json) {
    return AnalyticsDataPoint(
      timestamp: DateTime.parse(json['timestamp']),
      inboundMbps: (json['inbound_mbps'] as num).toDouble(),
      outboundMbps: (json['outbound_mbps'] as num).toDouble(),
      latencyMs: json['latency_ms'] == null
          ? null
          : (json['latency_ms'] as num).toDouble(),
    );
  }
}
