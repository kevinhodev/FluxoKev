#!/bin/sh
# Backup diário do Postgres. Roda por cron na instância.
#
# O extrato do BB e o da PREVI dá para reimportar, mas os lançamentos manuais
# — quitação antecipada, contribuição da PREVI, baixa de fatura — só existem
# aqui. É o que justifica o backup mesmo com um banco de 12 MB.
set -eu

DIR="${BACKUP_DIR:-/home/ubuntu/backups}"
KEEP_DAYS="${BACKUP_KEEP_DAYS:-14}"
STAMP="$(date +%F_%H%M)"
FILE="$DIR/fluxo_ia-$STAMP.sql.gz"

mkdir -p "$DIR"

# --clean --if-exists deixa o dump restaurável por cima de um banco existente.
if ! docker exec fluxo-postgres pg_dump -U fluxo_ia -d fluxo_ia --clean --if-exists \
	| gzip -9 > "$FILE.partial"; then
	rm -f "$FILE.partial"
	echo "[$(date -Is)] FALHOU: pg_dump não completou" >&2
	exit 1
fi

# Só promove o arquivo depois do dump inteiro: um backup truncado que parece
# válido é pior do que backup nenhum, porque só se descobre na hora de restaurar.
mv "$FILE.partial" "$FILE"

# Um dump vazio ou minúsculo indica falha silenciosa.
SIZE="$(stat -c %s "$FILE")"
if [ "$SIZE" -lt 10240 ]; then
	echo "[$(date -Is)] ALERTA: backup com apenas $SIZE bytes" >&2
	exit 1
fi

find "$DIR" -name 'fluxo_ia-*.sql.gz' -mtime "+$KEEP_DAYS" -delete
echo "[$(date -Is)] ok: $FILE ($SIZE bytes)"
