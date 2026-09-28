import '../entities/asset_position.dart';

abstract interface class PortfolioRepository {
  Future<List<AssetPosition>> listAssets();
  Future<List<LiabilityPosition>> listLiabilities();
}
