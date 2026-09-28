import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/insights_api.dart';

final insightsApiProvider = Provider<InsightsApi>(
  (ref) => InsightsApi(ref.watch(apiClientProvider)),
);

class ChatState {
  const ChatState({
    this.turns = const [],
    this.sending = false,
    this.error,
  });

  final List<ChatTurn> turns;
  final bool sending;
  final String? error;

  /// Custo acumulado da conversa, para o usuário ver o gasto crescer.
  double get totalCostUsd =>
      turns.fold(0, (sum, turn) => sum + (turn.costUsd ?? 0));

  ChatState copyWith({
    List<ChatTurn>? turns,
    bool? sending,
    String? error,
    bool clearError = false,
  }) => ChatState(
    turns: turns ?? this.turns,
    sending: sending ?? this.sending,
    error: clearError ? null : (error ?? this.error),
  );
}

class ChatController extends Notifier<ChatState> {
  @override
  ChatState build() => const ChatState();

  Future<void> send(String question) async {
    final text = question.trim();
    if (text.isEmpty || state.sending) return;

    // O histórico enviado é o anterior à pergunta atual: a API recebe a
    // pergunta separada, e duplicá-la no histórico confundiria o modelo.
    final history = List<ChatTurn>.from(state.turns);
    state = state.copyWith(
      turns: [...history, ChatTurn(role: 'user', content: text)],
      sending: true,
      clearError: true,
    );

    try {
      final answer = await ref
          .read(insightsApiProvider)
          .ask(question: text, history: history);
      state = state.copyWith(turns: [...state.turns, answer], sending: false);
    } catch (error) {
      state = state.copyWith(sending: false, error: _humanize(error));
    }
  }

  /// Remove a última pergunta que falhou, para o usuário reformular sem
  /// deixar uma mensagem órfã sem resposta na tela.
  void discardLastQuestion() {
    if (state.turns.isEmpty || !state.turns.last.isUser) return;
    state = state.copyWith(
      turns: state.turns.sublist(0, state.turns.length - 1),
      clearError: true,
    );
  }

  void clear() => state = const ChatState();

  String _humanize(Object error) {
    final text = error.toString();
    if (text.contains('AI_NOT_CONFIGURED')) {
      return 'A análise por IA não está configurada no servidor.';
    }
    if (text.contains('429') || text.toLowerCase().contains('rate')) {
      return 'Muitas perguntas em pouco tempo. Tente daqui a pouco.';
    }
    return 'Não consegui responder agora. $text';
  }
}

final chatControllerProvider = NotifierProvider<ChatController, ChatState>(
  ChatController.new,
);
