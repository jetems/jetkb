# jetKB Agent 集成设计文档

- **日期**：2026-05-14
- **范围**：CLI / MCP 接入层 + agent 用户与派单回写闭环
- **状态**：草案，待评审
- **方案**：B — 新增 `agent` 角色 + 专用 Agent 资源 + 共享 TS 客户端的独立 `jetkb-cli` 仓
- **关联文件**：本仓 `CLAUDE.md`、`AGENTS.md`、`docs/api/`、`docs/jetkb/`

## 0. 摘要

为 jetKB 增加两项能力：

1. **CLI / MCP 接入层**：让人类用户在终端，以及 LLM agent（Claude、Cursor、Cline 等）在对话中，都能操作 jetKB 看板。
2. **派单回写闭环**：把卡片"派给一个 agent 用户"，agent 通过 webhook 收到触发，自主执行，再用专用 API 端点回写完成状态。

设计原则：**fork-first**。jetKB 是 Basecamp Fizzy 的下游 fork，所有改动尽量集中在新文件，少改上游文件，能向上游 PR 的改动主动 PR，与 `CLAUDE.md` 制定的合并纪律对齐。

服务端 HTTP JSON API 已经完整存在（`docs/api/`）；Bearer Token 鉴权已可用（`Identity::AccessToken`）；Webhook 已支持 11 种事件。本设计**主要是在已有抽象之上加薄层**，而非重写。

---

## 1. 架构总览

### 1.1 系统四层

```
┌────────────────────────────────────────────────────────────────┐
│  人类用户                          AI Agent（任意进程/语言）    │
└─────────┬────────────────────────────────┬──────────────────────┘
          │                                │
          │ 终端 / Claude Code             │ HTTP + Bearer Token
          │                                │ Webhook 反向 push
          ▼                                ▼
┌──────────────────────┐         ┌─────────────────────────────┐
│  jetKB CLI (npm)     │◄────────│   用户自部署的 agent runner  │
│  jetKB MCP server    │  共享   │  （Copilot Agent / Claude    │
│  （TypeScript 单仓） │ 核心 SDK │   SDK / 自己写的 worker）    │
└──────────┬───────────┘         └──────────────┬──────────────┘
           │                                    │
           │  HTTP JSON + Bearer Token          │
           └─────────────┬──────────────────────┘
                         ▼
┌────────────────────────────────────────────────────────────────┐
│                    jetKB Rails (主应用)                         │
│                                                                 │
│   既有 JSON API（cards, comments, assignments, webhooks…）    │
│   + 新增：Agents namespace、agent role、agent_completion 端点  │
│   + 新增 webhook action：card_assigned_to_agent /              │
│                          card_agent_completed                  │
└────────────────────────────────────────────────────────────────┘
```

### 1.2 关键不变量

- HTTP JSON API 是唯一对外契约；CLI 和 MCP 都是它的客户端，不绕过 Rails。
- Agent 是 `User` 的一种 role，复用既有 `Assignment` / `Watch` / `Event` / `Webhook` 体系。
- 派单到回写完全异步；Rails 不等待 agent，agent 通过 webhook 入、HTTP 出。
- fork 隔离：新代码集中在新文件 + 一个 enum 末尾追加 + 一个 webhook actions 数组追加。

### 1.3 兼容性矩阵

| 既有抽象 | 受影响程度 |
|---|---|
| `User`、`Identity`、`Account` | enum 末尾加 1 个 role，否则不动 |
| `Assignment`、`Watch`、`Pin` | 完全不动 |
| `Event`、`Webhook` | 在常量数组里加 2 个 action 字符串 |
| 既有 controllers / views | 不动 |
| URL 路由 | 加 2 段新路由（`/agents`、`/cards/:n/agent_completion`） |
| 既有 JSON API | 不动；agent 用现有端点 |
| DB schema | 新增 1 张表 `card_agent_completions`（幂等键）；既有表不动 |

### 1.4 仓库布局

主仓新文件（节选）：

```
jetkb/
├── app/controllers/agents_controller.rb
├── app/controllers/agents/{tokens,board_accesses}_controller.rb
├── app/controllers/cards/agent_completions_controller.rb
├── app/models/card/agent_completion.rb
├── db/migrate/2026XXXX_create_card_agent_completions.rb
├── db/postgresql_migrate/2026XXXX_create_card_agent_completions.rb
├── config/initializers/jetkb_rate_limits.rb
├── config/initializers/jetkb_branding.rb
└── docs/{api/sections,jetkb}/...
```

CLI/MCP 独立仓 `jetkb-cli`，pnpm workspace：

```
jetkb-cli/
├── packages/core/   # @jetkb/core   共享 HTTP 客户端
├── packages/cli/    # @jetkb/cli    → 命令 `jetkb`
├── packages/mcp/    # @jetkb/mcp    → 命令 `jetkb-mcp`
└── apps/e2e/        # 跨栈 e2e
```

---

## 2. 数据模型变更

### 2.1 总览

上游文件改动（共 4 个）：

| 文件 | 变更 | 行数 |
|---|---|---|
| `app/models/user/role.rb` | enum 末尾追加 `agent`、加 `agent` / `api_active` scope、加 `agent?` 谓词 | +6 |
| `app/models/webhook.rb` | `PERMITTED_ACTIONS` 加 2 项 | +2 |
| `app/controllers/concerns/authorization.rb` | `ensure_can_access_account` 改用 `api_active?` | 改 1 |
| `app/models/account.rb` | 加 `agent_users` 便利 scope | +1 |

DB schema 变更：

- **users 表不动**：enum 是字符串列，新增枚举值不需要 schema 变更。
- **新增 1 张表** `card_agent_completions`（详见 2.8），仅用于 agent_completion 端点的幂等性记录。MySQL/SQLite 用 `db/migrate/`，PostgreSQL 用 `db/postgresql_migrate/`，两份并存。

