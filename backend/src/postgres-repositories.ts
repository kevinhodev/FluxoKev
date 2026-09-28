import { createHash } from "node:crypto";

import type { PoolClient } from "pg";

import type {
  Account,
  BenefitWallet,
  BenefitWalletPatch,
  Category,
  CreateBenefitWallet,
  CreateFixedExpense,
  CreateSubscription,
  CreateTransaction,
  FixedExpense,
  FixedExpensePatch,
  FinancialTransaction,
  Institution,
  Subscription,
  SubscriptionPatch,
  TransactionPatch,
  User,
} from "./domain.js";
import { normalizeDescription } from "./domain.js";
import {
  CATEGORY_ID_SQL,
  MERCHANT_NAME_SQL,
} from "./insights/merchant-aliases.js";
import type { DatabasePool } from "./db/pool.js";
import type { Repositories, TransactionFilters } from "./repositories.js";

type DbRow = Record<string, unknown>;

function asNumber(value: unknown): number {
  const result = Number(value);
  if (!Number.isSafeInteger(result)) throw new Error("Valor monetário fora do limite seguro.");
  return result;
}

function asIso(value: unknown): string {
  return value instanceof Date ? value.toISOString() : new Date(String(value)).toISOString();
}

function mapInstitution(row: DbRow): Institution {
  return {
    id: String(row.id),
    name: String(row.name),
    type: row.type as Institution["type"],
    externalId: row.external_id == null ? null : String(row.external_id),
  };
}

function mapAccount(row: DbRow): Account {
  return {
    id: String(row.id),
    institutionId: String(row.institution_id),
    name: String(row.name),
    type: row.type as Account["type"],
    currency: String(row.currency),
    currentBalanceMinorUnits: asNumber(row.current_balance_minor_units),
    availableBalanceMinorUnits:
      row.available_balance_minor_units == null
        ? null
        : asNumber(row.available_balance_minor_units),
    balanceGroupKey: row.balance_group_key == null ? null : String(row.balance_group_key),
    creditLimitMinorUnits:
      row.credit_limit_minor_units == null ? null : asNumber(row.credit_limit_minor_units),
    balanceDueDate:
      row.balance_due_date == null
        ? null
        : new Date(String(row.balance_due_date)).toISOString().slice(0, 10),
    lastSyncAt: row.last_sync_at == null ? null : asIso(row.last_sync_at),
  };
}

function mapCategory(row: DbRow): Category {
  return {
    id: String(row.id),
    parentId: row.parent_id == null ? null : String(row.parent_id),
    name: String(row.name),
    type: row.type as Category["type"],
  };
}

function mapTransaction(row: DbRow): FinancialTransaction {
  return {
    id: String(row.id),
    accountId: String(row.account_id),
    externalId: row.external_id == null ? null : String(row.external_id),
    occurredAt: asIso(row.occurred_at),
    description: String(row.description),
    normalizedDescription: String(row.normalized_description),
    merchantName: String(row.merchant_name),
    amountMinorUnits: asNumber(row.amount_minor_units),
    direction: row.direction as FinancialTransaction["direction"],
    nature: row.nature as FinancialTransaction["nature"],
    categoryId: String(row.category_id),
    source: row.source as FinancialTransaction["source"],
    providerStatus:
      row.provider_status == null
        ? null
        : (String(row.provider_status) as FinancialTransaction["providerStatus"]),
    providerCategory:
      row.provider_category == null ? null : String(row.provider_category),
    note: row.note == null ? null : String(row.note),
    createdAt: asIso(row.created_at),
    updatedAt: asIso(row.updated_at),
  };
}

function mapFixedExpense(row: DbRow): FixedExpense {
  return {
    id: String(row.id),
    name: String(row.name),
    categoryId: String(row.category_id),
    amountMinorUnits:
      row.amount_minor_units == null ? null : asNumber(row.amount_minor_units),
    valueKind: row.value_kind as FixedExpense["valueKind"],
    frequency: "MONTHLY",
    locationLabel: String(row.location_label),
    dueDay: row.due_day == null ? null : Number(row.due_day),
    active: row.active === true,
    note: row.note == null ? null : String(row.note),
    createdAt: asIso(row.created_at),
    updatedAt: asIso(row.updated_at),
  };
}

