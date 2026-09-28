import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/formatters/money_input_parser.dart';
import '../../../core/theme/app_colors.dart';
import '../application/fixed_expenses_providers.dart';
import '../domain/fixed_expense.dart';

Future<bool?> showFixedExpenseFormSheet({
  required BuildContext context,
  FixedExpense? expense,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: AppColors.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (context) => _FixedExpenseForm(expense: expense),
);

class _FixedExpenseForm extends ConsumerStatefulWidget {
  const _FixedExpenseForm({this.expense});

  final FixedExpense? expense;

  @override
  ConsumerState<_FixedExpenseForm> createState() => _FixedExpenseFormState();
}

class _FixedExpenseFormState extends ConsumerState<_FixedExpenseForm> {
  static const _categories = <String, String>{
    'housing-rent': 'Aluguel',
    'insurance': 'Seguro',
    'communications-internet': 'Internet',
    'communications-mobile': 'Telefonia',
    'housing-utilities': 'Energia',
    'other-expense': 'Outros',
  };

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final TextEditingController _location;
  late final TextEditingController _dueDay;
  late String _categoryId;
  late FixedExpenseValueKind _valueKind;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    _name = TextEditingController(text: expense?.name ?? '');
    _amount = TextEditingController(
      text: expense?.amount == null
          ? ''
          : (expense!.amount!.minorUnits / 100)
                .toStringAsFixed(2)
                .replaceAll('.', ','),
    );
    _location = TextEditingController(text: expense?.locationLabel ?? '');
    _dueDay = TextEditingController(text: expense?.dueDay?.toString() ?? '');
    _categoryId = _categories.containsKey(expense?.categoryId)
        ? expense!.categoryId
        : 'other-expense';
    _valueKind = expense?.valueKind ?? FixedExpenseValueKind.fixed;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _location.dispose();
    _dueDay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.expense != null;
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
                      editing ? 'Editar gasto fixo' : 'Novo gasto fixo',
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
              const SizedBox(height: 18),
              SegmentedButton<FixedExpenseValueKind>(
                segments: const [
                  ButtonSegment(
                    value: FixedExpenseValueKind.fixed,
                    label: Text('Valor fixo'),
                    icon: Icon(LucideIcons.badgeDollarSign),
                  ),
                  ButtonSegment(
                    value: FixedExpenseValueKind.variable,
                    label: Text('Variável'),
                    icon: Icon(LucideIcons.chartSpline),
                  ),
                ],
                selected: {_valueKind},
                onSelectionChanged: (values) =>
                    setState(() => _valueKind = values.first),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  prefixIcon: Icon(LucideIcons.receiptText),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Informe o nome.'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                  prefixIcon: Icon(LucideIcons.tags),
                ),
                items: _categories.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) setState(() => _categoryId = value);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: _valueKind == FixedExpenseValueKind.fixed
                      ? 'Valor mensal'
                      : 'Valor atual ou média (opcional)',
                  prefixText: 'R\$ ',
                ),
                validator: (value) {
                  if (_valueKind == FixedExpenseValueKind.variable &&
                      (value == null || value.trim().isEmpty)) {
                    return null;
                  }
                  return MoneyInputParser.tryParse(value ?? '') == null
                      ? 'Informe um valor válido.'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _location,
                      decoration: const InputDecoration(
                        labelText: 'Local (opcional)',
                        prefixIcon: Icon(LucideIcons.mapPin),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _dueDay,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Vence dia'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return null;
                        final day = int.tryParse(value);
                        return day == null || day < 1 || day > 31
                            ? 'Dia inválido'
                            : null;
                      },
                    ),
                  ),
                ],
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
                label: Text(editing ? 'Salvar alterações' : 'Adicionar gasto'),
              ),
              if (editing) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _busy ? null : _archive,
                  icon: const Icon(LucideIcons.archive),
                  label: const Text('Arquivar gasto'),
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
    final amount = _amount.text.trim().isEmpty
        ? null
        : MoneyInputParser.tryParse(_amount.text);
    final input = FixedExpenseInput(
      name: _name.text.trim(),
      categoryId: _categoryId,
      amount: amount,
      valueKind: _valueKind,
      locationLabel: _location.text.trim(),
      dueDay: int.tryParse(_dueDay.text),
    );
    try {
      final api = ref.read(fixedExpensesApiProvider);
      if (widget.expense case final expense?) {
        await api.update(expense.id, input);
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
    final expense = widget.expense;
    if (expense == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(fixedExpensesApiProvider).archive(expense.id);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
