class Money implements Comparable<Money> {
  const Money(this.minorUnits, {this.currency = 'BRL'});

  const Money.zero({this.currency = 'BRL'}) : minorUnits = 0;

  final int minorUnits;
  final String currency;

  bool get isNegative => minorUnits < 0;
  bool get isPositive => minorUnits > 0;
  bool get isZero => minorUnits == 0;

  Money get absolute => Money(minorUnits.abs(), currency: currency);
  Money get negated => Money(-minorUnits, currency: currency);

  Money operator +(Money other) {
    _ensureSameCurrency(other);
    return Money(minorUnits + other.minorUnits, currency: currency);
  }

  Money operator -(Money other) {
    _ensureSameCurrency(other);
    return Money(minorUnits - other.minorUnits, currency: currency);
  }

  void _ensureSameCurrency(Money other) {
    if (currency != other.currency) {
      throw ArgumentError('Não é possível operar moedas diferentes.');
    }
  }

  @override
  int compareTo(Money other) {
    _ensureSameCurrency(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Money &&
          minorUnits == other.minorUnits &&
          currency == other.currency;

  @override
  int get hashCode => Object.hash(minorUnits, currency);

  @override
  String toString() => 'Money($minorUnits $currency)';
}
