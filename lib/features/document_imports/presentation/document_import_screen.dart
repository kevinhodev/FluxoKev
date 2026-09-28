import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/formatters/money_formatter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/soft_card.dart';
import '../../overview/application/financial_dashboard_provider.dart';
import '../application/document_import_providers.dart';
import '../domain/entities/financial_documents.dart';

class DocumentImportScreen extends ConsumerStatefulWidget {
  const DocumentImportScreen({super.key});

  @override
  ConsumerState<DocumentImportScreen> createState() =>
      _DocumentImportScreenState();
}

class _DocumentImportScreenState extends ConsumerState<DocumentImportScreen> {
  bool _busy = false;
  String? _error;
  String? _fileName;
  Uint8List? _bytes;
  FinancialDocumentKind? _kind;
  FinancialDocumentPreview? _preview;

  Future<void> _pick(FinancialDocumentKind kind) async {
    const pdfType = XTypeGroup(label: 'PDF', extensions: ['pdf']);
    final file = await openFile(acceptedTypeGroups: const [pdfType]);
    if (file == null) return;
    Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      setState(() => _error = 'Não foi possível ler o arquivo escolhido.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _preview = null;
      _kind = kind;
      _fileName = file.name;
      _bytes = bytes;
    });
    try {
      final preview = await ref
          .read(financialDocumentsApiProvider)
          .preview(kind: kind, fileName: file.name, bytes: bytes);
      if (mounted) setState(() => _preview = preview);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    final kind = _kind;
    final fileName = _fileName;
    final bytes = _bytes;
    if (kind == null || fileName == null || bytes == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(financialDocumentsApiProvider)
          .importDocument(kind: kind, fileName: fileName, bytes: bytes);
      ref.invalidate(loansProvider);
      ref.invalidate(payrollSummaryProvider);
      ref.invalidate(pensionsProvider);
      ref.invalidate(financialDashboardProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kind == FinancialDocumentKind.loan
                ? 'Empréstimo importado com sucesso.'
                : 'PREVI importada com sucesso.',
          ),
        ),
      );
      setState(() {
        _preview = null;
        _bytes = null;
        _fileName = null;
        _kind = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
              sliver: SliverList.list(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: context.pop,
                        icon: const Icon(LucideIcons.arrowLeft),
                        tooltip: 'Voltar',
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Importar PDFs',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Text(
                      'Confira a prévia antes de adicionar os dados ao app.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _ImportOption(
                    title: 'Empréstimo do BB',
                    subtitle:
                        'Lê saldo, taxas, amortizações e todas as parcelas.',
                    icon: LucideIcons.landmark,
                    color: AppColors.primary,
                    onTap: _busy
                        ? null
                        : () => _pick(FinancialDocumentKind.loan),
                  ),
                  const SizedBox(height: 12),
                  _ImportOption(
                    title: 'Extrato da PREVI',
                    subtitle:
                        'Lê saldo, reservas, rentabilidade e histórico mensal.',
                    icon: LucideIcons.chartNoAxesCombined,
                    color: AppColors.success,
                    onTap: _busy
                        ? null
                        : () => _pick(FinancialDocumentKind.pension),
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 22),
                    const SoftCard(
                      child: Row(
                        children: [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Lendo e conferindo o documento...',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _ErrorCard(message: _error!),
                  ],
                  if (_preview != null && !_busy) ...[
                    const SizedBox(height: 20),
                    _PreviewCard(preview: _preview!),
                    const SizedBox(height: 14),
                    GradientButton(
                      label: 'Confirmar importação',
                      icon: LucideIcons.fileCheck2,
                      expand: true,
                      onPressed: _confirm,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportOption extends StatelessWidget {
  const _ImportOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SoftCard(
    padding: EdgeInsets.zero,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.fileUp, color: AppColors.primary),
          ],
        ),
      ),
    ),
  );
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preview});

  final FinancialDocumentPreview preview;

  @override
  Widget build(BuildContext context) {
    final loan = preview.loan;
    final pension = preview.pension;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.scanSearch, color: AppColors.primary),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'Prévia reconhecida',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              const _VerifiedBadge(),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            preview.fileName,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
          const Divider(height: 24),
          if (loan != null) ...[
            _PreviewMetric('Produto', loan.productName),
            _PreviewMetric(
              'Valor contratado',
              MoneyFormatter.format(loan.currentBalance),
            ),
            _PreviewMetric(
              'Quitando hoje',
              MoneyFormatter.format(loan.payoff),
            ),
            _PreviewMetric(
              'Parcelas',
              '${loan.remainingInstallments} abertas de ${loan.totalInstallments}',
            ),
            _PreviewMetric(
              'Amortizadas',
              '${loan.amortizedInstallments} parcelas finais',
            ),
            _PreviewMetric(
              'Próximo vencimento',
              loan.nextDueDate == null
                  ? 'Não encontrado'
                  : DateFormat('dd/MM/yyyy').format(loan.nextDueDate!),
            ),
            _PreviewMetric(
              'Término das abertas',
              loan.projectedEndDate == null
                  ? 'Não encontrado'
                  : DateFormat('dd/MM/yyyy').format(loan.projectedEndDate!),
            ),
          ],
          if (pension != null) ...[
            _PreviewMetric(
              'Plano',
              '${pension.providerName} • ${pension.profileName}',
            ),
            _PreviewMetric(
              'Saldo total',
              MoneyFormatter.format(pension.currentBalance),
            ),
            _PreviewMetric(
              'Reserva pessoal',
              MoneyFormatter.format(pension.participantReserve),
            ),
            _PreviewMetric(
              'Reserva patronal',
              MoneyFormatter.format(pension.employerReserve),
            ),
            _PreviewMetric(
              'Rentabilidade em 12 meses',
              pension.twelveMonthReturn == null
                  ? 'Não encontrada'
                  : '${pension.twelveMonthReturn!.toStringAsFixed(2).replaceAll('.', ',')}%',
            ),
            _PreviewMetric(
              'Histórico',
              '${pension.history.length} meses reconhecidos',
            ),
          ],
          if (preview.warnings.isNotEmpty) ...[
            const Divider(height: 24),
            for (final warning in preview.warnings)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  warning,
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _PreviewMetric extends StatelessWidget {
  const _PreviewMetric(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 126,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.success.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(99),
    ),
    child: const Text(
      'Conferido',
      style: TextStyle(
        color: AppColors.success,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.danger.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.danger.withValues(alpha: .18)),
    ),
    child: Row(
      children: [
        const Icon(LucideIcons.circleAlert, color: AppColors.danger),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: AppColors.danger, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}
