#!/usr/bin/env bash
# .env의 비어 있는 비밀값을 무작위로 채웁니다. 이미 값이 있으면 건드리지 않습니다.
set -euo pipefail
cd "$(dirname "$0")/.."

[ -f .env ] || cp .env.example .env

gen() { openssl rand -hex 32; }

fill() {
  local key=$1 value=$2
  if grep -qE "^${key}=$" .env; then
    sed -i "s|^${key}=$|${key}=${value}|" .env
    echo "generated ${key}"
  fi
}

fill POSTGRES_PASSWORD   "$(gen)"
fill LITELLM_MASTER_KEY  "sk-$(gen)"
fill LITELLM_SALT_KEY    "sk-$(gen)"
fill LITELLM_UI_PASSWORD "$(openssl rand -base64 18 | tr -d '/+=')"
fill WEBUI_SECRET_KEY    "$(gen)"
fill N8N_ENCRYPTION_KEY  "$(gen)"
fill MCPO_API_KEY        "$(gen)"

chmod 600 .env
mkdir -p data/files
touch mcpo/secrets.env && chmod 600 mcpo/secrets.env

if grep -qE '^ANTHROPIC_API_KEY=$' .env; then
  echo "⚠  .env 의 ANTHROPIC_API_KEY 를 채워주세요."
fi
echo "done. (.env 권한 600)"
