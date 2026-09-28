import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../financial_engine/domain/financial_engine.dart';
import '../../auth/application/auth_controller.dart';
import '../../portfolio/data/repositories/api_portfolio_repository.dart';
import '../../portfolio/domain/repositories/portfolio_repository.dart';
import '../../transactions/application/transaction_providers.dart';
import '../../transactions/domain/repositories/transaction_repository.dart';

class FinancialDashboardSnapshot {
  const FinancialDashboardSnapshot({
    required this.portfolio,
    required this.cashFlow,
  });

  final PortfolioSummary portfolio;
  final MonthlyCashFlowComparison cashFlow;
}

final portfolioRepositoryProvider = Provider<PortfolioRepository>(
  (ref) => ApiPortfolioRepository(ref.watch(apiClientProvider)),
);

final financialEngineProvider = Provider<FinancialEngine>(
  (ref) => const FinancialEngine(),
);

final financialDashboardProvider = FutureProvider<FinancialDashboardSnapshot>((
  ref,
) async {
  final accounts = await ref.watch(accountRepositoryProvider).listActive();
  final now = DateTime.now();
  final previousMonth = DateTime(now.year, now.month - 1);
  final transactions = await ref
      .watch(transactionRepositoryProvider)
      .list(
        query: TransactionQuery(
          from: DateTime(previousMonth.year, previousMonth.month),
          to: DateTime(
            now.year,
            now.month + 1,
          ).subtract(const Duration(microseconds: 1)),
        ),
      );
  final portfolioRepository = ref.watch(portfolioRepositoryProvider);
  final assets = await portfolioRepository.listAssets();
  final liabilities = await portfolioRepository.listLiabilities();
  final engine = ref.watch(financialEngineProvider);

  final portfolio = engine.calculatePortfolio(
    accounts: accounts,
    assets: assets,
    liabilities: liabilities,
  );
  final current = engine.calculateMonthlyCashFlow(
    transactions,
    year: now.year,
    month: now.month,
  );
  final previous = engine.calculateMonthlyCashFlow(
    transactions,
    year: previousMonth.year,
    month: previousMonth.month,
  );

  return FinancialDashboardSnapshot(
    portfolio: portfolio,
    cashFlow: MonthlyCashFlowComparison(current: current, previous: previous),
  );
});
