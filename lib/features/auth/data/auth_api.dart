import '../../../core/network/api_client.dart';
import '../domain/auth_session.dart';

class AuthApi {
  AuthApi(this._client);

  final ApiClient _client;

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final json =
        await _client.post(
              '/v1/auth/login',
              body: {'email': email.trim(), 'password': password},
            )
            as Map<String, dynamic>;
    final user = json['user'] as Map<String, dynamic>;
    return AuthSession(
      accessToken: json['accessToken'] as String,
      userId: user['id'] as String,
      userName: user['name'] as String,
      email: user['email'] as String,
    );
  }
}
