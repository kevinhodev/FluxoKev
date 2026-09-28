import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/formatters/money_formatter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/soft_card.dart';
import 'merchant_alias_sheet.dart';
import '../../accounts/domain/entities/financial_account.dart';
import '../../categories/domain/entities/financial_category.dart';
import '../../overview/application/financial_dashboard_provider.dart';
import '../application/transaction_list_item.dart';
import '../application/transaction_providers.dart';
import '../domain/entities/financial_transaction.dart';
import 'transaction_form_sheet.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  var selectedFilter = 0;
  var search = '';

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionListItemsProvider);
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
            sliver: SliverList.list(
              children: [
                PageHeader(
                  title: 'Transações',
                  subtitle: 'Acompanhe todas as movimentações',
                  actions: [
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(LucideIcons.search),
                      tooltip: 'Pesquisar',
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(LucideIcons.slidersHorizontal),
                      tooltip: 'Filtrar',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: GradientButton(
                    label: 'Nova transação',
                    icon: LucideIcons.plus,
                    onPressed: _openTransactionForm,
                  ),
                ),
                const SizedBox(height: 16),
                _Filters(
                  selected: selectedFilter,
                  onSelected: (value) => setState(() => selectedFilter = value),
                ),
                const SizedBox(height: 14),
                const _TransactionsSummary(),
                const SizedBox(height: 14),
                _SearchAndPeriod(
                  onSearch: (value) => setState(() => search = value),
                ),
                const SizedBox(height: 14),
                transactions.when(
                  loading: () => const _LoadingCard(),
                  error: (error, stackTrace) => _ErrorCard(
                    onRetry: () => ref.invalidate(transactionListItemsProvider),
                  ),
                  data: (items) => _TransactionList(
                    items: _applyFilters(items),
                    onEdit: _openTransactionForm,
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () {},
                  label: const Text('Carregar mais transações'),
                  icon: const Icon(LucideIcons.chevronDown, size: 18),
                  iconAlignment: IconAlignment.end,
                  style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                ),
                const SizedBox(height: 12),
                const _TransactionInsight(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<TransactionListItem> _applyFilters(List<TransactionListItem> items) {
    final normalizedSearch = search.trim().toLowerCase();
    return items
        .where((item) {
          final transaction = item.transaction;
          final matchesTab = switch (selectedFilter) {
            1 => item.account.type != AccountType.creditCard,
            2 => item.account.type == AccountType.creditCard,
            3 =>
              transaction.source != TransactionSource.openFinance &&
                  transaction.source != TransactionSource.manual,
            _ => true,
          };
          if (!matchesTab) return false;
          if (normalizedSearch.isEmpty) return true;
          return '${transaction.description} ${transaction.merchantName}'
              .toLowerCase()
              .contains(normalizedSearch);
        })
        .toList(growable: false);
  }

  Future<void> _openTransactionForm([TransactionListItem? item]) async {
    try {
      final results = await Future.wait([
        ref.read(accountRepositoryProvider).listActive(),
        ref.read(categoryRepositoryProvider).listAll(),
      ]);
      if (!mounted) return;

      final transaction = await showTransactionFormSheet(
        context: context,
        accounts: results[0] as List<FinancialAccount>,
        categories: results[1] as List<FinancialCategory>,
        transaction: item?.transaction,
      );
      if (transaction == null || !mounted) return;

      await ref.read(transactionRepositoryProvider).save(transaction);
      ref.invalidate(transactionListItemsProvider);
      ref.invalidate(financialDashboardProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            item == null
                ? 'Transação adicionada com sucesso.'
                : 'Transação atualizada com sucesso.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível salvar a transação.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  static const data = [
    ('Todas', LucideIcons.layers),
    ('Conta', LucideIcons.landmark),
    ('Cartão', LucideIcons.creditCard),
    ('Importadas', LucideIcons.fileUp),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < data.length; index++) ...[
          if (index > 0) const SizedBox(width: 7),
          Expanded(
            child: InkWell(
              onTap: () => onSelected(index),
              borderRadius: BorderRadius.circular(13),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  gradient: index == selected
                      ? AppColors.primaryGradient
                      : null,
                  color: index == selected ? null : AppColors.surface,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: index == selected
                        ? Colors.transparent
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      data[index].$2,
                      size: 16,
                      color: index == selected ? Colors.white : AppColors.text,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        data[index].$1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: index == selected
                              ? Colors.white
                              : AppColors.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TransactionsSummary extends ConsumerWidget {
  const _TransactionsSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(financialDashboardProvider);
    return dashboard.when(
      loading: () => const SoftCard(
        child: SizedBox(
          height: 66,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, stackTrace) => const SoftCard(
        child: SizedBox(
          height: 66,
          child: Center(child: Text('Resumo indisponível')),
        ),
      ),
      data: (snapshot) {
        final cashFlow = snapshot.cashFlow;
        return SoftCard(
          child: Row(
            children: [
              Expanded(
                child: _SummaryCell(
                  'Receitas',
                  MoneyFormatter.format(cashFlow.current.income),
                  _formatChange(cashFlow.incomeChange),
                  AppColors.success,
                ),
              ),
              const _VerticalDivider(),
              Expanded(
                child: _SummaryCell(
                  'Despesas',
                  MoneyFormatter.format(cashFlow.current.expenses),
                  _formatChange(cashFlow.expenseChange),
                  AppColors.danger,
                ),
              ),
              const _VerticalDivider(),
              Expanded(
                child: _SummaryCell(
                  'Saldo',
                  MoneyFormatter.format(cashFlow.current.balance),
                  _formatChange(cashFlow.balanceChange),
                  AppColors.primary,
                ),
              ),
              const _VerticalDivider(),
              Expanded(
                child: _SummaryCell(
                  'Transações',
                  '${cashFlow.current.transactionCount}',
                  'ago/2026',
                  AppColors.muted,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _formatChange(double? value) {
  if (value == null) return '—';
  final arrow = value >= 0 ? '↑' : '↓';
  final percentage = (value.abs() * 100)
      .toStringAsFixed(2)
      .replaceAll('.', ',');
  return '$arrow $percentage%';
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell(this.label, this.value, this.footer, this.color);

  final String label;
  final String value;
  final String footer;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 11)),
          const SizedBox(height: 7),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(footer, style: TextStyle(color: color, fontSize: 9)),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 66, color: AppColors.border);
}

class _SearchAndPeriod extends StatelessWidget {
  const _SearchAndPeriod({required this.onSearch});

  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final search = TextField(
          onChanged: onSearch,
          decoration: const InputDecoration(
            hintText: 'Buscar descrição ou comerciante...',
            prefixIcon: Icon(LucideIcons.search, size: 19),
          ),
        );
        final period = OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(LucideIcons.calendarDays, size: 18),
          label: const Text('01/08 — 31/08'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.text,
            backgroundColor: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            side: const BorderSide(color: AppColors.border),
          ),
        );
        if (constraints.maxWidth < 560) {
          return Column(
            children: [
              search,
              const SizedBox(height: 9),
              SizedBox(width: double.infinity, child: period),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: search),
            const SizedBox(width: 10),
            period,
          ],
        );
      },
    );
  }
}

class _TransactionList extends StatelessWidget {
  const _TransactionList({required this.items, required this.onEdit});

  final List<TransactionListItem> items;
  final ValueChanged<TransactionListItem> onEdit;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SoftCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Icon(LucideIcons.searchX, color: AppColors.muted, size: 28),
              SizedBox(height: 9),
              Text(
                'Nenhuma transação encontrada',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      );
    }
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _TransactionTile(item: items[index], onEdit: onEdit),
            if (index != items.length - 1) const Divider(),
          ],
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.item, required this.onEdit});

  final TransactionListItem item;
  final ValueChanged<TransactionListItem> onEdit;

  @override
  Widget build(BuildContext context) {
    final transaction = item.transaction;
    final color = _categoryColor(item);
    final amountColor = transaction.affectsCashFlow
        ? transaction.direction == TransactionDirection.credit
              ? AppColors.success
              : AppColors.danger
        : AppColors.primary;
    return InkWell(
      // Segurar abre a normalização: é aqui que o descritor cru da operadora
      // aparece, então é onde faz sentido decidir agrupá-lo.
      onLongPress: () => showMerchantAliasSheet(
        context,
        rawDescription: transaction.description,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                '${transaction.occurredAt.day.toString().padLeft(2, '0')}\nAGO',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
            ),
            const SizedBox(width: 10),
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: .12),
              foregroundColor: color,
              child: Icon(_merchantIcon(transaction), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.account.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                    ),
                  ),
                  if (transaction.isPending) ...[
                    const SizedBox(height: 3),
                    const Text(
                      'Pendente',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 5),
                  Text(
                    '${item.primaryCategory} • ${item.secondaryCategory}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 82,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  MoneyFormatter.format(transaction.signedAmount),
                  maxLines: 1,
                  style: TextStyle(
                    color: amountColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 28,
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: () => onEdit(item),
                icon: const Icon(LucideIcons.ellipsisVertical, size: 17),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _categoryColor(TransactionListItem item) {
  if (item.transaction.nature == TransactionNature.transfer) {
    return AppColors.primary;
  }
  if (item.category.id == 'food-supermarket') {
    return AppColors.success;
  }
  if (item.category.type == CategoryType.income ||
      item.category.type == CategoryType.investment) {
    return AppColors.success;
  }
  return switch (item.parentCategory?.id ?? item.category.id) {
    'food' => AppColors.danger,
    'transport' => AppColors.success,
    'subscriptions' => AppColors.secondary,
    'housing' => AppColors.info,
    _ => AppColors.muted,
  };
}

IconData _merchantIcon(FinancialTransaction transaction) {
  final merchant = transaction.merchantName.toLowerCase();
  if (merchant.contains('ifood')) return LucideIcons.utensils;
  if (merchant.contains('posto')) return LucideIcons.fuel;
  if (merchant.contains('salário')) return LucideIcons.landmark;
  if (merchant.contains('netflix')) return LucideIcons.monitor;
  if (merchant.contains('pão')) return LucideIcons.shoppingCart;
  if (merchant.contains('aluguel')) return LucideIcons.home;
  if (merchant.contains('uber')) return LucideIcons.car;
  if (merchant.contains('cdb')) return LucideIcons.trendingUp;
  if (transaction.nature == TransactionNature.transfer) {
    return LucideIcons.arrowRightLeft;
  }
  return LucideIcons.receiptText;
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const SoftCard(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 34),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        children: [
          const Icon(LucideIcons.circleAlert, color: AppColors.danger),
          const SizedBox(height: 8),
          const Text('Não foi possível carregar as transações.'),
          TextButton(onPressed: onRetry, child: const Text('Tentar novamente')),
        ],
      ),
    );
  }
}

class _TransactionInsight extends StatelessWidget {
  const _TransactionInsight();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            child: Icon(LucideIcons.sparkles),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dica Fluxo IA',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Você gastou 12% a mais em alimentação que no mês passado.',
                  style: TextStyle(fontSize: 12, height: 1.35),
                ),
              ],
            ),
          ),
          Icon(LucideIcons.chevronRight, color: AppColors.primary),
        ],
      ),
    );
  }
}
