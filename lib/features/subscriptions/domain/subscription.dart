import '../../../core/domain/money.dart';

class Subscription {
  const Subscription({
    required this.id,
    required this.name,
    required this.billingDescriptor,
    required this.amount,
    required this.billingDay,
    required this.paymentMethodLabel,
    required this.note,
  });

  final String id;
  final String name;
  final String billingDescriptor;
  final Money amount;
  final int? billingDay;
  final String paymentMethodLabel;
  final String? note;
}

class SubscriptionInput {
  const SubscriptionInput({
    required this.name,
    required this.billingDescriptor,
    required this.amount,
    required this.billingDay,
    required this.paymentMethodLabel,
    this.note,
  });

  final String name;
  final String billingDescriptor;
  final Money amount;
  final int? billingDay;
  final String paymentMethodLabel;
  final String? note;
}
