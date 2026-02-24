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

class DashboardTraffic {
  final DateTime timestamp;
  final double? inboundMbps;
  final double? outboundMbps;

  DashboardTraffic({
    required this.timestamp,
    required this.inboundMbps,
    required this.outboundMbps,
  });

  factory DashboardTraffic.fromJson(Map<String, dynamic> json) {
    return DashboardTraffic(
      timestamp: DateTime.parse(json['timestamp']),
      inboundMbps: json['inbound_mbps'] == null
          ? null
          : (json['inbound_mbps'] as num).toDouble(),
      outboundMbps: json['outbound_mbps'] == null
          ? null
          : (json['outbound_mbps'] as num).toDouble(),
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
  final List<DeviceTypeStats> deviceTypeStats;
  final int topDownWindowDays;
  final int cctvTotal;
  final int cctvOnline;
  final double cctvUptimePercentage;

  DashboardStats({
    required this.totalDevices,
    required this.onlineDevices,
    required this.activeAlerts,
    required this.totalBandwidth,
    required this.uptimePercentage,
    required this.topDownLocations,
    required this.deviceTypeStats,
    required this.topDownWindowDays,
    required this.cctvTotal,
    required this.cctvOnline,
    required this.cctvUptimePercentage,
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
      deviceTypeStats: (json['device_type_stats'] as List? ?? [])
          .map((e) => DeviceTypeStats.fromJson(e))
          .toList(),
      topDownWindowDays: json['top_down_window_days'] ?? 7,
      cctvTotal: json['cctv_total'] ?? 0,
      cctvOnline: json['cctv_online'] ?? 0,
      cctvUptimePercentage: (json['cctv_uptime_percentage'] ?? 0.0).toDouble(),
    );
  }
}

class UptimeTrendPoint {
  final DateTime date;
  final double? uptimePercentage;

  UptimeTrendPoint({
    required this.date,
    required this.uptimePercentage,
  });

  factory UptimeTrendPoint.fromJson(Map<String, dynamic> json) {
    return UptimeTrendPoint(
      date: DateTime.parse(json['date']),
      uptimePercentage: json['uptime_percentage'] != null
          ? (json['uptime_percentage'] as num).toDouble()
          : null,
    );
  }
}

class UptimeTrendResponse {
  final int days;
  final List<UptimeTrendPoint> data;

  UptimeTrendResponse({
    required this.days,
    required this.data,
  });

  factory UptimeTrendResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['data'] as List? ?? [];
    return UptimeTrendResponse(
      days: json['days'] ?? 7,
      data: raw.map((e) => UptimeTrendPoint.fromJson(e)).toList(),
    );
  }
}

class DeviceTypeStats {
  final String deviceType;
  final int count;

  DeviceTypeStats({
    required this.deviceType,
    required this.count,
  });

  factory DeviceTypeStats.fromJson(Map<String, dynamic> json) {
    return DeviceTypeStats(
      deviceType: json['device_type'] ?? 'Unknown',
      count: json['count'] ?? 0,
    );
  }
}
