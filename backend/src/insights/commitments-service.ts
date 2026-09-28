import { createHash } from "node:crypto";

import type { DatabasePool } from "../db/pool.js";
import { normalizeDescription } from "../domain.js";

export type InstallmentCommitment = {
  id: string;
  accountId: string;
  accountName: string;
  merchantName: string;
  purchaseDate: string;
  paidInstallments: number;
  totalInstallments: number;
  remainingInstallments: number;
  installmentAmountMinorUnits: number;
  remainingAmountMinorUnits: number;
  nextExpectedAt: string | null;
};

export type RecurringCommitment = {
  id: string;
  accountId: string;
  accountName: string;
  merchantName: string;
  categoryId: string;
  averageAmountMinorUnits: number;
  lastAmountMinorUnits: number;
  occurrences: number;
  lastChargedAt: string;
  nextExpectedAt: string;
  regularityScore: number;
  confidence: "HIGH" | "MEDIUM";
};

export type CommitmentsSummary = {
  generatedAt: string;
  monthlyInstallmentsMinorUnits: number;
  remainingInstallmentsMinorUnits: number;
  estimatedRecurringMonthlyMinorUnits: number;
  installments: InstallmentCommitment[];
  recurring: RecurringCommitment[];
};

export type CommitmentTransactionRow = {
  accountId: string;
  accountName: string;
  description: string;
  merchantName: string;
  amountMinorUnits: number;
  occurredAt: string;
  providerStatus: "POSTED" | "PENDING" | null;
  categoryId: string;
  creditCard: Record<string, unknown> | null;
  accountBalanceDueDate?: string | null;
  statementDueDate?: string | null;
  statementStatus?: "OPEN" | "PAID" | "OVERDUE" | null;
};

export interface CommitmentsService {
  getSummary(userId: string): Promise<CommitmentsSummary>;
}

export type VerifiedInstallmentRow = {
  statementId: string;
  accountId: string;
  accountName: string;
  dueDate: string;
  status: "OPEN" | "PAID" | "OVERDUE";
  futureInstallmentsMinorUnits: number;
  lineIndex: number;
  merchantName: string;
  purchaseDate: string | null;
  installmentNumber: number;
  totalInstallments: number;
  amountMinorUnits: number;
};

export function createCommitmentsService(pool: DatabasePool): CommitmentsService {
  return {
    async getSummary(userId) {
      const result = await pool.query(
        `SELECT
           t.account_id AS "accountId",
           a.name AS "accountName",
           t.description,
           t.merchant_name AS "merchantName",
           t.amount_minor_units AS "amountMinorUnits",
           t.occurred_at AS "occurredAt",
           t.provider_status AS "providerStatus",
           t.category_id AS "categoryId",
           t.provider_metadata->'creditCard' AS "creditCard",
           a.balance_due_date AS "accountBalanceDueDate",
           statement.due_date AS "statementDueDate",
           statement.status AS "statementStatus"
         FROM transactions t
         JOIN accounts a ON a.id = t.account_id AND a.user_id = t.user_id
         LEFT JOIN LATERAL (
           SELECT due_date, status
           FROM credit_card_statements
           WHERE user_id = t.user_id AND account_id = t.account_id
           ORDER BY statement_month DESC
           LIMIT 1
         ) statement ON true
         WHERE t.user_id = $1
           AND t.direction = 'DEBIT'
           AND t.nature = 'EXPENSE'
           AND NOT (t.source = 'PLUGGY' AND a.type = 'CREDIT_CARD')
           AND t.occurred_at >= now() - interval '13 months'
         ORDER BY t.occurred_at ASC`,
        [userId],
      );
      const analyzed = analyzeCommitments(
        result.rows.map((row) => ({
          ...row,
          amountMinorUnits: Number(row.amountMinorUnits),
          occurredAt:
            row.occurredAt instanceof Date
              ? row.occurredAt.toISOString()
              : new Date(String(row.occurredAt)).toISOString(),
          accountBalanceDueDate: asOptionalIsoDate(row.accountBalanceDueDate),
          statementDueDate: asOptionalIsoDate(row.statementDueDate),
        })) as CommitmentTransactionRow[],
      );
      const verified = await pool.query(
        `SELECT
           statement.id AS "statementId",
           statement.account_id AS "accountId",
           account.name AS "accountName",
           statement.due_date AS "dueDate",
           statement.status,
           statement.future_installments_minor_units AS "futureInstallmentsMinorUnits",
           item.line_index AS "lineIndex",
           item.merchant_name AS "merchantName",
           item.purchase_date AS "purchaseDate",
           item.installment_number AS "installmentNumber",
           item.total_installments AS "totalInstallments",
           item.amount_minor_units AS "amountMinorUnits"
         FROM credit_card_statements statement
         JOIN accounts account ON account.id = statement.account_id
         JOIN credit_card_statement_installments item
           ON item.statement_id = statement.id
         WHERE statement.user_id = $1
           AND statement.statement_month = (
             SELECT max(latest.statement_month)
             FROM credit_card_statements latest
             WHERE latest.user_id = statement.user_id
               AND latest.account_id = statement.account_id
           )
         ORDER BY statement.account_id, item.line_index`,
        [userId],
      );
      return applyVerifiedInstallments(
        analyzed,
        verified.rows.map((row) => ({
          ...row,
          dueDate: new Date(String(row.dueDate)).toISOString().slice(0, 10),
          purchaseDate:
            row.purchaseDate == null
              ? null
              : new Date(String(row.purchaseDate)).toISOString().slice(0, 10),
          futureInstallmentsMinorUnits: Number(row.futureInstallmentsMinorUnits),
          lineIndex: Number(row.lineIndex),
          installmentNumber: Number(row.installmentNumber),
          totalInstallments: Number(row.totalInstallments),
          amountMinorUnits: Number(row.amountMinorUnits),
        })) as VerifiedInstallmentRow[],
        new Date(),
      );
    },
  };
}

