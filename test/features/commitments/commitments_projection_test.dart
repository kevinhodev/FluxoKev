import 'package:flutter_test/flutter_test.dart';
import 'package:fluxo_ia/core/domain/money.dart';
import 'package:fluxo_ia/features/commitments/domain/entities/commitments_summary.dart';

void main() {
  test('projection removes an installment after its final month', () {
    final summary = CommitmentsSummary(
      generatedAt: DateTime(2026, 8, 14),
      monthlyInstallments: const Money(30000),
      remainingInstallments: const Money(70000),
      estimatedRecurringMonthly: const Money(5000),
      installments: [
        InstallmentCommitment(
          id: 'finishes-now',
          accountId: 'visa',
          accountName: 'Visa',
          merchantName: 'Compra curta',
          purchaseDate: DateTime(2026, 7, 1),
          paidInstallments: 1,
          totalInstallments: 2,
          remainingInstallments: 1,
          installmentAmount: const Money(10000),
          remainingAmount: const Money(10000),
          nextExpectedAt: DateTime(2026, 8, 20),
        ),
        InstallmentCommitment(
          id: 'continues',
          accountId: 'elo',
          accountName: 'Elo',
          merchantName: 'Compra longa',
          purchaseDate: DateTime(2026, 6, 1),
          paidInstallments: 2,
          totalInstallments: 5,
          remainingInstallments: 3,
          installmentAmount: const Money(20000),
          remainingAmount: const Money(60000),
          nextExpectedAt: DateTime(2026, 9, 5),
        ),
      ],
      recurring: [
        RecurringCommitment(
          id: 'subscription',
          accountId: 'elo',
          accountName: 'Elo',
          merchantName: 'Assinatura',
          categoryId: 'subscriptions',
          averageAmount: const Money(5000),
          lastAmount: const Money(5000),
          occurrences: 3,
          lastChargedAt: DateTime(2026, 8, 5),
          nextExpectedAt: DateTime(2026, 9, 5),
          regularityScore: .9,
          confidence: RecurringConfidence.high,
        ),
      ],
    );

    final projection = summary.projection(months: 5);

    expect(projection.map((item) => item.total.minorUnits), [
      10000,
      25000,
      25000,
      25000,
      5000,
    ]);
    expect(projection[1].installments.minorUnits, 20000);
    expect(projection[1].estimatedRecurring.minorUnits, 5000);
  });
}
