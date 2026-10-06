abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'TRAVLA_API_BASE_URL',
    defaultValue: 'https://travla.com.ng/api/v1',
  );

  static const webBaseUrl = String.fromEnvironment(
    'TRAVLA_WEB_BASE_URL',
    defaultValue: 'https://travla.com.ng',
  );

  static const appType = 'customer';
  static const appName = 'Travla';
}
