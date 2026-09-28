import type { DatabasePool } from "../db/pool.js";

export type MerchantAlias = {
  id: string;
  pattern: string;
  merchantName: string;
  /** Quantas transações o apelido cobre hoje. */
  matches: number;
  totalMinorUnits: number;
  /** Descritores brutos que a regra substituiu, para o usuário conferir. */
  descriptors: string[];
  /** Nulo quando a regra só renomeia, sem opinar sobre categoria. */
  categoryId: string | null;
};

export type CreateMerchantAlias = {
  pattern: string;
  merchantName: string;
  categoryId: string | null;
};

export interface MerchantAliasService {
  list(userId: string): Promise<MerchantAlias[]>;
  create(userId: string, input: CreateMerchantAlias): Promise<MerchantAlias>;
  update(
    userId: string,
    id: string,
    input: CreateMerchantAlias,
  ): Promise<MerchantAlias | null>;
  remove(userId: string, id: string): Promise<boolean>;
  /** Prévia antes de salvar: quantas transações o prefixo pegaria. */
  preview(
    userId: string,
    pattern: string,
  ): Promise<{ matches: number; totalMinorUnits: number; samples: string[] }>;
}

/**
 * SQL reaproveitado por quem precisa do nome normalizado. Fica aqui para que a
 * regra de casamento — prefixo, sem diferenciar maiúsculas — exista num lugar
 * só, em vez de ser reescrita em cada consulta.
 */
/**
 * Categoria efetiva: a da regra quando ela define uma, senão a que veio do
 * banco. Mesma precedência do nome — regra mais específica (prefixo mais
 * longo) ganha.
 */
export const CATEGORY_ID_SQL = `COALESCE(
  (SELECT a.category_id FROM merchant_aliases a
    WHERE a.user_id = t.user_id
      AND a.category_id IS NOT NULL
      AND upper(t.description) LIKE upper(a.pattern) || '%'
    ORDER BY length(a.pattern) DESC
    LIMIT 1),
  t.category_id
)`;

export const MERCHANT_NAME_SQL = `COALESCE(
  (SELECT a.merchant_name FROM merchant_aliases a
    WHERE a.user_id = t.user_id
      AND upper(t.description) LIKE upper(a.pattern) || '%'
    ORDER BY length(a.pattern) DESC
    LIMIT 1),
  split_part(t.description, '  ', 1)
)`;

export function createMerchantAliasService(
  pool: DatabasePool,
): MerchantAliasService {
  return {
    async list(userId) {
      const result = await pool.query(
        `SELECT a.id, a.pattern, a.merchant_name, a.category_id,
                (SELECT count(*) FROM transactions t
                  WHERE t.user_id = a.user_id
                    AND upper(t.description) LIKE upper(a.pattern) || '%') AS matches,
                COALESCE((SELECT sum(t.amount_minor_units) FROM transactions t
                  WHERE t.user_id = a.user_id
                    AND upper(t.description) LIKE upper(a.pattern) || '%'
                    AND t.direction = 'DEBIT'), 0) AS total,
                COALESCE((SELECT array_agg(DISTINCT split_part(t.description, '  ', 1))
                  FROM transactions t
                  WHERE t.user_id = a.user_id
                    AND upper(t.description) LIKE upper(a.pattern) || '%'), '{}') AS descriptors
         FROM merchant_aliases a
         WHERE a.user_id = $1
         ORDER BY a.merchant_name`,
        [userId],
      );
      return result.rows.map(mapAlias);
    },

    async preview(userId, pattern) {
      const result = await pool.query(
        `SELECT count(*) AS matches,
                COALESCE(sum(amount_minor_units) FILTER (WHERE direction = 'DEBIT'), 0) AS total,
                (array_agg(DISTINCT split_part(description, '  ', 1)))[1:5] AS samples
         FROM transactions
         WHERE user_id = $1 AND upper(description) LIKE upper($2) || '%'`,
        [userId, pattern.trim()],
      );
      const row = result.rows[0];
      return {
        matches: Number(row?.matches ?? 0),
        totalMinorUnits: Number(row?.total ?? 0),
        samples: ((row?.samples as string[] | null) ?? []).map((s) => s.trim()),
      };
    },

    async create(userId, input) {
      const result = await pool.query(
        `INSERT INTO merchant_aliases (user_id, pattern, merchant_name, category_id)
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (user_id, pattern)
           DO UPDATE SET merchant_name = EXCLUDED.merchant_name,
                         category_id = EXCLUDED.category_id
         RETURNING id, pattern, merchant_name, category_id`,
        [userId, input.pattern.trim(), input.merchantName.trim(), input.categoryId],
      );
      const created = result.rows[0];
      const stats = await this.preview(userId, input.pattern);
      return {
        id: String(created.id),
        pattern: String(created.pattern),
        merchantName: String(created.merchant_name),
        matches: stats.matches,
        totalMinorUnits: stats.totalMinorUnits,
        descriptors: stats.samples,
        categoryId: created.category_id == null ? null : String(created.category_id),
      };
    },

    async update(userId, id, input) {
      const pattern = input.pattern.trim();
      // O par (user_id, pattern) é único: mudar o prefixo para um já usado por
      // outra regra colidiria, e o erro cru do Postgres não diria qual.
      const clash = await pool.query(
        `SELECT 1 FROM merchant_aliases
          WHERE user_id = $1 AND pattern = $2 AND id <> $3`,
        [userId, pattern, id],
      );
      if ((clash.rowCount ?? 0) > 0) {
        throw new Error(`Já existe uma regra para "${pattern}".`);
      }
      const result = await pool.query(
        `UPDATE merchant_aliases
            SET pattern = $3, merchant_name = $4, category_id = $5
          WHERE id = $1 AND user_id = $2
          RETURNING id, pattern, merchant_name, category_id`,
        [id, userId, pattern, input.merchantName.trim(), input.categoryId],
      );
      const row = result.rows[0];
      if (!row) return null;
      const stats = await this.preview(userId, pattern);
      return {
        id: String(row.id),
        pattern: String(row.pattern),
        merchantName: String(row.merchant_name),
        matches: stats.matches,
        totalMinorUnits: stats.totalMinorUnits,
        descriptors: stats.samples,
        categoryId: row.category_id == null ? null : String(row.category_id),
      };
    },

    async remove(userId, id) {
      const result = await pool.query(
        "DELETE FROM merchant_aliases WHERE id = $1 AND user_id = $2",
        [id, userId],
      );
      return (result.rowCount ?? 0) > 0;
    },
  };
}

function mapAlias(row: Record<string, unknown>): MerchantAlias {
  return {
    id: String(row.id),
    pattern: String(row.pattern),
    merchantName: String(row.merchant_name),
    matches: Number(row.matches),
    totalMinorUnits: Number(row.total),
    descriptors: ((row.descriptors as string[] | null) ?? [])
      .map((d) => d.trim())
      .sort(),
    categoryId: row.category_id == null ? null : String(row.category_id),
  };
}
