import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/formatters/money_formatter.dart';
import '../../../core/theme/app_colors.dart';
import '../application/transaction_providers.dart';

/// Agrupa descritores de cartão sob um nome escolhido pelo usuário.
///
/// A operadora emite o mesmo estabelecimento sob variações ("AIRBNB PAGAM*AIRB",
/// "AIRBNB PLATAF SAO PAULO"), o que fragmenta qualquer análise. Quem decide o
/// que é a mesma coisa é o usuário: um prefixo curto demais juntaria postos
/// diferentes, e só ele sabe onde traçar a linha.
Future<bool?> showMerchantAliasSheet(
  BuildContext context, {

  /// Nulo quando a regra é criada da tela de regras, sem partir de um extrato.
  String? rawDescription,

  /// Preenchida quando se está editando uma regra existente.
  MerchantAlias? existing,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  builder: (_) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: _MerchantAliasSheet(
      rawDescription: rawDescription,
      existing: existing,
    ),
  ),
);

class _MerchantAliasSheet extends ConsumerStatefulWidget {
  const _MerchantAliasSheet({
    required this.rawDescription,
    required this.existing,
  });

  final String? rawDescription;
  final MerchantAlias? existing;

  @override
  ConsumerState<_MerchantAliasSheet> createState() => _SheetState();
}

class _SheetState extends ConsumerState<_MerchantAliasSheet> {
  late final TextEditingController _pattern;
  late final TextEditingController _name;
  Timer? _debounce;
  AliasPreviewState _preview = const AliasPreviewState.idle();
  String? _categoryId;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final editando = widget.existing;
    if (editando != null) {
      _pattern = TextEditingController(text: editando.pattern);
      _name = TextEditingController(text: editando.merchantName);
      _categoryId = editando.categoryId;
      _schedulePreview();
      return;
    }
    final origem = widget.rawDescription?.trim() ?? '';
    final primeira = origem.isEmpty
        ? ''
        : origem.split(RegExp(r'[\s*]+')).first;
    _pattern = TextEditingController(text: primeira);
    _name = TextEditingController(text: _titulo(primeira));
    if (primeira.isNotEmpty) _schedulePreview();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pattern.dispose();
    _name.dispose();
    super.dispose();
  }

  static String _titulo(String texto) => texto.isEmpty
      ? texto
      : texto[0].toUpperCase() + texto.substring(1).toLowerCase();

  void _schedulePreview() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _loadPreview);
  }

  Future<void> _loadPreview() async {
    final pattern = _pattern.text.trim();
    if (pattern.length < 3) {
      setState(() => _preview = const AliasPreviewState.idle());
      return;
    }
    setState(() => _preview = const AliasPreviewState.loading());
    try {
      final result = await ref
          .read(merchantAliasesApiProvider)
          .preview(pattern);
      if (mounted) setState(() => _preview = AliasPreviewState.ready(result));
    } catch (_) {
      if (mounted) setState(() => _preview = const AliasPreviewState.idle());
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final api = ref.read(merchantAliasesApiProvider);
      final editando = widget.existing;
      if (editando == null) {
        await api.create(
          pattern: _pattern.text.trim(),
          merchantName: _name.text.trim(),
          categoryId: _categoryId,
        );
      } else {
        await api.update(
          id: editando.id,
          pattern: _pattern.text.trim(),
          merchantName: _name.text.trim(),
          categoryId: _categoryId,
        );
      }
      ref.invalidate(merchantAliasesProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível salvar: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final valido =
        _pattern.text.trim().length >= 3 && _name.text.trim().length >= 2;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existing == null
                  ? 'Normalizar estabelecimento'
                  : 'Editar regra',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              widget.rawDescription ??
                  (widget.existing == null
                      ? 'Digite o começo do descritor que aparece no seu extrato.'
                      : 'Mudar o prefixo troca quais transações a regra pega.'),
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pattern,
              onChanged: (_) {
                setState(() {});
                _schedulePreview();
              },
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Agrupar tudo que começa com',
                helperText: 'Prefixo curto pega mais; longo pega menos',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Chamar de',
                hintText: 'Ex.: Airbnb',
              ),
            ),
            const SizedBox(height: 12),
            // Opcional: a regra pode só renomear. Fixar a categoria resolve o
            // caso em que a operadora classifica a mesma parada de um jeito
            // num mês e de outro no seguinte.
            ref
                .watch(expenseCategoriesProvider)
                .when(
                  loading: () => const SizedBox(height: 8),
                  error: (_, _) => const SizedBox(height: 8),
                  data: (categorias) => DropdownButtonFormField<String?>(
                    initialValue: _categoryId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Categoria (opcional)',
                      helperText: 'Vazio mantém a categoria que o banco enviar',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Não alterar'),
                      ),
                      for (final categoria in categorias)
                        DropdownMenuItem<String?>(
                          value: categoria.id,
                          child: Text(
                            categoria.parentId == null
                                ? categoria.name
                                : '   ${categoria.name}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (valor) => setState(() => _categoryId = valor),
                  ),
                ),
            const SizedBox(height: 16),
            _PreviewBox(state: _preview),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: !valido || _saving ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(LucideIcons.check, size: 18),
                label: Text(
                  _saving
                      ? 'Salvando...'
                      : widget.existing == null
                      ? 'Salvar apelido'
                      : 'Salvar alterações',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewBox extends StatelessWidget {
  const _PreviewBox({required this.state});

  final AliasPreviewState state;

  @override
  Widget build(BuildContext context) {
    final preview = state.value;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: state.loading
          ? const Text('Conferindo...', style: TextStyle(fontSize: 12))
          : preview == null
          ? const Text(
              'Digite ao menos 3 caracteres no prefixo.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${preview.matches} transações • ${MoneyFormatter.format(preview.total)}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (preview.samples.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Descritores alcançados:',
                    style: TextStyle(color: AppColors.muted, fontSize: 10.5),
                  ),
                  const SizedBox(height: 3),
                  for (final sample in preview.samples)
                    Text(
                      '• $sample',
                      style: const TextStyle(fontSize: 10.5, height: 1.45),
                    ),
                ],
              ],
            ),
    );
  }
}
