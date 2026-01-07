class DashboardStats {
  final int totalDevices;
  final int onlineDevices;
  final int activeAlerts;
  final double? totalBandwidth;

  DashboardStats({
    required this.totalDevices,
    required this.onlineDevices,
    required this.activeAlerts,
    required this.totalBandwidth,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalDevices: json['total_all_devices'] ?? 0,
      onlineDevices: json['all_online_devices'] ?? 0,
      activeAlerts: json['active_alerts'] ?? 0,
      totalBandwidth: json['total_bandwidth'] != null
          ? (json['total_bandwidth'] as num).toDouble()
          : null,
    );
  }
}
