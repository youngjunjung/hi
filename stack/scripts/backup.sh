#!/usr/bin/env bash
# 전체 DB 덤프 + 볼륨(Open WebUI 업로드 파일, n8n 설정) 백업.
# cron 예: 0 4 * * * /opt/agent/stack/scripts/backup.sh >> /var/log/agent-backup.log 2>&1
set -euo pipefail
cd "$(dirname "$0")/.."
source .env

DEST=${BACKUP_DIR:-./backups}/$(date +%Y%m%d-%H%M%S)
mkdir -p "$DEST"

docker compose exec -T postgres pg_dumpall -U "$POSTGRES_USER" | gzip > "$DEST/postgres.sql.gz"

for vol in open-webui-data n8n-data; do
  # cache/ (임베딩·음성 모델 등)는 다시 내려받으면 되므로 제외
  docker run --rm -v "agent_${vol}:/v:ro" -v "$(realpath "$DEST"):/out" alpine:3.22 \
    tar czf "/out/${vol}.tar.gz" --exclude=./cache -C /v .
done

cp .env "$DEST/env.backup" && chmod 600 "$DEST/env.backup"
tar czf "$DEST/config.tar.gz" litellm mcpo
echo "backup → $DEST"

# 14일 지난 백업 삭제
find "${BACKUP_DIR:-./backups}" -mindepth 1 -maxdepth 1 -type d -mtime +14 -exec rm -rf {} +
