#!/bin/sh
# Troca a senha de um usuário. Rode na instância:
#   ~/fluxo/scripts/set-password.sh kevin@fluxo.local
#
# A API não expõe endpoint de troca de senha, então o caminho é atualizar o
# hash direto no banco usando a mesma função que o login verifica.
#
# A senha é lida por prompt oculto e enviada ao container por stdin: não entra
# no histórico do shell nem na lista de processos.
set -eu

ALVO="${1:-}"
if [ -z "$ALVO" ]; then
	echo "uso: $0 <email>" >&2
	exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -qx fluxo-api; then
	echo "container fluxo-api não está rodando" >&2
	exit 1
fi

printf 'Nova senha para %s (mínimo 12): ' "$ALVO" >&2
stty -echo 2>/dev/null || true
read -r SENHA
stty echo 2>/dev/null || true
printf '\n' >&2

printf 'Confirme: ' >&2
stty -echo 2>/dev/null || true
read -r CONFIRMA
stty echo 2>/dev/null || true
printf '\n' >&2

if [ "$SENHA" != "$CONFIRMA" ]; then
	echo "as senhas não conferem" >&2
	exit 1
fi

# O mínimo de 12 é validado pelo próprio hashPassword, mas conferir aqui evita
# digitar duas vezes para só então descobrir que foi recusada.
if [ "${#SENHA}" -lt 12 ]; then
	echo "a senha precisa de pelo menos 12 caracteres (tem ${#SENHA})" >&2
	exit 1
fi

printf '%s' "$SENHA" | docker exec -i -e ALVO="$ALVO" fluxo-api \
	node --input-type=module -e '
import { hashPassword } from "/app/dist/src/security/password.js";
import { createPool } from "/app/dist/src/db/pool.js";

let senha = "";
for await (const parte of process.stdin) senha += parte;

const pool = createPool(process.env.DATABASE_URL);
try {
  const hash = await hashPassword(senha);
  const r = await pool.query(
    "UPDATE users SET password_hash = $1, updated_at = now() WHERE email = lower($2)",
    [hash, process.env.ALVO],
  );
  if (r.rowCount === 1) {
    console.log("senha atualizada para " + process.env.ALVO);
  } else {
    console.error("nenhum usuário com o e-mail " + process.env.ALVO);
    process.exitCode = 1;
  }
} finally {
  await pool.end();
}
'
