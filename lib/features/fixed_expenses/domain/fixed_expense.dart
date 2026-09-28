import '../../../core/domain/money.dart';

enum FixedExpenseValueKind { fixed, variable }

class FixedExpense {
  const FixedExpense({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.amount,
    required this.valueKind,
    required this.locationLabel,
    required this.dueDay,
    required this.note,
  });

  final String id;
  final String name;
  final String categoryId;
  final Money? amount;
  final FixedExpenseValueKind valueKind;
  final String locationLabel;
  final int? dueDay;
  final String? note;

  bool get isVariable => valueKind == FixedExpenseValueKind.variable;
}

class FixedExpenseInput {
  const FixedExpenseInput({
    required this.name,
    required this.categoryId,
    required this.amount,
    required this.valueKind,
    required this.locationLabel,
    required this.dueDay,
    this.note,
  });

  final String name;
  final String categoryId;
  final Money? amount;
  final FixedExpenseValueKind valueKind;
  final String locationLabel;
  final int? dueDay;
  final String? note;
}
