import Anthropic from "@anthropic-ai/sdk";

import type { DatabasePool } from "../db/pool.js";
import { CATEGORY_ID_SQL, MERCHANT_NAME_SQL } from "./merchant-aliases.js";

export type AiInsightsConfig = {
  apiKey: string;
  /** Trocável por variável de ambiente, sem rebuild. */
  model: string;
};

export type AiQuestion = {
  question: string;
  /** Turnos anteriores, para o chat manter fio da conversa. */
  history: { role: "user" | "assistant"; content: string }[];
};

export type AiAnswer = {
  answer: string;
  usage: {
    inputTokens: number;
    outputTokens: number;
    cacheReadTokens: number;
    cacheCreationTokens: number;
    estimatedCostUsd: number;
  };
};

export interface AiInsightsService {
  ask(userId: string, input: AiQuestion): Promise<AiAnswer>;
}

/**
 * Preço por milhão de tokens, só para exibir o custo estimado na resposta.
 * Serve para o usuário decidir se troca de modelo com número na mão.
 */
const PRICE_PER_MTOK: Record<string, { input: number; output: number }> = {
  "claude-opus-5": { input: 5, output: 25 },
  "claude-sonnet-5": { input: 3, output: 15 },
  "claude-haiku-4-5": { input: 1, output: 5 },
};

const SYSTEM_PROMPT = `Você é o analista financeiro pessoal do usuário dentro do app Fluxo IA.

Responda em português do Brasil. Valores em reais, formato 1.234,56.

Como trabalhar:
- Baseie toda afirmação nos dados fornecidos. Cite os números que sustentam a conclusão.
- Se os dados não respondem a pergunta, diga isso em vez de estimar. Dado ausente é uma resposta legítima.
- Prefira apontar o que mudou e por quê a repetir totais que o usuário já vê na tela.
- Desconfie de inconsistência: se dois números do contexto se contradizem, aponte a contradição em vez de escolher um.
- Seja direto. Sem preâmbulo, sem listar tudo que você poderia ter analisado.

Sobre os dados:
- "gastosPorMes" vem da sincronização bancária, já está categorizado, e é a fonte autoritativa de total por mês.
- "maioresEstabelecimentosPorMes" traz os 30 maiores. Onde o usuário criou um apelido, os descritores já vêm unificados sob o nome dele. Onde não criou, o MESMO estabelecimento ainda pode aparecer sob vários descritores de cartão — some os que começam com a mesma marca ao responder "quanto gasto com X", diga que fez isso, e sugira criar um apelido para não precisar repetir a soma.
- A lista de estabelecimentos é um recorte dos maiores, não o total. Se a soma dos descritores destoar de "gastosPorMes", confie no segundo.
- Compras parceladas aparecem no mês em que a parcela foi cobrada, não no da compra. O mês reflete desembolso, não a data da decisão de compra.
- Nos empréstimos, "aindaAPagar" é a soma nominal das parcelas em aberto e "quitandoHoje" é o valor presente delas. São coisas diferentes: o primeiro responde "quanto vou desembolsar", o segundo "quanto eu devo".
- O mês corrente costuma estar incompleto, porque depende da última sincronização. Considere isso antes de declarar tendência de queda.`;

export function createAiInsightsService(
  pool: DatabasePool,
  config: AiInsightsConfig,
): AiInsightsService {
  const client = new Anthropic({ apiKey: config.apiKey });

  return {
    async ask(userId, input) {
      const context = await buildFinancialContext(pool, userId);

      const response = await client.messages.create({
        model: config.model,
        max_tokens: 16000,
        thinking: { type: "adaptive" },
        system: [
          { type: "text", text: SYSTEM_PROMPT },
          {
            // O retrato financeiro é estável entre perguntas da mesma sessão,
            // então fica em bloco próprio com cache: as perguntas seguintes
            // pagam cerca de 10% por essa parte.
            type: "text",
            text: `Retrato financeiro do usuário:\n\n${JSON.stringify(context, null, 1)}`,
            cache_control: { type: "ephemeral" },
          },
        ],
        messages: [
          ...input.history.map((turn) => ({
            role: turn.role,
            content: turn.content,
          })),
          { role: "user" as const, content: input.question },
        ],
      });

      if (response.stop_reason === "refusal") {
        throw new Error(
          "O modelo recusou responder a esta pergunta: " +
            (response.stop_details?.explanation ?? "sem detalhe"),
        );
      }

      const answer = response.content
        .filter((block) => block.type === "text")
        .map((block) => block.text)
        .join("\n")
        .trim();

      const price = PRICE_PER_MTOK[config.model] ?? { input: 0, output: 0 };
      const cacheRead = response.usage.cache_read_input_tokens ?? 0;
      const cacheCreation = response.usage.cache_creation_input_tokens ?? 0;
      return {
        answer,
        usage: {
          inputTokens: response.usage.input_tokens,
          outputTokens: response.usage.output_tokens,
          cacheReadTokens: cacheRead,
          cacheCreationTokens: cacheCreation,
          estimatedCostUsd:
            ((response.usage.input_tokens + cacheCreation * 1.25 + cacheRead * 0.1) *
              price.input +
              response.usage.output_tokens * price.output) /
            1_000_000,
        },
      };
    },
  };
}

const reais = (minorUnits: unknown): number =>
  Math.round(Number(minorUnits)) / 100;

/**
 * Retrato agregado, não a lista crua de lançamentos.
 *
 * São 1.800+ transações; mandá-las inteiras custaria cerca de oito vezes mais
 * em tokens e responderia pior — "onde meu gasto cresceu" se enxerga melhor em
 * totais mensais por categoria do que em linhas individuais.
 */
