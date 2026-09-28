import '../domain/money.dart';

abstract final class MoneyInputParser {
  static Money? tryParse(String input) {
    var normalized = input.replaceAll(RegExp(r'[^0-9,.]'), '');
    if (normalized.isEmpty) return null;

    if (normalized.contains(',')) {
      normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
    } else if ('.'.allMatches(normalized).length > 1) {
      normalized = normalized.replaceAll('.', '');
    }

    final value = double.tryParse(normalized);
    if (value == null || !value.isFinite || value <= 0) return null;
    return Money((value * 100).round());
  }
}
