import '../entities/financial_transaction.dart';

class TransactionQuery {
  const TransactionQuery({
    this.from,
    this.to,
    this.accountId,
    this.source,
    this.search,
  });

  final DateTime? from;
  final DateTime? to;
  final String? accountId;
  final TransactionSource? source;
  final String? search;
}

abstract interface class TransactionRepository {
  Future<List<FinancialTransaction>> list({
    TransactionQuery query = const TransactionQuery(),
  });

  Future<FinancialTransaction?> findById(String id);
  Future<void> save(FinancialTransaction transaction);
  Future<void> updateCategory(String transactionId, String categoryId);
}
