import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import 'widgets/device_filter_bar.dart';
import 'widgets/device_card.dart';
import '../../models/device.dart';
import '../../services/device_service.dart';
import '../../services/websocket_service.dart';
import '../../widgets/visual_feedback.dart';
import '../../widgets/search_bar.dart';
import '../../widgets/pagination.dart';

part 'widgets/device_list_widgets.dart';

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen>
    with DeviceListWidgets {
  List<BaseNode> _nodes = [];
  int _totalItems = 0;

  bool _isLoading = true;
  String? _error;
  User? _currentUser;
  bool get _isAdmin => _currentUser?.role == 'admin';

  StreamSubscription<StatusChangeEvent>? _statusSubscription;
  Map<String, Map<String, dynamic>> _liveStats = {};
  Timer? _batchTimer;
  Timer? _searchDebounce;

  final Map<String, ValueNotifier<String?>> _statusNotifiers = {};
  final Map<String, ValueNotifier<Map<String, dynamic>?>> _liveStatsNotifiers =
      {};

  // Search & Filters
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedType;
  String? _selectedLocation;
  String? _selectedStatus;
  List<String> _deviceTypes = [];
  List<String> _locations = [];

  // Pagination
  int _currentPage = 1;
  int _itemsPerPage = 10;

  int get _totalPages => (_totalItems / _itemsPerPage).ceil().clamp(1, 9999);

  List<BaseNode> get _paginatedNodes => _nodes;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    _loadDeviceTypes();
    _fetchNodes();
    _initWebSocket();
    _searchController.addListener(_onSearchChanged);
    _startBatchPolling();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _statusSubscription?.cancel();
    _batchTimer?.cancel();
    _searchDebounce?.cancel();
    for (final notifier in _statusNotifiers.values) {
      notifier.dispose();
    }
    for (final notifier in _liveStatsNotifiers.values) {
      notifier.dispose();
    }
    super.dispose();
  }

  Future<void> _checkUserRole() async {
    try {
      final user = await AuthService().getCurrentUser();
      if (mounted) setState(() => _currentUser = user);
    } catch (e) {
      debugPrint("Failed to load user role: $e");
    }
  }

  void _startBatchPolling() {
    _batchTimer?.cancel();
    _batchTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && _nodes.isNotEmpty) {
        _fetchBatchLiveStats();
      }
    });
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      setState(() {
        _searchQuery = _searchController.text.trim();
        _currentPage = 1;
      });
      _fetchNodes();
    });
  }

  Future<void> _loadDeviceTypes() async {
    try {
      final types = await DeviceService().getDeviceTypes();
      if (!mounted) return;
      setState(() => _deviceTypes = types);
    } catch (_) {}
  }

  List<String> _deriveLocationNames(List<BaseNode> items) {
    final names = items
        .map((n) => n.locationName)
        .whereType<String>()
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    if (_selectedLocation != null && !names.contains(_selectedLocation)) {
      names.insert(0, _selectedLocation!);
    }

    return names;
  }

  Future<void> _fetchNodes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final page = await DeviceService().getNodesPage(
        search: _searchQuery,
        locationName: _selectedLocation,
        deviceType: _selectedType,
        status: _selectedStatus,
        page: _currentPage,
        limit: _itemsPerPage,
      );

      page.items.sort((a, b) {
        final isSwitchA = a.nodeKind == 'switch';
        final isSwitchB = b.nodeKind == 'switch';

        if (isSwitchA && !isSwitchB) return -1;
        if (!isSwitchA && isSwitchB) return 1;

        final idA = a.id ?? 0;
        final idB = b.id ?? 0;
        return idA.compareTo(idB);
      });

      if (!mounted) return;
      setState(() {
        _nodes = page.items;
        _locations = _deriveLocationNames(page.items);
        _totalItems = page.total;
        _isLoading = false;
      });

      for (final node in _nodes) {
        final key = '${node.nodeKind}_${node.id}';
        _statusNotifiers.putIfAbsent(
          key,
          () => ValueNotifier<String?>(node.status),
        );
        _liveStatsNotifiers.putIfAbsent(
          key,
          () => ValueNotifier<Map<String, dynamic>?>(_liveStats[key]),
        );
      }

      _fetchBatchLiveStats();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchBatchLiveStats() async {
    final visibleNodes = _nodes;
    if (visibleNodes.isEmpty) return;

    try {
      final stats = await DeviceService().getBulkLiveDetails(visibleNodes);
      if (mounted) {
        _liveStats = stats;
        for (final entry in stats.entries) {
          _liveStatsNotifiers.putIfAbsent(
            entry.key,
            () => ValueNotifier<Map<String, dynamic>?>(entry.value),
          );
          _liveStatsNotifiers[entry.key]!.value = entry.value;
        }
      }
    } catch (e) {
      debugPrint("Batch fetch error: $e");
    }
  }

  void _updateFilter({String? type, String? location, String? status}) {
    setState(() {
      if (type != null || _selectedType != null) _selectedType = type;
      if (location != null || _selectedLocation != null) {
        _selectedLocation = location;
      }
      if (status != null || _selectedStatus != null) _selectedStatus = status;
      _currentPage = 1;
    });
    _fetchNodes();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedType = null;
      _selectedLocation = null;
      _selectedStatus = null;
      _currentPage = 1;
    });
    _fetchNodes();
  }

  void _initWebSocket() {
    final wsService = WebSocketService();
    wsService.connect();

    _statusSubscription = wsService.statusChanges.listen((event) {
      if (mounted) _handleStatusChange(event);
    });
  }

  void _handleStatusChange(StatusChangeEvent event) {
    final key = '${event.nodeType}_${event.id}';
    if (_statusNotifiers.containsKey(key)) {
      _statusNotifiers[key]!.value = event.newStatus;
    }

    _showStatusNotification(event);
  }

  void _showStatusNotification(StatusChangeEvent event) {
    final isOnline = event.newStatus == 'online';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isOnline ? Icons.check_circle : Icons.error,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${event.name} is now ${event.newStatus.toUpperCase()}',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: isOnline ? Colors.green : Colors.red,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildDeviceListScreen(context);
  }
}
