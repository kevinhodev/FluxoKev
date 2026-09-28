import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/subscriptions_api.dart';
import '../domain/subscription.dart';

final subscriptionsApiProvider = Provider<SubscriptionsApi>(
  (ref) => SubscriptionsApi(ref.watch(apiClientProvider)),
);

final subscriptionsProvider = FutureProvider<List<Subscription>>(
  (ref) => ref.watch(subscriptionsApiProvider).list(),
);
