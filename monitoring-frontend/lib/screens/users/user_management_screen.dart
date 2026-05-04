import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../services/user_service.dart';
import '../../services/websocket_service.dart';
import '../../utils/search_pagination_mixin.dart';
import '../../widgets/components/table_action_header.dart';
import '../../widgets/layout/pagination.dart';
import '../../widgets/components/data_table.dart';
import '../../widgets/common/visual_feedback.dart';
import '../../widgets/dialogs/delete_confirm_dialog.dart';
import 'user_form_dialog.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen>
    with SearchPaginationMixin {
  final UserService _userService = UserService();
  StreamSubscription<StatusChangeEvent>? _statusSubscription;

  bool _isLoading = true;
  bool _isFetching = false;
  List<User> _users = [];
  int _totalItems = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchUsers(initial: true);
    _initWebSocket();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  @override
  void onSearchTriggered() {
    _fetchUsers();
  }

  void _initWebSocket() {
    final wsService = WebSocketService();
    _statusSubscription = wsService.statusChanges.listen((event) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${event.name} sekarang ${event.newStatus}'),
            backgroundColor: event.newStatus.toLowerCase() == 'online'
                ? Colors.green
                : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  Future<void> _fetchUsers({bool initial = false}) async {
    setState(() {
      initial ? _isLoading = true : _isFetching = true;
      _error = null;
    });

    try {
      final page = await _userService.getUsers(
        page: currentPage,
        limit: itemsPerPage,
        search: searchController.text.trim(),
      );

      page.items.sort((a, b) => a.id.compareTo(b.id));

      if (mounted) {
        setState(() {
          _users = page.items;
          _totalItems = page.total;
          _isLoading = false;
          _isFetching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          _isFetching = false;
        });
      }
    }
  }

  int get _totalPages => (_totalItems / itemsPerPage).ceil().clamp(1, 9999);

  Future<void> _openUserDialog({User? user}) async {
    final result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UserFormDialog(user: user),
    );
    if (result == true) _fetchUsers();
  }

  Future<void> _deleteUser(int userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => const DeleteConfirmDialog(
        title: "Hapus user",
        message: "Apakah yakin menghapus user ini ?",
      ),
    );

    if (confirm == true) {
      await _userService.deleteUser(userId);
      _fetchUsers();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return AsyncErrorWidget(
          error: _error!,
          onRetry: () => _fetchUsers(initial: true),
          message: 'Failed to load users');
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        onRefresh: () => _fetchUsers(initial: true),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Manajemen User",
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    TableActionHeader(
                      searchController: searchController,
                      searchHint: 'Cari berdasarkan username atau nama',
                      buttonLabel: 'Tambah User',
                      buttonIcon: Icons.add,
                      onButtonPressed: () => _openUserDialog(),
                    ),
                  ],
                ),
              ),
            ),
            _buildUsersTable(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: PaginationWidget(
                  currentPage: currentPage,
                  totalPages: _totalPages,
                  onPageChanged: handlePageChanged,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTable() {
    if (_users.isEmpty) {
      return SliverFillRemaining(
        child: EmptyStateWidget.searching(
          isSearching: searchController.text.isNotEmpty,
          searchQuery: searchController.text,
          label: 'users',
          defaultIcon: Icons.people_outline,
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverToBoxAdapter(
        child: CustomDataTable(
          columns: [
            CustomDataTable.column("Username"),
            CustomDataTable.column("Nama lengkap"),
            CustomDataTable.column("Email"),
            CustomDataTable.column("Role"),
            CustomDataTable.column("Actions"),
          ],
          rows: _users.map((user) {
            return DataRow(cells: [
              DataCell(Text(user.username,
                  style: const TextStyle(fontWeight: FontWeight.w500))),
              DataCell(Text(user.fullName)),
              DataCell(Text(user.email)),
              DataCell(Center(child: _buildRoleBadge(user.role))),
              DataCell(Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Edit',
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _openUserDialog(user: user),
                  ),
                  IconButton(
                    tooltip: 'Hapus',
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteUser(user.id),
                  ),
                ],
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color color;
    switch (role.toLowerCase()) {
      case 'admin':
        color = Colors.blue;
        break;
      case 'teknisi':
        color = Colors.orange;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        role.toUpperCase(),
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
