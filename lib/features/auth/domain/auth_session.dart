class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.userId,
    required this.userName,
    required this.email,
  });

  final String accessToken;
  final String userId;
  final String userName;
  final String email;
}