function mapSubscription(row: DbRow): Subscription {
  return {
    id: String(row.id),
    name: String(row.name),
    billingDescriptor: String(row.billing_descriptor),
    amountMinorUnits: asNumber(row.amount_minor_units),
    frequency: "MONTHLY",
    billingDay: row.billing_day == null ? null : Number(row.billing_day),
    paymentMethodLabel: String(row.payment_method_label),
    active: row.active === true,
    note: row.note == null ? null : String(row.note),
    createdAt: asIso(row.created_at),
    updatedAt: asIso(row.updated_at),
  };
}

function mapBenefitWallet(row: DbRow): BenefitWallet {
  return {
    id: String(row.id),
    name: String(row.name),
    currentBalanceMinorUnits: asNumber(row.current_balance_minor_units),
    monthlyCreditMinorUnits: asNumber(row.monthly_credit_minor_units),
    monthlyAllocationMinorUnits: asNumber(row.monthly_allocation_minor_units),
    allocationLabel: String(row.allocation_label),
    active: row.active === true,
    note: row.note == null ? null : String(row.note),
    createdAt: asIso(row.created_at),
    updatedAt: asIso(row.updated_at),
  };
}

function transactionFingerprint(input: CreateTransaction): string {
  return createHash("sha256")
    .update(
      [
        input.accountId,
        input.occurredAt.slice(0, 10),
        input.amountMinorUnits,
        normalizeDescription(input.description),
      ].join("|"),
    )
    .digest("hex");
}

