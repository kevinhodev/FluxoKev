import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/repositories/api_commitments_repository.dart';
import '../domain/entities/commitments_summary.dart';
import '../domain/repositories/commitments_repository.dart';

final commitmentsRepositoryProvider = Provider<CommitmentsRepository>(
  (ref) => ApiCommitmentsRepository(ref.watch(apiClientProvider)),
);

final commitmentsSummaryProvider = FutureProvider<CommitmentsSummary>(
  (ref) => ref.watch(commitmentsRepositoryProvider).getSummary(),
);
