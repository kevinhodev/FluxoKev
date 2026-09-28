import { createHash } from "node:crypto";

import type { TransactionDirection, TransactionNature } from "../../domain.js";
import type { PluggyAccount, PluggyTransaction } from "./client.js";

export type MappedPluggyTransaction = {
  amountMinorUnits: number;
  direction: TransactionDirection;
  nature: TransactionNature;
  categoryId: string;
};

export function mapAccountType(account: PluggyAccount) {
  if (account.type === "CREDIT") return "CREDIT_CARD" as const;
  switch (account.subtype) {
    case "SAVINGS_ACCOUNT":
      return "SAVINGS" as const;
    case "PAYMENT_ACCOUNT":
      return "PAYMENT" as const;
    case "CHECKING_ACCOUNT":
    default:
      return "CHECKING" as const;
  }
}

export function mapAccountBalanceMinorUnits(account: PluggyAccount): number {
  const amount = toMinorUnits(account.balance);
  return account.type === "CREDIT" ? -Math.abs(amount) : amount;
}

export function mapAvailableBalanceMinorUnits(account: PluggyAccount): number | null {
  const value =
    account.type === "CREDIT"
      ? account.creditData?.availableCreditLimit
      : account.bankData?.closingBalance;
  return value == null ? null : toMinorUnits(value);
}

export function mapCreditLimitMinorUnits(account: PluggyAccount): number | null {
  const value = account.creditData?.creditLimit;
  return value == null ? null : toMinorUnits(value);
}

export function creditBalanceGroupKey(account: PluggyAccount): string | null {
  const limits = account.creditData?.disaggregatedCreditLimits;
  if (account.type !== "CREDIT" || !limits?.length) return null;
  const normalizedLimits = limits
    .map((limit) => ({
      type: limit.creditLineLimitType ?? limit.type ?? null,
      used: limit.usedAmount ?? limit.usedCreditLimit ?? null,
      available: limit.availableAmount ?? limit.availableCreditLimit ?? null,
      limit: limit.limitAmount ?? limit.creditLimit ?? null,
    }))
    .sort((left, right) => JSON.stringify(left).localeCompare(JSON.stringify(right)));
  return createHash("sha256")
    .update(
      JSON.stringify({
        itemId: account.itemId,
        balance: account.balance,
        creditLimit: account.creditData?.creditLimit ?? null,
        availableCreditLimit: account.creditData?.availableCreditLimit ?? null,
        limits: normalizedLimits,
      }),
    )
    .digest("hex");
}

export function mapPluggyTransaction(
  account: PluggyAccount,
  transaction: PluggyTransaction,
): MappedPluggyTransaction {
  const direction = inferDirection(account, transaction);
  return {
    amountMinorUnits: Math.abs(toMinorUnits(transaction.amount)),
    direction,
    nature: inferNature(transaction.category, direction),
    categoryId: inferCategory(transaction.category, direction),
  };
}

function inferDirection(
  account: PluggyAccount,
  transaction: PluggyTransaction,
): TransactionDirection {
  if (transaction.type) return transaction.type;
  if (account.type === "CREDIT") return transaction.amount >= 0 ? "DEBIT" : "CREDIT";
  return transaction.amount < 0 ? "DEBIT" : "CREDIT";
}

function inferNature(
  category: string | null | undefined,
  direction: TransactionDirection,
): TransactionNature {
  const normalized = (category ?? "").toLowerCase();
  if (
    normalized.includes("transfer") ||
    normalized.includes("credit card payment") ||
    normalized.includes("same person")
  ) return "TRANSFER";
  if (
    direction === "CREDIT" &&
    (normalized.includes("investment") ||
      normalized.includes("proceeds") ||
      normalized.includes("dividend"))
  ) {
    return "INVESTMENT_RETURN";
  }
  return direction === "CREDIT" ? "INCOME" : "EXPENSE";
}

function inferCategory(
  category: string | null | undefined,
  direction: TransactionDirection,
): string {
  const value = (category ?? "").toLowerCase();
  if (value.includes("salary")) return "salary";
  if (value.includes("grocer")) return "food-supermarket";
  if (value.includes("food delivery")) return "food-delivery";
  if (value.includes("food") || value.includes("eating out")) return "food";
  if (value.includes("gas station")) return "transport-fuel";
  if (value.includes("taxi") || value.includes("ride-hailing")) return "transport-app";
  if (value.includes("transport") || value.includes("automotive")) return "transport";
  if (value.includes("toll") || value.includes("parking")) return "transport";
  if (value.includes("video streaming") || value.includes("music streaming")) {
    return "subscriptions-streaming";
  }
  if (value.includes("digital service")) return "subscriptions";
  if (value.includes("rent")) return "housing-rent";
  if (value.includes("utilit")) return "housing-utilities";
  if (value.includes("housing")) return "housing";
  if (value.includes("health") || value.includes("pharmacy")) return "health";
  if (value.includes("education")) return "education";
  if (value.includes("insurance")) return "insurance";
  if (value.includes("accommodation") || value.includes("accomodation")) return "travel";
  if (value.includes("travel") || value.includes("airport")) return "travel";
  if (value.includes("shopping") || value.includes("electronics")) return "shopping";
  if (value.includes("bank fee")) return "bank-fees";
  if (value.includes("tax") || value.includes("financial operation")) return "taxes";
  if (value.includes("leisure") || value.includes("cinema")) return "leisure";
  if (value.includes("proceeds") || value.includes("dividend")) {
    return "investments-return";
  }
  if (value.includes("investment")) {
    return direction === "CREDIT" ? "investments-return" : "transfer-investment";
  }
  if (value.includes("transfer") || value.includes("credit card payment")) {
    return "transfer-out";
  }
  return direction === "CREDIT" ? "other-income" : "other-expense";
}

function toMinorUnits(value: number): number {
  const result = Math.round(value * 100);
  if (!Number.isSafeInteger(result)) throw new Error("Valor da Pluggy fora do limite seguro.");
  return result;
}
