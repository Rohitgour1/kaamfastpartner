class AppConstants {
  AppConstants._();

  static const String appName = 'Kaam Fast Partner';

  /// Override locally: `--dart-define=API_BASE=http://YOUR_LAN_IP:8000/api/v1`
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://kaamfast.com/api/v1',
  );

  /// Website root (API base without `/api/v1`); legal pages are admin Landing Pages.
  static String get siteUrl => apiBaseUrl.replaceFirst(RegExp(r'/api/v\d+/?$'), '');
  static String get privacyPolicyUrl => '$siteUrl/p/privacy-policy';
  static String get termsUrl => '$siteUrl/p/terms';

  /// Bump when Terms / Privacy text changes so the server can ask for fresh consent.
  static const String legalVersion = '2026-10-11';

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const String defaultCountryCode = '+91';
  static const String debugOtpHint = '123456';
  static const String supportEmail = 'support@kaamfast.com';
  static const String supportPhone = '+918000000000';
  static const String supportWhatsApp = '918000000000';
}
