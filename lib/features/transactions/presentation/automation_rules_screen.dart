import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/formatters/money_formatter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/soft_card.dart';
import '../application/transaction_providers.dart';
import 'merchant_alias_sheet.dart';

/// Regras que renomeiam descritores de cartão para um nome único.
///
/// Cada regra casa por prefixo, e a tela mostra quais descritores brutos ela
/// engoliu — sem isso não dá para saber se um prefixo curto demais está
/// juntando estabelecimentos diferentes.
class AutomationRulesScreen extends ConsumerWidget {
  const AutomationRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(merchantAliasesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Regras automáticas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final criada = await showMerchantAliasSheet(context);
          if (criada == true) ref.invalidate(merchantAliasesProvider);
        },
        icon: const Icon(LucideIcons.plus),
        label: const Text('Nova regra'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(merchantAliasesProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 90),
            children: [
              const PageHeader(
                title: 'Nomes de estabelecimento',
                subtitle:
                    'A operadora emite o mesmo lugar sob descritores diferentes. '
                    'Cada regra junta as variações sob um nome só.',
              ),
              const SizedBox(height: 18),
              rules.when(
                loading: () => const SoftCard(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => SoftCard(
                  child: Text('Não foi possível carregar: $error'),
                ),
                data: (items) => items.isEmpty
                    ? const _EmptyState()
                    : Column(
                        children: [
                          for (final rule in items) ...[
                            _RuleCard(
                              rule: rule,
                              onEdit: () async {
                                final salva = await showMerchantAliasSheet(
                                  context,
                                  existing: rule,
                                );
                                if (salva == true) {
                                  ref.invalidate(merchantAliasesProvider);
                                }
                              },
                              onRemove: () async {
                                await ref
                                    .read(merchantAliasesApiProvider)
                                    .remove(rule.id);
                                ref.invalidate(merchantAliasesProvider);
                              },
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const SoftCard(
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: 22),
      child: Column(
        children: [
          Icon(LucideIcons.bot, color: AppColors.muted, size: 28),
          SizedBox(height: 10),
          Text(
            'Nenhuma regra ainda',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 6),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Crie pelo botão abaixo, ou segure uma transação no extrato '
              'para partir do descritor dela.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
        ],
      ),
    ),
  );
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.rule,
    required this.onEdit,
    required this.onRemove,
  });

  final MerchantAlias rule;
  final Future<void> Function() onEdit;
  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context) => SoftCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '"${rule.pattern}"',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          LucideIcons.arrowRight,
                          size: 14,
                          color: AppColors.muted,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          rule.merchantName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${rule.matches} transações • ${MoneyFormatter.format(rule.total)}',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  if (rule.categoryId != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.tag,
                          size: 12,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'categoria fixada em ${rule.categoryId}',
                          style: const TextStyle(
                            color: AppColors.secondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Editar regra',
              onPressed: onEdit,
              icon: const Icon(LucideIcons.pencil, size: 17),
            ),
            IconButton(
              tooltip: 'Excluir regra',
              onPressed: () async {
                final confirmar = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Excluir regra?'),
                    content: Text(
                      'As ${rule.matches} transações voltam a aparecer com o '
                      'descritor original da operadora. Nenhum lançamento é '
                      'apagado.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: const Text('Excluir'),
                      ),
                    ],
                  ),
                );
                if (confirmar == true) await onRemove();
              },
              icon: const Icon(LucideIcons.trash2, size: 18),
            ),
          ],
        ),
        if (rule.descriptors.isNotEmpty) ...[
          const Divider(height: 20),
          Text(
            'Substitui ${rule.descriptors.length} '
            '${rule.descriptors.length == 1 ? "descritor" : "descritores"}:',
            style: const TextStyle(color: AppColors.muted, fontSize: 10.5),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final descriptor in rule.descriptors)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: .06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    descriptor,
                    style: const TextStyle(fontSize: 10, height: 1.3),
                  ),
                ),
            ],
          ),
        ],
      ],
    ),
  );
}