export function applyVerifiedInstallments(
  summary: CommitmentsSummary,
  rows: VerifiedInstallmentRow[],
  now = new Date(),
): CommitmentsSummary {
  if (rows.length === 0) return summary;
  const verifiedAccountIds = new Set(rows.map((row) => row.accountId));
  const heuristicInstallments = summary.installments.filter(
    (item) => !verifiedAccountIds.has(item.accountId),
  );
  const statementGroups = new Map<string, VerifiedInstallmentRow[]>();
  for (const row of rows) {
    const group = statementGroups.get(row.statementId) ?? [];
    group.push(row);
    statementGroups.set(row.statementId, group);
  }

  const verifiedInstallments: InstallmentCommitment[] = [];
  let verifiedMonthly = 0;
  let verifiedRemaining = 0;
  for (const statementRows of statementGroups.values()) {
    const statement = statementRows[0]!;
    const open = statement.status !== "PAID";
    const next = nextVerifiedDueDate(statement.dueDate, statement.status, now);
    // Enquanto a fatura seguinte não é importada, vencimento que já passou conta
    // como pago, como na baixa das parcelas de empréstimo. Sem isso a última
    // parcela nunca saía: o vencimento só era empurrado para o mês seguinte.
    // Fatura marcada em atraso é a exceção, porque ali se sabe que não houve pagamento.
    const settledByDate = statement.status === "OVERDUE" ? 0 : next.elapsedDueDates;
    // Em fatura aberta, o primeiro vencimento baixado é o da própria fatura.
    const settledFutureDueDates = open ? Math.max(settledByDate - 1, 0) : settledByDate;
    const currentOpenAmount = open && settledByDate === 0
      ? statementRows.reduce((sum, item) => sum + item.amountMinorUnits, 0)
      : 0;
    const settledFutureAmount = statementRows.reduce(
      (sum, item) =>
        sum +
        item.amountMinorUnits *
          Math.min(settledFutureDueDates, item.totalInstallments - item.installmentNumber),
      0,
    );
    verifiedRemaining +=
      Math.max(statement.futureInstallmentsMinorUnits - settledFutureAmount, 0) +
      currentOpenAmount;

    for (const item of statementRows) {
      const billedAndPaid = open
        ? Math.max(item.installmentNumber - 1, 0)
        : item.installmentNumber;
      const paidInstallments = Math.min(
        item.totalInstallments,
        billedAndPaid + settledByDate,
      );
      const remainingInstallments = item.totalInstallments - paidInstallments;
      if (remainingInstallments === 0) continue;
      verifiedMonthly += item.amountMinorUnits;
      verifiedInstallments.push({
        id: stableId("verified-installment", `${item.statementId}|${item.lineIndex}`),
        accountId: item.accountId,
        accountName: item.accountName,
        merchantName: cleanInstallmentLabel(item.merchantName),
        purchaseDate: item.purchaseDate ?? statement.dueDate,
        paidInstallments,
        totalInstallments: item.totalInstallments,
        remainingInstallments,
        installmentAmountMinorUnits: item.amountMinorUnits,
        remainingAmountMinorUnits: item.amountMinorUnits * remainingInstallments,
        nextExpectedAt: next.dueDate,
      });
    }
  }

  return {
    ...summary,
    monthlyInstallmentsMinorUnits:
      heuristicInstallments.reduce(
        (sum, item) => sum + item.installmentAmountMinorUnits,
        0,
      ) + verifiedMonthly,
    remainingInstallmentsMinorUnits:
      heuristicInstallments.reduce(
        (sum, item) => sum + item.remainingAmountMinorUnits,
        0,
      ) + verifiedRemaining,
    installments: [...verifiedInstallments, ...heuristicInstallments].sort((a, b) =>
      (a.nextExpectedAt ?? "9999").localeCompare(b.nextExpectedAt ?? "9999"),
    ),
  };
}

