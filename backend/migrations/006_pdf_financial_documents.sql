CREATE TABLE financial_document_imports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kind TEXT NOT NULL CHECK (kind IN ('LOAN', 'PENSION')),
  file_name TEXT NOT NULL,
  document_sha256 TEXT NOT NULL,
  document_date DATE,
  parsed_data JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, kind, document_sha256)
);

CREATE TABLE loans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  import_id UUID NOT NULL REFERENCES financial_document_imports(id),
  provider_name TEXT NOT NULL,
  product_name TEXT NOT NULL,
  contract_number TEXT NOT NULL,
  contract_date DATE NOT NULL,
  current_balance_minor_units BIGINT NOT NULL CHECK (current_balance_minor_units >= 0),
  original_total_minor_units BIGINT NOT NULL CHECK (original_total_minor_units >= 0),
  debit_day SMALLINT NOT NULL CHECK (debit_day BETWEEN 1 AND 31),
  monthly_interest_rate NUMERIC(9, 6),
  annual_interest_rate NUMERIC(9, 6),
  monthly_effective_cost NUMERIC(9, 6),
  annual_effective_cost NUMERIC(9, 6),
  total_installments INTEGER NOT NULL CHECK (total_installments > 0),
  paid_installments INTEGER NOT NULL CHECK (paid_installments >= 0),
  remaining_installments INTEGER NOT NULL CHECK (remaining_installments >= 0),
  amortized_installments INTEGER NOT NULL DEFAULT 0 CHECK (amortized_installments >= 0),
  next_due_date DATE,
  projected_end_date DATE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, contract_number)
);

CREATE TABLE loan_installments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  loan_id UUID NOT NULL REFERENCES loans(id) ON DELETE CASCADE,
  installment_number INTEGER NOT NULL CHECK (installment_number > 0),
  due_date DATE NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('PAID', 'OPEN')),
  payment_kind TEXT NOT NULL CHECK (payment_kind IN ('REGULAR', 'AMORTIZED', 'PENDING')),
  amount_minor_units BIGINT NOT NULL CHECK (amount_minor_units > 0),
  UNIQUE (loan_id, installment_number)
);

CREATE INDEX loan_installments_due_idx
  ON loan_installments (loan_id, status, due_date);

CREATE TABLE pension_positions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  import_id UUID NOT NULL REFERENCES financial_document_imports(id),
  provider_name TEXT NOT NULL,
  profile_name TEXT NOT NULL,
  tax_regime TEXT,
  enrollment_date DATE,
  balance_date DATE NOT NULL,
  updated_through DATE,
  current_balance_minor_units BIGINT NOT NULL CHECK (current_balance_minor_units >= 0),
  part_one_balance_minor_units BIGINT NOT NULL DEFAULT 0 CHECK (part_one_balance_minor_units >= 0),
  participant_reserve_minor_units BIGINT NOT NULL DEFAULT 0 CHECK (participant_reserve_minor_units >= 0),
  employer_reserve_minor_units BIGINT NOT NULL DEFAULT 0 CHECK (employer_reserve_minor_units >= 0),
  monthly_return NUMERIC(9, 6),
  yearly_return NUMERIC(9, 6),
  twelve_month_return NUMERIC(9, 6),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, provider_name, profile_name)
);

CREATE TABLE pension_monthly_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pension_position_id UUID NOT NULL REFERENCES pension_positions(id) ON DELETE CASCADE,
  reference_month DATE NOT NULL,
  opening_balance_minor_units BIGINT NOT NULL,
  returns_minor_units BIGINT NOT NULL,
  employer_part_2a_minor_units BIGINT NOT NULL,
  employer_part_2b_minor_units BIGINT NOT NULL,
  participant_part_2a_minor_units BIGINT NOT NULL,
  participant_part_2b_minor_units BIGINT NOT NULL,
  participant_part_2c_minor_units BIGINT NOT NULL,
  personal_portability_minor_units BIGINT NOT NULL,
  employer_portability_minor_units BIGINT NOT NULL,
  closing_balance_minor_units BIGINT NOT NULL,
  UNIQUE (pension_position_id, reference_month)
);

CREATE INDEX pension_history_month_idx
  ON pension_monthly_history (pension_position_id, reference_month DESC);
