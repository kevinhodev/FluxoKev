# Fluxo IA Backend

API da Fase 1 do Fluxo IA. O servidor mantém autenticação, dados normalizados e
persistência PostgreSQL fora do aplicativo Flutter.

## Recursos atuais

- Login single-user com JWT de curta duração.
- Senhas derivadas com `scrypt` e comparação em tempo constante.
- Rate limit, headers seguros e CORS explícito.
- Instituições, contas, categorias hierárquicas e transações manuais.
- Valores monetários inteiros em centavos.
- Normalização determinística da descrição.
- Auditoria para edição de transações.
- Migrações SQL idempotentes.
- Sincronização Pluggy paginada por cursor e deduplicada por ID externo.
- Status pendente/efetivado e categoria original do provedor preservados.
- Cartões com a mesma linha de crédito consolidados sem misturar os extratos.
- Análise local de parcelamentos e recorrências em `GET /v1/commitments`.

## Desenvolvimento sem banco

```powershell
npm.cmd install
npm.cmd test
npm.cmd run check
```

Os testes usam repositórios em memória e não precisam do PostgreSQL.

## Execução com Docker

1. Copie `.env.example` para `.env`.
2. Gere valores fortes para `POSTGRES_PASSWORD`, `JWT_SECRET` e
   `BOOTSTRAP_PASSWORD`.
3. Execute `docker compose up -d --build`.
4. Crie ou atualize o único usuário:

```powershell
docker compose run --rm api node dist/src/db/bootstrap-user.js
```

A API ficará disponível em `http://localhost:8080`. Verifique com `GET /health`.

Para sincronizar a conexão configurada, defina `PLUGGY_CLIENT_ID`,
`PLUGGY_CLIENT_SECRET` e `PLUGGY_ITEM_ID` em `.env`, faça login e envie
`POST /v1/integrations/pluggy/sync` com o token Bearer. Essas credenciais nunca
devem ir para o Flutter.

No emulador Android, o host da máquina é acessado por
`http://10.0.2.2:8080`. O manifesto permite HTTP apenas em builds de debug;
produção deve usar uma URL HTTPS definida com `--dart-define=FLUXO_API_URL=...`.

Não versione o arquivo `.env`. Tokens de Open Finance e chaves de IA deverão
permanecer apenas no backend/secret manager.
