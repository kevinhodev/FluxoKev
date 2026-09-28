import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/domain/money.dart';
import '../../../core/formatters/money_input_parser.dart';
import '../../../core/theme/app_colors.dart';
import '../application/benefit_wallets_providers.dart';
import '../domain/benefit_wallet.dart';

Future<bool?> showBenefitWalletFormSheet({
  required BuildContext context,
  BenefitWallet? wallet,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: AppColors.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (context) => _BenefitWalletForm(wallet: wallet),
);

class _BenefitWalletForm extends ConsumerStatefulWidget {
  const _BenefitWalletForm({this.wallet});

  final BenefitWallet? wallet;

  @override
  ConsumerState<_BenefitWalletForm> createState() => _BenefitWalletFormState();
}

class _BenefitWalletFormState extends ConsumerState<_BenefitWalletForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _balance;
  late final TextEditingController _credit;
  late final TextEditingController _allocation;
  late final TextEditingController _allocationLabel;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final wallet = widget.wallet;
    _name = TextEditingController(text: wallet?.name ?? '');
    _balance = TextEditingController(text: _moneyText(wallet?.currentBalance));
    _credit = TextEditingController(text: _moneyText(wallet?.monthlyCredit));
    _allocation = TextEditingController(
      text: _moneyText(wallet?.monthlyAllocation),
    );
    _allocationLabel = TextEditingController(
      text: wallet?.allocationLabel ?? '',
    );
  }

  String _moneyText(Money? money) => money == null
      ? ''
      : (money.minorUnits / 100).toStringAsFixed(2).replaceAll('.', ',');

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    _credit.dispose();
    _allocation.dispose();
    _allocationLabel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.wallet != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      editing ? 'Editar benefício' : 'Novo benefício',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.x),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  prefixIcon: Icon(LucideIcons.walletCards),
                ),
                validator: (value) => value == null || value.trim().length < 2
                    ? 'Informe o nome.'
                    : null,
              ),
              const SizedBox(height: 12),
              _MoneyField(controller: _balance, label: 'Saldo atual'),
              const SizedBox(height: 12),
              _MoneyField(controller: _credit, label: 'Crédito mensal'),
              const SizedBox(height: 12),
              _MoneyField(
                controller: _allocation,
                label: 'Valor mensal reservado',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _allocationLabel,
                decoration: const InputDecoration(
                  labelText: 'Destino do valor reservado',
                  prefixIcon: Icon(LucideIcons.heartHandshake),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.danger)),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.check),
                label: Text(
                  editing ? 'Salvar alterações' : 'Adicionar benefício',
                ),
              ),
              if (editing) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _busy ? null : _archive,
                  icon: const Icon(LucideIcons.archive),
                  label: const Text('Arquivar benefício'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final input = BenefitWalletInput(
      name: _name.text.trim(),
      currentBalance: MoneyInputParser.tryParse(_balance.text)!,
      monthlyCredit: MoneyInputParser.tryParse(_credit.text)!,
      monthlyAllocation: MoneyInputParser.tryParse(_allocation.text)!,
      allocationLabel: _allocationLabel.text.trim(),
    );
    try {
      final api = ref.read(benefitWalletsApiProvider);
      if (widget.wallet case final wallet?) {
        await api.update(wallet.id, input);
      } else {
        await api.create(input);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _archive() async {
    final wallet = widget.wallet;
    if (wallet == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(benefitWalletsApiProvider).archive(wallet.id);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _MoneyField extends StatelessWidget {
  const _MoneyField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label, prefixText: 'R\$ '),
    validator: (value) => MoneyInputParser.tryParse(value ?? '') == null
        ? 'Informe um valor válido.'
        : null,
  );
}