export function analyzeCommitments(
  rows: CommitmentTransactionRow[],
  now = new Date(),
): CommitmentsSummary {
  const installments = analyzeInstallments(rows, now);
  const recurring = analyzeRecurring(rows, now);
  return {
    generatedAt: now.toISOString(),
    monthlyInstallmentsMinorUnits: installments.reduce(
      (sum, item) => sum + item.installmentAmountMinorUnits,
      0,
    ),
    remainingInstallmentsMinorUnits: installments.reduce(
      (sum, item) => sum + item.remainingAmountMinorUnits,
      0,
    ),
    estimatedRecurringMonthlyMinorUnits: recurring.reduce(
      (sum, item) => sum + item.averageAmountMinorUnits,
      0,
    ),
    installments,
    recurring,
  };
}

function analyzeInstallments(
  rows: CommitmentTransactionRow[],
  now: Date,
): InstallmentCommitment[] {
  const groups = new Map<string, Array<CommitmentTransactionRow & {
    installmentNumber: number;
    totalInstallments: number;
    purchaseDate: string;
  }>>();

  for (const row of rows) {
    const metadata = row.creditCard;
    const installmentNumber = asPositiveInteger(metadata?.installmentNumber);
    const totalInstallments = asPositiveInteger(metadata?.totalInstallments);
    const purchaseDate = asDate(metadata?.purchaseDate);
    if (!installmentNumber || !totalInstallments || !purchaseDate) continue;
    const cardNumber = String(metadata?.cardNumber ?? "");
    const key = [
      row.accountId,
      cardNumber,
      purchaseDate.slice(0, 10),
      totalInstallments,
      row.amountMinorUnits,
    ].join("|");
    const group = groups.get(key) ?? [];
    group.push({ ...row, installmentNumber, totalInstallments, purchaseDate });
    groups.set(key, group);
  }

  const result: InstallmentCommitment[] = [];
  for (const [key, group] of groups) {
    const latest = [...group].sort((a, b) => b.installmentNumber - a.installmentNumber)[0]!;
    const latestPostedInstallment = Math.max(
      0,
      ...group
        .filter((item) => item.providerStatus === "POSTED")
        .map((item) => item.installmentNumber),
    );
    const paidInstallments =
      latest.statementStatus === "OPEN" || latest.statementStatus === "OVERDUE"
        ? Math.max(latestPostedInstallment - 1, 0)
        : latestPostedInstallment;
    const remainingInstallments = Math.max(
      latest.totalInstallments - paidInstallments,
      0,
    );
    if (remainingInstallments === 0) continue;
    const nextPending = [...group]
      .filter((item) => item.providerStatus === "PENDING")
      .sort((a, b) => a.installmentNumber - b.installmentNumber)[0];
    const lastPosted = [...group]
      .filter((item) => item.providerStatus === "POSTED")
      .sort((a, b) => b.installmentNumber - a.installmentNumber)[0];
    const nextExpectedAt = calculateNextDueDate(
      latest,
      now,
      nextPending?.occurredAt ?? (lastPosted ? addUtcMonth(lastPosted.occurredAt) : null),
    );
    result.push({
      id: stableId("installment", key),
      accountId: latest.accountId,
      accountName: latest.accountName,
      merchantName: cleanInstallmentLabel(latest.merchantName || latest.description),
      purchaseDate: latest.purchaseDate,
      paidInstallments,
      totalInstallments: latest.totalInstallments,
      remainingInstallments,
      installmentAmountMinorUnits: latest.amountMinorUnits,
      remainingAmountMinorUnits: latest.amountMinorUnits * remainingInstallments,
      nextExpectedAt,
    });
  }
  return result.sort((a, b) =>
    (a.nextExpectedAt ?? "9999").localeCompare(b.nextExpectedAt ?? "9999"),
  );
}

