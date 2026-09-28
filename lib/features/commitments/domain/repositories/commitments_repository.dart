import '../entities/commitments_summary.dart';

abstract interface class CommitmentsRepository {
  Future<CommitmentsSummary> getSummary();
}