async function buildFinancialContext(pool: DatabasePool, userId: string) {
  const [porMes, estabelecimentos, emprestimos, assinaturas, fixas, previ] =
    await Promise.all([
      pool.query(
        `SELECT to_char(date_trunc('month', t.occurred_at), 'YYYY-MM') AS mes,
                COALESCE(${CATEGORY_ID_SQL}, 'sem-categoria') AS categoria,
                sum(t.amount_minor_units) AS total,
                count(*) AS lancamentos
         FROM transactions t
         WHERE t.user_id = $1 AND t.direction = 'DEBIT' AND t.nature = 'EXPENSE'
         GROUP BY 1, 2
         ORDER BY 1 DESC, 3 DESC`,
        [userId],
      ),
      // O apelido definido pelo usuário tem prioridade sobre o descritor bruto:
      // é ele que junta "AIRBNB PAGAM*AIRB" e "AIRBNB PLATAF SAO PAULO".
      pool.query(
        `WITH normalizado AS (
           SELECT ${MERCHANT_NAME_SQL} AS estabelecimento,
                  date_trunc('month', t.occurred_at) AS mes,
                  t.amount_minor_units
           FROM transactions t
           WHERE t.user_id = $1 AND t.direction = 'DEBIT' AND t.nature = 'EXPENSE'
         ), ranking AS (
           SELECT estabelecimento, sum(amount_minor_units) AS total
           FROM normalizado GROUP BY 1 ORDER BY 2 DESC LIMIT 30
         )
         SELECT n.estabelecimento,
                to_char(n.mes, 'YYYY-MM') AS mes,
                sum(n.amount_minor_units) AS total,
                count(*) AS vezes
         FROM normalizado n
         JOIN ranking r ON r.estabelecimento = n.estabelecimento
         GROUP BY 1, 2
         ORDER BY 1, 2`,
        [userId],
      ),
      pool.query(
        `SELECT l.product_name, l.contract_number, l.repayment_kind,
                l.payroll_deducted, l.monthly_interest_rate,
                l.total_installments, l.next_due_date,
                (SELECT sum(i.amount_minor_units) FROM loan_installments i
                  WHERE i.loan_id = l.id AND i.status = 'OPEN'
                    AND NOT i.early_settled AND i.due_date > current_date) AS ainda_a_pagar,
                (SELECT count(*) FROM loan_installments i
                  WHERE i.loan_id = l.id AND i.status = 'OPEN'
                    AND NOT i.early_settled AND i.due_date > current_date) AS parcelas_restantes,
                (SELECT i.amount_minor_units FROM loan_installments i
                  WHERE i.loan_id = l.id AND i.status = 'OPEN'
                    AND NOT i.early_settled AND i.due_date > current_date
                  ORDER BY i.due_date LIMIT 1) AS parcela_mensal
         FROM loans l WHERE l.user_id = $1
         ORDER BY 8 DESC NULLS LAST`,
        [userId],
      ),
      pool.query(
        `SELECT name, amount_minor_units FROM subscriptions WHERE user_id = $1`,
        [userId],
      ),
      pool.query(
        `SELECT name, amount_minor_units FROM fixed_expenses WHERE user_id = $1`,
        [userId],
      ),
      pool.query(
        `SELECT p.provider_name, p.profile_name,
                s.closing_balance_minor_units AS saldo_parcial,
                p.participant_reserve_minor_units + p.employer_reserve_minor_units AS saldo_reservas
         FROM pension_positions p
         LEFT JOIN LATERAL (
           SELECT closing_balance_minor_units FROM pension_monthly_snapshots
           WHERE pension_position_id = p.id ORDER BY reference_month DESC LIMIT 1
         ) s ON true
         WHERE p.user_id = $1`,
        [userId],
      ),
    ]);

  return {
    geradoEm: new Date().toISOString().slice(0, 10),
    moeda: "BRL",
    gastosPorMes: porMes.rows.map((r) => ({
      mes: r.mes,
      categoria: r.categoria,
      total: reais(r.total),
      lancamentos: Number(r.lancamentos),
    })),
    // Por estabelecimento E por mês: sem a dimensão de tempo não dá para
    // responder "esse gasto cresceu?", que é metade das perguntas úteis.
    maioresEstabelecimentosPorMes: estabelecimentos.rows.map((r) => ({
      estabelecimento: String(r.estabelecimento).trim(),
      mes: r.mes,
      total: reais(r.total),
      vezes: Number(r.vezes),
    })),
    emprestimos: emprestimos.rows.map((r) => ({
      produto: r.product_name,
      contrato: r.contract_number,
      tipo: r.repayment_kind,
      descontadoEmFolha: r.payroll_deducted === true,
      taxaMensalPercent: r.monthly_interest_rate == null ? null : Number(r.monthly_interest_rate),
      parcelaMensal: r.parcela_mensal == null ? null : reais(r.parcela_mensal),
      parcelasRestantes: Number(r.parcelas_restantes ?? 0),
      totalParcelas: Number(r.total_installments),
      aindaAPagar: r.ainda_a_pagar == null ? 0 : reais(r.ainda_a_pagar),
      proximoVencimento: r.next_due_date == null ? null : String(r.next_due_date).slice(0, 10),
    })),
    assinaturas: assinaturas.rows.map((r) => ({
      nome: r.name,
      mensal: r.amount_minor_units == null ? null : reais(r.amount_minor_units),
    })),
    despesasFixas: fixas.rows.map((r) => ({
      nome: r.name,
      mensal: r.amount_minor_units == null ? null : reais(r.amount_minor_units),
    })),
    previdencia: previ.rows.map((r) => ({
      provedor: r.provider_name,
      perfil: r.profile_name,
      saldo: reais(r.saldo_parcial ?? r.saldo_reservas),
    })),
  };
}
