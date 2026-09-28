import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/formatters/money_formatter.dart';
import '../../../core/domain/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/soft_card.dart';
import '../application/commitments_providers.dart';
import '../domain/entities/commitments_summary.dart';
import '../../fixed_expenses/application/fixed_expenses_providers.dart';
import '../../fixed_expenses/domain/fixed_expense.dart';
import '../../fixed_expenses/presentation/fixed_expense_form_sheet.dart';
import '../../subscriptions/application/subscriptions_providers.dart';
import '../../subscriptions/domain/subscription.dart';
import '../../subscriptions/presentation/subscription_form_sheet.dart';

const _monthNames = <String>[
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

const _monthAbbreviations = <String>[
  'JAN',
  'FEV',
  'MAR',
  'ABR',
  'MAI',
  'JUN',
  'JUL',
  'AGO',
  'SET',
  'OUT',
  'NOV',
  'DEZ',
];

class CommitmentsScreen extends ConsumerStatefulWidget {
  const CommitmentsScreen({super.key, this.initialSection = 0});

  final int initialSection;

  @override
  ConsumerState<CommitmentsScreen> createState() => _CommitmentsScreenState();
}

class _CommitmentsScreenState extends ConsumerState<CommitmentsScreen> {
  late int selectedSection;

  @override
  void initState() {
    super.initState();
    selectedSection = widget.initialSection;
  }

  @override
  void didUpdateWidget(covariant CommitmentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSection != widget.initialSection) {
      selectedSection = widget.initialSection;
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(commitmentsSummaryProvider);
    final fixedExpenses = ref.watch(fixedExpensesProvider);
    final subscriptions = ref.watch(subscriptionsProvider);
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.refresh(commitmentsSummaryProvider.future),
            ref.refresh(fixedExpensesProvider.future),
            ref.refresh(subscriptionsProvider.future),
          ]);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
              sliver: SliverList.list(
                children: [
                  PageHeader(
                    title: 'Compromissos',
                    subtitle: 'O que já está comprometido nos próximos meses',
                    actions: [
                      IconButton(
                        onPressed: () =>
                            ref.invalidate(commitmentsSummaryProvider),
                        icon: const Icon(LucideIcons.refreshCw),
                        tooltip: 'Atualizar análise',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  summary.when(
                    loading: () => const _LoadingState(),
                    error: (error, stackTrace) => _ErrorState(
                      onRetry: () => ref.invalidate(commitmentsSummaryProvider),
                    ),
                    data: (data) => fixedExpenses.when(
                      loading: () => const _LoadingState(),
                      error: (error, stackTrace) => _ErrorState(
                        onRetry: () => ref.invalidate(fixedExpensesProvider),
                      ),
                      data: (fixed) => subscriptions.when(
                        loading: () => const _LoadingState(),
                        error: (error, stackTrace) => _ErrorState(
                          onRetry: () => ref.invalidate(subscriptionsProvider),
                        ),
                        data: (activeSubscriptions) => _Content(
                          summary: data,
                          fixedExpenses: fixed,
                          subscriptions: activeSubscriptions,
                          selectedSection: selectedSection,
                          onSectionSelected: (value) =>
                              setState(() => selectedSection = value),
                          onEditFixedExpense: (expense) async {
                            final changed = await showFixedExpenseFormSheet(
                              context: context,
                              expense: expense,
                            );
                            if (changed == true) {
                              ref.invalidate(fixedExpensesProvider);
                            }
                          },
                          onEditSubscription: (subscription) async {
                            final changed = await showSubscriptionFormSheet(
                              context: context,
                              subscription: subscription,
                            );
                            if (changed == true) {
                              ref.invalidate(subscriptionsProvider);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/commitments/transactions'),
                    icon: const Icon(LucideIcons.listFilter, size: 18),
                    label: const Text('Ver extrato completo'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.summary,
    required this.fixedExpenses,
    required this.subscriptions,
    required this.selectedSection,
    required this.onSectionSelected,
    required this.onEditFixedExpense,
    required this.onEditSubscription,
  });

  final CommitmentsSummary summary;
  final List<FixedExpense> fixedExpenses;
  final List<Subscription> subscriptions;
  final int selectedSection;
  final ValueChanged<int> onSectionSelected;
  final ValueChanged<FixedExpense?> onEditFixedExpense;
  final ValueChanged<Subscription?> onEditSubscription;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryCard(summary: summary, subscriptions: subscriptions),
        const SizedBox(height: 16),
        _SectionSelector(
          selected: selectedSection,
          installmentCount: summary.installments.length,
          recurringCount: subscriptions.length,
          fixedCount: fixedExpenses.length,
          onSelected: onSectionSelected,
        ),
        const SizedBox(height: 14),
        if (selectedSection == 0)
          _InstallmentsList(items: summary.installments)
        else if (selectedSection == 1)
          _SubscriptionsList(items: subscriptions, onEdit: onEditSubscription),
        if (selectedSection == 2)
          _FixedExpensesList(items: fixedExpenses, onEdit: onEditFixedExpense),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary, required this.subscriptions});

  final CommitmentsSummary summary;
  final List<Subscription> subscriptions;

  @override
  Widget build(BuildContext context) {
    final subscriptionTotal = Money(
      subscriptions.fold<int>(
        0,
        (total, item) => total + item.amount.minorUnits,
      ),
    );
    final projection = summary
        .projection()
        .map(
          (item) => MonthlyCommitmentProjection(
            month: item.month,
            installments: item.installments,
            estimatedRecurring: subscriptionTotal,
          ),
        )
        .toList(growable: false);
    final maxMinorUnits = projection.fold<int>(
      0,
      (maximum, item) =>
          item.total.minorUnits > maximum ? item.total.minorUnits : maximum,
    );
    final currentMonth = projection.first;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .22),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.calendarClock, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Projeção de compromissos',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            MoneyFormatter.format(currentMonth.total),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            'previstos para ${_monthNames[currentMonth.month.month - 1]}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 18),
          for (final item in projection) ...[
            _ProjectionBar(item: item, maxMinorUnits: maxMinorUnits),
            if (item != projection.last) const SizedBox(height: 9),
          ],
          const SizedBox(height: 13),
          const Wrap(
            spacing: 14,
            runSpacing: 5,
            children: [
              _ProjectionLegend(color: Colors.white, label: 'Parcelas'),
              _ProjectionLegend(
                color: Color(0xFFC4B5FD),
                label: 'Assinaturas estimadas',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.hourglass,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${MoneyFormatter.format(summary.remainingInstallments)} ainda a pagar em compras parceladas. O valor cai quando cada compra termina.',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectionBar extends StatelessWidget {
  const _ProjectionBar({required this.item, required this.maxMinorUnits});

  final MonthlyCommitmentProjection item;
  final int maxMinorUnits;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 31,
        child: Text(
          _monthAbbreviations[item.month.month - 1],
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final total = item.total.minorUnits;
            final widthFactor = maxMinorUnits == 0
                ? 0.0
                : total / maxMinorUnits;
            return Stack(
              children: [
                Container(
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                SizedBox(
                  width: constraints.maxWidth * widthFactor,
                  height: 18,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: Row(
                      children: [
                        if (item.installments.minorUnits > 0)
                          Expanded(
                            flex: item.installments.minorUnits,
                            child: Container(color: Colors.white),
                          ),
                        if (item.estimatedRecurring.minorUnits > 0)
                          Expanded(
                            flex: item.estimatedRecurring.minorUnits,
                            child: Container(color: const Color(0xFFC4B5FD)),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      const SizedBox(width: 9),
      SizedBox(
        width: 91,
        child: Text(
          MoneyFormatter.format(item.total),
          textAlign: TextAlign.end,
          maxLines: 1,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ],
  );
}

class _ProjectionLegend extends StatelessWidget {
  const _ProjectionLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
    ],
  );
}

class _SectionSelector extends StatelessWidget {
  const _SectionSelector({
    required this.selected,
    required this.installmentCount,
    required this.recurringCount,
    required this.fixedCount,
    required this.onSelected,
  });

  final int selected;
  final int installmentCount;
  final int recurringCount;
  final int fixedCount;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Parcelas', installmentCount, LucideIcons.creditCard),
      ('Assinaturas', recurringCount, LucideIcons.repeat2),
      ('Fixos', fixedCount, LucideIcons.receiptText),
    ];
    return Row(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          if (index > 0) const SizedBox(width: 9),
          Expanded(
            child: InkWell(
              onTap: () => onSelected(index),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: selected == index
                      ? AppColors.primary
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected == index
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      items[index].$3,
                      size: 17,
                      color: selected == index ? Colors.white : AppColors.text,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${items[index].$1}  ${items[index].$2}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected == index
                              ? Colors.white
                              : AppColors.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
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

class _InstallmentsList extends StatelessWidget {
  const _InstallmentsList({required this.items});

  final List<InstallmentCommitment> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyState(label: 'Nenhuma compra parcelada ativa.');
    }
    return Column(
      children: [
        for (final item in items) ...[
          _InstallmentCard(item: item),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _InstallmentCard extends StatelessWidget {
  const _InstallmentCard({required this.item});

  final InstallmentCommitment item;

  @override
  Widget build(BuildContext context) => SoftCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFEDEBFF),
              foregroundColor: AppColors.primary,
              child: Icon(LucideIcons.shoppingBag, size: 19),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.merchantName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.accountName,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  MoneyFormatter.format(item.installmentAmount),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const Text(
                  '/mês',
                  style: TextStyle(color: AppColors.muted, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Text(
              '${item.paidInstallments} de ${item.totalInstallments} pagas',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
            ),
            const Spacer(),
            Text(
              'Faltam ${item.remainingInstallments}',
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: item.progress,
            minHeight: 7,
            backgroundColor: AppColors.border,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 11),
        Row(
          children: [
            const Icon(
              LucideIcons.walletCards,
              size: 15,
              color: AppColors.muted,
            ),
            const SizedBox(width: 6),
            Text(
              '${MoneyFormatter.format(item.remainingAmount)} restantes',
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
            const Spacer(),
            if (item.nextExpectedAt != null)
              Text(
                'Próxima ${DateFormat('dd/MM').format(item.nextExpectedAt!)}',
                style: const TextStyle(color: AppColors.primary, fontSize: 11),
              ),
          ],
        ),
      ],
    ),
  );
}

class _SubscriptionsList extends StatelessWidget {
  const _SubscriptionsList({required this.items, required this.onEdit});

  final List<Subscription> items;
  final ValueChanged<Subscription?> onEdit;

  @override
  Widget build(BuildContext context) {
    final total = Money(
      items.fold<int>(0, (sum, item) => sum + item.amount.minorUnits),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.secondary.withValues(alpha: .15),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Assinaturas ativas',
                style: TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                MoneyFormatter.format(total),
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${items.length} cobranças mensais confirmadas',
                style: const TextStyle(color: AppColors.muted, fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => onEdit(null),
          icon: const Icon(LucideIcons.plus, size: 18),
          label: const Text('Adicionar assinatura'),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const _EmptyState(label: 'Nenhuma assinatura ativa cadastrada.')
        else
          for (final item in items) ...[
            _SubscriptionCard(item: item, onTap: () => onEdit(item)),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.item, required this.onTap});

  final Subscription item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SoftCard(
    onTap: onTap,
    child: Row(
      children: [
        const CircleAvatar(
          backgroundColor: Color(0xFFF1EAFE),
          foregroundColor: AppColors.secondary,
          child: Icon(LucideIcons.repeat2, size: 19),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  if (item.billingDay != null) 'cobra dia ${item.billingDay}',
                  if (item.paymentMethodLabel.isNotEmpty)
                    item.paymentMethodLabel,
                ].join(' • '),
                style: const TextStyle(color: AppColors.muted, fontSize: 10),
              ),
              if (item.billingDescriptor.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  item.billingDescriptor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 9),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              MoneyFormatter.format(item.amount),
              style: const TextStyle(
                color: AppColors.secondary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Text(
              '/mês',
              style: TextStyle(color: AppColors.muted, fontSize: 10),
            ),
            const SizedBox(height: 7),
            const Icon(LucideIcons.pencil, color: AppColors.primary, size: 14),
          ],
        ),
      ],
    ),
  );
}

class _FixedExpensesList extends StatelessWidget {
  const _FixedExpensesList({required this.items, required this.onEdit});

  final List<FixedExpense> items;
  final ValueChanged<FixedExpense?> onEdit;

  @override
  Widget build(BuildContext context) {
    final knownTotal = Money(
      items.fold<int>(0, (sum, item) => sum + (item.amount?.minorUnits ?? 0)),
    );
    final variableCount = items.where((item) => item.isVariable).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.success.withValues(alpha: .15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gastos mensais conhecidos',
                style: TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                MoneyFormatter.format(knownTotal),
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                variableCount == 0
                    ? '${items.length} gastos mensais cadastrados'
                    : '${items.length} cadastrados • $variableCount variável sem valor definido',
                style: const TextStyle(color: AppColors.muted, fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => onEdit(null),
          icon: const Icon(LucideIcons.plus, size: 18),
          label: const Text('Adicionar gasto fixo'),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const _EmptyState(label: 'Nenhum gasto fixo cadastrado.')
        else
          for (final item in items) ...[
            _FixedExpenseCard(item: item, onTap: () => onEdit(item)),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _FixedExpenseCard extends StatelessWidget {
  const _FixedExpenseCard({required this.item, required this.onTap});

  final FixedExpense item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SoftCard(
    onTap: onTap,
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: _color.withValues(alpha: .11),
          foregroundColor: _color,
          child: Icon(_icon, size: 19),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                [
                  _categoryLabel(item.categoryId),
                  if (item.locationLabel.isNotEmpty) item.locationLabel,
                  if (item.dueDay != null) 'vence dia ${item.dueDay}',
                ].join(' • '),
                style: const TextStyle(color: AppColors.muted, fontSize: 10),
              ),
              if (item.isVariable) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Text(
                    'Valor variável',
                    style: TextStyle(
                      color: AppColors.info,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              item.amount == null
                  ? 'A definir'
                  : MoneyFormatter.format(item.amount!),
              style: TextStyle(
                color: item.amount == null ? AppColors.muted : AppColors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Text(
              '/mês',
              style: TextStyle(color: AppColors.muted, fontSize: 10),
            ),
            const SizedBox(height: 7),
            const Icon(LucideIcons.pencil, color: AppColors.primary, size: 14),
          ],
        ),
      ],
    ),
  );

  IconData get _icon => switch (item.categoryId) {
    'housing-rent' => LucideIcons.house,
    'insurance' => LucideIcons.shieldCheck,
    'communications-internet' => LucideIcons.wifi,
    'communications-mobile' => LucideIcons.smartphone,
    'housing-utilities' => LucideIcons.zap,
    _ => LucideIcons.receiptText,
  };

  Color get _color => switch (item.categoryId) {
    'housing-rent' => AppColors.primary,
    'insurance' => AppColors.secondary,
    'communications-internet' => AppColors.info,
    'communications-mobile' => AppColors.success,
    'housing-utilities' => AppColors.warning,
    _ => AppColors.muted,
  };
}

String _categoryLabel(String categoryId) => switch (categoryId) {
  'housing-rent' => 'Aluguel',
  'insurance' => 'Seguro',
  'communications-internet' => 'Internet',
  'communications-mobile' => 'Telefonia',
  'housing-utilities' => 'Energia',
  _ => 'Outros',
};

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) => const SoftCard(
    child: SizedBox(
      height: 220,
      child: Center(child: CircularProgressIndicator()),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => SoftCard(
    child: Column(
      children: [
        const Icon(LucideIcons.circleAlert, color: AppColors.danger),
        const SizedBox(height: 9),
        const Text('Não foi possível analisar seus compromissos.'),
        TextButton(onPressed: onRetry, child: const Text('Tentar novamente')),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => SoftCard(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Icon(
            LucideIcons.circleCheck,
            color: AppColors.success,
            size: 30,
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    ),
  );
}
