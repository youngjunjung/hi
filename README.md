# 개인 AI 에이전트 (안 C: 하이브리드)

Ubuntu 서버에 백엔드를 두고, 폰/태블릿에서 자연어로 명령하면 작업을 대신 처리하는 개인 에이전트입니다.
대중적인 오픈소스만 조합하고, 기능은 **MCP 서버** 또는 **n8n 워크플로**를 하나씩 붙여서 늘려갑니다.

```
[폰/태블릿]  Open WebUI PWA (채팅·음성)        Telegram (알림 수신)
      │  Tailscale VPN (인터넷에 포트 공개 없음)        ▲
      ▼                                               │
┌──────────────────────── Ubuntu 서버 · docker compose ───────────────────────┐
│  Open WebUI ──(OpenAI API)──▶ LiteLLM ──▶ Claude API (Opus / Sonnet / Haiku)  │
│      │                                                                       │
│      ├─(OpenAPI)──▶ mcpo ──▶ MCP 서버들 (time, fetch, files, …추가)           │
│      └─(MCP)──────▶ n8n  ──▶ Gmail·Calendar·Notion·정기 작업·승인 흐름 ──────┘
│                                                                              │
│  Postgres + pgvector (Open WebUI 대화·RAG, n8n, LiteLLM 사용량)               │
└──────────────────────────────────────────────────────────────────────────────┘
```

| 구성 요소 | 역할 | 버전(고정) |
|---|---|---|
| [Open WebUI](https://github.com/open-webui/open-webui) | 채팅 UI, PWA, 음성 입력, RAG, 도구 호출 | v0.13.3 |
| [LiteLLM](https://github.com/BerriAI/litellm) | LLM 게이트웨이 (모델 교체, 비용 추적, 폴백) | v1.108.11-lts |
| [mcpo](https://github.com/open-webui/mcpo) | stdio MCP 서버 → OpenAPI 도구 서버 브리지 | 0.0.20 (digest) |
| [n8n](https://github.com/n8n-io/n8n) | 워크플로, 정기 작업, 400+ SaaS 연동, MCP 서버 | 2.48.4 |
| [pgvector](https://github.com/pgvector/pgvector) | Postgres + 벡터 검색 | 0.8.7-pg17 |
| [Tailscale](https://tailscale.com) | 폰 ↔ 서버 사설 네트워크 + HTTPS 인증서 | (호스트 설치) |

## 빠른 시작

```bash
git clone <이 저장소> /opt/agent && cd /opt/agent/stack
cp .env.example .env
vi .env                      # ANTHROPIC_API_KEY, TS_HOSTNAME 입력
./scripts/init-secrets.sh    # 나머지 비밀값 자동 생성
docker compose up -d
sudo tailscale serve --bg 3000                 # https://<서버>.ts.net      → Open WebUI
sudo tailscale serve --bg --https=8443 5678    # https://<서버>.ts.net:8443 → n8n
```

자세한 순서는 아래 문서를 따라가세요.

1. **[docs/01-setup.md](docs/01-setup.md)**: 서버 준비, 설치, 폰 연결 (1단계)
2. **[docs/02-add-tools.md](docs/02-add-tools.md)**: 기능 추가 방법 (MCP 서버, n8n 워크플로, Google·Notion·Telegram) (2~3단계)
3. **[docs/03-operations.md](docs/03-operations.md)**: 백업, 업그레이드, 보안 점검

## 로드맵

| 단계 | 목표 | 상태 |
|---|---|---|
| 1 | 기반: Open WebUI + LiteLLM + Tailscale, 폰에서 대화 | 이 저장소로 바로 가능 |
| 2 | 기본 도구: 시간, 웹페이지 읽기, 서버 파일 작업 (MCP) | 기본 포함 |
| 3 | 개인 데이터: Google Calendar·Gmail·Notion (n8n → MCP) | 가이드 제공 |
| 4 | 자동화: 아침 브리핑, Telegram 알림, 승인 흐름 | 가이드 제공 |
| 5 | 지식·기억: 내 문서 RAG, 장기 기억, Langfuse 관측 | 추후 |
| 6 | 확장: 브라우저 자동화(Playwright MCP), Home Assistant, 업무 API | 추후 |
