import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/domain/money.dart';
import '../../domain/entities/financial_transaction.dart';
import 'transaction_local_store.dart';

class SharedPreferencesTransactionStore implements TransactionLocalStore {
  SharedPreferencesTransactionStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _storageKey = 'fluxo_ia.transactions.v1';

  final SharedPreferencesAsync _preferences;

  @override
  Future<List<FinancialTransaction>?> readAll() async {
    final payload = await _preferences.getString(_storageKey);
    if (payload == null) return null;

    final records = jsonDecode(payload) as List<dynamic>;
    return records
        .map(
          (record) =>
              _transactionFromJson(Map<String, dynamic>.from(record as Map)),
        )
        .toList(growable: false);
  }

  @override
  Future<void> writeAll(List<FinancialTransaction> transactions) async {
    final payload = jsonEncode(
      transactions.map(_transactionToJson).toList(growable: false),
    );
    await _preferences.setString(_storageKey, payload);
  }
}

Map<String, Object?> _transactionToJson(FinancialTransaction transaction) => {
  'id': transaction.id,
  'externalId': transaction.externalId,
  'accountId': transaction.accountId,
  'occurredAt': transaction.occurredAt.toIso8601String(),
  'description': transaction.description,
  'merchantName': transaction.merchantName,
  'minorUnits': transaction.amount.minorUnits,
  'currency': transaction.amount.currency,
  'direction': transaction.direction.name,
  'nature': transaction.nature.name,
  'categoryId': transaction.categoryId,
  'source': transaction.source.name,
  'note': transaction.note,
};

FinancialTransaction _transactionFromJson(Map<String, dynamic> json) {
  return FinancialTransaction(
    id: json['id'] as String,
    externalId: json['externalId'] as String?,
    accountId: json['accountId'] as String,
    occurredAt: DateTime.parse(json['occurredAt'] as String),
    description: json['description'] as String,
    merchantName: json['merchantName'] as String,
    amount: Money(
      json['minorUnits'] as int,
      currency: json['currency'] as String? ?? 'BRL',
    ),
    direction: TransactionDirection.values.byName(json['direction'] as String),
    nature: TransactionNature.values.byName(json['nature'] as String),
    categoryId: json['categoryId'] as String,
    source: TransactionSource.values.byName(json['source'] as String),
    note: json['note'] as String?,
  );
}
