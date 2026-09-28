import '../../../../core/domain/money.dart';

class InstallmentCommitment {
  const InstallmentCommitment({
    required this.id,
    required this.accountId,
    required this.accountName,
    required this.merchantName,
    required this.purchaseDate,
    required this.paidInstallments,
    required this.totalInstallments,
    required this.remainingInstallments,
    required this.installmentAmount,
    required this.remainingAmount,
    this.nextExpectedAt,
  });

  final String id;
  final String accountId;
  final String accountName;
  final String merchantName;
  final DateTime purchaseDate;
  final int paidInstallments;
  final int totalInstallments;
  final int remainingInstallments;
  final Money installmentAmount;
  final Money remainingAmount;
  final DateTime? nextExpectedAt;

  double get progress => totalInstallments == 0
      ? 0
      : (paidInstallments / totalInstallments).clamp(0, 1);
}

enum RecurringConfidence { high, medium }

class RecurringCommitment {
  const RecurringCommitment({
    required this.id,
    required this.accountId,
    required this.accountName,
    required this.merchantName,
    required this.categoryId,
    required this.averageAmount,
    required this.lastAmount,
    required this.occurrences,
    required this.lastChargedAt,
    required this.nextExpectedAt,
    required this.regularityScore,
    required this.confidence,
  });

  final String id;
  final String accountId;
  final String accountName;
  final String merchantName;
  final String categoryId;
  final Money averageAmount;
  final Money lastAmount;
  final int occurrences;
  final DateTime lastChargedAt;
  final DateTime nextExpectedAt;
  final double regularityScore;
  final RecurringConfidence confidence;
}

class MonthlyCommitmentProjection {
  const MonthlyCommitmentProjection({
    required this.month,
    required this.installments,
    required this.estimatedRecurring,
  });

  final DateTime month;
  final Money installments;
  final Money estimatedRecurring;

  Money get total => installments + estimatedRecurring;
}

class CommitmentsSummary {
  const CommitmentsSummary({
    required this.generatedAt,
    required this.monthlyInstallments,
    required this.remainingInstallments,
    required this.estimatedRecurringMonthly,
    required this.installments,
    required this.recurring,
  });

  final DateTime generatedAt;
  final Money monthlyInstallments;
  final Money remainingInstallments;
  final Money estimatedRecurringMonthly;
  final List<InstallmentCommitment> installments;
  final List<RecurringCommitment> recurring;

  Money get estimatedMonthlyCommitment =>
      monthlyInstallments + estimatedRecurringMonthly;

  List<MonthlyCommitmentProjection> projection({int months = 6}) {
    if (months <= 0) return const [];

    final start = DateTime(generatedAt.year, generatedAt.month);
    final installmentTotals = List<int>.filled(months, 0);
    final recurringTotals = List<int>.filled(months, 0);

    for (final item in installments) {
      final nextExpectedAt = item.nextExpectedAt;
      if (nextExpectedAt == null) continue;
      final firstMonth = DateTime(nextExpectedAt.year, nextExpectedAt.month);
      for (var index = 0; index < item.remainingInstallments; index++) {
        final target = DateTime(firstMonth.year, firstMonth.month + index);
        final offset = _monthOffset(start, target);
        if (offset >= 0 && offset < months) {
          installmentTotals[offset] += item.installmentAmount.minorUnits;
        }
      }
    }

    for (final item in recurring) {
      var firstMonth = DateTime(
        item.nextExpectedAt.year,
        item.nextExpectedAt.month,
      );
      while (_monthOffset(start, firstMonth) < 0) {
        firstMonth = DateTime(firstMonth.year, firstMonth.month + 1);
      }
      final firstOffset = _monthOffset(start, firstMonth);
      for (var offset = firstOffset; offset < months; offset++) {
        recurringTotals[offset] += item.averageAmount.minorUnits;
      }
    }

    return List.generate(
      months,
      (index) => MonthlyCommitmentProjection(
        month: DateTime(start.year, start.month + index),
        installments: Money(installmentTotals[index]),
        estimatedRecurring: Money(recurringTotals[index]),
      ),
      growable: false,
    );
  }

  static int _monthOffset(DateTime start, DateTime target) =>
      (target.year - start.year) * 12 + target.month - start.month;
}
