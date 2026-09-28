import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/formatters/money_input_parser.dart';
import '../../../core/theme/app_colors.dart';
import '../../accounts/domain/entities/financial_account.dart';
import '../../categories/domain/entities/financial_category.dart';
import '../domain/entities/financial_transaction.dart';

Future<FinancialTransaction?> showTransactionFormSheet({
  required BuildContext context,
  required List<FinancialAccount> accounts,
  required List<FinancialCategory> categories,
  FinancialTransaction? transaction,
}) {
  return showModalBottomSheet<FinancialTransaction>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _TransactionForm(
      accounts: accounts,
      categories: categories,
      transaction: transaction,
    ),
  );
}

class _TransactionForm extends StatefulWidget {
  const _TransactionForm({
    required this.accounts,
    required this.categories,
    this.transaction,
  });

  final List<FinancialAccount> accounts;
  final List<FinancialCategory> categories;
  final FinancialTransaction? transaction;

  @override
  State<_TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<_TransactionForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController;
  late final TextEditingController _merchantController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late DateTime _date;
  late String _accountId;
  late CategoryType _type;
  late String _categoryId;

  @override
  void initState() {
    super.initState();
    final transaction = widget.transaction;
    final initialCategory = transaction == null
        ? _categoriesFor(CategoryType.expense).first
        : widget.categories.firstWhere(
            (category) => category.id == transaction.categoryId,
          );
    _type = initialCategory.type;
    _categoryId = initialCategory.id;
    _accountId = transaction?.accountId ?? widget.accounts.first.id;
    _date = transaction?.occurredAt ?? DateTime.now();
    _descriptionController = TextEditingController(
      text: transaction?.description ?? '',
    );
    _merchantController = TextEditingController(
      text: transaction?.merchantName ?? '',
    );
    _amountController = TextEditingController(
      text: transaction == null
          ? ''
          : (transaction.amount.minorUnits / 100)
                .toStringAsFixed(2)
                .replaceAll('.', ','),
    );
    _noteController = TextEditingController(text: transaction?.note ?? '');
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _merchantController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.transaction != null;
    final categories = _categoriesFor(_type);
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
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      editing ? 'Editar transação' : 'Nova transação',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.x),
                  ),
                ],
              ),
              const Text(
                'Preencha os dados para atualizar seu fluxo financeiro.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<CategoryType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(
                    value: CategoryType.expense,
                    child: Text('Despesa'),
                  ),
                  DropdownMenuItem(
                    value: CategoryType.income,
                    child: Text('Receita'),
                  ),
                  DropdownMenuItem(
                    value: CategoryType.transfer,
                    child: Text('Transferência'),
                  ),
                  DropdownMenuItem(
                    value: CategoryType.investment,
                    child: Text('Rendimento'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null || value == _type) return;
                  setState(() {
                    _type = value;
                    _categoryId = _categoriesFor(value).first.id;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('transaction-description'),
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  prefixIcon: Icon(LucideIcons.receiptText),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Informe uma descrição.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('transaction-merchant'),
                controller: _merchantController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Estabelecimento',
                  hintText: 'Opcional',
                  prefixIcon: Icon(LucideIcons.store),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('transaction-amount'),
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Valor',
                  hintText: '0,00',
                  prefixText: 'R\$ ',
                ),
                validator: (value) =>
                    MoneyInputParser.tryParse(value ?? '') == null
                    ? 'Informe um valor maior que zero.'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _accountId,
                decoration: const InputDecoration(
                  labelText: 'Conta',
                  prefixIcon: Icon(LucideIcons.landmark),
                ),
                items: widget.accounts
                    .map(
                      (account) => DropdownMenuItem(
                        value: account.id,
                        child: Text(account.name),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) _accountId = value;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(_type),
                initialValue: _categoryId,
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                  prefixIcon: Icon(LucideIcons.tag),
                ),
                items: categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category.id,
                        child: Text(_categoryLabel(category)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) _categoryId = value;
                },
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data',
                    prefixIcon: Icon(LucideIcons.calendarDays),
                  ),
                  child: Text(
                    '${_date.day.toString().padLeft(2, '0')}/'
                    '${_date.month.toString().padLeft(2, '0')}/${_date.year}',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Observação',
                  hintText: 'Opcional',
                  prefixIcon: Icon(LucideIcons.notebookPen),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('transaction-submit'),
                  onPressed: _submit,
                  icon: const Icon(LucideIcons.check),
                  label: Text(editing ? 'Salvar alterações' : 'Adicionar'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<FinancialCategory> _categoriesFor(CategoryType type) {
    final parentIds = widget.categories
        .map((category) => category.parentId)
        .whereType<String>()
        .toSet();
    return widget.categories
        .where((category) => category.type == type)
        .where((category) => !parentIds.contains(category.id))
        .toList(growable: false);
  }

  String _categoryLabel(FinancialCategory category) {
    if (category.parentId == null) return category.name;
    final parent = widget.categories.firstWhere(
      (candidate) => candidate.id == category.parentId,
    );
    return '${parent.name} • ${category.name}';
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected != null) setState(() => _date = selected);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final amount = MoneyInputParser.tryParse(_amountController.text)!;
    final previous = widget.transaction;
    final description = _descriptionController.text.trim();
    final merchant = _merchantController.text.trim();
    final direction = switch (_type) {
      CategoryType.expense || CategoryType.transfer =>
        previous?.direction ?? TransactionDirection.debit,
      CategoryType.income || CategoryType.investment =>
        previous?.direction ?? TransactionDirection.credit,
    };
    final nature = switch (_type) {
      CategoryType.expense => TransactionNature.expense,
      CategoryType.income => TransactionNature.income,
      CategoryType.transfer => TransactionNature.transfer,
      CategoryType.investment => TransactionNature.investmentReturn,
    };

    Navigator.pop(
      context,
      FinancialTransaction(
        id: previous?.id ?? 'manual-${DateTime.now().microsecondsSinceEpoch}',
        externalId: previous?.externalId,
        accountId: _accountId,
        occurredAt: DateTime(
          _date.year,
          _date.month,
          _date.day,
          previous?.occurredAt.hour ?? 12,
          previous?.occurredAt.minute ?? 0,
        ),
        description: description,
        merchantName: merchant.isEmpty ? description : merchant,
        amount: amount,
        direction: direction,
        nature: nature,
        categoryId: _categoryId,
        source: previous?.source ?? TransactionSource.manual,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      ),
    );
  }
}
