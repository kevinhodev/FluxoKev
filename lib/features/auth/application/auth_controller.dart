import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_config.dart';
import '../../../core/network/api_client.dart';
import '../data/auth_api.dart';
import '../domain/auth_session.dart';

final apiConfigProvider = Provider<ApiConfig>(
  (ref) => ApiConfig.fromEnvironment(),
);

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

final apiClientProvider = Provider<ApiClient>((ref) {
  final token = ref.watch(authControllerProvider).value?.accessToken;
  return ApiClient(config: ref.watch(apiConfigProvider), accessToken: token);
});

class AuthController extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() async => null;

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => AuthApi(
        ApiClient(config: ref.read(apiConfigProvider)),
      ).login(email: email, password: password),
    );
  }

  void logout() => state = const AsyncData(null);
}
