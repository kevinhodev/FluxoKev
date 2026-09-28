import '../../../../core/domain/money.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/commitments_summary.dart';
import '../../domain/repositories/commitments_repository.dart';

class ApiCommitmentsRepository implements CommitmentsRepository {
  ApiCommitmentsRepository(this._client);

  final ApiClient _client;

  @override
  Future<CommitmentsSummary> getSummary() async {
    final json = await _client.get('/v1/commitments') as Map<String, dynamic>;
    return CommitmentsSummary(
      generatedAt: DateTime.parse(json['generatedAt'] as String).toLocal(),
      monthlyInstallments: Money(json['monthlyInstallmentsMinorUnits'] as int),
      remainingInstallments: Money(
        json['remainingInstallmentsMinorUnits'] as int,
      ),
      estimatedRecurringMonthly: Money(
        json['estimatedRecurringMonthlyMinorUnits'] as int,
      ),
      installments: (json['installments'] as List<dynamic>)
          .map((item) => _installment(item as Map<String, dynamic>))
          .toList(growable: false),
      recurring: (json['recurring'] as List<dynamic>)
          .map((item) => _recurring(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  InstallmentCommitment _installment(Map<String, dynamic> json) =>
      InstallmentCommitment(
        id: json['id'] as String,
        accountId: json['accountId'] as String,
        accountName: json['accountName'] as String,
        merchantName: json['merchantName'] as String,
        purchaseDate: DateTime.parse(json['purchaseDate'] as String).toLocal(),
        paidInstallments: json['paidInstallments'] as int,
        totalInstallments: json['totalInstallments'] as int,
        remainingInstallments: json['remainingInstallments'] as int,
        installmentAmount: Money(json['installmentAmountMinorUnits'] as int),
        remainingAmount: Money(json['remainingAmountMinorUnits'] as int),
        nextExpectedAt: json['nextExpectedAt'] == null
            ? null
            : DateTime.parse(json['nextExpectedAt'] as String).toLocal(),
      );

  RecurringCommitment _recurring(
    Map<String, dynamic> json,
  ) => RecurringCommitment(
    id: json['id'] as String,
    accountId: json['accountId'] as String,
    accountName: json['accountName'] as String,
    merchantName: json['merchantName'] as String,
    categoryId: json['categoryId'] as String,
    averageAmount: Money(json['averageAmountMinorUnits'] as int),
    lastAmount: Money(json['lastAmountMinorUnits'] as int),
    occurrences: json['occurrences'] as int,
    lastChargedAt: DateTime.parse(json['lastChargedAt'] as String).toLocal(),
    nextExpectedAt: DateTime.parse(json['nextExpectedAt'] as String).toLocal(),
    regularityScore: (json['regularityScore'] as num).toDouble(),
    confidence: json['confidence'] == 'HIGH'
        ? RecurringConfidence.high
        : RecurringConfidence.medium,
  );
}
