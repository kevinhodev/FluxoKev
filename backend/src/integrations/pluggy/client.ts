export type PluggyItem = {
  id: string;
  status: string;
  executionStatus: string | null;
  lastUpdatedAt: string | null;
  connector?: { id: number; name: string } | null;
};

export type PluggyAccount = {
  id: string;
  itemId: string;
  type: "BANK" | "CREDIT";
  subtype: string;
  name: string;
  marketingName?: string | null;
  number?: string | null;
  balance: number;
  currencyCode: string;
  bankData?: { closingBalance?: number | null } | null;
  creditData?: {
    availableCreditLimit?: number | null;
    creditLimit?: number | null;
    balanceDueDate?: string | null;
    balanceCloseDate?: string | null;
    minimumPayment?: number | null;
    brand?: string | null;
    level?: string | null;
    status?: string | null;
    additionalCards?: Array<Record<string, unknown>> | null;
    disaggregatedCreditLimits?: Array<Record<string, unknown>> | null;
  } | null;
};

export type PluggyTransaction = {
  id: string;
  accountId: string;
  description: string;
  descriptionRaw?: string | null;
  currencyCode: string;
  amount: number;
  date: string;
  category?: string | null;
  categoryId?: string | null;
  type?: "DEBIT" | "CREDIT" | null;
  status: "PENDING" | "POSTED";
  providerCode?: string | null;
  merchant?: { name?: string | null } | null;
  creditCardMetadata?: Record<string, unknown> | null;
};

type AuthResponse = { apiKey: string };
type ResultsResponse<T> = { results: T[]; next?: string | null };

export type PluggyClientOptions = {
  clientId: string;
  clientSecret: string;
  baseUrl?: string;
  fetchImplementation?: typeof fetch;
};

export class PluggyClient {
  private readonly baseUrl: string;
  private readonly fetchImplementation: typeof fetch;
  private apiKey: { value: string; expiresAt: number } | null = null;

  constructor(private readonly options: PluggyClientOptions) {
    this.baseUrl = options.baseUrl ?? "https://api.pluggy.ai";
    this.fetchImplementation = options.fetchImplementation ?? fetch;
  }

  async getItem(itemId: string): Promise<PluggyItem> {
    return this.request<PluggyItem>(`/items/${encodeURIComponent(itemId)}`);
  }

  async listAccounts(itemId: string): Promise<PluggyAccount[]> {
    const response = await this.request<ResultsResponse<PluggyAccount> | PluggyAccount[]>(
      `/accounts?itemId=${encodeURIComponent(itemId)}`,
    );
    return Array.isArray(response) ? response : response.results;
  }

  async listTransactions(accountId: string): Promise<PluggyTransaction[]> {
    const transactions: PluggyTransaction[] = [];
    let path: string | null =
      `/v2/transactions?accountId=${encodeURIComponent(accountId)}`;
    let pages = 0;
    while (path) {
      if (++pages > 100) throw new Error("Paginação da Pluggy excedeu o limite seguro.");
      const response: ResultsResponse<PluggyTransaction> =
        await this.request<ResultsResponse<PluggyTransaction>>(path);
      transactions.push(...response.results);
      const next = response.next ?? null;
      path = next?.startsWith("?") ? `/v2/transactions${next}` : next;
    }
    return transactions;
  }

  private async request<T>(path: string): Promise<T> {
    const apiKey = await this.getApiKey();
    const url = path.startsWith("http") ? path : `${this.baseUrl}${path}`;
    const response = await this.fetchImplementation(url, {
      headers: { "X-API-KEY": apiKey, Accept: "application/json" },
      signal: AbortSignal.timeout(30_000),
    });
    if (!response.ok) throw new Error(`Pluggy respondeu HTTP ${response.status}.`);
    return (await response.json()) as T;
  }

  private async getApiKey(): Promise<string> {
    if (this.apiKey && this.apiKey.expiresAt > Date.now()) return this.apiKey.value;
    const response = await this.fetchImplementation(`${this.baseUrl}/auth`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify({
        clientId: this.options.clientId,
        clientSecret: this.options.clientSecret,
      }),
      signal: AbortSignal.timeout(15_000),
    });
    if (!response.ok) {
      throw new Error(`Autenticação Pluggy falhou com HTTP ${response.status}.`);
    }
    const body = (await response.json()) as AuthResponse;
    this.apiKey = { value: body.apiKey, expiresAt: Date.now() + 110 * 60_000 };
    return body.apiKey;
  }
}
