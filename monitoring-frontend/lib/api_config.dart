class ApiConfig {
  static const String baseUrl = 'http://localhost:8000';
  static const String apiVersion = '/api/v1';
  static const String url = '$baseUrl$apiVersion';

  // Endpoints
  static const String login = '$baseUrl$apiVersion/auth/login';
  static const String register = '$baseUrl$apiVersion/auth/register';
  static const String me = '$baseUrl$apiVersion/auth/me';
  static const String devices = '$baseUrl$apiVersion/devices';
  static const String switches = '$baseUrl$apiVersion/switches';
  static const String deviceNodes = '$baseUrl$apiVersion/devices/nodes';
  static const String deviceTypes = '$baseUrl$apiVersion/devices/types';
  static const String locations = '$baseUrl$apiVersion/locations';
  static const String networkNodes = '$baseUrl$apiVersion/network-nodes';
  static const String foRoutes = '$baseUrl$apiVersion/fo-routes';
  static const String mapTopology = '$baseUrl$apiVersion/map/topology';
  static const String alerts = '$baseUrl$apiVersion/alerts';
  static const String users = '$baseUrl$apiVersion/users';
  static const String dashboardStats = '$baseUrl$apiVersion/dashboard/stats';
  static const String dashboardTraffic =
      '$baseUrl$apiVersion/dashboard/traffic';
  static const String dashboardUptimeTrend =
      '$baseUrl$apiVersion/dashboard/uptime-trend';
  static const String syncLibreNMS = '$baseUrl$apiVersion/sync/from-librenms';
  static const String deviceList = '$baseUrl$apiVersion/devices/with-locations';
  static const String switchList =
      '$baseUrl$apiVersion/switches/with-locations';
  static const String registerLibreNMS =
      '$baseUrl$apiVersion/register/librenms';
  static String get wsUrl {
    return baseUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://');
  }

  static String get wsStatusEndpoint => '$wsUrl$apiVersion/ws/status';
}
