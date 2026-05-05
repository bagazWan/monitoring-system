import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'widgets/device_filter_bar.dart';
import 'widgets/device_card.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../models/device.dart';
import '../../services/device_service.dart';
import '../../services/location_service.dart';
import '../../widgets/common/visual_feedback.dart';
import '../../widgets/components/search_bar.dart';
import '../../widgets/layout/pagination.dart';
import '../../providers/metrics_provider.dart';
import '../../utils/location_group_formatter.dart';

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
  bool get _canViewIp =>
      _currentUser?.role == 'admin' || _currentUser?.role == 'teknisi';

  Timer? _searchDebounce;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedType;
  String? _selectedLocation;
  String? _selectedStatus;
  List<String> _deviceTypes = [];
  List<String> _locations = [];
  static const _noChange = Object();

  int _currentPage = 1;
  int _itemsPerPage = 10;

  int get _totalPages => (_totalItems / _itemsPerPage).ceil().clamp(1, 9999);
  List<BaseNode> get _paginatedNodes => _nodes;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    _loadDeviceTypes();
    _loadLocations();
    _fetchNodes();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
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
      final groups = await LocationService().getLocationGroups();
      if (!mounted) return;

      final formattedNames = LocationGroupFormatter.formatNames(groups);

      if (_selectedLocation != null &&
          !formattedNames.contains(_selectedLocation)) {
        formattedNames.insert(0, _selectedLocation!);
      }

      setState(() => _locations = formattedNames);
    } catch (_) {}
  }

  Future<void> _fetchNodes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final cleanLocation = _selectedLocation?.replaceAll('↳', '').trim();

      final page = await DeviceService().getNodesPage(
        search: _searchQuery,
        locationName: cleanLocation,
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
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _updateFilter({
    Object? type = _noChange,
    Object? location = _noChange,
    Object? status = _noChange,
  }) {
    setState(() {
      if (type != _noChange) {
        _selectedType = type as String?;
      }
      if (location != _noChange) {
        _selectedLocation = location as String?;
      }
      if (status != _noChange) {
        _selectedStatus = status as String?;
      }
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

  @override
  Widget build(BuildContext context) {
    return buildDeviceListScreen(context);
  }
}
