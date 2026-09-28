import { z } from "zod";

import { loadConfig } from "../config.js";
import { hashPassword } from "../security/password.js";
import { createPool } from "./pool.js";

const input = z
  .object({
    BOOTSTRAP_NAME: z.string().min(2),
    BOOTSTRAP_EMAIL: z.email(),
    BOOTSTRAP_PASSWORD: z.string().min(12),
  })
  .parse(process.env);
const config = loadConfig();
const pool = createPool(config.databaseUrl);

try {
  const passwordHash = await hashPassword(input.BOOTSTRAP_PASSWORD);
  const result = await pool.query<{ id: string }>(
    `INSERT INTO users (name, email, password_hash)
     VALUES ($1, lower($2), $3)
     ON CONFLICT (email) DO UPDATE SET
       name = EXCLUDED.name,
       password_hash = EXCLUDED.password_hash,
       updated_at = now()
     RETURNING id`,
    [input.BOOTSTRAP_NAME, input.BOOTSTRAP_EMAIL, passwordHash],
  );
  process.stdout.write(`Usuário administrativo pronto: ${result.rows[0]?.id}\n`);
} finally {
  await pool.end();
}
