import '../../../../core/domain/money.dart';

enum AccountType { checking, savings, payment, creditCard, other }

class FinancialAccount {
  const FinancialAccount({
    required this.id,
    required this.institutionId,
    required this.name,
    required this.type,
    required this.currentBalance,
    this.availableBalance,
    this.balanceGroupKey,
    this.creditLimit,
    this.balanceDueDate,
    this.active = true,
  });

  final String id;
  final String institutionId;
  final String name;
  final AccountType type;
  final Money currentBalance;
  final Money? availableBalance;
  final String? balanceGroupKey;
  final Money? creditLimit;
  final DateTime? balanceDueDate;
  final bool active;

  bool get isCreditCard => type == AccountType.creditCard;
}
