import '../../../../core/network/api_client.dart';
import '../../domain/entities/financial_category.dart';
import '../../domain/repositories/category_repository.dart';

class ApiCategoryRepository implements CategoryRepository {
  ApiCategoryRepository(this._client);

  final ApiClient _client;
  List<FinancialCategory>? _cache;

  @override
  Future<List<FinancialCategory>> listAll() async {
    if (_cache case final cached?) return cached;
    final rows = await _client.get('/v1/categories') as List<dynamic>;
    return _cache = rows
        .map((row) => _fromJson(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<FinancialCategory?> findById(String id) async {
    final categories = await listAll();
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  FinancialCategory _fromJson(Map<String, dynamic> json) => FinancialCategory(
    id: json['id'] as String,
    parentId: json['parentId'] as String?,
    name: json['name'] as String,
    type: switch (json['type']) {
      'INCOME' => CategoryType.income,
      'TRANSFER' => CategoryType.transfer,
      'INVESTMENT' => CategoryType.investment,
      _ => CategoryType.expense,
    },
  );
}
