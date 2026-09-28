import assert from "node:assert/strict";
import { test } from "node:test";

import {
  applyVerifiedInstallments,
  analyzeCommitments,
  type CommitmentTransactionRow,
} from "../src/insights/commitments-service.js";

function row(
  occurredAt: string,
  amountMinorUnits: number,
  overrides: Partial<CommitmentTransactionRow> = {},
): CommitmentTransactionRow {
  return {
    accountId: "card-1",
    accountName: "Cartão Visa",
    description: "SERVICO",
    merchantName: "Serviço",
    amountMinorUnits,
    occurredAt,
    providerStatus: "POSTED",
    categoryId: "subscriptions-streaming",
    creditCard: null,
    ...overrides,
  };
}

test("agrupa parcelas e calcula valor e quantidade restantes", () => {
  const purchaseDate = "2026-01-10T00:00:00.000Z";
  const rows = [1, 2, 3].map((installmentNumber) =>
    row(`2026-0${installmentNumber}-10T00:00:00.000Z`, 10_000, {
      description: `LOJA ${installmentNumber}/6`,
      merchantName: `LOJA ${installmentNumber}/6`,
      providerStatus: installmentNumber === 3 ? "PENDING" : "POSTED",
      creditCard: {
        cardNumber: "1234",
        purchaseDate,
        installmentNumber,
        totalInstallments: 6,
      },
    }),
  );

  const summary = analyzeCommitments(rows, new Date("2026-03-01T00:00:00.000Z"));

  assert.equal(summary.installments.length, 1);
  assert.equal(summary.installments[0]?.paidInstallments, 2);
  assert.equal(summary.installments[0]?.remainingInstallments, 4);
  assert.equal(summary.installments[0]?.remainingAmountMinorUnits, 40_000);
  assert.equal(summary.installments[0]?.merchantName, "LOJA");
});

test("detecta recorrência mensal estável com confiança explícita", () => {
  const rows = [
    row("2026-06-15T00:00:00.000Z", 2_990),
    row("2026-07-15T00:00:00.000Z", 2_990),
    row("2026-08-14T00:00:00.000Z", 3_090),
  ];

  const summary = analyzeCommitments(rows, new Date("2026-08-14T12:00:00.000Z"));

  assert.equal(summary.recurring.length, 1);
  assert.equal(summary.recurring[0]?.confidence, "HIGH");
  assert.equal(summary.recurring[0]?.occurrences, 3);
  assert.equal(summary.estimatedRecurringMonthlyMinorUnits, 3_023);
});

test("não classifica compras frequentes e irregulares como assinatura", () => {
  const rows = [
    row("2026-06-01T00:00:00.000Z", 2_000),
    row("2026-06-10T00:00:00.000Z", 2_000),
    row("2026-07-01T00:00:00.000Z", 4_000),
  ];

  const summary = analyzeCommitments(rows, new Date("2026-08-01T00:00:00.000Z"));
  assert.equal(summary.recurring.length, 0);
});

test("fatura aberta mantém a parcela atual pendente no vencimento verificado", () => {
  const summary = analyzeCommitments(
    [
      row("2026-05-14T00:00:00.000Z", 23_000, {
        description: "COMPRA PARC 03/03",
        merchantName: "COMPRA PARC 03/03",
        statementDueDate: "2026-08-20T00:00:00.000Z",
        statementStatus: "OPEN",
        creditCard: {
          cardNumber: "1112",
          purchaseDate: "2026-05-14T00:00:00.000Z",
          installmentNumber: 3,
          totalInstallments: 3,
        },
      }),
    ],
    new Date("2026-08-14T12:00:00.000Z"),
  );

  assert.equal(summary.installments[0]?.paidInstallments, 2);
  assert.equal(summary.installments[0]?.remainingInstallments, 1);
  assert.equal(summary.installments[0]?.nextExpectedAt, "2026-08-20");
});

test("fatura paga avança a próxima parcela para o vencimento seguinte", () => {
  const summary = analyzeCommitments(
    [
      row("2026-03-04T00:00:00.000Z", 60_000, {
        description: "COMPRA PARC 05/12",
        merchantName: "COMPRA PARC 05/12",
        statementDueDate: "2026-08-05T00:00:00.000Z",
        statementStatus: "PAID",
        creditCard: {
          cardNumber: "2507",
          purchaseDate: "2026-03-04T00:00:00.000Z",
          installmentNumber: 5,
          totalInstallments: 12,
        },
      }),
    ],
    new Date("2026-08-14T12:00:00.000Z"),
  );

  assert.equal(summary.installments[0]?.paidInstallments, 5);
  assert.equal(summary.installments[0]?.remainingInstallments, 7);
  assert.equal(summary.installments[0]?.nextExpectedAt, "2026-09-05");
});

