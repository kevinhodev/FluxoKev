import '../../../core/network/api_client.dart';

/// Uma fala do chat. `role` espelha o que a API espera no histórico.
class ChatTurn {
  const ChatTurn({
    required this.role,
    required this.content,
    this.costUsd,
  });

  final String role;
  final String content;

  /// Custo estimado da resposta em dólares; nulo nas falas do usuário.
  final double? costUsd;

  bool get isUser => role == 'user';

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class InsightsApi {
  const InsightsApi(this._client);

  final ApiClient _client;

  Future<ChatTurn> ask({
    required String question,
    required List<ChatTurn> history,
  }) async {
    final json =
        await _client.post(
              '/v1/insights/ask',
              body: {
                'question': question,
                // O histórico vai inteiro porque a API é sem estado; o backend
                // limita a 20 turnos.
                'history': history.map((turn) => turn.toJson()).toList(),
              },
            )
            as Map<String, dynamic>;
    final usage = json['usage'] as Map<String, dynamic>?;
    return ChatTurn(
      role: 'assistant',
      content: json['answer'] as String,
      costUsd: (usage?['estimatedCostUsd'] as num?)?.toDouble(),
    );
  }
}
