-- A contribuição do mês corrente deixa de ser projetada por heurística de data.
-- O saldo do snapshot passa a ser fiel à PREVI e a contribuição só entra quando
-- lançada explicitamente, evitando dobrar o valor quando a PREVI enfim credita.
ALTER TABLE pension_monthly_snapshots
  ADD COLUMN IF NOT EXISTS contribution_applied BOOLEAN NOT NULL DEFAULT false;
