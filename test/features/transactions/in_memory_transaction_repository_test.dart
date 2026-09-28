import 'package:fluxo_ia/features/transactions/data/repositories/in_memory_transaction_repository.dart';
import 'package:fluxo_ia/features/transactions/domain/entities/financial_transaction.dart';
import 'package:fluxo_ia/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryTransactionRepository repository;

  setUp(() => repository = InMemoryTransactionRepository());

  test('filtra transações importadas por origem', () async {
    final imported = await repository.list(
      query: const TransactionQuery(source: TransactionSource.csvImport),
    );

    expect(imported, hasLength(1));
    expect(imported.single.description, 'PÃO DE AÇÚCAR');
  });

  test('atualiza categoria sem alterar o restante da transação', () async {
    final before = await repository.findById('tx-001');

    await repository.updateCategory('tx-001', 'food-supermarket');
    final after = await repository.findById('tx-001');

    expect(before, isNotNull);
    expect(after?.categoryId, 'food-supermarket');
    expect(after?.amount, before?.amount);
    expect(after?.externalId, before?.externalId);
  });

  test('transferência não afeta o fluxo de receitas e despesas', () async {
    final transaction = await repository.findById('tx-009');

    expect(transaction?.nature, TransactionNature.transfer);
    expect(transaction?.affectsCashFlow, isFalse);
    expect(transaction?.signedAmount.minorUnits, -200000);
  });
}
