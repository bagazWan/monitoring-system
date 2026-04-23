import 'package:flutter/material.dart';
import '../../models/analytics_data_point.dart';
import '../../services/analytic_service.dart';
import '../../services/device_service.dart';
import 'widgets/analytics_sidebar.dart';
import 'widgets/analytics_chart.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();
  final DeviceService _deviceService = DeviceService();

  List<String> _locations = [];
  String? _locationA;
  String? _locationB;

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
      final groups = await _deviceService.getLocationGroups();
      if (!mounted) return;

      final List<String> formattedNames = [];
      formattedNames.add("-");

      final parents = groups.where((g) => g.parentId == null).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      for (final parent in parents) {
        formattedNames.add(parent.name);
        final children = groups
            .where((g) => g.parentId == parent.groupId)
            .toList()
          ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        for (final child in children) {
          formattedNames.add("   ↳ ${child.name}");
        }
      }

      setState(() {
        _locations = formattedNames;
        _locationA = "-";
        _locationB = "-";
      });
    } catch (e) {
      debugPrint("Failed loading locations: $e");
    }
  }

  Future<void> _fetchComparisonData() async {
    final hasLocA = _locationA != null && _locationA != "-";
    final hasLocB = _locationB != null && _locationB != "-";

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
            locationName: cleanA);
      }

      Future<List<AnalyticsDataPoint>>? futureB;
      if (hasLocB) {
        final cleanB = _locationB!.replaceAll('↳', '').trim();
        futureB = _analyticsService.getHistoricalMetrics(
            startDate: _dateRange.start,
            endDate: _dateRange.end,
            locationName: cleanB);
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
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 12),
            child: Text("History Graph",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 24.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(24.0),
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
                    ),
                  ),
                  const SizedBox(width: 24),
                  AnalyticsSidebar(
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
                    dateRange: _dateRange,
                    onDateRangePressed: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2023),
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
