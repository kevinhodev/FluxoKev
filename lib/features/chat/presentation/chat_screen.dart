import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/soft_card.dart';
import '../application/chat_controller.dart';
import '../data/insights_api.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    _input.clear();
    await ref.read(chatControllerProvider.notifier).send(text);
    if (!mounted || !_scroll.hasClients) return;
    // Depois da resposta, levar o usuário ao fim da conversa.
    await _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider);
    final vazio = state.turns.isEmpty;

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              controller: _scroll,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  sliver: SliverList.list(
                    children: [
                      PageHeader(
                        title: 'Chat com IA',
                        subtitle:
                            'Converse sobre suas finanças e receba insights personalizados',
                        actions: [
                          if (!vazio)
                            IconButton(
                              tooltip: 'Limpar conversa',
                              onPressed: state.sending
                                  ? null
                                  : () => ref
                                        .read(chatControllerProvider.notifier)
                                        .clear(),
                              icon: const Icon(
                                LucideIcons.eraser,
                                color: AppColors.muted,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (vazio) ...[
                        _QuickActions(
                          onPick: state.sending ? null : _send,
                        ),
                        const SizedBox(height: 22),
                        const _EmptyHint(),
                      ] else
                        for (final turn in state.turns) ...[
                          turn.isUser
                              ? _UserBubble(text: turn.content)
                              : _AssistantBubble(turn: turn),
                          const SizedBox(height: 16),
                        ],
                      if (state.sending) ...[
                        const _Thinking(),
                        const SizedBox(height: 16),
                      ],
                      if (state.error case final erro?) ...[
                        _ErrorCard(
                          message: erro,
                          onRetry: () {
                            final ultima = state.turns.isNotEmpty &&
                                    state.turns.last.isUser
                                ? state.turns.last.content
                                : null;
                            ref
                                .read(chatControllerProvider.notifier)
                                .discardLastQuestion();
                            if (ultima != null) _send(ultima);
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (state.totalCostUsd > 0)
                        _CostFooter(totalUsd: state.totalCostUsd),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _ChatComposer(
            controller: _input,
            enabled: !state.sending,
            onSubmit: _send,
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onPick});

  final void Function(String)? onPick;

  /// Rótulo curto para o card, pergunta completa para o modelo.
  static const actions = [
    (
      'Resumo do mês',
      'Como foi meu mês? Compare com os anteriores.',
      LucideIcons.pieChart,
    ),
    (
      'O que mais cresceu',
      'Quais categorias de gasto mais cresceram nos últimos 6 meses e por quê?',
      LucideIcons.chartNoAxesColumnIncreasing,
    ),
    (
      'Minhas dívidas',
      'Analise meus empréstimos: quanto ainda vou pagar e onde vale amortizar.',
      LucideIcons.creditCard,
    ),
    (
      'Onde cortar',
      'Onde eu poderia cortar gastos sem mudar muito minha rotina?',
      LucideIcons.scissors,
    ),
  ];

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 112,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: actions.length,
      separatorBuilder: (_, _) => const SizedBox(width: 9),
      itemBuilder: (context, index) {
        final (titulo, pergunta, icone) = actions[index];
        return SizedBox(
          width: 150,
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: onPick == null ? null : () => onPick!(pergunta),
            child: SoftCard(
              padding: const EdgeInsets.all(13),
              radius: 15,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icone, color: AppColors.primary, size: 19),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    pergunta,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) => const Row(
    crossAxisAlignment: CrossAxisAlignment.start,
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
              'Fluxo IA',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 7),
            Text(
              'Tenho acesso aos seus gastos categorizados, empréstimos, '
              'assinaturas e PREVI. Pergunte o que quiser — ou toque em '
              'uma sugestão acima.',
              style: TextStyle(fontSize: 13, height: 1.45),
            ),
          ],
        ),
      ),
    ],
  );
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 620),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.secondary.withValues(alpha: .13),
            AppColors.primary.withValues(alpha: .09),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(5),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
        border: Border.all(color: AppColors.primary.withValues(alpha: .12)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4)),
    ),
  );
}

class _AssistantBubble extends StatelessWidget {
  const _AssistantBubble({required this.turn});

  final ChatTurn turn;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const CircleAvatar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: Icon(LucideIcons.sparkles),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fluxo IA',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            // O modelo responde em Markdown — títulos, negrito e tabelas.
            // Sem renderizar, a resposta aparece com "##" e "|" crus na tela.
            MarkdownBody(
              data: turn.content,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(fontSize: 13, height: 1.5),
                listBullet: const TextStyle(fontSize: 13, height: 1.5),
                h1: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                h2: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                h3: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                strong: const TextStyle(fontWeight: FontWeight.w800),
                tableHead: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
                tableBody: const TextStyle(fontSize: 11.5),
                tableBorder: TableBorder.all(
                  color: AppColors.muted.withValues(alpha: .25),
                  width: 0.5,
                ),
                tableCellsPadding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 5,
                ),
                blockquoteDecoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: .05),
                  borderRadius: BorderRadius.circular(6),
                ),
                code: const TextStyle(fontSize: 12, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      CircleAvatar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: Icon(LucideIcons.sparkles),
      ),
      SizedBox(width: 12),
      SizedBox.square(
        dimension: 15,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      SizedBox(width: 10),
      Text(
        'Analisando seus dados...',
        style: TextStyle(color: AppColors.muted, fontSize: 12),
      ),
    ],
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => SoftCard(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(LucideIcons.triangleAlert, color: AppColors.danger, size: 19),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message, style: const TextStyle(fontSize: 12)),
        ),
        TextButton(onPressed: onRetry, child: const Text('Tentar de novo')),
      ],
    ),
  );
}

class _CostFooter extends StatelessWidget {
  const _CostFooter({required this.totalUsd});

  final double totalUsd;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      // Deixa o custo visível: é o número que decide se vale trocar de modelo.
      'Custo desta conversa: US\$ ${totalUsd.toStringAsFixed(4)}',
      style: const TextStyle(color: AppColors.muted, fontSize: 10),
    ),
  );
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.enabled,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool enabled;
  final void Function(String) onSubmit;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
    decoration: BoxDecoration(
      color: Theme.of(context).scaffoldBackgroundColor,
      border: Border(
        top: BorderSide(color: AppColors.muted.withValues(alpha: .15)),
      ),
    ),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: enabled,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: enabled ? onSubmit : null,
            decoration: const InputDecoration(
              hintText: 'Pergunte sobre suas finanças...',
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: enabled ? () => onSubmit(controller.text) : null,
          icon: const Icon(LucideIcons.arrowUp, size: 19),
        ),
      ],
    ),
  );
}
