CREATE TABLE subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  billing_descriptor TEXT NOT NULL DEFAULT '',
  amount_minor_units BIGINT NOT NULL CHECK (amount_minor_units > 0),
  frequency TEXT NOT NULL DEFAULT 'MONTHLY' CHECK (frequency = 'MONTHLY'),
  billing_day SMALLINT CHECK (billing_day BETWEEN 1 AND 31),
  payment_method_label TEXT NOT NULL DEFAULT '',
  active BOOLEAN NOT NULL DEFAULT true,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, name)
);

CREATE INDEX subscriptions_user_active_idx
  ON subscriptions (user_id, active, name);

INSERT INTO subscriptions (
  user_id, name, billing_descriptor, amount_minor_units, billing_day,
  payment_method_label, note
)
SELECT id, 'Disney+', 'DL*GOOGLE Disney', 6990, 5,
       'OUROCARD PLATINUM VISA', 'Assinatura ativa confirmada pelo usuário.'
FROM users
UNION ALL
SELECT id, 'YouTube', 'DL*GOOGLE YouTub', 2690, 3,
       'OUROCARD PLATINUM VISA', 'Assinatura ativa confirmada pelo usuário.'
FROM users
UNION ALL
SELECT id, 'Claude', 'ANTHROPIC* CLAUDE SUB', 11000, 29,
       'OUROCARD PLATINUM VISA', 'Assinatura ativa confirmada pelo usuário.'
FROM users
UNION ALL
SELECT id, 'Amazon Prime', 'DL*GOOGLE Prime', 1990, 27,
       'OUROCARD PLATINUM VISA', 'Assinatura ativa confirmada pelo usuário.'
FROM users
UNION ALL
SELECT id, 'Premiere', 'Google Prime Video', 5990, 9,
       'OUROCARD PLATINUM VISA', 'Assinatura ativa confirmada pelo usuário.'
FROM users
ON CONFLICT (user_id, name) DO UPDATE SET
  billing_descriptor = EXCLUDED.billing_descriptor,
  amount_minor_units = EXCLUDED.amount_minor_units,
  billing_day = EXCLUDED.billing_day,
  payment_method_label = EXCLUDED.payment_method_label,
  active = true,
  note = EXCLUDED.note,
  updated_at = now();
