import { readFile, readdir } from "node:fs/promises";
import { resolve } from "node:path";

import { loadConfig } from "../config.js";
import { createPool } from "./pool.js";

const config = loadConfig();
const pool = createPool(config.databaseUrl);

try {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      name TEXT PRIMARY KEY,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);
  const directory = resolve(process.cwd(), "migrations");
  const files = (await readdir(directory))
    .filter((file) => file.endsWith(".sql"))
    .sort();

  for (const file of files) {
    const alreadyApplied = await pool.query(
      "SELECT 1 FROM schema_migrations WHERE name = $1",
      [file],
    );
    if (alreadyApplied.rowCount) continue;

    const client = await pool.connect();
    try {
      await client.query("BEGIN");
      await client.query(await readFile(resolve(directory, file), "utf8"));
      await client.query("INSERT INTO schema_migrations (name) VALUES ($1)", [file]);
      await client.query("COMMIT");
      process.stdout.write(`Migração aplicada: ${file}\n`);
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
    }
  }
} finally {
  await pool.end();
}
