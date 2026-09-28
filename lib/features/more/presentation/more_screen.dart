import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_brand.dart';
import '../../../core/widgets/soft_card.dart';
import '../../commitments/application/commitments_providers.dart';
import '../../integrations/pluggy/application/pluggy_connection_provider.dart';
import '../../overview/application/financial_dashboard_provider.dart';
import '../../transactions/application/transaction_providers.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pluggy = ref.watch(pluggyConnectionProvider);
    final pluggyStatus = pluggy.asData?.value;
    final connected = pluggyStatus?.connected ?? false;
    final syncSubtitle = switch (pluggy) {
      AsyncLoading() => 'Buscando dados disponíveis...',
      AsyncError() => 'Falha na última tentativa',
      AsyncData(value: final value) =>
        value.lastSyncAt == null
            ? 'Ainda não sincronizado'
            : 'Última busca ${DateFormat('dd/MM HH:mm').format(value.lastSyncAt!)}',
    };
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
            sliver: SliverList.list(
              children: [
                const AppBrand(compact: true),
                const SizedBox(height: 18),
                const Text(
                  'Mais',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const Text(
                  'Configurações, integrações e recursos do app',
                  style: TextStyle(color: AppColors.muted, fontSize: 14),
                ),
                const SizedBox(height: 18),
                _SettingsSection(
                  title: 'Conexões',
                  items: [
                    const _SettingsItem(
                      'Contas conectadas',
                      '3 ativas',
                      LucideIcons.link,
                      AppColors.primary,
                    ),
                    _SettingsItem(
                      'Open Finance / Pluggy',
                      connected ? 'Conectado' : 'Verificar',
                      LucideIcons.link2,
                      connected ? AppColors.success : AppColors.warning,
                    ),
                    _SettingsItem(
                      'Buscar dados disponíveis',
                      syncSubtitle,
                      LucideIcons.refreshCw,
                      AppColors.primary,
                      onTap: pluggy.isLoading
                          ? null
                          : () async {
                              await ref
                                  .read(pluggyConnectionProvider.notifier)
                                  .fetchAvailableData();
                              ref.invalidate(financialDashboardProvider);
                              ref.invalidate(transactionListItemsProvider);
                              ref.invalidate(commitmentsSummaryProvider);
                            },
                    ),
                    _SettingsItem(
                      'Importar arquivos',
                      'CSV, OFX, PDF e PREVI',
                      LucideIcons.fileUp,
                      AppColors.primary,
                      onTap: () => context.push('/imports'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SettingsSection(
                  title: 'Organização',
                  items: [
                    const _SettingsItem(
                      'Categorias',
                      null,
                      LucideIcons.tag,
                      AppColors.secondary,
                    ),
                    _SettingsItem(
                      'Regras automáticas',
                      'Normalização de nomes de estabelecimento',
                      LucideIcons.bot,
                      AppColors.warning,
                      onTap: () => context.push('/rules'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const _SettingsSection(
                  title: 'Planejamento',
                  items: [
                    _SettingsItem(
                      'Metas financeiras',
                      null,
                      LucideIcons.target,
                      AppColors.primary,
                    ),
                    _SettingsItem(
                      'Orçamentos',
                      null,
                      LucideIcons.pieChart,
                      AppColors.success,
                    ),
                    _SettingsItem(
                      'Simulações',
                      null,
                      LucideIcons.chartNoAxesColumnIncreasing,
                      AppColors.info,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const _SettingsSection(
                  title: 'IA',
                  items: [
                    _SettingsItem(
                      'Modelo de IA',
                      'Econômico',
                      LucideIcons.sparkles,
                      AppColors.secondary,
                    ),
                    _SettingsItem(
                      'Limite mensal',
                      'R\$ 20,00',
                      LucideIcons.wallet,
                      AppColors.primary,
                    ),
                    _SettingsItem(
                      'Histórico do chat',
                      null,
                      LucideIcons.messageCircle,
                      AppColors.secondary,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const _SettingsSection(
                  title: 'Dados e segurança',
                  items: [
                    _SettingsItem(
                      'Privacidade',
                      null,
                      LucideIcons.shieldCheck,
                      AppColors.success,
                    ),
                    _SettingsItem(
                      'Exportar dados',
                      null,
                      LucideIcons.download,
                      AppColors.info,
                    ),
                    _SettingsItem(
                      'Backup e restauração',
                      null,
                      LucideIcons.cloudUpload,
                      AppColors.warning,
                    ),
                    _SettingsItem(
                      'Notificações',
                      null,
                      LucideIcons.bell,
                      AppColors.secondary,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const _SettingsSection(
                  title: '',
                  items: [
                    _SettingsItem(
                      'Sobre o app',
                      null,
                      LucideIcons.info,
                      AppColors.primary,
                    ),
                    _SettingsItem(
                      'Versão 0.1.0',
                      null,
                      LucideIcons.layers,
                      AppColors.primary,
                      trailing: false,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _MoreChatCta(onTap: () => context.go('/chat')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.items});

  final String title;
  final List<_SettingsItem> items;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Text(
              title,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 5),
          ],
          for (var index = 0; index < items.length; index++) ...[
            items[index],
            if (index != items.length - 1) const Divider(),
          ],
        ],
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  const _SettingsItem(
    this.title,
    this.subtitle,
    this.icon,
    this.color, {
    this.trailing = true,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final bool trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isStatus = subtitle == 'Conectado';
    return InkWell(
      onTap: onTap ?? (trailing ? () {} : null),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  if (subtitle != null && !isStatus && subtitle!.length >= 14)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (isStatus)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: .18),
                  ),
                ),
                child: const Text(
                  'Conectado',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              )
            else if (subtitle != null && subtitle!.length < 14)
              Text(
                subtitle!,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            if (trailing) ...[
              const SizedBox(width: 7),
              const Icon(
                LucideIcons.chevronRight,
                size: 17,
                color: AppColors.muted,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MoreChatCta extends StatelessWidget {
  const _MoreChatCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              child: Icon(LucideIcons.sparkles),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Conversar com a IA',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Tire dúvidas e receba insights personalizados',
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
