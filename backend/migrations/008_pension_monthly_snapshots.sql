CREATE TABLE pension_monthly_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pension_position_id UUID NOT NULL REFERENCES pension_positions(id) ON DELETE CASCADE,
  reference_month DATE NOT NULL,
  as_of_date DATE NOT NULL,
  accumulated_return_minor_units BIGINT NOT NULL,
  closing_balance_minor_units BIGINT NOT NULL CHECK (closing_balance_minor_units >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (pension_position_id, reference_month),
  CHECK (reference_month = date_trunc('month', reference_month)::date),
  CHECK (as_of_date >= reference_month),
  CHECK (as_of_date < reference_month + INTERVAL '1 month')
);

CREATE INDEX pension_monthly_snapshots_date_idx
  ON pension_monthly_snapshots (pension_position_id, as_of_date DESC);
