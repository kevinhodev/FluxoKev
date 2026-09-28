import cors from "@fastify/cors";
import helmet from "@fastify/helmet";
import jwt from "@fastify/jwt";
import rateLimit from "@fastify/rate-limit";
import Fastify, {
  type FastifyInstance,
  type FastifyReply,
  type FastifyRequest,
} from "fastify";
import { z, ZodError } from "zod";

import type { AppConfig } from "./config.js";
import type {
  Account,
  BenefitWalletPatch,
  Category,
  CreateBenefitWallet,
  CreateFixedExpense,
  CreateSubscription,
  CreateTransaction,
  FixedExpensePatch,
  Institution,
  SubscriptionPatch,
  TransactionPatch,
} from "./domain.js";
import type { Repositories, TransactionFilters } from "./repositories.js";
import { verifyPassword } from "./security/password.js";
import type { PluggySyncService } from "./integrations/pluggy/sync-service.js";
import type { CommitmentsService } from "./insights/commitments-service.js";
import type { FinancialDocumentService } from "./imports/pdf-document-service.js";
import type { AiInsightsService } from "./insights/ai-insights-service.js";
import type { MerchantAliasService } from "./insights/merchant-aliases.js";

declare module "fastify" {
  interface FastifyInstance {
    authenticate(request: FastifyRequest, reply: FastifyReply): Promise<void>;
  }
}

declare module "@fastify/jwt" {
  interface FastifyJWT {
    payload: { sub: string; email: string };
    user: { sub: string; email: string };
  }
}

type BuildAppOptions = {
  config: Pick<AppConfig, "jwtSecret" | "jwtExpiresIn" | "corsOrigins">;
  repositories: Repositories;
  pluggySync?: PluggySyncService;
  commitments?: CommitmentsService;
  financialDocuments?: FinancialDocumentService;
  aiInsights?: AiInsightsService;
  merchantAliases?: MerchantAliasService;
  logger?: boolean;
};

class ApiError extends Error {
  constructor(
    readonly statusCode: number,
    readonly code: string,
    message: string,
  ) {
    super(message);
  }
}

const emailSchema = z.string().trim().toLowerCase().email();
const idSchema = z.string().uuid();
const dateTimeSchema = z.string().refine(
  (value) => !Number.isNaN(Date.parse(value)),
  "Data e hora inválidas.",
);
const moneySchema = z.number().int().positive().max(Number.MAX_SAFE_INTEGER);

const loginSchema = z.object({
  email: emailSchema,
  password: z.string().min(1).max(200),
});

const institutionSchema = z.object({
  name: z.string().trim().min(2).max(120),
  type: z.enum(["BANK", "PENSION", "OTHER"]),
  externalId: z.string().trim().max(200).nullable().default(null),
});

const accountSchema = z.object({
  institutionId: idSchema,
  name: z.string().trim().min(2).max(120),
  type: z.enum(["CHECKING", "SAVINGS", "PAYMENT", "CREDIT_CARD", "OTHER"]),
  currency: z.string().trim().toUpperCase().length(3).default("BRL"),
  currentBalanceMinorUnits: z.number().int().safe(),
  availableBalanceMinorUnits: z.number().int().safe().nullable().default(null),
});

const transactionFields = {
  accountId: idSchema,
  occurredAt: dateTimeSchema,
  description: z.string().trim().min(1).max(300),
  merchantName: z.string().trim().min(1).max(200),
  amountMinorUnits: moneySchema,
  direction: z.enum(["CREDIT", "DEBIT"]),
  nature: z.enum(["INCOME", "EXPENSE", "TRANSFER", "INVESTMENT_RETURN"]),
  categoryId: z.string().trim().min(1).max(100),
  note: z.string().trim().max(1_000).nullable().default(null),
} as const;
const createTransactionSchema = z.object(transactionFields);
const updateTransactionSchema = z
  .object({
    occurredAt: transactionFields.occurredAt.optional(),
    description: transactionFields.description.optional(),
    merchantName: transactionFields.merchantName.optional(),
    amountMinorUnits: transactionFields.amountMinorUnits.optional(),
    direction: transactionFields.direction.optional(),
    nature: transactionFields.nature.optional(),
    categoryId: transactionFields.categoryId.optional(),
    note: z.string().trim().max(1_000).nullable().optional(),
  })
  .refine((value) => Object.keys(value).length > 0, "Informe ao menos uma alteração.");

