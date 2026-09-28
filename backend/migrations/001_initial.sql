CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE institutions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('BANK', 'PENSION', 'OTHER')),
  external_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, name)
);

CREATE TABLE accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  institution_id UUID NOT NULL REFERENCES institutions(id),
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('CHECKING', 'SAVINGS', 'PAYMENT', 'CREDIT_CARD', 'OTHER')),
  currency CHAR(3) NOT NULL DEFAULT 'BRL',
  current_balance_minor_units BIGINT NOT NULL DEFAULT 0,
  available_balance_minor_units BIGINT,
  last_sync_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE categories (
  id TEXT PRIMARY KEY,
  parent_id TEXT REFERENCES categories(id),
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('INCOME', 'EXPENSE', 'TRANSFER', 'INVESTMENT'))
);

CREATE TABLE transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  account_id UUID NOT NULL REFERENCES accounts(id),
  external_id TEXT,
  occurred_at TIMESTAMPTZ NOT NULL,
  description TEXT NOT NULL,
  normalized_description TEXT NOT NULL,
  merchant_name TEXT NOT NULL,
  amount_minor_units BIGINT NOT NULL CHECK (amount_minor_units > 0),
  direction TEXT NOT NULL CHECK (direction IN ('CREDIT', 'DEBIT')),
  nature TEXT NOT NULL CHECK (nature IN ('INCOME', 'EXPENSE', 'TRANSFER', 'INVESTMENT_RETURN')),
  category_id TEXT NOT NULL REFERENCES categories(id),
  source TEXT NOT NULL CHECK (source IN ('OPEN_FINANCE', 'OFX_IMPORT', 'CSV_IMPORT', 'XLSX_IMPORT', 'PDF_IMPORT', 'MANUAL')),
  fingerprint TEXT,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, source, external_id)
);

CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  action TEXT NOT NULL,
  old_value JSONB,
  new_value JSONB,
  source TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX transactions_user_date_idx ON transactions (user_id, occurred_at DESC);
CREATE INDEX transactions_user_category_idx ON transactions (user_id, category_id);
CREATE INDEX transactions_fingerprint_idx ON transactions (user_id, fingerprint);

INSERT INTO categories (id, parent_id, name, type) VALUES
  ('food', NULL, 'Alimentação', 'EXPENSE'),
  ('food-delivery', 'food', 'Delivery', 'EXPENSE'),
  ('food-supermarket', 'food', 'Supermercado', 'EXPENSE'),
  ('transport', NULL, 'Transporte', 'EXPENSE'),
  ('transport-fuel', 'transport', 'Combustível', 'EXPENSE'),
  ('transport-app', 'transport', 'Aplicativo', 'EXPENSE'),
  ('salary', NULL, 'Salário', 'INCOME'),
  ('subscriptions', NULL, 'Assinaturas', 'EXPENSE'),
  ('subscriptions-streaming', 'subscriptions', 'Streaming', 'EXPENSE'),
  ('housing', NULL, 'Moradia', 'EXPENSE'),
  ('housing-rent', 'housing', 'Aluguel', 'EXPENSE'),
  ('housing-utilities', 'housing', 'Energia', 'EXPENSE'),
  ('housing-condo', 'housing', 'Condomínio', 'EXPENSE'),
  ('health', NULL, 'Saúde', 'EXPENSE'),
  ('education', NULL, 'Educação', 'EXPENSE'),
  ('insurance', NULL, 'Seguros', 'EXPENSE'),
  ('other-expense', NULL, 'Outras despesas', 'EXPENSE'),
  ('transfer', NULL, 'Transferência', 'TRANSFER'),
  ('transfer-out', 'transfer', 'Saída', 'TRANSFER'),
  ('transfer-investment', 'transfer', 'Investimento', 'TRANSFER'),
  ('investments', NULL, 'Investimentos', 'INVESTMENT'),
  ('investments-return', 'investments', 'Rendimento', 'INVESTMENT')
ON CONFLICT (id) DO NOTHING;
