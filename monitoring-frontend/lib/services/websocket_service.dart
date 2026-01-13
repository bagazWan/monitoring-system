import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../api_config.dart';

/// Model for status change events
class StatusChangeEvent {
  final String nodeType;
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

/// Connection state enum for better state management
enum WebSocketConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

/// Singleton WebSocket service with exponential backoff reconnection
class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  WebSocketConnectionState _connectionState =
      WebSocketConnectionState.disconnected;
  bool _shouldReconnect = true;
  int _reconnectAttempts = 0;

  // Exponential backoff configuration
  static const int _maxReconnectAttempts = 10;
  static const Duration _initialReconnectDelay = Duration(seconds: 1);
  static const Duration _maxReconnectDelay = Duration(seconds: 60);
  static const Duration _pingInterval = Duration(seconds: 30);
  static const double _backoffMultiplier = 2.0;
  static const double _jitterFactor = 0.1; // 10% jitter

  // Stream controllers
  final _statusChangeController =
      StreamController<StatusChangeEvent>.broadcast();
  final _connectionStateController =
      StreamController<WebSocketConnectionState>.broadcast();
  final _heartbeatController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream of status change events
  Stream<StatusChangeEvent> get statusChanges => _statusChangeController.stream;

  /// Stream of connection state changes
  Stream<WebSocketConnectionState> get connectionState =>
      _connectionStateController.stream;

  /// Stream of heartbeat events
  Stream<Map<String, dynamic>> get heartbeats => _heartbeatController.stream;

  /// Current connection state
  WebSocketConnectionState get currentState => _connectionState;

  /// Whether currently connected
  bool get isConnected =>
      _connectionState == WebSocketConnectionState.connected;

  /// Calculate reconnect delay with exponential backoff and jitter
  Duration _calculateReconnectDelay() {
    // Exponential backoff:  delay = initialDelay * (multiplier ^ attempts)
    final exponentialDelay = _initialReconnectDelay.inMilliseconds *
        pow(_backoffMultiplier, _reconnectAttempts);

    // Cap at max delay
    final cappedDelay =
        min(exponentialDelay, _maxReconnectDelay.inMilliseconds);

    // Add jitter to prevent thundering herd
    final random = Random();
    final jitter = cappedDelay * _jitterFactor * (random.nextDouble() * 2 - 1);
    final finalDelay = cappedDelay + jitter;

    return Duration(milliseconds: finalDelay.toInt());
  }

  /// Connect to WebSocket server
  Future<void> connect() async {
    if (_connectionState == WebSocketConnectionState.connected ||
        _connectionState == WebSocketConnectionState.connecting) {
      return;
    }

    _shouldReconnect = true;
    _reconnectAttempts = 0;
    await _attemptConnection();
  }

  Future<void> _attemptConnection() async {
    _updateConnectionState(WebSocketConnectionState.connecting);

    try {
      final wsUrl = ApiConfig.baseUrl
          .replaceFirst('http://', 'ws://')
          .replaceFirst('https://', 'wss://');
      final uri = Uri.parse('$wsUrl/api/v1/ws/status');

      debugPrint(
          'WebSocket:  Connecting to $uri (attempt ${_reconnectAttempts + 1})');

      _channel = WebSocketChannel.connect(uri);

      // Wait for connection to establish
      await _channel!.ready;

      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDone,
        cancelOnError: false,
      );

      _updateConnectionState(WebSocketConnectionState.connected);
      _reconnectAttempts = 0; // Reset on successful connection
      _startPingTimer();

      debugPrint('WebSocket: Connected successfully');
    } catch (e) {
      debugPrint('WebSocket: Connection failed: $e');
      _handleConnectionFailure();
    }
  }

  void _updateConnectionState(WebSocketConnectionState state) {
    _connectionState = state;
    _connectionStateController.add(state);
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
          debugPrint('WebSocket: Heartbeat received');
          break;

        case 'pong':
          // Ping response received - connection is healthy
          break;

        default:
          debugPrint('WebSocket:  Unknown message type: $type');
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
    _stopPingTimer();

    if (_shouldReconnect) {
      _scheduleReconnect();
    } else {
      _updateConnectionState(WebSocketConnectionState.disconnected);
    }
  }

  void _handleConnectionFailure() {
    _stopPingTimer();

    if (_shouldReconnect && _reconnectAttempts < _maxReconnectAttempts) {
      _scheduleReconnect();
    } else {
      _updateConnectionState(WebSocketConnectionState.disconnected);
      if (_reconnectAttempts >= _maxReconnectAttempts) {
        debugPrint('WebSocket: Max reconnect attempts reached');
      }
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();

    _updateConnectionState(WebSocketConnectionState.reconnecting);

    final delay = _calculateReconnectDelay();
    debugPrint(
      'WebSocket: Reconnecting in ${delay.inSeconds}s '
      '(attempt ${_reconnectAttempts + 1}/$_maxReconnectAttempts)',
    );

    _reconnectTimer = Timer(delay, () {
      _reconnectAttempts++;
      _attemptConnection();
    });
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      if (isConnected && _channel != null) {
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

  /// Manually trigger a reconnection attempt
  void reconnect() {
    if (_connectionState != WebSocketConnectionState.connecting) {
      _reconnectAttempts = 0;
      disconnect();
      connect();
    }
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

    _updateConnectionState(WebSocketConnectionState.disconnected);
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
