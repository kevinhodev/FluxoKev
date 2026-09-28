import '../../../../core/domain/money.dart';
import '../../domain/entities/commitments_summary.dart';
import '../../domain/repositories/commitments_repository.dart';

class InMemoryCommitmentsRepository implements CommitmentsRepository {
  @override
  Future<CommitmentsSummary> getSummary() async => CommitmentsSummary(
    generatedAt: DateTime(2026, 8, 14),
    monthlyInstallments: const Money(284940),
    remainingInstallments: const Money(986720),
    estimatedRecurringMonthly: const Money(14570),
    installments: [
      InstallmentCommitment(
        id: 'installment-1',
        accountId: 'account-bb-card',
        accountName: 'Ourocard Visa',
        merchantName: 'Notebook',
        purchaseDate: DateTime(2026, 3, 12),
        paidInstallments: 5,
        totalInstallments: 12,
        remainingInstallments: 7,
        installmentAmount: const Money(54990),
        remainingAmount: const Money(384930),
        nextExpectedAt: DateTime(2026, 9, 12),
      ),
      InstallmentCommitment(
        id: 'installment-2',
        accountId: 'account-bb-card',
        accountName: 'Ourocard Elo',
        merchantName: 'Loja Online',
        purchaseDate: DateTime(2026, 5, 20),
        paidInstallments: 3,
        totalInstallments: 10,
        remainingInstallments: 7,
        installmentAmount: const Money(18990),
        remainingAmount: const Money(132930),
        nextExpectedAt: DateTime(2026, 9, 20),
      ),
    ],
    recurring: [
      RecurringCommitment(
        id: 'recurring-1',
        accountId: 'account-bb-card',
        accountName: 'Ourocard Visa',
        merchantName: 'Netflix',
        categoryId: 'subscriptions-streaming',
        averageAmount: const Money(5590),
        lastAmount: const Money(5590),
        occurrences: 6,
        lastChargedAt: DateTime(2026, 8, 5),
        nextExpectedAt: DateTime(2026, 9, 5),
        regularityScore: .98,
        confidence: RecurringConfidence.high,
      ),
    ],
  );
}
