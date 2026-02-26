part of '../device_list_screen.dart';

mixin DeviceListWidgets on State<DeviceListScreen> {
  Widget buildDeviceListScreen(BuildContext context) {
    final state = this as _DeviceListScreenState;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        onRefresh: state._fetchNodes,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(state)),
            _buildDeviceList(state),
            SliverToBoxAdapter(child: _buildPagination(state)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(_DeviceListScreenState state) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Device List",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          SearchBarWidget(
            controller: state._searchController,
            hintText: 'Search by name or IP address',
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DeviceFilterBar(
                  selectedType: state._selectedType,
                  selectedLocation: state._selectedLocation,
                  selectedStatus: state._selectedStatus,
                  deviceTypes: state._deviceTypes,
                  locations: state._locations,
                  onTypeChanged: (v) => state._updateFilter(type: v),
                  onLocationChanged: (v) => state._updateFilter(location: v),
                  onStatusChanged: (v) => state._updateFilter(status: v),
                  onClearFilters: state._clearFilters,
                ),
              ),
              if (state._isAdmin) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    final refresh =
                        await Navigator.pushNamed(context, '/register-node');
                    if (refresh == true) state._fetchNodes();
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text("Register"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _buildResultsSummary(state),
        ],
      ),
    );
  }

  Widget _buildResultsSummary(_DeviceListScreenState state) {
    final showing = state._paginatedNodes.length;
    final total = state._totalItems;

    return Row(
      children: [
        Text(
          "Showing $showing of $total devices",
          style: TextStyle(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildDeviceList(_DeviceListScreenState state) {
    if (state._isLoading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state._error != null) {
      return SliverFillRemaining(
        child: AsyncErrorWidget(
          error: state._error!,
          onRetry: state._fetchNodes,
          message: 'Failed to load devices',
        ),
      );
    }

    if (state._nodes.isEmpty) {
      if (state._searchQuery.isNotEmpty) {
        return SliverFillRemaining(
          child: EmptyStateWidget.searching(
            isSearching: true,
            searchQuery: state._searchQuery,
            label: 'devices',
            defaultIcon: Icons.devices_other,
          ),
        );
      }

      return SliverFillRemaining(
        child: EmptyStateWidget(
          message: 'No devices found',
          icon: Icons.devices_other,
          onAction: (state._searchQuery.isNotEmpty ||
                  state._selectedType != null ||
                  state._selectedLocation != null ||
                  state._selectedStatus != null)
              ? state._clearFilters
              : null,
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final node = state._paginatedNodes[index];
            final key = '${node.nodeKind}_${node.id}';
            final statusNotifier = state._statusNotifiers[key];
            final liveStatsNotifier = state._liveStatsNotifiers[key];

            return DeviceCard(
              key: ValueKey(node.id),
              node: node,
              isAdmin: state._isAdmin,
              onRefresh: state._fetchNodes,
              liveStatsListenable: liveStatsNotifier,
              statusListenable: statusNotifier,
            );
          },
          childCount: state._paginatedNodes.length,
        ),
      ),
    );
  }

  Widget _buildPagination(_DeviceListScreenState state) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: PaginationWidget(
        currentPage: state._currentPage,
        totalPages: state._totalPages,
        onPageChanged: (page) {
          state.setState(() => state._currentPage = page);
          state._fetchNodes();
        },
      ),
    );
  }
}
