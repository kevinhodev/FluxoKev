import '../../../../core/domain/money.dart';
import '../../domain/entities/asset_position.dart';
import '../../domain/repositories/portfolio_repository.dart';

class InMemoryPortfolioRepository implements PortfolioRepository {
  static const _assets = [
    AssetPosition(
      id: 'asset-investments',
      name: 'Investimentos',
      assetClass: AssetClass.investment,
      currentValue: Money(21430289),
      isLiquid: true,
    ),
    AssetPosition(
      id: 'asset-previ',
      name: 'PREVI',
      assetClass: AssetClass.pension,
      currentValue: Money(14268018),
      isLiquid: false,
    ),
  ];

  // Cartões vêm das contas. Aqui ficam apenas passivos sem conta sincronizada.
  static const _liabilities = [
    LiabilityPosition(
      id: 'liability-personal-loan',
      name: 'Empréstimo pessoal',
      outstandingBalance: Money(12195915),
    ),
  ];

  @override
  Future<List<AssetPosition>> listAssets() async => List.unmodifiable(_assets);

  @override
  Future<List<LiabilityPosition>> listLiabilities() async =>
      List.unmodifiable(_liabilities);
}
