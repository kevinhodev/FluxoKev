import 'package:fluxo_ia/core/domain/money.dart';
import 'package:fluxo_ia/features/accounts/data/repositories/in_memory_account_repository.dart';
import 'package:fluxo_ia/features/financial_engine/domain/financial_engine.dart';
import 'package:fluxo_ia/features/portfolio/data/repositories/in_memory_portfolio_repository.dart';
import 'package:fluxo_ia/features/transactions/data/repositories/in_memory_transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = FinancialEngine();

  test('calcula o fluxo mensal e ignora transferências', () async {
    final transactions = await InMemoryTransactionRepository().list();

    final august = engine.calculateMonthlyCashFlow(
      transactions,
      year: 2026,
      month: 8,
    );

    expect(august.income, const Money(1432000));
    expect(august.expenses, const Money(687045));
    expect(august.balance, const Money(744955));
    expect(august.transactionCount, 18);
  });

  test('compara agosto com julho sem arredondar valores monetários', () async {
    final transactions = await InMemoryTransactionRepository().list();
    final comparison = MonthlyCashFlowComparison(
      current: engine.calculateMonthlyCashFlow(
        transactions,
        year: 2026,
        month: 8,
      ),
      previous: engine.calculateMonthlyCashFlow(
        transactions,
        year: 2026,
        month: 7,
      ),
    );

    expect(comparison.incomeChange, closeTo(0.0821, 0.0001));
    expect(comparison.expenseChange, closeTo(0.0518, 0.0001));
    expect(comparison.balanceChange, closeTo(0.1116, 0.0001));
  });

  test('consolida contas, ativos e passivos no patrimônio', () async {
    final accounts = await InMemoryAccountRepository().listActive();
    final portfolioRepository = InMemoryPortfolioRepository();
    final assets = await portfolioRepository.listAssets();
    final liabilities = await portfolioRepository.listLiabilities();

    final summary = engine.calculatePortfolio(
      accounts: accounts,
      assets: assets,
      liabilities: liabilities,
    );

    expect(summary.cash, const Money(1894225));
    expect(summary.investments, const Money(21430289));
    expect(summary.pension, const Money(14268018));
    expect(summary.liquidAssets, const Money(23324514));
    expect(summary.grossAssets, const Money(37592532));
    expect(summary.totalDebt, const Money(12469400));
    expect(summary.netWorth, const Money(25123132));
  });
}
