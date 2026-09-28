import assert from "node:assert/strict";
import { test } from "node:test";

import { PluggyClient } from "../src/integrations/pluggy/client.js";

test("autentica uma vez e percorre a paginação por cursor", async () => {
  const urls: string[] = [];
  const fakeFetch: typeof fetch = async (input, init) => {
    const url = String(input);
    urls.push(url);
    if (url.endsWith("/auth")) {
      assert.equal(init?.method, "POST");
      return Response.json({ apiKey: "temporary-key" });
    }
    assert.equal(new Headers(init?.headers).get("x-api-key"), "temporary-key");
    if (url.includes("after=next-cursor")) {
      return Response.json({
        results: [
          {
            id: "transaction-2",
            accountId: "account",
            description: "Salário",
            currencyCode: "BRL",
            amount: 100,
            date: "2026-08-02T00:00:00.000Z",
            status: "POSTED",
          },
        ],
        next: null,
      });
    }
    return Response.json({
      results: [
        {
          id: "transaction-1",
          accountId: "account",
          description: "Compra",
          currencyCode: "BRL",
          amount: -10,
          date: "2026-08-01T00:00:00.000Z",
          status: "POSTED",
        },
      ],
      next: "?accountId=account&after=next-cursor",
    });
  };
  const client = new PluggyClient({
    clientId: "00000000-0000-4000-8000-000000000000",
    clientSecret: "secret",
    baseUrl: "https://pluggy.test",
    fetchImplementation: fakeFetch,
  });

  const transactions = await client.listTransactions("account");

  assert.equal(transactions.length, 2);
  assert.equal(urls.filter((url) => url.endsWith("/auth")).length, 1);
  assert.equal(
    urls[2],
    "https://pluggy.test/v2/transactions?accountId=account&after=next-cursor",
  );
});
