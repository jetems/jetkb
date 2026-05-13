# PostgreSQL 支持改造清单（jetKB）

本文档列出把 jetKB（fizzy 上游）从 SQLite / MySQL（Trilogy）扩展到支持 PostgreSQL 18 所需的所有改动点。仅作为路线图与决策依据，不是已完成的工作。

> **重要**：上游 fizzy 不支持 PG，这是 jetKB 的 fork-only 工作；任何向上游 PR 的概率几乎为零。预计实现工作量 1–2 周（不含测试与中文分词），后续维护成本 = 每次 upstream sync 都要回归这条线。

---

## 一、可行性结论

**可行**。难点集中在两处：

1. **全文搜索** — `MATCH … AGAINST` 是 MySQL 专属，PG 用 `tsvector` + GIN（中文还需第三方分词扩展）。
2. **UUID 存储** — 现状是把 UUIDv7 编码成 Base36 字符串、序列化成 `binary(16)` / `blob(16)`。PG 应换用原生 `uuid` 列。

其它部分（迁移字符集、JSON 列、Solid Queue / Cache / Cable、Active Storage 等）PG 都已支持，改动量不大。

---

## 二、PostgreSQL 18 新特性的利用机会

PG 18（2025-09 GA）有几个特性对 jetKB 是真正的利好，**值得在改造时直接用上**，而不是先做兼容层再优化：

| 特性 | 在 jetKB 里的用法 |
|---|---|
| **原生 `uuidv7()` 函数** | 数据库端生成 UUIDv7，去掉 Ruby 端 `SecureRandom.uuid_v7` + Base36 编码这一整套（`lib/rails_ext/active_record_uuid_type.rb` 可以直接删掉）。索引/排序也更友好。 |
| **`uuidv7_to_timestamp()`** | 从 UUID 反解 created_at，对调试、归档脚本很有用。 |
| **虚拟生成列（virtual generated columns，STORED）** | `events.particulars` JSONB 里高频字段（`column`、`new_board` 等）可以做成 STORED 生成列直接加索引，省掉 `->>` 查询。 |
| **B-tree skip scan** | `search_records_*` 这种 `(account_key, content, title)` 复合索引，PG 18 之后即便只过滤 `account_key` 也能用上索引，不用专门再加单列索引。 |
| **Async I/O for seq scan** | 大账户做 `Account::Export` 时整表 dump 显著加速，需在 `postgresql.conf` 启用 `io_method = io_uring`（Linux）。 |
| **NOT VALID 外键 / CHECK** | 用于平滑迁移现有数据时，先 `NOT VALID` 添加约束跳过全表扫描，后台再 `VALIDATE CONSTRAINT`。 |
| **`OLD`/`NEW` 在 RETURNING 子句中** | Webhook 通知的差异计算可以在一条 SQL 内完成，无需 Ruby 层 `previous_changes`。 |

> 注意：依赖 PG 18 会把 jetKB-PG 的最低版本卡在 18，不向下兼容 PG 16/17。这是一个明确的设计选择 — fork 自己决定就好，没有上游约束。

---

## 三、Phase 0：基础设施

| 项 | 文件 | 改动 |
|---|---|---|
| 加 PG gem | `Gemfile` | 新增 `gem "pg", "~> 1.5"`，放在 sqlite3 旁边（不在 saas Gemfile 里） |
| 允许 `postgresql` 作为 adapter 名 | `lib/fizzy.rb` | `DbAdapter#postgresql?` 方法；保留 `sqlite?` |
| 新增数据库配置模板 | `config/database.postgresql.yml`（新建） | 镜像 mysql.yml 结构；adapter 用 `postgresql`；指定 `min_messages: warning`、`prepared_statements: true` |
| `database.yml` 入口分发 | `config/database.yml` | 已经按 `Fizzy.db_adapter` 动态选文件，无需改 |
| 环境变量 | docs / `.env.example` | 加 `DATABASE_ADAPTER=postgresql`、`POSTGRES_HOST/PORT/USER/PASSWORD/DB` |
| `bin/setup` | `bin/setup` | 检测 `DATABASE_ADAPTER=postgresql` 时调用 `createdb`，提示 PG 版本 ≥ 18 |
| CI 容器 | `.github/workflows/*.yml`（如果将来开 PG 矩阵） | 新增 `pg: 18` 服务，并跑 `DATABASE_ADAPTER=postgresql bin/ci` |

