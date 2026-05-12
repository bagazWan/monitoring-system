import 'package:flutter/material.dart';
import 'widgets/analytics_sidebar.dart';
import 'widgets/analytics_chart.dart';
import '../../models/analytics_data_point.dart';
import '../../services/analytic_service.dart';
import '../../services/location_service.dart';
import '../../services/device_service.dart';
import '../../utils/location_group_formatter.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();
  final LocationService _locationService = LocationService();
  final DeviceService _deviceService = DeviceService();

  List<String> _locations = [];
  String? _locationA;
  String? _locationB;

  List<String> _deviceTypes = [];
  String? _selectedDeviceType;

  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );

  String _selectedMetric = 'inbound';

  List<AnalyticsDataPoint> _dataA = [];
  List<AnalyticsDataPoint> _dataB = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    try {
      final groups = await _locationService.getLocationGroups();
      final types = await _deviceService.getDeviceTypes();
      if (!mounted) return;
      final formattedNames = LocationGroupFormatter.formatNames(groups);
      formattedNames.insert(0, "-");

      final formattedTypes = List<String>.from(types);
      formattedTypes.insert(0, "-");
      setState(() {
        _locations = formattedNames;
        _locationA = "-";
        _locationB = "-";
        _deviceTypes = formattedTypes;
        _selectedDeviceType = "-";
      });
    } catch (e) {
      debugPrint("Failed loading data: $e");
    }
  }

  Future<void> _fetchComparisonData() async {
    final hasLocA = _locationA != null && _locationA != "-";
    final hasLocB = _locationB != null && _locationB != "-";
    final devType = (_selectedDeviceType == "-" || _selectedDeviceType == null)
        ? null
        : _selectedDeviceType;

    if (!hasLocA && !hasLocB) {
      setState(() {
        _dataA = [];
        _dataB = [];
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      Future<List<AnalyticsDataPoint>>? futureA;
      if (hasLocA) {
        final cleanA = _locationA!.replaceAll('↳', '').trim();
        futureA = _analyticsService.getHistoricalMetrics(
          startDate: _dateRange.start,
          endDate: _dateRange.end,
          locationName: cleanA,
          deviceType: devType,
        );
      }

      Future<List<AnalyticsDataPoint>>? futureB;
      if (hasLocB) {
        final cleanB = _locationB!.replaceAll('↳', '').trim();
        futureB = _analyticsService.getHistoricalMetrics(
          startDate: _dateRange.start,
          endDate: _dateRange.end,
          locationName: cleanB,
          deviceType: devType,
        );
      }

      final results = await Future.wait([
        if (futureA != null) futureA else Future.value(<AnalyticsDataPoint>[]),
        if (futureB != null) futureB else Future.value(<AnalyticsDataPoint>[])
      ]);

      if (mounted) {
        setState(() {
          _dataA = hasLocA ? results[0] : [];
          _dataB = hasLocB ? (hasLocA ? results[1] : results[0]) : [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;

    Widget buildSidebar() {
      return AnalyticsSidebar(
        allLocations: _locations,
        locationA: _locationA,
        locationB: _locationB,
        onLocationAChanged: (val) {
          setState(() => _locationA = val);
          _fetchComparisonData();
        },
        onLocationBChanged: (val) {
          setState(() => _locationB = val);
          _fetchComparisonData();
        },
        deviceTypes: _deviceTypes,
        selectedDeviceType: _selectedDeviceType,
        onDeviceTypeChanged: (val) {
          setState(() => _selectedDeviceType = val);
          _fetchComparisonData();
        },
        dateRange: _dateRange,
        onDateRangePressed: () async {
          final picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2026),
            lastDate: DateTime.now(),
            initialDateRange: _dateRange,
          );
          if (picked != null) {
            setState(() => _dateRange = picked);
            _fetchComparisonData();
          }
        },
        selectedMetric: _selectedMetric,
        onMetricChanged: (val) {
          setState(() => _selectedMetric = val);
        },
      );
    }

    Widget buildChartBox() {
      return Container(
        padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: AnalyticsLineChart(
          dataA: _dataA,
          dataB: _dataB,
          locationA: _locationA,
          locationB: _locationB,
          dateRange: _dateRange,
          metric: _selectedMetric,
          isLoading: _isLoading,
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      floatingActionButton: isMobile
          ? FloatingActionButton.extended(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    padding: const EdgeInsets.only(top: 16),
                    child: SafeArea(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: buildSidebar(),
                        ),
                      ),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.filter_list),
              label: const Text("Filter"),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text("Grafik Histori",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 24.0),
              child: isMobile
                  ? buildChartBox()
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: buildChartBox()),
                        const SizedBox(width: 24),
                        SizedBox(
                          width: 300,
                          child: buildSidebar(),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
