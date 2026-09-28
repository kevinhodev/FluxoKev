import '../../../../core/domain/money.dart';
import '../../domain/entities/financial_transaction.dart';
import '../../domain/repositories/transaction_repository.dart';

class InMemoryTransactionRepository implements TransactionRepository {
  InMemoryTransactionRepository() : _transactions = _seedTransactions();

  final List<FinancialTransaction> _transactions;

  @override
  Future<FinancialTransaction?> findById(String id) async {
    for (final transaction in _transactions) {
      if (transaction.id == id) return transaction;
    }
    return null;
  }

  @override
  Future<List<FinancialTransaction>> list({
    TransactionQuery query = const TransactionQuery(),
  }) async {
    final normalizedSearch = query.search?.trim().toLowerCase();
    final result = _transactions.where((transaction) {
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
  Future<void> save(FinancialTransaction transaction) async {
    final index = _transactions.indexWhere((item) => item.id == transaction.id);
    if (index == -1) {
      _transactions.add(transaction);
    } else {
      _transactions[index] = transaction;
    }
  }

  @override
  Future<void> updateCategory(String transactionId, String categoryId) async {
    final index = _transactions.indexWhere((item) => item.id == transactionId);
    if (index == -1) {
      throw StateError('Transação não encontrada: $transactionId');
    }
    _transactions[index] = _transactions[index].copyWith(
      categoryId: categoryId,
    );
  }
}

List<FinancialTransaction> _seedTransactions() => [
  FinancialTransaction(
    id: 'tx-001',
    externalId: 'pluggy-001',
    accountId: 'account-bb-card',
    occurredAt: DateTime(2026, 8, 31, 12, 15),
    description: 'IFOOD*RESTAURANTE',
    merchantName: 'iFood',
    amount: const Money(4590),
    direction: TransactionDirection.debit,
    nature: TransactionNature.expense,
    categoryId: 'food-delivery',
    source: TransactionSource.openFinance,
  ),
  FinancialTransaction(
    id: 'tx-002',
    externalId: 'pluggy-002',
    accountId: 'account-bb-checking',
    occurredAt: DateTime(2026, 8, 30, 18, 30),
    description: 'POSTO BR PETROBRAS',
    merchantName: 'Posto BR',
    amount: const Money(15000),
    direction: TransactionDirection.debit,
    nature: TransactionNature.expense,
    categoryId: 'transport-fuel',
    source: TransactionSource.openFinance,
  ),
  FinancialTransaction(
    id: 'tx-003',
    externalId: 'pluggy-003',
    accountId: 'account-bb-checking',
    occurredAt: DateTime(2026, 8, 30, 9),
    description: 'SALÁRIO',
    merchantName: 'Salário',
    amount: const Money(780000),
    direction: TransactionDirection.credit,
    nature: TransactionNature.income,
    categoryId: 'salary',
    source: TransactionSource.openFinance,
  ),
  FinancialTransaction(
    id: 'tx-004',
    externalId: 'pluggy-004',
    accountId: 'account-bb-card',
    occurredAt: DateTime(2026, 8, 29, 20),
    description: 'NETFLIX.COM',
    merchantName: 'Netflix',
    amount: const Money(5590),
    direction: TransactionDirection.debit,
    nature: TransactionNature.expense,
    categoryId: 'subscriptions-streaming',
    source: TransactionSource.openFinance,
  ),
  FinancialTransaction(
    id: 'tx-005',
    accountId: 'account-bb-card',
    occurredAt: DateTime(2026, 8, 29, 16, 20),
    description: 'PÃO DE AÇÚCAR',
    merchantName: 'Pão de Açúcar',
    amount: const Money(9875),
    direction: TransactionDirection.debit,
    nature: TransactionNature.expense,
    categoryId: 'food-supermarket',
    source: TransactionSource.csvImport,
  ),
  FinancialTransaction(
    id: 'tx-006',
    externalId: 'pluggy-006',
    accountId: 'account-bb-checking',
    occurredAt: DateTime(2026, 8, 28, 8),
    description: 'ALUGUEL AGOSTO/26',
    merchantName: 'Aluguel',
    amount: const Money(180000),
    direction: TransactionDirection.debit,
    nature: TransactionNature.expense,
    categoryId: 'housing-rent',
    source: TransactionSource.openFinance,
  ),
  FinancialTransaction(
    id: 'tx-007',
    externalId: 'pluggy-007',
    accountId: 'account-bb-card',
    occurredAt: DateTime(2026, 8, 27, 22, 10),
    description: 'UBER *TRIP',
    merchantName: 'Uber',
    amount: const Money(2340),
    direction: TransactionDirection.debit,
    nature: TransactionNature.expense,
    categoryId: 'transport-app',
    source: TransactionSource.openFinance,
  ),
  FinancialTransaction(
    id: 'tx-008',
    externalId: 'pluggy-008',
    accountId: 'account-bb-checking',
    occurredAt: DateTime(2026, 8, 27, 14),
    description: 'PIX - JOÃO SILVA',
    merchantName: 'João Silva',
    amount: const Money(20000),
    direction: TransactionDirection.debit,
    nature: TransactionNature.transfer,
    categoryId: 'transfer-out',
    source: TransactionSource.openFinance,
  ),
  FinancialTransaction(
    id: 'tx-009',
    externalId: 'pluggy-009',
    accountId: 'account-bb-checking',
    occurredAt: DateTime(2026, 8, 26, 11),
    description: 'APLICAÇÃO CDB',
    merchantName: 'Aplicação CDB',
    amount: const Money(200000),
    direction: TransactionDirection.debit,
    nature: TransactionNature.transfer,
    categoryId: 'transfer-investment',
    source: TransactionSource.openFinance,
  ),
  FinancialTransaction(
    id: 'tx-010',
    externalId: 'pluggy-010',
    accountId: 'account-bb-checking',
    occurredAt: DateTime(2026, 8, 25, 10),
    description: 'RENDIMENTO CDB',
    merchantName: 'Rendimento CDB',
    amount: const Money(6345),
    direction: TransactionDirection.credit,
    nature: TransactionNature.investmentReturn,
    categoryId: 'investments-return',
    source: TransactionSource.openFinance,
  ),
  FinancialTransaction(
    id: 'tx-011',
    accountId: 'account-bb-checking',
    occurredAt: DateTime(2026, 8, 24, 10),
    description: 'CONTA DE ENERGIA',
    merchantName: 'Energia',
    amount: const Money(32000),
    direction: TransactionDirection.debit,
    nature: TransactionNature.expense,
    categoryId: 'housing-utilities',
    source: TransactionSource.openFinance,
  ),
  FinancialTransaction(
    id: 'tx-012',
    accountId: 'account-bb-checking',
    occurredAt: DateTime(2026, 8, 23, 10),
    description: 'CONDOMÍNIO AGOSTO/26',
    merchantName: 'Condomínio',
    amount: const Money(85000),
    direction: TransactionDirection.debit,
    nature: TransactionNature.expense,
    categoryId: 'housing-condo',
    source: TransactionSource.openFinance,
  ),
  FinancialTransaction(
    id: 'tx-013',
    accountId: 'account-bb-card',
    occurredAt: DateTime(2026, 8, 22, 10),
    description: 'CLÍNICA MÉDICA',
    merchantName: 'Clínica médica',
    amount: const Money(45000),
    direction: TransactionDirection.debit,
    nature: TransactionNature.expense,
    categoryId: 'health',
    source: TransactionSource.openFinance,
  ),
  FinancialTransaction(
    id: 'tx-014',
    accountId: 'account-bb-checking',
    occurredAt: DateTime(2026, 8, 21, 10),
    description: 'CURSO DE ESPECIALIZAÇÃO',
    merchantName: 'Curso',
    amount: const Money(120000),
    direction: TransactionDirection.debit,
    nature: TransactionNature.expense,
    categoryId: 'education',
    source: TransactionSource.openFinance,
  ),
  FinancialTransaction(
    id: 'tx-015',
    accountId: 'account-bb-checking',
    occurredAt: DateTime(2026, 8, 20, 10),
    description: 'SEGURO AUTO',
    merchantName: 'Seguro auto',
    amount: const Money(57650),
    direction: TransactionDirection.debit,
    nature: TransactionNature.expense,
    categoryId: 'insurance',
    source: TransactionSource.openFinance,
  ),
  FinancialTransaction(
    id: 'tx-016',
    accountId: 'account-bb-card',
    occurredAt: DateTime(2026, 8, 19, 10),
    description: 'SUPERMERCADO LOCAL',
    merchantName: 'Supermercado local',
    amount: const Money(60000),
    direction: TransactionDirection.debit,
    nature: TransactionNature.expense,
    categoryId: 'food-supermarket',
    source: TransactionSource.openFinance,
  ),
  FinancialTransaction(
    id: 'tx-017',
    accountId: 'account-bb-checking',
    occurredAt: DateTime(2026, 8, 18, 10),
    description: 'OUTRAS DESPESAS',
    merchantName: 'Outras despesas',
    amount: const Money(70000),
    direction: TransactionDirection.debit,
    nature: TransactionNature.expense,
    categoryId: 'other-expense',
    source: TransactionSource.manual,
  ),
  FinancialTransaction(
    id: 'tx-018',
    accountId: 'account-bb-checking',
    occurredAt: DateTime(2026, 8, 17, 10),
    description: 'BONIFICAÇÃO',
    merchantName: 'Bonificação',
    amount: const Money(652000),
    direction: TransactionDirection.credit,
    nature: TransactionNature.income,
    categoryId: 'salary',
    source: TransactionSource.openFinance,
  ),
  FinancialTransaction(
    id: 'tx-jul-001',
    accountId: 'account-bb-checking',
    occurredAt: DateTime(2026, 7, 31, 10),
    description: 'RECEITAS JULHO/26',
    merchantName: 'Receitas de julho',
    amount: const Money(1323353),
    direction: TransactionDirection.credit,
    nature: TransactionNature.income,
    categoryId: 'salary',
    source: TransactionSource.manual,
  ),
  FinancialTransaction(
    id: 'tx-jul-002',
    accountId: 'account-bb-checking',
    occurredAt: DateTime(2026, 7, 30, 10),
    description: 'DESPESAS JULHO/26',
    merchantName: 'Despesas de julho',
    amount: const Money(653210),
    direction: TransactionDirection.debit,
    nature: TransactionNature.expense,
    categoryId: 'other-expense',
    source: TransactionSource.manual,
  ),
];
