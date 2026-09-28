import type {
  Account,
  BenefitWallet,
  BenefitWalletPatch,
  Category,
  CreateBenefitWallet,
  CreateFixedExpense,
  CreateTransaction,
  FixedExpense,
  FixedExpensePatch,
  CreateSubscription,
  Subscription,
  SubscriptionPatch,
  FinancialTransaction,
  Institution,
  TransactionPatch,
  User,
} from "./domain.js";

export interface DatabaseHealth {
  ping(): Promise<void>;
}

export interface UserRepository {
  findByEmail(email: string): Promise<User | null>;
}

export interface InstitutionRepository {
  list(userId: string): Promise<Institution[]>;
  create(userId: string, input: Omit<Institution, "id">): Promise<Institution>;
}

export interface AccountRepository {
  list(userId: string): Promise<Account[]>;
  create(
    userId: string,
    input: Omit<
      Account,
      | "id"
      | "lastSyncAt"
      | "balanceGroupKey"
      | "creditLimitMinorUnits"
      | "balanceDueDate"
    >,
  ): Promise<Account>;
}

export interface CategoryRepository {
  list(): Promise<Category[]>;
}

export type TransactionFilters = {
  from?: string | undefined;
  to?: string | undefined;
  search?: string | undefined;
};

export interface TransactionRepository {
  list(userId: string, filters: TransactionFilters): Promise<FinancialTransaction[]>;
  create(userId: string, input: CreateTransaction): Promise<FinancialTransaction>;
  update(
    userId: string,
    transactionId: string,
    patch: TransactionPatch,
  ): Promise<FinancialTransaction | null>;
}

export interface FixedExpenseRepository {
  list(userId: string): Promise<FixedExpense[]>;
  create(userId: string, input: CreateFixedExpense): Promise<FixedExpense>;
  update(
    userId: string,
    fixedExpenseId: string,
    patch: FixedExpensePatch,
  ): Promise<FixedExpense | null>;
  archive(userId: string, fixedExpenseId: string): Promise<boolean>;
}

export interface SubscriptionRepository {
  list(userId: string): Promise<Subscription[]>;
  create(userId: string, input: CreateSubscription): Promise<Subscription>;
  update(
    userId: string,
    subscriptionId: string,
    patch: SubscriptionPatch,
  ): Promise<Subscription | null>;
  archive(userId: string, subscriptionId: string): Promise<boolean>;
}

export interface BenefitWalletRepository {
  list(userId: string): Promise<BenefitWallet[]>;
  create(userId: string, input: CreateBenefitWallet): Promise<BenefitWallet>;
  update(
    userId: string,
    walletId: string,
    patch: BenefitWalletPatch,
  ): Promise<BenefitWallet | null>;
  archive(userId: string, walletId: string): Promise<boolean>;
}

export type Repositories = {
  health: DatabaseHealth;
  users: UserRepository;
  institutions: InstitutionRepository;
  accounts: AccountRepository;
  categories: CategoryRepository;
  transactions: TransactionRepository;
  fixedExpenses: FixedExpenseRepository;
  subscriptions: SubscriptionRepository;
  benefitWallets: BenefitWalletRepository;
};