export function createPostgresRepositories(pool: DatabasePool): Repositories {
  return {
    health: {
      async ping() {
        await pool.query("SELECT 1");
      },
    },
    users: {
      async findByEmail(email) {
        const result = await pool.query(
          `SELECT id, name, email, password_hash
           FROM users WHERE email = lower($1) LIMIT 1`,
          [email],
        );
        const row = result.rows[0] as DbRow | undefined;
        if (!row) return null;
        return {
          id: String(row.id),
          name: String(row.name),
          email: String(row.email),
          passwordHash: String(row.password_hash),
        } satisfies User;
      },
    },
    institutions: {
      async list(userId) {
        const result = await pool.query(
          `SELECT id, name, type, external_id
           FROM institutions WHERE user_id = $1 ORDER BY name`,
          [userId],
        );
        return result.rows.map((row) => mapInstitution(row as DbRow));
      },
      async create(userId, input) {
        const result = await pool.query(
          `INSERT INTO institutions (user_id, name, type, external_id)
           VALUES ($1, $2, $3, $4)
           RETURNING id, name, type, external_id`,
          [userId, input.name, input.type, input.externalId],
        );
        return mapInstitution(result.rows[0] as DbRow);
      },
    },
    accounts: {
      async list(userId) {
        const result = await pool.query(
          `SELECT a.id, a.institution_id, a.name, a.type, a.currency,
                  CASE
                    WHEN statement.id IS NOT NULL AND statement.status = 'PAID' THEN 0
                    WHEN statement.id IS NOT NULL THEN -statement.total_minor_units
                    ELSE a.current_balance_minor_units
                  END AS current_balance_minor_units,
                  a.available_balance_minor_units,
                  CASE WHEN statement.id IS NOT NULL THEN NULL ELSE a.balance_group_key END
                    AS balance_group_key,
                  a.credit_limit_minor_units,
                  COALESCE(statement.due_date, a.balance_due_date) AS balance_due_date,
                  a.last_sync_at
           FROM accounts a
           LEFT JOIN LATERAL (
             SELECT id, status, total_minor_units, due_date
             FROM credit_card_statements
             WHERE user_id = a.user_id AND account_id = a.id
             ORDER BY statement_month DESC
             LIMIT 1
           ) statement ON true
           WHERE a.user_id = $1 ORDER BY a.name`,
          [userId],
        );
        return result.rows.map((row) => mapAccount(row as DbRow));
      },
      async create(userId, input) {
        const result = await pool.query(
          `INSERT INTO accounts (
             user_id, institution_id, name, type, currency,
             current_balance_minor_units, available_balance_minor_units
           )
           SELECT $1, id, $3, $4, $5, $6, $7
           FROM institutions WHERE id = $2 AND user_id = $1
           RETURNING id, institution_id, name, type, currency,
                     current_balance_minor_units, available_balance_minor_units,
                     balance_group_key, credit_limit_minor_units, balance_due_date, last_sync_at`,
          [
            userId,
            input.institutionId,
            input.name,
            input.type,
            input.currency,
            input.currentBalanceMinorUnits,
            input.availableBalanceMinorUnits,
          ],
        );
        const row = result.rows[0] as DbRow | undefined;
        if (!row) throw new ReferenceError("Instituição não encontrada.");
        return mapAccount(row);
      },
    },
    categories: {
      async list() {
        const result = await pool.query(
          "SELECT id, parent_id, name, type FROM categories ORDER BY type, name",
        );
        return result.rows.map((row) => mapCategory(row as DbRow));
      },
    },
    transactions: {
      async list(userId, filters) {
        return listTransactions(pool, userId, filters);
      },
      async create(userId, input) {
        const normalized = normalizeDescription(input.description);
        const result = await pool.query(
          `INSERT INTO transactions (
             user_id, account_id, occurred_at, description, normalized_description,
             merchant_name, amount_minor_units, direction, nature, category_id,
             source, fingerprint, note
           )
           SELECT $1, a.id, $3, $4, $5, $6, $7, $8, $9, $10, 'MANUAL', $11, $12
           FROM accounts a WHERE a.id = $2 AND a.user_id = $1
           RETURNING *`,
          [
            userId,
            input.accountId,
            input.occurredAt,
            input.description,
            normalized,
            input.merchantName,
            input.amountMinorUnits,
            input.direction,
            input.nature,
            input.categoryId,
            transactionFingerprint(input),
            input.note,
          ],
        );
        const row = result.rows[0] as DbRow | undefined;
        if (!row) throw new ReferenceError("Conta não encontrada.");
        return mapTransaction(row);
      },
      async update(userId, transactionId, patch) {
        return updateTransaction(pool, userId, transactionId, patch);
      },
    },
    fixedExpenses: {
      async list(userId) {
        const result = await pool.query(
          `SELECT * FROM fixed_expenses
           WHERE user_id = $1 AND active = true
           ORDER BY value_kind, name`,
          [userId],
        );
        return result.rows.map((row) => mapFixedExpense(row as DbRow));
      },
      async create(userId, input) {
        const result = await pool.query(
          `INSERT INTO fixed_expenses (
             user_id, name, category_id, amount_minor_units, value_kind,
             frequency, location_label, due_day, note
           ) VALUES ($1,$2,$3,$4,$5,'MONTHLY',$6,$7,$8)
           RETURNING *`,
          [
            userId,
            input.name,
            input.categoryId,
            input.amountMinorUnits,
            input.valueKind,
            input.locationLabel,
            input.dueDay,
            input.note,
          ],
        );
        return mapFixedExpense(result.rows[0] as DbRow);
      },
      async update(userId, fixedExpenseId, patch) {
        return updateFixedExpense(pool, userId, fixedExpenseId, patch);
      },
      async archive(userId, fixedExpenseId) {
        const result = await pool.query(
          `UPDATE fixed_expenses SET active = false, updated_at = now()
           WHERE id = $1 AND user_id = $2 AND active = true`,
          [fixedExpenseId, userId],
        );
        return (result.rowCount ?? 0) > 0;
      },
    },
    subscriptions: {
      async list(userId) {
        const result = await pool.query(
          `SELECT * FROM subscriptions
           WHERE user_id = $1 AND active = true
           ORDER BY billing_day NULLS LAST, name`,
          [userId],
        );
        return result.rows.map((row) => mapSubscription(row as DbRow));
      },
      async create(userId, input: CreateSubscription) {
        const result = await pool.query(
          `INSERT INTO subscriptions (
             user_id, name, billing_descriptor, amount_minor_units, frequency,
             billing_day, payment_method_label, note
           ) VALUES ($1,$2,$3,$4,'MONTHLY',$5,$6,$7)
           RETURNING *`,
          [
            userId,
            input.name,
            input.billingDescriptor,
            input.amountMinorUnits,
            input.billingDay,
            input.paymentMethodLabel,
            input.note,
          ],
        );
        return mapSubscription(result.rows[0] as DbRow);
      },
      async update(userId, subscriptionId, patch) {
        return updateSubscription(pool, userId, subscriptionId, patch);
      },
      async archive(userId, subscriptionId) {
        const result = await pool.query(
          `UPDATE subscriptions SET active = false, updated_at = now()
           WHERE id = $1 AND user_id = $2 AND active = true`,
          [subscriptionId, userId],
        );
        return (result.rowCount ?? 0) > 0;
      },
    },
    benefitWallets: {
      async list(userId) {
        const result = await pool.query(
          `SELECT * FROM benefit_wallets
           WHERE user_id = $1 AND active = true
           ORDER BY name`,
          [userId],
        );
        return result.rows.map((row) => mapBenefitWallet(row as DbRow));
      },
      async create(userId, input: CreateBenefitWallet) {
        const result = await pool.query(
          `INSERT INTO benefit_wallets (
             user_id, name, current_balance_minor_units,
             monthly_credit_minor_units, monthly_allocation_minor_units,
             allocation_label, note
           ) VALUES ($1,$2,$3,$4,$5,$6,$7)
           RETURNING *`,
          [
            userId,
            input.name,
            input.currentBalanceMinorUnits,
            input.monthlyCreditMinorUnits,
            input.monthlyAllocationMinorUnits,
            input.allocationLabel,
            input.note,
          ],
        );
        return mapBenefitWallet(result.rows[0] as DbRow);
      },
      async update(userId, walletId, patch) {
        return updateBenefitWallet(pool, userId, walletId, patch);
      },
      async archive(userId, walletId) {
        const result = await pool.query(
          `UPDATE benefit_wallets SET active = false, updated_at = now()
           WHERE id = $1 AND user_id = $2 AND active = true`,
          [walletId, userId],
        );
        return (result.rowCount ?? 0) > 0;
      },
    },
  };
}

