import { createHash, randomUUID } from "node:crypto";
import { execFile } from "node:child_process";
import { mkdtemp, readdir, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { basename, join } from "node:path";
import { promisify } from "node:util";
import type { PoolClient } from "pg";

import type { DatabasePool } from "../db/pool.js";

const execFileAsync = promisify(execFile);

export type PdfDocumentKind = "LOAN" | "PENSION";

export type PdfImportInput = {
  kind: PdfDocumentKind;
  fileName: string;
  contentBase64: string;
};

export type LoanInstallmentPreview = {
  number: number;
  dueDate: string;
  status: "PAID" | "OPEN";
  paymentKind: "REGULAR" | "AMORTIZED" | "PENDING";
  amountMinorUnits: number;
  /** Quitada à mão antes do dia do débito; não vem do extrato. */
  earlySettled: boolean;
};

export type LoanPreview = {
  /** Nulo no preview do PDF, preenchido depois que o empréstimo é salvo. */
  id: string | null;
  providerName: string;
  productName: string;
  contractNumber: string;
  documentDate: string;
  contractDate: string;
  currentBalanceMinorUnits: number;
  originalTotalMinorUnits: number;
  debitDay: number;
  monthlyInterestRate: number | null;
  annualInterestRate: number | null;
  monthlyEffectiveCost: number | null;
  annualEffectiveCost: number | null;
  repaymentKind: "MONTHLY" | "THIRTEENTH_SALARY";
  payrollDeducted: boolean;
  totalInstallments: number;
  paidInstallments: number;
  remainingInstallments: number;
  amortizedInstallments: number;
  nextDueDate: string | null;
  projectedEndDate: string | null;
  /** Soma nominal das parcelas ainda em aberto: desembolso futuro total. */
  remainingPaymentsMinorUnits: number;
  /** Valor presente das parcelas em aberto: quanto custaria quitar hoje. */
  payoffMinorUnits: number;
  installments: LoanInstallmentPreview[];
};

export type PayrollSummary = {
  referenceMonth: string;
  regularNetReferenceMinorUnits: number;
  excludedDeductionMinorUnits: number;
  exclusionEffectiveFrom: string | null;
  correctedNetEstimateMinorUnits: number;
  ownPayrollLoanDeductionsMinorUnits: number;
  ownPayrollLoanCount: number;
};

export type PensionHistoryPreview = {
  referenceMonth: string;
  openingBalanceMinorUnits: number;
  returnsMinorUnits: number;
  employerPart2aMinorUnits: number;
  employerPart2bMinorUnits: number;
  participantPart2aMinorUnits: number;
  participantPart2bMinorUnits: number;
  participantPart2cMinorUnits: number;
  personalPortabilityMinorUnits: number;
  employerPortabilityMinorUnits: number;
  closingBalanceMinorUnits: number;
};

export type PensionPreview = {
  id: string | null;
  providerName: string;
  profileName: string;
  taxRegime: string | null;
  enrollmentDate: string | null;
  balanceDate: string;
  updatedThrough: string | null;
  currentBalanceMinorUnits: number;
  partOneBalanceMinorUnits: number;
  participantReserveMinorUnits: number;
  employerReserveMinorUnits: number;
  monthlyReturn: number | null;
  yearlyReturn: number | null;
  twelveMonthReturn: number | null;
  latestSnapshot: PensionMonthlySnapshot | null;
  history: PensionHistoryPreview[];
};

export type PensionProjectionPoint = {
  year: number;
  projectedBalanceMinorUnits: number;
  projectedParticipantReserveMinorUnits: number;
  projectedEmployerReserveMinorUnits: number;
  grossWithdrawableMinorUnits: number;
  employerEligibleRate: number;
  projectedContributionCount: number;
};

export type PensionMonthlySnapshot = {
  referenceMonth: string;
  asOfDate: string;
  accumulatedReturnMinorUnits: number;
  closingBalanceMinorUnits: number;
  /** Contribuição do mês já lançada manualmente sobre a posição da PREVI. */
  contributionApplied: boolean;
  /** Mediana das últimas contribuições, oferecida para lançamento na tela. */
  projectedContributionMinorUnits: number;
};

export type PensionMonthlySnapshotInput = Omit<
  PensionMonthlySnapshot,
  "closingBalanceMinorUnits" | "projectedContributionMinorUnits"
>;

export type PensionProjection = {
  pensionId: string;
  sourceUpdatedThrough: string;
  monthlyReturnRateUsed: number;
  annualizedReturnRate: number;
  averageParticipantContributionMinorUnits: number;
  averageEmployerContributionMinorUnits: number;
  currentContributionCount: number;
  partOneBalanceMinorUnits: number;
  currentPartTwoBalanceMinorUnits: number;
  currentGrossWithdrawableMinorUnits: number;
  currentEmployerEligibleRate: number;
  latestSnapshot: PensionMonthlySnapshot | null;
  returnOverrides: Array<{ referenceMonth: string; returnRate: number }>;
  points: PensionProjectionPoint[];
  notices: string[];
};

export type FinancialDocumentPreview = {
  kind: PdfDocumentKind;
  fileName: string;
  documentSha256: string;
  warnings: string[];
  data: LoanPreview | PensionPreview;
};

/**
 * Quitação antecipada em contagens, não em números de parcela: é assim que o
 * banco oferece ("as N da frente, as M de trás") e torna a operação idempotente
 * — reenviar front=0/back=0 desfaz o lançamento.
 */
export type LoanEarlySettlementInput = {
  /** Próximas parcelas do cronograma quitadas adiantado. */
  front: number;
  /** Últimas parcelas do cronograma, amortizadas pela cauda. */
  back: number;
};

export interface FinancialDocumentService {
  preview(input: PdfImportInput): Promise<FinancialDocumentPreview>;
  import(userId: string, input: PdfImportInput): Promise<FinancialDocumentPreview>;
  listLoans(userId: string): Promise<LoanPreview[]>;
  setLoanEarlySettlement(
    userId: string,
    loanId: string,
    input: LoanEarlySettlementInput,
  ): Promise<LoanPreview | null>;
  getPayrollSummary(userId: string): Promise<PayrollSummary | null>;
  listPensions(userId: string): Promise<PensionPreview[]>;
  getPensionProjection(
    userId: string,
    pensionId: string,
    horizonYears?: number,
  ): Promise<PensionProjection | null>;
  savePensionReturn(
    userId: string,
    pensionId: string,
    referenceMonth: string,
    returnRate: number,
  ): Promise<PensionProjection | null>;
  savePensionSnapshot(
    userId: string,
    pensionId: string,
    input: PensionMonthlySnapshotInput,
  ): Promise<PensionProjection | null>;
  getPortfolio(userId: string): Promise<{
    assets: Array<{
      id: string;
      name: string;
      assetClass: "PENSION";
      currentValueMinorUnits: number;
      isLiquid: false;
    }>;
    liabilities: Array<{
      id: string;
      name: string;
      outstandingBalanceMinorUnits: number;
    }>;
  }>;
}

export function createFinancialDocumentService(
  pool: DatabasePool,
): FinancialDocumentService {
  return {
    preview: parsePdfInput,
    async import(userId, input) {
      const preview = await parsePdfInput(input);
      const client = await pool.connect();
      try {
        await client.query("BEGIN");
        const imported = await client.query<{ id: string }>(
          `INSERT INTO financial_document_imports (
             user_id, kind, file_name, document_sha256, document_date, parsed_data
           ) VALUES ($1, $2, $3, $4, $5, $6::jsonb)
           ON CONFLICT (user_id, kind, document_sha256)
           DO UPDATE SET file_name = EXCLUDED.file_name, parsed_data = EXCLUDED.parsed_data
           RETURNING id`,
          [
            userId,
            preview.kind,
            preview.fileName,
            preview.documentSha256,
            preview.kind === "LOAN"
              ? (preview.data as LoanPreview).documentDate
              : (preview.data as PensionPreview).balanceDate,
            JSON.stringify(preview.data),
          ],
        );
        const importId = imported.rows[0]!.id;
        if (preview.kind === "LOAN") {
          await persistLoan(client, userId, importId, preview.data as LoanPreview);
        } else {
          await persistPension(client, userId, importId, preview.data as PensionPreview);
        }
        await client.query("COMMIT");
        return preview;
      } catch (error) {
        await client.query("ROLLBACK");
        throw error;
      } finally {
        client.release();
      }
    },
    async listLoans(userId) {
      return loadLoans(pool, userId);
    },
    async setLoanEarlySettlement(userId, loanId, input) {
      const client = await pool.connect();
      try {
        await client.query("BEGIN");
        const owned = await client.query(
          "SELECT id FROM loans WHERE id = $1 AND user_id = $2",
          [loanId, userId],
        );
        if (owned.rowCount === 0) {
          await client.query("ROLLBACK");
          return null;
        }
        // Recomeça do zero para que as contagens sejam absolutas, e não incrementais.
        await client.query(
          "UPDATE loan_installments SET early_settled = false WHERE loan_id = $1",
          [loanId],
        );
        // Elegíveis são as que o extrato deixou em aberto e cujo vencimento ainda
        // não chegou: o que já venceu é baixado pela data, não por lançamento.
        const open = await client.query<{ installment_number: number }>(
          `SELECT installment_number FROM loan_installments
           WHERE loan_id = $1 AND status = 'OPEN' AND due_date > current_date
           ORDER BY due_date, installment_number`,
          [loanId],
        );
        const numbers = open.rows.map((row) => Number(row.installment_number));
        const front = Math.max(0, Math.trunc(input.front));
        const back = Math.max(0, Math.trunc(input.back));
        if (front + back > numbers.length) {
          await client.query("ROLLBACK");
          throw new Error(
            `O contrato tem ${numbers.length} parcelas em aberto; ` +
              `${front} da frente e ${back} de trás somam ${front + back}.`,
          );
        }
        const fromFront = numbers.slice(0, front);
        const fromBack = back === 0 ? [] : numbers.slice(numbers.length - back);
        if (fromFront.length > 0) {
          await client.query(
            `UPDATE loan_installments SET early_settled = true, payment_kind = 'REGULAR'
             WHERE loan_id = $1 AND installment_number = ANY($2::int[])`,
            [loanId, fromFront],
          );
        }
        if (fromBack.length > 0) {
          // Quitar a cauda encurta o contrato: é amortização, não parcela adiantada.
          await client.query(
            `UPDATE loan_installments SET early_settled = true, payment_kind = 'AMORTIZED'
             WHERE loan_id = $1 AND installment_number = ANY($2::int[])`,
            [loanId, fromBack],
          );
        }
        await client.query(
          `UPDATE loans SET amortized_installments = (
             SELECT count(*) FROM loan_installments
             WHERE loan_id = $1 AND payment_kind = 'AMORTIZED'
               AND (status = 'PAID' OR early_settled)
           ), updated_at = now() WHERE id = $1`,
          [loanId],
        );
        await client.query("COMMIT");
      } catch (error) {
        await client.query("ROLLBACK").catch(() => {});
        throw error;
      } finally {
        client.release();
      }
      const loans = await loadLoans(pool, userId);
      return loans.find((loan) => loan.id === loanId) ?? null;
    },
    async getPayrollSummary(userId) {
      const result = await pool.query(
        `SELECT
           profile.reference_month,
           profile.regular_net_reference_minor_units,
           profile.excluded_deduction_minor_units,
           profile.exclusion_effective_from,
           COALESCE(sum(next_installment.amount_minor_units), 0) AS own_payroll_loan_deductions_minor_units,
           count(next_installment.loan_id) AS own_payroll_loan_count
         FROM payroll_profiles profile
         LEFT JOIN LATERAL (
           SELECT loan.id AS loan_id, installment.amount_minor_units
           FROM loans loan
           JOIN LATERAL (
             SELECT amount_minor_units
             FROM loan_installments
             WHERE loan_id = loan.id AND status = 'OPEN'
               AND due_date > current_date
             ORDER BY due_date, installment_number
             LIMIT 1
           ) installment ON true
           WHERE loan.user_id = profile.user_id
             AND loan.payroll_deducted = true
             AND loan.repayment_kind = 'MONTHLY'
         ) next_installment ON true
         WHERE profile.user_id = $1
         GROUP BY profile.user_id`,
        [userId],
      );
      const row = result.rows[0];
      if (!row) return null;
      const regularNet = Number(row.regular_net_reference_minor_units);
      const excluded = Number(row.excluded_deduction_minor_units);
      return {
        referenceMonth: dateOnly(row.reference_month)!,
        regularNetReferenceMinorUnits: regularNet,
        excludedDeductionMinorUnits: excluded,
        exclusionEffectiveFrom: dateOnly(row.exclusion_effective_from),
        correctedNetEstimateMinorUnits: regularNet + excluded,
        ownPayrollLoanDeductionsMinorUnits: Number(
          row.own_payroll_loan_deductions_minor_units,
        ),
        ownPayrollLoanCount: Number(row.own_payroll_loan_count),
      };
    },
    async listPensions(userId) {
      return loadPensions(pool, userId);
    },
    async getPensionProjection(userId, pensionId, horizonYears = 10) {
      const pension = await loadPension(pool, userId, pensionId);
      if (!pension) return null;
      const [overrides, snapshots] = await Promise.all([
        loadPensionReturnOverrides(pool, pensionId),
        loadPensionSnapshots(pool, pensionId),
      ]);
      return buildPensionProjection(
        pension,
        overrides,
        horizonYears,
        new Date(),
        snapshots,
      );
    },
    async savePensionReturn(userId, pensionId, referenceMonth, returnRate) {
      const pension = await loadPension(pool, userId, pensionId);
      if (!pension) return null;
      await pool.query(
        `INSERT INTO pension_return_overrides (
           pension_position_id, reference_month, return_rate
         ) VALUES ($1, $2, $3)
         ON CONFLICT (pension_position_id, reference_month) DO UPDATE SET
           return_rate = EXCLUDED.return_rate, updated_at = now()`,
        [pensionId, monthStart(referenceMonth), returnRate],
      );
      const overrides = await loadPensionReturnOverrides(pool, pensionId);
      return buildPensionProjection(pension, overrides, 10);
    },
    async savePensionSnapshot(userId, pensionId, input) {
      const pension = await loadPension(pool, userId, pensionId);
      if (!pension) return null;
      const resolved = resolvePensionSnapshot(
        pension,
        {
          ...input,
          closingBalanceMinorUnits: 0,
          projectedContributionMinorUnits: 0,
        },
        new Date(),
      );
      await pool.query(
        `INSERT INTO pension_monthly_snapshots (
           pension_position_id, reference_month, as_of_date,
           accumulated_return_minor_units, closing_balance_minor_units,
           contribution_applied
         ) VALUES ($1, $2, $3, $4, $5, $6)
         ON CONFLICT (pension_position_id, reference_month) DO UPDATE SET
           as_of_date = EXCLUDED.as_of_date,
           accumulated_return_minor_units = EXCLUDED.accumulated_return_minor_units,
           closing_balance_minor_units = EXCLUDED.closing_balance_minor_units,
           contribution_applied = EXCLUDED.contribution_applied,
           updated_at = now()`,
        [
          pensionId,
          monthStart(input.referenceMonth),
          input.asOfDate,
          input.accumulatedReturnMinorUnits,
          resolved.closingBalanceMinorUnits,
          input.contributionApplied,
        ],
      );
      const [overrides, snapshots] = await Promise.all([
        loadPensionReturnOverrides(pool, pensionId),
        loadPensionSnapshots(pool, pensionId),
      ]);
      return buildPensionProjection(
        pension,
        overrides,
        10,
        new Date(),
        snapshots,
      );
    },
    async getPortfolio(userId) {
      // O passivo é o custo de quitar hoje, não o valor contratado da coluna
      // current_balance_minor_units, que o extrato traz como base para o CET.
      const [pensions, loans] = await Promise.all([
        loadPensions(pool, userId),
        loadLoans(pool, userId),
      ]);
      return {
        assets: pensions.map((pension) => ({
          id: pension.id!,
          name: pension.providerName,
          assetClass: "PENSION" as const,
          currentValueMinorUnits:
            pension.latestSnapshot?.closingBalanceMinorUnits ??
            pension.participantReserveMinorUnits + pension.employerReserveMinorUnits,
          isLiquid: false as const,
        })),
        liabilities: loans.map((loan) => ({
          id: loan.contractNumber,
          name: loan.productName,
          outstandingBalanceMinorUnits: loan.payoffMinorUnits,
        })),
      };
    },
  };
}

async function parsePdfInput(input: PdfImportInput): Promise<FinancialDocumentPreview> {
  const bytes = Buffer.from(input.contentBase64, "base64");
  if (bytes.length < 5 || bytes.subarray(0, 5).toString("ascii") !== "%PDF-") {
    throw new Error("O arquivo enviado não é um PDF válido.");
  }
  if (bytes.length > 8 * 1024 * 1024) {
    throw new Error("O PDF excede o limite de 8 MB.");
  }
  const text = await extractPdfText(bytes);
  const data = input.kind === "LOAN" ? parseLoanText(text) : parsePensionText(text);
  const warnings: string[] = [];
  if (input.kind === "LOAN") {
    const loan = data as LoanPreview;
    if (loan.installments.length !== loan.totalInstallments) {
      warnings.push(
        `Foram lidas ${loan.installments.length} de ${loan.totalInstallments} parcelas.`,
      );
    }
  } else if ((data as PensionPreview).history.length === 0) {
    warnings.push("O histórico mensal da PREVI não foi encontrado.");
  }
  return {
    kind: input.kind,
    fileName: basename(input.fileName).slice(0, 180),
    documentSha256: createHash("sha256").update(bytes).digest("hex"),
    warnings,
    data,
  };
}

export function parseLoanText(text: string, today = todayIso()): LoanPreview {
  const clean = normalizeOcr(text);
  const documentDate = requireMatch(clean, /(\d{2}\/\d{2}\/\d{4})[^\n]*\d{1,2}:\d{2}/i, "data do documento");
  const dates = [...clean.matchAll(/\b\d{2}\/\d{2}\/\d{4}\b/g)].map((match) => match[0]);
  const contractDate =
    matchAfterLabel(clean, /DATA DO CONTRATO/i, /\d{2}\/\d{2}\/\d{4}/) ??
    dates.find((value) => value.endsWith("/2024"));
  if (!contractDate) throw new Error("Não foi possível identificar a data do contrato.");

  const installments = parseLoanInstallments(clean, parseBrDate(documentDate));
  if (installments.length === 0) {
    throw new Error("Nenhuma parcela foi reconhecida no PDF do empréstimo.");
  }
  const totalInstallments = Math.max(...installments.map((item) => item.number));
  const paidInstallments = installments.filter((item) => item.status === "PAID").length;
  const open = installments.filter((item) => item.status === "OPEN");
  const amortizedInstallments = installments.filter(
    (item) => item.paymentKind === "AMORTIZED",
  ).length;
  const currencyValues = [...clean.matchAll(/R[$S]\s*([\d.]+,\d{2})/gi)].map((match) =>
    parseMoney(match[1]!),
  );
  if (currencyValues.length < 2) {
    throw new Error("Não foi possível identificar os valores do empréstimo.");
  }
  const percentages = [...clean.matchAll(/(\d{1,2},\d{1,4})\s*%/g)].map((match) =>
    parsePercent(match[1]!),
  );
  const contractNumber =
    clean.match(/\b(\d{8,12})\b/)?.[1] ?? `pdf-${randomUUID().slice(0, 8)}`;
  const productName = recognizeLoanProduct(clean);
  const normalizedProduct = stripDiacritics(productName).toUpperCase();
  const repaymentKind =
    normalizedProduct.includes("13") && normalizedProduct.includes("SALARIO")
    ? "THIRTEENTH_SALARY"
    : "MONTHLY";
  const payrollDeducted = normalizedProduct.includes("CONSIGNACAO");
  const debitDay = Number(
    open[0]?.dueDate.slice(8, 10) ??
      matchAfterLabel(clean, /DIA DO DEBITO/i, /\b(?:[1-9]|[12]\d|3[01])\b/) ??
      1,
  );
  const monthlyInterestRate = percentages[0] ?? null;
  const settlement = deriveLoanSettlement(
    installments,
    monthlyInterestRate,
    today,
  );
  return {
    id: null,
    providerName: "Banco do Brasil",
    productName,
    contractNumber,
    documentDate: toIsoDate(documentDate),
    contractDate: toIsoDate(contractDate),
    currentBalanceMinorUnits: currencyValues[0]!,
    originalTotalMinorUnits: currencyValues[1]!,
    debitDay,
    monthlyInterestRate,
    annualInterestRate: percentages[1] ?? null,
    monthlyEffectiveCost: percentages[2] ?? null,
    annualEffectiveCost: percentages[3] ?? null,
    repaymentKind,
    payrollDeducted,
    totalInstallments,
    paidInstallments: settlement.paidInstallments,
    remainingInstallments: settlement.remainingInstallments,
    amortizedInstallments,
    nextDueDate: settlement.nextDueDate,
    projectedEndDate: open.at(-1)?.dueDate ?? null,
    remainingPaymentsMinorUnits: settlement.remainingPaymentsMinorUnits,
    payoffMinorUnits: settlement.payoffMinorUnits,
    installments: settlement.installments,
  };
}

function recognizeLoanProduct(text: string): string {
  const normalized = stripDiacritics(text).toUpperCase();
  if (/13[Oº°.]?\s*SALARIO/.test(normalized)) return "BB Crédito 13º Salário";
  if (normalized.includes("VEICULO FUNCI")) return "BB Crédito Veículo Funci";
  if (normalized.includes("RENOVACAO CONSIGNACAO")) {
    return "BB Renovação Consignação";
  }
  if (normalized.includes("CREDITO CONSIGNACAO")) {
    return "BB Crédito Consignação";
  }
  if (normalized.includes("RENOVACAO FUNCI")) return "BB Crédito Renovação Funci";
  return (
    text
      .split("\n")
      .map((line) => line.trim())
      .find((line) => /^BB\s+CREDITO/i.test(stripDiacritics(line)))
      ?.replace(/R[$S].*$/i, "")
      .replace(/\s+/g, " ")
      .trim() ?? "Empréstimo Banco do Brasil"
  );
}

export function parsePensionText(text: string): PensionPreview {
  const clean = text.replace(/\u00a0/g, " ");
  const flat = clean.replace(/\s+/g, " ");
  const normalizedFlat = stripDiacritics(flat);
  const profileName = requireMatch(
    flat,
    /PERFIL DE INVESTIMENTO:\s*(.+?)\s+ATUALIZADO ATE:/i,
    "perfil de investimento",
  );
  const taxRegime = matchGroup(
    normalizedFlat,
    /REGIME DE TRIBUTACAO:\s*(.+?)\s+DATA DE FILIACAO:/i,
  );
  const enrollmentDate = matchGroup(
    normalizedFlat,
    /DATA DE FILIACAO:\s*(\d{2}\/\d{2}\/\d{4})/i,
  );
  const updatedThrough = matchGroup(
    normalizedFlat,
    /ATUALIZADO ATE:\s*(\d{2}\/\d{2}\/\d{4})/i,
  );
  const balanceDate = requireMatch(
    flat,
    /(\d{2}\/\d{2}\/\d{4})\s+SALDO DE CONTRIBUICOES INDIVIDUAIS/i,
    "data do saldo",
  );
  const partOne = moneyAfterLabel(flat, /SALDO DE CONTRIBUICOES INDIVIDUAIS PARA A PARTE 1/i, 0);
  const participantReserve = moneyAfterLabel(flat, /RESERVA INDIVIDUAL DE POUPANCA/i, 1);
  const employerReserve = moneyAfterLabel(flat, /RESERVA PATRONAL DE POUPANCA/i, 1);
  const participantBalance = moneyAfterLabel(flat, /SALDO DE CONTA DO PARTICIPANTE/i, 1);
  const profilePattern = new RegExp(
    `${escapeRegExp(stripDiacritics(profileName))}\\s+(\\d{1,2},\\d{1,4})%\\s+(\\d{1,2},\\d{1,4})%\\s+(\\d{1,2},\\d{1,4})%`,
    "i",
  );
  const returns = stripDiacritics(clean).replace(/\s+/g, " ").match(profilePattern);
  const history = parsePensionHistory(clean);
  return {
    id: null,
    providerName: "PREVI",
    profileName: profileName.trim(),
    taxRegime: taxRegime?.trim() ?? null,
    enrollmentDate: enrollmentDate ? toIsoDate(enrollmentDate) : null,
    balanceDate: toIsoDate(balanceDate),
    updatedThrough: updatedThrough ? toIsoDate(updatedThrough) : null,
    currentBalanceMinorUnits: participantBalance,
    partOneBalanceMinorUnits: partOne,
    participantReserveMinorUnits: participantReserve,
    employerReserveMinorUnits: employerReserve,
    monthlyReturn: returns?.[1] ? parsePercent(returns[1]) : null,
    yearlyReturn: returns?.[2] ? parsePercent(returns[2]) : null,
    twelveMonthReturn: returns?.[3] ? parsePercent(returns[3]) : null,
    latestSnapshot: null,
    history,
  };
}

function parseLoanInstallments(text: string, documentDate: Date): LoanInstallmentPreview[] {
  const recognized: Array<Omit<LoanInstallmentPreview, "number">> = [];
  const pattern = /^\s*\S+\s+(\d{2}\/\d{2}\/\d{4})\s+(PAGO|A\s+VENCER)\s+(?:R[$S]\s*)?([\d.,/]+)/gim;
  for (const match of text.matchAll(pattern)) {
    const dueDate = parseBrDate(match[1]!);
    const paid = stripDiacritics(match[2]!).replace(/\s+/g, " ").toUpperCase() === "PAGO";
    recognized.push({
      dueDate: formatDate(dueDate),
      status: paid ? "PAID" : "OPEN",
      paymentKind: paid
        ? dueDate.getTime() > documentDate.getTime()
          ? "AMORTIZED"
          : "REGULAR"
        : "PENDING",
      amountMinorUnits: parseOcrMoney(match[3]!),
      earlySettled: false,
    });
  }
  if (recognized.length === 0) return [];
  const firstDueDate = recognized
    .map((item) => new Date(`${item.dueDate}T12:00:00.000Z`))
    .sort((a, b) => a.getTime() - b.getTime())[0]!;
  const byNumber = new Map<number, LoanInstallmentPreview>();
  for (const item of recognized) {
    const dueDate = new Date(`${item.dueDate}T12:00:00.000Z`);
    const number =
      (dueDate.getUTCFullYear() - firstDueDate.getUTCFullYear()) * 12 +
      dueDate.getUTCMonth() -
      firstDueDate.getUTCMonth() +
      1;
    byNumber.set(number, { number, ...item });
  }
  return [...byNumber.values()].sort((a, b) => a.number - b.number);
}

function parsePensionHistory(text: string): PensionHistoryPreview[] {
  const months: Record<string, number> = {
    JAN: 1,
    FEV: 2,
    MAR: 3,
    ABR: 4,
    MAI: 5,
    JUN: 6,
    JUL: 7,
    AGO: 8,
    SET: 9,
    OUT: 10,
    NOV: 11,
    DEZ: 12,
  };
  const rows: PensionHistoryPreview[] = [];
  for (const line of text.split(/\r?\n/)) {
    const header = stripDiacritics(line).match(
      /^\s*(JAN|FEV|MAR|ABR|MAI|JUN|JUL|AGO|SET|OUT|NOV|DEZ)\/(\d{4})\b/i,
    );
    if (!header) continue;
    const values = line.match(/-?(?:\d{1,3}(?:\.\d{3})*|\d+),\d{2}/g) ?? [];
    if (values.length !== 10) continue;
    const money = values.map(parseMoney);
    rows.push({
      referenceMonth: `${header[2]}-${String(months[header[1]!.toUpperCase()]).padStart(2, "0")}-01`,
      openingBalanceMinorUnits: money[0]!,
      returnsMinorUnits: money[1]!,
      employerPart2aMinorUnits: money[2]!,
      employerPart2bMinorUnits: money[3]!,
      participantPart2aMinorUnits: money[4]!,
      participantPart2bMinorUnits: money[5]!,
      participantPart2cMinorUnits: money[6]!,
      personalPortabilityMinorUnits: money[7]!,
      employerPortabilityMinorUnits: money[8]!,
      closingBalanceMinorUnits: money[9]!,
    });
  }
  return rows.sort((a, b) => b.referenceMonth.localeCompare(a.referenceMonth));
}

async function extractPdfText(bytes: Buffer): Promise<string> {
  const directory = await mkdtemp(join(tmpdir(), "fluxo-ia-pdf-"));
  const inputPath = join(directory, "document.pdf");
  try {
    await writeFile(inputPath, bytes);
    let text = "";
    try {
      const result = await execFileAsync("pdftotext", ["-layout", inputPath, "-"], {
        encoding: "utf8",
        maxBuffer: 16 * 1024 * 1024,
      });
      text = result.stdout;
    } catch {
      text = "";
    }
    if (text.replace(/\s/g, "").length >= 200) return text;

    const prefix = join(directory, "page");
    await execFileAsync("pdftoppm", ["-png", "-r", "240", inputPath, prefix], {
      maxBuffer: 4 * 1024 * 1024,
    });
    const pages = (await readdir(directory))
      .filter((file) => /^page-\d+\.png$/i.test(file))
      .sort((a, b) => pageNumber(a) - pageNumber(b));
    const chunks: string[] = [];
    for (const page of pages) {
      const result = await execFileAsync(
        "tesseract",
        [join(directory, page), "stdout", "-l", "por", "--psm", "4"],
        { encoding: "utf8", maxBuffer: 8 * 1024 * 1024 },
      );
      chunks.push(result.stdout);
    }
    return chunks.join("\n");
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
}

async function persistLoan(
  client: PoolClient,
  userId: string,
  importId: string,
  data: LoanPreview,
): Promise<void> {
  const result = await client.query<{ id: string }>(
    `INSERT INTO loans (
       user_id, import_id, provider_name, product_name, contract_number, contract_date,
     current_balance_minor_units, original_total_minor_units, debit_day,
     monthly_interest_rate, annual_interest_rate, monthly_effective_cost,
       annual_effective_cost, repayment_kind, payroll_deducted,
       total_installments, paid_installments,
       remaining_installments, amortized_installments, next_due_date,
       projected_end_date, updated_at
     ) VALUES (
       $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,now()
     ) ON CONFLICT (user_id, contract_number) DO UPDATE SET
       import_id=EXCLUDED.import_id, provider_name=EXCLUDED.provider_name,
       product_name=EXCLUDED.product_name, contract_date=EXCLUDED.contract_date,
       current_balance_minor_units=EXCLUDED.current_balance_minor_units,
       original_total_minor_units=EXCLUDED.original_total_minor_units,
       debit_day=EXCLUDED.debit_day, monthly_interest_rate=EXCLUDED.monthly_interest_rate,
       annual_interest_rate=EXCLUDED.annual_interest_rate,
       monthly_effective_cost=EXCLUDED.monthly_effective_cost,
       annual_effective_cost=EXCLUDED.annual_effective_cost,
       repayment_kind=EXCLUDED.repayment_kind,
       payroll_deducted=EXCLUDED.payroll_deducted,
       total_installments=EXCLUDED.total_installments,
       paid_installments=EXCLUDED.paid_installments,
       remaining_installments=EXCLUDED.remaining_installments,
       amortized_installments=EXCLUDED.amortized_installments,
       next_due_date=EXCLUDED.next_due_date,
       projected_end_date=EXCLUDED.projected_end_date, updated_at=now()
     RETURNING id`,
    [
      userId,
      importId,
      data.providerName,
      data.productName,
      data.contractNumber,
      data.contractDate,
      data.currentBalanceMinorUnits,
      data.originalTotalMinorUnits,
      data.debitDay,
      data.monthlyInterestRate,
      data.annualInterestRate,
      data.monthlyEffectiveCost,
      data.annualEffectiveCost,
      data.repaymentKind,
      data.payrollDeducted,
      data.totalInstallments,
      data.paidInstallments,
      data.remainingInstallments,
      data.amortizedInstallments,
      data.nextDueDate,
      data.projectedEndDate,
    ],
  );
  const loanId = result.rows[0]!.id;
  // O extrato é a fonte da verdade do cronograma, mas a quitação antecipada foi
  // lançada à mão e não aparece nele. Preserva por número de parcela para o
  // reimport não apagar um pagamento que o usuário registrou.
  const earlier = await client.query<{ installment_number: number }>(
    `SELECT installment_number FROM loan_installments
     WHERE loan_id = $1 AND early_settled`,
    [loanId],
  );
  const earlySettled = new Set(
    earlier.rows.map((row) => Number(row.installment_number)),
  );
  await client.query("DELETE FROM loan_installments WHERE loan_id = $1", [loanId]);
  for (const item of data.installments) {
    await client.query(
      `INSERT INTO loan_installments (
         loan_id, installment_number, due_date, status, payment_kind,
         amount_minor_units, early_settled
       ) VALUES ($1,$2,$3,$4,$5,$6,$7)`,
      [
        loanId,
        item.number,
        item.dueDate,
        item.status,
        item.paymentKind,
        item.amountMinorUnits,
        earlySettled.has(item.number),
      ],
    );
  }
}

async function persistPension(
  client: PoolClient,
  userId: string,
  importId: string,
  data: PensionPreview,
): Promise<void> {
  const result = await client.query<{ id: string }>(
    `INSERT INTO pension_positions (
       user_id, import_id, provider_name, profile_name, tax_regime, enrollment_date,
       balance_date, updated_through, current_balance_minor_units,
       part_one_balance_minor_units, participant_reserve_minor_units,
       employer_reserve_minor_units, monthly_return, yearly_return,
       twelve_month_return, updated_at
     ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,now())
     ON CONFLICT (user_id, provider_name, profile_name) DO UPDATE SET
       import_id=EXCLUDED.import_id, tax_regime=EXCLUDED.tax_regime,
       enrollment_date=EXCLUDED.enrollment_date, balance_date=EXCLUDED.balance_date,
       updated_through=EXCLUDED.updated_through,
       current_balance_minor_units=EXCLUDED.current_balance_minor_units,
       part_one_balance_minor_units=EXCLUDED.part_one_balance_minor_units,
       participant_reserve_minor_units=EXCLUDED.participant_reserve_minor_units,
       employer_reserve_minor_units=EXCLUDED.employer_reserve_minor_units,
       monthly_return=EXCLUDED.monthly_return, yearly_return=EXCLUDED.yearly_return,
       twelve_month_return=EXCLUDED.twelve_month_return, updated_at=now()
     RETURNING id`,
    [
      userId,
      importId,
      data.providerName,
      data.profileName,
      data.taxRegime,
      data.enrollmentDate,
      data.balanceDate,
      data.updatedThrough,
      data.currentBalanceMinorUnits,
      data.partOneBalanceMinorUnits,
      data.participantReserveMinorUnits,
      data.employerReserveMinorUnits,
      data.monthlyReturn,
      data.yearlyReturn,
      data.twelveMonthReturn,
    ],
  );
  const pensionId = result.rows[0]!.id;
  await client.query("DELETE FROM pension_monthly_history WHERE pension_position_id = $1", [
    pensionId,
  ]);
  for (const item of data.history) {
    await client.query(
      `INSERT INTO pension_monthly_history (
         pension_position_id, reference_month, opening_balance_minor_units,
         returns_minor_units, employer_part_2a_minor_units,
         employer_part_2b_minor_units, participant_part_2a_minor_units,
         participant_part_2b_minor_units, participant_part_2c_minor_units,
         personal_portability_minor_units, employer_portability_minor_units,
         closing_balance_minor_units
       ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)`,
      [
        pensionId,
        item.referenceMonth,
        item.openingBalanceMinorUnits,
        item.returnsMinorUnits,
        item.employerPart2aMinorUnits,
        item.employerPart2bMinorUnits,
        item.participantPart2aMinorUnits,
        item.participantPart2bMinorUnits,
        item.participantPart2cMinorUnits,
        item.personalPortabilityMinorUnits,
        item.employerPortabilityMinorUnits,
        item.closingBalanceMinorUnits,
      ],
    );
  }
}

/** Data de referência da baixa automática, em UTC e no formato YYYY-MM-DD. */
function todayIso(): string {
  return new Date().toISOString().slice(0, 10);
}

/**
 * Meses de calendário entre duas datas YYYY-MM-DD, mínimo 1.
 *
 * O expoente do desconto precisa vir da distância real até o vencimento, e não
 * da posição da parcela na lista: quitação antecipada abre buracos no
 * cronograma, e usar a posição faria uma parcela de daqui a cinco meses ser
 * descontada como se vencesse no mês que vem.
 */
function monthsBetween(from: string, to: string): number {
  const months =
    (Number(to.slice(0, 4)) - Number(from.slice(0, 4))) * 12 +
    (Number(to.slice(5, 7)) - Number(from.slice(5, 7)));
  return Math.max(1, months);
}

async function loadLoans(
  pool: DatabasePool,
  userId: string,
  today = todayIso(),
): Promise<LoanPreview[]> {
  const result = await pool.query(
    `SELECT l.*, COALESCE(
       json_agg(json_build_object(
         'number', i.installment_number,
         'dueDate', to_char(i.due_date, 'YYYY-MM-DD'),
         'status', i.status,
         'paymentKind', i.payment_kind,
         'amountMinorUnits', i.amount_minor_units,
         'earlySettled', i.early_settled
       ) ORDER BY i.installment_number) FILTER (WHERE i.id IS NOT NULL), '[]'
     ) AS installments
     FROM loans l
     LEFT JOIN loan_installments i ON i.loan_id = l.id
     WHERE l.user_id = $1
     GROUP BY l.id
     ORDER BY l.updated_at DESC`,
    [userId],
  );
  return result.rows.map((row) => mapLoanRow(row, today));
}

/**
 * O extrato importado é um retrato da data do import e nada no banco avança
 * sozinho. Aqui a parcela cujo vencimento já passou conta como liquidada, o que
 * faz a baixa do dia do débito acontecer sem depender de rotina agendada.
 *
 * Parcelas AMORTIZED já vêm liquidadas do extrato mesmo vencendo no futuro:
 * a amortização mata a cauda do cronograma, não as próximas parcelas.
 */
function deriveLoanSettlement(
  installments: LoanInstallmentPreview[],
  monthlyInterestRate: number | null,
  today: string,
) {
  const settled: LoanInstallmentPreview[] = [];
  const outstanding: LoanInstallmentPreview[] = [];
  for (const item of installments) {
    if (item.status === "PAID") {
      settled.push(item);
    } else if (item.earlySettled) {
      settled.push({ ...item, status: "PAID" });
    } else if (item.dueDate <= today) {
      settled.push({ ...item, status: "PAID", paymentKind: "REGULAR" });
    } else {
      outstanding.push(item);
    }
  }
  outstanding.sort((a, b) => a.dueDate.localeCompare(b.dueDate));

  const remainingPaymentsMinorUnits = outstanding.reduce(
    (sum, item) => sum + item.amountMinorUnits,
    0,
  );
  // Valor presente das parcelas restantes descontadas pela taxa do contrato.
  // Sem taxa conhecida não há como descontar, então o desembolso é o piso.
  const rate = monthlyInterestRate == null ? 0 : monthlyInterestRate / 100;
  const payoffMinorUnits =
    rate <= 0
      ? remainingPaymentsMinorUnits
      : Math.round(
          outstanding.reduce(
            (sum, item) =>
              sum +
              item.amountMinorUnits /
                Math.pow(1 + rate, monthsBetween(today, item.dueDate)),
            0,
          ),
        );

  return {
    paidInstallments: settled.length,
    remainingInstallments: outstanding.length,
    nextDueDate: outstanding[0]?.dueDate ?? null,
    remainingPaymentsMinorUnits,
    payoffMinorUnits,
    installments: [...settled, ...outstanding].sort(
      (a, b) => a.number - b.number,
    ),
  };
}

function mapLoanRow(
  row: Record<string, unknown>,
  today = todayIso(),
): LoanPreview {
  const id = row.id == null ? null : String(row.id);
  const monthlyInterestRate = nullableNumber(row.monthly_interest_rate);
  const settlement = deriveLoanSettlement(
    (row.installments as LoanInstallmentPreview[]).map((item) => ({
      ...item,
      amountMinorUnits: Number(item.amountMinorUnits),
      earlySettled: item.earlySettled === true,
    })),
    monthlyInterestRate,
    today,
  );
  return {
    id,
    providerName: String(row.provider_name),
    productName: String(row.product_name),
    contractNumber: String(row.contract_number),
    documentDate: new Date(String(row.updated_at)).toISOString().slice(0, 10),
    contractDate: dateOnly(row.contract_date)!,
    currentBalanceMinorUnits: Number(row.current_balance_minor_units),
    originalTotalMinorUnits: Number(row.original_total_minor_units),
    debitDay: Number(row.debit_day),
    monthlyInterestRate,
    annualInterestRate: nullableNumber(row.annual_interest_rate),
    monthlyEffectiveCost: nullableNumber(row.monthly_effective_cost),
    annualEffectiveCost: nullableNumber(row.annual_effective_cost),
    repaymentKind:
      row.repayment_kind === "THIRTEENTH_SALARY"
        ? "THIRTEENTH_SALARY"
        : "MONTHLY",
    payrollDeducted: row.payroll_deducted === true,
    totalInstallments: Number(row.total_installments),
    paidInstallments: settlement.paidInstallments,
    remainingInstallments: settlement.remainingInstallments,
    amortizedInstallments: Number(row.amortized_installments),
    nextDueDate: settlement.nextDueDate,
    projectedEndDate: dateOnly(row.projected_end_date),
    remainingPaymentsMinorUnits: settlement.remainingPaymentsMinorUnits,
    payoffMinorUnits: settlement.payoffMinorUnits,
    installments: settlement.installments,
  };
}

function mapPensionRow(row: Record<string, unknown>): PensionPreview {
  return {
    id: String(row.id),
    providerName: String(row.provider_name),
    profileName: String(row.profile_name),
    taxRegime: row.tax_regime == null ? null : String(row.tax_regime),
    enrollmentDate: dateOnly(row.enrollment_date),
    balanceDate: dateOnly(row.balance_date)!,
    updatedThrough: dateOnly(row.updated_through),
    currentBalanceMinorUnits: Number(row.current_balance_minor_units),
    partOneBalanceMinorUnits: Number(row.part_one_balance_minor_units),
    participantReserveMinorUnits: Number(row.participant_reserve_minor_units),
    employerReserveMinorUnits: Number(row.employer_reserve_minor_units),
    monthlyReturn: nullableNumber(row.monthly_return),
    yearlyReturn: nullableNumber(row.yearly_return),
    twelveMonthReturn: nullableNumber(row.twelve_month_return),
    latestSnapshot: mapPensionSnapshot(row.latest_snapshot),
    history: (row.history as PensionHistoryPreview[]).map((item) => ({
      ...item,
      openingBalanceMinorUnits: Number(item.openingBalanceMinorUnits),
      returnsMinorUnits: Number(item.returnsMinorUnits),
      employerPart2aMinorUnits: Number(item.employerPart2aMinorUnits),
      employerPart2bMinorUnits: Number(item.employerPart2bMinorUnits),
      participantPart2aMinorUnits: Number(item.participantPart2aMinorUnits),
      participantPart2bMinorUnits: Number(item.participantPart2bMinorUnits),
      participantPart2cMinorUnits: Number(item.participantPart2cMinorUnits),
      personalPortabilityMinorUnits: Number(item.personalPortabilityMinorUnits),
      employerPortabilityMinorUnits: Number(item.employerPortabilityMinorUnits),
      closingBalanceMinorUnits: Number(item.closingBalanceMinorUnits),
    })),
  };
}

function mapPensionSnapshot(value: unknown): PensionMonthlySnapshot | null {
  if (!value || typeof value !== "object") return null;
  const row = value as Record<string, unknown>;
  return {
    referenceMonth: String(row.referenceMonth),
    asOfDate: String(row.asOfDate),
    accumulatedReturnMinorUnits: Number(row.accumulatedReturnMinorUnits),
    closingBalanceMinorUnits: Number(row.closingBalanceMinorUnits),
    contributionApplied: row.contributionApplied === true,
    projectedContributionMinorUnits: 0,
  };
}

type PensionReturnOverride = {
  referenceMonth: string;
  returnRate: number;
};

async function loadPensions(
  pool: DatabasePool,
  userId: string,
): Promise<PensionPreview[]> {
  const result = await pool.query(
    `SELECT p.*,
     (SELECT json_build_object(
        'referenceMonth', to_char(s.reference_month, 'YYYY-MM-DD'),
        'asOfDate', to_char(s.as_of_date, 'YYYY-MM-DD'),
        'accumulatedReturnMinorUnits', s.accumulated_return_minor_units,
        'closingBalanceMinorUnits', s.closing_balance_minor_units,
        'contributionApplied', s.contribution_applied
      ) FROM pension_monthly_snapshots s
      WHERE s.pension_position_id = p.id
      ORDER BY s.as_of_date DESC LIMIT 1) AS latest_snapshot,
     COALESCE(
       json_agg(json_build_object(
         'referenceMonth', to_char(h.reference_month, 'YYYY-MM-DD'),
         'openingBalanceMinorUnits', h.opening_balance_minor_units,
         'returnsMinorUnits', h.returns_minor_units,
         'employerPart2aMinorUnits', h.employer_part_2a_minor_units,
         'employerPart2bMinorUnits', h.employer_part_2b_minor_units,
         'participantPart2aMinorUnits', h.participant_part_2a_minor_units,
         'participantPart2bMinorUnits', h.participant_part_2b_minor_units,
         'participantPart2cMinorUnits', h.participant_part_2c_minor_units,
         'personalPortabilityMinorUnits', h.personal_portability_minor_units,
         'employerPortabilityMinorUnits', h.employer_portability_minor_units,
         'closingBalanceMinorUnits', h.closing_balance_minor_units
       ) ORDER BY h.reference_month DESC) FILTER (WHERE h.id IS NOT NULL), '[]'
     ) AS history
     FROM pension_positions p
     LEFT JOIN pension_monthly_history h ON h.pension_position_id = p.id
     WHERE p.user_id = $1
     GROUP BY p.id
     ORDER BY p.updated_at DESC`,
    [userId],
  );
  return result.rows.map(mapPensionRow).map(resolveLatestPensionSnapshot);
}

async function loadPension(
  pool: DatabasePool,
  userId: string,
  pensionId: string,
): Promise<PensionPreview | null> {
  const result = await pool.query(
    `SELECT p.*,
     (SELECT json_build_object(
        'referenceMonth', to_char(s.reference_month, 'YYYY-MM-DD'),
        'asOfDate', to_char(s.as_of_date, 'YYYY-MM-DD'),
        'accumulatedReturnMinorUnits', s.accumulated_return_minor_units,
        'closingBalanceMinorUnits', s.closing_balance_minor_units,
        'contributionApplied', s.contribution_applied
      ) FROM pension_monthly_snapshots s
      WHERE s.pension_position_id = p.id
      ORDER BY s.as_of_date DESC LIMIT 1) AS latest_snapshot,
     COALESCE(
       json_agg(json_build_object(
         'referenceMonth', to_char(h.reference_month, 'YYYY-MM-DD'),
         'openingBalanceMinorUnits', h.opening_balance_minor_units,
         'returnsMinorUnits', h.returns_minor_units,
         'employerPart2aMinorUnits', h.employer_part_2a_minor_units,
         'employerPart2bMinorUnits', h.employer_part_2b_minor_units,
         'participantPart2aMinorUnits', h.participant_part_2a_minor_units,
         'participantPart2bMinorUnits', h.participant_part_2b_minor_units,
         'participantPart2cMinorUnits', h.participant_part_2c_minor_units,
         'personalPortabilityMinorUnits', h.personal_portability_minor_units,
         'employerPortabilityMinorUnits', h.employer_portability_minor_units,
         'closingBalanceMinorUnits', h.closing_balance_minor_units
       ) ORDER BY h.reference_month DESC) FILTER (WHERE h.id IS NOT NULL), '[]'
     ) AS history
     FROM pension_positions p
     LEFT JOIN pension_monthly_history h ON h.pension_position_id = p.id
     WHERE p.user_id = $1 AND p.id = $2
     GROUP BY p.id`,
    [userId, pensionId],
  );
  return result.rows[0] ? mapPensionRow(result.rows[0]) : null;
}

async function loadPensionReturnOverrides(
  pool: DatabasePool,
  pensionId: string,
): Promise<PensionReturnOverride[]> {
  const result = await pool.query(
    `SELECT to_char(reference_month, 'YYYY-MM-DD') AS reference_month, return_rate
     FROM pension_return_overrides
     WHERE pension_position_id = $1
     ORDER BY reference_month`,
    [pensionId],
  );
  return result.rows.map((row) => ({
    referenceMonth: String(row.reference_month),
    returnRate: Number(row.return_rate),
  }));
}

async function loadPensionSnapshots(
  pool: DatabasePool,
  pensionId: string,
): Promise<PensionMonthlySnapshot[]> {
  const result = await pool.query(
    `SELECT to_char(reference_month, 'YYYY-MM-DD') AS reference_month,
            to_char(as_of_date, 'YYYY-MM-DD') AS as_of_date,
            accumulated_return_minor_units, closing_balance_minor_units,
            contribution_applied
     FROM pension_monthly_snapshots
     WHERE pension_position_id = $1
     ORDER BY reference_month`,
    [pensionId],
  );
  return result.rows.map((row) => ({
    referenceMonth: String(row.reference_month),
    asOfDate: String(row.as_of_date),
    accumulatedReturnMinorUnits: Number(row.accumulated_return_minor_units),
    closingBalanceMinorUnits: Number(row.closing_balance_minor_units),
    contributionApplied: row.contribution_applied === true,
    projectedContributionMinorUnits: 0,
  }));
}

export function buildPensionProjection(
  pension: PensionPreview,
  overrides: PensionReturnOverride[] = [],
  horizonYears = 10,
  asOf = new Date(),
  snapshots: PensionMonthlySnapshot[] = [],
): PensionProjection {
  if (!pension.id) {
    throw new Error("A projeção exige uma posição PREVI persistida.");
  }
  const history = [...pension.history].sort((a, b) =>
    a.referenceMonth.localeCompare(b.referenceMonth),
  );
  const sourceUpdatedThrough =
    pension.updatedThrough ?? history.at(-1)?.referenceMonth ?? pension.balanceDate;
  const sourceMonth = new Date(`${monthStart(sourceUpdatedThrough)}T12:00:00.000Z`);
  const overrideByMonth = new Map(
    overrides.map((item) => [monthStart(item.referenceMonth), item.returnRate]),
  );
  const resolvedSnapshots = snapshots.map((item) =>
    resolvePensionSnapshot(pension, item, asOf),
  );
  const snapshotByMonth = new Map(
    resolvedSnapshots.map((item) => [monthStart(item.referenceMonth), item]),
  );
  const latestSnapshot = [...resolvedSnapshots]
    .filter((item) => item.asOfDate <= asOf.toISOString().slice(0, 10))
    .sort((a, b) => b.asOfDate.localeCompare(a.asOfDate))[0] ?? null;

  // O mês do "atualizado até" que ainda não fechou tem só alguns dias de
  // rendimento; entrar na média como mês cheio a distorceria.
  const openMonth =
    pension.updatedThrough && !isMonthEnd(pension.updatedThrough)
      ? monthStart(pension.updatedThrough)
      : null;
  const observedRates = history
    .filter(
      (item) =>
        item.openingBalanceMinorUnits > 0 &&
        monthStart(item.referenceMonth) !== openMonth,
    )
    .map((item) => ({
      month: monthStart(item.referenceMonth),
      rate: monthlyReturnRate(item),
    }));
  for (const item of overrides) {
    const month = monthStart(item.referenceMonth);
    const existing = observedRates.find((rate) => rate.month === month);
    if (existing) existing.rate = item.returnRate;
    else observedRates.push({ month, rate: item.returnRate });
  }
  // Média do histórico inteiro, e não dos últimos 12 meses: com a janela curta,
  // o mesmo histórico projetava a década a 0,5% ou a 27,9% a.a. dependendo do
  // mês do extrato. Com o histórico todo, cada extrato novo só refina a média.
  const monthlyReturnRateUsed = observedRates.length
    ? geometricMonthlyRate(observedRates.map((item) => item.rate))
    : pension.twelveMonthReturn != null
      ? equivalentMonthlyRate(pension.twelveMonthReturn)
      : (pension.monthlyReturn ?? 0);
  const annualizedReturnRate =
    (Math.pow(1 + monthlyReturnRateUsed / 100, 12) - 1) * 100;

  const contributionRows = history.filter(
    (item) => participantContribution(item) > 0 || employerContribution(item) > 0,
  );
  const {
    participantMinorUnits: averageParticipantContributionMinorUnits,
    employerMinorUnits: averageEmployerContributionMinorUnits,
  } = contributionLevel(contributionRows);
  const currentMonth = new Date(
    Date.UTC(asOf.getUTCFullYear(), asOf.getUTCMonth(), 1, 12),
  );
  const enrollmentMonth = pension.enrollmentDate
    ? new Date(`${monthStart(pension.enrollmentDate)}T12:00:00.000Z`)
    : null;
  const sourceContributionCount = enrollmentMonth
    ? inclusiveMonthCount(enrollmentMonth, sourceMonth)
    : contributionRows.length;
  const currentContributionCount = enrollmentMonth
    ? Math.max(
        contributionRows.length,
        inclusiveMonthCount(
          enrollmentMonth,
          currentMonth > sourceMonth ? currentMonth : sourceMonth,
        ),
      )
    : contributionRows.length;

  let currentParticipant = pension.participantReserveMinorUnits;
  let currentEmployer = pension.employerReserveMinorUnits;
  const currentCursor = new Date(sourceMonth);
  currentCursor.setUTCMonth(currentCursor.getUTCMonth() + 1);
  while (currentCursor <= currentMonth) {
    const month = formatMonth(currentCursor);
    const snapshot = snapshotByMonth.get(month);
    if (snapshot) {
      const totalBefore = currentParticipant + currentEmployer;
      const participantShare = totalBefore > 0 ? currentParticipant / totalBefore : 0.5;
      currentParticipant = snapshot.closingBalanceMinorUnits * participantShare;
      currentEmployer = snapshot.closingBalanceMinorUnits - currentParticipant;
    } else {
      const rate = overrideByMonth.get(month) ?? monthlyReturnRateUsed;
      currentParticipant =
        currentParticipant * (1 + rate / 100) +
        averageParticipantContributionMinorUnits;
      currentEmployer =
        currentEmployer * (1 + rate / 100) + averageEmployerContributionMinorUnits;
    }
    currentCursor.setUTCMonth(currentCursor.getUTCMonth() + 1);
  }
  const currentEmployerEligibleRate = employerEligibleRate(currentContributionCount);
  const currentGrossWithdrawableMinorUnits = Math.round(
    currentParticipant + currentEmployer * (currentEmployerEligibleRate / 100),
  );

  let participant = pension.participantReserveMinorUnits;
  let employer = pension.employerReserveMinorUnits;
  const points: PensionProjectionPoint[] = [];
  const cursor = new Date(sourceMonth);
  cursor.setUTCMonth(cursor.getUTCMonth() + 1);
  let projectedMonths = 0;
  const finalYear = sourceMonth.getUTCFullYear() + Math.max(1, Math.min(horizonYears, 30));
  while (cursor.getUTCFullYear() <= finalYear) {
    const month = formatMonth(cursor);
    const snapshot = snapshotByMonth.get(month);
    if (snapshot) {
      const totalBefore = participant + employer;
      const participantShare = totalBefore > 0 ? participant / totalBefore : 0.5;
      participant = snapshot.closingBalanceMinorUnits * participantShare;
      employer = snapshot.closingBalanceMinorUnits - participant;
      const actualContributionTotal = Math.max(
        0,
        snapshot.closingBalanceMinorUnits -
          totalBefore -
          snapshot.accumulatedReturnMinorUnits,
      );
      const expectedContributionTotal =
        averageParticipantContributionMinorUnits +
        averageEmployerContributionMinorUnits;
      const remainingContribution = Math.max(
        0,
        expectedContributionTotal - actualContributionTotal,
      );
      const expectedParticipantShare = expectedContributionTotal > 0
        ? averageParticipantContributionMinorUnits / expectedContributionTotal
        : 0.5;
      participant += remainingContribution * expectedParticipantShare;
      employer += remainingContribution * (1 - expectedParticipantShare);
    } else {
      const rate = overrideByMonth.get(month) ?? monthlyReturnRateUsed;
      participant =
        participant * (1 + rate / 100) + averageParticipantContributionMinorUnits;
      employer = employer * (1 + rate / 100) + averageEmployerContributionMinorUnits;
    }
    projectedMonths += 1;
    const contributionCount = enrollmentMonth
      ? inclusiveMonthCount(enrollmentMonth, cursor)
      : sourceContributionCount + projectedMonths;
    if (cursor.getUTCMonth() === 11) {
      const eligibleRate = employerEligibleRate(contributionCount);
      points.push({
        year: cursor.getUTCFullYear(),
        projectedBalanceMinorUnits: Math.round(participant + employer),
        projectedParticipantReserveMinorUnits: Math.round(participant),
        projectedEmployerReserveMinorUnits: Math.round(employer),
        grossWithdrawableMinorUnits: Math.round(
          participant + employer * (eligibleRate / 100),
        ),
        employerEligibleRate: eligibleRate,
        projectedContributionCount: contributionCount,
      });
    }
    cursor.setUTCMonth(cursor.getUTCMonth() + 1);
  }

  return {
    pensionId: pension.id,
    sourceUpdatedThrough,
    monthlyReturnRateUsed: roundRate(monthlyReturnRateUsed),
    annualizedReturnRate: roundRate(annualizedReturnRate),
    averageParticipantContributionMinorUnits,
    averageEmployerContributionMinorUnits,
    currentContributionCount,
    partOneBalanceMinorUnits: pension.partOneBalanceMinorUnits,
    currentPartTwoBalanceMinorUnits: Math.round(currentParticipant + currentEmployer),
    currentGrossWithdrawableMinorUnits,
    currentEmployerEligibleRate,
    latestSnapshot,
    returnOverrides: overrides.map((item) => ({
      referenceMonth: monthStart(item.referenceMonth),
      returnRate: item.returnRate,
    })),
    points,
    notices: [
      "Estimativa bruta antes do Imposto de Renda e de eventuais débitos com o plano.",
      "A Parte I custeia benefícios de risco e não foi incluída no resgate projetado.",
      "O resgate pressupõe desligamento do patrocinador e cancelamento da inscrição no plano.",
    ],
  };
}

function participantContribution(item: PensionHistoryPreview): number {
  return (
    item.participantPart2aMinorUnits +
    item.participantPart2bMinorUnits +
    item.participantPart2cMinorUnits
  );
}

/**
 * Patamar atual da contribuição mensal. Ela é um percentual do salário: só muda
 * quando o salário muda, e volta ao patamar no mês seguinte a férias ou 13º. A
 * mediana descarta esses picos isolados; a janela de três meses faz um aumento
 * valer no mês seguinte, enquanto a de seis o segurava por quatro meses.
 */
function contributionLevel(history: PensionHistoryPreview[]): {
  participantMinorUnits: number;
  employerMinorUnits: number;
} {
  const recent = history
    .filter(
      (item) => participantContribution(item) > 0 || employerContribution(item) > 0,
    )
    .slice(-3);
  return {
    participantMinorUnits: Math.round(median(recent.map(participantContribution))),
    employerMinorUnits: Math.round(median(recent.map(employerContribution))),
  };
}

/**
 * Rendimento percentual do mês sobre o capital que de fato esteve aplicado.
 * O dinheiro que entra no mês rende só parte dele: dividir apenas pelo saldo de
 * abertura inflava a taxa, sobretudo no início, quando a contribuição era do
 * tamanho do saldo. Metade do fluxo no denominador é o Dietz modificado com
 * entrada no meio do mês, que fica a centésimos da rentabilidade da PREVI.
 */
function monthlyReturnRate(item: PensionHistoryPreview): number {
  const inflows =
    participantContribution(item) +
    employerContribution(item) +
    item.personalPortabilityMinorUnits +
    item.employerPortabilityMinorUnits;
  return (
    (item.returnsMinorUnits / (item.openingBalanceMinorUnits + inflows / 2)) * 100
  );
}

function resolveLatestPensionSnapshot(pension: PensionPreview): PensionPreview {
  if (!pension.latestSnapshot) return pension;
  return {
    ...pension,
    latestSnapshot: resolvePensionSnapshot(
      pension,
      pension.latestSnapshot,
      new Date(),
    ),
  };
}

function resolvePensionSnapshot(
  pension: PensionPreview,
  snapshot: PensionMonthlySnapshot,
  asOf: Date,
): PensionMonthlySnapshot {
  const snapshotMonth = monthStart(snapshot.referenceMonth);
  const priorHistory = [...pension.history]
    .filter((item) => monthStart(item.referenceMonth) < snapshotMonth)
    .sort((a, b) => a.referenceMonth.localeCompare(b.referenceMonth));
  const baseBalance =
    priorHistory.at(-1)?.closingBalanceMinorUnits ??
    pension.participantReserveMinorUnits + pension.employerReserveMinorUnits;
  const {
    participantMinorUnits: participantAverage,
    employerMinorUnits: employerAverage,
  } = contributionLevel(priorHistory);
  const currentMonth = formatMonth(asOf);
  // Mês já encerrado sempre teve contribuição. No mês corrente o saldo fica fiel
  // à PREVI: a contribuição só entra quando lançada explicitamente, porque o dia
  // do crédito não é previsível e projetar aqui adulteraria um valor medido.
  const contributionIsDue =
    snapshotMonth < currentMonth || snapshot.contributionApplied;
  const projectedContributionMinorUnits = participantAverage + employerAverage;
  return {
    ...snapshot,
    projectedContributionMinorUnits,
    closingBalanceMinorUnits:
      baseBalance +
      snapshot.accumulatedReturnMinorUnits +
      (contributionIsDue ? projectedContributionMinorUnits : 0),
  };
}

function employerContribution(item: PensionHistoryPreview): number {
  return item.employerPart2aMinorUnits + item.employerPart2bMinorUnits;
}

function employerEligibleRate(contributionCount: number): number {
  return Math.min(80, 10 + Math.floor(contributionCount / 12) * 3.5);
}

function inclusiveMonthCount(from: Date, through: Date): number {
  return Math.max(
    0,
    (through.getUTCFullYear() - from.getUTCFullYear()) * 12 +
      through.getUTCMonth() -
      from.getUTCMonth() +
      1,
  );
}

function median(values: number[]): number {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2
    ? sorted[middle]!
    : (sorted[middle - 1]! + sorted[middle]!) / 2;
}

function geometricMonthlyRate(rates: number[]): number {
  const product = rates.reduce(
    (accumulator, rate) => accumulator * Math.max(0, 1 + rate / 100),
    1,
  );
  return (Math.pow(product, 1 / rates.length) - 1) * 100;
}

function equivalentMonthlyRate(annualRate: number): number {
  return (Math.pow(1 + annualRate / 100, 1 / 12) - 1) * 100;
}

function monthStart(value: string): string {
  return `${value.slice(0, 7)}-01`;
}

/** Se a data YYYY-MM-DD é o último dia do seu mês. */
function isMonthEnd(value: string): boolean {
  const next = new Date(`${value.slice(0, 10)}T12:00:00.000Z`);
  next.setUTCDate(next.getUTCDate() + 1);
  return next.getUTCDate() === 1;
}

function formatMonth(value: Date): string {
  return `${value.getUTCFullYear()}-${String(value.getUTCMonth() + 1).padStart(2, "0")}-01`;
}

function roundRate(value: number): number {
  return Math.round(value * 10_000) / 10_000;
}

function normalizeOcr(value: string): string {
  return stripDiacritics(value)
    .replace(/[|]/g, " ")
    .replace(/\bRS\s*(?=\d)/gi, "R$ ")
    .replace(/\bA\s+VENCER\b/gi, "A VENCER");
}

function stripDiacritics(value: string): string {
  return value.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
}

function matchAfterLabel(text: string, label: RegExp, value: RegExp): string | null {
  const normalized = stripDiacritics(text);
  const labelMatch = normalized.match(label);
  if (!labelMatch?.index) return null;
  return normalized.slice(labelMatch.index, labelMatch.index + 240).match(value)?.[0] ?? null;
}

function requireMatch(text: string, pattern: RegExp, label: string): string {
  const value = matchGroup(stripDiacritics(text), pattern);
  if (!value) throw new Error(`Não foi possível identificar ${label} no PDF.`);
  return value;
}

function matchGroup(text: string, pattern: RegExp): string | null {
  return text.match(pattern)?.[1] ?? null;
}

function moneyAfterLabel(text: string, label: RegExp, index: number): number {
  const normalized = stripDiacritics(text);
  const labelMatch = normalized.match(label);
  if (labelMatch?.index == null) throw new Error("Campo financeiro da PREVI não encontrado.");
  const values = normalized
    .slice(labelMatch.index + labelMatch[0].length, labelMatch.index + labelMatch[0].length + 100)
    .match(/-?(?:\d{1,3}(?:\.\d{3})*|\d+),\d{2}/g);
  if (!values?.[index]) throw new Error("Valor financeiro da PREVI não encontrado.");
  return parseMoney(values[index]);
}

function parseMoney(value: string): number {
  const normalized = value.replace(/\./g, "").replace(",", ".");
  const result = Math.round(Number(normalized) * 100);
  if (!Number.isSafeInteger(result)) throw new Error(`Valor monetário inválido: ${value}`);
  return result;
}

function parseOcrMoney(value: string): number {
  let normalized = value.trim().replace("/", ",");
  if (!normalized.includes(",")) {
    const digits = normalized.replace(/\D/g, "");
    if (digits.length < 3) throw new Error(`Valor monetário inválido: ${value}`);
    normalized = `${digits.slice(0, -2)},${digits.slice(-2)}`;
  }
  return parseMoney(normalized);
}

function parsePercent(value: string): number {
  return Number(value.replace(",", "."));
}

function parseBrDate(value: string): Date {
  const [day, month, year] = value.split("/").map(Number);
  const result = new Date(Date.UTC(year!, month! - 1, day!));
  if (Number.isNaN(result.getTime())) throw new Error(`Data inválida: ${value}`);
  return result;
}

function toIsoDate(value: string): string {
  return formatDate(parseBrDate(value));
}

function formatDate(value: Date): string {
  return value.toISOString().slice(0, 10);
}

function dateOnly(value: unknown): string | null {
  if (value == null) return null;
  return new Date(String(value)).toISOString().slice(0, 10);
}

function nullableNumber(value: unknown): number | null {
  return value == null ? null : Number(value);
}

function pageNumber(fileName: string): number {
  return Number(fileName.match(/(\d+)\.png$/)?.[1] ?? 0);
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
