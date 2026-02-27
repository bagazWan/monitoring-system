import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/location.dart';
import '../../../services/map_service.dart';
import '../../../widgets/data_table.dart';
import '../../../widgets/visual_feedback.dart';
import '../../../widgets/search_bar.dart';
import '../../../widgets/pagination.dart';
import '../dialogs/location_form_dialog.dart';

class LocationTab extends StatefulWidget {
  final VoidCallback? onChanged;
  const LocationTab({super.key, this.onChanged});

  @override
  State<LocationTab> createState() => _LocationTabState();
}

class _LocationTabState extends State<LocationTab> {
  final MapService _service = MapService();
  bool _isLoading = true;
  List<Location> _locations = [];
  int _totalItems = 0;
  String? _error;

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  int _currentPage = 1;
  final int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _fetchData(showLoader: true);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _currentPage = 1;
      _fetchData(showLoader: false);
    });
  }

  Future<void> _fetchData({required bool showLoader}) async {
    if (showLoader) {
      setState(() => _isLoading = true);
    }
    try {
      final page = await _service.getLocationsPage(
        page: _currentPage,
        limit: _itemsPerPage,
        search: _searchController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _locations = page.items;
          _totalItems = page.total;
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

  Future<void> _openForm({Location? location}) async {
    final result = await showDialog(
      context: context,
      builder: (context) => LocationFormDialog(location: location),
    );
    if (result == true) {
      widget.onChanged?.call();
      _fetchData(showLoader: true);
    }
  }

  Future<void> _delete(Location location) async {
    final confirm = await _showDeleteConfirm(location.name);
    if (confirm == true) {
      try {
        await _service.deleteLocation(location.id);
        widget.onChanged?.call();
        _fetchData(showLoader: true);
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
        title: const Text("Delete Location?"),
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
      return AsyncErrorWidget(
          error: _error!, onRetry: () => _fetchData(showLoader: true));
    }

    final totalPages = (_totalItems / _itemsPerPage).ceil();

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
                  hintText: "Search by name or address",
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: () => _openForm(),
                  icon: const Icon(Icons.add),
                  label: const Text("Add Location"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 16),
          if (_locations.isEmpty)
            EmptyStateWidget.searching(
              isSearching: _searchController.text.isNotEmpty,
              searchQuery: _searchController.text,
              label: 'locations',
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
                        child: Text("Address",
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
              rows: _locations
                  .map((loc) => DataRow(cells: [
                        DataCell(Text(loc.name)),
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
              currentPage: _currentPage,
              totalPages: totalPages > 0 ? totalPages : 1,
              onPageChanged: (page) {
                setState(() => _currentPage = page);
                _fetchData(showLoader: true);
              },
            ),
          ],
        ],
      ),
    );
  }
}
