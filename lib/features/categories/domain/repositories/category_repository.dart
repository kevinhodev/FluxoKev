import '../entities/financial_category.dart';

abstract interface class CategoryRepository {
  Future<List<FinancialCategory>> listAll();
  Future<FinancialCategory?> findById(String id);
}
