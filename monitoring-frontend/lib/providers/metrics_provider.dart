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
}
