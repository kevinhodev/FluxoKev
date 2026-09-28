enum CategoryType { income, expense, transfer, investment }

class FinancialCategory {
  const FinancialCategory({
    required this.id,
    required this.name,
    required this.type,
    this.parentId,
  });

  final String id;
  final String? parentId;
  final String name;
  final CategoryType type;
}
