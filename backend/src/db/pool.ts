import pg from "pg";

const { Pool } = pg;

export function createPool(databaseUrl: string) {
  return new Pool({
    connectionString: databaseUrl,
    max: 10,
    idleTimeoutMillis: 30_000,
    connectionTimeoutMillis: 5_000,
  });
}

export type DatabasePool = ReturnType<typeof createPool>;