### 2.2 `User::Role` 扩展

```ruby
module User::Role
  extend ActiveSupport::Concern

  included do
    enum :role, %i[ owner admin member system agent ].index_by(&:itself), scopes: false
    # 末尾追加保证整数枚举值稳定：owner=0、admin=1、member=2、system=3、agent=4

    scope :owner,      -> { where(active: true, role: :owner) }
    scope :admin,      -> { where(active: true, role: %i[ owner admin ]) }
    scope :member,     -> { where(active: true, role: :member) }
    scope :agent,      -> { where(active: true, role: :agent) }
    scope :active,     -> { where(active: true, role: %i[ owner admin member ]) }
    scope :api_active, -> { where(active: true, role: %i[ owner admin member agent ]) }
  end

  def agent?
    role == "agent"
  end

  def api_active?
    active? && role.in?(%w[ owner admin member agent ])
  end

  def admin?
    super || owner?
  end
end
```

### 2.3 `system` vs `agent` 边界

| 维度 | `system`（保留） | `agent`（新增） |
|---|---|---|
| 每账号数量 | 恰好 1 | 0~N |
| 用途 | jetKB 自己写的系统消息 | 外部 AI agent 人格 |
| 出现在 `Comment.by_system` | ✅ | ❌（agent 评论是真评论） |
| 出现在 `User.active` scope | ❌ | ❌ |
| 出现在 assignee 候选 | ❌ | ✅（核心场景） |
| 有 Identity | ❌ | ✅（每个 agent 一个 Identity）|
| 有 access token | ❌ | ✅ |

### 2.4 Agent 的 Identity

`Identity` 强制 `EMAIL_REGEXP` 校验。agent 没有真邮箱，使用合成邮箱：

```
<slug>@agent.local
# 例：code-review-bot@agent.local
```

- magic link 发送在 `send_magic_link` 处加 guard：若 identity 所有 user 都是 agent → 拒绝
- passkey 注册 UI 层不暴露
- access token 完全复用 `Identity::AccessToken`

### 2.5 `User.active` 二元性审计

| 检查点 | 现状 | agent 走哪条 |
|---|---|---|
| `users.active` DB 列 | bool，缺省 true | true |
| `User.active` scope | 不含 agent | 不进，保持人类语义 |
| `Current.user&.active?` | 读 DB 列 | 通过 |
| `accessible_cards` | 通过 `Access` 表 | 给 agent 显式 Access 或 all_access 板 |
| mention 候选 | 走 `active` scope | 不在候选 |

新增 `api_active?` 谓词替换 `ensure_can_access_account` 里对 `active?` 的判断（动 `concerns/authorization.rb`，`[jetkb]` 标记）。

### 2.6 Access 与可见性

- 创建 agent 时选择是否 `all_access_boards`（默认 true）
- 受限板通过 `Access` 表显式 grant，复用既有模型
- 派单时若 agent 看不到该板 → 422

### 2.7 Webhook actions 扩展

```ruby
# app/models/webhook.rb
PERMITTED_ACTIONS = %w[
  card_assigned
  card_assigned_to_agent      # 新
  card_closed
  card_postponed
  card_auto_postponed
  card_board_changed
  card_published
  card_reopened
  card_sent_back_to_triage
  card_triaged
  card_unassigned
  card_agent_completed        # 新
  comment_created
].freeze
```

- `card_assigned_to_agent`：assignee 是 agent 时与 `card_assigned` **并发触发**
- `card_agent_completed`：仅由 `POST /cards/:n/agent_completion` 触发

### 2.8 新建一张轻量表

`card_agent_completions` —— 用于 agent_completion 的幂等键，是本设计**唯一新表**：

| 列 | 类型 | 说明 |
|---|---|---|
| `id` | uuid (v7) | PK |
| `card_id` | fk | 卡片 |
| `user_id` | fk | agent 的 User |
| `idempotency_key` | string | 由 client 传入，可空 |
| `result` | string | succeeded/failed/cancelled/needs_human |
| `comment_id` | fk nullable | 创建的评论 |
| `event_id` | fk nullable | 触发的 event |
| `particulars` | json/jsonb | summary/outcome/artifacts/metrics 序列化 |
| `created_at` | datetime | |

唯一索引：`(card_id, user_id, idempotency_key)` 当 key 非空时。

PG 路径用 `jsonb`，MySQL/SQLite 用 `json`，PG 与 MySQL 两份 migration。

---

## 3. HTTP API 表面

### 3.1 routes.rb 增量

```ruby
resources :agents do
  scope module: :agents do
    resources :tokens, only: %i[ index create destroy ]
    resources :board_accesses, only: %i[ index create destroy ]
  end
end

resources :cards do
  scope module: :cards do
    resource :agent_completion, only: %i[ create ]
    # ... 既有 routes 不动
  end
end
```

### 3.2 Agents CRUD

#### `GET /:account_slug/agents`

列表，admin 可见。

```json
[
  {
    "id": "03f...",
    "name": "Code Review Bot",
    "slug": "code-review-bot",
    "email_address": "code-review-bot@agent.local",
    "webhook_url": "https://my-agent.example.com/jetkb",
    "all_access_boards": true,
    "permission": "write",
    "active": true,
    "created_at": "2026-05-14T10:30:00Z",
    "last_active_at": "2026-05-14T15:20:00Z",
    "assigned_cards_count": 3,
    "completed_cards_count": 27,
    "url": "http://app.../agents/03f..."
  }
]
```

#### `POST /:account_slug/agents`

admin 创建。同事务建 Identity + User + 首个 access token。

请求：

