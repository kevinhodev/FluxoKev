import '../../accounts/domain/entities/financial_account.dart';
import '../../categories/domain/entities/financial_category.dart';
import '../domain/entities/financial_transaction.dart';

class TransactionListItem {
  const TransactionListItem({
    required this.transaction,
    required this.account,
    required this.category,
    this.parentCategory,
  });

  final FinancialTransaction transaction;
  final FinancialAccount account;
  final FinancialCategory category;
  final FinancialCategory? parentCategory;

  String get primaryCategory => parentCategory?.name ?? category.name;
  String get secondaryCategory =>
      parentCategory == null ? _natureLabel(transaction.nature) : category.name;
}

String _natureLabel(TransactionNature nature) => switch (nature) {
  TransactionNature.income => 'Receita',
  TransactionNature.expense => 'Despesa',
  TransactionNature.transfer => 'Movimentação neutra',
  TransactionNature.investmentReturn => 'Rendimento',
};
