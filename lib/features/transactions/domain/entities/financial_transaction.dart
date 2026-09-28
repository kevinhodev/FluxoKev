import '../../../../core/domain/money.dart';

enum TransactionDirection { credit, debit }

enum TransactionNature { income, expense, transfer, investmentReturn }

enum TransactionSource {
  openFinance,
  pluggy,
  ofxImport,
  csvImport,
  xlsxImport,
  pdfImport,
  manual,
}

class FinancialTransaction {
  FinancialTransaction({
    required this.id,
    required this.accountId,
    required this.occurredAt,
    required this.description,
    required this.merchantName,
    required this.amount,
    required this.direction,
    required this.nature,
    required this.categoryId,
    required this.source,
    this.externalId,
    this.providerStatus,
    this.providerCategory,
    this.note,
  }) : assert(amount.minorUnits >= 0, 'O valor deve ser absoluto.');

  final String id;
  final String accountId;
  final DateTime occurredAt;
  final String description;
  final String merchantName;
  final Money amount;
  final TransactionDirection direction;
  final TransactionNature nature;
  final String categoryId;
  final TransactionSource source;
  final String? externalId;
  final String? providerStatus;
  final String? providerCategory;
  final String? note;

  bool get isPending => providerStatus == 'PENDING';

  Money get signedAmount =>
      direction == TransactionDirection.credit ? amount : amount.negated;

  bool get affectsCashFlow =>
      nature == TransactionNature.income || nature == TransactionNature.expense;

  FinancialTransaction copyWith({String? categoryId, String? note}) {
    return FinancialTransaction(
      id: id,
      accountId: accountId,
      occurredAt: occurredAt,
      description: description,
      merchantName: merchantName,
      amount: amount,
      direction: direction,
      nature: nature,
      categoryId: categoryId ?? this.categoryId,
      source: source,
      externalId: externalId,
      providerStatus: providerStatus,
      providerCategory: providerCategory,
      note: note ?? this.note,
    );
  }
}