```json
{
  "agent": {
    "name": "Code Review Bot",
    "slug": "code-review-bot",
    "webhook_url": "https://my-agent.example.com/jetkb",
    "all_access_boards": true,
    "permission": "write"
  }
}
```

| 参数 | 必需 | 说明 |
|---|---|---|
| `name` | ✅ | 显示名 |
| `slug` | ✅ | 唯一，正则 `\A[a-z0-9]([a-z0-9-]*[a-z0-9])?\z`，长度 2-50 |
| `webhook_url` | ❌ | 可空（拉模式） |
| `all_access_boards` | ❌ | 缺省 true |
| `permission` | ❌ | `read`/`write`，缺省 `write` |

响应 `201 Created` + initial_token 字段（token 明文**仅此一次**返回）。

#### `GET/PATCH/DELETE /:account_slug/agents/:id`

PATCH 可改 `name`/`webhook_url`/`all_access_boards`，**不可改 `slug`**。DELETE 级联 destroy Identity + tokens + assignments；comments/events 默认保留，可加 `--hard` 选项硬删。

#### Token 管理

`POST/GET /:account_slug/agents/:id/tokens` 与 `DELETE /:account_slug/agents/:id/tokens/:token_id` 镜像 `/my/access_tokens`。

#### Board 授权

`POST/GET/DELETE /:account_slug/agents/:id/board_accesses`，仅在 `all_access_boards=false` 时生效。

### 3.3 Agent 自用端点

**完全复用既有 API**：

```bash
# 列派给自己的卡
GET /:account/cards?assignee_ids[]=<my-user-id>

# 详情
GET /:account/cards/:n

# 中间报告
POST /:account/cards/:n/comments
{ "comment": { "body": "<p>Started...</p>" } }

# 关闭/进列/分类...
POST /:account/cards/:n/closure
POST /:account/cards/:n/triage   { "column_id": "..." }
```

### 3.4 `POST /:account/cards/:n/agent_completion` —— 糖端点

agent 完成任务的统一入口，单事务原子写：comment + 状态变更 + 自分配解除 + event。

请求：

```json
{
  "agent_completion": {
    "result": "succeeded",
    "summary": "Analyzed PR, found 3 issues. Posted detailed comments on lines 42, 87, 102.",
    "details_html": "<p>Optional rich-text details...</p>",
    "outcome": "closed",
    "artifacts": [
      { "label": "PR comment", "url": "https://github.com/org/repo/pull/123#discussion_r456" }
    ],
    "metrics": {
      "duration_ms": 18420,
      "tokens_used": 12500,
      "cost_usd": 0.34
    }
  }
}
```

| 字段 | 必需 | 说明 |
|---|---|---|
| `result` | ✅ | `succeeded`/`failed`/`cancelled`/`needs_human` |
| `summary` | ✅ | 单行摘要，进 comment body |
| `details_html` | ❌ | rich text，进 comment 展开块 |
| `outcome` | ❌ | `closed`/`triaged:<column_id>`/`not_now`/`none`，缺省由 `result` 推导 |
| `artifacts` | ❌ | 链接数组，≤10 |
| `metrics` | ❌ | 任意 JSON，存入 event.particulars |

**幂等性**：请求头 `Idempotency-Key: <uuid>`，与 `(card_id, agent_id, key)` 唯一索引绑定。

**权限**：仅 `Current.user.agent?` 且 `card.assigned_to?(Current.user)` 时通过；否则 403。

服务端事务：

```
BEGIN
  comments.create!(creator: agent, body: <rendered>)
  case outcome:
    when "closed"      → card.close(closer: agent)
    when /^triaged:/   → card.triage_into(column, by: agent)
    when "not_now"     → card.postpone(by: agent)
    when "none"        → 不改状态
  card.assignments.destroy_by(assignee: agent)
  Event.create!(action: "card_agent_completed", creator: agent,
                eventable: card, particulars: {...})
COMMIT
```

响应：

```json
{
  "id": "03f...",
  "card_number": 42,
  "result": "succeeded",
  "outcome": "closed",
  "comment_id": "03f...",
  "event_id": "03f...",
  "created_at": "2026-05-14T15:30:00Z"
}
```

### 3.5 既有端点的微调

| 端点 | 改动 | 原因 |
|---|---|---|
| `POST /cards/:n/assignments` | 0 | 既有逻辑对 agent user 透明 |
| `GET /cards` JSON | `creator.is_agent` / `assignees[].is_agent` 字段 | UI 区分 |
| `card_assigned` webhook | assignee 是 agent 时并发 `card_assigned_to_agent` | 精确订阅 |
| `Comment.by_user` | 0 | agent.role != system，天然包含 |

### 3.6 错误响应

| 状态 | 场景 |
|---|---|
| 401 | 缺/无效 Bearer token |
| 403 | 角色不符；agent 不是 assignee |
| 404 | 资源不存在或不可见（跨账号不泄漏存在性）|
| 422 | slug 冲突/格式错；webhook_url 非法；派单到 agent 看不到的板 |
| 429 | 速率限制 |

### 3.7 速率限制

- `POST /cards/:n/agent_completion`：60/min/agent，5000/day/agent
- `POST /agents`：10/h/admin-identity
- `POST /agents/:id/tokens`：20/day/agent
- 其他端点：跟随上游

实现：`rack-attack` + `config/initializers/jetkb_rate_limits.rb`（**新文件**，零冲突）。

### 3.8 文档

- `docs/api/sections/agents.md` 新增
- `docs/api/README.md` 目录加链接
- OpenAPI 暂不做（YAGNI），手写 Markdown 与现有 API doc 同风格

---

## 4. CLI + MCP 设计

### 4.1 仓库：`jetkb-cli`，pnpm workspace

