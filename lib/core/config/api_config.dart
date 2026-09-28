import 'package:flutter/foundation.dart';

class ApiConfig {
  const ApiConfig._(this.baseUri);

  static const _definedBaseUrl = String.fromEnvironment('FLUXO_API_URL');
  static const _androidEmulatorUrl = 'http://10.0.2.2:8080';

  final Uri baseUri;

  factory ApiConfig.fromEnvironment() {
    final rawUrl = _definedBaseUrl.isEmpty
        ? _androidEmulatorUrl
        : _definedBaseUrl;
    return ApiConfig.parse(rawUrl, releaseMode: kReleaseMode);
  }

  factory ApiConfig.parse(String rawUrl, {bool releaseMode = false}) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null ||
        !uri.hasScheme ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw FormatException('FLUXO_API_URL inválida: $rawUrl');
    }
    if (releaseMode && uri.scheme != 'https') {
      throw StateError('A API deve usar HTTPS em builds de produção.');
    }
    return ApiConfig._(
      uri.replace(path: uri.path.replaceFirst(RegExp(r'/$'), '')),
    );
  }

  Uri endpoint(String path) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    final basePath = baseUri.path.endsWith('/')
        ? baseUri.path
        : '${baseUri.path}/';
    return baseUri.replace(path: '$basePath$normalizedPath');
  }
}