async function updateBenefitWallet(
  pool: DatabasePool,
  userId: string,
  walletId: string,
  patch: BenefitWalletPatch,
): Promise<BenefitWallet | null> {
  const fields: string[] = [];
  const values: unknown[] = [walletId, userId];
  const columns: Record<keyof BenefitWalletPatch, string> = {
    name: "name",
    currentBalanceMinorUnits: "current_balance_minor_units",
    monthlyCreditMinorUnits: "monthly_credit_minor_units",
    monthlyAllocationMinorUnits: "monthly_allocation_minor_units",
    allocationLabel: "allocation_label",
    note: "note",
  };
  for (const [key, column] of Object.entries(columns) as Array<
    [keyof BenefitWalletPatch, string]
  >) {
    if (!(key in patch)) continue;
    values.push(patch[key]);
    fields.push(`${column} = $${values.length}`);
  }
  if (fields.length === 0) return null;
  const result = await pool.query(
    `UPDATE benefit_wallets
     SET ${fields.join(", ")}, updated_at = now()
     WHERE id = $1 AND user_id = $2 AND active = true
     RETURNING *`,
    values,
  );
  const row = result.rows[0] as DbRow | undefined;
  return row ? mapBenefitWallet(row) : null;
}

async function updateSubscription(
  pool: DatabasePool,
  userId: string,
  subscriptionId: string,
  patch: SubscriptionPatch,
): Promise<Subscription | null> {
  const fields: string[] = [];
  const values: unknown[] = [subscriptionId, userId];
  const columns: Record<keyof SubscriptionPatch, string> = {
    name: "name",
    billingDescriptor: "billing_descriptor",
    amountMinorUnits: "amount_minor_units",
    billingDay: "billing_day",
    paymentMethodLabel: "payment_method_label",
    note: "note",
  };
  for (const [key, column] of Object.entries(columns) as Array<
    [keyof SubscriptionPatch, string]
  >) {
    if (!(key in patch)) continue;
    values.push(patch[key]);
    fields.push(`${column} = $${values.length}`);
  }
  if (fields.length === 0) return null;
  const result = await pool.query(
    `UPDATE subscriptions
     SET ${fields.join(", ")}, updated_at = now()
     WHERE id = $1 AND user_id = $2 AND active = true
     RETURNING *`,
    values,
  );
  const row = result.rows[0] as DbRow | undefined;
  return row ? mapSubscription(row) : null;
}

async function updateFixedExpense(
  pool: DatabasePool,
  userId: string,
  fixedExpenseId: string,
  patch: FixedExpensePatch,
): Promise<FixedExpense | null> {
  const fields: string[] = [];
  const values: unknown[] = [fixedExpenseId, userId];
  const columns: Record<keyof FixedExpensePatch, string> = {
    name: "name",
    categoryId: "category_id",
    amountMinorUnits: "amount_minor_units",
    valueKind: "value_kind",
    locationLabel: "location_label",
    dueDay: "due_day",
    note: "note",
  };
  for (const [key, column] of Object.entries(columns) as Array<
    [keyof FixedExpensePatch, string]
  >) {
    if (!(key in patch)) continue;
    values.push(patch[key]);
    fields.push(`${column} = $${values.length}`);
  }
  if (fields.length === 0) return null;
  const result = await pool.query(
    `UPDATE fixed_expenses
     SET ${fields.join(", ")}, updated_at = now()
     WHERE id = $1 AND user_id = $2 AND active = true
     RETURNING *`,
    values,
  );
  const row = result.rows[0] as DbRow | undefined;
  return row ? mapFixedExpense(row) : null;
}

