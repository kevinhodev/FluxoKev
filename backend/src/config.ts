import { z } from "zod";

const configSchema = z
  .object({
    NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
    HOST: z.string().default("127.0.0.1"),
    PORT: z.coerce.number().int().min(1).max(65_535).default(8080),
    DATABASE_URL: z.url(),
    JWT_SECRET: z.string().min(32),
    JWT_EXPIRES_IN: z.string().default("15m"),
    CORS_ORIGINS: z.string().default(""),
    PLUGGY_CLIENT_ID: z.string().trim().optional(),
    PLUGGY_CLIENT_SECRET: z.string().trim().optional(),
    PLUGGY_ITEM_ID: z.string().uuid().optional(),
    ANTHROPIC_API_KEY: z.string().trim().min(1).optional(),
    // Trocável sem rebuild: o custo por pergunta muda bastante entre modelos.
    AI_MODEL: z.string().trim().default("claude-opus-5"),
  })
  .superRefine((value, context) => {
    const configured = [
      value.PLUGGY_CLIENT_ID,
      value.PLUGGY_CLIENT_SECRET,
      value.PLUGGY_ITEM_ID,
    ].filter(Boolean).length;
    if (configured !== 0 && configured !== 3) {
      context.addIssue({
        code: "custom",
        message:
          "PLUGGY_CLIENT_ID, PLUGGY_CLIENT_SECRET e PLUGGY_ITEM_ID devem ser definidos juntos.",
      });
    }
  });

export type AppConfig = {
  nodeEnv: "development" | "test" | "production";
  host: string;
  port: number;
  databaseUrl: string;
  jwtSecret: string;
  jwtExpiresIn: string;
  corsOrigins: string[];
  pluggy: {
    clientId: string;
    clientSecret: string;
    itemId: string;
  } | null;
  ai: { apiKey: string; model: string } | null;
};

export function loadConfig(environment: NodeJS.ProcessEnv = process.env): AppConfig {
  const parsed = configSchema.parse(environment);
  const pluggy =
    parsed.PLUGGY_CLIENT_ID && parsed.PLUGGY_CLIENT_SECRET && parsed.PLUGGY_ITEM_ID
      ? {
          clientId: parsed.PLUGGY_CLIENT_ID,
          clientSecret: parsed.PLUGGY_CLIENT_SECRET,
          itemId: parsed.PLUGGY_ITEM_ID,
        }
      : null;
  const ai = parsed.ANTHROPIC_API_KEY
    ? { apiKey: parsed.ANTHROPIC_API_KEY, model: parsed.AI_MODEL }
    : null;
  return {
    nodeEnv: parsed.NODE_ENV,
    host: parsed.HOST,
    port: parsed.PORT,
    databaseUrl: parsed.DATABASE_URL,
    jwtSecret: parsed.JWT_SECRET,
    jwtExpiresIn: parsed.JWT_EXPIRES_IN,
    corsOrigins: parsed.CORS_ORIGINS.split(",")
      .map((origin) => origin.trim())
      .filter(Boolean),
    pluggy,
    ai,
  };
}
