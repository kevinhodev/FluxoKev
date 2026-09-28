import 'package:intl/intl.dart';

import '../domain/money.dart';

abstract final class MoneyFormatter {
  static final _brl = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: r'R$',
    decimalDigits: 2,
  );
  static final _brlWhole = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: r'R$',
    decimalDigits: 0,
  );

  static String format(Money money) => _brl.format(money.minorUnits / 100);

  static String formatWhole(Money money) =>
      _brlWhole.format(money.minorUnits / 100);

  static String formatThousands(Money money, {bool signedDebt = false}) {
    final value = money.minorUnits.abs() / 100000;
    final formatted = value.toStringAsFixed(1).replaceAll('.', ',');
    final prefix = signedDebt ? '-' : '';
    return '$prefix${r'R$'} $formatted mil';
  }
}
