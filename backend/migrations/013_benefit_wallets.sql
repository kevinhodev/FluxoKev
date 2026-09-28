CREATE TABLE benefit_wallets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  current_balance_minor_units BIGINT NOT NULL CHECK (current_balance_minor_units >= 0),
  monthly_credit_minor_units BIGINT NOT NULL CHECK (monthly_credit_minor_units >= 0),
  monthly_allocation_minor_units BIGINT NOT NULL DEFAULT 0
    CHECK (monthly_allocation_minor_units >= 0),
  allocation_label TEXT NOT NULL DEFAULT '',
  active BOOLEAN NOT NULL DEFAULT true,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, name)
);

CREATE INDEX benefit_wallets_user_active_idx
  ON benefit_wallets (user_id, active, name);

INSERT INTO benefit_wallets (
  user_id, name, current_balance_minor_units, monthly_credit_minor_units,
  monthly_allocation_minor_units, allocation_label, note
)
SELECT id, 'Alelo', 397500, 209713, 130000, 'Ajuda para minha mãe',
       'Benefício de uso restrito; não compõe o caixa livre.'
FROM users
ON CONFLICT (user_id, name) DO UPDATE SET
  current_balance_minor_units = EXCLUDED.current_balance_minor_units,
  monthly_credit_minor_units = EXCLUDED.monthly_credit_minor_units,
  monthly_allocation_minor_units = EXCLUDED.monthly_allocation_minor_units,
  allocation_label = EXCLUDED.allocation_label,
  active = true,
  note = EXCLUDED.note,
  updated_at = now();
