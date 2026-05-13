# 在 PostgreSQL 18 上运行 jetKB

jetKB 支持三种数据库：SQLite（OSS 默认）、MySQL（SaaS 默认 / Trilogy）、PostgreSQL 18+（可选）。本文档讲怎么切到 PG。

> 改造路线图见 [`jetkb-postgresql-roadmap.md`](./jetkb-postgresql-roadmap.md)。

## 0. 先决条件

- PostgreSQL **18 或更高**。低于 18 也能跑，但拿不到 `uuidv7()` 服务端生成等红利。
- macOS 本机：`brew install postgresql@18 libpq && brew services start postgresql@18`
- Linux：用发行版包或官方 apt 仓库。
- 至少 200 MB 内存（小账户）。

## 1. 安装 PG gem

PG gem 在 Gemfile 里是**可选 group**，默认不装。一次性设置：

```bash
bundle config set --local with postgresql
bundle install
```

这样 `bundle install` 之后会拉 `pg ~> 1.5`。MySQL/SQLite 用户继续 `bundle install`，不会被强制装 libpq。

## 2. 创建数据库

```bash
createdb jetkb_development
createdb jetkb_test
# Solid Cable / Queue / Cache 用单独的库
createdb jetkb_development_cable
createdb jetkb_production_cable
createdb jetkb_production_queue
createdb jetkb_production_cache
```

如果你的 PG 用了别的用户名/密码：

```bash
export POSTGRES_HOST=127.0.0.1
export POSTGRES_PORT=5432
export POSTGRES_USER=jetkb
export POSTGRES_PASSWORD=...
export POSTGRES_DB=jetkb_development
export POSTGRES_TEST_DB=jetkb_test
```

## 3. 启动

```bash
export DATABASE_ADAPTER=postgresql
bin/setup
bin/dev
```

`DATABASE_ADAPTER` 是切换关键。第一次跑会：
- 跑 `db/postgresql_migrate/00000000000001_create_initial_schema.rb`（建 69 张表）
- 跑 `db/postgresql_migrate/00000000000002_add_search_vector_and_gin.rb`（建 16 个 search shard 的 GIN 索引）
- 把 schema dump 到 `db/structure.sql`（**不是** `schema.rb`，因为后者保不住 tsvector/GIN）

## 4. 验证

```bash
bin/rails console
```

```ruby
ActiveRecord::Base.connection.adapter_name  # => "PostgreSQL"
Account.create!(name: "Test")                # 应该正常返回带 base36 ID
Search::Record.connection.execute("SELECT typname FROM pg_type WHERE typname = 'tsvector'").to_a
```

## 5. 中文分词（可选但强烈推荐）

默认搜索配置 `jetkb_search` 是 PG 内置 `simple` 分词器（按空白分），对中文几乎无效。生产用户应该装一个中文 tokenizer 扩展：

### 选项 A — `zhparser`（推荐，云厂商支持好）

```bash
# 自托管
git clone https://github.com/amutu/zhparser.git
cd zhparser && make && make install
```

```sql
-- 数据库内
CREATE EXTENSION zhparser;

-- 把 jetkb_search 切到 zhparser
ALTER TEXT SEARCH CONFIGURATION jetkb_search
  ALTER MAPPING FOR n, v, a, i, e, l WITH simple;

-- 重建 16 个 GIN 索引
SELECT 'REINDEX INDEX search_records_' || g || '_search_gin;'
FROM generate_series(0, 15) g \gexec
```

### 选项 B — `pg_jieba`

```bash
git clone https://github.com/jaiminpan/pg_jieba.git
cd pg_jieba && cmake . && make && make install
```

```sql
CREATE EXTENSION pg_jieba;

ALTER TEXT SEARCH CONFIGURATION jetkb_search
  ALTER MAPPING FOR n, v, a, i, e, l WITH jieba;
```

### 阿里云 RDS / 腾讯云 CDB

两家都内置了 `zhparser`，直接 `CREATE EXTENSION` 后走选项 A 的 SQL 即可。

## 6. 切回 MySQL/SQLite

