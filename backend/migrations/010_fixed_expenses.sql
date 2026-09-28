INSERT INTO categories (id, parent_id, name, type) VALUES
  ('communications', NULL, 'Comunicação', 'EXPENSE'),
  ('communications-internet', 'communications', 'Internet', 'EXPENSE'),
  ('communications-mobile', 'communications', 'Telefonia', 'EXPENSE')
ON CONFLICT (id) DO NOTHING;

CREATE TABLE fixed_expenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  category_id TEXT NOT NULL REFERENCES categories(id),
  amount_minor_units BIGINT CHECK (amount_minor_units > 0),
  value_kind TEXT NOT NULL CHECK (value_kind IN ('FIXED', 'VARIABLE')),
  frequency TEXT NOT NULL DEFAULT 'MONTHLY' CHECK (frequency = 'MONTHLY'),
  location_label TEXT NOT NULL DEFAULT '',
  due_day SMALLINT CHECK (due_day BETWEEN 1 AND 31),
  active BOOLEAN NOT NULL DEFAULT true,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (value_kind = 'VARIABLE' OR amount_minor_units IS NOT NULL),
  UNIQUE (user_id, name, location_label)
);

CREATE INDEX fixed_expenses_user_active_idx
  ON fixed_expenses (user_id, active, name);

INSERT INTO fixed_expenses (
  user_id, name, category_id, amount_minor_units, value_kind, location_label, note
)
SELECT id, 'Aluguel RJ', 'housing-rent', 50000, 'FIXED', 'Rio de Janeiro',
       'Valor mensal informado pelo usuário.'
FROM users
UNION ALL
SELECT id, 'Seguro do carro', 'insurance', 19779, 'FIXED', '',
       'Valor mensal informado pelo usuário.'
FROM users
UNION ALL
SELECT id, 'Internet Flex Fibra', 'communications-internet', 9999, 'FIXED',
       'Rio de Janeiro', 'Valor mensal informado pelo usuário.'
FROM users
UNION ALL
SELECT id, 'TIM', 'communications-mobile', 11990, 'FIXED', '',
       'Valor mensal informado pelo usuário.'
FROM users
ON CONFLICT (user_id, name, location_label) DO UPDATE SET
  category_id = EXCLUDED.category_id,
  amount_minor_units = EXCLUDED.amount_minor_units,
  value_kind = EXCLUDED.value_kind,
  active = true,
  note = EXCLUDED.note,
  updated_at = now();
