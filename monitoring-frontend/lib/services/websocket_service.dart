import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../api_config.dart';

class StatusChangeEvent {
  final String nodeType; // device or switch
  final int id;
  final String name;
  final String ipAddress;
  final String oldStatus;
  final String newStatus;
  final DateTime timestamp;

  StatusChangeEvent({
    required this.nodeType,
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.oldStatus,
    required this.newStatus,
    required this.timestamp,
  });

  factory StatusChangeEvent.fromJson(Map<String, dynamic> json) {
    return StatusChangeEvent(
      nodeType: json['node_type'] ?? '',
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      ipAddress: json['ip_address'] ?? '',
      oldStatus: json['old_status'] ?? '',
      newStatus: json['new_status'] ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    );
  }
}

/// Singleton WebSocket service for real-time status updates
class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  bool _isConnected = false;
  bool _shouldReconnect = true;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  static const Duration _reconnectDelay = Duration(seconds: 3);
  static const Duration _pingInterval = Duration(seconds: 30);

  // Stream controllers for broadcasting events
  final _statusChangeController =
      StreamController<StatusChangeEvent>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();
  final _heartbeatController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream of status change events
  Stream<StatusChangeEvent> get statusChanges => _statusChangeController.stream;

  /// Stream of connection state (connected/disconnected)
  Stream<bool> get connectionState => _connectionStateController.stream;

  /// Stream of heartbeat events with summary data
  Stream<Map<String, dynamic>> get heartbeats => _heartbeatController.stream;

  /// Whether currently connected
  bool get isConnected => _isConnected;

  /// Connect to WebSocket server
  Future<void> connect() async {
    if (_isConnected) return;

    _shouldReconnect = true;
    await _attemptConnection();
  }

  Future<void> _attemptConnection() async {
    try {
      // Build WebSocket URL from API config
      final wsUrl = ApiConfig.baseUrl
          .replaceFirst('http://', 'ws://')
          .replaceFirst('https://', 'wss://');
      final uri = Uri.parse('$wsUrl/api/v1/ws/status');

      debugPrint('WebSocket:  Connecting to $uri');

      _channel = WebSocketChannel.connect(uri);

      // Listen to incoming messages
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDone,
        cancelOnError: false,
      );

      _isConnected = true;
      _reconnectAttempts = 0;
      _connectionStateController.add(true);
      _startPingTimer();

      debugPrint('WebSocket: Connected successfully');
    } catch (e) {
      debugPrint('WebSocket: Connection failed: $e');
      _handleConnectionFailure();
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'connected':
          debugPrint('WebSocket: Server confirmed connection');
          break;

        case 'status_change':
          final event = StatusChangeEvent.fromJson(data);
          _statusChangeController.add(event);
          debugPrint(
            'WebSocket: Status change - ${event.name}:  ${event.oldStatus} -> ${event.newStatus}',
          );
          break;

        case 'heartbeat':
          _heartbeatController.add(data);
          break;

        case 'pong':
          // Ping response received
          break;

        default:
          debugPrint('WebSocket: Unknown message type: $type');
      }
    } catch (e) {
      debugPrint('WebSocket: Failed to parse message: $e');
    }
  }

  void _handleError(dynamic error) {
    debugPrint('WebSocket: Error: $error');
    _handleConnectionFailure();
  }

  void _handleDone() {
    debugPrint('WebSocket: Connection closed');
    _isConnected = false;
    _connectionStateController.add(false);
    _stopPingTimer();

    if (_shouldReconnect) {
      _scheduleReconnect();
    }
  }

  void _handleConnectionFailure() {
    _isConnected = false;
    _connectionStateController.add(false);
    _stopPingTimer();

    if (_shouldReconnect) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('WebSocket: Max reconnect attempts reached');
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      _reconnectAttempts++;
      debugPrint(
        'WebSocket: Reconnecting (attempt $_reconnectAttempts/$_maxReconnectAttempts)',
      );
      _attemptConnection();
    });
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      if (_isConnected && _channel != null) {
        try {
          _channel!.sink.add('ping');
        } catch (e) {
          debugPrint('WebSocket: Failed to send ping: $e');
        }
      }
    });
  }

  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  /// Disconnect from WebSocket server
  Future<void> disconnect() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _stopPingTimer();

    if (_channel != null) {
      await _channel!.sink.close();
      _channel = null;
    }

    _isConnected = false;
    _connectionStateController.add(false);
    debugPrint('WebSocket: Disconnected');
  }

  /// Dispose all resources
  void dispose() {
    disconnect();
    _statusChangeController.close();
    _connectionStateController.close();
    _heartbeatController.close();
  }
}
