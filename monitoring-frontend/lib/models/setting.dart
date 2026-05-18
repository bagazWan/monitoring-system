class SystemConfig {
  final int pingFrequency;
  final int pingProbeCount;
  final int pingTimeoutMs;
  final int offlineFailRequired;
  final int recoverySuccessRequired;
  final int alertRaiseStreak;
  final int alertClearStreak;
  final int historyIntervalSeconds;
  final int historyRetentionDays;
  final int alertRetentionDays;
  final int topDownMinAlertDurationMinutes;

  SystemConfig(
      {required this.pingFrequency,
      required this.pingProbeCount,
      required this.pingTimeoutMs,
      required this.offlineFailRequired,
      required this.recoverySuccessRequired,
      required this.alertRaiseStreak,
      required this.alertClearStreak,
      required this.historyIntervalSeconds,
      required this.historyRetentionDays,
      required this.alertRetentionDays,
      required this.topDownMinAlertDurationMinutes});

  factory SystemConfig.fromJson(Map<String, dynamic> json) {
    return SystemConfig(
        pingFrequency: json['ping_frequency'] ?? 5,
        pingProbeCount: json['ping_probe_count'] ?? 3,
        pingTimeoutMs: json['ping_timeout_ms'] ?? 1000,
        offlineFailRequired: json['offline_fail_required'] ?? 3,
        recoverySuccessRequired: json['recovery_success_required'] ?? 2,
        alertRaiseStreak: json['alert_raise_streak'] ?? 2,
        alertClearStreak: json['alert_clear_streak'] ?? 2,
        historyIntervalSeconds: json['history_interval_seconds'] ?? 300,
        historyRetentionDays: json['history_retention_days'] ?? 365,
        alertRetentionDays: json['alert_retention_days'] ?? 300,
        topDownMinAlertDurationMinutes:
            json['top_down_min_alert_duration_minutes'] ?? 30);
  }

  Map<String, dynamic> toJson() {
    return {
      'ping_frequency': pingFrequency,
      'ping_probe_count': pingProbeCount,
      'ping_timeout_ms': pingTimeoutMs,
      'offline_fail_required': offlineFailRequired,
      'recovery_success_required': recoverySuccessRequired,
      'alert_raise_streak': alertRaiseStreak,
      'alert_clear_streak': alertClearStreak,
      'history_interval_seconds': historyIntervalSeconds,
      'history_retention_days': historyRetentionDays,
      'alert_retention_days': alertRetentionDays,
      'top_down_min_alert_duration_minutes': topDownMinAlertDurationMinutes
    };
  }
}

class ThresholdRule {
  final String metricType; // 'latency', 'bandwidth_in', 'bandwidth_out'
  final String condition; // 'above', 'below'
  final double warningValue;
  final double criticalValue;

  ThresholdRule({
    required this.metricType,
    required this.condition,
    required this.warningValue,
    required this.criticalValue,
  });

  factory ThresholdRule.fromJson(Map<String, dynamic> json) {
    return ThresholdRule(
      metricType: json['metric_type'] ?? '',
      condition: json['condition'] ?? 'above',
      warningValue: (json['warning_value'] as num?)?.toDouble() ?? 0.0,
      criticalValue: (json['critical_value'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'metric_type': metricType,
      'condition': condition,
      'warning_value': warningValue,
      'critical_value': criticalValue,
    };
  }
}
