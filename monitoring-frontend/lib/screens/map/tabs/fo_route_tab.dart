import 'package:flutter/material.dart';
import '../../../models/fo_route.dart';
import '../../../models/network_node.dart';
import '../../../services/map_service.dart';
import '../../../widgets/data_table.dart';
import '../../../widgets/visual_feedback.dart';
import '../../../widgets/search_bar.dart';
import '../../../widgets/pagination.dart';
import '../dialogs/fo_route_form_dialog.dart';

class FORouteTab extends StatefulWidget {
  const FORouteTab({super.key});

  @override
  State<FORouteTab> createState() => _FORouteTabState();
}

class _FORouteTabState extends State<FORouteTab> {
  final MapService _service = MapService();
  bool _isLoading = true;
  List<FORoute> _routes = [];
  Map<int, String> _nodeNameLookup = {};
  String? _error;

  final TextEditingController _searchController = TextEditingController();
  int _currentPage = 1;
  final int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _searchController.addListener(() => setState(() => _currentPage = 1));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _service.getFORoutes(),
        _service.getNetworkNodes(),
      ]);

      if (mounted) {
        setState(() {
          _routes = results[0] as List<FORoute>;
          final nodes = results[1] as List<NetworkNode>;

          _nodeNameLookup = {
            for (var n in nodes) n.id: n.name ?? "Node #${n.id}"
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<FORoute> get _filteredRoutes {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return _routes;
    return _routes.where((route) {
      final start = _nodeNameLookup[route.startNodeId]?.toLowerCase() ?? "";
      final end = _nodeNameLookup[route.endNodeId]?.toLowerCase() ?? "";
      final desc = route.description?.toLowerCase() ?? "";
      return start.contains(query) ||
          end.contains(query) ||
          desc.contains(query);
    }).toList();
  }

  List<FORoute> get _paginatedRoutes {
    final filtered = _filteredRoutes;
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    if (startIndex >= filtered.length) return [];
    final endIndex = (startIndex + _itemsPerPage < filtered.length)
        ? startIndex + _itemsPerPage
        : filtered.length;
    return filtered.sublist(startIndex, endIndex);
  }

  Future<void> _openForm({FORoute? route}) async {
    final result = await showDialog(
      context: context,
      builder: (context) => FORouteFormDialog(route: route),
    );
    if (result == true) _fetchData();
  }

  Future<void> _delete(FORoute route) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Delete Route?"),
        content: Text(
            "Are you sure you want to delete this route between ${_nodeNameLookup[route.startNodeId]} and ${_nodeNameLookup[route.endNodeId]}?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () => Navigator.pop(c, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text("Delete")),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _service.deleteFORoute(route.id);
        _fetchData();
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return AsyncErrorWidget(error: _error!, onRetry: _fetchData);
    }

    final filtered = _filteredRoutes;
    final paginated = _paginatedRoutes;
    final totalPages = (filtered.length / _itemsPerPage).ceil();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SearchBarWidget(
                  controller: _searchController,
                  hintText: "Search by connected node",
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: () => _openForm(),
                  icon: const Icon(Icons.add),
                  label: const Text("Add FO Route"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8))),
                ),
              )
            ],
          ),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            EmptyStateWidget.searching(
              isSearching: _searchController.text.isNotEmpty,
              searchQuery: _searchController.text,
              label: 'FO routes',
            )
          else ...[
            CustomDataTable(
              columns: const [
                DataColumn(
                    label: Expanded(
                        child: Text("Start Node",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold)))),
                DataColumn(
                    label: Expanded(
                        child: Text("End Node",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold)))),
                DataColumn(
                    label: Expanded(
                        child: Text("Length",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold)))),
                DataColumn(
                    label: Expanded(
                        child: Text("Description",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold)))),
                DataColumn(
                    label: Expanded(
                        child: Text("Action",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold)))),
              ],
              rows: paginated
                  .map((route) => DataRow(cells: [
                        DataCell(Text(_nodeNameLookup[route.startNodeId] ??
                            "ID: ${route.startNodeId}")),
                        DataCell(Text(_nodeNameLookup[route.endNodeId] ??
                            "ID: ${route.endNodeId}")),
                        DataCell(Center(child: Text("${route.length} m"))),
                        DataCell(Text(route.description ?? "-")),
                        DataCell(
                          Center(
                              child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.blue),
                                  onPressed: () => _openForm(route: route)),
                              IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () => _delete(route)),
                            ],
                          )),
                        )
                      ]))
                  .toList(),
            ),
            const SizedBox(height: 16),
            PaginationWidget(
              currentPage: _currentPage,
              totalPages: totalPages > 0 ? totalPages : 1,
              onPageChanged: (page) => setState(() => _currentPage = page),
            ),
          ],
        ],
      ),
    );
  }
}
