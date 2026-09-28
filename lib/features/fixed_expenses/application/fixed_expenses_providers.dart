import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/fixed_expenses_api.dart';
import '../domain/fixed_expense.dart';

final fixedExpensesApiProvider = Provider<FixedExpensesApi>(
  (ref) => FixedExpensesApi(ref.watch(apiClientProvider)),
);

final fixedExpensesProvider = FutureProvider<List<FixedExpense>>(
  (ref) => ref.watch(fixedExpensesApiProvider).list(),
);
