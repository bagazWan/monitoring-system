import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import 'device_filter_bar.dart';
import 'device_card.dart';
import '../../models/device.dart';
import '../../services/device_service.dart';
import '../../services/websocket_service.dart';
import '../../widgets/visual_feedback.dart';
import '../../widgets/search_bar.dart';
import '../../widgets/pagination.dart';

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
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

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    _loadDeviceTypes();
    _loadLocations();
    _fetchNodes();
    _initWebSocket();
    _searchController.addListener(_onSearchChanged);
    _startBatchPolling();
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

  Future<void> _fetchBatchLiveStats() async {
    final visibleNodes = _nodes;
    if (visibleNodes.isEmpty) return;

    try {
      final stats = await DeviceService().getBulkLiveDetails(visibleNodes);
      if (mounted) {
        setState(() {
          _liveStats = stats;
        });
      }
    } catch (e) {
      debugPrint("Batch fetch error: $e");
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _statusSubscription?.cancel();
    _batchTimer?.cancel();
    _searchDebounce?.cancel();
    super.dispose();
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

  Future<void> _loadLocations() async {
    try {
      final locations = await DeviceService().getLocations();
      if (!mounted) return;
      setState(() {
        _locations = locations.map((l) => l.name).toList()..sort();
      });
    } catch (_) {}
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
        _totalItems = page.total;
        _isLoading = false;
      });
      _fetchBatchLiveStats();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
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
    setState(() {
      for (int i = 0; i < _nodes.length; i++) {
        final node = _nodes[i];
        final isMatch = _isNodeMatch(node, event);
        if (isMatch) {
          _nodes[i].status = event.newStatus;
          break;
        }
      }
    });
    _showStatusNotification(event);
  }

  bool _isNodeMatch(BaseNode node, StatusChangeEvent event) {
    return (event.nodeType == 'device' &&
            node.deviceType?.toLowerCase() != 'switch' &&
            node.id == event.id) ||
        (event.nodeType == 'switch' &&
            node.deviceType?.toLowerCase() == 'switch' &&
            node.id == event.id);
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

  int get _totalPages => (_totalItems / _itemsPerPage).ceil().clamp(1, 9999);

  List<BaseNode> get _paginatedNodes => _nodes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        onRefresh: _fetchNodes,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Device List",
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    SearchBarWidget(
                      controller: _searchController,
                      hintText: 'Search by name or IP address',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DeviceFilterBar(
                            selectedType: _selectedType,
                            selectedLocation: _selectedLocation,
                            selectedStatus: _selectedStatus,
                            deviceTypes: _deviceTypes,
                            locations: _locations,
                            onTypeChanged: (v) => _updateFilter(type: v),
                            onLocationChanged: (v) =>
                                _updateFilter(location: v),
                            onStatusChanged: (v) => _updateFilter(status: v),
                            onClearFilters: _clearFilters,
                          ),
                        ),
                        if (_isAdmin) ...[
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final refresh = await Navigator.pushNamed(
                                  context, '/register-node');
                              if (refresh == true) _fetchNodes();
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text("Register"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildResultsSummary(),
                  ],
                ),
              ),
            ),
            _buildDeviceList(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: PaginationWidget(
                  currentPage: _currentPage,
                  totalPages: _totalPages,
                  onPageChanged: (page) {
                    setState(() => _currentPage = page);
                    _fetchNodes();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsSummary() {
    final showing = _paginatedNodes.length;
    final total = _totalItems;

    return Row(
      children: [
        Text(
          "Showing $showing of $total devices",
          style: TextStyle(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildDeviceList() {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return SliverFillRemaining(
        child: AsyncErrorWidget(
          error: _error!,
          onRetry: _fetchNodes,
          message: 'Failed to load devices',
        ),
      );
    }

    if (_nodes.isEmpty) {
      if (_searchQuery.isNotEmpty) {
        return SliverFillRemaining(
          child: EmptyStateWidget.searching(
            isSearching: true,
            searchQuery: _searchQuery,
            label: 'devices',
            defaultIcon: Icons.devices_other,
          ),
        );
      }

      return SliverFillRemaining(
        child: EmptyStateWidget(
          message: 'No devices found',
          icon: Icons.devices_other,
          onAction: (_searchQuery.isNotEmpty ||
                  _selectedType != null ||
                  _selectedLocation != null ||
                  _selectedStatus != null)
              ? _clearFilters
              : null,
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final node = _paginatedNodes[index];
            final key = '${node.nodeKind}_${node.id}';
            return DeviceCard(
              key: ValueKey(node.id),
              node: node,
              isAdmin: _isAdmin,
              onRefresh: _fetchNodes,
              liveStats: _liveStats[key],
            );
          },
          childCount: _paginatedNodes.length,
        ),
      ),
    );
  }
}
