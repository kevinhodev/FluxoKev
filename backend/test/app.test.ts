import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { test } from "node:test";

import { buildApp } from "../src/app.js";
import {
  normalizeDescription,
  type BenefitWallet,
  type FinancialTransaction,
  type FixedExpense,
  type Subscription,
} from "../src/domain.js";
import type { Repositories } from "../src/repositories.js";
import { hashPassword } from "../src/security/password.js";

async function createFixture() {
  const userId = randomUUID();
  const institutionId = randomUUID();
  const accountId = randomUUID();
  const passwordHash = await hashPassword("uma-senha-segura-123");
  const transactions: FinancialTransaction[] = [];
  const fixedExpenses: FixedExpense[] = [];
  const subscriptions: Subscription[] = [];
  const benefitWallets: BenefitWallet[] = [];
  const repositories: Repositories = {
    health: { async ping() {} },
    users: {
      async findByEmail(email) {
        return email === "gabriel@example.com"
          ? {
              id: userId,
              name: "Gabriel",
              email,
              passwordHash,
            }
          : null;
      },
    },
    institutions: {
      async list() {
        return [];
      },
      async create(_userId, input) {
        return { id: institutionId, ...input };
      },
    },
    accounts: {
      async list() {
        return [
          {
            id: accountId,
            institutionId,
            name: "Conta corrente",
            type: "CHECKING",
            currency: "BRL",
            currentBalanceMinorUnits: 0,
            availableBalanceMinorUnits: null,
            balanceGroupKey: null,
            creditLimitMinorUnits: null,
            balanceDueDate: null,
            lastSyncAt: null,
          },
        ];
      },
      async create(_userId, input) {
        return {
          id: accountId,
          balanceGroupKey: null,
          creditLimitMinorUnits: null,
          balanceDueDate: null,
          lastSyncAt: null,
          ...input,
        };
      },
    },
    categories: {
      async list() {
        return [{ id: "food", parentId: null, name: "Alimentação", type: "EXPENSE" }];
      },
    },
    transactions: {
      async list() {
        return transactions;
      },
      async create(_userId, input) {
        const now = new Date().toISOString();
        const transaction: FinancialTransaction = {
          id: randomUUID(),
          ...input,
          normalizedDescription: normalizeDescription(input.description),
          externalId: null,
          source: "MANUAL",
          providerStatus: null,
          providerCategory: null,
          createdAt: now,
          updatedAt: now,
        };
        transactions.push(transaction);
        return transaction;
      },
      async update() {
        return null;
      },
    },
    fixedExpenses: {
      async list() {
        return fixedExpenses.filter((item) => item.active);
      },
      async create(_userId, input) {
        const now = new Date().toISOString();
        const expense: FixedExpense = {
          id: randomUUID(),
          ...input,
          active: true,
          createdAt: now,
          updatedAt: now,
        };
        fixedExpenses.push(expense);
        return expense;
      },
      async update(_userId, id, patch) {
        const expense = fixedExpenses.find((item) => item.id === id && item.active);
        if (!expense) return null;
        Object.assign(expense, patch, { updatedAt: new Date().toISOString() });
        return expense;
      },
      async archive(_userId, id) {
        const expense = fixedExpenses.find((item) => item.id === id && item.active);
        if (!expense) return false;
        expense.active = false;
        return true;
      },
    },
    subscriptions: {
      async list() {
        return subscriptions.filter((item) => item.active);
      },
      async create(_userId, input) {
        const now = new Date().toISOString();
        const subscription: Subscription = {
          id: randomUUID(),
          ...input,
          active: true,
          createdAt: now,
          updatedAt: now,
        };
        subscriptions.push(subscription);
        return subscription;
      },
      async update(_userId, id, patch) {
        const subscription = subscriptions.find(
          (item) => item.id === id && item.active,
        );
        if (!subscription) return null;
        Object.assign(subscription, patch, { updatedAt: new Date().toISOString() });
        return subscription;
      },
      async archive(_userId, id) {
        const subscription = subscriptions.find(
          (item) => item.id === id && item.active,
        );
        if (!subscription) return false;
        subscription.active = false;
        return true;
      },
    },
    benefitWallets: {
      async list() {
        return benefitWallets.filter((item) => item.active);
      },
      async create(_userId, input) {
        const now = new Date().toISOString();
        const wallet: BenefitWallet = {
          id: randomUUID(),
          ...input,
          active: true,
          createdAt: now,
          updatedAt: now,
        };
        benefitWallets.push(wallet);
        return wallet;
      },
      async update(_userId, id, patch) {
        const wallet = benefitWallets.find((item) => item.id === id && item.active);
        if (!wallet) return null;
        Object.assign(wallet, patch, { updatedAt: new Date().toISOString() });
        return wallet;
      },
      async archive(_userId, id) {
        const wallet = benefitWallets.find((item) => item.id === id && item.active);
        if (!wallet) return false;
        wallet.active = false;
        return true;
      },
    },
  };
  const app = await buildApp({
    config: {
      jwtSecret: "test-secret-with-at-least-thirty-two-characters",
      jwtExpiresIn: "15m",
      corsOrigins: [],
    },
    repositories,
  });
  return { app, accountId };
}

test("health verifica a dependência do banco", async () => {
  const { app } = await createFixture();
  const response = await app.inject({ method: "GET", url: "/health" });
  assert.equal(response.statusCode, 200);
  assert.deepEqual(response.json(), { status: "ok" });
  await app.close();
});

