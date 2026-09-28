import '../../../../core/domain/money.dart';
import '../../domain/entities/financial_account.dart';
import '../../domain/repositories/account_repository.dart';

class InMemoryAccountRepository implements AccountRepository {
  static const _accounts = [
    FinancialAccount(
      id: 'account-bb-checking',
      institutionId: 'institution-bb',
      name: 'Conta corrente',
      type: AccountType.checking,
      currentBalance: Money(1894225),
    ),
    FinancialAccount(
      id: 'account-bb-card',
      institutionId: 'institution-bb',
      name: 'Cartão de crédito',
      type: AccountType.creditCard,
      currentBalance: Money(-273485),
    ),
  ];

  @override
  Future<FinancialAccount?> findById(String id) async {
    for (final account in _accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  @override
  Future<List<FinancialAccount>> listActive() async =>
      List.unmodifiable(_accounts.where((account) => account.active));
}
