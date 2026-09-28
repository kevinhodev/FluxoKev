-- Quitação antecipada lançada à mão, fora do ciclo do dia do débito.
-- Fica em coluna própria para não sobrescrever o status vindo do extrato:
-- assim o lançamento é reversível e o reimport do PDF não é perdido.
ALTER TABLE loan_installments
  ADD COLUMN IF NOT EXISTS early_settled BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS loan_installments_early_idx
  ON loan_installments (loan_id) WHERE early_settled;
