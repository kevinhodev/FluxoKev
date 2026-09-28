CREATE TABLE pension_return_overrides (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pension_position_id UUID NOT NULL REFERENCES pension_positions(id) ON DELETE CASCADE,
  reference_month DATE NOT NULL,
  return_rate NUMERIC(9, 6) NOT NULL CHECK (return_rate BETWEEN -100 AND 1000),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (pension_position_id, reference_month),
  CHECK (reference_month = date_trunc('month', reference_month)::date)
);

CREATE INDEX pension_return_overrides_month_idx
  ON pension_return_overrides (pension_position_id, reference_month DESC);
