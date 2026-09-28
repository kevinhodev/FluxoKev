import '../../../core/domain/money.dart';

class BenefitWallet {
  const BenefitWallet({
    required this.id,
    required this.name,
    required this.currentBalance,
    required this.monthlyCredit,
    required this.monthlyAllocation,
    required this.allocationLabel,
    required this.note,
  });

  final String id;
  final String name;
  final Money currentBalance;
  final Money monthlyCredit;
  final Money monthlyAllocation;
  final String allocationLabel;
  final String? note;

  Money get monthlyAvailable => monthlyCredit - monthlyAllocation;
}

class BenefitWalletInput {
  const BenefitWalletInput({
    required this.name,
    required this.currentBalance,
    required this.monthlyCredit,
    required this.monthlyAllocation,
    required this.allocationLabel,
    this.note,
  });

  final String name;
  final Money currentBalance;
  final Money monthlyCredit;
  final Money monthlyAllocation;
  final String allocationLabel;
  final String? note;
}
