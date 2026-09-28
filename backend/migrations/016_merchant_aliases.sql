-- Apelidos de estabelecimento definidos pelo usuário.
--
-- O mesmo lugar aparece sob vários descritores de cartão ("AIRBNB PAGAM*AIRB",
-- "AIRBNB PLATAF SAO PAULO", "AIRBNB * HM48DWW4ET"), o que fragmenta qualquer
-- análise por estabelecimento. Normalizar por regex erra nos dois sentidos:
-- colapsar pelo primeiro token juntaria "POSTO RUTH" com "POSTO CLUBE DOS 500".
--
-- Aqui quem escolhe o prefixo é o usuário, que sabe o que é a mesma coisa.
-- A tabela é separada de transactions de propósito: a sincronização da Pluggy
-- sobrescreve merchant_name a cada rodada, então o apelido seria perdido se
-- ficasse gravado na própria transação. Aplicando na leitura, ele sobrevive.
CREATE TABLE merchant_aliases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  -- Casado como prefixo, sem diferenciar maiúsculas.
  pattern TEXT NOT NULL CHECK (length(btrim(pattern)) >= 3),
  merchant_name TEXT NOT NULL CHECK (length(btrim(merchant_name)) >= 2),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, pattern)
);

CREATE INDEX merchant_aliases_user_idx ON merchant_aliases (user_id);
