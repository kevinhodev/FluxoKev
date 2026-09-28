import 'package:fluxo_ia/app/app.dart';
import 'package:fluxo_ia/features/transactions/application/transaction_providers.dart';
import 'package:fluxo_ia/features/transactions/data/repositories/in_memory_transaction_repository.dart';
import 'package:fluxo_ia/features/transactions/domain/entities/financial_transaction.dart';
import 'package:fluxo_ia/features/accounts/data/repositories/in_memory_account_repository.dart';
import 'package:fluxo_ia/features/categories/data/repositories/in_memory_category_repository.dart';
import 'package:fluxo_ia/features/commitments/application/commitments_providers.dart';
import 'package:fluxo_ia/features/commitments/data/repositories/in_memory_commitments_repository.dart';
import 'package:fluxo_ia/features/document_imports/application/document_import_providers.dart';
import 'package:fluxo_ia/features/fixed_expenses/application/fixed_expenses_providers.dart';
import 'package:fluxo_ia/features/subscriptions/application/subscriptions_providers.dart';
import 'package:fluxo_ia/features/benefits/application/benefit_wallets_providers.dart';
import 'package:fluxo_ia/features/overview/application/financial_dashboard_provider.dart';
import 'package:fluxo_ia/features/portfolio/data/repositories/in_memory_portfolio_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('adiciona uma transação manual pelo formulário', (tester) async {
    final repository = InMemoryTransactionRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(repository),
          accountRepositoryProvider.overrideWithValue(
            InMemoryAccountRepository(),
          ),
          categoryRepositoryProvider.overrideWithValue(
            InMemoryCategoryRepository(),
          ),
          commitmentsRepositoryProvider.overrideWithValue(
            InMemoryCommitmentsRepository(),
          ),
          portfolioRepositoryProvider.overrideWithValue(
            InMemoryPortfolioRepository(),
          ),
          loansProvider.overrideWith((ref) async => const []),
          pensionsProvider.overrideWith((ref) async => const []),
          payrollSummaryProvider.overrideWith((ref) async => null),
          fixedExpensesProvider.overrideWith((ref) async => const []),
          subscriptionsProvider.overrideWith((ref) async => const []),
          benefitWalletsProvider.overrideWith((ref) async => const []),
        ],
        child: const FluxoIaApp(skipAuthentication: true),
      ),
    );
    await tester.pumpAndSettle();

    final commitmentsTab = find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Compromissos'),
    );
    await tester.tap(commitmentsTab);
    await tester.pumpAndSettle();
    final fullStatement = find.text('Ver extrato completo');
    await tester.scrollUntilVisible(
      fullStatement,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(fullStatement);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nova transação'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('transaction-description')),
      'Padaria',
    );
    await tester.enterText(
      find.byKey(const Key('transaction-amount')),
      '25,90',
    );
    final submit = find.byKey(const Key('transaction-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    final saved = (await repository.list())
        .where((transaction) => transaction.description == 'Padaria')
        .single;
    expect(saved.amount.minorUnits, 2590);
    expect(saved.source, TransactionSource.manual);
    expect(find.text('Transação adicionada com sucesso.'), findsOneWidget);
  });
}
