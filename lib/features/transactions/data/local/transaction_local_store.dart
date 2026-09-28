import '../../domain/entities/financial_transaction.dart';

abstract interface class TransactionLocalStore {
  Future<List<FinancialTransaction>?> readAll();
  Future<void> writeAll(List<FinancialTransaction> transactions);
}
