CREATE TABLE credit_card_statements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  statement_month DATE NOT NULL,
  due_date DATE NOT NULL,
  closed_at DATE,
  next_close_date DATE,
  total_minor_units BIGINT NOT NULL CHECK (total_minor_units >= 0),
  previous_balance_minor_units BIGINT NOT NULL DEFAULT 0,
  payments_minor_units BIGINT NOT NULL DEFAULT 0,
  future_installments_minor_units BIGINT NOT NULL DEFAULT 0,
  status TEXT NOT NULL CHECK (status IN ('OPEN', 'PAID', 'OVERDUE')),
  paid_at DATE,
  source TEXT NOT NULL CHECK (source IN ('PLUGGY', 'PDF_IMPORT', 'MANUAL')),
  document_sha256 TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, account_id, statement_month)
);

CREATE UNIQUE INDEX credit_card_statements_document_unique
  ON credit_card_statements (user_id, document_sha256)
  WHERE document_sha256 IS NOT NULL;

CREATE INDEX credit_card_statements_account_due_idx
  ON credit_card_statements (account_id, due_date DESC);
