part of '../dashboard_screen.dart';

mixin DashboardScreenWidgets on State<DashboardScreen> {
  Widget buildDashboardScreen(BuildContext context) {
    final state = this as _DashboardScreenState;

    return RefreshIndicator(
      onRefresh: state._handleManualRefresh,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          scrollbars: false,
        ),
        child: SingleChildScrollView(
          controller: state._scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ValueListenableBuilder<bool>(
              valueListenable: state._isStatsLoading,
              builder: (context, loading, _) {
                return ValueListenableBuilder<Object?>(
                  valueListenable: state._statsError,
                  builder: (context, error, _) {
                    return ValueListenableBuilder<DashboardStats?>(
                      valueListenable: state._dashboardStats,
                      builder: (context, stats, _) {
                        if (loading && stats == null) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        if (error != null) {
                          return AsyncErrorWidget(
                            error: error,
                            onRetry: state._handleManualRefresh,
                          );
                        }

                        if (stats == null) {
                          return const EmptyStateWidget(
                            message: "No dashboard data available",
                            icon: Icons.dashboard_customize_outlined,
                          );
                        }

                        final offlineCount =
                            stats.totalDevices - stats.onlineDevices;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Overview",
                              style: TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 24),
                            _buildFilters(state),
                            const SizedBox(height: 20),
                            DashboardSummaryGrid(
                              stats: stats,
                              offlineCount: offlineCount,
                            ),
                            const SizedBox(height: 30),
                            _buildCharts(state),
                            const SizedBox(height: 30),
                            _buildTopDown(state, stats),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(_DashboardScreenState state) {
    return ValueListenableBuilder<bool>(
      valueListenable: state._isLoadingLocations,
      builder: (context, loadingLocations, _) {
        return ValueListenableBuilder<List<Location>>(
          valueListenable: state._locations,
          builder: (context, locations, _) {
            return ValueListenableBuilder<String?>(
              valueListenable: state._selectedLocationName,
              builder: (context, selected, _) {
                return DashboardFilters(
                  isLoading: loadingLocations,
                  locations: locations,
                  selectedLocationName: selected,
                  onLocationChanged: (value) {
                    state._selectedLocationName.value = value;
                    state._refreshDashboard();
                    state._resetTrafficData();
                    if (state._chartsInitialized) {
                      state._refreshUptimeTrend();
                    }
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCharts(_DashboardScreenState state) {
    return ValueListenableBuilder<bool>(
      valueListenable: state._chartsVisible,
      builder: (context, visible, _) {
        if (!visible) {
          return Container(
            key: state._chartsKey,
            height: 320,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              "Scroll to load charts",
              style: TextStyle(color: Colors.grey[500]),
            ),
          );
        }

        return Container(
          key: state._chartsKey,
          child: ValueListenableBuilder<List<NetworkActivityData>>(
            valueListenable: state._trafficData,
            builder: (context, traffic, _) {
              return ValueListenableBuilder<bool>(
                valueListenable: state._isTrafficLoading,
                builder: (context, trafficLoading, _) {
                  return ValueListenableBuilder<List<UptimeTrendPoint>>(
                    valueListenable: state._uptimeTrendData,
                    builder: (context, uptime, _) {
                      return ValueListenableBuilder<bool>(
                        valueListenable: state._isUptimeLoading,
                        builder: (context, uptimeLoading, _) {
                          return DashboardCharts(
                            trafficData: traffic,
                            isTrafficLoading: trafficLoading,
                            uptimeData: uptime,
                            isUptimeLoading: uptimeLoading,
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTopDown(_DashboardScreenState state, DashboardStats stats) {
    return ValueListenableBuilder<bool>(
      valueListenable: state._topDownVisible,
      builder: (context, visible, _) {
        if (!visible) {
          return Container(
            key: state._topDownKey,
            height: 220,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              "Scroll to load top down",
              style: TextStyle(color: Colors.grey[500]),
            ),
          );
        }

        return Container(
          key: state._topDownKey,
          child: ValueListenableBuilder<int>(
            valueListenable: state._topDownWindowDays,
            builder: (context, windowDays, _) {
              return DashboardTopDown(
                stats: stats,
                selectedWindowDays: windowDays,
                onWindowChanged: (window) {
                  state._topDownWindowDays.value = window;
                  state._refreshDashboard();
                },
              );
            },
          ),
        );
      },
    );
  }
}
