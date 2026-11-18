#!/bin/bash
# Postgres 컨테이너 최초 기동 시 1회 실행: 서비스별 DB 생성 + pgvector 확장
set -euo pipefail

for db in litellm n8n openwebui; do
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres \
    -c "CREATE DATABASE ${db};"
done

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname openwebui \
  -c "CREATE EXTENSION IF NOT EXISTS vector;"
