import 'package:flutter/material.dart';
import '../../../models/network_node.dart';
import '../../../models/location.dart';
import '../../../services/map_service.dart';
import '../../../widgets/data_table.dart';
import '../../../widgets/visual_feedback.dart';
import '../../../widgets/search_bar.dart';
import '../../../widgets/pagination.dart';
import '../dialogs/network_node_form_dialog.dart';

class NetworkNodeTab extends StatefulWidget {
  const NetworkNodeTab({super.key});

  @override
  State<NetworkNodeTab> createState() => _NetworkNodeTabState();
}

class _NetworkNodeTabState extends State<NetworkNodeTab> {
  final MapService _service = MapService();
  bool _isLoading = true;
  List<NetworkNode> _networkNodes = [];
  Map<int, String> _locationNameLookup = {};
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
        _service.getNetworkNodes(),
        _service.getLocations(),
      ]);

      final nodes = results[0] as List<NetworkNode>;
      final locations = results[1] as List<Location>;

      if (mounted) {
        setState(() {
          _networkNodes = nodes;
          _locationNameLookup = {for (var loc in locations) loc.id: loc.name};
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<NetworkNode> get _filteredNodes {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return _networkNodes;
    return _networkNodes.where((node) {
      final locName = _locationNameLookup[node.locationId]?.toLowerCase() ?? "";
      return (node.name?.toLowerCase().contains(query) ?? false) ||
          locName.contains(query) ||
          node.type.toLowerCase().contains(query);
    }).toList();
  }

  List<NetworkNode> get _paginatedNodes {
    final filtered = _filteredNodes;
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    if (startIndex >= filtered.length) return [];
    final endIndex = (startIndex + _itemsPerPage < filtered.length)
        ? startIndex + _itemsPerPage
        : filtered.length;
    return filtered.sublist(startIndex, endIndex);
  }

  Future<void> _openForm({NetworkNode? networkNode}) async {
    final result = await showDialog(
      context: context,
      builder: (context) => NetworkNodeFormDialog(node: networkNode),
    );
    if (result == true) _fetchData();
  }

  Future<void> _delete(NetworkNode networkNode) async {
    final confirm = await _showDeleteConfirm(networkNode.name!);
    if (confirm == true) {
      try {
        await _service.deleteNetworkNode(networkNode.id);
        _fetchData();
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<bool?> _showDeleteConfirm(String name) {
    return showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Delete Network Node?"),
        content: Text("Delete $name? All nodes here will be unassigned."),
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
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return AsyncErrorWidget(error: _error!, onRetry: _fetchData);
    }

    final filtered = _filteredNodes;
    final paginated = _paginatedNodes;
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
                  hintText: "Search by name",
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: () => _openForm(),
                  icon: const Icon(Icons.add),
                  label: const Text("Add Network Node"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            EmptyStateWidget.searching(
              isSearching: _searchController.text.isNotEmpty,
              searchQuery: _searchController.text,
              label: 'network nodes',
            )
          else ...[
            CustomDataTable(
              columns: const [
                DataColumn(
                    label: Expanded(
                        child: Text("Name",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold)))),
                DataColumn(
                    label: Expanded(
                        child: Text("Location Name",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold)))),
                DataColumn(
                    label: Expanded(
                        child: Text("Type",
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
                  .map((node) => DataRow(cells: [
                        DataCell(Text(node.name!)),
                        DataCell(Text(
                            _locationNameLookup[node.locationId] ?? "Unknown")),
                        DataCell(Text(node.type)),
                        DataCell(Text(node.description ?? "-")),
                        DataCell(
                          Center(
                              child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.blue),
                                  onPressed: () =>
                                      _openForm(networkNode: node)),
                              IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () => _delete(node)),
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
            )
          ],
        ],
      ),
    );
  }
}
