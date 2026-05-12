import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/websocket_service.dart';

class MetricsProvider extends ChangeNotifier {
  final Map<int, Map<String, dynamic>> _deviceMetrics = {};
  final Map<int, Map<String, dynamic>> _switchMetrics = {};
  StreamSubscription? _metricsSub;

  MetricsProvider() {
    _initListener();
  }

  Iterable<Map<String, dynamic>> get allDeviceMetrics => _deviceMetrics.values;
  Iterable<Map<String, dynamic>> get allSwitchMetrics => _switchMetrics.values;

  double get totalLiveBandwidth {
    double total = 0;
    for (var d in _deviceMetrics.values) {
      total += (d['in_mbps'] ?? 0) + (d['out_mbps'] ?? 0);
    }
    for (var s in _switchMetrics.values) {
      total += (s['in_mbps'] ?? 0) + (s['out_mbps'] ?? 0);
    }
    return total;
  }

  void _initListener() {
    _metricsSub = WebSocketService().metricsUpdates.listen((data) {
      bool hasChanges = false;

      final devices = data['device_metrics'] as List<dynamic>? ?? [];
      for (var d in devices) {
        final id = d['device_id'] as int;
        _deviceMetrics[id] = d as Map<String, dynamic>;
        hasChanges = true;
      }

      final switches = data['switch_metrics'] as List<dynamic>? ?? [];
      for (var s in switches) {
        final id = s['switch_id'] as int;
        _switchMetrics[id] = s as Map<String, dynamic>;
        hasChanges = true;
      }

      if (hasChanges) {
        notifyListeners();
      }
    });
  }

  Map<String, dynamic>? getDeviceMetrics(int id) => _deviceMetrics[id];
  Map<String, dynamic>? getSwitchMetrics(int id) => _switchMetrics[id];

  @override
  void dispose() {
    _metricsSub?.cancel();
    super.dispose();
  }

  Map<String, dynamic> getFilteredDashboardMetrics(
      {String? locationName, String? deviceType}) {
    double totalIn = 0.0;
    double totalOut = 0.0;
    int offlineCount = 0;

    double totalLatency = 0.0;
    int latencyCount = 0;

    void processItem(Map<String, dynamic> item, bool isSwitch) {
      if (deviceType != null) {
        if (isSwitch && deviceType.toLowerCase() != 'switch') return;
        if (!isSwitch &&
            (item['device_type']?.toString().toLowerCase() !=
                deviceType.toLowerCase())) return;
      }

      if (locationName != null) {
        String filterLoc =
            locationName.replaceAll('↳', '').trim().toLowerCase();

        String itemLoc =
            (item['location_name']?.toString() ?? '').trim().toLowerCase();
        String itemGroup =
            (item['location_group']?.toString() ?? '').trim().toLowerCase();
        String itemParent =
            (item['location_parent']?.toString() ?? '').trim().toLowerCase();

        if (itemLoc != filterLoc &&
            itemGroup != filterLoc &&
            itemParent != filterLoc) {
          return;
        }
      }

      totalIn += (item['in_mbps'] as num?)?.toDouble() ?? 0.0;
      totalOut += (item['out_mbps'] as num?)?.toDouble() ?? 0.0;

      String status = item['status']?.toString().toLowerCase() ?? 'offline';
      if (status == 'offline' || status == 'down' || status == 'critical') {
        offlineCount++;
      }

      final latency = (item['latency_ms'] as num?)?.toDouble();
      if (latency != null && !latency.isNaN) {
        totalLatency += latency;
        latencyCount++;
      }
    }

    for (var d in _deviceMetrics.values) processItem(d, false);
    for (var s in _switchMetrics.values) processItem(s, true);

    double avgLatency = latencyCount > 0 ? (totalLatency / latencyCount) : 0.0;

    return {
      'total_in': totalIn,
      'total_out': totalOut,
      'total_bandwidth': totalIn + totalOut,
      'offline_count': offlineCount,
      'average_latency': avgLatency,
    };
  }
}
