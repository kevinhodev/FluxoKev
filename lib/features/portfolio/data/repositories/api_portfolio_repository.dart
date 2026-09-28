import '../../../../core/domain/money.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/asset_position.dart';
import '../../domain/repositories/portfolio_repository.dart';

class ApiPortfolioRepository implements PortfolioRepository {
  const ApiPortfolioRepository(this._client);

  final ApiClient _client;

  Future<Map<String, dynamic>> _load() async =>
      await _client.get('/v1/portfolio/positions') as Map<String, dynamic>;

  @override
  Future<List<AssetPosition>> listAssets() async {
    final json = await _load();
    return (json['assets'] as List<dynamic>)
        .map((item) {
          final row = item as Map<String, dynamic>;
          return AssetPosition(
            id: row['id'] as String,
            name: row['name'] as String,
            assetClass: row['assetClass'] == 'PENSION'
                ? AssetClass.pension
                : AssetClass.investment,
            currentValue: Money((row['currentValueMinorUnits'] as num).toInt()),
            isLiquid: row['isLiquid'] as bool,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<List<LiabilityPosition>> listLiabilities() async {
    final json = await _load();
    return (json['liabilities'] as List<dynamic>)
        .map((item) {
          final row = item as Map<String, dynamic>;
          return LiabilityPosition(
            id: row['id'] as String,
            name: row['name'] as String,
            outstandingBalance: Money(
              (row['outstandingBalanceMinorUnits'] as num).toInt(),
            ),
          );
        })
        .toList(growable: false);
  }
}
