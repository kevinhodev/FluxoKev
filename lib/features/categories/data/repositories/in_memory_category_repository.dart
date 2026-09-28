import '../../domain/entities/financial_category.dart';
import '../../domain/repositories/category_repository.dart';

class InMemoryCategoryRepository implements CategoryRepository {
  static const _categories = [
    FinancialCategory(
      id: 'food',
      name: 'Alimentação',
      type: CategoryType.expense,
    ),
    FinancialCategory(
      id: 'food-delivery',
      parentId: 'food',
      name: 'Delivery',
      type: CategoryType.expense,
    ),
    FinancialCategory(
      id: 'food-supermarket',
      parentId: 'food',
      name: 'Supermercado',
      type: CategoryType.expense,
    ),
    FinancialCategory(
      id: 'transport',
      name: 'Transporte',
      type: CategoryType.expense,
    ),
    FinancialCategory(
      id: 'transport-fuel',
      parentId: 'transport',
      name: 'Combustível',
      type: CategoryType.expense,
    ),
    FinancialCategory(
      id: 'transport-app',
      parentId: 'transport',
      name: 'Aplicativo',
      type: CategoryType.expense,
    ),
    FinancialCategory(id: 'salary', name: 'Salário', type: CategoryType.income),
    FinancialCategory(
      id: 'subscriptions',
      name: 'Assinaturas',
      type: CategoryType.expense,
    ),
    FinancialCategory(
      id: 'subscriptions-streaming',
      parentId: 'subscriptions',
      name: 'Streaming',
      type: CategoryType.expense,
    ),
    FinancialCategory(
      id: 'housing',
      name: 'Moradia',
      type: CategoryType.expense,
    ),
    FinancialCategory(
      id: 'housing-rent',
      parentId: 'housing',
      name: 'Aluguel',
      type: CategoryType.expense,
    ),
    FinancialCategory(
      id: 'housing-utilities',
      parentId: 'housing',
      name: 'Energia',
      type: CategoryType.expense,
    ),
    FinancialCategory(
      id: 'housing-condo',
      parentId: 'housing',
      name: 'Condomínio',
      type: CategoryType.expense,
    ),
    FinancialCategory(id: 'health', name: 'Saúde', type: CategoryType.expense),
    FinancialCategory(
      id: 'education',
      name: 'Educação',
      type: CategoryType.expense,
    ),
    FinancialCategory(
      id: 'insurance',
      name: 'Seguros',
      type: CategoryType.expense,
    ),
    FinancialCategory(
      id: 'other-expense',
      name: 'Outras despesas',
      type: CategoryType.expense,
    ),
    FinancialCategory(
      id: 'transfer',
      name: 'Transferência',
      type: CategoryType.transfer,
    ),
    FinancialCategory(
      id: 'transfer-out',
      parentId: 'transfer',
      name: 'Saída',
      type: CategoryType.transfer,
    ),
    FinancialCategory(
      id: 'transfer-investment',
      parentId: 'transfer',
      name: 'Investimento',
      type: CategoryType.transfer,
    ),
    FinancialCategory(
      id: 'investments',
      name: 'Investimentos',
      type: CategoryType.investment,
    ),
    FinancialCategory(
      id: 'investments-return',
      parentId: 'investments',
      name: 'Rendimento',
      type: CategoryType.investment,
    ),
  ];

  @override
  Future<FinancialCategory?> findById(String id) async {
    for (final category in _categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  @override
  Future<List<FinancialCategory>> listAll() async =>
      List.unmodifiable(_categories);
}
