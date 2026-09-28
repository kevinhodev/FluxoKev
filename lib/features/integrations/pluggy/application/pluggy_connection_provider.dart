import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/application/auth_controller.dart';

class PluggyConnectionStatus {
  const PluggyConnectionStatus({
    required this.configured,
    required this.connectorName,
    required this.status,
    required this.executionStatus,
    required this.providerUpdatedAt,
    required this.lastSyncAt,
    required this.lastError,
  });

  final bool configured;
  final String? connectorName;
  final String? status;
  final String? executionStatus;
  final DateTime? providerUpdatedAt;
  final DateTime? lastSyncAt;
  final String? lastError;

  bool get connected =>
      configured &&
      (executionStatus == 'SUCCESS' || executionStatus == 'PARTIAL_SUCCESS');
}

final pluggyConnectionProvider =
    AsyncNotifierProvider<PluggyConnectionController, PluggyConnectionStatus>(
      PluggyConnectionController.new,
    );

class PluggyConnectionController extends AsyncNotifier<PluggyConnectionStatus> {
  @override
  Future<PluggyConnectionStatus> build() => _load();

  Future<void> fetchAvailableData() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(apiClientProvider)
          .post('/v1/integrations/pluggy/sync', body: const {});
      return _load();
    });
  }

  Future<PluggyConnectionStatus> _load() async {
    final json =
        await ref.read(apiClientProvider).get('/v1/integrations/pluggy/status')
            as Map<String, dynamic>;
    return PluggyConnectionStatus(
      configured: json['configured'] as bool? ?? false,
      connectorName: json['connectorName'] as String?,
      status: json['status'] as String?,
      executionStatus: json['executionStatus'] as String?,
      providerUpdatedAt: _date(json['providerUpdatedAt']),
      lastSyncAt: _date(json['lastSyncAt']),
      lastError: json['lastError'] as String?,
    );
  }

  DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;
}
