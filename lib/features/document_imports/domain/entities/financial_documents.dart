import '../../../../core/domain/money.dart';

enum FinancialDocumentKind { loan, pension }

enum LoanInstallmentStatus { paid, open }

enum LoanPaymentKind { regular, amortized, pending }

enum LoanRepaymentKind { monthly, thirteenthSalary }

class LoanInstallment {
  const LoanInstallment({
    required this.number,
    required this.dueDate,
    required this.status,
    required this.paymentKind,
    required this.amount,
    required this.earlySettled,
  });

  final int number;
  final DateTime dueDate;
  final LoanInstallmentStatus status;
  final LoanPaymentKind paymentKind;
  final Money amount;

  /// Quitada à mão antes do dia do débito; não veio do extrato.
  final bool earlySettled;
}

class LoanDetails {
  const LoanDetails({
    required this.id,
    required this.providerName,
    required this.productName,
    required this.contractNumber,
    required this.documentDate,
    required this.contractDate,
    required this.currentBalance,
    required this.originalTotal,
    required this.debitDay,
    required this.monthlyInterestRate,
    required this.annualInterestRate,
    required this.monthlyEffectiveCost,
    required this.annualEffectiveCost,
    required this.repaymentKind,
    required this.payrollDeducted,
    required this.totalInstallments,
    required this.paidInstallments,
    required this.remainingInstallments,
    required this.amortizedInstallments,
    required this.nextDueDate,
    required this.projectedEndDate,
    required this.remainingPayments,
    required this.payoff,
    required this.installments,
  });

  /// Nulo no preview do PDF, preenchido depois que o empréstimo é salvo.
  final String? id;
  final String providerName;
  final String productName;
  final String contractNumber;
  final DateTime documentDate;
  final DateTime contractDate;
  final Money currentBalance;
  final Money originalTotal;
  final int debitDay;
  final double? monthlyInterestRate;
  final double? annualInterestRate;
  final double? monthlyEffectiveCost;
  final double? annualEffectiveCost;
  final LoanRepaymentKind repaymentKind;
  final bool payrollDeducted;
  final int totalInstallments;
  final int paidInstallments;
  final int remainingInstallments;
  final int amortizedInstallments;
  final DateTime? nextDueDate;
  final DateTime? projectedEndDate;

  /// Soma nominal das parcelas em aberto: quanto ainda será desembolsado.
  final Money remainingPayments;

  /// Valor presente das parcelas em aberto: quanto custaria quitar hoje.
  final Money payoff;

  final List<LoanInstallment> installments;

  List<LoanInstallment> get upcomingInstallments => installments
      .where((item) => item.status == LoanInstallmentStatus.open)
      .toList(growable: false);

  double get progress => totalInstallments == 0
      ? 0
      : (paidInstallments / totalInstallments).clamp(0, 1);

  bool get isThirteenthSalaryAdvance =>
      repaymentKind == LoanRepaymentKind.thirteenthSalary;
}

class PayrollSummary {
  const PayrollSummary({
    required this.referenceMonth,
    required this.regularNetReference,
    required this.excludedDeduction,
    required this.exclusionEffectiveFrom,
    required this.correctedNetEstimate,
    required this.ownPayrollLoanDeductions,
    required this.ownPayrollLoanCount,
  });

  final DateTime referenceMonth;
  final Money regularNetReference;
  final Money excludedDeduction;
  final DateTime? exclusionEffectiveFrom;
  final Money correctedNetEstimate;
  final Money ownPayrollLoanDeductions;
  final int ownPayrollLoanCount;
}

class PensionHistoryEntry {
  const PensionHistoryEntry({
    required this.referenceMonth,
    required this.openingBalance,
    required this.returns,
    required this.employerContributions,
    required this.participantContributions,
    required this.closingBalance,
  });

  final DateTime referenceMonth;
  final Money openingBalance;
  final Money returns;
  final Money employerContributions;
  final Money participantContributions;
  final Money closingBalance;
}

