ALTER TABLE loans
  ADD COLUMN IF NOT EXISTS repayment_kind TEXT NOT NULL DEFAULT 'MONTHLY'
    CHECK (repayment_kind IN ('MONTHLY', 'THIRTEENTH_SALARY')),
  ADD COLUMN IF NOT EXISTS payroll_deducted BOOLEAN NOT NULL DEFAULT false;

CREATE TABLE IF NOT EXISTS payroll_profiles (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  reference_month DATE NOT NULL,
  regular_net_reference_minor_units BIGINT NOT NULL
    CHECK (regular_net_reference_minor_units >= 0),
  excluded_deduction_minor_units BIGINT NOT NULL DEFAULT 0
    CHECK (excluded_deduction_minor_units >= 0),
  exclusion_effective_from DATE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Perfil inicial derivado dos créditos líquidos já conciliados. O PDF-fonte não é armazenado.
INSERT INTO payroll_profiles (
  user_id,
  reference_month,
  regular_net_reference_minor_units,
  excluded_deduction_minor_units,
  exclusion_effective_from
)
SELECT id, DATE '2026-06-01', 571568, 25867, DATE '2026-07-01'
FROM users
ON CONFLICT (user_id) DO NOTHING;

UPDATE loans
SET
  repayment_kind = CASE
    WHEN upper(product_name) LIKE '%13%SALARIO%' THEN 'THIRTEENTH_SALARY'
    ELSE 'MONTHLY'
  END,
  payroll_deducted = upper(product_name) LIKE '%CONSIGNA%';
