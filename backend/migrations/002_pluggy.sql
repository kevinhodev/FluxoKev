CREATE TABLE financial_connections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider TEXT NOT NULL CHECK (provider IN ('PLUGGY')),
  external_item_id TEXT NOT NULL,
  connector_name TEXT NOT NULL,
  status TEXT NOT NULL,
  execution_status TEXT,
  provider_updated_at TIMESTAMPTZ,
  last_sync_at TIMESTAMPTZ,
  last_error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, provider, external_item_id)
);

ALTER TABLE accounts
  ADD COLUMN connection_id UUID REFERENCES financial_connections(id) ON DELETE SET NULL,
  ADD COLUMN external_id TEXT;

ALTER TABLE accounts
  ADD CONSTRAINT accounts_user_external_id_unique UNIQUE (user_id, external_id);

ALTER TABLE transactions
  DROP CONSTRAINT IF EXISTS transactions_source_check;

ALTER TABLE transactions
  ADD CONSTRAINT transactions_source_check CHECK (
    source IN (
      'OPEN_FINANCE', 'PLUGGY', 'OFX_IMPORT', 'CSV_IMPORT',
      'XLSX_IMPORT', 'PDF_IMPORT', 'MANUAL'
    )
  ),
  ADD COLUMN provider_status TEXT CHECK (provider_status IN ('PENDING', 'POSTED')),
  ADD COLUMN provider_category TEXT,
  ADD COLUMN provider_metadata JSONB NOT NULL DEFAULT '{}'::jsonb;

INSERT INTO categories (id, parent_id, name, type) VALUES
  ('other-income', NULL, 'Outras receitas', 'INCOME')
ON CONFLICT (id) DO NOTHING;

CREATE INDEX accounts_connection_idx ON accounts (connection_id);
CREATE INDEX financial_connections_user_idx ON financial_connections (user_id);