```
jetkb-cli/
├── packages/
│   ├── core/      # @jetkb/core      共享 HTTP 客户端
│   ├── cli/       # @jetkb/cli       命令 `jetkb`
│   └── mcp/       # @jetkb/mcp       命令 `jetkb-mcp`
├── apps/e2e/      # docker-compose 拉 jetKB 镜像 + 跨栈测试
└── .github/workflows/{ci,release}.yml
```

**为什么独立仓**：发布节奏与 Rails 解耦；语言生态隔离；npm 安装路径自然；版本号独立。

### 4.2 `@jetkb/core` 客户端 SDK

```typescript
const client = new JetkbClient({
  baseUrl: "https://app.jetkb.example.com",
  accountSlug: "1234567",
  token: process.env.JETKB_TOKEN,
});

await client.cards.list({ assigneeIds: ["me"], indexedBy: "all" });
await client.cards.update(42, { title: "Updated" });
await client.cards.agentCompletion.create(42, {
  result: "succeeded", summary: "Done.", outcome: "closed",
});
```

要点：

- HTTP 用 `undici`（Node 内置，零依赖），fallback 到 `fetch`（Workers/Deno/Bun 兼容）
- 类型从 `docs/api/sections/*.md` 手维护到 `types.ts`，不做代码生成
- ETag 自动管理（LRU + If-None-Match → 304 透明返回）
- 列表方法返回 `AsyncIterableIterator`，自动翻 `Link: rel=next`
- 错误层级：`JetkbApiError`（4xx/5xx）/ `JetkbNetworkError` / `JetkbAuthError`
- 429 自动指数退避，最多 3 次
- 工具函数 `verifyWebhookSignature(body, signature, timestamp, secret, maxAgeSeconds)`

### 4.3 鉴权解析顺序

1. 显式 `token` 选项
2. `JETKB_TOKEN` 环境变量
3. `~/.config/jetkb/config.toml` 的 `default_profile`
4. `--profile <name>` 显式切换
5. macOS Keychain（P2 可选）

配置文件：

```toml
default_profile = "personal"

[profiles.personal]
base_url     = "https://app.jetkb.example.com"
account_slug = "1234567"
token        = "4f9Q6d2wXr8Kp1Ls0Vz3BnTa"

[profiles.work]
base_url     = "https://jetkb.mycompany.com"
account_slug = "9876543"
token_command = "op read 'op://Personal/jetkb-work/credential'"
```

`token_command` 通过 `child_process.execFile`（**不走 shell**，防注入）调外部命令拿 token，原生支持 1Password / Bitwarden / `pass` / `vault`。

CLI 启动检查 config 文件权限：mode != 600 给 warning。

### 4.4 `@jetkb/cli` 命令分组

仿 `gh` / `kubectl` 风格：

```
jetkb auth { login | logout | status | whoami }
jetkb config { list | get | set | unset | profiles }
jetkb cards { list | get | create | edit | close | reopen | triage |
              postpone | assign | unassign | tag | comment | watch |
              unwatch | pin | unpin | gild | ungild }
jetkb boards { list | get | create }
jetkb columns { list }
jetkb tags { list | create | delete }
jetkb agents { list | create | show | update | delete |
               token { rotate | list | delete } |
               board-access { add | list | remove } }
jetkb webhooks { list | create | delete | deliveries | test-signature }
jetkb me { identity | cards | notifications }
jetkb search <query>
jetkb open <number>
```

输出：默认 table；`--json` / `--yaml` / `--ndjson` 切换。

`jetkb auth login` 走 magic link 流，自动建 access token 并写入 config，零浏览器跳转。

`--debug` 全局 flag 打印每个 HTTP 请求/响应（token 自动脱敏前 4 + 后 4）。

### 4.5 `@jetkb/mcp` 工具集（中等粒度，14 个）

| Tool | 入参 | 含义 |
|---|---|---|
| `list_my_cards` | `status?`, `board_id?` | 派给我的卡（agent 默认）|
| `list_cards` | `assignee_ids?`, `board_ids?`, `tag_ids?`, `status?`, `query?`, `limit?` | 通用搜索 |
| `get_card` | `card_number` | 详情（含 column/tags/assignees/steps/最近评论）|
| `create_card` | `board_id`, `title`, `description?`, `tags?` | 新建 |
| `update_card` | `card_number`, `title?`, `description?`, `tags?` | 改属性 |
| `move_card` | `card_number`, `target` (column/closed/not_now/triage) | 状态机统一入口 |
| `comment_on_card` | `card_number`, `body_markdown` | Markdown 评论 |
| `assign_card` | `card_number`, `assignee` (email/slug/"me") | toggle |
| `tag_card` | `card_number`, `tag` | toggle |
| `complete_card_as_agent` | `card_number`, `result`, `summary`, `outcome?`, `artifacts?`, `metrics?` | 包装 agent_completion 端点 |
| `list_boards` | — | 我能看的所有板 |
| `list_columns` | `board_id` | 列 |
| `search` | `query`, `limit?` | 全文 |
| `get_my_identity` | — | 自我认知（人/agent + 权限）|

**特意不暴露**：webhooks CRUD / agents CRUD / token 操作 / 删卡片。危险/管理操作让人类用 CLI 做。

MCP resources（被 host 当上下文塞给 LLM）：

- `jetkb://card/<number>`
- `jetkb://board/<id>`
- `jetkb://my/inbox`

工具描述强制英文（LLM 友好），工具返回值透传服务端语言。

启动方式：

```bash
jetkb-mcp                       # stdio（Claude Desktop / Cursor 默认）
jetkb-mcp --transport http --port 3344  # SSE/HTTP（自托管平台）
```

### 4.6 分发渠道

| 渠道 | 阶段 |
|---|---|
| npm / npx | P0 |
| Homebrew tap | P2 |
| 单二进制（macOS/Linux/Windows） | P2 |
| Docker image `ghcr.io/<org>/jetkb-mcp` | P2 |

