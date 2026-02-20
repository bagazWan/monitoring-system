class LocationDownSummary {
  final int locationId;
  final String locationName;
  final int offlineCount;

  LocationDownSummary({
    required this.locationId,
    required this.locationName,
    required this.offlineCount,
  });

  factory LocationDownSummary.fromJson(Map<String, dynamic> json) {
    return LocationDownSummary(
      locationId: json['location_id'],
      locationName: json['location_name'],
      offlineCount: json['offline_count'],
    );
  }
}

class DashboardStats {
  final int totalDevices;
  final int onlineDevices;
  final int activeAlerts;
  final double? totalBandwidth;
  final double uptimePercentage;
  final List<LocationDownSummary> topDownLocations;

  DashboardStats({
    required this.totalDevices,
    required this.onlineDevices,
    required this.activeAlerts,
    required this.totalBandwidth,
    required this.uptimePercentage,
    required this.topDownLocations,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    final rawBandwidth = json['total_bandwidth'];

    return DashboardStats(
      totalDevices: json['total_all_devices'] ?? 0,
      onlineDevices: json['all_online_devices'] ?? 0,
      activeAlerts: json['active_alerts'] ?? 0,
      totalBandwidth:
          rawBandwidth == null ? null : (rawBandwidth as num).toDouble(),
      uptimePercentage: (json['uptime_percentage'] ?? 0.0).toDouble(),
      topDownLocations: (json['top_down_locations'] as List? ?? [])
          .map((item) => LocationDownSummary.fromJson(item))
          .toList(),
    );
  }
}
