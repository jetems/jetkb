# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Context

This repo is **jetKB**, a downstream fork of [Fizzy](https://github.com/basecamp/fizzy) by 37signals. Two ongoing concerns shape every change:

1. **Stay synced with upstream** — pick up upstream features and patches with the smallest possible merge surface.
2. **Rebrand Fizzy → jetKB** — replace user-visible brand without rewriting internal class names or paths.

For upstream project knowledge (commands, multi-tenancy, models, deploy, testing), see `AGENTS.md`. For Ruby/Rails coding style, see `STYLE.md`. **Both files are upstream-tracked — do not edit them to record jetKB-specific notes; put fork notes in this file.**

## Fork Topology

Expected git remotes:

```
upstream → git@github.com:basecamp/fizzy.git   (read-only, source of truth for shared code)
origin   → <jetKB fork URL>                    (push target)
```

Currently `origin` still points at `basecamp/fizzy` — confirm and fix before any push:

```bash
git remote -v
# If origin points at basecamp/fizzy:
git remote rename origin upstream
git remote add origin <jetkb-fork-url>
```

## Branching

- `main` — tracks upstream `main` plus jetKB customizations. Default branch, deploy source.
- `upstream-sync/YYYY-MM-DD` — short-lived branches used only for merging from upstream.
- Feature branches: `jetkb/<topic>` for fork-only work; no prefix for changes intended to be PR'd back to upstream.

## Upstream Sync Workflow

Run regularly (weekly cadence is a good default; always before starting non-trivial work):

```bash
git fetch upstream
git checkout -b upstream-sync/$(date +%Y-%m-%d) main
git merge upstream/main
# Resolve conflicts (see "Conflict resolution" below)
bin/ci                                  # must pass before merging
git checkout main && git merge --ff-only upstream-sync/$(date +%Y-%m-%d)
```

Enable `git rerere` once per clone to auto-resolve recurring conflicts:

```bash
git config rerere.enabled true
```

### Conflict resolution rules

- **In rebrand surfaces** (user-facing text, logos, mailer subjects, README, docs) → prefer the jetKB side.
- **In code logic** → prefer upstream and re-apply any jetKB customization on top in a follow-up commit. Never silently drop upstream changes.
- After merging, run the brand audit (below) to make sure no new "Fizzy" strings slipped in.

## Rebrand: Fizzy → jetKB

~148 source files reference "Fizzy". Keep rebrand changes **as concentrated as possible** to minimize merge conflicts. Choose the mechanism with the smallest surface, in this order:

1. **Config / env overrides** — set app name, host, mailer-from, default account names via env vars or a single `config/initializers/jetkb_branding.rb`. Prefer this over editing strings inline.
2. **i18n overrides** — when a string is already wrapped in `t("...")`, override it in `config/locales/en.yml` (or add `zh-CN.yml` for Chinese). If the string is hardcoded in a view/mailer/model, **first** submit an upstream PR that extracts it to an i18n key, **then** override the value here. This shrinks the rebrand surface and avoids permanent forking of that file.
3. **Asset replacement** — swap files in `app/assets/images/` keeping filenames identical so views/CSS need no edits.
4. **Direct source edits** — last resort. Group such edits into commits tagged `[brand]` so they are easy to spot during upstream merges.

### What NOT to rebrand

Do **not** rename internal identifiers: module names like `Fizzy::Something`, class names, table names, Ruby file paths, route helpers, CSS class names with `fizzy-` prefix. Renaming these creates massive permanent conflicts with every upstream change for zero user-visible benefit. The brand is only the user-visible surface.

### Brand audit

Before every release and after every upstream merge, confirm no "Fizzy" leaked into user-facing surfaces:

```bash
git grep -i fizzy -- 'app/views/**' 'app/mailers/**' 'config/locales/**' 'public/**' 'docs/**' 'README.md'
```

Hits in `app/models/`, `app/controllers/`, `lib/`, `test/` are expected (internal naming) and acceptable.

## Chinese Localization

The upstream has minimal i18n — `config/locales/en.yml` is only ~31 lines; most strings are hardcoded in views, mailers, and model error messages. Strategy:

- Add `config/locales/zh-CN.yml` mirroring keys as they're introduced.
- For each hardcoded English string you want translated, prefer the path: **upstream PR to extract to i18n key** → then translate in `zh-CN.yml`. This benefits everyone and eliminates ongoing merge cost.
- Where upstreaming is not viable, tag the commit `[zh-CN]` and keep the diff localized to a single file when possible.
- Set the runtime locale via env (`RAILS_LOCALE=zh-CN`) or a per-account preference — do not hardcode `I18n.default_locale = :"zh-CN"` in a file that upstream owns.

## Commit Conventions

Prefix fork commits so upstream-merge reviewers can quickly classify them:

| Prefix | Meaning |
|---|---|
| `[brand]` | Branding-only changes (text, logos, mailer-from) |
| `[zh-CN]` | Chinese localization |
| `[jetkb]` | Fork-only features, deploy config, or ops |
| `[sync]` | Upstream merge commits |
| _(none)_ | Changes intended to be PR'd back to upstream |

When a `[brand]` or `[zh-CN]` change could plausibly be split as "upstream extracts to i18n, jetKB overrides value," **do the upstream PR first** rather than forking the file.

## Files to Know

- `AGENTS.md`, `STYLE.md`, `docs/development.md`, `docs/docker-deployment.md`, `docs/kamal-deployment.md` — upstream-tracked; do not edit
- `config/deploy.yml` — upstream Kamal config. Prefer a sibling `config/deploy.jetkb.yml` (selected via Kamal `-d jetkb`) over editing the upstream file
- `config/locales/en.yml` — small upstream i18n file; jetKB overrides go in `zh-CN.yml` or `en.yml` (carefully)
- `config/initializers/jetkb_branding.rb` — recommended single home for brand config constants (create when first needed)
- `LICENSE.md` — O'Saasy License: private/internal use is allowed; offering jetKB as a competing SaaS to third parties is not

## PostgreSQL Support (fork-only third adapter)

jetKB adds an **optional** PostgreSQL 18+ path alongside upstream SQLite (OSS default) and MySQL/Trilogy (SaaS default). MySQL and SQLite behavior is unchanged when PG isn't activated.

- `Gemfile`: `pg` gem in `group :postgresql, optional: true` — opt in with `bundle config set --local with postgresql`.
- Activation: `DATABASE_ADAPTER=postgresql` env var. `Fizzy.db_adapter.postgresql?` predicate.
- Files exclusive to the PG path (safe to evolve without touching upstream files):
  - `config/database.postgresql.yml`
  - `db/postgresql_migrate/*.rb` (separate migration directory **outside** `db/migrate/` so Rails' recursive globber doesn't pick them up under MySQL/SQLite; PG-only)
  - `app/models/search/record/postgresql.rb` (tsvector + GIN + ts_headline)
- Cross-cutting touch points (small, careful changes):
  - `lib/fizzy.rb` — `DbAdapter#postgresql?` predicate
  - `lib/rails_ext/active_record_uuid_type.rb` — `PostgresqlUuid` type with hex/base36 round-trip
  - `config/application.rb` — switches `schema_format` to `:sql` and migration paths when PG is active
  - `app/models/board/accessible.rb` — uuid_type lookup is now adapter-dynamic
- Schema dump: PG path emits `db/structure.sql` (not `schema.rb`) because Ruby schema can't represent tsvector/GIN. MySQL/SQLite still use `schema.rb`. **Do not commit both**; the active adapter determines which dump file Rails refreshes.

When upstream changes any of the cross-cutting files above during a sync, audit the PG path. See `docs/jetkb-postgresql-roadmap.md` for the full design rationale and `docs/jetkb-postgresql.md` for operator-facing instructions.