function analyzeRecurring(
  rows: CommitmentTransactionRow[],
  now: Date,
): RecurringCommitment[] {
  const groups = new Map<string, CommitmentTransactionRow[]>();
  for (const row of rows) {
    if (row.creditCard && asPositiveInteger(row.creditCard.installmentNumber)) continue;
    if (row.providerStatus !== "POSTED") continue;
    const merchant = normalizeDescription(row.merchantName || row.description);
    const key = `${row.accountId}|${merchant}`;
    const group = groups.get(key) ?? [];
    group.push(row);
    groups.set(key, group);
  }

  const result: RecurringCommitment[] = [];
  for (const [key, group] of groups) {
    if (group.length < 3) continue;
    const ordered = [...group].sort((a, b) => a.occurredAt.localeCompare(b.occurredAt));
    const monthKeys = ordered.map((item) => item.occurredAt.slice(0, 7));
    if (new Set(monthKeys).size !== monthKeys.length) continue;
    const intervals = ordered.slice(1).map((item, index) =>
      daysBetween(ordered[index]!.occurredAt, item.occurredAt),
    );
    if (intervals.some((days) => days < 25 || days > 35)) continue;
    const amounts = ordered.map((item) => item.amountMinorUnits);
    const average = Math.round(amounts.reduce((sum, value) => sum + value, 0) / amounts.length);
    const amountVariation = average === 0 ? 1 : (Math.max(...amounts) - Math.min(...amounts)) / average;
    if (amountVariation > 0.1) continue;
    const latest = ordered.at(-1)!;
    if (daysBetween(latest.occurredAt, now.toISOString()) > 45) continue;
    const averageInterval = intervals.reduce((sum, value) => sum + value, 0) / intervals.length;
    const timingScore = 1 - Math.min(Math.abs(30 - averageInterval) / 5, 1);
    const amountScore = 1 - Math.min(amountVariation / 0.1, 1);
    const regularityScore = roundScore(timingScore * 0.6 + amountScore * 0.4);
    if (regularityScore < 0.6) continue;
    const categoryBoost = latest.categoryId.startsWith("subscriptions");
    result.push({
      id: stableId("recurring", key),
      accountId: latest.accountId,
      accountName: latest.accountName,
      merchantName: cleanInstallmentLabel(latest.merchantName || latest.description),
      categoryId: latest.categoryId,
      averageAmountMinorUnits: average,
      lastAmountMinorUnits: latest.amountMinorUnits,
      occurrences: ordered.length,
      lastChargedAt: latest.occurredAt,
      nextExpectedAt: addUtcMonth(latest.occurredAt),
      regularityScore,
      confidence: categoryBoost || regularityScore >= 0.85 ? "HIGH" : "MEDIUM",
    });
  }
  return result.sort((a, b) => b.regularityScore - a.regularityScore);
}

function asPositiveInteger(value: unknown): number | null {
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : null;
}

