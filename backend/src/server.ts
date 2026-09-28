import { buildApp } from "./app.js";
import { loadConfig } from "./config.js";
import { createPool } from "./db/pool.js";
import { createPostgresRepositories } from "./postgres-repositories.js";
import { PluggyClient } from "./integrations/pluggy/client.js";
import { createPluggySyncService } from "./integrations/pluggy/sync-service.js";
import { createCommitmentsService } from "./insights/commitments-service.js";
import { createFinancialDocumentService } from "./imports/pdf-document-service.js";
import { createAiInsightsService } from "./insights/ai-insights-service.js";
import { createMerchantAliasService } from "./insights/merchant-aliases.js";

const config = loadConfig();
const pool = createPool(config.databaseUrl);
const pluggySync = config.pluggy
  ? createPluggySyncService(
      pool,
      new PluggyClient({
        clientId: config.pluggy.clientId,
        clientSecret: config.pluggy.clientSecret,
      }),
      config.pluggy.itemId,
    )
  : undefined;
const aiInsights = config.ai
  ? createAiInsightsService(pool, config.ai)
  : undefined;
const app = await buildApp({
  config,
  repositories: createPostgresRepositories(pool),
  commitments: createCommitmentsService(pool),
  financialDocuments: createFinancialDocumentService(pool),
  ...(pluggySync ? { pluggySync } : {}),
  ...(aiInsights ? { aiInsights } : {}),
  merchantAliases: createMerchantAliasService(pool),
  logger: true,
});

const shutdown = async (signal: string) => {
  app.log.info({ signal }, "Encerrando API");
  await app.close();
  await pool.end();
  process.exit(0);
};

process.on("SIGINT", () => void shutdown("SIGINT"));
process.on("SIGTERM", () => void shutdown("SIGTERM"));

await app.listen({ host: config.host, port: config.port });