---

## 四、Phase 1：UUID 主键

现状（`lib/rails_ext/active_record_uuid_type.rb`、`config/initializers/uuid_primary_keys.rb`）：

- Ruby 端：`SecureRandom.uuid_v7` → 32 位 hex → Base36 25 字符
- DB 端：MySQL 存 `binary(16)`，SQLite 存 `blob(16)`
- Rails 端：自定义 `ActiveRecord::Type::Uuid < Binary` 处理序列化

PG 路线（推荐方案 A）：

### 方案 A — 用 PG 原生 `uuid` 列 + 服务器端生成（推荐）

| 项 | 改动 |
|---|---|
| `Uuid` Type 注册 | 新增 `ActiveRecord::Type.register(:uuid, ActiveRecord::Type::Uuid, adapter: :postgresql)` |
| `PostgresqlUuidAdapter` 模块 | 仿照 `SqliteUuidAdapter` / `MysqlUuidAdapter`，把 PG 原生 `uuid` 列识别成 jetKB 的 base36 字符串呈现层 |
| 主键 default | PG 端用 `DEFAULT uuidv7()`（PG 18 新增），Ruby 端 `PendingUuidDefault` 路径在 PG 时跳过 |
| Base36 编码 | **保留**，因为模型/路由/测试 fixture 大量依赖 25 字符 base36 字面量。`serialize` 时把 base36 转成 PG `uuid` 字符串，反之亦然 |
| Schema dumper | `SchemaDumperUuidType` 增加对 PG `uuid` sql_type 的识别 |
| 测试 fixture 的 deterministic UUID 生成 | 不受影响（fixture loader 走 Ruby 路径） |

### 方案 B — 保留 binary(16) 模式（不推荐）

PG 不支持 `binary(16)` 这种定长二进制；要用 `bytea` 自己加长度约束。理论可行但放弃了 PG 18 的 `uuidv7()` 红利，且与生态工具（`pg_uuidv7`、`uuid-ossp`、psql `\d`）互操作差。**除非有强兼容需求，否则用方案 A**。

---

## 五、Phase 2：全文搜索（最大的一块）

现状：

- `search_records_0` … `search_records_15` 共 16 个分片表，按账户哈希分布
- 每个分片有 `FULLTEXT INDEX (account_key, content, title)`
- 查询走 `MATCH(...) AGAINST(? IN BOOLEAN MODE)`，Ruby 端 `Search::Stemmer`（Mittens, Porter）做英文词干化
- SQLite 路径单独写了 `search_records_fts` FTS5 虚拟表

PG 路线：

### 5.1 表结构

| 项 | 改动 |
|---|---|
| 16 个分片表 | 保留，建表 DDL 在新 PG 迁移里重写，列同 MySQL |
| `tsvector` 生成列 | 新增 `search_vector tsvector GENERATED ALWAYS AS (to_tsvector('simple', coalesce(account_key,'') \|\| ' ' \|\| coalesce(title,'') \|\| ' ' \|\| coalesce(content,''))) STORED`。PG 18 的虚拟生成列还在试验阶段，**STORED** 是稳定选择 |
| GIN 索引 | `CREATE INDEX … USING gin (search_vector)` 替代 FULLTEXT |
| 中文分词 | 见 5.3 |

### 5.2 查询适配

新增 `app/models/search/record/postgresql.rb`，签名同 `trilogy.rb` / `sqlite.rb`：

```ruby
scope :matching, ->(query, account_id) do
  ts_query = "account#{account_id} & (#{Search::Stemmer.stem(query)})"
  where("search_vector @@ to_tsquery('simple', ?)", ts_query)
end

def self.search_fields(query)
  # ts_headline 替代 SQLite 的 highlight()
  [
    "ts_headline('simple', title, to_tsquery('simple', #{connection.quote(query.terms)}), 'StartSel=<mark>,StopSel=</mark>') AS result_title",
    "ts_headline('simple', content, to_tsquery('simple', #{connection.quote(query.terms)}), 'MaxFragments=2,StartSel=<mark>,StopSel=</mark>') AS result_content"
  ]
end
```

`Search::Record < ApplicationRecord` 的 `include const_get(connection.adapter_name)` 已经会按 adapter 自动选模块，命名空间叫 `PostgreSQL`（注意大小写）。

### 5.3 中文分词（重点）

PG 的 `simple` / `english` 文本搜索配置不分中文（按字节分），命中率会极差。需要扩展：

