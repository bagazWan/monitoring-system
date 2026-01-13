class ApiConfig {
  static const String baseUrl = 'http://localhost:8080';
  static const String apiVersion = '/api/v1';

  // Endpoints
  static const String login = '$baseUrl$apiVersion/auth/login';
  static const String register = '$baseUrl$apiVersion/auth/register';
  static const String me = '$baseUrl$apiVersion/auth/me';
  static const String devices = '$baseUrl$apiVersion/devices';
  static const String switches = '$baseUrl$apiVersion/switches';
  static const String locations = '$baseUrl$apiVersion/locations';
  static const String alerts = '$baseUrl$apiVersion/alerts';
  static const String users = '$baseUrl$apiVersion/users';
  static const String dashboardStats = '$baseUrl$apiVersion/stats';
  static const String syncLibreNMS = '$baseUrl$apiVersion/sync/from-librenms';
  static const String deviceInfo = '$baseUrl$apiVersion/devices';
  static const String switchInfo = '$baseUrl$apiVersion/switches';
  static const String deviceList = '$baseUrl$apiVersion/devices/with-locations';
  static const String switchList =
      '$baseUrl$apiVersion/switches/with-locations';
}
