import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/financial_documents_api.dart';
import '../domain/entities/financial_documents.dart';

final financialDocumentsApiProvider = Provider<FinancialDocumentsApi>(
  (ref) => FinancialDocumentsApi(ref.watch(apiClientProvider)),
);

final loansProvider = FutureProvider<List<LoanDetails>>(
  (ref) => ref.watch(financialDocumentsApiProvider).listLoans(),
);

final payrollSummaryProvider = FutureProvider<PayrollSummary?>(
  (ref) => ref.watch(financialDocumentsApiProvider).getPayrollSummary(),
);

final pensionsProvider = FutureProvider<List<PensionDetails>>(
  (ref) => ref.watch(financialDocumentsApiProvider).listPensions(),
);

final pensionProjectionProvider =
    FutureProvider.family<PensionProjection, String>(
      (ref, pensionId) => ref
          .watch(financialDocumentsApiProvider)
          .getPensionProjection(pensionId),
    );
