import '../../domain/entities/financial_transaction.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../local/transaction_local_store.dart';
import 'in_memory_transaction_repository.dart';

class PersistentTransactionRepository implements TransactionRepository {
  PersistentTransactionRepository({required TransactionLocalStore store})
    : _store = store;

  final TransactionLocalStore _store;
  Future<void> _pendingMutation = Future.value();

  Future<List<FinancialTransaction>> _readOrSeed() async {
    await _pendingMutation;
    final stored = await _store.readAll();
    if (stored != null) return stored;

    final seeded = await InMemoryTransactionRepository().list();
    await _store.writeAll(seeded);
    return seeded;
  }

  @override
  Future<FinancialTransaction?> findById(String id) async {
    final transactions = await _readOrSeed();
    for (final transaction in transactions) {
      if (transaction.id == id) return transaction;
    }
    return null;
  }

  @override
  Future<List<FinancialTransaction>> list({
    TransactionQuery query = const TransactionQuery(),
  }) async {
    final transactions = await _readOrSeed();
    final normalizedSearch = query.search?.trim().toLowerCase();
    final result = transactions.where((transaction) {
      if (query.from != null && transaction.occurredAt.isBefore(query.from!)) {
        return false;
      }
      if (query.to != null && transaction.occurredAt.isAfter(query.to!)) {
        return false;
      }
      if (query.accountId != null && transaction.accountId != query.accountId) {
        return false;
      }
      if (query.source != null && transaction.source != query.source) {
        return false;
      }
      if (normalizedSearch != null && normalizedSearch.isNotEmpty) {
        final haystack =
            '${transaction.description} ${transaction.merchantName}'
                .toLowerCase();
        if (!haystack.contains(normalizedSearch)) return false;
      }
      return true;
    }).toList()..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return List.unmodifiable(result);
  }

  @override
  Future<void> save(FinancialTransaction transaction) {
    return _mutate((transactions) {
      final index = transactions.indexWhere(
        (item) => item.id == transaction.id,
      );
      if (index == -1) {
        transactions.add(transaction);
      } else {
        transactions[index] = transaction;
      }
    });
  }

  @override
  Future<void> updateCategory(String transactionId, String categoryId) {
    return _mutate((transactions) {
      final index = transactions.indexWhere((item) => item.id == transactionId);
      if (index == -1) {
        throw StateError('Transação não encontrada: $transactionId');
      }
      transactions[index] = transactions[index].copyWith(
        categoryId: categoryId,
      );
    });
  }

  Future<void> _mutate(
    void Function(List<FinancialTransaction> transactions) mutation,
  ) {
    final operation = _pendingMutation.then((_) async {
      final transactions =
          (await _store.readAll() ??
                  await InMemoryTransactionRepository().list())
              .toList();
      mutation(transactions);
      await _store.writeAll(transactions);
    });
    _pendingMutation = operation.then<void>((_) {}, onError: (_) {});
    return operation;
  }
}
