import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'device_filter_bar.dart';
import 'device_card.dart';
import '../../models/device.dart';
import '../../services/device_service.dart';
import '../../services/websocket_service.dart';
import '../../widgets/error_boundary.dart';
import '../../widgets/search_bar.dart';
import '../../widgets/pagination.dart';

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  // Data
  List<BaseNode> _allNodes = [];
  List<BaseNode> _filteredNodes = [];
  bool _isLoading = true;
  String? _error;

  // WebSocket
  StreamSubscription<StatusChangeEvent>? _statusSubscription;

  // Search & Filters
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedType;
  String? _selectedLocation;
  String? _selectedStatus;

  // Pagination
  int _currentPage = 1;
  int _itemsPerPage = 10;
  final List<int> _itemsPerPageOptions = [10, 25, 50, 100];

  // Filter options
  List<String> _deviceTypes = [];
  List<String> _locations = [];

  @override
  void initState() {
    super.initState();
    _fetchNodes();
    _initWebSocket();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _statusSubscription?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _currentPage = 1;
      _applyFilters();
    });
  }

  Future<void> _fetchNodes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final nodes = await DeviceService().getAllNodes();
      setState(() {
        _allNodes = nodes;
        _extractFilterOptions();
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _extractFilterOptions() {
    _deviceTypes = _allNodes
        .map((n) => n.deviceType ?? 'Unknown')
        .toSet()
        .toList()
      ..sort();

    _locations = _allNodes
        .map((n) => n.locationName ?? 'Unknown')
        .toSet()
        .toList()
      ..sort();
  }

  void _applyFilters() {
    _filteredNodes = _allNodes.where((node) {
      if (_searchQuery.isNotEmpty) {
        final matchesSearch = node.name.toLowerCase().contains(_searchQuery) ||
            node.ipAddress.toLowerCase().contains(_searchQuery) ||
            (node.macAddress?.toLowerCase().contains(_searchQuery) ?? false);
        if (!matchesSearch) return false;
      }

      if (_selectedType != null &&
          (node.deviceType ?? 'Unknown') != _selectedType) {
        return false;
      }

      if (_selectedLocation != null &&
          (node.locationName ?? 'Unknown') != _selectedLocation) {
        return false;
      }

      if (_selectedStatus != null &&
          node.status?.toLowerCase() != _selectedStatus) {
        return false;
      }

      return true;
    }).toList();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedType = null;
      _selectedLocation = null;
      _selectedStatus = null;
      _currentPage = 1;
      _applyFilters();
    });
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
      for (int i = 0; i < _allNodes.length; i++) {
        final node = _allNodes[i];
        final isMatch = _isNodeMatch(node, event);
        if (isMatch) {
          _allNodes[i].status = event.newStatus;
          _applyFilters();
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

  int get _totalPages => (_filteredNodes.length / _itemsPerPage).ceil();
  int get _startIndex => (_currentPage - 1) * _itemsPerPage;
  int get _endIndex =>
      math.min(_startIndex + _itemsPerPage, _filteredNodes.length);
  List<BaseNode> get _paginatedNodes => _filteredNodes.isEmpty
      ? []
      : _filteredNodes.sublist(_startIndex, _endIndex);

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
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Device List",
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    SearchBarWidget(
                      controller: _searchController,
                      hintText: 'Search by name or IP address',
                    ),
                    const SizedBox(height: 12),
                    DeviceFilterBar(
                      selectedType: _selectedType,
                      selectedLocation: _selectedLocation,
                      selectedStatus: _selectedStatus,
                      deviceTypes: _deviceTypes,
                      locations: _locations,
                      onTypeChanged: (v) => _updateFilter(type: v),
                      onLocationChanged: (v) => _updateFilter(location: v),
                      onStatusChanged: (v) => _updateFilter(status: v),
                      onClearFilters: _clearFilters,
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
                  onPageChanged: (page) => setState(() => _currentPage = page),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateFilter({String? type, String? location, String? status}) {
    setState(() {
      if (type != null || _selectedType != null) _selectedType = type;
      if (location != null || _selectedLocation != null) {
        _selectedLocation = location;
      }
      if (status != null || _selectedStatus != null) _selectedStatus = status;
      _currentPage = 1;
      _applyFilters();
    });
  }

  Widget _buildResultsSummary() {
    final showing = _paginatedNodes.length;
    final total = _filteredNodes.length;
    final allTotal = _allNodes.length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          total == allTotal
              ? 'Showing $showing of $total'
              : 'Showing $showing of $total ($allTotal total)',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        Row(
          children: [
            Text('Show: ',
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            DropdownButton<int>(
              value: _itemsPerPage,
              underline: const SizedBox(),
              isDense: true,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              items: _itemsPerPageOptions
                  .map((count) =>
                      DropdownMenuItem(value: count, child: Text('$count')))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _itemsPerPage = value;
                    _currentPage = 1;
                  });
                }
              },
            ),
          ],
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

    if (_filteredNodes.isEmpty) {
      return SliverFillRemaining(
        child: EmptyStateWidget(
          message: _allNodes.isEmpty
              ? 'No devices found'
              : 'No devices match your filters',
          icon: Icons.devices_other,
          onAction: _allNodes.isNotEmpty ? _clearFilters : null,
          actionLabel: 'Clear Filters',
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => DeviceCard(
            key: ValueKey(_paginatedNodes[index].id),
            node: _paginatedNodes[index],
          ),
          childCount: _paginatedNodes.length,
        ),
      ),
    );
  }
}