const transactionQuerySchema = z.object({
  from: dateTimeSchema.optional(),
  to: dateTimeSchema.optional(),
  search: z.string().trim().max(200).optional(),
});

const pdfImportSchema = z.object({
  kind: z.enum(["LOAN", "PENSION"]),
  fileName: z.string().trim().min(1).max(180),
  contentBase64: z.string().min(8).max(11_200_000),
});

const pensionProjectionQuerySchema = z.object({
  years: z.coerce.number().int().min(1).max(30).default(10),
});

const pensionReturnSchema = z.object({
  referenceMonth: z.string().regex(/^\d{4}-\d{2}(?:-01)?$/),
  returnRate: z.number().min(-100).max(1000),
});

const merchantAliasSchema = z.object({
  // Prefixo curto demais pegaria meio extrato sem querer.
  pattern: z.string().trim().min(3).max(120),
  merchantName: z.string().trim().min(2).max(80),
  // Nulo = a regra só renomeia, sem mexer na categoria.
  categoryId: z.string().trim().min(1).max(100).nullable().default(null),
});

const aiAskSchema = z.object({
  question: z.string().trim().min(3).max(2000),
  history: z
    .array(
      z.object({
        role: z.enum(["user", "assistant"]),
        content: z.string().trim().min(1).max(8000),
      }),
    )
    .max(20)
    .default([]),
});

const loanSettlementSchema = z.object({
  front: z.number().int().min(0).max(600).default(0),
  back: z.number().int().min(0).max(600).default(0),
});

const pensionSnapshotSchema = z
  .object({
    referenceMonth: z.string().regex(/^\d{4}-\d{2}-01$/),
    asOfDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
    accumulatedReturnMinorUnits: z.number().int().safe(),
    contributionApplied: z.boolean().default(false),
  })
  .refine(
    (value) => value.asOfDate.slice(0, 7) === value.referenceMonth.slice(0, 7),
    "A posição deve pertencer ao mês de referência.",
  );

const fixedExpenseFields = {
  name: z.string().trim().min(2).max(120),
  categoryId: z.string().trim().min(1).max(100),
  amountMinorUnits: z.number().int().positive().safe().nullable(),
  valueKind: z.enum(["FIXED", "VARIABLE"]),
  frequency: z.literal("MONTHLY").default("MONTHLY"),
  locationLabel: z.string().trim().max(120).default(""),
  dueDay: z.number().int().min(1).max(31).nullable().default(null),
  note: z.string().trim().max(500).nullable().default(null),
} as const;
const fixedExpenseSchema = z.object(fixedExpenseFields).refine(
  (value) => value.valueKind === "VARIABLE" || value.amountMinorUnits !== null,
  { message: "Informe o valor do gasto fixo.", path: ["amountMinorUnits"] },
);
const fixedExpensePatchSchema = z
  .object({
    name: fixedExpenseFields.name.optional(),
    categoryId: fixedExpenseFields.categoryId.optional(),
    amountMinorUnits: fixedExpenseFields.amountMinorUnits.optional(),
    valueKind: fixedExpenseFields.valueKind.optional(),
    locationLabel: fixedExpenseFields.locationLabel.optional(),
    dueDay: fixedExpenseFields.dueDay.optional(),
    note: fixedExpenseFields.note.optional(),
  })
  .refine((value) => Object.keys(value).length > 0, "Informe ao menos uma alteração.")
  .refine(
    (value) => !(value.valueKind === "FIXED" && value.amountMinorUnits === null),
    { message: "Informe o valor do gasto fixo.", path: ["amountMinorUnits"] },
  );

const subscriptionFields = {
  name: z.string().trim().min(2).max(120),
  billingDescriptor: z.string().trim().max(180).default(""),
  amountMinorUnits: z.number().int().positive().safe(),
  frequency: z.literal("MONTHLY").default("MONTHLY"),
  billingDay: z.number().int().min(1).max(31).nullable().default(null),
  paymentMethodLabel: z.string().trim().max(120).default(""),
  note: z.string().trim().max(500).nullable().default(null),
} as const;
const subscriptionSchema = z.object(subscriptionFields);
const subscriptionPatchSchema = z
  .object({
    name: subscriptionFields.name.optional(),
    billingDescriptor: subscriptionFields.billingDescriptor.optional(),
    amountMinorUnits: subscriptionFields.amountMinorUnits.optional(),
    billingDay: subscriptionFields.billingDay.optional(),
    paymentMethodLabel: subscriptionFields.paymentMethodLabel.optional(),
    note: subscriptionFields.note.optional(),
  })
  .refine((value) => Object.keys(value).length > 0, "Informe ao menos uma alteração.");

