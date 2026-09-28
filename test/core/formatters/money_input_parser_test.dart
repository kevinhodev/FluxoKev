import 'package:fluxo_ia/core/formatters/money_input_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('converte valores brasileiros para centavos', () {
    expect(MoneyInputParser.tryParse('R\$ 1.234,56')?.minorUnits, 123456);
    expect(MoneyInputParser.tryParse('55,90')?.minorUnits, 5590);
  });

  test('rejeita valor vazio, zero ou inválido', () {
    expect(MoneyInputParser.tryParse(''), isNull);
    expect(MoneyInputParser.tryParse('0'), isNull);
    expect(MoneyInputParser.tryParse('abc'), isNull);
  });
}
