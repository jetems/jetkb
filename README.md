# jetKB

**jetKB** 是 37signals 出品的看板式任务管理工具 [Fizzy](https://github.com/basecamp/fizzy) 的中文化分支版本。

我们以最小改动量同步上游代码，在其之上覆盖一层完整的简体中文翻译、CJK 全文检索支持，以及一个可选的 PostgreSQL 18+ 数据库适配层。

> 上游英文文档与开发者指南请见 [`AGENTS.md`](AGENTS.md)、[`STYLE.md`](STYLE.md) 与 [`docs/`](docs/) 目录；这些文件保持与上游一致，**不在本分支二次编辑**。

---

## 与 Fizzy 的关系

- **上游**：[`basecamp/fizzy`](https://github.com/basecamp/fizzy) — 所有应用核心逻辑、看板/卡片/通知/Webhook 模型、Solid Queue/Cable/Cache、Kamal 部署体系均来源于此，我们定期同步。
- **本仓库**：`jetems/jetkb` — 承担"翻译 + 品牌 + 数据库扩展 + Agent 集成"四类增量，绝不重命名内部类名、表名、CSS 前缀，以最大限度减少未来合并冲突。

详细的分支策略与合并约定见 [`CLAUDE.md`](CLAUDE.md)。

---

## 主要增量功能

### 1. 全量简体中文界面

- **认证 & 注册**：登录、邮箱魔法链接、注册、邮箱变更、退出账号
- **看板视图**：看板列表、列管理、卡片创建/编辑/评论/标签/分配人/步骤、筛选条件
- **个人中心**：菜单、账号设置、个人资料、Passkeys、API 令牌、导入导出、加入码
- **通知系统**：通知中心、桌面/移动推送、邮件通知、退订页、各浏览器/系统的开启指引
- **邮件模板**：魔法链接、通知摘要、邀请、文本版邮件
- **欢迎引导**：登录后弹出的 Welcome Letter 已重写为操作指引（去除 37signals 品牌信息，替换为 jetKB 上手步骤）
- **Lexxy 富文本编辑器**：通过 Stimulus + MutationObserver 在运行时改写工具栏 tooltip、下拉菜单、表格控制面板和动态"X 行/X 列"文本（上游硬编码英文，未提供 i18n hook）
- **前端动态文本**：JS 相对时间（`刚刚` / `3 分钟前`）、筛选标签、活动时间线动词、系统评论、邮件频率选择器

实现机制：

- `config/initializers/jetkb_i18n.rb` — 默认 locale 设为 `zh-CN`，回退到 `en`；测试环境保持 `en` 以避免影响 fixtures
- `config/locales/zh-CN.yml` — 翻译主文件
- `app/javascript/controllers/lexxy_i18n_controller.js` — Lexxy 编辑器运行时翻译控制器
- `app/javascript/local-time/zh-CN.js` — 中文相对时间

### 2. CJK 全文检索

上游搜索使用 ASCII-only 的 `\w` 字符类和 Snowball 词干器，会在分词前直接抹掉所有中文字符，导致中文卡片无法被搜索到。本分支对检索管线进行了 Unicode 化改造：

- **`app/models/search/query.rb`** — 用 `\p{L}\p{N}` 替换 ASCII `\w`，保留 CJK / 带重音的拉丁字母进入分词器
- **`app/models/search/stemmer.rb`** — 检测 Han / Hiragana / Katakana / Hangul 字符段，对每段中文文本进行**二元（bigram）分词**（"深圳公司" → `深圳`、`圳公`、`公司`），与全文索引一致；英文部分继续走原 Snowball stemmer
- 同时兼容 MySQL/Trilogy、SQLite 和 PostgreSQL 三套搜索后端

### 3. PostgreSQL 18+ 数据库适配（可选）

上游官方仅支持 MySQL（SaaS）与 SQLite（OSS 单机），本分支额外提供 PostgreSQL 路径，便于使用 PG 原生 `tsvector` + GIN 索引、native UUID 类型以及更强的 SQL 生态。

- **激活方式**：`bundle config set --local with postgresql` 安装 `pg` gem，运行时设置 `DATABASE_ADAPTER=postgresql`
- **隔离设计**：PG 专属文件全部放在独立路径，未激活时对 MySQL/SQLite 行为零影响
  - `config/database.postgresql.yml`
  - `db/postgresql_migrate/*.rb`（独立目录，避免被 SQLite/MySQL 的 migrator 拾取）
  - `app/models/search/record/postgresql.rb`（tsvector + GIN + Ruby 端 Highlighter）
- **跨适配层小改动**：UUID 类型按适配器分发（base36 vs 原生 UUID）、`date_subtract` 增加 PG 实现、`maximum(:id)` 改用 ORDER + PICK（PG 无 `MAX(uuid)`）
- **运维文档**：[`docs/jetkb-postgresql.md`](docs/jetkb-postgresql.md)（操作员视角）与 [`docs/jetkb-postgresql-roadmap.md`](docs/jetkb-postgresql-roadmap.md)（设计动机）

### 4. jetKB 品牌

通过 `config/initializers/jetkb_branding.rb` 暴露 `JetKB::Brand::APP_NAME`、`SUPPORT_EMAIL`、`MARKETING_URL`、`DOMAIN`、`COMPANY` 五个常量，所有视图、邮件、配置统一引用，重新换皮只需改这一个文件或对应环境变量。

- Logo、PWA Manifest、Header 已替换为 jetKB 资源
- 默认邮件发件人：`jetKB <support@jetkb.com>`（可由 `MAILER_FROM_ADDRESS` 环境变量覆盖）
- 本地开发域名：`app.jetkb.localhost:3006`

> 内部类名、模块名、CSS 前缀（如 `fizzy-`）、Ruby 文件路径**有意保留为 Fizzy 原名**，仅替换用户可见的品牌字串。这是降低上游合并冲突的关键策略。

### 5. Agent 集成（CLI + MCP + 派单回写闭环）

把卡片当成"任务"派给 AI agent，agent 通过 webhook 收到触发后自主执行，再用专用端点原子化回写完成状态。本分支以最小侵入在 Fizzy 的既有抽象（Assignment / Event / Webhook / AccessToken）之上加薄层，**不引入 LLM 调用** —— agent runner 的实现由用户自行部署，jetKB 只暴露"派单 + 回写"的钩子。

**服务端能力（本仓）**：

- **新增 `agent` 用户角色**：`User::Role` 末尾追加 `:agent`，与 `system` 并列但语义不同（agent 可被派任务、可登录 API；system 仅代表系统消息）。新增 `User.agent` / `User.api_active` scope 与 `agent?` / `api_active?` 谓词
- **`/agents` REST namespace**：`AgentsController` CRUD + `Agents::TokensController`（轮换 token）+ `Agents::BoardAccessesController`（受限板授权）。admin 专属，agent 自己看不到自己也不能改自己 token —— 防越权
- **`AgentSetting` 模型**：sidecar 表存 `webhook_url` + `all_access_boards`，与 `User::Settings`（人类通知偏好）隔离
- **`POST /:account/cards/:n/agent_completion` 糖端点**：单事务原子写"评论 + 状态变更（close/triage/postpone/none）+ 解除自分配 + 事件"。请求头 `Idempotency-Key` 自动去重（持久化在 `card_agent_completions` 表）。详细字段：`result` / `summary` / `details_html`（自动 sanitize）/ `outcome` / `artifacts[]` / `metrics{}`
- **Webhook fan-out**：派单给 agent 时除既有 `card_assigned` 外**并发触发** `card_assigned_to_agent`；agent_completion 触发 `card_agent_completed`。订阅方可精确路由
- **限流**：`rack-attack` 对 agent_completion（60/min, 5000/day）、agent 创建（10/h）、token 轮换（20/day）按 token 哈希分桶
- **`is_agent` 字段**：User JSON 序列化器输出布尔值，前端 / 客户端可区分人 / agent

**fork 隔离纪律**：6 个上游文件 ~30 行改动，其余全部新文件。详细映射见 [`docs/jetkb/agent-architecture.md`](docs/jetkb/agent-architecture.md)。

**配套客户端（独立仓 [`jetems/jetkb-cli`](https://github.com/jetems/jetkb-cli)）**：

| 包 | 命令 | 用途 |
|---|---|---|
| `@jetkb/core` | — | TypeScript HTTP 客户端 SDK，含 ETag 缓存、async 分页、webhook 签名验证 |
| `@jetkb/cli` | `jetkb` | 终端命令行，覆盖 cards（18 条子命令）/ agents / auth / config |
| `@jetkb/mcp` | `jetkb-mcp` | Model Context Protocol server，14 个中等粒度工具 + 3 个 MCP resource，可在 Claude Desktop / Cursor / Cline 中直接挂载使用 |

**关键文档**：

- [`docs/api/sections/agents.md`](docs/api/sections/agents.md) —— Agents + agent_completion HTTP API 完整参考
- [`docs/jetkb/agent-integration.md`](docs/jetkb/agent-integration.md) —— 给 agent runner 开发者的实施指南（含签名校验、退避、监控建议）
- [`docs/jetkb/agent-architecture.md`](docs/jetkb/agent-architecture.md) —— 维护者视角的内部架构说明
- [`docs/jetkb/agent-qa-checklist.md`](docs/jetkb/agent-qa-checklist.md) —— 发版前手动验证清单

---

## 快速开始

### 本地开发（SQLite，开箱即用）

```bash
bin/setup        # 安装 gem、建库、加载 schema
bin/dev          # 启动开发服务器
```

访问 http://app.jetkb.localhost:3006 ，登录邮箱 `david@example.com`，魔法链接会打印在 Rails console。

### 启用 PostgreSQL

```bash
bundle config set --local with postgresql
bundle install
DATABASE_ADAPTER=postgresql bin/rails db:setup
DATABASE_ADAPTER=postgresql bin/dev
```

详情见 [`docs/jetkb-postgresql.md`](docs/jetkb-postgresql.md)。

### 测试

```bash
bin/rails test            # 单元 + 集成测试
bin/rails test:system     # 系统测试（Capybara + Selenium）
bin/ci                    # 完整 CI（Rubocop / Brakeman / 测试套件）
```

### 部署

复用上游的 Kamal 流程，环境变量 `DATABASE_ADAPTER`、`JETKB_*`、`MAILER_FROM_ADDRESS` 用于切换数据库与品牌信息。具体见 [`docs/kamal-deployment.md`](docs/kamal-deployment.md)（上游文档）与 [`CLAUDE.md`](CLAUDE.md)。

---

## 协议

源代码遵循 [O'Saasy License](LICENSE.md)：**允许私有 / 内部使用**，**不允许将 jetKB 包装为与上游竞争的第三方 SaaS 对外提供**。

上游版权归 [37signals](https://37signals.com) 所有；本分支的中文化、PG 适配与品牌改动版权归 jetKB 维护者所有，按相同协议发布。