const benefitWalletFields = {
  name: z.string().trim().min(2).max(120),
  currentBalanceMinorUnits: z.number().int().min(0).safe(),
  monthlyCreditMinorUnits: z.number().int().min(0).safe(),
  monthlyAllocationMinorUnits: z.number().int().min(0).safe(),
  allocationLabel: z.string().trim().max(160).default(""),
  note: z.string().trim().max(500).nullable().default(null),
} as const;
const benefitWalletSchema = z.object(benefitWalletFields);
const benefitWalletPatchSchema = z
  .object({
    name: benefitWalletFields.name.optional(),
    currentBalanceMinorUnits: benefitWalletFields.currentBalanceMinorUnits.optional(),
    monthlyCreditMinorUnits: benefitWalletFields.monthlyCreditMinorUnits.optional(),
    monthlyAllocationMinorUnits:
      benefitWalletFields.monthlyAllocationMinorUnits.optional(),
    allocationLabel: benefitWalletFields.allocationLabel.optional(),
    note: benefitWalletFields.note.optional(),
  })
  .refine((value) => Object.keys(value).length > 0, "Informe ao menos uma alteração.");

export async function buildApp(options: BuildAppOptions): Promise<FastifyInstance> {
  const app = Fastify({ logger: options.logger ?? false, trustProxy: false });
  await app.register(helmet);
  await app.register(cors, {
    origin: options.config.corsOrigins.length ? options.config.corsOrigins : false,
    credentials: false,
  });
  await app.register(rateLimit, { max: 100, timeWindow: "1 minute" });
  await app.register(jwt, { secret: options.config.jwtSecret });

  app.decorate("authenticate", async (request) => {
    try {
      await request.jwtVerify();
    } catch {
      throw new ApiError(401, "UNAUTHORIZED", "Autenticação necessária.");
    }
  });

  app.setErrorHandler((error, _request, reply) => {
    if (error instanceof ApiError) {
      return reply.status(error.statusCode).send({
        error: { code: error.code, message: error.message },
      });
    }
    if (error instanceof ZodError) {
      return reply.status(400).send({
        error: {
          code: "VALIDATION_ERROR",
          message: "Dados inválidos.",
          details: error.issues,
        },
      });
    }
    if (error instanceof ReferenceError) {
      return reply.status(400).send({
        error: { code: "INVALID_REFERENCE", message: error.message },
      });
    }
    if (
      typeof error === "object" &&
      error !== null &&
      "statusCode" in error &&
      typeof error.statusCode === "number" &&
      error.statusCode >= 400 &&
      error.statusCode < 500
    ) {
      return reply.status(error.statusCode).send({
        error: { code: "REQUEST_ERROR", message: "Requisição inválida." },
      });
    }
    app.log.error(error);
    return reply.status(500).send({
      error: { code: "INTERNAL_ERROR", message: "Erro interno do servidor." },
    });
  });

  app.get("/health", async (_request, reply) => {
    await options.repositories.health.ping();
    return reply.send({ status: "ok" });
  });

  app.post(
    "/v1/auth/login",
    { config: { rateLimit: { max: 5, timeWindow: "1 minute" } } },
    async (request, reply) => {
      const input = loginSchema.parse(request.body);
      const user = await options.repositories.users.findByEmail(input.email);
      if (!user || !(await verifyPassword(input.password, user.passwordHash))) {
        throw new ApiError(401, "INVALID_CREDENTIALS", "E-mail ou senha inválidos.");
      }
      const accessToken = app.jwt.sign(
        { sub: user.id, email: user.email },
        { expiresIn: options.config.jwtExpiresIn },
      );
      return reply.send({
        accessToken,
        tokenType: "Bearer",
        expiresIn: options.config.jwtExpiresIn,
        user: { id: user.id, name: user.name, email: user.email },
      });
    },
  );

  app.get(
    "/v1/institutions",
    { preHandler: app.authenticate },
    async (request) => options.repositories.institutions.list(request.user.sub),
  );
  app.post(
    "/v1/institutions",
    { preHandler: app.authenticate },
    async (request, reply) => {
      const input = institutionSchema.parse(request.body);
      const institution = await options.repositories.institutions.create(
        request.user.sub,
        input satisfies Omit<Institution, "id">,
      );
      return reply.status(201).send(institution);
    },
  );

  app.get(
    "/v1/accounts",
    { preHandler: app.authenticate },
    async (request) => options.repositories.accounts.list(request.user.sub),
  );
  app.post(
    "/v1/accounts",
    { preHandler: app.authenticate },
    async (request, reply) => {
      const input = accountSchema.parse(request.body);
      const account = await options.repositories.accounts.create(
        request.user.sub,
        input satisfies Omit<
          Account,
          | "id"
          | "lastSyncAt"
          | "balanceGroupKey"
          | "creditLimitMinorUnits"
          | "balanceDueDate"
        >,
      );
      return reply.status(201).send(account);
    },
  );

  app.get(
    "/v1/categories",
    { preHandler: app.authenticate },
    async () => options.repositories.categories.list() satisfies Promise<Category[]>,
  );

  app.get(
    "/v1/commitments",
    { preHandler: app.authenticate },
    async (request) => {
      if (!options.commitments) {
        throw new ApiError(503, "COMMITMENTS_NOT_CONFIGURED", "Análise indisponível.");
      }
      return options.commitments.getSummary(request.user.sub);
    },
  );

  app.get(
    "/v1/fixed-expenses",
    { preHandler: app.authenticate },
    async (request) => options.repositories.fixedExpenses.list(request.user.sub),
  );
  app.post(
    "/v1/fixed-expenses",
    { preHandler: app.authenticate },
    async (request, reply) => {
      const input = fixedExpenseSchema.parse(request.body);
      const created = await options.repositories.fixedExpenses.create(
        request.user.sub,
        input satisfies CreateFixedExpense,
      );
      return reply.status(201).send(created);
    },
  );
  app.patch(
    "/v1/fixed-expenses/:id",
    { preHandler: app.authenticate },
    async (request, reply) => {
      const { id } = z.object({ id: idSchema }).parse(request.params);
      const parsedPatch = fixedExpensePatchSchema.parse(request.body);
      const patch = Object.fromEntries(
        Object.entries(parsedPatch).filter(([, value]) => value !== undefined),
      ) as FixedExpensePatch;
      const updated = await options.repositories.fixedExpenses.update(
        request.user.sub,
        id,
        patch,
      );
      if (!updated) {
        throw new ApiError(404, "NOT_FOUND", "Gasto fixo não encontrado.");
      }
      return reply.send(updated);
    },
  );
  app.delete(
    "/v1/fixed-expenses/:id",
    { preHandler: app.authenticate },
    async (request, reply) => {
      const { id } = z.object({ id: idSchema }).parse(request.params);
      const archived = await options.repositories.fixedExpenses.archive(
        request.user.sub,
        id,
      );
      if (!archived) {
        throw new ApiError(404, "NOT_FOUND", "Gasto fixo não encontrado.");
      }
      return reply.status(204).send();
    },
  );

  app.get(
    "/v1/subscriptions",
    { preHandler: app.authenticate },
    async (request) => options.repositories.subscriptions.list(request.user.sub),
  );
  app.post(
    "/v1/subscriptions",
    { preHandler: app.authenticate },
    async (request, reply) => {
      const input = subscriptionSchema.parse(request.body);
      const created = await options.repositories.subscriptions.create(
        request.user.sub,
        input satisfies CreateSubscription,
      );
      return reply.status(201).send(created);
    },
  );
  app.patch(
    "/v1/subscriptions/:id",
    { preHandler: app.authenticate },
    async (request, reply) => {
      const { id } = z.object({ id: idSchema }).parse(request.params);
      const parsedPatch = subscriptionPatchSchema.parse(request.body);
      const patch = Object.fromEntries(
        Object.entries(parsedPatch).filter(([, value]) => value !== undefined),
      ) as SubscriptionPatch;
      const updated = await options.repositories.subscriptions.update(
        request.user.sub,
        id,
        patch,
      );
      if (!updated) {
        throw new ApiError(404, "NOT_FOUND", "Assinatura não encontrada.");
      }
      return reply.send(updated);
    },
  );
  app.delete(
    "/v1/subscriptions/:id",
    { preHandler: app.authenticate },
    async (request, reply) => {
      const { id } = z.object({ id: idSchema }).parse(request.params);
      const archived = await options.repositories.subscriptions.archive(
        request.user.sub,
        id,
      );
      if (!archived) {
        throw new ApiError(404, "NOT_FOUND", "Assinatura não encontrada.");
      }
      return reply.status(204).send();
    },
  );

  app.get(
    "/v1/benefit-wallets",
    { preHandler: app.authenticate },
    async (request) => options.repositories.benefitWallets.list(request.user.sub),
  );
  app.post(
    "/v1/benefit-wallets",
    { preHandler: app.authenticate },
    async (request, reply) => {
      const input = benefitWalletSchema.parse(request.body);
      const created = await options.repositories.benefitWallets.create(
        request.user.sub,
        input satisfies CreateBenefitWallet,
      );
      return reply.status(201).send(created);
    },
  );
  app.patch(
    "/v1/benefit-wallets/:id",
    { preHandler: app.authenticate },
    async (request, reply) => {
      const { id } = z.object({ id: idSchema }).parse(request.params);
      const parsedPatch = benefitWalletPatchSchema.parse(request.body);
      const patch = Object.fromEntries(
        Object.entries(parsedPatch).filter(([, value]) => value !== undefined),
      ) as BenefitWalletPatch;
      const updated = await options.repositories.benefitWallets.update(
        request.user.sub,
        id,
        patch,
      );
      if (!updated) {
        throw new ApiError(404, "NOT_FOUND", "Benefício não encontrado.");
      }
      return reply.send(updated);
    },
  );
  app.delete(
    "/v1/benefit-wallets/:id",
    { preHandler: app.authenticate },
    async (request, reply) => {
      const { id } = z.object({ id: idSchema }).parse(request.params);
      const archived = await options.repositories.benefitWallets.archive(
        request.user.sub,
        id,
      );
      if (!archived) {
        throw new ApiError(404, "NOT_FOUND", "Benefício não encontrado.");
      }
      return reply.status(204).send();
    },
  );

  app.post(
    "/v1/imports/pdf/preview",
    {
      preHandler: app.authenticate,
      bodyLimit: 12 * 1024 * 1024,
      config: { rateLimit: { max: 10, timeWindow: "1 minute" } },
    },
    async (request) => {
      if (!options.financialDocuments) {
        throw new ApiError(503, "PDF_IMPORT_NOT_CONFIGURED", "Importação indisponível.");
      }
      const input = pdfImportSchema.parse(request.body);
      try {
        return await options.financialDocuments.preview(input);
      } catch (error) {
        throw new ApiError(
          422,
          "PDF_NOT_RECOGNIZED",
          error instanceof Error ? error.message : "Não foi possível interpretar o PDF.",
        );
      }
    },
  );

  app.post(
    "/v1/imports/pdf",
    {
      preHandler: app.authenticate,
      bodyLimit: 12 * 1024 * 1024,
      config: { rateLimit: { max: 15, timeWindow: "1 minute" } },
    },
    async (request, reply) => {
      if (!options.financialDocuments) {
        throw new ApiError(503, "PDF_IMPORT_NOT_CONFIGURED", "Importação indisponível.");
      }
      const input = pdfImportSchema.parse(request.body);
      try {
        const imported = await options.financialDocuments.import(request.user.sub, input);
        return reply.status(201).send(imported);
      } catch (error) {
        throw new ApiError(
          422,
          "PDF_NOT_RECOGNIZED",
          error instanceof Error ? error.message : "Não foi possível importar o PDF.",
        );
      }
    },
  );

  app.get(
    "/v1/loans",
    { preHandler: app.authenticate },
    async (request) => options.financialDocuments?.listLoans(request.user.sub) ?? [],
  );

  app.put(
    "/v1/loans/:loanId/settlements",
    { preHandler: app.authenticate },
    async (request, reply) => {
      if (!options.financialDocuments) {
        throw new ApiError(503, "PDF_IMPORT_NOT_CONFIGURED", "Empréstimos indisponíveis.");
      }
      const { loanId } = z.object({ loanId: idSchema }).parse(request.params);
      const input = loanSettlementSchema.parse(request.body);
      let loan;
      try {
        loan = await options.financialDocuments.setLoanEarlySettlement(
          request.user.sub,
          loanId,
          input,
        );
      } catch (error) {
        throw new ApiError(
          422,
          "SETTLEMENT_OUT_OF_RANGE",
          error instanceof Error ? error.message : "Quitação inválida.",
        );
      }
      if (!loan) {
        throw new ApiError(404, "LOAN_NOT_FOUND", "Empréstimo não encontrado.");
      }
      return reply.send(loan);
    },
  );

  app.get(
    "/v1/payroll/summary",
    { preHandler: app.authenticate },
    async (request) =>
      options.financialDocuments?.getPayrollSummary(request.user.sub) ?? null,
  );

  app.get(
    "/v1/pensions",
    { preHandler: app.authenticate },
    async (request) => options.financialDocuments?.listPensions(request.user.sub) ?? [],
  );

  app.get(
    "/v1/pensions/:pensionId/projection",
    { preHandler: app.authenticate },
    async (request) => {
      if (!options.financialDocuments) {
        throw new ApiError(503, "PDF_IMPORT_NOT_CONFIGURED", "Projeção indisponível.");
      }
      const { pensionId } = z.object({ pensionId: idSchema }).parse(request.params);
      const { years } = pensionProjectionQuerySchema.parse(request.query);
      const projection = await options.financialDocuments.getPensionProjection(
        request.user.sub,
        pensionId,
        years,
      );
      if (!projection) {
        throw new ApiError(404, "PENSION_NOT_FOUND", "Posição PREVI não encontrada.");
      }
      return projection;
    },
  );

  app.put(
    "/v1/pensions/:pensionId/monthly-return",
    { preHandler: app.authenticate },
    async (request) => {
      if (!options.financialDocuments) {
        throw new ApiError(503, "PDF_IMPORT_NOT_CONFIGURED", "Projeção indisponível.");
      }
      const { pensionId } = z.object({ pensionId: idSchema }).parse(request.params);
      const input = pensionReturnSchema.parse(request.body);
      const projection = await options.financialDocuments.savePensionReturn(
        request.user.sub,
        pensionId,
        input.referenceMonth,
        input.returnRate,
      );
      if (!projection) {
        throw new ApiError(404, "PENSION_NOT_FOUND", "Posição PREVI não encontrada.");
      }
      return projection;
    },
  );

  app.put(
    "/v1/pensions/:pensionId/monthly-snapshot",
    { preHandler: app.authenticate },
    async (request) => {
      if (!options.financialDocuments) {
        throw new ApiError(503, "PDF_IMPORT_NOT_CONFIGURED", "Projeção indisponível.");
      }
      const { pensionId } = z.object({ pensionId: idSchema }).parse(request.params);
      const input = pensionSnapshotSchema.parse(request.body);
      const projection = await options.financialDocuments.savePensionSnapshot(
        request.user.sub,
        pensionId,
        input,
      );
      if (!projection) {
        throw new ApiError(404, "PENSION_NOT_FOUND", "Posição PREVI não encontrada.");
      }
      return projection;
    },
  );

  app.get(
    "/v1/merchant-aliases",
    { preHandler: app.authenticate },
    async (request) => options.merchantAliases?.list(request.user.sub) ?? [],
  );

  app.get(
    "/v1/merchant-aliases/preview",
    { preHandler: app.authenticate },
    async (request) => {
      if (!options.merchantAliases) {
        throw new ApiError(503, "ALIASES_NOT_CONFIGURED", "Indisponível.");
      }
      const { pattern } = z
        .object({ pattern: z.string().trim().min(3).max(120) })
        .parse(request.query);
      return options.merchantAliases.preview(request.user.sub, pattern);
    },
  );

  app.post(
    "/v1/merchant-aliases",
    { preHandler: app.authenticate },
    async (request, reply) => {
      if (!options.merchantAliases) {
        throw new ApiError(503, "ALIASES_NOT_CONFIGURED", "Indisponível.");
      }
      const input = merchantAliasSchema.parse(request.body);
      const alias = await options.merchantAliases.create(request.user.sub, input);
      return reply.status(201).send(alias);
    },
  );

  app.put(
    "/v1/merchant-aliases/:id",
    { preHandler: app.authenticate },
    async (request, reply) => {
      if (!options.merchantAliases) {
        throw new ApiError(503, "ALIASES_NOT_CONFIGURED", "Indisponível.");
      }
      const { id } = z.object({ id: idSchema }).parse(request.params);
      const input = merchantAliasSchema.parse(request.body);
      let alias;
      try {
        alias = await options.merchantAliases.update(request.user.sub, id, input);
      } catch (error) {
        throw new ApiError(
          409,
          "ALIAS_PATTERN_TAKEN",
          error instanceof Error ? error.message : "Prefixo já usado.",
        );
      }
      if (!alias) {
        throw new ApiError(404, "ALIAS_NOT_FOUND", "Regra não encontrada.");
      }
      return reply.send(alias);
    },
  );

  app.delete(
    "/v1/merchant-aliases/:id",
    { preHandler: app.authenticate },
    async (request, reply) => {
      if (!options.merchantAliases) {
        throw new ApiError(503, "ALIASES_NOT_CONFIGURED", "Indisponível.");
      }
      const { id } = z.object({ id: idSchema }).parse(request.params);
      const removed = await options.merchantAliases.remove(request.user.sub, id);
      if (!removed) {
        throw new ApiError(404, "ALIAS_NOT_FOUND", "Apelido não encontrado.");
      }
      return reply.status(204).send();
    },
  );

  app.post(
    "/v1/insights/ask",
    {
      preHandler: app.authenticate,
      // Cada pergunta custa dinheiro de verdade: o limite protege a conta,
      // não só o servidor.
      config: { rateLimit: { max: 20, timeWindow: "1 hour" } },
    },
    async (request, reply) => {
      if (!options.aiInsights) {
        throw new ApiError(
          503,
          "AI_NOT_CONFIGURED",
          "Análise por IA indisponível: defina ANTHROPIC_API_KEY.",
        );
      }
      const input = aiAskSchema.parse(request.body);
      try {
        return reply.send(await options.aiInsights.ask(request.user.sub, input));
      } catch (error) {
        request.log.error({ err: error }, "Falha ao consultar a IA");
        throw new ApiError(
          502,
          "AI_REQUEST_FAILED",
          error instanceof Error ? error.message : "A IA não respondeu.",
        );
      }
    },
  );

  app.get(
    "/v1/portfolio/positions",
    { preHandler: app.authenticate },
    async (request) =>
      options.financialDocuments?.getPortfolio(request.user.sub) ?? {
        assets: [],
        liabilities: [],
      },
  );

  app.get(
    "/v1/transactions",
    { preHandler: app.authenticate },
    async (request) => {
      const filters = transactionQuerySchema.parse(request.query);
      return options.repositories.transactions.list(
        request.user.sub,
        filters satisfies TransactionFilters,
      );
    },
  );
  app.post(
    "/v1/transactions",
    { preHandler: app.authenticate },
    async (request, reply) => {
      const input = createTransactionSchema.parse(request.body);
      const transaction = await options.repositories.transactions.create(
        request.user.sub,
        input satisfies CreateTransaction,
      );
      return reply.status(201).send(transaction);
    },
  );
  app.patch(
    "/v1/transactions/:id",
    { preHandler: app.authenticate },
    async (request, reply) => {
      const { id } = z.object({ id: idSchema }).parse(request.params);
      const patch = updateTransactionSchema.parse(request.body);
      const transaction = await options.repositories.transactions.update(
        request.user.sub,
        id,
        patch satisfies TransactionPatch,
      );
      if (!transaction) {
        throw new ApiError(404, "NOT_FOUND", "Transação não encontrada.");
      }
      return reply.send(transaction);
    },
  );

  app.get(
    "/v1/integrations/pluggy/status",
    { preHandler: app.authenticate },
    async (request) => {
      if (!options.pluggySync) {
        return { configured: false, provider: "PLUGGY" as const };
      }
      const status = await options.pluggySync.getStatus(request.user.sub);
      return (
        status ?? {
          configured: true,
          provider: "PLUGGY" as const,
          status: "NOT_SYNCED",
        }
      );
    },
  );

  app.post(
    "/v1/integrations/pluggy/sync",
    {
      preHandler: app.authenticate,
      config: { rateLimit: { max: 5, timeWindow: "1 minute" } },
    },
    async (request, reply) => {
      if (!options.pluggySync) {
        throw new ApiError(
          503,
          "PLUGGY_NOT_CONFIGURED",
          "Integração Pluggy não configurada.",
        );
      }
      return reply.send(await options.pluggySync.sync(request.user.sub));
    },
  );

  return app;
}
