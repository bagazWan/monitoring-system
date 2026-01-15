class Alert {
  final int alertId;
  final int? deviceId;
  final int? switchId;
  final String deviceName;
  final String locationName;
  final String alertType;
  final String severity;
  final String message;
  final String status;
  final String? assignedToUserId;
  final DateTime createdAt;
  final DateTime? clearedAt;

  Alert({
    required this.alertId,
    this.deviceId,
    this.switchId,
    required this.deviceName,
    required this.locationName,
    required this.alertType,
    required this.severity,
    required this.message,
    required this.status,
    this.assignedToUserId,
    required this.createdAt,
    this.clearedAt,
  });

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      alertId: json['alert_id'],
      deviceId: json['device_id'],
      switchId: json['switch_id'],
      deviceName: json['device_name'] ?? ' - ',
      locationName: json['location_name'] ?? ' - ',
      alertType: json['alert_type'] ?? 'Unknown',
      severity: json['severity'] ?? 'info',
      message: json['message'] ?? '',
      status: json['status'] ?? 'active',
      assignedToUserId: json['assigned_to_user_id'],
      createdAt: DateTime.parse(json['created_at']),
      clearedAt: json['cleared_at'] != null
          ? DateTime.parse(json['cleared_at'])
          : null,
    );
  }
}
