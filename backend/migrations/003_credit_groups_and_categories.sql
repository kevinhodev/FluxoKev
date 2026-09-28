ALTER TABLE accounts
  ADD COLUMN balance_group_key TEXT,
  ADD COLUMN credit_limit_minor_units BIGINT,
  ADD COLUMN balance_due_date DATE,
  ADD COLUMN provider_metadata JSONB NOT NULL DEFAULT '{}'::jsonb;

INSERT INTO categories (id, parent_id, name, type) VALUES
  ('shopping', NULL, 'Compras', 'EXPENSE'),
  ('travel', NULL, 'Viagens', 'EXPENSE'),
  ('taxes', NULL, 'Impostos e taxas', 'EXPENSE'),
  ('bank-fees', NULL, 'Tarifas bancárias', 'EXPENSE'),
  ('leisure', NULL, 'Lazer', 'EXPENSE')
ON CONFLICT (id) DO NOTHING;

CREATE INDEX accounts_balance_group_idx ON accounts (user_id, balance_group_key);
