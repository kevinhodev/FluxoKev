import '../entities/financial_account.dart';

abstract interface class AccountRepository {
  Future<List<FinancialAccount>> listActive();
  Future<FinancialAccount?> findById(String id);
}
