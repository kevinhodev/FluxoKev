INSERT INTO categories (id, parent_id, name, type) VALUES
  ('communications-mobile', 'communications', 'Telefonia', 'EXPENSE')
ON CONFLICT (id) DO NOTHING;

UPDATE fixed_expenses
SET active = false,
    updated_at = now()
WHERE name = 'Luz RJ'
  AND location_label = 'Rio de Janeiro'
  AND active = true;

INSERT INTO fixed_expenses (
  user_id, name, category_id, amount_minor_units, value_kind, location_label, note
)
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
