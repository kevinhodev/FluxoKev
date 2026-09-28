import { createHash } from "node:crypto";

import type { PoolClient } from "pg";

import type { DatabasePool } from "../../db/pool.js";
import { normalizeDescription } from "../../domain.js";
import type {
  PluggyAccount,
  PluggyClient,
  PluggyItem,
  PluggyTransaction,
} from "./client.js";
import {
  creditBalanceGroupKey,
  mapAccountBalanceMinorUnits,
  mapAccountType,
  mapAvailableBalanceMinorUnits,
  mapCreditLimitMinorUnits,
  mapPluggyTransaction,
} from "./mapping.js";

export type PluggySyncResult = {
  itemStatus: string;
  executionStatus: string | null;
  accounts: number;
  transactions: number;
  syncedAt: string;
};

export type PluggyConnectionStatus = {
  configured: true;
  provider: "PLUGGY";
  connectorName: string;
  status: string;
  executionStatus: string | null;
  providerUpdatedAt: string | null;
  lastSyncAt: string | null;
  lastError: string | null;
} | null;

export interface PluggySyncService {
  sync(userId: string): Promise<PluggySyncResult>;
  getStatus(userId: string): Promise<PluggyConnectionStatus>;
}

export function createPluggySyncService(
  pool: DatabasePool,
  client: PluggyClient,
  itemId: string,
): PluggySyncService {
  return {
    async sync(userId) {
      const item = await client.getItem(itemId);
      if (!new Set(["SUCCESS", "PARTIAL_SUCCESS"]).has(item.executionStatus ?? "")) {
        throw new Error(`Conexão Pluggy indisponível: ${item.executionStatus ?? item.status}.`);
      }
      const accounts = await client.listAccounts(itemId);
      const bankAccounts = accounts.filter((account) => account.type === "BANK");
      const transactionsByAccount = new Map<string, PluggyTransaction[]>();
      await Promise.all(
        bankAccounts.map(async (account) => {
          transactionsByAccount.set(account.id, await client.listTransactions(account.id));
        }),
      );

      const syncedAt = new Date().toISOString();
      const db = await pool.connect();
      try {
        await db.query("BEGIN");
        const connectionId = await upsertConnection(db, userId, item, syncedAt);
        const institutionId = await upsertInstitution(db, userId, item, bankAccounts);
        let transactionCount = 0;
        for (const account of bankAccounts) {
          const accountId = await upsertAccount(
            db,
            userId,
            institutionId,
            connectionId,
            account,
            syncedAt,
          );
          for (const transaction of transactionsByAccount.get(account.id) ?? []) {
            await upsertTransaction(db, userId, accountId, account, transaction);
            transactionCount++;
          }
        }
        await db.query("COMMIT");
        return {
          itemStatus: item.status,
          executionStatus: item.executionStatus,
          accounts: bankAccounts.length,
          transactions: transactionCount,
          syncedAt,
        };
      } catch (error) {
        await db.query("ROLLBACK");
        throw error;
      } finally {
        db.release();
      }
    },

    async getStatus(userId) {
      const result = await pool.query(
        `SELECT connector_name, status, execution_status, provider_updated_at,
                last_sync_at, last_error
         FROM financial_connections
         WHERE user_id = $1 AND provider = 'PLUGGY'
         ORDER BY updated_at DESC LIMIT 1`,
        [userId],
      );
      const row = result.rows[0] as Record<string, unknown> | undefined;
      if (!row) return null;
      return {
        configured: true,
        provider: "PLUGGY",
        connectorName: String(row.connector_name),
        status: String(row.status),
        executionStatus:
          row.execution_status == null ? null : String(row.execution_status),
        providerUpdatedAt: asOptionalIso(row.provider_updated_at),
        lastSyncAt: asOptionalIso(row.last_sync_at),
        lastError: row.last_error == null ? null : String(row.last_error),
      };
    },
  };
}

async function upsertConnection(
  db: PoolClient,
  userId: string,
  item: PluggyItem,
  syncedAt: string,
): Promise<string> {
  const result = await db.query(
    `INSERT INTO financial_connections (
       user_id, provider, external_item_id, connector_name, status,
       execution_status, provider_updated_at, last_sync_at, last_error
     ) VALUES ($1, 'PLUGGY', $2, $3, $4, $5, $6, $7, NULL)
     ON CONFLICT (user_id, provider, external_item_id) DO UPDATE SET
       connector_name = EXCLUDED.connector_name,
       status = EXCLUDED.status,
       execution_status = EXCLUDED.execution_status,
       provider_updated_at = EXCLUDED.provider_updated_at,
       last_sync_at = EXCLUDED.last_sync_at,
       last_error = NULL,
       updated_at = now()
     RETURNING id`,
    [
      userId,
      item.id,
      item.connector?.name ?? "Pluggy",
      item.status,
      item.executionStatus,
      item.lastUpdatedAt,
      syncedAt,
    ],
  );
  return String(result.rows[0].id);
}

