import '../../../core/domain/money.dart';
import '../../../core/network/api_client.dart';
import '../domain/subscription.dart';

class SubscriptionsApi {
  const SubscriptionsApi(this._client);

  final ApiClient _client;

  Future<List<Subscription>> list() async {
    final rows = await _client.get('/v1/subscriptions') as List<dynamic>;
    return rows
        .map((row) => _subscription(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Subscription> create(SubscriptionInput input) async {
    final json = await _client.post('/v1/subscriptions', body: _body(input));
    return _subscription(json as Map<String, dynamic>);
  }

  Future<Subscription> update(String id, SubscriptionInput input) async {
    final json = await _client.patch(
      '/v1/subscriptions/$id',
      body: _body(input),
    );
    return _subscription(json as Map<String, dynamic>);
  }

  Future<void> archive(String id) => _client.delete('/v1/subscriptions/$id');

  Map<String, dynamic> _body(SubscriptionInput input) => {
    'name': input.name,
    'billingDescriptor': input.billingDescriptor,
    'amountMinorUnits': input.amount.minorUnits,
    'frequency': 'MONTHLY',
    'billingDay': input.billingDay,
    'paymentMethodLabel': input.paymentMethodLabel,
    'note': input.note,
  };

  Subscription _subscription(Map<String, dynamic> json) => Subscription(
    id: json['id'] as String,
    name: json['name'] as String,
    billingDescriptor: json['billingDescriptor'] as String? ?? '',
    amount: Money((json['amountMinorUnits'] as num).toInt()),
    billingDay: (json['billingDay'] as num?)?.toInt(),
    paymentMethodLabel: json['paymentMethodLabel'] as String? ?? '',
    note: json['note'] as String?,
  );
}