### 4.7 版本号策略

- `@jetkb/core` 跟随服务端 API 主版本
- 客户端启动握手读 `X-JetKB-Api-Version` 响应头，不兼容时 warning
- 请求带 `Accept: application/json; version=1`，预留多版本能力

### 4.8 i18n

- CLI 输出：默认英文，`JETKB_LANG=zh-CN` 切中文（用 `i18next`）
- MCP 工具描述：强制英文
- MCP 返回的卡片内容：透传服务端语言

---

## 5. 安全、鉴权、ACL、限流

### 5.1 威胁模型

| # | 威胁 | 缓解 |
|---|---|---|
| 1 | Agent token 泄漏 | 短期 + 轮转 + 一次显示 + 配置不入 git |
| 2 | Agent 越权访问 | `accessible_*` 查询走既有 ACL；agent 默认仅 all_access 板 |
| 3 | Webhook 中间人重放 | HMAC + timestamp + replay window |
| 4 | Webhook URL SSRF | 复用 `SsrfProtection`；投递时再次校验 IP |
| 5 | Agent 假装是人/反之 | role 持久化 + UI 显式徽标 + slug 全局唯一 |
| 6 | agent_completion 恶意重放 | Idempotency-Key + 仅 assignee + 限流 |
| 7 | 客户端 log 泄漏 token | core 统一脱敏；`--debug` 也 redact |
| 8 | 跨账号串扰 | URL 含 slug + `Current.account` 强校验 |
| 9 | 假冒 CLI 钓鱼 | login 显示 host 二次确认；只信任官方分发 |
| 10 | Comment XSS | ActionText sanitizer + agent_completion 字段一律走 sanitizer |

### 5.2 Token 生命周期

- 一个 agent 一个 Identity，N 个 token（零停机轮转）
- 创建时返回明文 1 次；DB 存原始（沿用上游 `has_secure_token`，24 位 base58）
- range 仅 `read`/`write`，**不做 per-board scope**（YAGNI；用 Access 表替代）
- 推荐轮转流程文档化（`jetkb agents token rotate` 命令）

### 5.3 授权矩阵

| 操作 | owner | admin | member | agent | 匿名 |
|---|---|---|---|---|---|
| 列/看/CRUD agents | ✅ | ✅ | ❌ | ❌ | ❌ |
| 旋转 agent token | ✅ | ✅ | ❌ | ❌（不能旋自己）| ❌ |
| 给 agent 授权板 | ✅ | ✅ | ❌ | ❌ | ❌ |
| 派任务给 agent | ✅ | ✅ | ✅ | ❌ | ❌ |
| `agent_completion` | ❌ | ❌ | ❌ | ✅（仅对自己派的卡）| ❌ |
| 在卡片评论/改状态 | ✅ | ✅ | ✅ | ✅（按既有规则）| ❌ |
| 删卡片 | creator/admin | creator/admin | creator | ❌ | ❌ |
| 设为 board creator | ✅ | ✅ | ✅ | ❌ | ❌ |
| 看 webhooks | ✅ | ✅ | ❌ | ❌ | ❌ |

关键 before_action：

```ruby
# AgentsController
before_action :ensure_admin

# Cards::AgentCompletionsController
before_action :ensure_agent
before_action :ensure_assigned_to_current_user
```

### 5.4 Webhook 签名

调用方验证范式：

```typescript
import { verifyWebhookSignature } from "@jetkb/core/webhooks";

app.post("/jetkb-webhook", express.raw({ type: "application/json" }), (req, res) => {
  const ok = verifyWebhookSignature({
    body: req.body,
    signatureHeader: req.headers["x-webhook-signature"] as string,
    timestampHeader: req.headers["x-webhook-timestamp"] as string,
    secret: process.env.JETKB_WEBHOOK_SECRET!,
    maxAgeSeconds: 300,
  });
  if (!ok) return res.status(401).end();
  // 处理...
});
```

**向上游 PR 候选**：签名算法升级为 `HMAC-SHA256(secret, timestamp + "." + body)`，header 携带版本：

```
X-Webhook-Signature: t=1715680800,v1=abc123...
```

### 5.5 SSRF

agent.webhook_url 必须走既有 `SsrfProtection`：

- 协议白名单：`https`（默认）+ `http`（开发模式/私网内显式开关）
- 拒绝私网 IP / `localhost` / `file://`
- 投递时再次解析 IP 防 DNS rebinding

### 5.6 身份分离

数据层：`User.role == "agent"` 持久化；所有 Event/Comment 创作权属可追溯。

表现层：

- 头像左下角 🤖 角标
- 用户卡片 `kind: Agent` 标签
- @mention 候选**排除** agent
- 卡片 assignee 列表上 agent 徽章颜色不同
- Webhook payload 始终带 `is_agent`

防混淆：

- slug 全局唯一
- agent 不能被设为 board creator
- agent 不能旋转自己的 token

审计端点：`GET /:account/agents/:id/activities` 列 agent 全部事件。

### 5.7 限流

- `POST /cards/:n/agent_completion`：60/min/agent，5000/day/agent
- `POST /agents`：10/h/admin-identity
- `POST /agents/:id/tokens`：20/day/agent
- 其他端点跟随上游

实现：`config/initializers/jetkb_rate_limits.rb`（新文件，rack-attack），超限返回 429 + `Retry-After`。

### 5.8 客户端侧 token 保护

| 来源 | 安全级别 |
|---|---|
| `--token` flag | ⚠️ 进 shell history，仅调试 |
| `JETKB_TOKEN` env | 中 |
| `~/.config/jetkb/config.toml` 明文 | 中（要求 chmod 600）|
| `token_command` | 高 |
| macOS Keychain（P2）| 高 |

