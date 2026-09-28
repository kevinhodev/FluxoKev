import '../../../core/domain/money.dart';
import '../../../core/network/api_client.dart';

class MerchantAlias {
  const MerchantAlias({
    required this.id,
    required this.pattern,
    required this.merchantName,
    required this.matches,
    required this.total,
    required this.descriptors,
    required this.categoryId,
  });

  final String id;
  final String pattern;
  final String merchantName;
  final int matches;
  final Money total;

  /// Descritores brutos que esta regra substituiu.
  final List<String> descriptors;

  /// Nulo quando a regra só renomeia, sem fixar categoria.
  final String? categoryId;
}

/// Quantas transações um prefixo pegaria, antes de salvar.
class AliasPreview {
  const AliasPreview({
    required this.matches,
    required this.total,
    required this.samples,
  });

  final int matches;
  final Money total;

  /// Descritores distintos que o prefixo alcança, para o usuário conferir
  /// que não está juntando coisa errada.
  final List<String> samples;
}

class MerchantAliasesApi {
  const MerchantAliasesApi(this._client);

  final ApiClient _client;

  Future<List<MerchantAlias>> list() async {
    final rows = await _client.get('/v1/merchant-aliases') as List<dynamic>;
    return rows
        .map((row) => _alias(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<AliasPreview> preview(String pattern) async {
    final json =
        await _client.get(
              '/v1/merchant-aliases/preview',
              query: {'pattern': pattern},
            )
            as Map<String, dynamic>;
    return AliasPreview(
      matches: (json['matches'] as num).toInt(),
      total: Money((json['totalMinorUnits'] as num).toInt()),
      samples: (json['samples'] as List<dynamic>).cast<String>(),
    );
  }

  Future<MerchantAlias> create({
    required String pattern,
    required String merchantName,
    String? categoryId,
  }) async {
    final json =
        await _client.post(
              '/v1/merchant-aliases',
              body: {
                'pattern': pattern,
                'merchantName': merchantName,
                'categoryId': categoryId,
              },
            )
            as Map<String, dynamic>;
    return _alias(json);
  }

  Future<MerchantAlias> update({
    required String id,
    required String pattern,
    required String merchantName,
    String? categoryId,
  }) async {
    final json =
        await _client.put(
              '/v1/merchant-aliases/$id',
              body: {
                'pattern': pattern,
                'merchantName': merchantName,
                'categoryId': categoryId,
              },
            )
            as Map<String, dynamic>;
    return _alias(json);
  }

  Future<void> remove(String id) =>
      _client.delete('/v1/merchant-aliases/$id');

  MerchantAlias _alias(Map<String, dynamic> json) => MerchantAlias(
    id: json['id'] as String,
    pattern: json['pattern'] as String,
    merchantName: json['merchantName'] as String,
    matches: (json['matches'] as num).toInt(),
    total: Money((json['totalMinorUnits'] as num).toInt()),
    descriptors: (json['descriptors'] as List<dynamic>? ?? const [])
        .cast<String>(),
    categoryId: json['categoryId'] as String?,
  );
}
