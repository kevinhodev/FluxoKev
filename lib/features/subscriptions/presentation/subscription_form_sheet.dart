import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/formatters/money_input_parser.dart';
import '../../../core/theme/app_colors.dart';
import '../application/subscriptions_providers.dart';
import '../domain/subscription.dart';

Future<bool?> showSubscriptionFormSheet({
  required BuildContext context,
  Subscription? subscription,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: AppColors.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (context) => _SubscriptionForm(subscription: subscription),
);

class _SubscriptionForm extends ConsumerStatefulWidget {
  const _SubscriptionForm({this.subscription});

  final Subscription? subscription;

  @override
  ConsumerState<_SubscriptionForm> createState() => _SubscriptionFormState();
}

class _SubscriptionFormState extends ConsumerState<_SubscriptionForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final TextEditingController _billingDay;
  late final TextEditingController _descriptor;
  late final TextEditingController _paymentMethod;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final item = widget.subscription;
    _name = TextEditingController(text: item?.name ?? '');
    _amount = TextEditingController(
      text: item == null
          ? ''
          : (item.amount.minorUnits / 100)
                .toStringAsFixed(2)
                .replaceAll('.', ','),
    );
    _billingDay = TextEditingController(
      text: item?.billingDay?.toString() ?? '',
    );
    _descriptor = TextEditingController(text: item?.billingDescriptor ?? '');
    _paymentMethod = TextEditingController(
      text: item?.paymentMethodLabel ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _billingDay.dispose();
    _descriptor.dispose();
    _paymentMethod.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.subscription != null;
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
                      editing ? 'Editar assinatura' : 'Nova assinatura',
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
                  prefixIcon: Icon(LucideIcons.repeat2),
                ),
                validator: (value) => value == null || value.trim().length < 2
                    ? 'Informe o nome.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Valor mensal',
                  prefixText: 'R\$ ',
                ),
                validator: (value) =>
                    MoneyInputParser.tryParse(value ?? '') == null
                    ? 'Informe um valor válido.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _billingDay,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Dia da cobrança (opcional)',
                  prefixIcon: Icon(LucideIcons.calendarDays),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  final day = int.tryParse(value);
                  return day == null || day < 1 || day > 31
                      ? 'Informe um dia válido.'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _paymentMethod,
                decoration: const InputDecoration(
                  labelText: 'Cartão ou forma de pagamento',
                  prefixIcon: Icon(LucideIcons.creditCard),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptor,
                decoration: const InputDecoration(
                  labelText: 'Nome que aparece na fatura',
                  prefixIcon: Icon(LucideIcons.scanText),
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
                  editing ? 'Salvar alterações' : 'Adicionar assinatura',
                ),
              ),
              if (editing) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _busy ? null : _archive,
                  icon: const Icon(LucideIcons.archive),
                  label: const Text('Arquivar assinatura'),
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
    final input = SubscriptionInput(
      name: _name.text.trim(),
      billingDescriptor: _descriptor.text.trim(),
      amount: MoneyInputParser.tryParse(_amount.text)!,
      billingDay: int.tryParse(_billingDay.text),
      paymentMethodLabel: _paymentMethod.text.trim(),
    );
    try {
      final api = ref.read(subscriptionsApiProvider);
      if (widget.subscription case final item?) {
        await api.update(item.id, input);
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
    final item = widget.subscription;
    if (item == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(subscriptionsApiProvider).archive(item.id);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
