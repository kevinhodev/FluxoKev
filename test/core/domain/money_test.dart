import 'package:fluxo_ia/core/domain/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money', () {
    test('opera valores usando unidades monetárias inteiras', () {
      const income = Money(10000);
      const expense = Money(3550);

      expect((income - expense).minorUnits, 6450);
      expect(expense.negated.minorUnits, -3550);
      expect(expense.negated.absolute, expense);
    });

    test('impede operações entre moedas diferentes', () {
      const brl = Money(100, currency: 'BRL');
      const usd = Money(100, currency: 'USD');

      expect(() => brl + usd, throwsArgumentError);
    });
  });
}
