import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/domain/money.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/soft_card.dart';
import '../../document_imports/application/document_import_providers.dart';
import '../../document_imports/domain/entities/financial_documents.dart';
import '../../overview/application/financial_dashboard_provider.dart';

class PensionProjectionScreen extends ConsumerStatefulWidget {
  const PensionProjectionScreen({required this.pensionId, super.key});

  final String pensionId;

  @override
  ConsumerState<PensionProjectionScreen> createState() =>
      _PensionProjectionScreenState();
}

class _PensionProjectionScreenState
    extends ConsumerState<PensionProjectionScreen> {
  final _accumulatedReturnController = TextEditingController();
  var _initializedReturn = false;
  var _saving = false;
  var _selectedTab = 0;
  var _historyPage = 0;

  @override
  void dispose() {
    _accumulatedReturnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projection = ref.watch(pensionProjectionProvider(widget.pensionId));
    final pensions = ref.watch(pensionsProvider);
    final pension = pensions.asData?.value
        .where((item) => item.id == widget.pensionId)
        .firstOrNull;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: projection.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _ProjectionError(
            onRetry: () =>
                ref.invalidate(pensionProjectionProvider(widget.pensionId)),
          ),
          data: (data) {
            _initializeReturn(data);
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  sliver: SliverList.list(
                    children: [
                      _Header(onBack: context.pop),
                      const SizedBox(height: 20),
                      Text(
                        'Sua saída do BB',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                            ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        pension?.profileName ?? 'PREVI Futuro',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _PensionTabs(
                        selected: _selectedTab,
                        onSelected: (value) => setState(() {
                          _selectedTab = value;
                          _historyPage = 0;
                        }),
                      ),
                      const SizedBox(height: 16),
                      if (_selectedTab == 0) ...[
                        _CurrentRescueHero(projection: data),
                        const SizedBox(height: 14),
                        _ReturnInputCard(
                          accumulatedReturnController:
                              _accumulatedReturnController,
                          month: DateTime.now(),
                          saving: _saving,
                          onSave: () => _saveReturn(data),
                          snapshot: data.latestSnapshot,
                          onToggleContribution: () =>
                              _toggleContribution(data),
                        ),
                        const SizedBox(height: 18),
                        _AssumptionsCard(projection: data),
                        const SizedBox(height: 22),
                        const Text(
                          'Quanto você teria por ano',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Saldo acumulado da Parte II e resgate bruto se você saísse do BB naquele ano.',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _AnnualProjectionCard(points: data.points),
                        const SizedBox(height: 14),
                        _RulesCard(projection: data),
                      ] else if (pension != null)
                        _PensionHistoryTab(
                          pension: pension,
                          projection: data,
                          page: _historyPage,
                          onPageChanged: (value) =>
                              setState(() => _historyPage = value),
                        )
                      else
                        const SoftCard(
                          child: Center(child: CircularProgressIndicator()),
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

  void _initializeReturn(PensionProjection projection) {
    if (_initializedReturn) return;
    _initializedReturn = true;
    final snapshot = projection.latestSnapshot;
    final now = DateTime.now();
    if (snapshot != null &&
        snapshot.referenceMonth.year == now.year &&
        snapshot.referenceMonth.month == now.month) {
      _accumulatedReturnController.text = _moneyInput(
        snapshot.accumulatedReturn,
      );
    }
  }

  Future<void> _saveReturn(PensionProjection projection) async {
    final accumulatedReturn = _tryParseMoney(_accumulatedReturnController.text);
    if (accumulatedReturn == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o rendimento acumulado do mês.')),
      );
      return;
    }
    // Salvar o rendimento não pode desfazer uma contribuição já lançada.
    await _persistSnapshot(
      projection,
      accumulatedReturn: accumulatedReturn,
      contributionApplied:
          projection.latestSnapshot?.contributionApplied ?? false,
      message: 'Projeção recalculada.',
    );
  }

  Future<void> _toggleContribution(PensionProjection projection) async {
    final snapshot = projection.latestSnapshot;
    if (snapshot == null) return;
    final applying = !snapshot.contributionApplied;
    await _persistSnapshot(
      projection,
      // O campo pode ter edição não salva; ela prevalece sobre o valor gravado.
      accumulatedReturn:
          _tryParseMoney(_accumulatedReturnController.text) ??
          snapshot.accumulatedReturn,
      contributionApplied: applying,
      message: applying
          ? 'Contribuição lançada sobre a posição da PREVI.'
          : 'Contribuição removida.',
    );
  }

  Future<void> _persistSnapshot(
    PensionProjection projection, {
    required Money accumulatedReturn,
    required bool contributionApplied,
    required String message,
  }) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(financialDocumentsApiProvider)
          .saveMonthlySnapshot(
            pensionId: projection.pensionId,
            asOfDate: DateTime.now(),
            accumulatedReturn: accumulatedReturn,
            contributionApplied: contributionApplied,
          );
      ref.invalidate(pensionProjectionProvider(widget.pensionId));
      ref.invalidate(pensionsProvider);
      ref.invalidate(financialDashboardProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível salvar: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _PensionTabs extends StatelessWidget {
  const _PensionTabs({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      children: [
        Expanded(
          child: _PensionTabButton(
            label: 'Projeção',
            icon: LucideIcons.chartSpline,
            selected: selected == 0,
            onTap: () => onSelected(0),
          ),
        ),
        Expanded(
          child: _PensionTabButton(
            label: 'Histórico',
            icon: LucideIcons.history,
            selected: selected == 1,
            onTap: () => onSelected(1),
          ),
        ),
      ],
    ),
  );
}

class _PensionTabButton extends StatelessWidget {
  const _PensionTabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(11),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 17,
            color: selected ? Colors.white : AppColors.muted,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.muted,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    ),
  );
}

class _PensionHistoryTab extends StatelessWidget {
  const _PensionHistoryTab({
    required this.pension,
    required this.projection,
    required this.page,
    required this.onPageChanged,
  });

  static const pageSize = 12;

  final PensionDetails pension;
  final PensionProjection projection;
  final int page;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final items = pension.history
        .map(
          (item) => _PensionHistoryItem(
            month: item.referenceMonth,
            returns: item.returns,
            balance: item.closingBalance,
            partial: false,
          ),
        )
        .toList();
    final snapshot = projection.latestSnapshot;
    if (snapshot != null) {
      items.removeWhere(
        (item) =>
            item.month.year == snapshot.referenceMonth.year &&
            item.month.month == snapshot.referenceMonth.month,
      );
      items.add(
        _PensionHistoryItem(
          month: snapshot.referenceMonth,
          returns: snapshot.accumulatedReturn,
          balance: snapshot.closingBalance,
          partial: true,
        ),
      );
    }
    items.sort((a, b) => b.month.compareTo(a.month));
    final pageCount = math.max(1, (items.length / pageSize).ceil());
    final safePage = page.clamp(0, pageCount - 1);
    final visible = items
        .skip(safePage * pageSize)
        .take(pageSize)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Evolução do saldo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Página ${safePage + 1} de $pageCount • ${visible.length} meses',
                style: const TextStyle(color: AppColors.muted, fontSize: 10),
              ),
              const SizedBox(height: 14),
              _BalanceChart(items: visible.reversed.toList(growable: false)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SoftCard(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
          child: Column(
            children: [
              const Row(
                children: [
                  Expanded(
                    child: Text(
                      'Mês',
                      style: TextStyle(color: AppColors.muted, fontSize: 10),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Rendimento',
                      textAlign: TextAlign.right,
                      style: TextStyle(color: AppColors.muted, fontSize: 10),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Saldo',
                      textAlign: TextAlign.right,
                      style: TextStyle(color: AppColors.muted, fontSize: 10),
                    ),
                  ),
                ],
              ),
              const Divider(height: 18),
              for (var index = 0; index < visible.length; index++) ...[
                _HistoryRow(item: visible[index]),
                if (index != visible.length - 1) const Divider(height: 16),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: safePage > 0
                    ? () => onPageChanged(safePage - 1)
                    : null,
                icon: const Icon(LucideIcons.chevronLeft, size: 16),
                label: const Text('Anterior'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: safePage < pageCount - 1
                    ? () => onPageChanged(safePage + 1)
                    : null,
                iconAlignment: IconAlignment.end,
                icon: const Icon(LucideIcons.chevronRight, size: 16),
                label: const Text('Próxima'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PensionHistoryItem {
  const _PensionHistoryItem({
    required this.month,
    required this.returns,
    required this.balance,
    required this.partial,
  });

  final DateTime month;
  final Money returns;
  final Money balance;
  final bool partial;
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.item});

  final _PensionHistoryItem item;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Row(
          children: [
            Text(
              '${_monthShort(item.month.month)}/${item.month.year}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
            ),
            if (item.partial) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Text(
                  'parcial',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontSize: 7,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      Expanded(
        child: Text(
          MoneyFormatter.format(item.returns),
          textAlign: TextAlign.right,
          style: TextStyle(
            color: item.returns.isNegative
                ? AppColors.danger
                : AppColors.success,
            fontWeight: FontWeight.w700,
            fontSize: 10,
          ),
        ),
      ),
      Expanded(
        child: Text(
          MoneyFormatter.format(item.balance),
          textAlign: TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 10),
        ),
      ),
    ],
  );
}

class _BalanceChart extends StatelessWidget {
  const _BalanceChart({required this.items});

  final List<_PensionHistoryItem> items;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 170,
        child: LayoutBuilder(
          builder: (context, constraints) => CustomPaint(
            size: Size(constraints.maxWidth, 170),
            painter: _BalanceChartPainter(
              values: items.map((item) => item.balance.minorUnits).toList(),
            ),
          ),
        ),
      ),
      if (items.isNotEmpty)
        Row(
          children: [
            Text(
              '${_monthShort(items.first.month.month)}/${items.first.month.year}',
              style: const TextStyle(color: AppColors.muted, fontSize: 9),
            ),
            const Spacer(),
            Text(
              '${_monthShort(items.last.month.month)}/${items.last.month.year}',
              style: const TextStyle(color: AppColors.muted, fontSize: 9),
            ),
          ],
        ),
    ],
  );
}

class _BalanceChartPainter extends CustomPainter {
  const _BalanceChartPainter({required this.values});

  final List<int> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const top = 12.0;
    final bottom = size.height - 10;
    final minValue = values.reduce(math.min).toDouble();
    final maxValue = values.reduce(math.max).toDouble();
    final range = math.max(1, maxValue - minValue);
    final gridPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (var index = 0; index < 4; index++) {
      final y = top + (bottom - top) * index / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    Offset pointAt(int index) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * index / (values.length - 1);
      final normalized = (values[index] - minValue) / range;
      return Offset(x, bottom - normalized * (bottom - top));
    }

    final line = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var index = 1; index < values.length; index++) {
      final point = pointAt(index);
      line.lineTo(point.dx, point.dy);
    }
    final fill = Path.from(line)
      ..lineTo(pointAt(values.length - 1).dx, bottom)
      ..lineTo(pointAt(0).dx, bottom)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x334F46E5), Color(0x004F46E5)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = AppColors.primary
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final pointPaint = Paint()..color = AppColors.primary;
    for (var index = 0; index < values.length; index++) {
      canvas.drawCircle(pointAt(index), 3.2, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BalanceChartPainter oldDelegate) =>
      oldDelegate.values != values;
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton.filledTonal(
        onPressed: onBack,
        icon: const Icon(LucideIcons.arrowLeft),
      ),
      const SizedBox(width: 10),
      const Expanded(
        child: Text(
          'Planejamento PREVI',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      const Icon(LucideIcons.shieldCheck, color: AppColors.primary),
    ],
  );
}

class _CurrentRescueHero extends StatelessWidget {
  const _CurrentRescueHero({required this.projection});

  final PensionProjection projection;

  @override
  Widget build(BuildContext context) => Container(
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
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Resgate bruto estimado hoje',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 7),
        FittedBox(
          child: Text(
            MoneyFormatter.format(projection.currentGrossWithdrawable),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
        ),
        if (projection.latestSnapshot case final snapshot?) ...[
          const SizedBox(height: 8),
          Text(
            'Posição parcial em ${snapshot.asOfDate.day.toString().padLeft(2, '0')}/${snapshot.asOfDate.month.toString().padLeft(2, '0')} • rendimento ${MoneyFormatter.format(snapshot.accumulatedReturn)}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _HeroMetric(
                label: 'Saldo Parte II',
                value: MoneyFormatter.format(projection.currentPartTwoBalance),
              ),
            ),
            Container(width: 1, height: 38, color: Colors.white24),
            const SizedBox(width: 16),
            Expanded(
              child: _HeroMetric(
                label: 'Parte patronal liberada',
                value: '${_percent(projection.currentEmployerEligibleRate)}%',
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .13),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                LucideIcons.calendarClock,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${projection.currentContributionCount} contribuições • regra atual: 10% + 3,5 p.p. por ano completo',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      const SizedBox(height: 4),
      FittedBox(
        child: Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ],
  );
}

class _ReturnInputCard extends StatelessWidget {
  const _ReturnInputCard({
    required this.accumulatedReturnController,
    required this.month,
    required this.saving,
    required this.onSave,
    required this.snapshot,
    required this.onToggleContribution,
  });

  final TextEditingController accumulatedReturnController;
  final DateTime month;
  final bool saving;
  final VoidCallback onSave;
  final PensionMonthlySnapshot? snapshot;
  final VoidCallback onToggleContribution;

  @override
  Widget build(BuildContext context) => SoftCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFEDEBFF),
              foregroundColor: AppColors.secondary,
              child: Icon(LucideIcons.chartSpline),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Posição parcial de ${_monthName(month.month)}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const Text(
                    'O saldo fica fiel à PREVI; a contribuição você lança.',
                    style: TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: accumulatedReturnController,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          decoration: const InputDecoration(
            labelText: 'Rendimento acumulado no mês',
            hintText: 'Ex.: -182,90',
            prefixText: r'R$ ',
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: saving ? null : onSave,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(LucideIcons.refreshCw, size: 17),
            label: Text(saving ? 'Atualizando...' : 'Atualizar projeção'),
          ),
        ),
        // A PREVI demora a creditar a contribuição já descontada em folha.
        // O lançamento é manual para o saldo nunca divergir da fonte sozinho.
        if (snapshot case final snap?
            when snap.projectedContribution.minorUnits > 0) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: saving ? null : onToggleContribution,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: Icon(
                snap.contributionApplied
                    ? LucideIcons.undo2
                    : LucideIcons.circlePlus,
                size: 17,
              ),
              label: Text(
                snap.contributionApplied
                    ? 'Remover contribuição de '
                          '${MoneyFormatter.format(snap.projectedContribution)}'
                    : 'Lançar contribuição de '
                          '${MoneyFormatter.format(snap.projectedContribution)}',
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            snap.contributionApplied
                ? 'Contribuição somada por cima da posição da PREVI.'
                : 'Mediana das suas últimas contribuições. Lance quando o '
                      'desconto já tiver saído do salário.',
            style: const TextStyle(color: AppColors.muted, fontSize: 10.5),
          ),
        ],
      ],
    ),
  );
}

class _AssumptionsCard extends StatelessWidget {
  const _AssumptionsCard({required this.projection});

  final PensionProjection projection;

  @override
  Widget build(BuildContext context) => SoftCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Premissas calculadas do histórico',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 13),
        Row(
          children: [
            Expanded(
              child: _Assumption(
                label: 'Retorno médio',
                value: '${_percent(projection.monthlyReturnRateUsed)}% a.m.',
              ),
            ),
            Expanded(
              child: _Assumption(
                label: 'Equivalente anual',
                value: '${_percent(projection.annualizedReturnRate)}% a.a.',
              ),
            ),
          ],
        ),
        const Divider(height: 22),
        Row(
          children: [
            Expanded(
              child: _Assumption(
                label: 'Sua contribuição',
                value: MoneyFormatter.format(
                  projection.averageParticipantContribution,
                ),
              ),
            ),
            Expanded(
              child: _Assumption(
                label: 'Contribuição do BB',
                value: MoneyFormatter.format(
                  projection.averageEmployerContribution,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Assumption extends StatelessWidget {
  const _Assumption({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 10)),
      const SizedBox(height: 4),
      FittedBox(
        child: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
      ),
    ],
  );
}

class _AnnualProjectionCard extends StatelessWidget {
  const _AnnualProjectionCard({required this.points});

  final List<PensionProjectionPoint> points;

  @override
  Widget build(BuildContext context) {
    final maxValue = points.fold<int>(
      1,
      (value, item) => math.max(value, item.projectedBalance.minorUnits),
    );
    return SoftCard(
      child: Column(
        children: [
          const Row(
            children: [
              _LegendDot(color: AppColors.primary, label: 'Saldo'),
              SizedBox(width: 15),
              _LegendDot(color: AppColors.success, label: 'Resgate bruto'),
            ],
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < points.length; index++) ...[
            _ProjectionYearRow(point: points[index], maxValue: maxValue),
            if (index != points.length - 1) const Divider(height: 20),
          ],
        ],
      ),
    );
  }
}

class _ProjectionYearRow extends StatelessWidget {
  const _ProjectionYearRow({required this.point, required this.maxValue});

  final PensionProjectionPoint point;
  final int maxValue;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          SizedBox(
            width: 46,
            child: Text(
              '${point.year}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: Text(
              MoneyFormatter.format(point.projectedBalance),
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              MoneyFormatter.format(point.grossWithdrawable),
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            Container(
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Container(
              width:
                  constraints.maxWidth *
                  point.projectedBalance.minorUnits /
                  maxValue,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: .28),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Container(
              width:
                  constraints.maxWidth *
                  point.grossWithdrawable.minorUnits /
                  maxValue,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 6),
      Text(
        '${_percent(point.employerEligibleRate)}% da parte patronal • ${point.projectedContributionCount} contribuições',
        style: const TextStyle(color: AppColors.muted, fontSize: 9),
      ),
    ],
  );
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 10)),
    ],
  );
}

class _RulesCard extends StatelessWidget {
  const _RulesCard({required this.projection});

  final PensionProjection projection;

  @override
  Widget build(BuildContext context) => SoftCard(
    color: const Color(0xFFF0FDF4),
    borderColor: const Color(0xFFBBF7D0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(LucideIcons.info, color: AppColors.success, size: 19),
            SizedBox(width: 8),
            Text(
              'Como esta estimativa funciona',
              style: TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final notice in projection.notices)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '• $notice',
              style: const TextStyle(fontSize: 11, height: 1.4),
            ),
          ),
        Text(
          'Parte I registrada no extrato: ${MoneyFormatter.format(projection.partOneBalance)}.',
          style: const TextStyle(color: AppColors.muted, fontSize: 10),
        ),
      ],
    ),
  );
}

class _ProjectionError extends StatelessWidget {
  const _ProjectionError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: SoftCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.circleAlert, color: AppColors.danger),
            const SizedBox(height: 9),
            const Text('Não foi possível carregar a projeção.'),
            TextButton(
              onPressed: onRetry,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    ),
  );
}

String _percent(double value) =>
    value.toStringAsFixed(value % 1 == 0 ? 0 : 2).replaceAll('.', ',');

Money? _tryParseMoney(String input) {
  var normalized = input.trim().replaceAll(RegExp(r'[^0-9,.-]'), '');
  if (normalized.isEmpty || normalized == '-') return null;
  if (normalized.contains(',')) {
    normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
  } else if ('.'.allMatches(normalized).length > 1) {
    normalized = normalized.replaceAll('.', '');
  }
  final value = double.tryParse(normalized);
  if (value == null || !value.isFinite) return null;
  return Money((value * 100).round());
}

String _moneyInput(Money money) {
  final absolute = money.minorUnits.abs();
  final whole = absolute ~/ 100;
  final cents = (absolute % 100).toString().padLeft(2, '0');
  final sign = money.isNegative ? '-' : '';
  return '$sign$whole,$cents';
}

String _monthName(int month) => const [
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
][month - 1];

String _monthShort(int month) => const [
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
