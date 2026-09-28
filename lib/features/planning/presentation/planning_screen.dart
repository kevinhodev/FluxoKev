import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/domain/money.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/soft_card.dart';
import '../../commitments/application/commitments_providers.dart';
import '../../document_imports/application/document_import_providers.dart';
import '../../document_imports/domain/entities/financial_documents.dart';

class PlanningScreen extends ConsumerStatefulWidget {
  const PlanningScreen({super.key});

  @override
  ConsumerState<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends ConsumerState<PlanningScreen> {
  var selected = 0;
  var selectedLoan = 0;

  @override
  Widget build(BuildContext context) {
    final loans = ref.watch(loansProvider);
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
            sliver: SliverList.list(
              children: [
                PageHeader(
                  title: 'Empréstimos & Planejamento',
                  subtitle: 'Acompanhe suas dívidas e planeje o futuro',
                  actions: [
                    IconButton(
                      onPressed: () => context.push('/imports'),
                      icon: const Icon(LucideIcons.fileUp),
                      tooltip: 'Importar PDF',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _PlanningTabs(
                  selected: selected,
                  onSelected: (value) => setState(() => selected = value),
                ),
                const SizedBox(height: 16),
                if (selected == 0)
                  loans.when(
                    loading: () => const SoftCard(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, stackTrace) => _PlanningError(
                      onRetry: () => ref.invalidate(loansProvider),
                    ),
                    data: (items) => items.isEmpty
                        ? _EmptyLoans(onImport: () => context.push('/imports'))
                        : _LoanData(
                            loans: items,
                            selectedIndex: selectedLoan.clamp(
                              0,
                              items.length - 1,
                            ),
                            onSelected: (value) =>
                                setState(() => selectedLoan = value),
                          ),
                  )
                else
                  const _PlanningComingSoon(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoanData extends StatelessWidget {
  const _LoanData({
    required this.loans,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<LoanDetails> loans;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final loan = loans[selectedIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DebtOverview(loans: loans),
        const SizedBox(height: 16),
        _LoanSelector(
          loans: loans,
          selectedIndex: selectedIndex,
          onSelected: onSelected,
        ),
        const SizedBox(height: 12),
        _LoanCard(loan: loan),
        const SizedBox(height: 16),
        _EarlySettlementCard(key: ValueKey(loan.contractNumber), loan: loan),
        const SizedBox(height: 16),
        _LoanImportSummary(loan: loan),
        const SizedBox(height: 20),
        Text(
          loan.isThirteenthSalaryAdvance
              ? 'Liquidação no 13º salário'
              : 'Próximas parcelas',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        _InstallmentsCard(items: loan.upcomingInstallments.take(3).toList()),
      ],
    );
  }
}

/// Lançamento de quitação antecipada fora do ciclo do dia do débito, como
/// acontece quando entra PLR: paga-se algumas parcelas da frente e amortiza-se
/// a cauda do contrato, que é onde o desconto é maior.
class _EarlySettlementCard extends ConsumerStatefulWidget {
  const _EarlySettlementCard({super.key, required this.loan});

  final LoanDetails loan;

  @override
  ConsumerState<_EarlySettlementCard> createState() =>
      _EarlySettlementCardState();
}

class _EarlySettlementCardState extends ConsumerState<_EarlySettlementCard> {
  late int _front = _settledFront;
  late int _back = _settledBack;
  var _saving = false;

  /// Só o que ainda não venceu é elegível: vencido já é baixado pela data.
  List<LoanInstallment> get _eligible {
    final today = DateTime.now();
    return widget.loan.installments
        .where(
          (item) =>
              item.earlySettled ||
              (item.status == LoanInstallmentStatus.open &&
                  item.dueDate.isAfter(today)),
        )
        .toList(growable: false)
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  int get _settledFront {
    var count = 0;
    for (final item in _eligible) {
      if (!item.earlySettled) break;
      count++;
    }
    return count;
  }

  int get _settledBack {
    var count = 0;
    for (final item in _eligible.reversed) {
      if (!item.earlySettled) break;
      count++;
    }
    // Contrato inteiro quitado não é frente e trás ao mesmo tempo.
    return count == _eligible.length ? 0 : count;
  }

  List<LoanInstallment> get _selection {
    final items = _eligible;
    final back = _back == 0
        ? const <LoanInstallment>[]
        : items.sublist(items.length - _back);
    return [...items.take(_front), ...back];
  }

  /// Mesma fórmula do backend: desconto pela distância até o vencimento.
  Money get _estimatedCost {
    final rate = (widget.loan.monthlyInterestRate ?? 0) / 100;
    final today = DateTime.now();
    if (rate <= 0) return _faceValue;
    var total = 0.0;
    for (final item in _selection) {
      final months =
          (item.dueDate.year - today.year) * 12 +
          (item.dueDate.month - today.month);
      total += item.amount.minorUnits / _pow(1 + rate, months < 1 ? 1 : months);
    }
    return Money(total.round());
  }

  Money get _faceValue =>
      Money(_selection.fold<int>(0, (sum, i) => sum + i.amount.minorUnits));

  static double _pow(double base, int exponent) {
    var result = 1.0;
    for (var i = 0; i < exponent; i++) {
      result *= base;
    }
    return result;
  }

  Future<void> _submit() async {
    final loanId = widget.loan.id;
    if (loanId == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(financialDocumentsApiProvider)
          .setEarlySettlement(loanId: loanId, front: _front, back: _back);
      ref.invalidate(loansProvider);
      ref.invalidate(commitmentsSummaryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _front + _back == 0
                  ? 'Quitação antecipada desfeita.'
                  : '${_front + _back} parcelas lançadas como quitadas.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível lançar: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = _eligible.length;
    final dirty = _front != _settledFront || _back != _settledBack;
    final discount = Money(
      _faceValue.minorUnits - _estimatedCost.minorUnits,
    );
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFEDEBFF),
                foregroundColor: AppColors.secondary,
                child: Icon(LucideIcons.banknoteArrowDown),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quitação antecipada',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Para pagar fora do dia 20, com PLR ou 13º.',
                      style: TextStyle(color: AppColors.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SettlementStepper(
            label: 'Da frente',
            hint: 'próximas parcelas',
            value: _front,
            max: available - _back,
            onChanged: (value) => setState(() => _front = value),
          ),
          const SizedBox(height: 8),
          _SettlementStepper(
            label: 'De trás',
            hint: 'amortiza o fim do contrato',
            value: _back,
            max: available - _front,
            onChanged: (value) => setState(() => _back = value),
          ),
          if (_front + _back > 0) ...[
            const Divider(height: 24),
            _SettlementLine(
              label: 'Valor de face',
              value: MoneyFormatter.format(_faceValue),
            ),
            const SizedBox(height: 6),
            _SettlementLine(
              label: 'Desconto estimado',
              value: '− ${MoneyFormatter.format(discount)}',
              highlight: true,
            ),
            const SizedBox(height: 6),
            _SettlementLine(
              label: 'Custo estimado',
              value: MoneyFormatter.format(_estimatedCost),
              bold: true,
            ),
            const SizedBox(height: 6),
            const Text(
              'Estimativa pela taxa do contrato. O valor do banco costuma '
              'ficar poucos reais acima.',
              style: TextStyle(color: AppColors.muted, fontSize: 10.5),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving || !dirty ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(LucideIcons.check, size: 17),
              label: Text(
                _saving
                    ? 'Lançando...'
                    : _front + _back == 0
                    ? 'Desfazer lançamento'
                    : 'Lançar ${_front + _back} parcelas',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettlementStepper extends StatelessWidget {
  const _SettlementStepper({
    required this.label,
    required this.hint,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(
              hint,
              style: const TextStyle(color: AppColors.muted, fontSize: 10.5),
            ),
          ],
        ),
      ),
      IconButton(
        onPressed: value <= 0 ? null : () => onChanged(value - 1),
        icon: const Icon(LucideIcons.circleMinus, size: 22),
      ),
      SizedBox(
        width: 28,
        child: Text(
          '$value',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      IconButton(
        onPressed: value >= max ? null : () => onChanged(value + 1),
        icon: const Icon(LucideIcons.circlePlus, size: 22),
      ),
    ],
  );
}

class _SettlementLine extends StatelessWidget {
  const _SettlementLine({
    required this.label,
    required this.value,
    this.highlight = false,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool highlight;
  final bool bold;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: const TextStyle(color: AppColors.muted, fontSize: 12),
      ),
      Text(
        value,
        style: TextStyle(
          fontSize: bold ? 15 : 13,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
          color: highlight ? Colors.green.shade700 : null,
        ),
      ),
    ],
  );
}

class _DebtOverview extends StatelessWidget {
  const _DebtOverview({required this.loans});

  final List<LoanDetails> loans;

  @override
  Widget build(BuildContext context) {
    final monthly = loans.where((loan) => !loan.isThirteenthSalaryAdvance);
    final annual = loans.where((loan) => loan.isThirteenthSalaryAdvance);
    final monthlyPayment = Money(
      monthly.fold<int>(0, (sum, loan) {
        final open = loan.upcomingInstallments;
        return sum + (open.isEmpty ? 0 : open.first.amount.minorUnits);
      }),
    );
    final thirteenthPayment = Money(
      annual.fold<int>(0, (sum, loan) {
        final open = loan.upcomingInstallments;
        return sum + (open.isEmpty ? 0 : open.first.amount.minorUnits);
      }),
    );
    // Desembolso futuro total (principal + juros que ainda vão correr).
    final remainingPayments = Money(
      loans.fold<int>(0, (sum, loan) => sum + loan.remainingPayments.minorUnits),
    );
    // Custo de quitar tudo hoje, sem os juros que deixariam de correr.
    final payoff = Money(
      loans.fold<int>(0, (sum, loan) => sum + loan.payoff.minorUnits),
    );
    final futureInterest = Money(
      remainingPayments.minorUnits - payoff.minorUnits,
    );
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.gauge, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Mapa das dívidas',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _OverviewMetric(
                  label: 'Parcelas mensais',
                  value: MoneyFormatter.format(monthlyPayment),
                  detail: '${monthly.length} contratos',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OverviewMetric(
                  label: 'Quanto eu devo',
                  value: MoneyFormatter.format(payoff),
                  detail: 'quitando hoje',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: _OverviewMetric(
              label: 'Quanto ainda vou pagar',
              value: MoneyFormatter.format(remainingPayments),
              detail:
                  '${loans.length} contratos • inclui '
                  '${MoneyFormatter.format(futureInterest)} de juros futuros',
            ),
          ),
          if (annual.isNotEmpty) ...[
            const Divider(height: 24),
            Row(
              children: [
                const Icon(
                  LucideIcons.calendarCheck2,
                  color: AppColors.secondary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${MoneyFormatter.format(thirteenthPayment)} serão liquidados pelo próprio 13º, fora da pressão mensal comum.',
                    style: const TextStyle(fontSize: 11, height: 1.4),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: .05),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 10),
        ),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          detail,
          style: const TextStyle(color: AppColors.muted, fontSize: 9),
        ),
      ],
    ),
  );
}

class _LoanSelector extends StatelessWidget {
  const _LoanSelector({
    required this.loans,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<LoanDetails> loans;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 42,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: loans.length,
      separatorBuilder: (context, index) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final loan = loans[index];
        final active = index == selectedIndex;
        final finalDigits = loan.contractNumber.length > 4
            ? loan.contractNumber.substring(loan.contractNumber.length - 4)
            : loan.contractNumber;
        return ChoiceChip(
          selected: active,
          onSelected: (_) => onSelected(index),
          avatar: Icon(
            loan.isThirteenthSalaryAdvance
                ? LucideIcons.calendarCheck2
                : loan.payrollDeducted
                ? LucideIcons.badgeDollarSign
                : LucideIcons.landmark,
            size: 15,
            color: active ? Colors.white : AppColors.primary,
          ),
          label: Text(
            loan.isThirteenthSalaryAdvance ? '13º • $finalDigits' : finalDigits,
          ),
          selectedColor: AppColors.primary,
          labelStyle: TextStyle(
            color: active ? Colors.white : AppColors.text,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
          side: BorderSide(
            color: active ? AppColors.primary : AppColors.border,
          ),
        );
      },
    ),
  );
}

class _EmptyLoans extends StatelessWidget {
  const _EmptyLoans({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) => SoftCard(
    child: Column(
      children: [
        const CircleAvatar(
          radius: 28,
          backgroundColor: Color(0xFFEDEBFF),
          foregroundColor: AppColors.primary,
          child: Icon(LucideIcons.fileUp),
        ),
        const SizedBox(height: 12),
        const Text(
          'Importe o PDF do empréstimo',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        const Text(
          'O app lê o saldo, as taxas e o cronograma antes de salvar.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 15),
        GradientButton(
          label: 'Selecionar PDF',
          icon: LucideIcons.fileUp,
          onPressed: onImport,
        ),
      ],
    ),
  );
}

class _PlanningError extends StatelessWidget {
  const _PlanningError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => SoftCard(
    child: Column(
      children: [
        const Icon(LucideIcons.circleAlert, color: AppColors.danger),
        const SizedBox(height: 8),
        const Text('Não foi possível carregar os empréstimos.'),
        TextButton(onPressed: onRetry, child: const Text('Tentar novamente')),
      ],
    ),
  );
}

class _PlanningComingSoon extends StatelessWidget {
  const _PlanningComingSoon();

  @override
  Widget build(BuildContext context) => const SoftCard(
    child: Text(
      'Esta área será conectada aos dados reais na próxima etapa.',
      textAlign: TextAlign.center,
      style: TextStyle(color: AppColors.muted),
    ),
  );
}

class _PlanningTabs extends StatelessWidget {
  const _PlanningTabs({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  static const tabs = [
    ('Empréstimos', LucideIcons.creditCard),
    ('Planejamento', LucideIcons.target),
    ('Metas', LucideIcons.flag),
  ];

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(4),
      radius: 14,
      child: Row(
        children: [
          for (var index = 0; index < tabs.length; index++)
            Expanded(
              child: InkWell(
                onTap: () => onSelected(index),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    color: index == selected
                        ? AppColors.primary.withValues(alpha: .08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border(
                      bottom: BorderSide(
                        color: index == selected
                            ? AppColors.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        tabs[index].$2,
                        size: 17,
                        color: index == selected
                            ? AppColors.primary
                            : AppColors.muted,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          tabs[index].$1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: index == selected
                                ? AppColors.primary
                                : AppColors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LoanCard extends StatelessWidget {
  const _LoanCard({required this.loan});

  final LoanDetails loan;

  @override
  Widget build(BuildContext context) {
    final nextAmount = loan.upcomingInstallments.isEmpty
        ? const Money.zero()
        : loan.upcomingInstallments.first.amount;
    final contractFinal = loan.contractNumber.length <= 4
        ? loan.contractNumber
        : loan.contractNumber.substring(loan.contractNumber.length - 4);
    return SoftCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.white24,
                  foregroundColor: Colors.white,
                  child: Icon(LucideIcons.banknote),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loan.productName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${loan.providerName} • contrato final $contractFinal',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    loan.remainingInstallments == 0
                        ? 'Quitado'
                        : loan.isThirteenthSalaryAdvance
                        ? 'Antecipação do 13º'
                        : loan.payrollDeducted
                        ? 'Desconto em folha'
                        : 'Débito mensal',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Wrap(
                  runSpacing: 18,
                  children: [
                    _LoanMetric(
                      'Quitando hoje',
                      MoneyFormatter.format(loan.payoff),
                    ),
                    _LoanMetric(
                      'Ainda a pagar',
                      MoneyFormatter.format(loan.remainingPayments),
                    ),
                    _LoanMetric(
                      loan.isThirteenthSalaryAdvance
                          ? 'Liquidação prevista'
                          : 'Próxima parcela',
                      MoneyFormatter.format(nextAmount),
                    ),
                    _LoanMetric(
                      'Taxa de juros',
                      _formatPercent(loan.monthlyInterestRate, 'a.m.'),
                    ),
                    _LoanMetric(
                      'CET',
                      _formatPercent(loan.annualEffectiveCost, 'a.a.'),
                    ),
                    _LoanMetric(
                      'Início',
                      DateFormat('dd/MM/yyyy').format(loan.contractDate),
                    ),
                    _LoanMetric(
                      'Término das abertas',
                      loan.projectedEndDate == null
                          ? '—'
                          : DateFormat(
                              'dd/MM/yyyy',
                            ).format(loan.projectedEndDate!),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Progresso do pagamento',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${loan.paidInstallments} de ${loan.totalInstallments} liquidadas',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: loan.progress,
                    minHeight: 12,
                    color: AppColors.primary,
                    backgroundColor: AppColors.border,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Text(
                      '${loan.paidInstallments} pagas',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${loan.remainingInstallments} restantes',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoanMetric extends StatelessWidget {
  const _LoanMetric(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _LoanImportSummary extends StatelessWidget {
  const _LoanImportSummary({required this.loan});

  final LoanDetails loan;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.success.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.success.withValues(alpha: .16)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(LucideIcons.fileCheck2, color: AppColors.success),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cronograma conferido pelo PDF',
                style: TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                loan.isThirteenthSalaryAdvance
                    ? 'Pagamento único vinculado ao recebimento do 13º salário. Ele fica separado do comprometimento mensal recorrente.'
                    : '${loan.amortizedInstallments} parcelas finais já foram amortizadas. O término considera somente as ${loan.remainingInstallments} parcelas abertas.',
                style: const TextStyle(fontSize: 11, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// Kept for the next planning iteration, but never shown with placeholder data.
// ignore: unused_element
class _SimulationCard extends StatelessWidget {
  const _SimulationCard();

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Simular amortização',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Veja como uma amortização pode reduzir juros e prazo.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: _SimulationValue(
                    'Amortização',
                    'R\$ 2.000,00',
                    AppColors.text,
                  ),
                ),
                Icon(LucideIcons.arrowRight, color: AppColors.primary),
                Expanded(
                  child: _SimulationValue(
                    'Economia',
                    'R\$ 3.742,18',
                    AppColors.success,
                  ),
                ),
                Expanded(
                  child: _SimulationValue(
                    'Prazo',
                    '6 meses',
                    AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GradientButton(
            label: 'Ver simulação detalhada',
            icon: LucideIcons.calculator,
            expand: true,
            onPressed: _noop,
          ),
        ],
      ),
    );
  }
}

void _noop() {}

String _formatPercent(double? value, String period) => value == null
    ? '—'
    : '${value.toStringAsFixed(2).replaceAll('.', ',')}% $period';

class _SimulationValue extends StatelessWidget {
  const _SimulationValue(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted, fontSize: 9),
        ),
        const SizedBox(height: 6),
        FittedBox(
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _InstallmentsCard extends StatelessWidget {
  const _InstallmentsCard({required this.items});

  final List<LoanInstallment> items;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          for (final item in items) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '${item.dueDate.day.toString().padLeft(2, '0')}\n${_monthAbbreviation(item.dueDate.month)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Parcela ${item.number}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'Vencimento: ${DateFormat('dd/MM/yyyy').format(item.dueDate)}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    MoneyFormatter.format(item.amount),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      'Pendente',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w700,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
          ],
        ],
      ),
    );
  }
}

String _monthAbbreviation(int month) => const [
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
][month - 1];

// ignore: unused_element
class _StrategyCard extends StatelessWidget {
  const _StrategyCard();

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: const Color(0xFFF1FBF5),
      borderColor: const Color(0xFFCDF2DC),
      child: Row(
        children: [
          const Icon(LucideIcons.sparkles, color: AppColors.success),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estratégia calculada',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Pelos cenários atuais, amortizar R\$ 2.000 agora reduz mais juros do que investir esse valor.',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          TextButton(onPressed: () {}, child: const Text('Entenda')),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _QuickTools extends StatelessWidget {
  const _QuickTools();

  static const items = [
    ('Amortização', LucideIcons.calculator),
    ('Investir vs. amortizar', LucideIcons.scale),
    ('Calendário', LucideIcons.calendarDays),
    ('Extrato', LucideIcons.fileText),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          if (index > 0) const SizedBox(width: 7),
          Expanded(
            child: SoftCard(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 13),
              radius: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(items[index].$2, color: AppColors.primary, size: 21),
                  const SizedBox(height: 8),
                  Text(
                    items[index].$1,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
