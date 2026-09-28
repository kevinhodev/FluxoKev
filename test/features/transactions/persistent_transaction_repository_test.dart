import 'package:fluxo_ia/core/domain/money.dart';
import 'package:fluxo_ia/features/transactions/data/local/transaction_local_store.dart';
import 'package:fluxo_ia/features/transactions/data/repositories/persistent_transaction_repository.dart';
import 'package:fluxo_ia/features/transactions/domain/entities/financial_transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _MemoryStore store;
  late PersistentTransactionRepository repository;

  setUp(() {
    store = _MemoryStore();
    repository = PersistentTransactionRepository(store: store);
  });

  test('semeia os dados apenas na primeira leitura', () async {
    final firstRead = await repository.list();
    final writesAfterFirstRead = store.writeCount;
    final secondRead = await repository.list();

    expect(firstRead, isNotEmpty);
    expect(secondRead, hasLength(firstRead.length));
    expect(writesAfterFirstRead, 1);
    expect(store.writeCount, 1);
  });

  test('salva transação manual e a recupera em nova instância', () async {
    final transaction = FinancialTransaction(
      id: 'manual-test',
      accountId: 'account-bb-checking',
      occurredAt: DateTime(2026, 8, 11),
      description: 'Padaria',
      merchantName: 'Padaria',
      amount: const Money(2590),
      direction: TransactionDirection.debit,
      nature: TransactionNature.expense,
      categoryId: 'food-delivery',
      source: TransactionSource.manual,
      note: 'Café da manhã',
    );

    await repository.save(transaction);
    final restored = await PersistentTransactionRepository(
      store: store,
    ).findById(transaction.id);

    expect(restored?.amount, const Money(2590));
    expect(restored?.source, TransactionSource.manual);
    expect(restored?.note, 'Café da manhã');
  });

  test('atualiza uma transação existente sem duplicar', () async {
    final before = await repository.findById('tx-001');
    expect(before, isNotNull);

    final edited = FinancialTransaction(
      id: before!.id,
      externalId: before.externalId,
      accountId: before.accountId,
      occurredAt: before.occurredAt,
      description: 'IFOOD EDITADO',
      merchantName: before.merchantName,
      amount: before.amount,
      direction: before.direction,
      nature: before.nature,
      categoryId: 'food-supermarket',
      source: before.source,
      note: 'Revisado',
    );
    await repository.save(edited);

    final matches = (await repository.list())
        .where((transaction) => transaction.id == edited.id)
        .toList();
    expect(matches, hasLength(1));
    expect(matches.single.description, 'IFOOD EDITADO');
    expect(matches.single.categoryId, 'food-supermarket');
  });
}

class _MemoryStore implements TransactionLocalStore {
  List<FinancialTransaction>? records;
  var writeCount = 0;

  @override
  Future<List<FinancialTransaction>?> readAll() async =>
      records == null ? null : List<FinancialTransaction>.from(records!);

  @override
  Future<void> writeAll(List<FinancialTransaction> transactions) async {
    writeCount++;
    records = List<FinancialTransaction>.from(transactions);
  }
}
