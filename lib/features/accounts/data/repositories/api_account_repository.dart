import '../../../../core/domain/money.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/financial_account.dart';
import '../../domain/repositories/account_repository.dart';

class ApiAccountRepository implements AccountRepository {
  ApiAccountRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<FinancialAccount>> listActive() async {
    final rows = await _client.get('/v1/accounts') as List<dynamic>;
    return rows
        .map((row) => _fromJson(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<FinancialAccount?> findById(String id) async {
    final accounts = await listActive();
    for (final account in accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  FinancialAccount _fromJson(Map<String, dynamic> json) => FinancialAccount(
    id: json['id'] as String,
    institutionId: json['institutionId'] as String,
    name: json['name'] as String,
    type: switch (json['type']) {
      'CHECKING' => AccountType.checking,
      'SAVINGS' => AccountType.savings,
      'PAYMENT' => AccountType.payment,
      'CREDIT_CARD' => AccountType.creditCard,
      _ => AccountType.other,
    },
    currentBalance: Money(json['currentBalanceMinorUnits'] as int),
    availableBalance: _money(json['availableBalanceMinorUnits']),
    balanceGroupKey: json['balanceGroupKey'] as String?,
    creditLimit: _money(json['creditLimitMinorUnits']),
    balanceDueDate: json['balanceDueDate'] == null
        ? null
        : DateTime.parse(json['balanceDueDate'] as String),
  );

  Money? _money(dynamic value) => value == null ? null : Money(value as int);
}
