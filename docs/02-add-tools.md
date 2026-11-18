# 2~4단계: 기능을 하나씩 추가하기

에이전트에 기능을 붙이는 방법은 세 가지입니다. 상황에 맞는 것을 고르세요.

| 방법 | 언제 | 예 |
|---|---|---|
| **A. mcpo에 MCP 서버 추가** | 공개된 MCP 서버가 있고 로컬에서 실행(stdio)할 때 | 파일, 브라우저, Git, DB 조회 |
| **B. 원격 MCP 서버 직접 연결** | 서비스가 HTTP MCP 엔드포인트를 제공할 때 | SaaS 공식 MCP 서버 |
| **C. n8n 워크플로를 MCP 도구로 노출** | OAuth 연동, 여러 단계, 승인 흐름, 정기 실행이 필요할 때 | Gmail, Google Calendar, Notion, 아침 브리핑 |

> **원칙**: 먼저 **읽기 전용** 도구로 시작하고, 쓰기 도구(메일 발송, 삭제)는 동작을 충분히 확인한 뒤 승인 단계를 붙여서 추가하세요.

---

## A. mcpo에 MCP 서버 추가

1. `stack/mcpo/config.json`에 서버를 추가합니다. mcpo가 `--hot-reload`로 실행 중이라 저장하면 자동으로 다시 읽습니다.

   ```jsonc
   {
     "mcpServers": {
       "time":  { "command": "uvx", "args": ["mcp-server-time", "--local-timezone=Asia/Seoul"] },
       "fetch": { "command": "uvx", "args": ["mcp-server-fetch"] },
       "files": { "command": "npx", "args": ["-y", "@modelcontextprotocol/server-filesystem", "/data/files"] },

       // 예: Git 저장소 조회 (/data/files/repos 아래)
       "git": { "command": "uvx", "args": ["mcp-server-git", "--repository", "/data/files/repos/myrepo"] }
     }
   }
   ```

   (실제 파일은 JSON이므로 `//` 주석은 넣지 마세요.)

2. API 키가 필요한 서버는 키를 `config.json`에 직접 쓰지 말고 `stack/mcpo/secrets.env`에 `NAME=value` 형식으로 넣은 뒤, `docker compose up -d mcpo`로 재시작합니다. 이 파일은 git에서 제외되어 있습니다.

3. Open WebUI에 등록합니다. **Admin Panel → Settings → Tools**(외부 도구 서버)에서 **+**를 누르고 다음과 같이 입력합니다.
   - Type: **OpenAPI**
   - URL: `http://mcpo:8000/<서버이름>` (예: `http://mcpo:8000/git`)
   - Auth: Bearer, Key: `.env`의 `MCPO_API_KEY` 값

4. **Admin Panel → Settings → Models → 사용할 모델 → Tools**에서 새 도구를 체크합니다.

> `docker-compose.yml`의 `TOOL_SERVER_CONNECTIONS`는 **첫 부팅 때만** 적용됩니다. 그 뒤로는 위 관리 화면에서 추가합니다.