class PensionDetails {
  const PensionDetails({
    required this.id,
    required this.providerName,
    required this.profileName,
    required this.taxRegime,
    required this.enrollmentDate,
    required this.balanceDate,
    required this.updatedThrough,
    required this.currentBalance,
    required this.partOneBalance,
    required this.participantReserve,
    required this.employerReserve,
    required this.monthlyReturn,
    required this.yearlyReturn,
    required this.twelveMonthReturn,
    required this.latestSnapshot,
    required this.history,
  });

  final String? id;
  final String providerName;
  final String profileName;
  final String? taxRegime;
  final DateTime? enrollmentDate;
  final DateTime balanceDate;
  final DateTime? updatedThrough;
  final Money currentBalance;
  final Money partOneBalance;
  final Money participantReserve;
  final Money employerReserve;
  final double? monthlyReturn;
  final double? yearlyReturn;
  final double? twelveMonthReturn;
  final PensionMonthlySnapshot? latestSnapshot;
  final List<PensionHistoryEntry> history;

  Money get displayedCurrentBalance =>
      latestSnapshot == null ? currentBalance : latestSnapshot!.closingBalance;
}

class PensionProjectionPoint {
  const PensionProjectionPoint({
    required this.year,
    required this.projectedBalance,
    required this.projectedParticipantReserve,
    required this.projectedEmployerReserve,
    required this.grossWithdrawable,
    required this.employerEligibleRate,
    required this.projectedContributionCount,
  });

  final int year;
  final Money projectedBalance;
  final Money projectedParticipantReserve;
  final Money projectedEmployerReserve;
  final Money grossWithdrawable;
  final double employerEligibleRate;
  final int projectedContributionCount;
}

class PensionReturnOverride {
  const PensionReturnOverride({
    required this.referenceMonth,
    required this.returnRate,
  });

  final DateTime referenceMonth;
  final double returnRate;
}

class PensionMonthlySnapshot {
  const PensionMonthlySnapshot({
    required this.referenceMonth,
    required this.asOfDate,
    required this.accumulatedReturn,
    required this.closingBalance,
    required this.contributionApplied,
    required this.projectedContribution,
  });

  final DateTime referenceMonth;
  final DateTime asOfDate;
  final Money accumulatedReturn;
  final Money closingBalance;

  /// Contribuição do mês já somada sobre a posição informada pela PREVI.
  final bool contributionApplied;

  /// Mediana das últimas contribuições, oferecida para lançamento na tela.
  final Money projectedContribution;
}

class PensionProjection {
  const PensionProjection({
    required this.pensionId,
    required this.sourceUpdatedThrough,
    required this.monthlyReturnRateUsed,
    required this.annualizedReturnRate,
    required this.averageParticipantContribution,
    required this.averageEmployerContribution,
    required this.currentContributionCount,
    required this.partOneBalance,
    required this.currentPartTwoBalance,
    required this.currentGrossWithdrawable,
    required this.currentEmployerEligibleRate,
    required this.latestSnapshot,
    required this.returnOverrides,
    required this.points,
    required this.notices,
  });

  final String pensionId;
  final DateTime sourceUpdatedThrough;
  final double monthlyReturnRateUsed;
  final double annualizedReturnRate;
  final Money averageParticipantContribution;
  final Money averageEmployerContribution;
  final int currentContributionCount;
  final Money partOneBalance;
  final Money currentPartTwoBalance;
  final Money currentGrossWithdrawable;
  final double currentEmployerEligibleRate;
  final PensionMonthlySnapshot? latestSnapshot;
  final List<PensionReturnOverride> returnOverrides;
  final List<PensionProjectionPoint> points;
  final List<String> notices;
}

class FinancialDocumentPreview {
  const FinancialDocumentPreview({
    required this.kind,
    required this.fileName,
    required this.warnings,
    this.loan,
    this.pension,
  });

  final FinancialDocumentKind kind;
  final String fileName;
  final List<String> warnings;
  final LoanDetails? loan;
  final PensionDetails? pension;
}
