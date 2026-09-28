import '../../../core/domain/money.dart';
import '../../../core/network/api_client.dart';
import '../domain/benefit_wallet.dart';

class BenefitWalletsApi {
  const BenefitWalletsApi(this._client);

  final ApiClient _client;

  Future<List<BenefitWallet>> list() async {
    final rows = await _client.get('/v1/benefit-wallets') as List<dynamic>;
    return rows
        .map((row) => _wallet(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<BenefitWallet> create(BenefitWalletInput input) async {
    final json = await _client.post('/v1/benefit-wallets', body: _body(input));
    return _wallet(json as Map<String, dynamic>);
  }

  Future<BenefitWallet> update(String id, BenefitWalletInput input) async {
    final json = await _client.patch(
      '/v1/benefit-wallets/$id',
      body: _body(input),
    );
    return _wallet(json as Map<String, dynamic>);
  }

  Future<void> archive(String id) => _client.delete('/v1/benefit-wallets/$id');

  Map<String, dynamic> _body(BenefitWalletInput input) => {
    'name': input.name,
    'currentBalanceMinorUnits': input.currentBalance.minorUnits,
    'monthlyCreditMinorUnits': input.monthlyCredit.minorUnits,
    'monthlyAllocationMinorUnits': input.monthlyAllocation.minorUnits,
    'allocationLabel': input.allocationLabel,
    'note': input.note,
  };

  BenefitWallet _wallet(Map<String, dynamic> json) => BenefitWallet(
    id: json['id'] as String,
    name: json['name'] as String,
    currentBalance: Money((json['currentBalanceMinorUnits'] as num).toInt()),
    monthlyCredit: Money((json['monthlyCreditMinorUnits'] as num).toInt()),
    monthlyAllocation: Money(
      (json['monthlyAllocationMinorUnits'] as num).toInt(),
    ),
    allocationLabel: json['allocationLabel'] as String? ?? '',
    note: json['note'] as String?,
  );
}