PG 配置是并行的，不会污染原路径：

```bash
unset DATABASE_ADAPTER  # 默认走 SQLite (OSS) 或 MySQL (SaaS)
bin/rails db:reset
```

应用启动时根据 `DATABASE_ADAPTER` 决定加载哪一套 schema：
- 不设 → SQLite（OSS）或 MySQL（`SAAS=1` 或有 `tmp/saas.txt`）
- `=postgresql` → PG 专用 schema + structure.sql

## 7. 部署到生产

`config/database.postgresql.yml` 已经按 primary / cable / queue / cache 切了 4 个库。Kamal 部署模板示例（自己加在 `config/deploy.jetkb.yml`，不要动 upstream 的 `config/deploy.yml`）：

```yaml
accessories:
  postgres:
    image: postgres:18-alpine
    host: <your-host>
    port: 5432
    env:
      clear:
        POSTGRES_USER: jetkb
        POSTGRES_DB: jetkb_production
      secret:
        - POSTGRES_PASSWORD
    files:
      - config/deploy/postgres/init.sql:/docker-entrypoint-initdb.d/init.sql
    directories:
      - data:/var/lib/postgresql/data

env:
  clear:
    DATABASE_ADAPTER: postgresql
    POSTGRES_HOST: jetkb-postgres
  secret:
    - POSTGRES_PASSWORD
```

`config/deploy/postgres/init.sql`：

```sql
CREATE DATABASE jetkb_production;
CREATE DATABASE jetkb_production_cable;
CREATE DATABASE jetkb_production_queue;
CREATE DATABASE jetkb_production_cache;

\c jetkb_production
CREATE EXTENSION zhparser;  -- 如装了中文分词
```

## 8. 备份

```bash
# 全量
pg_dump -Fc -h $POSTGRES_HOST -U $POSTGRES_USER jetkb_production > jetkb_$(date +%Y%m%d).dump

# 恢复
pg_restore -h $POSTGRES_HOST -U $POSTGRES_USER -d jetkb_production_new jetkb_20260513.dump
```

## 9. 已知限制

1. **导入导出不跨 adapter** — `Account::DataTransfer` 的 zip 文件在 MySQL/PG 之间不保证字节兼容（`json` vs `jsonb` 序列化顺序差异）。同一 adapter 内 export → import 没问题。
2. **`db/schema.rb` 在 PG 模式下不维护** — 改用 `db/structure.sql`。如果同一台机器在 PG 和 MySQL 之间来回切，`db:migrate` 各自维护自己那份 schema dump，**不要混淆提交**。
3. **搜索高亮 HTML 形态略有差异** — PG 的 `ts_headline` 用 `<mark>` 包裹高亮词，与 SQLite FTS5 的 `highlight()` 标记格式语义相同但产生时机不同。前端样式已经 cover 这两种。

## 10. 排错

| 现象 | 原因 | 解决 |
|---|---|---|
| `PG::ConnectionBad: could not connect to server` | PG 没启动 / 端口错 | `brew services start postgresql@18` 或检查 `POSTGRES_PORT` |
| `ActiveRecord::StatementInvalid: PG::UndefinedFunction: ERROR: function uuidv7() does not exist` | PG 版本 < 18 | 升级到 18，或在 migration 里用 `gen_random_uuid()` |
| `text search configuration "jetkb_search" does not exist` | Phase 2 迁移没跑 | `bin/rails db:migrate` |
| 中文搜索结果为空 | 用了默认 simple 分词器 | 见第 5 节装 zhparser/pg_jieba |
| `bundle install` 报 `pg` gem 缺失 | 没启用 optional group | `bundle config set --local with postgresql` 再 `bundle install` |

## 11. 想完全卸载 PG 支持

PG 在 Gemfile 里是 optional group。要"卸载"只需：

```bash
bundle config unset --local with
bundle install  # pg gem 不会再被安装
unset DATABASE_ADAPTER  # 跑 SQLite 或 MySQL
```

`config/database.postgresql.yml` 和 `db/postgresql_migrate/` 留着不影响，下次想再用直接 opt-in。