async function upsertInstitution(
  db: PoolClient,
  userId: string,
  item: PluggyItem,
  accounts: PluggyAccount[],
): Promise<string> {
  const bank = accounts.find((account) => account.type === "BANK");
  const name = bank?.marketingName || bank?.name || item.connector?.name || "Pluggy";
  const result = await db.query(
    `INSERT INTO institutions (user_id, name, type, external_id)
     VALUES ($1, $2, 'BANK', $3)
     ON CONFLICT (user_id, name) DO UPDATE SET external_id = EXCLUDED.external_id
     RETURNING id`,
    [userId, name, item.id],
  );
  return String(result.rows[0].id);
}

async function upsertAccount(
  db: PoolClient,
  userId: string,
  institutionId: string,
  connectionId: string,
  account: PluggyAccount,
  syncedAt: string,
): Promise<string> {
  const result = await db.query(
    `INSERT INTO accounts (
       user_id, institution_id, connection_id, external_id, name, type,
       currency, current_balance_minor_units, available_balance_minor_units,
       balance_group_key, credit_limit_minor_units, balance_due_date,
       provider_metadata, last_sync_at
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13::jsonb, $14)
     ON CONFLICT (user_id, external_id) DO UPDATE SET
       institution_id = EXCLUDED.institution_id,
       connection_id = EXCLUDED.connection_id,
       name = EXCLUDED.name,
       type = EXCLUDED.type,
       currency = EXCLUDED.currency,
       current_balance_minor_units = EXCLUDED.current_balance_minor_units,
       available_balance_minor_units = EXCLUDED.available_balance_minor_units,
       balance_group_key = EXCLUDED.balance_group_key,
       credit_limit_minor_units = EXCLUDED.credit_limit_minor_units,
       balance_due_date = EXCLUDED.balance_due_date,
       provider_metadata = EXCLUDED.provider_metadata,
       last_sync_at = EXCLUDED.last_sync_at,
       updated_at = now()
     RETURNING id`,
    [
      userId,
      institutionId,
      connectionId,
      account.id,
      account.marketingName || account.name,
      mapAccountType(account),
      account.currencyCode || "BRL",
      mapAccountBalanceMinorUnits(account),
      mapAvailableBalanceMinorUnits(account),
      creditBalanceGroupKey(account),
      mapCreditLimitMinorUnits(account),
      account.creditData?.balanceDueDate ?? null,
      JSON.stringify({
        brand: account.creditData?.brand ?? null,
        level: account.creditData?.level ?? null,
        status: account.creditData?.status ?? null,
        minimumPayment: account.creditData?.minimumPayment ?? null,
        lastFourDigits:
          account.type === "CREDIT"
            ? account.number?.replace(/\D/g, "").slice(-4) || null
            : null,
      }),
      syncedAt,
    ],
  );
  return String(result.rows[0].id);
}

async function upsertTransaction(
  db: PoolClient,
  userId: string,
  accountId: string,
  account: PluggyAccount,
  transaction: PluggyTransaction,
): Promise<void> {
  const mapped = mapPluggyTransaction(account, transaction);
  const description = transaction.description.trim();
  const normalized = normalizeDescription(description);
  const fingerprint = createHash("sha256")
    .update(
      [accountId, transaction.date.slice(0, 10), mapped.amountMinorUnits, normalized].join(
        "|",
      ),
    )
    .digest("hex");
  const metadata = {
    providerCategoryId: transaction.categoryId ?? null,
    providerCode: transaction.providerCode ?? null,
    creditCard: transaction.creditCardMetadata ?? null,
  };

  await db.query(
    `INSERT INTO transactions (
       user_id, account_id, external_id, occurred_at, description,
       normalized_description, merchant_name, amount_minor_units, direction,
       nature, category_id, source, fingerprint, provider_status,
       provider_category, provider_metadata
     ) VALUES (
       $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, 'PLUGGY',
       $12, $13, $14, $15::jsonb
     )
     ON CONFLICT (user_id, source, external_id) DO UPDATE SET
       account_id = EXCLUDED.account_id,
       occurred_at = EXCLUDED.occurred_at,
       description = EXCLUDED.description,
       normalized_description = EXCLUDED.normalized_description,
       merchant_name = EXCLUDED.merchant_name,
       amount_minor_units = EXCLUDED.amount_minor_units,
       direction = EXCLUDED.direction,
       nature = EXCLUDED.nature,
       category_id = EXCLUDED.category_id,
       fingerprint = EXCLUDED.fingerprint,
       provider_status = EXCLUDED.provider_status,
       provider_category = EXCLUDED.provider_category,
       provider_metadata = EXCLUDED.provider_metadata,
       updated_at = now()`,
    [
      userId,
      accountId,
      transaction.id,
      transaction.date,
      description,
      normalized,
      transaction.merchant?.name?.trim() || description,
      mapped.amountMinorUnits,
      mapped.direction,
      mapped.nature,
      mapped.categoryId,
      fingerprint,
      transaction.status,
      transaction.category ?? null,
      JSON.stringify(metadata),
    ],
  );
}

function asOptionalIso(value: unknown): string | null {
  if (value == null) return null;
  return value instanceof Date ? value.toISOString() : new Date(String(value)).toISOString();
}
