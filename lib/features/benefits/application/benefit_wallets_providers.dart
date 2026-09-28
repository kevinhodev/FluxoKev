import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/benefit_wallets_api.dart';
import '../domain/benefit_wallet.dart';

final benefitWalletsApiProvider = Provider<BenefitWalletsApi>(
  (ref) => BenefitWalletsApi(ref.watch(apiClientProvider)),
);

final benefitWalletsProvider = FutureProvider<List<BenefitWallet>>(
  (ref) => ref.watch(benefitWalletsApiProvider).list(),
);