token 统一脱敏（前 4 + 后 4）；`--debug` 输出走同一脱敏；单元测试覆盖"无完整 token 出现在错误消息里"。

### 5.9 数据保留

- agent DELETE：Identity + tokens + sessions 立即销毁；级联 assignments 清空；**默认保留 comments + events**，`--hard` 选项硬删
- agent webhook deliveries 30 天后清理（既有 cleanup job 覆盖）

### 5.10 多租户隔离回归

- `agent A` 用 X 账号 token 命中 Y URL → **404**（不是 403，避免泄漏存在性）
- agent A 看不到账号 X 未授权的板 → 404
- agent A `agent_completion` 关掉非自己的卡 → 403

### 5.11 文档

`docs/jetkb/agent-integration.md`：给 agent runner 实施者的最后一公里指南：

1. 创建 agent + 拿 token
2. 收 webhook 的 Express/Fastify/FastAPI 最小例子
3. 用 `@jetkb/core` 回写状态的代码示例
4. 推荐架构：webhook → 队列 → worker → LLM API → 回写
5. 安全清单（token 存储、签名验证、退避）
6. 监控建议

---

## 6. i18n / 品牌 / fork 隔离

### 6.1 上游文件改动清单（5 个文件，~25 行）

| 文件 | 改动 | 行数 | 标签 | PR 上游 |
|---|---|---|---|---|
| `user/role.rb` | +agent enum + scope + 谓词 | +6 | _无_ | ✅ |
| `webhook.rb` | +2 actions | +2 | _无_ | ✅ |
| `authorization.rb` | 改用 `api_active?` | 改 1 | `[jetkb]` | ⚠️ |
| `routes.rb` | +9 行新 namespace | +9 | _无_ | ❌ jetKB-only |
| `cards/_assignee.html.erb` | +3 渲染 is_agent | +3 | _无_ | ✅ |

### 6.2 上游 PR 战略

并行写、不等待上游：

- PR 1（上游友好）：role enum + webhook actions + is_agent
- PR 2（jetKB-only）：Agents 业务逻辑全集
- PR 3：CLI/MCP 独立仓首版

上游接受 → 下次 sync 时 rerere 自动消化对应改动；上游拒绝 → 继续持有，标 `[jetkb]`。

### 6.3 全新文件清单（零冲突）

```
app/controllers/agents_controller.rb
app/controllers/agents/{tokens,board_accesses}_controller.rb
app/controllers/cards/agent_completions_controller.rb
app/models/agent.rb
app/models/card/agent_completion.rb
app/models/card/agent_completable.rb
app/views/agents/...
app/views/cards/agent_completions/*.json.jbuilder
db/migrate/2026XXXX_create_card_agent_completions.rb
db/postgresql_migrate/2026XXXX_create_card_agent_completions.rb
config/initializers/jetkb_rate_limits.rb
config/initializers/jetkb_branding.rb
docs/api/sections/agents.md
docs/jetkb/{agent-integration,agent-architecture,agent-roadmap}.md
test/controllers/agents_controller_test.rb
test/controllers/agents/tokens_controller_test.rb
test/controllers/cards/agent_completions_controller_test.rb
test/integration/{agent_assign_complete_flow,agent_multi_tenant,agent_rate_limit}_test.rb
test/models/card/agent_completion_test.rb
test/fixtures/agents.yml
```

### 6.4 PG 适配器同步

- 新表 `card_agent_completions` 两份 migration
- PG 用 `jsonb`，MySQL/SQLite 用 `json`
- 刷新 `db/structure.sql`（PG）或 `db/schema.rb`（MySQL/SQLite），**不同时提交两份**

### 6.5 i18n key 命名空间

```yaml
en:
  agents:
    page_title: "Agents"
    new: "New agent"
    fields: { name, slug, webhook_url, all_access_boards, permission }
    validation: { slug_taken, slug_format }
    flash: { created, token_rotated, destroyed }
    list: { empty, assigned_count }
  cards:
    agent_completions:
      results: { succeeded, failed, cancelled, needs_human }
      comment_template_html: "..."
```

zh-CN.yml 镜像完整对应，`zh-CN:` 顶层只能出现一次（参 `MEMORY.md` 提醒）。

agent locale 存到 `user.settings` JSON 字段，复用既有机制（不加 DB 列）。

### 6.6 品牌

新建 `config/initializers/jetkb_branding.rb`：

```ruby
Rails.application.config.x.brand = ActiveSupport::OrderedOptions.new.tap do |b|
  b.name               = ENV.fetch("BRAND_NAME", "jetKB")
  b.short_name         = ENV.fetch("BRAND_SHORT_NAME", "jetKB")
  b.mailer_from        = ENV.fetch("MAILER_FROM", "noreply@jetkb.example.com")
  b.docs_url           = ENV.fetch("DOCS_URL", "https://docs.jetkb.example.com")
  b.support_email      = ENV.fetch("SUPPORT_EMAIL", "support@jetkb.example.com")
  b.cli_command        = "jetkb"
  b.npm_package_prefix = "@jetkb"
end
```

agent 合成邮箱故意用 `@agent.local`（品牌中立），不绑 jetKB 品牌。

CLI 命令名 / npm 包名故意叫 `jetkb` / `@jetkb/*`（不叫 `@fizzy/*`），因为这是 fork-first 的产物，与上游 Fizzy 是不同的工具集。

### 6.7 上游 sync 冲突点预测

`git rerere` 务必开启。常见冲突：

- `user/role.rb` enum 顺序
- `webhook.rb` PERMITTED_ACTIONS 数组
- `routes.rb` 新 namespace 上下文
- `authorization.rb` 热点文件

第一次手解，后续合并自动。

---

## 7. 测试策略

### 7.1 测试金字塔

