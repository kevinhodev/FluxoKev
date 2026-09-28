import '../../domain/entities/asset_position.dart';
import '../../domain/repositories/portfolio_repository.dart';

/// Fontes ainda não conectadas (PREVI e empréstimos) não entram nos totais.
class EmptyPortfolioRepository implements PortfolioRepository {
  const EmptyPortfolioRepository();

  @override
  Future<List<AssetPosition>> listAssets() async => const [];

  @override
  Future<List<LiabilityPosition>> listLiabilities() async => const [];
}
