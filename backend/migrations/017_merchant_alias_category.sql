-- Regra pode, além de renomear, fixar a categoria.
--
-- A sincronização da Pluggy sobrescreve category_id a cada rodada (sync-service
-- linha ~281), então corrigir a categoria na transação seria perdido no próximo
-- sync. Guardando na regra e aplicando na leitura, a correção é permanente.
--
-- Nulo significa "só renomeia": nem toda regra precisa opinar sobre categoria.
ALTER TABLE merchant_aliases
  ADD COLUMN IF NOT EXISTS category_id TEXT REFERENCES categories(id);