```
                E2E (~10)
            Integration (~30)
       Controller / System (~60)
              Unit (~200)
        CLI/MCP unit (~150)
```

### 7.2 服务端单元（model 层）

- `test/models/user/role_test.rb`：agent role 合法性 / scope 严格性 / `agent?` / `api_active?` / admin? 防越权
- `test/models/account_test.rb` 追加：agent_users 不含 system_user / system_user 仍单例
- `test/models/card/agent_completion_test.rb`：单事务 / outcome 推导 / 幂等性 / 非 assignee 拒绝 / event 序列化 / artifacts 上限
- `test/models/webhook/signature_test.rb`：签名验证完整闭环（含 timestamp 防重放）
- `test/models/webhook/ssrf_test.rb`：agent.webhook_url 走同一 SSRF 防护

### 7.3 Controller

- `agents_controller_test.rb`：列/创建/PATCH/DELETE 全 happy + sad path；跨账号 404 不泄漏存在性
- `cards/agent_completions_controller_test.rb`：仅 agent + assignee 准入；Idempotency-Key 重放；outcome 行为；webhook 调度
- 既有 `cards_controller_test.rb` 追加：agent 视角 / JSON 输出 `is_agent` 字段

### 7.4 Integration

`agent_assign_complete_flow_test.rb` —— **核心闭环**：admin 建 agent → admin 派单 → 验 webhook fan-out → agent 回写 → 验状态/解除自分配/webhook 触发。

`agent_multi_tenant_test.rb`、`agent_rate_limit_test.rb`：5.10 / 5.7 用例。

### 7.5 System (Capybara)

- `agents_management_test.rb`：UI 流（创建/复制 token/删除）
- `agent_completion_render_test.rb`：评论渲染 / artifacts 链接 / sanitizer / metrics 不展示

### 7.6 CLI / MCP

`@jetkb/core` 单测（jest + nock）：翻页 / ETag / 401 / 429 退避 / token 脱敏 / 签名验证。

`@jetkb/cli` 命令测试：输出格式 / `auth login` mock 流 / 配置文件权限 warning / `token_command` 外部进程 / 错误退出码标准化。

`@jetkb/mcp`：14 工具列表 / call_tool 行为 / input schema 校验 / token 未配置时清晰错误。

### 7.7 E2E（跨栈）

`jetkb-cli/apps/e2e/`：

```bash
docker-compose -f apps/e2e/docker-compose.yml up -d
pnpm --filter e2e test
```

场景清单：

1. 完整闭环（创建 agent → 派单 → agent runner 收 webhook → SDK 回写 → 验状态）
2. MCP 直接调（stdio + tools/call）
3. token 轮转
4. 多 profile 切换
5. 错误体验
6. 签名验证

### 7.8 限流 / 性能

- 限流测试用注入的 clock（时间冻结），不真等 60s
- 性能（webhook fan-out / agent_completion p95）排到 P2，不阻塞首发

### 7.9 CI

- 主仓：`bin/ci` 不动，新测试自动跑
- `jetkb-cli`：node 矩阵 18/20/22 + e2e
- DB 矩阵：MySQL + PG 都跑 agent 测试集

### 7.10 手动 QA 清单

`docs/jetkb/agent-qa-checklist.md`：

1. UI 建 agent → 复制 token → 配 Claude Desktop MCP
2. `@jetkb://my/inbox` 看派给自己的卡
3. 让 Claude 调 `complete_card_as_agent`，验 timeline 渲染
4. CLI shell 用法：`jetkb cards list --indexed-by stalled --json | jq`
5. 1Password CLI 测 `token_command`
6. 受限板派给只能看公开板的 agent → 验 422
7. 错签名 webhook → agent runner 拒收
8. `--debug` 验 token 脱敏
9. `LANG=zh-CN` 验中文
10. 删 agent 后 timeline 评论/事件保留

### 7.11 上线门禁

| 阶段 | 必须通过 |
|---|---|
| P0 内测 | 7.2-7.6 全套 + E2E 完整闭环 1 个 |
| P1 公测 | 上 + 多租户 + 限流 + ≥5 个 E2E + 安全清单逐项 |
| P2 GA | 上 + 性能 baseline + 手动 QA + Homebrew/二进制 + 跨仓 CI |

---

## 8. 实施计划

### 8.1 阶段总览（Claude Code 加速节奏）

| 周 | 服务端 | CLI/MCP | 验收 |
|---|---|---|---|
| W1 | PR-1（基础 enum）+ PR-2 + PR-3（迁移）+ PR-7（限流）| CLI-1 + CLI-2 | PR-1 合入，下游解锁 |
| W2 | PR-4（Agents CRUD）+ PR-5（agent_completion）+ PR-6（webhook fan-out）+ PR-8（i18n）| CLI-3（core 全集）+ CLI-4（CLI 命令）| 服务端 + CLI core 单测 |
| W3 | PR-9（测试集后半）+ PR-10（文档）| CLI-5（MCP）+ CLI-6（E2E）+ CLI-7（npm 0.1.0）| **P0 完成**：闭环跑通 |
| W4 | 签名补强 + 多租户/限流测 + 审计端点 | 错误体验 + `token_command` + MCP resources + 文档站 | **P1 公测** |
| W5 | 性能 baseline + 上游 PR 跟进 | Homebrew + 单二进制 + Docker | **P2 GA candidate** |

**~5 周到 GA candidate**，瓶颈是 PR review 深度 + E2E 信号充分性。

### 8.2 服务端 PR 拆分

