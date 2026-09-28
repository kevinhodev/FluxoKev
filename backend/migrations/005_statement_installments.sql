CREATE TABLE credit_card_statement_installments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  statement_id UUID NOT NULL REFERENCES credit_card_statements(id) ON DELETE CASCADE,
  line_index INTEGER NOT NULL CHECK (line_index > 0),
  merchant_name TEXT NOT NULL,
  purchase_date DATE,
  installment_number INTEGER NOT NULL CHECK (installment_number > 0),
  total_installments INTEGER NOT NULL CHECK (total_installments >= installment_number),
  amount_minor_units BIGINT NOT NULL CHECK (amount_minor_units > 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (statement_id, line_index)
);

CREATE INDEX credit_card_statement_installments_statement_idx
  ON credit_card_statement_installments (statement_id);
