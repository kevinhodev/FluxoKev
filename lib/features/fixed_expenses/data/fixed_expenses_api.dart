import '../../../core/domain/money.dart';
import '../../../core/network/api_client.dart';
import '../domain/fixed_expense.dart';

class FixedExpensesApi {
  const FixedExpensesApi(this._client);

  final ApiClient _client;

  Future<List<FixedExpense>> list() async {
    final rows = await _client.get('/v1/fixed-expenses') as List<dynamic>;
    return rows
        .map((row) => _expense(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<FixedExpense> create(FixedExpenseInput input) async {
    final json = await _client.post('/v1/fixed-expenses', body: _body(input));
    return _expense(json as Map<String, dynamic>);
  }

  Future<FixedExpense> update(String id, FixedExpenseInput input) async {
    final json = await _client.patch(
      '/v1/fixed-expenses/$id',
      body: _body(input),
    );
    return _expense(json as Map<String, dynamic>);
  }

  Future<void> archive(String id) => _client.delete('/v1/fixed-expenses/$id');

  Map<String, dynamic> _body(FixedExpenseInput input) => {
    'name': input.name,
    'categoryId': input.categoryId,
    'amountMinorUnits': input.amount?.minorUnits,
    'valueKind': input.valueKind == FixedExpenseValueKind.fixed
        ? 'FIXED'
        : 'VARIABLE',
    'frequency': 'MONTHLY',
    'locationLabel': input.locationLabel,
    'dueDay': input.dueDay,
    'note': input.note,
  };

  FixedExpense _expense(Map<String, dynamic> json) => FixedExpense(
    id: json['id'] as String,
    name: json['name'] as String,
    categoryId: json['categoryId'] as String,
    amount: json['amountMinorUnits'] == null
        ? null
        : Money((json['amountMinorUnits'] as num).toInt()),
    valueKind: json['valueKind'] == 'VARIABLE'
        ? FixedExpenseValueKind.variable
        : FixedExpenseValueKind.fixed,
    locationLabel: json['locationLabel'] as String? ?? '',
    dueDay: (json['dueDay'] as num?)?.toInt(),
    note: json['note'] as String?,
  );
}