MCP 서버는 [modelcontextprotocol/servers](https://github.com/modelcontextprotocol/servers) 목록과 공식 MCP Registry에서 찾을 수 있습니다. **커뮤니티 서버는 설치 전에 코드와 요구 권한을 확인하세요.** 서버는 컨테이너 안에서 실행되며 `/data/files` 폴더에만 접근할 수 있습니다.

---

## B. 원격 MCP 서버 직접 연결

Open WebUI는 Streamable HTTP 방식의 MCP 서버를 직접 지원합니다.
**Admin Panel → Settings → Tools → +** 에서 Type을 **MCP (Streamable HTTP)**로 고르고, URL과 인증(Bearer 또는 OAuth)을 입력합니다.

---

## C. n8n 워크플로를 도구로 노출 (Google·Notion 등 개인 데이터 연동)

n8n은 Google, Notion, Slack 등 수백 개 서비스의 **OAuth 로그인 흐름을 내장**하고 있어 개인 계정 연동이 가장 쉽습니다.
워크플로를 **MCP Server Trigger**로 노출하면, Open WebUI에서 대화 중에 그 워크플로를 도구처럼 호출합니다.

### C-1. Google 계정 연결 (Calendar, Gmail 공통, 최초 1회)

1. [Google Cloud Console](https://console.cloud.google.com)에서 새 프로젝트를 만듭니다.
2. **APIs & Services → Library**에서 `Google Calendar API`, `Gmail API`를 사용 설정합니다.
3. **OAuth consent screen**: User type은 External, 테스트 사용자에 본인 Gmail을 추가합니다. Publishing status는 Testing으로 두면 본인만 사용할 수 있습니다.
4. **Credentials → Create Credentials → OAuth client ID**를 만듭니다.
   - Application type: **Web application**
   - Authorized redirect URI: `https://myserver.tail1234.ts.net:8443/rest/oauth2-credential/callback`
     (n8n 크리덴셜 생성 화면에 표시되는 "OAuth Redirect URL"을 그대로 복사하세요.)
5. n8n → **Credentials → Add → Google Calendar OAuth2 API**에 Client ID와 Secret을 넣고 **Sign in with Google**을 누릅니다. Gmail도 같은 방법으로 추가합니다.

> 리디렉션은 브라우저 안에서 일어나므로 서버를 인터넷에 공개하지 않아도 됩니다(tailnet 주소로 충분).
> Testing 상태의 OAuth 앱은 토큰이 7일마다 만료될 수 있습니다. 만료되면 n8n 크리덴셜에서 다시 로그인하세요.

### C-2. "내 일정" 도구 만들기 (읽기 전용 예시)

n8n에서 새 워크플로를 만듭니다.

1. **MCP Server Trigger** 노드를 추가합니다.
   - Path: `personal` (엔드포인트: `http://n8n:5678/mcp/personal`)
   - Authentication: **Bearer Auth**. 새 크리덴셜을 만들고 긴 무작위 토큰을 지정합니다(`openssl rand -hex 32`).
2. 트리거의 Tools 입력에 **Google Calendar Tool** 노드를 연결합니다.
   - Operation: **Get Many** (이벤트 조회)
   - Calendar: primary, Time Min/Max: "Let the model define" (✨ 버튼)
   - Tool Description: `사용자의 구글 캘린더 일정을 기간으로 조회한다`
3. 필요하면 같은 트리거에 **Gmail Tool**(Get Many, 읽기)도 연결합니다.
4. 워크플로를 **Publish(활성화)** 합니다. 활성화된 워크플로만 운영 URL(`/mcp/...`)이 동작합니다.

Open WebUI에 등록합니다. **Admin Panel → Settings → Tools → +**
- Type: **MCP (Streamable HTTP)**
- URL: `http://n8n:5678/mcp/personal`
- Auth: Bearer, Key: 위에서 만든 토큰

이제 폰에서 "이번 주 내 일정 알려줘", "어제 온 메일 중 중요한 것 요약해줘"라고 물어보세요.

### C-3. 쓰기 작업은 승인 단계와 함께

일정 생성이나 메일 발송처럼 쓰기 작업은 바로 실행하지 말고 사람이 확인한 뒤 실행되게 만드세요.

- **간단한 방법**: 시스템 프롬프트에 "실행 전 요약을 보여주고 확인받기" 규칙을 둡니다(1단계에서 설정). 모델의 판단에 맡기는 방식입니다.
- **확실한 방법**: 도구 대신 **서브 워크플로**(`Call n8n Workflow Tool`)를 연결합니다. 그 워크플로 안에서 **Telegram → Send and Wait for Response**(승인 버튼)를 거친 뒤에만 Gmail Send가 실행되게 합니다. 폰으로 "승인/거절" 버튼이 옵니다.

### C-4. Telegram 알림과 아침 브리핑 (정기 작업)

**Telegram 봇 만들기**

1. Telegram에서 `@BotFather`를 열고 `/newbot`으로 봇을 만든 뒤 토큰을 받습니다.
2. 만든 봇에게 아무 메시지나 보냅니다.
3. n8n에서 **Credentials → Telegram API**에 토큰을 넣습니다.
4. 내 chat ID는 `https://api.telegram.org/bot<토큰>/getUpdates` 응답의 `chat.id`에서 확인합니다.

**아침 브리핑 워크플로**

```
Schedule Trigger (평일 07:30)
  → Google Calendar: 오늘 일정 조회
  → Gmail: 지난 24시간 안 읽은 메일 조회
  → HTTP Request: 날씨 API (선택)
  → AI Agent 또는 Basic LLM Chain
       Model: OpenAI Chat Model 노드
         Base URL: http://litellm:4000/v1   (Credentials의 Base URL 항목)
         API Key : .env의 LITELLM_MASTER_KEY
         Model   : claude-haiku
       Prompt: "아래 일정/메일/날씨로 오늘 아침 브리핑을 5줄로 써줘 …"
  → Telegram: Send Message (내 chat ID)
```

> n8n의 LLM 노드도 **LiteLLM을 거치게** 하면 비용이 한곳에서 집계되고, 모델 교체도 LiteLLM 설정 한 곳에서 끝납니다.
> LiteLLM UI(`ssh -L 4000:localhost:4000 서버` 후 `http://localhost:4000/ui`)에서 n8n 전용 가상 키를 만들고 월 예산을 걸어두면 더 안전합니다.

**Telegram으로 명령 받기(선택)**: Telegram Trigger는 Telegram 서버가 내 서버로 웹훅을 보내야 하므로 **공개 HTTPS 주소**가 필요합니다. 필요할 때만 `tailscale funnel`로 n8n 웹훅 포트를 공개하고, 워크플로 첫 단계에서 **내 chat ID만 허용**하는 IF 노드를 반드시 넣으세요. 대부분은 Open WebUI 앱으로 명령하고 Telegram은 알림 수신용으로 쓰는 것을 권장합니다.

---

## 다음 단계 아이디어

| 기능 | 방법 |
|---|---|
| Notion 페이지 검색, 작성 | n8n Notion 노드 → MCP Server Trigger (C 방식) |
| 내 문서로 질의응답(RAG) | Open WebUI **Workspace → Knowledge**에 문서 업로드, 채팅에서 `#`로 참조 |
| 웹 검색 | Admin Panel → Settings → Web Search (SearXNG 자체 호스팅 또는 검색 API 키) |
| 브라우저 자동화 | mcpo에 Playwright MCP 서버 추가 (A 방식, 헤드리스 브라우저 필요) |
| 집안 IoT | Home Assistant의 MCP Server 통합 → B 방식으로 연결 |
| 호출 추적, 비용 대시보드 | Langfuse 셀프 호스팅 + LiteLLM `success_callback: ["langfuse"]` |