test("rotas financeiras exigem autenticação", async () => {
  const { app } = await createFixture();
  const response = await app.inject({ method: "GET", url: "/v1/accounts" });
  assert.equal(response.statusCode, 401);
  await app.close();
});

test("login permite cadastrar transação manual normalizada", async () => {
  const { app, accountId } = await createFixture();
  const login = await app.inject({
    method: "POST",
    url: "/v1/auth/login",
    payload: { email: "gabriel@example.com", password: "uma-senha-segura-123" },
  });
  assert.equal(login.statusCode, 200);
  const token = login.json<{ accessToken: string }>().accessToken;

  const created = await app.inject({
    method: "POST",
    url: "/v1/transactions",
    headers: { authorization: `Bearer ${token}` },
    payload: {
      accountId,
      occurredAt: "2026-08-11T12:00:00.000Z",
      description: "  Café da manhã  ",
      merchantName: "Padaria",
      amountMinorUnits: 2590,
      direction: "DEBIT",
      nature: "EXPENSE",
      categoryId: "food",
      note: null,
    },
  });

  assert.equal(created.statusCode, 201);
  assert.equal(created.json().source, "MANUAL");
  assert.equal(created.json().normalizedDescription, "CAFE DA MANHA");
  await app.close();
});

test("cadastra e lista gasto mensal variável sem inventar valor", async () => {
  const { app } = await createFixture();
  const login = await app.inject({
    method: "POST",
    url: "/v1/auth/login",
    payload: { email: "gabriel@example.com", password: "uma-senha-segura-123" },
  });
  const token = login.json<{ accessToken: string }>().accessToken;
  const created = await app.inject({
    method: "POST",
    url: "/v1/fixed-expenses",
    headers: { authorization: `Bearer ${token}` },
    payload: {
      name: "Luz RJ",
      categoryId: "housing-utilities",
      amountMinorUnits: null,
      valueKind: "VARIABLE",
      frequency: "MONTHLY",
      locationLabel: "Rio de Janeiro",
      dueDay: null,
      note: null,
    },
  });
  assert.equal(created.statusCode, 201);
  assert.equal(created.json().amountMinorUnits, null);

  const listed = await app.inject({
    method: "GET",
    url: "/v1/fixed-expenses",
    headers: { authorization: `Bearer ${token}` },
  });
  assert.equal(listed.statusCode, 200);
  assert.equal(listed.json().length, 1);
  assert.equal(listed.json()[0].valueKind, "VARIABLE");
  await app.close();
});

test("cadastra, edita e arquiva assinatura confirmada", async () => {
  const { app } = await createFixture();
  const login = await app.inject({
    method: "POST",
    url: "/v1/auth/login",
    payload: { email: "gabriel@example.com", password: "uma-senha-segura-123" },
  });
  const token = login.json<{ accessToken: string }>().accessToken;
  const created = await app.inject({
    method: "POST",
    url: "/v1/subscriptions",
    headers: { authorization: `Bearer ${token}` },
    payload: {
      name: "Disney+",
      billingDescriptor: "DL*GOOGLE Disney",
      amountMinorUnits: 6990,
      frequency: "MONTHLY",
      billingDay: 5,
      paymentMethodLabel: "OUROCARD VISA",
      note: null,
    },
  });
  assert.equal(created.statusCode, 201);
  const id = created.json().id as string;

  const updated = await app.inject({
    method: "PATCH",
    url: `/v1/subscriptions/${id}`,
    headers: { authorization: `Bearer ${token}` },
    payload: { amountMinorUnits: 7090 },
  });
  assert.equal(updated.statusCode, 200);
  assert.equal(updated.json().amountMinorUnits, 7090);

  const archived = await app.inject({
    method: "DELETE",
    url: `/v1/subscriptions/${id}`,
    headers: { authorization: `Bearer ${token}` },
  });
  assert.equal(archived.statusCode, 204);

  const listed = await app.inject({
    method: "GET",
    url: "/v1/subscriptions",
    headers: { authorization: `Bearer ${token}` },
  });
  assert.deepEqual(listed.json(), []);
  await app.close();
});

test("cadastra e atualiza carteira de benefício sem misturar com caixa", async () => {
  const { app } = await createFixture();
  const login = await app.inject({
    method: "POST",
    url: "/v1/auth/login",
    payload: { email: "gabriel@example.com", password: "uma-senha-segura-123" },
  });
  const token = login.json<{ accessToken: string }>().accessToken;
  const created = await app.inject({
    method: "POST",
    url: "/v1/benefit-wallets",
    headers: { authorization: `Bearer ${token}` },
    payload: {
      name: "Alelo",
      currentBalanceMinorUnits: 397500,
      monthlyCreditMinorUnits: 209713,
      monthlyAllocationMinorUnits: 130000,
      allocationLabel: "Ajuda para minha mãe",
      note: null,
    },
  });
  assert.equal(created.statusCode, 201);
  const id = created.json().id as string;

  const updated = await app.inject({
    method: "PATCH",
    url: `/v1/benefit-wallets/${id}`,
    headers: { authorization: `Bearer ${token}` },
    payload: { currentBalanceMinorUnits: 400000 },
  });
  assert.equal(updated.statusCode, 200);
  assert.equal(updated.json().currentBalanceMinorUnits, 400000);

  const listed = await app.inject({
    method: "GET",
    url: "/v1/benefit-wallets",
    headers: { authorization: `Bearer ${token}` },
  });
  assert.equal(listed.json().length, 1);
  await app.close();
});
