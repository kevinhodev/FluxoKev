import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/domain/money.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_brand.dart';
import '../../../core/widgets/soft_card.dart';
import '../../financial_engine/domain/financial_engine.dart';
import '../../benefits/application/benefit_wallets_providers.dart';
import '../../benefits/domain/benefit_wallet.dart';
import '../../benefits/presentation/benefit_wallet_form_sheet.dart';
import '../../document_imports/application/document_import_providers.dart';
import '../../document_imports/domain/entities/financial_documents.dart';
import '../../fixed_expenses/application/fixed_expenses_providers.dart';
import '../../fixed_expenses/domain/fixed_expense.dart';
import '../../subscriptions/application/subscriptions_providers.dart';
import '../../subscriptions/domain/subscription.dart';
import '../application/financial_dashboard_provider.dart';

class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(financialDashboardProvider);
    final pensions = ref.watch(pensionsProvider);
    final payroll = ref.watch(payrollSummaryProvider);
    final benefitWallets = ref.watch(benefitWalletsProvider);
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            sliver: SliverList.list(
              children: [
                const _OverviewHeader(),
                const SizedBox(height: 18),
                _DashboardSection(dashboard: dashboard),
                _BenefitWalletsSection(wallets: benefitWallets),
                _PayrollSection(summary: payroll),
                _PensionSection(pensions: pensions),
                const SizedBox(height: 16),
                const _InsightCard(),
                const SizedBox(height: 14),
                _ChatCta(onTap: () => context.go('/chat')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitWalletsSection extends ConsumerWidget {
  const _BenefitWalletsSection({required this.wallets});

  final AsyncValue<List<BenefitWallet>> wallets;

  @override
  Widget build(BuildContext context, WidgetRef ref) => wallets.when(
    loading: () => const SizedBox.shrink(),
    error: (error, stackTrace) => const SizedBox.shrink(),
    data: (items) {
      if (items.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          children: [
            for (final wallet in items) ...[
              SoftCard(
                onTap: () async {
                  final changed = await showBenefitWalletFormSheet(
                    context: context,
                    wallet: wallet,
                  );
                  if (changed == true) {
                    ref.invalidate(benefitWalletsProvider);
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Color(0xFFE8F8EF),
                          foregroundColor: AppColors.success,
                          child: Icon(LucideIcons.utensils),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                wallet.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const Text(
                                'Benefício separado do caixa livre',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              MoneyFormatter.format(wallet.currentBalance),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const Text(
                              'saldo atual',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _BenefitMetric(
                            label: 'Crédito mensal',
                            value: wallet.monthlyCredit,
                            color: AppColors.success,
                          ),
                        ),
                        Expanded(
                          child: _BenefitMetric(
                            label: wallet.allocationLabel.isEmpty
                                ? 'Valor reservado'
                                : wallet.allocationLabel,
                            value: wallet.monthlyAllocation,
                            color: AppColors.secondary,
                          ),
                        ),
                        Expanded(
                          child: _BenefitMetric(
                            label: 'Disponível para você',
                            value: wallet.monthlyAvailable,
                            color: wallet.monthlyAvailable.isNegative
                                ? AppColors.danger
                                : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Icon(
                          LucideIcons.pencil,
                          color: AppColors.primary,
                          size: 14,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Toque para atualizar saldo e valores mensais',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      );
    },
  );
}

class _BenefitMetric extends StatelessWidget {
  const _BenefitMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final Money value;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.muted, fontSize: 9),
        ),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            MoneyFormatter.format(value),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  );
}

class _PayrollSection extends ConsumerWidget {
  const _PayrollSection({required this.summary});

  final AsyncValue<PayrollSummary?> summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptions = ref.watch(subscriptionsProvider);
    final fixedExpenses = ref.watch(fixedExpensesProvider);
    final loans = ref.watch(loansProvider);
    return summary.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (payroll) {
        if (payroll == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Color(0xFFE1F8EC),
                      foregroundColor: AppColors.success,
                      child: Icon(LucideIcons.badgeDollarSign),
                    ),
                    SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Salário líquido regular',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Estimativa após os descontos em folha',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  MoneyFormatter.format(payroll.correctedNetEstimate),
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Base regular de ${DateFormat('MM/yyyy').format(payroll.referenceMonth)} corrigida para os próximos meses.',
                  style: const TextStyle(color: AppColors.muted, fontSize: 10),
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _PayrollMetric(
                        label: 'Consignados BB mapeados',
                        value: MoneyFormatter.format(
                          payroll.ownPayrollLoanDeductions,
                        ),
                        detail: '${payroll.ownPayrollLoanCount} em folha',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PayrollMetric(
                        label: 'Desconto desconsiderado',
                        value:
                            '+${MoneyFormatter.format(payroll.excludedDeduction)}',
                        detail: 'desde jul/2026',
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(LucideIcons.info, size: 16, color: AppColors.info),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'A PREVI já está embutida no líquido. O veículo aparece abaixo como financiamento; Renovação Funci continua fora desta projeção.',
                          style: TextStyle(fontSize: 10, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 28),
                _PayrollCommitmentsBreakdown(
                  payroll: payroll,
                  subscriptions: subscriptions,
                  fixedExpenses: fixedExpenses,
                  loans: loans,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PayrollCommitmentsBreakdown extends StatelessWidget {
  const _PayrollCommitmentsBreakdown({
    required this.payroll,
    required this.subscriptions,
    required this.fixedExpenses,
    required this.loans,
  });

  final PayrollSummary payroll;
  final AsyncValue<List<Subscription>> subscriptions;
  final AsyncValue<List<FixedExpense>> fixedExpenses;
  final AsyncValue<List<LoanDetails>> loans;

  @override
  Widget build(BuildContext context) => subscriptions.when(
    loading: () => const _PayrollBreakdownLoading(),
    error: (error, stackTrace) => const _PayrollBreakdownUnavailable(),
    data: (activeSubscriptions) => fixedExpenses.when(
      loading: () => const _PayrollBreakdownLoading(),
      error: (error, stackTrace) => const _PayrollBreakdownUnavailable(),
      data: (fixed) => loans.when(
        loading: () => const _PayrollBreakdownLoading(),
        error: (error, stackTrace) => const _PayrollBreakdownUnavailable(),
        data: (loanItems) {
          final fixedTotal = Money(
            fixed.fold<int>(
              0,
              (total, item) => total + (item.amount?.minorUnits ?? 0),
            ),
          );
          final subscriptionsTotal = Money(
            activeSubscriptions.fold<int>(
              0,
              (total, item) => total + item.amount.minorUnits,
            ),
          );
          final vehicleFinancingTotal = Money(
            loanItems.fold<int>(0, (total, loan) {
              final product = loan.productName.toLowerCase();
              final isVehicle =
                  product.contains('veículo') || product.contains('veiculo');
              if (!isVehicle || loan.upcomingInstallments.isEmpty) return total;
              return total + loan.upcomingInstallments.first.amount.minorUnits;
            }),
          );
          final total = fixedTotal + subscriptionsTotal + vehicleFinancingTotal;
          final available = payroll.correctedNetEstimate - total;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Compromissos descontados do líquido',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              const Text(
                'Toque em uma linha para ver os detalhes.',
                style: TextStyle(color: AppColors.muted, fontSize: 10),
              ),
              const SizedBox(height: 9),
              _PayrollDiscountRow(
                icon: LucideIcons.receiptText,
                label: 'Gastos fixos',
                amount: fixedTotal,
                onTap: () => context.go('/commitments?section=fixed'),
              ),
              _PayrollDiscountRow(
                icon: LucideIcons.repeat2,
                label: 'Assinaturas',
                amount: subscriptionsTotal,
                onTap: () => context.go('/commitments?section=subscriptions'),
              ),
              _PayrollDiscountRow(
                icon: LucideIcons.carFront,
                label: 'Financiamentos',
                amount: vehicleFinancingTotal,
                onTap: () => context.go('/planning'),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      (available.isNegative
                              ? AppColors.danger
                              : AppColors.success)
                          .withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Livre após compromissos',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Projeção mensal, não é o saldo da conta',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      MoneyFormatter.format(available),
                      style: TextStyle(
                        color: available.isNegative
                            ? AppColors.danger
                            : AppColors.success,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _PayrollDiscountRow extends StatelessWidget {
  const _PayrollDiscountRow({
    required this.icon,
    required this.label,
    required this.amount,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Money amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(11),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 9),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.primary),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '-${MoneyFormatter.format(amount)}',
            style: const TextStyle(
              color: AppColors.danger,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 5),
          const Icon(
            LucideIcons.chevronRight,
            size: 15,
            color: AppColors.muted,
          ),
        ],
      ),
    ),
  );
}

class _PayrollBreakdownLoading extends StatelessWidget {
  const _PayrollBreakdownLoading();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );
}

class _PayrollBreakdownUnavailable extends StatelessWidget {
  const _PayrollBreakdownUnavailable();

  @override
  Widget build(BuildContext context) => const Text(
    'Não foi possível calcular os compromissos agora.',
    style: TextStyle(color: AppColors.muted, fontSize: 10),
  );
}

class _PayrollMetric extends StatelessWidget {
  const _PayrollMetric({
    required this.label,
    required this.value,
    required this.detail,
    this.color = AppColors.text,
  });

  final String label;
  final String value;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 10)),
      const SizedBox(height: 5),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const SizedBox(height: 2),
      Text(detail, style: const TextStyle(color: AppColors.muted, fontSize: 9)),
    ],
  );
}

class _DashboardSection extends ConsumerWidget {
  const _DashboardSection({required this.dashboard});

  final AsyncValue<FinancialDashboardSnapshot> dashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return dashboard.when(
      loading: () => const SoftCard(
        child: SizedBox(
          height: 180,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, stackTrace) => SoftCard(
        child: Column(
          children: [
            const Icon(LucideIcons.circleAlert, color: AppColors.danger),
            const SizedBox(height: 8),
            const Text('Não foi possível calcular seu panorama financeiro.'),
            TextButton(
              onPressed: () => ref.invalidate(financialDashboardProvider),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
      data: (snapshot) => Column(
        children: [
          _NetWorthHero(summary: snapshot.portfolio),
          const SizedBox(height: 24),
          const _TitleRow(title: 'Visão geral', action: 'Ver todos'),
          const SizedBox(height: 10),
          _AssetGrid(summary: snapshot.portfolio),
          const SizedBox(height: 16),
          _CompositionCard(summary: snapshot.portfolio),
          const SizedBox(height: 16),
          _MonthlySummary(comparison: snapshot.cashFlow),
        ],
      ),
    );
  }
}

class _PensionSection extends StatelessWidget {
  const _PensionSection({required this.pensions});

  final AsyncValue<List<PensionDetails>> pensions;

  @override
  Widget build(BuildContext context) => pensions.when(
    loading: () => const SizedBox.shrink(),
    error: (error, stackTrace) => const SizedBox.shrink(),
    data: (items) {
      if (items.isEmpty) return const SizedBox.shrink();
      final pension = items.first;
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: SoftCard(
          onTap: pension.id == null
              ? null
              : () => context.push('/pension/${pension.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFE1F8EC),
                    foregroundColor: AppColors.success,
                    child: Icon(LucideIcons.chartNoAxesCombined),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pension.providerName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          pension.profileName,
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
                        MoneyFormatter.format(pension.displayedCurrentBalance),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      if (pension.twelveMonthReturn != null)
                        Text(
                          '+${pension.twelveMonthReturn!.toStringAsFixed(2).replaceAll('.', ',')}% em 12 meses',
                          style: const TextStyle(
                            color: AppColors.success,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _PensionMetric(
                      label: 'Reserva pessoal',
                      value: MoneyFormatter.format(pension.participantReserve),
                    ),
                  ),
                  Expanded(
                    child: _PensionMetric(
                      label: 'Reserva patronal',
                      value: MoneyFormatter.format(pension.employerReserve),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                pension.latestSnapshot == null
                    ? 'Atualizada até ${DateFormat('dd/MM/yyyy').format(pension.updatedThrough ?? pension.balanceDate)} • ${pension.history.length} meses de histórico'
                    : 'Posição parcial em ${DateFormat('dd/MM/yyyy').format(pension.latestSnapshot!.asOfDate)} • ${pension.history.length} meses fechados',
                style: const TextStyle(color: AppColors.muted, fontSize: 10),
              ),
              if (pension.id != null) ...[
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Icon(
                      LucideIcons.chartSpline,
                      color: AppColors.primary,
                      size: 16,
                    ),
                    SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Projetar saldo e resgate ao sair do BB',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Icon(
                      LucideIcons.chevronRight,
                      color: AppColors.primary,
                      size: 17,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _PensionMetric extends StatelessWidget {
  const _PensionMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 10)),
      const SizedBox(height: 3),
      FittedBox(
        child: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        ),
      ),
    ],
  );
}

class _OverviewHeader extends StatelessWidget {
  const _OverviewHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Abrir menu',
              onPressed: () {},
              icon: const Icon(LucideIcons.menu),
            ),
            const Spacer(),
            const AppBrand(compact: true),
            const Spacer(),
            IconButton(
              tooltip: 'Notificações',
              onPressed: () {},
              icon: const Badge(child: Icon(LucideIcons.bell)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Bom dia, Gabriel 👋',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Aqui está o resumo da sua vida financeira',
                style: TextStyle(color: AppColors.muted, fontSize: 14),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(99),
                color: AppColors.surface,
              ),
              child: const Row(
                children: [
                  Icon(
                    LucideIcons.refreshCw,
                    color: AppColors.primary,
                    size: 15,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Há 5 min',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NetWorthHero extends StatelessWidget {
  const _NetWorthHero({required this.summary});

  final PortfolioSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x334F46E5),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 320;
          final total = _HeroValue(
            label: 'Patrimônio bruto',
            value: MoneyFormatter.format(summary.grossAssets),
            footer: 'Ativos consolidados',
            large: true,
          );
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SmallHeroValue(
                label: 'Patrimônio líquido',
                value: MoneyFormatter.format(summary.netWorth),
              ),
              const SizedBox(height: 14),
              _SmallHeroValue(
                label: 'Disponível agora',
                value: MoneyFormatter.format(summary.cash),
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [total, const SizedBox(height: 18), details],
            );
          }
          return Row(
            children: [
              Expanded(flex: 6, child: total),
              Container(width: 1, height: 84, color: Colors.white24),
              const SizedBox(width: 18),
              Expanded(flex: 4, child: details),
            ],
          );
        },
      ),
    );
  }
}

class _HeroValue extends StatelessWidget {
  const _HeroValue({
    required this.label,
    required this.value,
    required this.footer,
    this.large = false,
  });

  final String label;
  final String value;
  final String footer;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: large ? 30 : 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          footer,
          style: const TextStyle(color: Color(0xFFC9F7D8), fontSize: 12),
        ),
      ],
    );
  }
}

class _SmallHeroValue extends StatelessWidget {
  const _SmallHeroValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 3),
        FittedBox(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.title, required this.action});

  final String title;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ),
        TextButton(
          onPressed: () {},
          child: Row(
            children: [
              Text(action),
              const SizedBox(width: 4),
              const Icon(LucideIcons.chevronRight, size: 16),
            ],
          ),
        ),
      ],
    );
  }
}

class _AssetGrid extends StatelessWidget {
  const _AssetGrid({required this.summary});

  final PortfolioSummary summary;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        'Conta',
        MoneyFormatter.formatThousands(summary.cash),
        _formatShare(summary.shareOfGross(summary.cash)),
        LucideIcons.wallet,
        AppColors.info,
      ),
      (
        'Investimentos',
        MoneyFormatter.formatThousands(summary.investments),
        _formatShare(summary.shareOfGross(summary.investments)),
        LucideIcons.chartNoAxesColumnIncreasing,
        AppColors.success,
      ),
      (
        'Previdência',
        MoneyFormatter.formatThousands(summary.pension),
        _formatShare(summary.shareOfGross(summary.pension)),
        LucideIcons.users,
        AppColors.secondary,
      ),
      (
        'Dívidas',
        MoneyFormatter.formatThousands(summary.totalDebt, signedDebt: true),
        'Passivo',
        LucideIcons.creditCard,
        AppColors.danger,
      ),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < items.length; index++) ...[
          if (index > 0) const SizedBox(width: 7),
          Expanded(child: _AssetTile(data: items[index])),
        ],
      ],
    );
  }
}

class _AssetTile extends StatelessWidget {
  const _AssetTile({required this.data});

  final (String, String, String, IconData, Color) data;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 12),
      radius: 15,
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: data.$5.withValues(alpha: 0.11),
              shape: BoxShape.circle,
            ),
            child: Icon(data.$4, size: 19, color: data.$5),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              data.$1,
              maxLines: 1,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
            ),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              data.$2,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: data.$5 == AppColors.danger ? data.$5 : AppColors.text,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            data.$3,
            style: const TextStyle(color: AppColors.muted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _CompositionCard extends StatelessWidget {
  const _CompositionCard({required this.summary});

  final PortfolioSummary summary;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TitleRow(title: 'Composição dos ativos', action: 'Detalhes'),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 112,
                height: 112,
                child: CustomPaint(
                  painter: _DonutPainter(
                    values: [
                      summary.shareOfGross(summary.cash),
                      summary.shareOfGross(summary.investments),
                      summary.shareOfGross(summary.pension),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: [
                    _Legend(
                      color: AppColors.info,
                      label: 'Conta',
                      value: MoneyFormatter.formatWhole(summary.cash),
                      percent: _formatShare(
                        summary.shareOfGross(summary.cash),
                        decimals: 0,
                      ),
                    ),
                    _Legend(
                      color: AppColors.success,
                      label: 'Investimentos',
                      value: MoneyFormatter.formatWhole(summary.investments),
                      percent: _formatShare(
                        summary.shareOfGross(summary.investments),
                        decimals: 0,
                      ),
                    ),
                    _Legend(
                      color: AppColors.secondary,
                      label: 'PREVI',
                      value: MoneyFormatter.formatWhole(summary.pension),
                      percent: _formatShare(
                        summary.shareOfGross(summary.pension),
                        decimals: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              const Icon(
                LucideIcons.circleAlert,
                size: 16,
                color: AppColors.danger,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Passivos: ${MoneyFormatter.format(summary.totalDebt)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.label,
    required this.value,
    required this.percent,
  });

  final Color color;
  final String label;
  final String value;
  final String percent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
          ),
          const SizedBox(width: 5),
          Text(
            percent,
            style: const TextStyle(color: AppColors.muted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.values});

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.width * .23;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    const colors = [AppColors.info, AppColors.success, AppColors.secondary];
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = math.pi * 2 * values[i];
      paint.color = colors[i];
      canvas.drawArc(rect.deflate(stroke / 2), start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.values != values;
}

class _MonthlySummary extends StatelessWidget {
  const _MonthlySummary({required this.comparison});

  final MonthlyCashFlowComparison comparison;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TitleRow(title: 'Resumo de agosto', action: 'Ago/2026'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: 'Receitas',
                  value: MoneyFormatter.format(comparison.current.income),
                  color: AppColors.success,
                  change: _formatChange(comparison.incomeChange),
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: 'Despesas',
                  value: MoneyFormatter.format(comparison.current.expenses),
                  color: AppColors.danger,
                  change: _formatChange(comparison.expenseChange),
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: 'Sobra',
                  value: MoneyFormatter.format(comparison.current.balance),
                  color: AppColors.success,
                  change: _formatChange(comparison.balanceChange),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: comparison.current.expenseRatio.clamp(0.0, 1.0),
              minHeight: 9,
              color: AppColors.success,
              backgroundColor: AppColors.border,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '${(comparison.current.expenseRatio * 100).toStringAsFixed(1).replaceAll('.', ',')}% da receita comprometida',
              style: const TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.change,
  });

  final String label;
  final String value;
  final Color color;
  final String change;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 12)),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(change, style: TextStyle(color: color, fontSize: 10)),
      ],
    );
  }
}

String _formatShare(double value, {int decimals = 1}) {
  final percentage = (value * 100)
      .toStringAsFixed(decimals)
      .replaceAll('.', ',');
  return '$percentage%';
}

String _formatChange(double? value) {
  if (value == null) return 'Sem comparação';
  final arrow = value >= 0 ? '↑' : '↓';
  final percentage = (value.abs() * 100)
      .toStringAsFixed(2)
      .replaceAll('.', ',');
  return '$arrow $percentage% vs jul/26';
}

class _InsightCard extends StatelessWidget {
  const _InsightCard();

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TitleRow(title: 'Insights para você', action: 'Ver todos'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.secondary.withValues(alpha: .10),
                  AppColors.primary.withValues(alpha: .04),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  backgroundColor: Color(0x187C3AED),
                  foregroundColor: AppColors.secondary,
                  child: Icon(LucideIcons.sparkles),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Seus gastos com restaurantes aumentaram 23% em relação ao mês passado.',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
                Icon(LucideIcons.chevronRight, color: AppColors.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatCta extends StatelessWidget {
  const _ChatCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          children: [
            Icon(LucideIcons.messageCircle, color: Colors.white, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quer entender melhor seus números?',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Converse com a IA e receba insights.',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
