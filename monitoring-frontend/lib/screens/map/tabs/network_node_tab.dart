import 'package:flutter/material.dart';
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
import '../dialogs/network_node_form_dialog.dart';

class NetworkNodeTab extends StatefulWidget {
  final VoidCallback? onChanged;
  const NetworkNodeTab({super.key, this.onChanged});

  @override
  State<NetworkNodeTab> createState() => _NetworkNodeTabState();
}

class _NetworkNodeTabState extends State<NetworkNodeTab>
    with SearchPaginationMixin {
  final MapService _service = MapService();
  bool _isLoading = true;
  List<NetworkNode> _networkNodes = [];
  Map<int, String> _locationNameLookup = {};
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
        _service.getNetworkNodesPage(
          page: currentPage,
          limit: itemsPerPage,
          search: searchController.text.trim(),
        ),
        LocationService().getLocationOptions(),
      ]);

      final nodesPage = results[0] as NetworkNodePage;
      final locations = results[1] as List<Location>;

      if (mounted) {
        setState(() {
          _networkNodes = nodesPage.items;
          _totalItems = nodesPage.total;
          _locationNameLookup = {for (var loc in locations) loc.id: loc.name};
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openForm({NetworkNode? networkNode}) async {
    final result = await showDialog(
      context: context,
      builder: (context) => NetworkNodeFormDialog(node: networkNode),
    );
    if (result == true) {
      widget.onChanged?.call();
      _fetchData(showLoader: true);
    }
  }

  Future<void> _delete(NetworkNode networkNode) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => DeleteConfirmDialog(
        title: "Hapus node jaringan?",
        message:
            "Hapus ${networkNode.name}? Semua perangkat di sini akan menjadi tidak teralokasi.",
      ),
    );

    if (confirm == true) {
      try {
        await _service.deleteNetworkNode(networkNode.id);
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
            searchHint: "Cari berdasarkan nama",
            buttonLabel: "Tambah Node Jaringan",
            buttonIcon: Icons.add,
            onButtonPressed: () => _openForm(),
          ),
          const SizedBox(height: 16),
          if (_networkNodes.isEmpty)
            EmptyStateWidget.searching(
              isSearching: searchController.text.isNotEmpty,
              searchQuery: searchController.text,
              label: 'node jaringan',
            )
          else ...[
            CustomDataTable(
              columns: [
                CustomDataTable.column("Nama"),
                CustomDataTable.column("Nama Lokasi"),
                CustomDataTable.column("Tipe"),
                CustomDataTable.column("Deskripsi"),
                CustomDataTable.column("Action"),
              ],
              rows: _networkNodes
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
              currentPage: currentPage,
              totalPages: totalPages > 0 ? totalPages : 1,
              onPageChanged: handlePageChanged,
            )
          ],
        ],
      ),
    );
  }
}
