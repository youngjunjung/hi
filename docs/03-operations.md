# 운영: 백업, 업그레이드, 보안

## 자주 쓰는 명령

```bash
cd /opt/agent/stack
docker compose ps                    # 상태
docker compose logs -f open-webui    # 로그 (litellm, mcpo, n8n, postgres)
docker compose restart mcpo          # 특정 서비스 재시작
docker compose down                  # 중지 (데이터는 볼륨에 유지)
```

## 백업

```bash
./scripts/backup.sh                  # ./backups/<날짜>/ 에 저장, 14일 지난 백업은 자동 삭제
```

백업에는 다음이 들어갑니다.

- Postgres 전체 덤프: 대화 기록, RAG 벡터, n8n 워크플로·크리덴셜, LiteLLM 사용량
- Open WebUI 업로드 파일, n8n 설정 볼륨 (모델 캐시 제외)
- `.env`와 `litellm/`, `mcpo/` 설정

매일 자동으로 백업하려면 `crontab -e`에 다음을 추가합니다.

```
0 4 * * * /opt/agent/stack/scripts/backup.sh >> /var/log/agent-backup.log 2>&1
```

> **`.env`의 `N8N_ENCRYPTION_KEY`를 잃어버리면 n8n에 저장된 크리덴셜을 복호화할 수 없습니다.** 백업 폴더를 다른 기기(NAS, 클라우드)에도 복사해 두세요.

**복원 순서** (새 서버 기준)

1. 저장소를 clone하고 `env.backup`을 `.env`로 복사합니다.
2. `docker compose up -d postgres`로 Postgres만 띄웁니다.
3. 초기화 스크립트가 만든 빈 DB를 지웁니다: `for db in litellm n8n openwebui; do docker compose exec -T postgres psql -U agent -d postgres -c "DROP DATABASE $db;"; done`
4. 덤프를 복원합니다: `gunzip -c postgres.sql.gz | docker compose exec -T postgres psql -U agent -d postgres`
5. 볼륨 tar를 `docker run --rm -v agent_<볼륨>:/v -v $PWD:/b alpine:3.22 tar xzf /b/<파일> -C /v`로 풉니다.
6. `docker compose up -d`로 전체를 띄웁니다.

## 업그레이드

이미지 버전은 `docker-compose.yml`에 고정되어 있습니다. 한 번에 하나씩 올리세요.

1. 먼저 `./scripts/backup.sh`로 백업합니다.
2. 각 프로젝트의 릴리스 노트에서 Breaking change를 확인합니다.
   - Open WebUI: <https://github.com/open-webui/open-webui/releases>
   - LiteLLM: <https://github.com/BerriAI/litellm/releases> (`-lts` 또는 `-stable` 태그 권장)
   - n8n: <https://github.com/n8n-io/n8n/releases> (`stable` 채널 버전)
3. `docker-compose.yml`의 태그를 바꾸고 `docker compose pull <서비스> && docker compose up -d <서비스>`를 실행합니다.
4. 문제가 생기면 태그를 되돌리고 다시 `up -d` 합니다. DB 마이그레이션이 일어난 경우에는 백업에서 복원합니다.

## 보안 체크리스트

- [ ] 모든 포트가 `127.0.0.1`에만 바인딩되어 있는지 (`ss -ltnp | grep -E '3000|4000|5678'`)
- [ ] `tailscale funnel`을 쓰지 않거나, 꼭 필요한 경로만 공개했는지
- [ ] Tailscale 관리 콘솔에서 **기기 승인(Device approval)**, 필요하면 ACL로 서버 접근 기기를 제한했는지
- [ ] Anthropic 콘솔의 **월 사용 한도**, LiteLLM 가상 키 예산을 설정했는지
- [ ] Open WebUI 신규 가입이 꺼져 있는지 (첫 관리자 가입 후 자동으로 꺼짐, 기본 역할은 `pending`)
- [ ] Gmail, Calendar는 읽기 도구부터 시작했는지. 쓰기 도구에는 승인 단계가 있는지
- [ ] 외부 콘텐츠(웹, 메일)를 읽는 대화에서 쓰기 도구를 같이 켜두지 않았는지 (프롬프트 인젝션 대비)
- [ ] `.env`, `mcpo/secrets.env`의 권한이 600인지, git에 커밋되지 않았는지
- [ ] 서버 OS 자동 보안 업데이트: `sudo apt install unattended-upgrades`
- [ ] 백업이 다른 기기에도 복사되는지
