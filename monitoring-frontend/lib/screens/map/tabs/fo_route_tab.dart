import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../models/fo_route.dart';
import '../../../models/network_node.dart';
import '../../../models/location.dart';
import '../../../services/map_service.dart';
import '../../../services/location_service.dart';
import '../../../utils/search_pagination_mixin.dart';
import '../../../widgets/components/table_action_header.dart';
import '../../../widgets/components/data_table.dart';
import '../../../widgets/common/visual_feedback.dart';
import '../../../widgets/layout/pagination.dart';
import '../../../widgets/dialogs/delete_confirm_dialog.dart';
import '../dialogs/fo_route_form_dialog.dart';
import '../route_editor_screen.dart';

class FORouteTab extends StatefulWidget {
  final VoidCallback? onChanged;
  const FORouteTab({super.key, this.onChanged});

  @override
  State<FORouteTab> createState() => _FORouteTabState();
}

class _FORouteTabState extends State<FORouteTab> with SearchPaginationMixin {
  final MapService _service = MapService();
  bool _isLoading = true;
  List<FORoute> _routes = [];
  Map<int, String> _nodeNameLookup = {};
  Map<int, LatLng> _nodeLocationLookup = {};
  int _totalItems = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchData(showLoader: true);
  }

  @override
  void onSearchTriggered() {
    _fetchData(showLoader: false);
  }

  Future<void> _fetchData({required bool showLoader}) async {
    if (showLoader) setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _service.getFORoutesPage(
          page: currentPage,
          limit: itemsPerPage,
          search: searchController.text.trim(),
        ),
        _service.getNetworkNodes(),
        LocationService().getLocations(limit: 1000),
      ]);

      final page = results[0] as FORoutePage;
      final nodes = results[1] as List<NetworkNode>;
      final locations = results[2] as List<Location>;

      if (mounted) {
        setState(() {
          _routes = page.items;
          _totalItems = page.total;

          _nodeNameLookup = {
            for (var n in nodes) n.id: n.name ?? "Node #${n.id}"
          };

          final locMap = {for (var loc in locations) loc.id: loc};
          _nodeLocationLookup = {};
          for (var node in nodes) {
            final loc = locMap[node.locationId];
            if (loc != null) {
              _nodeLocationLookup[node.id] =
                  LatLng(loc.latitude, loc.longitude);
            }
          }

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

  Future<void> _openForm({FORoute? route}) async {
    final result = await showDialog(
      context: context,
      builder: (context) => FORouteFormDialog(route: route),
    );
    if (result == true) {
      widget.onChanged?.call();
      _fetchData(showLoader: true);
    }
  }

  Future<void> _openMapEditor(FORoute route) async {
    final startLoc = _nodeLocationLookup[route.startNodeId];
    final endLoc = _nodeLocationLookup[route.endNodeId];

    if (startLoc == null || endLoc == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Error: Tidak bisa menemukan lokasi untuk node.")),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RouteEditorScreen(
          route: route,
          startLocation: startLoc,
          endLocation: endLoc,
        ),
      ),
    );

    if (result == true) {
      widget.onChanged?.call();
      _fetchData(showLoader: true);
    }
  }

  Future<void> _delete(FORoute route) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => DeleteConfirmDialog(
        title: "Hapus jalur",
        message:
            "Apakah ingin menghapus jalur ini antara ${_nodeNameLookup[route.startNodeId]} dengan ${_nodeNameLookup[route.endNodeId]}?",
      ),
    );

    if (confirm == true) {
      try {
        await _service.deleteFORoute(route.id);
        widget.onChanged?.call();
        _fetchData(showLoader: true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return AsyncErrorWidget(
          error: _error!, onRetry: () => _fetchData(showLoader: true));
    }

    final totalPages = (_totalItems / itemsPerPage).ceil();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TableActionHeader(
            searchController: searchController,
            searchHint: "Cari berdasarkan node yang terhubung",
            buttonLabel: "Tambah Jalur FO",
            buttonIcon: Icons.add,
            onButtonPressed: () => _openForm(),
          ),
          const SizedBox(height: 16),
          if (_routes.isEmpty)
            EmptyStateWidget.searching(
              isSearching: searchController.text.isNotEmpty,
              searchQuery: searchController.text,
              label: 'jalur FO',
            )
          else ...[
            CustomDataTable(
              columns: [
                CustomDataTable.column("Node Awal"),
                CustomDataTable.column("Node Akhir"),
                CustomDataTable.column("Panjang"),
                CustomDataTable.column("Deskripsi"),
                CustomDataTable.column("Action"),
              ],
              rows: _routes
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
                                  tooltip: "Edit Garis",
                                  icon: const Icon(Icons.map,
                                      color: Colors.green),
                                  onPressed: () => _openMapEditor(route)),
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
              currentPage: currentPage,
              totalPages: totalPages > 0 ? totalPages : 1,
              onPageChanged: handlePageChanged,
            ),
          ],
        ],
      ),
    );
  }
}
