import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/data/repositories/api_account_repository.dart';
import '../../accounts/domain/repositories/account_repository.dart';
import '../../categories/data/repositories/api_category_repository.dart';
import '../../categories/domain/entities/financial_category.dart';
import '../../categories/domain/repositories/category_repository.dart';
import '../../auth/application/auth_controller.dart';
import '../data/merchant_aliases_api.dart';
import '../data/repositories/api_transaction_repository.dart';
import '../domain/repositories/transaction_repository.dart';
import 'transaction_list_item.dart';

export '../data/merchant_aliases_api.dart' show MerchantAlias, AliasPreview;

final merchantAliasesApiProvider = Provider<MerchantAliasesApi>(
  (ref) => MerchantAliasesApi(ref.watch(apiClientProvider)),
);

/// Categorias de despesa, para o seletor das regras.
final expenseCategoriesProvider = FutureProvider<List<FinancialCategory>>(
  (ref) async {
    final todas = await ref.watch(categoryRepositoryProvider).listAll();
    return todas
        .where((c) => c.type == CategoryType.expense)
        .toList(growable: false)
      ..sort((a, b) => a.name.compareTo(b.name));
  },
);

final merchantAliasesProvider = FutureProvider<List<MerchantAlias>>(
  (ref) => ref.watch(merchantAliasesApiProvider).list(),
);

/// Estado da prévia enquanto o usuário digita o prefixo.
class AliasPreviewState {
  const AliasPreviewState.idle() : loading = false, value = null;
  const AliasPreviewState.loading() : loading = true, value = null;
  const AliasPreviewState.ready(AliasPreview this.value) : loading = false;

  final bool loading;
  final AliasPreview? value;
}

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => ApiAccountRepository(ref.watch(apiClientProvider)),
);

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => ApiCategoryRepository(ref.watch(apiClientProvider)),
);

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => ApiTransactionRepository(ref.watch(apiClientProvider)),
);

final transactionListItemsProvider = FutureProvider<List<TransactionListItem>>((
  ref,
) async {
  final accountRepository = ref.watch(accountRepositoryProvider);
  final categoryRepository = ref.watch(categoryRepositoryProvider);
  final transactionRepository = ref.watch(transactionRepositoryProvider);

  final accounts = await accountRepository.listActive();
  final categories = await categoryRepository.listAll();
  final now = DateTime.now();
  final transactions = await transactionRepository.list(
    query: TransactionQuery(
      from: DateTime(now.year, now.month),
      to: DateTime(
        now.year,
        now.month + 1,
      ).subtract(const Duration(microseconds: 1)),
    ),
  );

  final accountsById = {for (final account in accounts) account.id: account};
  final categoriesById = {
    for (final category in categories) category.id: category,
  };

  return transactions
      .map((transaction) {
        final account = accountsById[transaction.accountId];
        final category = categoriesById[transaction.categoryId];
        if (account == null || category == null) {
          throw StateError(
            'Relacionamento inválido na transação ${transaction.id}.',
          );
        }
        return TransactionListItem(
          transaction: transaction,
          account: account,
          category: category,
          parentCategory: category.parentId == null
              ? null
              : categoriesById[category.parentId],
        );
      })
      .toList(growable: false);
});
