import 'package:flutter/material.dart';
import 'dart:async';

class AlertNotification {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  /// Show alert notification overlay
  static void show(
    BuildContext context, {
    required String message,
    required String severity,
    String? deviceName,
    VoidCallback? onTap,
  }) {
    // Remove existing notification if any
    dismiss();

    final overlay = Overlay.of(context);

    _currentEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 80,
        right: 20,
        child: _AlertNotificationWidget(
          message: message,
          severity: severity,
          deviceName: deviceName,
          onTap: onTap ?? () => dismiss(),
          onDismiss: dismiss,
        ),
      ),
    );

    overlay.insert(_currentEntry!);

    // Auto dismiss after 5 seconds
    _dismissTimer = Timer(const Duration(seconds: 5), () {
      dismiss();
    });
  }

  /// Dismiss current notification
  static void dismiss() {
    _dismissTimer?.cancel();
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _AlertNotificationWidget extends StatefulWidget {
  final String message;
  final String severity;
  final String? deviceName;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _AlertNotificationWidget({
    required this.message,
    required this.severity,
    this.deviceName,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_AlertNotificationWidget> createState() =>
      _AlertNotificationWidgetState();
}

class _AlertNotificationWidgetState extends State<_AlertNotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.5, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getSeverityColor() {
    switch (widget.severity.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'info':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getSeverityIcon() {
    switch (widget.severity.toLowerCase()) {
      case 'critical':
        return Icons.error;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'info':
        return Icons.info;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 350,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _getSeverityColor(),
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      _getSeverityIcon(),
                      color: _getSeverityColor(),
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'New Alert',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _getSeverityColor(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: widget.onDismiss,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (widget.deviceName != null) ...[
                  Text(
                    widget.deviceName!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  widget.message,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: widget.onTap,
                      child: const Text('View'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
