import 'dart:convert';
import 'dart:io';

import '../config/api_config.dart';

class ApiException implements Exception {
  const ApiException(this.statusCode, this.code, this.message);

  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({required this.config, this.accessToken, HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  final ApiConfig config;
  final String? accessToken;
  final HttpClient _httpClient;

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, {Object? body}) =>
      _send('POST', path, body: body);

  Future<dynamic> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);

  Future<dynamic> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    var uri = config.endpoint(path);
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query);
    }
    final request = await _httpClient.openUrl(method, uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.contentType = ContentType.json;
    if (accessToken case final token?) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    if (body != null) request.write(jsonEncode(body));

    final response = await request.close();
    final raw = await utf8.decoder.bind(response).join();
    final decoded = raw.isEmpty ? null : jsonDecode(raw);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded is Map<String, dynamic>
          ? decoded['error'] as Map<String, dynamic>?
          : null;
      throw ApiException(
        response.statusCode,
        error?['code'] as String? ?? 'HTTP_ERROR',
        error?['message'] as String? ?? 'Falha ao acessar o servidor.',
      );
    }
    return decoded;
  }
}