| 扩展 | 优势 | 劣势 |
|---|---|---|
| **`zhparser`** | 最成熟，社区广 | 编译安装，云厂商 RDS 支持不一 |
| **`pg_jieba`** | jieba 直接移植，分词质量好 | 内存占用大；多 Postgres 版本兼容性弱 |
| **`pgroonga`** | 多语言通杀，索引压缩好 | 学习成本高，运维独立 |

**推荐：阿里云/腾讯云 RDS 选 `zhparser`；自托管选 `pg_jieba`。**

在 `Search::Stemmer` 上加分支：

```ruby
def stem(value)
  if Fizzy.db_adapter.postgresql? && value.match?(/\p{Han}/)
    value # 让 PG 端分词器处理，Ruby 不干预
  else
    # 英文走 Porter（现状）
  end
end
```

并在迁移里 `CREATE TEXT SEARCH CONFIGURATION jetkb_chinese …` 把 `zhparser`/`pg_jieba` 串进去。

### 5.4 SQLite FTS 模块的去留

`app/models/search/record/sqlite.rb` 和 `app/models/search/record/sqlite/fts.rb` 保留不动 — SQLite 路径仍能跑，PG 是第三套并行实现。

---

## 六、Phase 3：迁移文件（migrations）

> 当前所有迁移都用 `charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci"`。这些选项对 PG 无意义，会报 unknown option 警告但不报错（Rails 适配器会忽略）。**最干净的做法是新写一份 PG 专用 squashed schema**，不动 MySQL/SQLite 历史迁移。

### 6.1 选项 A — 新增 PG-only squashed initial schema（推荐）

新增 `db/postgresql_migrate/00000000000000_initial_postgresql_schema.rb`，从当前 `db/schema.rb` 翻译成 PG 语法：

- `t.binary "id", limit: 16` → `t.uuid :id, default: -> { "uuidv7()" }`
- `t.json` → `t.jsonb`（性能更好，PG 标准做法）
- 去掉 `charset` / `collation` 参数
- `FULLTEXT` 索引 → `tsvector` 列 + GIN（见 Phase 2）

加载策略：

```ruby
# config/application.rb
config.paths["db/migrate"] = [ "db/postgresql_migrate" ] if Fizzy.db_adapter.postgresql?
```

并把 `db/postgresql_migrate/00000000000000` 之后的所有 PG 增量迁移单独维护一条线。

### 6.2 选项 B — 迁移文件里按 adapter 分支

每个迁移加 `if connection.adapter_name == "PostgreSQL"` 分支。**不推荐** —— 已有 130+ 迁移，逐个改成本极高且后续每个上游新迁移都得跟。

### 6.3 schema.rb 还是 structure.sql

切到 PG 后，`schema.rb` 会丢失 `tsvector` 生成列、GIN 索引、`zhparser` 配置等 PG-only 结构。强烈建议 PG adapter 时切到 `config.active_record.schema_format = :sql`，产出 `db/structure.sql`。

在 `config/application.rb` 加：

```ruby
config.active_record.schema_format = Fizzy.db_adapter.postgresql? ? :sql : :ruby
```

---

## 七、Phase 4：模型层零散适配

### 7.1 `app/models/board/accessible.rb`

`uuid_type = ActiveRecord::Type.lookup(:uuid, adapter: :trilogy)` — 写死了 `:trilogy`。改成按当前 adapter 查：

```ruby
uuid_type = ActiveRecord::Type.lookup(:uuid, adapter: connection.adapter_name.downcase.to_sym)
```

或更稳：把这段 raw SQL 改写成 ActiveRecord query（`where(events: { eventable_type: "Card", eventable: { board_id: id } })`），但工作量大。

### 7.2 `Account::DataTransfer`（导入/导出）

整套 zip 导入逻辑里有没有用到 MySQL-specific 行为？快速看：

- 没有 raw SQL，依赖 ActiveRecord 序列化 — **OK**
- 但 PG 的 `jsonb` 序列化和 MySQL `json` 顺序不同 — 导入导出之间跨 DB 类型不保证 byte-identical，**这一条要在 [[upstream-sync]] 文档里标注**

### 7.3 `app/models/search/record/sqlite/fts.rb`

```ruby
"INSERT OR REPLACE INTO search_records_fts(rowid, title, content) VALUES (?, ?, ?)"
```

