import '../../../../core/domain/money.dart';

enum AssetClass { investment, pension }

class AssetPosition {
  const AssetPosition({
    required this.id,
    required this.name,
    required this.assetClass,
    required this.currentValue,
    required this.isLiquid,
  });

  final String id;
  final String name;
  final AssetClass assetClass;
  final Money currentValue;
  final bool isLiquid;
}

class LiabilityPosition {
  const LiabilityPosition({
    required this.id,
    required this.name,
    required this.outstandingBalance,
  });

  final String id;
  final String name;
  final Money outstandingBalance;
}
