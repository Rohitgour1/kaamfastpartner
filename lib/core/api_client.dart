import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kaamfast_partner/core/app_constants.dart';
import 'package:kaamfast_partner/l10n/app_strings.dart';

class TokenStorage {
  static const _key = 'partner_auth_token';
  static const _phoneKey = 'partner_phone';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String?> read() => _storage.read(key: _key);
  Future<void> write(String token) => _storage.write(key: _key, value: token);
  Future<String?> readPhone() => _storage.read(key: _phoneKey);
  Future<void> writePhone(String phone) =>
      _storage.write(key: _phoneKey, value: phone);
  Future<void> clear() async {
    await _storage.delete(key: _key);
    await _storage.delete(key: _phoneKey);
  }
}

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient(this._tokens) {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: AppConstants.connectTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokens.read();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final TokenStorage _tokens;
  late final Dio _dio;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _unwrap(() => _dio.get(path, queryParameters: query));

  Future<dynamic> post(String path, {Object? data}) =>
      _unwrap(() => _dio.post(path, data: data));

  Future<dynamic> put(String path, {Object? data}) =>
      _unwrap(() => _dio.put(path, data: data));

  Future<dynamic> postMultipart(String path, FormData data) =>
      _unwrap(() => _dio.post(path, data: data, options: Options(contentType: 'multipart/form-data')));

  Future<dynamic> _unwrap(Future<Response<dynamic>> Function() call) async {
    try {
      final response = await call();
      final body = response.data;
      if (body is Map<String, dynamic>) {
        if (body['success'] == false) {
          throw ApiException(
            AppStrings.tr(body['message']?.toString() ?? 'Request failed'),
            statusCode: response.statusCode,
          );
        }
        return body['data'];
      }
      return body;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map) {
        final errors = data['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final first = errors.values
              .expand((v) => v is List ? v : [v])
              .map((v) => '$v')
              .where((v) => v.isNotEmpty && v != 'null')
              .firstOrNull;
          if (first != null) {
            throw ApiException(first, statusCode: e.response?.statusCode);
          }
        }
        final message = data['message']?.toString();
        if (message != null && message.isNotEmpty && message != 'null') {
          throw ApiException(
            AppStrings.tr(message),
            statusCode: e.response?.statusCode,
          );
        }
      }
      throw ApiException(_networkMessage(e), statusCode: e.response?.statusCode);
    }
  }

  String _networkMessage(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        AppStrings.tr(
          'Could not connect to the server. Check your internet and try again.',
        ),
      DioExceptionType.connectionError => AppStrings.tr(
        'No internet connection. Turn on Wi-Fi / mobile data.',
      ),
      _ => e.message ?? AppStrings.tr('Network error. Please try again.'),
    };
  }
}