| PR | 内容 | 上游友好 |
|---|---|---|
| PR-1 | role enum + scope + 谓词 + webhook actions + is_agent | ✅ 同时发上游 |
| PR-2 | `authorization.rb` 改用 `api_active?` | ⚠️ |
| PR-3 | `card_agent_completions` 迁移（MySQL + PG）+ 模型 | ❌ |
| PR-4 | `AgentsController` + tokens + board_accesses + JSON views + routes | ❌ |
| PR-5 | `Cards::AgentCompletionsController` + service model + JSON view | ❌ |
| PR-6 | Webhook 派发：card_assigned 时 fan-out agent action；agent_completed | ❌ |
| PR-7 | `jetkb_rate_limits.rb` + rack-attack gem | ❌ |
| PR-8 | i18n key + zh-CN.yml + 品牌 initializer | ⚠️ 抽 key 部分可 PR |
| PR-9 | 测试集（7.2-7.4） | ❌ |
| PR-10 | API doc + jetKB doc | ❌ |

### 8.3 CLI/MCP PR 拆分

| PR | 内容 |
|---|---|
| CLI-1 | 仓库 + pnpm workspace + tsconfig + lint + CI |
| CLI-2 | `@jetkb/core` 基础：JetkbClient + 鉴权 + cards/boards/columns |
| CLI-3 | `@jetkb/core` 补：comments/assignments/agents/agent_completion/webhooks |
| CLI-4 | `@jetkb/cli` 最小命令：auth + cards + agents |
| CLI-5 | `@jetkb/mcp` 14 工具 + Claude Desktop 配置文档 |
| CLI-6 | E2E + docker-compose |
| CLI-7 | npm publish workflow + changeset + 0.1.0 |

### 8.4 第一个 PR（PR-1）样子

```
# 提交 1（无前缀，候选上游）
M  app/models/user/role.rb            # +6
M  app/models/webhook.rb              # +2
M  app/views/users/_user.json.jbuilder  # +1（is_agent）
A  test/models/user/role_test.rb
M  test/models/webhook_test.rb

# 提交 2（[jetkb]）
M  app/controllers/concerns/authorization.rb  # 改 1
M  test/integration/agent_api_access_test.rb

# 提交 3（[brand]）
A  config/initializers/jetkb_branding.rb
M  config/locales/en.yml
M  config/locales/zh-CN.yml
```

### 8.5 风险登记

| # | 风险 | 概率 | 影响 | 对策 |
|---|---|---|---|---|
| R1 | 上游改 User::Role 顺序 → enum 错位 | 低 | 高 | 严格末尾追加 + CI 守卫 `assert_equal 4, User.roles["agent"]` + rerere |
| R2 | 上游改 webhook 投递接口 → 我们的 timestamp 签名分叉 | 中 | 中 | 优先 PR 上游；客户端工具自带不依赖上游接口 |
| R3 | MCP SDK 大版本破坏协议 | 中 | 中 | 集成测试覆盖 + 锁定主版本 |
| R4 | Idempotency 表无限增长 | 中 | 低 | cleanup job 30 天 TTL |
| R5 | agent token 泄漏 | 中 | 高 | 5.x 设计 + 401 告警 |
| R6 | 用户 webhook URL 大量超时堵队列 | 中 | 中 | 沿用上游重试 + 死信策略 |
| R7 | rack-attack 与上游既有限流冲突 | 低 | 中 | 实现前 grep 确认 |
| R8 | `token_command` shell 注入 | 低 | 高 | `execFile` 不走 shell |
| R9 | PG/MySQL schema 分叉 | 中 | 高 | 两份 migration + 矩阵 CI |
| R10 | 大账号 agent 视角查询慢 | 中 | 中 | P2 baseline + 按需加索引 |

### 8.6 回滚策略

- 每个 PR 独立可 revert
- PR-6 后若 webhook fan-out 出问题：临时 `WEBHOOK_AGENT_ACTIONS_DISABLED=1` env 让 dispatcher 跳过新 action
- 极端：反向 revert PR-10 → PR-1 + 删表，不影响人类用户数据
- 客户端 npm 已发版仅 deprecate，不删除

### 8.7 灰度

不引入 feature flag —— **创建第一个 agent 之前**新路径不被触发；admin 显式建 agent 自带灰度。

### 8.8 上线后监控

- 服务端：`card_assigned_to_agent` 与 `card_agent_completed` 日计数；agent 401 比率；agent_completion p95/p99
- 客户端：npm 下载量；GitHub issues/discussions 频率；MCP host 兼容性反馈

### 8.9 范围之外（明确划界）

不在本设计：

- LLM API 调用、prompt 工程、token 计费 → agent runner 的责任
- agent 间通信 / multi-agent 编排
- 卡片自动生成 / 自动派单的 AI 看板助手
- per-board token scope
- 复杂 SLA / on-call 告警
- 多账号同 agent 的 UI 管理（数据层支持，首版 UI 一次管一个）

将来要做这些，重新发起设计文档。

---

## 附录 A：术语表

| 词 | 含义 |
|---|---|
| **agent** | role 为 `agent` 的 User，可被分配卡片，用 access token 操作 API |
| **agent runner** | 真正执行 agent 工作的进程，用户自部署，不在 jetKB 内 |
| **agent_completion** | agent 报告完成的糖端点，原子写 comment + 状态 + event |
| **system user** | role 为 `system` 的 User，每账号 1 个，代表 jetKB 自己说话 |
| **idempotency key** | 客户端生成的 UUID，让 agent_completion 重试安全 |
| **all_access board** | 账号所有 active user（含 agent）默认可见的板 |

## 附录 B：参考

- 既有 API 文档：`docs/api/`
- 多租户实现：`config/application.rb` 的 `AccountSlug::Extractor`
- 鉴权实现：`app/controllers/concerns/authentication.rb`
- 既有 webhook 模型：`app/models/webhook.rb`
- fork 纪律：`CLAUDE.md`
- Ruby 风格：`STYLE.md`
- 上游项目说明：`AGENTS.md`
