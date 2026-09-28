import 'package:fluxo_ia/core/config/api_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('monta endpoints a partir da URL base', () {
    final config = ApiConfig.parse('http://10.0.2.2:8080/');

    expect(
      config.endpoint('/v1/transactions').toString(),
      'http://10.0.2.2:8080/v1/transactions',
    );
  });

  test('bloqueia HTTP em produção', () {
    expect(
      () => ApiConfig.parse('http://api.fluxo.local', releaseMode: true),
      throwsStateError,
    );
    expect(
      ApiConfig.parse(
        'https://api.fluxo.local',
        releaseMode: true,
      ).baseUri.scheme,
      'https',
    );
  });

  test('rejeita URL sem host', () {
    expect(() => ApiConfig.parse('localhost:8080'), throwsFormatException);
  });
}
