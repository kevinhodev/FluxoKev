import assert from "node:assert/strict";
import { test } from "node:test";

import type {
  PluggyAccount,
  PluggyTransaction,
} from "../src/integrations/pluggy/client.js";
import {
  creditBalanceGroupKey,
  mapAccountBalanceMinorUnits,
  mapAccountType,
  mapPluggyTransaction,
} from "../src/integrations/pluggy/mapping.js";

const bankAccount: PluggyAccount = {
  id: "account-bank",
  itemId: "item",
  type: "BANK",
  subtype: "CHECKING_ACCOUNT",
  name: "Conta corrente",
  balance: 165.13,
  currencyCode: "BRL",
};

const creditCard: PluggyAccount = {
  id: "account-card",
  itemId: "item",
  type: "CREDIT",
  subtype: "CREDIT_CARD",
  name: "Ourocard",
  balance: 15955,
  currencyCode: "BRL",
};

function transaction(input: Partial<PluggyTransaction>): PluggyTransaction {
  return {
    id: "transaction",
    accountId: bankAccount.id,
    description: "Compra",
    currencyCode: "BRL",
    amount: -10,
    date: "2026-08-14T12:00:00.000Z",
    status: "POSTED",
    ...input,
  };
}

test("mapeia conta corrente e dívida do cartão em centavos", () => {
  assert.equal(mapAccountType(bankAccount), "CHECKING");
  assert.equal(mapAccountBalanceMinorUnits(bankAccount), 16_513);
  assert.equal(mapAccountType(creditCard), "CREDIT_CARD");
  assert.equal(mapAccountBalanceMinorUnits(creditCard), -1_595_500);
});

test("prioriza o tipo informado pela Pluggy", () => {
  const result = mapPluggyTransaction(
    bankAccount,
    transaction({ amount: 7800, type: "CREDIT", category: "Salary" }),
  );
  assert.deepEqual(result, {
    amountMinorUnits: 780_000,
    direction: "CREDIT",
    nature: "INCOME",
    categoryId: "salary",
  });
});

test("aplica a convenção de sinal específica do cartão sem type", () => {
  const expense = mapPluggyTransaction(
    creditCard,
    transaction({
      accountId: creditCard.id,
      amount: 55.9,
      category: "Video streaming",
    }),
  );
  const payment = mapPluggyTransaction(
    creditCard,
    transaction({
      accountId: creditCard.id,
      amount: -500,
      category: "Credit card payment",
    }),
  );
  assert.equal(expense.direction, "DEBIT");
  assert.equal(expense.categoryId, "subscriptions-streaming");
  assert.equal(payment.direction, "CREDIT");
  assert.equal(payment.nature, "TRANSFER");
});

test("agrupa cartões que repetem a mesma linha de crédito", () => {
  const creditData = {
    creditLimit: 31000,
    availableCreditLimit: 15045,
    disaggregatedCreditLimits: [
      {
        creditLineLimitType: "LIMITE_CREDITO_TOTAL",
        usedAmount: 15955,
        availableAmount: 15045,
        limitAmount: 31000,
      },
    ],
  };
  const first = creditBalanceGroupKey({ ...creditCard, creditData });
  const second = creditBalanceGroupKey({
    ...creditCard,
    id: "another-card",
    number: "1112",
    creditData,
  });
  assert.ok(first);
  assert.equal(first, second);
});

test("normaliza categorias reais retornadas pela Pluggy", () => {
  assert.equal(
    mapPluggyTransaction(
      bankAccount,
      transaction({ type: "DEBIT", category: "Groceries" }),
    ).categoryId,
    "food-supermarket",
  );
  const proceeds = mapPluggyTransaction(
    bankAccount,
    transaction({
      type: "CREDIT",
      amount: 63.45,
      category: "Proceeds interests and dividends",
    }),
  );
  assert.equal(proceeds.categoryId, "investments-return");
  assert.equal(proceeds.nature, "INVESTMENT_RETURN");
});
