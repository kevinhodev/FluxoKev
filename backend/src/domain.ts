export type User = {
  id: string;
  name: string;
  email: string;
  passwordHash: string;
};

export type Institution = {
  id: string;
  name: string;
  type: "BANK" | "PENSION" | "OTHER";
  externalId: string | null;
};

export type Account = {
  id: string;
  institutionId: string;
  name: string;
  type: "CHECKING" | "SAVINGS" | "PAYMENT" | "CREDIT_CARD" | "OTHER";
  currency: string;
  currentBalanceMinorUnits: number;
  availableBalanceMinorUnits: number | null;
  balanceGroupKey: string | null;
  creditLimitMinorUnits: number | null;
  balanceDueDate: string | null;
  lastSyncAt: string | null;
};

export type Category = {
  id: string;
  parentId: string | null;
  name: string;
  type: "INCOME" | "EXPENSE" | "TRANSFER" | "INVESTMENT";
};

export type TransactionDirection = "CREDIT" | "DEBIT";
export type TransactionNature = "INCOME" | "EXPENSE" | "TRANSFER" | "INVESTMENT_RETURN";
export type TransactionSource =
  | "OPEN_FINANCE"
  | "PLUGGY"
  | "OFX_IMPORT"
  | "CSV_IMPORT"
  | "XLSX_IMPORT"
  | "PDF_IMPORT"
  | "MANUAL";

export type FinancialTransaction = {
  id: string;
  accountId: string;
  externalId: string | null;
  occurredAt: string;
  description: string;
  normalizedDescription: string;
  merchantName: string;
  amountMinorUnits: number;
  direction: TransactionDirection;
  nature: TransactionNature;
  categoryId: string;
  source: TransactionSource;
  providerStatus: "POSTED" | "PENDING" | null;
  providerCategory: string | null;
  note: string | null;
  createdAt: string;
  updatedAt: string;
};

export type CreateTransaction = Omit<
  FinancialTransaction,
  | "id"
  | "normalizedDescription"
  | "source"
  | "externalId"
  | "providerStatus"
  | "providerCategory"
  | "createdAt"
  | "updatedAt"
>;

export type TransactionPatch = {
  occurredAt?: string | undefined;
  description?: string | undefined;
  merchantName?: string | undefined;
  amountMinorUnits?: number | undefined;
  direction?: TransactionDirection | undefined;
  nature?: TransactionNature | undefined;
  categoryId?: string | undefined;
  note?: string | null | undefined;
};

export type FixedExpense = {
  id: string;
  name: string;
  categoryId: string;
  amountMinorUnits: number | null;
  valueKind: "FIXED" | "VARIABLE";
  frequency: "MONTHLY";
  locationLabel: string;
  dueDay: number | null;
  active: boolean;
  note: string | null;
  createdAt: string;
  updatedAt: string;
};

export type CreateFixedExpense = Omit<
  FixedExpense,
  "id" | "active" | "createdAt" | "updatedAt"
>;

export type FixedExpensePatch = Partial<
  Pick<
    FixedExpense,
    | "name"
    | "categoryId"
    | "amountMinorUnits"
    | "valueKind"
    | "locationLabel"
    | "dueDay"
    | "note"
  >
>;

export type Subscription = {
  id: string;
  name: string;
  billingDescriptor: string;
  amountMinorUnits: number;
  frequency: "MONTHLY";
  billingDay: number | null;
  paymentMethodLabel: string;
  active: boolean;
  note: string | null;
  createdAt: string;
  updatedAt: string;
};

export type CreateSubscription = Omit<
  Subscription,
  "id" | "active" | "createdAt" | "updatedAt"
>;

export type SubscriptionPatch = Partial<
  Pick<
    Subscription,
    | "name"
    | "billingDescriptor"
    | "amountMinorUnits"
    | "billingDay"
    | "paymentMethodLabel"
    | "note"
  >
>;

export type BenefitWallet = {
  id: string;
  name: string;
  currentBalanceMinorUnits: number;
  monthlyCreditMinorUnits: number;
  monthlyAllocationMinorUnits: number;
  allocationLabel: string;
  active: boolean;
  note: string | null;
  createdAt: string;
  updatedAt: string;
};

export type CreateBenefitWallet = Omit<
  BenefitWallet,
  "id" | "active" | "createdAt" | "updatedAt"
>;

export type BenefitWalletPatch = Partial<
  Pick<
    BenefitWallet,
    | "name"
    | "currentBalanceMinorUnits"
    | "monthlyCreditMinorUnits"
    | "monthlyAllocationMinorUnits"
    | "allocationLabel"
    | "note"
  >
>;

export function normalizeDescription(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/\s+/g, " ")
    .trim()
    .toUpperCase();
}
