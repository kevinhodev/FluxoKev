import 'dart:convert';
import 'dart:typed_data';

import '../../../core/domain/money.dart';
import '../../../core/network/api_client.dart';
import '../domain/entities/financial_documents.dart';

class FinancialDocumentsApi {
  const FinancialDocumentsApi(this._client);

  final ApiClient _client;

  Future<FinancialDocumentPreview> preview({
    required FinancialDocumentKind kind,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final json = await _client.post(
      '/v1/imports/pdf/preview',
      body: _uploadBody(kind: kind, fileName: fileName, bytes: bytes),
    );
    return _preview(json as Map<String, dynamic>);
  }

  Future<FinancialDocumentPreview> importDocument({
    required FinancialDocumentKind kind,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final json = await _client.post(
      '/v1/imports/pdf',
      body: _uploadBody(kind: kind, fileName: fileName, bytes: bytes),
    );
    return _preview(json as Map<String, dynamic>);
  }

  Future<List<LoanDetails>> listLoans() async {
    final rows = await _client.get('/v1/loans') as List<dynamic>;
    return rows
        .map((row) => _loan(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<LoanDetails> setEarlySettlement({
    required String loanId,
    required int front,
    required int back,
  }) async {
    final json = await _client.put(
      '/v1/loans/$loanId/settlements',
      body: {'front': front, 'back': back},
    );
    return _loan(json as Map<String, dynamic>);
  }

  Future<PayrollSummary?> getPayrollSummary() async {
    final json = await _client.get('/v1/payroll/summary');
    if (json == null) return null;
    final data = json as Map<String, dynamic>;
    return PayrollSummary(
      referenceMonth: DateTime.parse(data['referenceMonth'] as String),
      regularNetReference: Money(
        (data['regularNetReferenceMinorUnits'] as num).toInt(),
      ),
      excludedDeduction: Money(
        (data['excludedDeductionMinorUnits'] as num).toInt(),
      ),
      exclusionEffectiveFrom: _date(data['exclusionEffectiveFrom']),
      correctedNetEstimate: Money(
        (data['correctedNetEstimateMinorUnits'] as num).toInt(),
      ),
      ownPayrollLoanDeductions: Money(
        (data['ownPayrollLoanDeductionsMinorUnits'] as num).toInt(),
      ),
      ownPayrollLoanCount: (data['ownPayrollLoanCount'] as num).toInt(),
    );
  }

  Future<List<PensionDetails>> listPensions() async {
    final rows = await _client.get('/v1/pensions') as List<dynamic>;
    return rows
        .map((row) => _pension(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<PensionProjection> getPensionProjection(
    String pensionId, {
    int years = 10,
  }) async {
    final json = await _client.get(
      '/v1/pensions/$pensionId/projection',
      query: {'years': '$years'},
    );
    return _pensionProjection(json as Map<String, dynamic>);
  }

  Future<PensionProjection> saveMonthlyReturn({
    required String pensionId,
    required DateTime referenceMonth,
    required double returnRate,
  }) async {
    final month =
        '${referenceMonth.year.toString().padLeft(4, '0')}-${referenceMonth.month.toString().padLeft(2, '0')}-01';
    final json = await _client.put(
      '/v1/pensions/$pensionId/monthly-return',
      body: {'referenceMonth': month, 'returnRate': returnRate},
    );
    return _pensionProjection(json as Map<String, dynamic>);
  }

  Future<PensionProjection> saveMonthlySnapshot({
    required String pensionId,
    required DateTime asOfDate,
    required Money accumulatedReturn,
    bool contributionApplied = false,
  }) async {
    final referenceMonth =
        '${asOfDate.year.toString().padLeft(4, '0')}-${asOfDate.month.toString().padLeft(2, '0')}-01';
    final date =
        '${asOfDate.year.toString().padLeft(4, '0')}-${asOfDate.month.toString().padLeft(2, '0')}-${asOfDate.day.toString().padLeft(2, '0')}';
    final json = await _client.put(
      '/v1/pensions/$pensionId/monthly-snapshot',
      body: {
        'referenceMonth': referenceMonth,
        'asOfDate': date,
        'accumulatedReturnMinorUnits': accumulatedReturn.minorUnits,
        'contributionApplied': contributionApplied,
      },
    );
    return _pensionProjection(json as Map<String, dynamic>);
  }

  Map<String, dynamic> _uploadBody({
    required FinancialDocumentKind kind,
    required String fileName,
    required Uint8List bytes,
  }) => {
    'kind': kind == FinancialDocumentKind.loan ? 'LOAN' : 'PENSION',
    'fileName': fileName,
    'contentBase64': base64Encode(bytes),
  };

  FinancialDocumentPreview _preview(Map<String, dynamic> json) {
    final kind = json['kind'] == 'LOAN'
        ? FinancialDocumentKind.loan
        : FinancialDocumentKind.pension;
    final data = json['data'] as Map<String, dynamic>;
    return FinancialDocumentPreview(
      kind: kind,
      fileName: json['fileName'] as String,
      warnings: (json['warnings'] as List<dynamic>? ?? const []).cast<String>(),
      loan: kind == FinancialDocumentKind.loan ? _loan(data) : null,
      pension: kind == FinancialDocumentKind.pension ? _pension(data) : null,
    );
  }

  LoanDetails _loan(Map<String, dynamic> json) => LoanDetails(
    id: json['id'] as String?,
    providerName: json['providerName'] as String,
    productName: json['productName'] as String,
    contractNumber: json['contractNumber'] as String,
    documentDate: DateTime.parse(json['documentDate'] as String),
    contractDate: DateTime.parse(json['contractDate'] as String),
    currentBalance: Money((json['currentBalanceMinorUnits'] as num).toInt()),
    originalTotal: Money((json['originalTotalMinorUnits'] as num).toInt()),
    debitDay: (json['debitDay'] as num).toInt(),
    monthlyInterestRate: _double(json['monthlyInterestRate']),
    annualInterestRate: _double(json['annualInterestRate']),
    monthlyEffectiveCost: _double(json['monthlyEffectiveCost']),
    annualEffectiveCost: _double(json['annualEffectiveCost']),
    repaymentKind: json['repaymentKind'] == 'THIRTEENTH_SALARY'
        ? LoanRepaymentKind.thirteenthSalary
        : LoanRepaymentKind.monthly,
    payrollDeducted: json['payrollDeducted'] as bool? ?? false,
    totalInstallments: (json['totalInstallments'] as num).toInt(),
    paidInstallments: (json['paidInstallments'] as num).toInt(),
    remainingInstallments: (json['remainingInstallments'] as num).toInt(),
    amortizedInstallments: (json['amortizedInstallments'] as num).toInt(),
    nextDueDate: _date(json['nextDueDate']),
    projectedEndDate: _date(json['projectedEndDate']),
    remainingPayments: Money(
      (json['remainingPaymentsMinorUnits'] as num).toInt(),
    ),
    payoff: Money((json['payoffMinorUnits'] as num).toInt()),
    installments: (json['installments'] as List<dynamic>)
        .map((item) => _loanInstallment(item as Map<String, dynamic>))
        .toList(growable: false),
  );

  LoanInstallment _loanInstallment(Map<String, dynamic> json) =>
      LoanInstallment(
        number: (json['number'] as num).toInt(),
        dueDate: DateTime.parse(json['dueDate'] as String),
        status: json['status'] == 'PAID'
            ? LoanInstallmentStatus.paid
            : LoanInstallmentStatus.open,
        paymentKind: switch (json['paymentKind']) {
          'AMORTIZED' => LoanPaymentKind.amortized,
          'REGULAR' => LoanPaymentKind.regular,
          _ => LoanPaymentKind.pending,
        },
        amount: Money((json['amountMinorUnits'] as num).toInt()),
        earlySettled: json['earlySettled'] as bool? ?? false,
      );

  PensionDetails _pension(Map<String, dynamic> json) => PensionDetails(
    id: json['id'] as String?,
    providerName: json['providerName'] as String,
    profileName: json['profileName'] as String,
    taxRegime: json['taxRegime'] as String?,
    enrollmentDate: _date(json['enrollmentDate']),
    balanceDate: DateTime.parse(json['balanceDate'] as String),
    updatedThrough: _date(json['updatedThrough']),
    currentBalance: Money((json['currentBalanceMinorUnits'] as num).toInt()),
    partOneBalance: Money((json['partOneBalanceMinorUnits'] as num).toInt()),
    participantReserve: Money(
      (json['participantReserveMinorUnits'] as num).toInt(),
    ),
    employerReserve: Money((json['employerReserveMinorUnits'] as num).toInt()),
    monthlyReturn: _double(json['monthlyReturn']),
    yearlyReturn: _double(json['yearlyReturn']),
    twelveMonthReturn: _double(json['twelveMonthReturn']),
    latestSnapshot: json['latestSnapshot'] == null
        ? null
        : _pensionMonthlySnapshot(
            json['latestSnapshot'] as Map<String, dynamic>,
          ),
    history: (json['history'] as List<dynamic>)
        .map((item) => _pensionHistory(item as Map<String, dynamic>))
        .toList(growable: false),
  );

  PensionProjection _pensionProjection(
    Map<String, dynamic> json,
  ) => PensionProjection(
    pensionId: json['pensionId'] as String,
    sourceUpdatedThrough: DateTime.parse(
      json['sourceUpdatedThrough'] as String,
    ),
    monthlyReturnRateUsed: (json['monthlyReturnRateUsed'] as num).toDouble(),
    annualizedReturnRate: (json['annualizedReturnRate'] as num).toDouble(),
    averageParticipantContribution: Money(
      (json['averageParticipantContributionMinorUnits'] as num).toInt(),
    ),
    averageEmployerContribution: Money(
      (json['averageEmployerContributionMinorUnits'] as num).toInt(),
    ),
    currentContributionCount: (json['currentContributionCount'] as num).toInt(),
    partOneBalance: Money((json['partOneBalanceMinorUnits'] as num).toInt()),
    currentPartTwoBalance: Money(
      (json['currentPartTwoBalanceMinorUnits'] as num).toInt(),
    ),
    currentGrossWithdrawable: Money(
      (json['currentGrossWithdrawableMinorUnits'] as num).toInt(),
    ),
    currentEmployerEligibleRate: (json['currentEmployerEligibleRate'] as num)
        .toDouble(),
    latestSnapshot: json['latestSnapshot'] == null
        ? null
        : _pensionMonthlySnapshot(
            json['latestSnapshot'] as Map<String, dynamic>,
          ),
    returnOverrides: (json['returnOverrides'] as List<dynamic>? ?? const [])
        .map(
          (item) => PensionReturnOverride(
            referenceMonth: DateTime.parse(
              (item as Map<String, dynamic>)['referenceMonth'] as String,
            ),
            returnRate: (item['returnRate'] as num).toDouble(),
          ),
        )
        .toList(growable: false),
    points: (json['points'] as List<dynamic>)
        .map((item) => _pensionProjectionPoint(item as Map<String, dynamic>))
        .toList(growable: false),
    notices: (json['notices'] as List<dynamic>).cast<String>(),
  );

  PensionMonthlySnapshot _pensionMonthlySnapshot(Map<String, dynamic> json) =>
      PensionMonthlySnapshot(
        referenceMonth: DateTime.parse(json['referenceMonth'] as String),
        asOfDate: DateTime.parse(json['asOfDate'] as String),
        accumulatedReturn: Money(
          (json['accumulatedReturnMinorUnits'] as num).toInt(),
        ),
        closingBalance: Money(
          (json['closingBalanceMinorUnits'] as num).toInt(),
        ),
        contributionApplied: json['contributionApplied'] as bool? ?? false,
        projectedContribution: Money(
          (json['projectedContributionMinorUnits'] as num?)?.toInt() ?? 0,
        ),
      );

  PensionProjectionPoint _pensionProjectionPoint(Map<String, dynamic> json) =>
      PensionProjectionPoint(
        year: (json['year'] as num).toInt(),
        projectedBalance: Money(
          (json['projectedBalanceMinorUnits'] as num).toInt(),
        ),
        projectedParticipantReserve: Money(
          (json['projectedParticipantReserveMinorUnits'] as num).toInt(),
        ),
        projectedEmployerReserve: Money(
          (json['projectedEmployerReserveMinorUnits'] as num).toInt(),
        ),
        grossWithdrawable: Money(
          (json['grossWithdrawableMinorUnits'] as num).toInt(),
        ),
        employerEligibleRate: (json['employerEligibleRate'] as num).toDouble(),
        projectedContributionCount: (json['projectedContributionCount'] as num)
            .toInt(),
      );

  PensionHistoryEntry _pensionHistory(
    Map<String, dynamic> json,
  ) => PensionHistoryEntry(
    referenceMonth: DateTime.parse(json['referenceMonth'] as String),
    openingBalance: Money((json['openingBalanceMinorUnits'] as num).toInt()),
    returns: Money((json['returnsMinorUnits'] as num).toInt()),
    employerContributions: Money(
      (json['employerPart2aMinorUnits'] as num).toInt() +
          (json['employerPart2bMinorUnits'] as num).toInt(),
    ),
    participantContributions: Money(
      (json['participantPart2aMinorUnits'] as num).toInt() +
          (json['participantPart2bMinorUnits'] as num).toInt() +
          (json['participantPart2cMinorUnits'] as num).toInt(),
    ),
    closingBalance: Money((json['closingBalanceMinorUnits'] as num).toInt()),
  );

  DateTime? _date(dynamic value) =>
      value == null ? null : DateTime.parse(value as String);

  double? _double(dynamic value) =>
      value == null ? null : (value as num).toDouble();
}