async function listTransactions(
  pool: DatabasePool,
  userId: string,
  filters: TransactionFilters,
): Promise<FinancialTransaction[]> {
  const clauses = [
    "t.user_id = $1",
    "NOT (t.source = 'PLUGGY' AND a.type = 'CREDIT_CARD')",
  ];
  const values: unknown[] = [userId];
  if (filters.from) {
    values.push(filters.from);
    clauses.push(`t.occurred_at >= $${values.length}`);
  }
  if (filters.to) {
    values.push(filters.to);
    clauses.push(`t.occurred_at <= $${values.length}`);
  }
  if (filters.search) {
    values.push(`%${normalizeDescription(filters.search)}%`);
    clauses.push(
      `(t.normalized_description LIKE $${values.length} OR upper(t.merchant_name) LIKE $${values.length})`,
    );
  }
  const result = await pool.query(
    // Sobrepõe nome e categoria pelas regras do usuário. Corrigir na própria
    // transação não adiantaria: a sincronização da Pluggy sobrescreve os dois.
    `SELECT t.*,
            ${MERCHANT_NAME_SQL} AS merchant_name,
            ${CATEGORY_ID_SQL} AS category_id
     FROM transactions t
     JOIN accounts a ON a.id = t.account_id AND a.user_id = t.user_id
     WHERE ${clauses.join(" AND ")}
     ORDER BY t.occurred_at DESC, t.created_at DESC
     LIMIT 500`,
    values,
  );
  return result.rows.map((row) => mapTransaction(row as DbRow));
}

async function updateTransaction(
  pool: DatabasePool,
  userId: string,
  transactionId: string,
  patch: TransactionPatch,
): Promise<FinancialTransaction | null> {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const currentResult = await client.query(
      "SELECT * FROM transactions WHERE id = $1 AND user_id = $2 FOR UPDATE",
      [transactionId, userId],
    );
    const currentRow = currentResult.rows[0] as DbRow | undefined;
    if (!currentRow) {
      await client.query("ROLLBACK");
      return null;
    }
    const current = mapTransaction(currentRow);
    const next: FinancialTransaction = {
      ...current,
      occurredAt: patch.occurredAt ?? current.occurredAt,
      description: patch.description ?? current.description,
      merchantName: patch.merchantName ?? current.merchantName,
      amountMinorUnits: patch.amountMinorUnits ?? current.amountMinorUnits,
      direction: patch.direction ?? current.direction,
      nature: patch.nature ?? current.nature,
      categoryId: patch.categoryId ?? current.categoryId,
      note: patch.note === undefined ? current.note : patch.note,
    };
    const updatedResult = await client.query(
      `UPDATE transactions SET
         occurred_at = $3,
         description = $4,
         normalized_description = $5,
         merchant_name = $6,
         amount_minor_units = $7,
         direction = $8,
         nature = $9,
         category_id = $10,
         note = $11,
         updated_at = now()
       WHERE id = $1 AND user_id = $2
       RETURNING *`,
      [
        transactionId,
        userId,
        next.occurredAt,
        next.description,
        normalizeDescription(next.description),
        next.merchantName,
        next.amountMinorUnits,
        next.direction,
        next.nature,
        next.categoryId,
        next.note,
      ],
    );
    const updated = mapTransaction(updatedResult.rows[0] as DbRow);
    await writeAudit(client, userId, transactionId, current, updated);
    await client.query("COMMIT");
    return updated;
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

async function writeAudit(
  client: PoolClient,
  userId: string,
  entityId: string,
  oldValue: FinancialTransaction,
  newValue: FinancialTransaction,
) {
  await client.query(
    `INSERT INTO audit_logs (
       user_id, entity_type, entity_id, action, old_value, new_value, source
     ) VALUES ($1, 'TRANSACTION', $2, 'UPDATE', $3::jsonb, $4::jsonb, 'USER')`,
    [userId, entityId, JSON.stringify(oldValue), JSON.stringify(newValue)],
  );
}
