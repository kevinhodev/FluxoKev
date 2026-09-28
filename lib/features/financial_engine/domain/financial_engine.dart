import '../../../core/domain/money.dart';
import '../../accounts/domain/entities/financial_account.dart';
import '../../portfolio/domain/entities/asset_position.dart';
import '../../transactions/domain/entities/financial_transaction.dart';

class MonthlyCashFlow {
  const MonthlyCashFlow({
    required this.year,
    required this.month,
    required this.income,
    required this.expenses,
    required this.transactionCount,
  });

  final int year;
  final int month;
  final Money income;
  final Money expenses;
  final int transactionCount;

  Money get balance => income - expenses;
  double get expenseRatio =>
      income.isZero ? 0 : expenses.minorUnits / income.minorUnits;
}

class MonthlyCashFlowComparison {
  const MonthlyCashFlowComparison({
    required this.current,
    required this.previous,
  });

  final MonthlyCashFlow current;
  final MonthlyCashFlow previous;

  double? get incomeChange =>
      _percentageChange(current.income.minorUnits, previous.income.minorUnits);

  double? get expenseChange => _percentageChange(
    current.expenses.minorUnits,
    previous.expenses.minorUnits,
  );

  double? get balanceChange => _percentageChange(
    current.balance.minorUnits,
    previous.balance.minorUnits,
  );
}

class PortfolioSummary {
  const PortfolioSummary({
    required this.cash,
    required this.investments,
    required this.pension,
    required this.liquidAssets,
    required this.grossAssets,
    required this.totalDebt,
  });

  final Money cash;
  final Money investments;
  final Money pension;
  final Money liquidAssets;
  final Money grossAssets;
  final Money totalDebt;

  Money get netWorth => grossAssets - totalDebt;

  double shareOfGross(Money value) =>
      grossAssets.isZero ? 0 : value.minorUnits / grossAssets.minorUnits;
}

class FinancialEngine {
  const FinancialEngine();

  MonthlyCashFlow calculateMonthlyCashFlow(
    Iterable<FinancialTransaction> transactions, {
    required int year,
    required int month,
  }) {
    var income = const Money.zero();
    var expenses = const Money.zero();
    var count = 0;

    for (final transaction in transactions) {
      if (transaction.occurredAt.year != year ||
          transaction.occurredAt.month != month) {
        continue;
      }
      count++;
      if (!transaction.affectsCashFlow) continue;
      if (transaction.nature == TransactionNature.income) {
        income += transaction.amount;
      } else if (transaction.nature == TransactionNature.expense) {
        expenses += transaction.amount;
      }
    }

    return MonthlyCashFlow(
      year: year,
      month: month,
      income: income,
      expenses: expenses,
      transactionCount: count,
    );
  }

  PortfolioSummary calculatePortfolio({
    required Iterable<FinancialAccount> accounts,
    required Iterable<AssetPosition> assets,
    required Iterable<LiabilityPosition> liabilities,
  }) {
    var cash = const Money.zero();
    var investments = const Money.zero();
    var pension = const Money.zero();
    var liquidInvestments = const Money.zero();
    var totalDebt = const Money.zero();
    final countedCreditGroups = <String>{};

    for (final account in accounts) {
      if (!account.isCreditCard && account.currentBalance.isPositive) {
        cash += account.currentBalance;
      } else if (account.isCreditCard && account.currentBalance.isNegative) {
        final groupKey = account.balanceGroupKey ?? account.id;
        if (countedCreditGroups.add(groupKey)) {
          totalDebt += account.currentBalance.absolute;
        }
      }
    }
    for (final asset in assets) {
      switch (asset.assetClass) {
        case AssetClass.investment:
          investments += asset.currentValue;
        case AssetClass.pension:
          pension += asset.currentValue;
      }
      if (asset.isLiquid) liquidInvestments += asset.currentValue;
    }
    for (final liability in liabilities) {
      totalDebt += liability.outstandingBalance.absolute;
    }

    return PortfolioSummary(
      cash: cash,
      investments: investments,
      pension: pension,
      liquidAssets: cash + liquidInvestments,
      grossAssets: cash + investments + pension,
      totalDebt: totalDebt,
    );
  }
}

double? _percentageChange(int current, int previous) {
  if (previous == 0) return null;
  return (current - previous) / previous;
}