function asDate(value: unknown): string | null {
  if (typeof value !== "string" || Number.isNaN(Date.parse(value))) return null;
  return new Date(value).toISOString();
}

function asOptionalIsoDate(value: unknown): string | null {
  if (value == null || Number.isNaN(Date.parse(String(value)))) return null;
  return new Date(String(value)).toISOString();
}

function daysBetween(first: string, second: string): number {
  return Math.abs(Date.parse(second) - Date.parse(first)) / 86_400_000;
}

function addUtcMonth(value: string): string {
  const date = new Date(value);
  const targetMonth = date.getUTCMonth() + 1;
  const lastDay = new Date(Date.UTC(date.getUTCFullYear(), targetMonth + 1, 0)).getUTCDate();
  return new Date(Date.UTC(
    date.getUTCFullYear(),
    targetMonth,
    Math.min(date.getUTCDate(), lastDay),
    date.getUTCHours(),
    date.getUTCMinutes(),
    date.getUTCSeconds(),
    date.getUTCMilliseconds(),
  )).toISOString();
}

function calculateNextDueDate(
  row: CommitmentTransactionRow,
  now: Date,
  fallback: string | null,
): string | null {
  const verifiedDueDate = row.statementDueDate;
  if (verifiedDueDate) {
    let candidate = new Date(verifiedDueDate);
    if (row.statementStatus === "PAID") candidate = new Date(addUtcMonth(candidate.toISOString()));
    while (candidate.getTime() < startOfUtcDay(now).getTime()) {
      candidate = new Date(addUtcMonth(candidate.toISOString()));
    }
    return formatDateOnly(candidate);
  }

  const accountDueDate = row.accountBalanceDueDate;
  if (accountDueDate) {
    const dueDay = new Date(accountDueDate).getUTCDate();
    let candidate = dateWithDay(now.getUTCFullYear(), now.getUTCMonth(), dueDay);
    if (candidate.getTime() < startOfUtcDay(now).getTime()) {
      candidate = dateWithDay(now.getUTCFullYear(), now.getUTCMonth() + 1, dueDay);
    }
    return formatDateOnly(candidate);
  }

  if (!fallback) return null;
  let candidate = new Date(fallback);
  while (candidate.getTime() < startOfUtcDay(now).getTime()) {
    candidate = new Date(addUtcMonth(candidate.toISOString()));
  }
  return formatDateOnly(candidate);
}

/**
 * Próximo vencimento a partir da última fatura importada e quantos vencimentos
 * já passaram desde a primeira parcela que ela deixou em aberto.
 */
function nextVerifiedDueDate(
  dueDate: string,
  status: "OPEN" | "PAID" | "OVERDUE",
  now: Date,
): { dueDate: string; elapsedDueDates: number } {
  let candidate = new Date(`${dueDate}T12:00:00.000Z`);
  if (status === "PAID") candidate = new Date(addUtcMonth(candidate.toISOString()));
  let elapsedDueDates = 0;
  while (candidate.getTime() < startOfUtcDay(now).getTime()) {
    candidate = new Date(addUtcMonth(candidate.toISOString()));
    elapsedDueDates += 1;
  }
  return { dueDate: formatDateOnly(candidate), elapsedDueDates };
}

function dateWithDay(year: number, month: number, day: number): Date {
  const lastDay = new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
  return new Date(Date.UTC(year, month, Math.min(day, lastDay)));
}

function startOfUtcDay(value: Date): Date {
  return new Date(Date.UTC(value.getUTCFullYear(), value.getUTCMonth(), value.getUTCDate()));
}

function formatDateOnly(value: Date): string {
  return value.toISOString().slice(0, 10);
}

function cleanInstallmentLabel(value: string): string {
  return value
    .replace(/\b(?:PARC(?:ELA)?\s*)?\d{1,2}\s*[\/-]\s*\d{1,2}\b/giu, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function stableId(kind: string, value: string): string {
  return createHash("sha256").update(`${kind}|${value}`).digest("hex").slice(0, 24);
}

function roundScore(value: number): number {
  return Math.round(value * 1000) / 1000;
}
