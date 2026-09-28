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
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('captura as cinco telas principais em viewport Android', (
    tester,
  ) async {
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter-Variable.ttf'));
    await inter.load();
    final lucide = FontLoader('packages/lucide_icons_flutter/Lucide')
      ..addFont(
        rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
      );
    await lucide.load();

    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/01_overview.png'),
    );

    await _openTab(tester, 'Compromissos');
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/02_commitments.png'),
    );

    await _openTab(tester, 'Planejamento');
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/03_planning.png'),
    );

    await _openTab(tester, 'Chat com IA');
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/04_chat.png'),
    );

    await _openTab(tester, 'Mais');
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/05_more.png'),
    );
  });
}

Future<void> _openTab(WidgetTester tester, String label) async {
  final destination = find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  );
  await tester.tap(destination);
  await tester.pumpAndSettle();
}
