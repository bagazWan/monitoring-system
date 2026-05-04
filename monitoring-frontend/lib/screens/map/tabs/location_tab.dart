import 'package:flutter/material.dart';
import '../../../models/location.dart';
import '../../../services/location_service.dart';
import '../../../utils/search_pagination_mixin.dart';
import '../../../widgets/components/table_action_header.dart';
import '../../../widgets/components/data_table.dart';
import '../../../widgets/common/visual_feedback.dart';
import '../../../widgets/layout/pagination.dart';
import '../../../widgets/dialogs/delete_confirm_dialog.dart';
import '../dialogs/location_form_dialog.dart';
import '../dialogs/manage_location_groups_dialog.dart';

class LocationTab extends StatefulWidget {
  final VoidCallback? onChanged;
  const LocationTab({super.key, this.onChanged});

  @override
  State<LocationTab> createState() => _LocationTabState();
}

class _LocationTabState extends State<LocationTab> with SearchPaginationMixin {
  final LocationService _service = LocationService();
  bool _isLoading = true;
  List<Location> _locations = [];
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
      final page = await _service.getLocationsPage(
        page: currentPage,
        limit: itemsPerPage,
        search: searchController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _locations = page.items;
        _totalItems = page.total;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openForm({Location? location}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => LocationFormDialog(location: location),
    );
    if (result == true) {
      widget.onChanged?.call();
      _fetchData(showLoader: true);
    }
  }

  Future<void> _openManageGroups() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => const ManageLocationGroupsDialog(),
    );
    if (changed == true) {
      widget.onChanged?.call();
      _fetchData(showLoader: false);
    }
  }

  Future<void> _delete(Location location) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => DeleteConfirmDialog(
        title: "Hapus lokasi?",
        message:
            "Hapus ${location.name}? Semua perangkat di sini akan menjadi tidak teralokasi.",
      ),
    );

    if (confirm == true) {
      try {
        await _service.deleteLocation(location.id);
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
            searchHint: "Cari berdasarkan nama, alamat, atau group",
            buttonLabel: "Tambah Lokasi",
            buttonIcon: Icons.add,
            onButtonPressed: () => _openForm(),
            additionalActions: [
              SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: _openManageGroups,
                  icon: const Icon(Icons.group_work_outlined),
                  label: const Text("Kelola Group"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_locations.isEmpty)
            EmptyStateWidget.searching(
              isSearching: searchController.text.isNotEmpty,
              searchQuery: searchController.text,
              label: 'lokasi',
            )
          else ...[
            CustomDataTable(
              columns: [
                CustomDataTable.column("Nama"),
                CustomDataTable.column("Group"),
                CustomDataTable.column("Alamat"),
                CustomDataTable.column("Deskripsi"),
                CustomDataTable.column("Action"),
              ],
              rows: _locations
                  .map((loc) => DataRow(cells: [
                        DataCell(Text(loc.name)),
                        DataCell(Text(loc.groupName ?? "-")),
                        DataCell(Text(loc.address ?? "-")),
                        DataCell(Text(loc.description ?? "-")),
                        DataCell(Center(
                            child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                                icon:
                                    const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _openForm(location: loc)),
                            IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _delete(loc)),
                          ],
                        ))),
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
