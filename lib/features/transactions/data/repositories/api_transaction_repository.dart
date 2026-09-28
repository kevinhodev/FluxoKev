import '../../../../core/domain/money.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/financial_transaction.dart';
import '../../domain/repositories/transaction_repository.dart';

class ApiTransactionRepository implements TransactionRepository {
  ApiTransactionRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<FinancialTransaction>> list({
    TransactionQuery query = const TransactionQuery(),
  }) async {
    final params = <String, String>{
      if (query.from != null) 'from': query.from!.toUtc().toIso8601String(),
      if (query.to != null) 'to': query.to!.toUtc().toIso8601String(),
      if (query.search != null && query.search!.trim().isNotEmpty)
        'search': query.search!.trim(),
    };
    final rows =
        await _client.get('/v1/transactions', query: params) as List<dynamic>;
    final transactions = rows
        .map((row) => _fromJson(row as Map<String, dynamic>))
        .where(
          (item) =>
              query.accountId == null || item.accountId == query.accountId,
        )
        .where((item) => query.source == null || item.source == query.source)
        .toList(growable: false);
    return transactions;
  }

  @override
  Future<FinancialTransaction?> findById(String id) async {
    final transactions = await list();
    for (final transaction in transactions) {
      if (transaction.id == id) return transaction;
    }
    return null;
  }

  @override
  Future<void> save(FinancialTransaction transaction) async {
    final body = _toJson(transaction);
    if (transaction.id.startsWith('manual-')) {
      await _client.post('/v1/transactions', body: body);
    } else {
      body.remove('accountId');
      await _client.patch('/v1/transactions/${transaction.id}', body: body);
    }
  }

  @override
  Future<void> updateCategory(String transactionId, String categoryId) =>
      _client.patch(
        '/v1/transactions/$transactionId',
        body: {'categoryId': categoryId},
      );

  Map<String, dynamic> _toJson(FinancialTransaction item) => {
    'accountId': item.accountId,
    'occurredAt': item.occurredAt.toUtc().toIso8601String(),
    'description': item.description,
    'merchantName': item.merchantName,
    'amountMinorUnits': item.amount.minorUnits,
    'direction': item.direction == TransactionDirection.credit
        ? 'CREDIT'
        : 'DEBIT',
    'nature': switch (item.nature) {
      TransactionNature.income => 'INCOME',
      TransactionNature.expense => 'EXPENSE',
      TransactionNature.transfer => 'TRANSFER',
      TransactionNature.investmentReturn => 'INVESTMENT_RETURN',
    },
    'categoryId': item.categoryId,
    'note': item.note,
  };

  FinancialTransaction _fromJson(Map<String, dynamic> json) =>
      FinancialTransaction(
        id: json['id'] as String,
        externalId: json['externalId'] as String?,
        accountId: json['accountId'] as String,
        occurredAt: DateTime.parse(json['occurredAt'] as String).toLocal(),
        description: json['description'] as String,
        merchantName: json['merchantName'] as String,
        amount: Money(json['amountMinorUnits'] as int),
        direction: json['direction'] == 'CREDIT'
            ? TransactionDirection.credit
            : TransactionDirection.debit,
        nature: switch (json['nature']) {
          'INCOME' => TransactionNature.income,
          'TRANSFER' => TransactionNature.transfer,
          'INVESTMENT_RETURN' => TransactionNature.investmentReturn,
          _ => TransactionNature.expense,
        },
        categoryId: json['categoryId'] as String,
        source: switch (json['source']) {
          'OPEN_FINANCE' => TransactionSource.openFinance,
          'PLUGGY' => TransactionSource.pluggy,
          'OFX_IMPORT' => TransactionSource.ofxImport,
          'CSV_IMPORT' => TransactionSource.csvImport,
          'XLSX_IMPORT' => TransactionSource.xlsxImport,
          'PDF_IMPORT' => TransactionSource.pdfImport,
          _ => TransactionSource.manual,
        },
        providerStatus: json['providerStatus'] as String?,
        providerCategory: json['providerCategory'] as String?,
        note: json['note'] as String?,
      );
}