test("parcelas verificadas substituem heurísticas e respeitam o estado da fatura", () => {
  const base = analyzeCommitments([], new Date("2026-08-14T12:00:00.000Z"));
  const summary = applyVerifiedInstallments(
    base,
    [
      {
        statementId: "statement-visa",
        accountId: "card-visa",
        accountName: "Visa",
        dueDate: "2026-08-20",
        status: "OPEN",
        futureInstallmentsMinorUnits: 10_000,
        lineIndex: 1,
        merchantName: "LOJA PARC 03/03",
        purchaseDate: "2026-05-14",
        installmentNumber: 3,
        totalInstallments: 3,
        amountMinorUnits: 5_000,
      },
    ],
    new Date("2026-08-14T12:00:00.000Z"),
  );

  assert.equal(summary.installments.length, 1);
  assert.equal(summary.installments[0]?.paidInstallments, 2);
  assert.equal(summary.installments[0]?.remainingInstallments, 1);
  assert.equal(summary.installments[0]?.nextExpectedAt, "2026-08-20");
  assert.equal(summary.remainingInstallmentsMinorUnits, 15_000);
});

/** Fatura paga com vencimento em 05/08 e duas compras parceladas. */
function paidAugustStatement(status: "PAID" | "OVERDUE") {
  return [
    {
      statementId: "statement-elo",
      accountId: "card-elo",
      accountName: "Elo",
      dueDate: "2026-08-05",
      status,
      // 199,90 da última parcela mais 6 x 111,09.
      futureInstallmentsMinorUnits: 19_990 + 6 * 11_109,
      lineIndex: 1,
      merchantName: "Grupo Casas B PARC 09/10",
      purchaseDate: "2025-10-26",
      installmentNumber: 9,
      totalInstallments: 10,
      amountMinorUnits: 19_990,
    },
    {
      statementId: "statement-elo",
      accountId: "card-elo",
      accountName: "Elo",
      dueDate: "2026-08-05",
      status,
      futureInstallmentsMinorUnits: 19_990 + 6 * 11_109,
      lineIndex: 2,
      merchantName: "Mercado Livre PARC 06/12",
      purchaseDate: "2026-03-10",
      installmentNumber: 6,
      totalInstallments: 12,
      amountMinorUnits: 11_109,
    },
  ];
}

test("vencimento que passou sem fatura nova dá baixa e encerra o parcelamento", () => {
  const base = analyzeCommitments([], new Date("2026-09-16T12:00:00.000Z"));
  // A fatura de 05/09 não foi importada, mas o vencimento já passou.
  const summary = applyVerifiedInstallments(
    base,
    paidAugustStatement("PAID"),
    new Date("2026-09-16T12:00:00.000Z"),
  );

  // A 10/10 venceu em 05/09: a Casas Bahia sai, em vez de reaparecer em outubro.
  assert.equal(summary.installments.length, 1);
  assert.equal(summary.installments[0]?.merchantName, "Mercado Livre");
  assert.equal(summary.installments[0]?.paidInstallments, 7);
  assert.equal(summary.installments[0]?.remainingInstallments, 5);
  assert.equal(summary.installments[0]?.nextExpectedAt, "2026-10-05");
  assert.equal(summary.monthlyInstallmentsMinorUnits, 11_109);
  assert.equal(summary.remainingInstallmentsMinorUnits, 5 * 11_109);
});

test("fatura em atraso não dá baixa sozinha pela data", () => {
  const base = analyzeCommitments([], new Date("2026-09-16T12:00:00.000Z"));
  const summary = applyVerifiedInstallments(
    base,
    paidAugustStatement("OVERDUE"),
    new Date("2026-09-16T12:00:00.000Z"),
  );

  // Sabidamente sem pagamento: a parcela da própria fatura continua devida.
  assert.equal(summary.installments.length, 2);
  assert.equal(summary.installments[0]?.paidInstallments, 8);
  assert.equal(summary.installments[0]?.remainingInstallments, 2);
});
