import 'package:fluxo_ia/app/app.dart';
import 'package:fluxo_ia/features/transactions/application/transaction_providers.dart';
import 'package:fluxo_ia/features/transactions/data/repositories/in_memory_transaction_repository.dart';
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
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('abre a visão geral e mostra a navegação principal', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(
            InMemoryTransactionRepository(),
          ),
          accountRepositoryProvider.overrideWithValue(
            InMemoryAccountRepository(),
          ),
          categoryRepositoryProvider.overrideWithValue(
            InMemoryCategoryRepository(),
          ),
          portfolioRepositoryProvider.overrideWithValue(
            InMemoryPortfolioRepository(),
          ),
          commitmentsRepositoryProvider.overrideWithValue(
            InMemoryCommitmentsRepository(),
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

    expect(find.text('Bom dia, Gabriel 👋'), findsOneWidget);
    expect(find.text('Visão Geral'), findsOneWidget);
    expect(find.text('Compromissos'), findsOneWidget);
    expect(find.text('Planejamento'), findsOneWidget);
    expect(find.text('Chat com IA'), findsOneWidget);
    expect(find.text('Mais'), findsOneWidget);
  });
}