SQLite 专用，PG 路径不会走到这里，无需改。

### 7.4 验证 `Solid Queue` / `Solid Cable` / `Solid Cache` 在 PG 下可用

三个 Solid gem 官方都支持 PG。`config/cable.yml`、`config/queue.yml`、`config/cache.yml` 都引用主连接，无需改。但 PG 18 的 `LISTEN/NOTIFY` 比 MySQL 的 polling 更高效 —— 可选优化 Solid Cable 的 backend。

---

## 八、Phase 5：测试

| 项 | 改动 |
|---|---|
| Fixture | UUID fixture 生成走 Ruby（fixture_set），不受影响 |
| 测试 DB | `bin/rails db:test:prepare` 在 PG 模式下要先 `CREATE DATABASE jetkb_test`；写一段 README |
| Parallel tests | PG 多个 worker DB 名 `jetkb_test_1`, `jetkb_test_2` — Rails 内置支持，无需改 |
| 全文搜索测试 | `test/models/search/` 下有 stemmer / matching 测试，跑在每个 adapter 下都要绿 |
| CI 矩阵 | `DATABASE_ADAPTER ∈ {sqlite, mysql, postgresql}` 三条并行 |

---

## 九、Phase 6：运维 & 部署

| 项 | 改动 |
|---|---|
| Kamal `deploy.jetkb.yml` | 新增 PG 服务条目（如 docker `postgres:18-alpine` 或外部 RDS） |
| 1Password / Secrets | PG 连接串、扩展安装权限 |
| Backup | `pg_dump --format=custom` 替代 `mysqldump` |
| Search 索引重建 | `SearchReindexJob`（已存在）在 PG 下要先 `CREATE EXTENSION zhparser` |
| 监控 | `pg_stat_statements` 替代 MySQL slow log |

---

## 十、需要决策的几个点

1. **PG 最低版本卡 18？** 还是兼容 16+？  
   — 推荐 **18+**，因为 `uuidv7()` 是杀手特性，否则 UUID 这块得保留 Ruby 端生成。

2. **中文分词扩展选哪个？**  
   — 自托管/开源用户：`pg_jieba`。SaaS 上云：跟着云厂商支持的扩展走（RDS 多支持 `zhparser`）。

3. **MySQL 路径是否长期保留？**  
   — 上游 fizzy SaaS 用的是 MySQL，下游 sync 时 MySQL 路径必须保留。**PG 是第三条并行路径，不替换任何东西。**

4. **`schema.rb` vs `structure.sql`？**  
   — PG adapter 切换到 `structure.sql`，其它 adapter 保持 `schema.rb`（运行时按 `Fizzy.db_adapter` 切换）。这是 Rails 支持的姿势。

5. **导入/导出跨 DB 是否支持？**  
   — 当前 MySQL ↔ SQLite 都没保证。**PG 加入后明确声明只支持同 adapter 内 export/import**，避免对外承诺。

---

## 十一、上游 sync 的影响

每次 `git merge upstream/main` 之后必须检查：

- `db/migrate/` 有新增迁移 → 在 `db/postgresql_migrate/` 写对应 PG 版本
- `app/models/search/` 有变更 → 同步到 `app/models/search/record/postgresql.rb`
- `lib/rails_ext/active_record_uuid_type.rb` 有改 → 同步 PG 注册
- `config/database.*.yml` 模板调整 → 同步到 `database.postgresql.yml`

为减少冲突，所有 PG-only 文件用 `_postgresql` 后缀或独立目录命名，不挤进上游已有文件。

---

## 十二、最小可跑路径（MVP）

如果只想先验证可行性、不做生产就绪：

1. Phase 0 全部
2. Phase 1 方案 A
3. Phase 3 选项 A 写一份 squashed initial schema（先去掉 search_records 16 张表，搜索功能暂时禁用）
4. 启动应用，跑 CRUD（看板、卡片、评论、通知、Webhook）

预计 2–3 天。这一步能让团队 review、给出 go/no-go 决策，再决定要不要投入 Phase 2 的全文搜索改造。

---

## 十三、不会被改动的部分

- 视图、控制器、Stimulus 控制器 — 全部 DB 无关
- i18n 翻译 — DB 无关
- Action Text / Active Storage / Solid 三件套 — Rails 官方 PG 支持
- 鉴权 / Magic link / Passkey — DB 无关
- 推送通知 / Service Worker — DB 无关
