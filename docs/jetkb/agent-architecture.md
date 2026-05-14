# Agent system architecture

This document is the internal reference for jetKB maintainers and contributors
working on the agent feature. For the operator-facing integration guide, see
[agent-integration.md](agent-integration.md). For the full API reference, see
[../api/sections/agents.md](../api/sections/agents.md).

---

## What an agent is

An agent is a `User` record with `role: "agent"`. It is not a new model — it
reuses the full existing stack:

- `Identity` (email: `<slug>@agent.local`) — one Identity per agent, scoped to
  the account.
- `User` with `role: :agent` — the account-scoped membership record.
- `Identity::AccessToken` — bearer tokens issued and rotated through the agents
  API, not through the personal access token UI.
- `Assignment` — cards are assigned to agent users exactly as they are to human
  users.
- `Watch` — agents can watch cards.
- `Event` — all actions taken by an agent (comments, completions) create Event
  records with the agent user as `creator`.
- `Webhook` — two new `PERMITTED_ACTIONS` are the only addition to the webhook
  infrastructure.

### How agents differ from human users

| Attribute | Human user | Agent user |
|-----------|-----------|------------|
| `role` | `owner`, `admin`, `member` | `agent` |
| Email | real address | `<slug>@agent.local` |
| `User.active` scope | included | **excluded** |
| `User.api_active` scope | included | **included** |
| `is_agent` in JSON | `false` | `true` |
| Creates own tokens | via `/my/access_tokens` | via `/agents/:id/tokens` (admin only) |
| Can call `agent_completion` | no (403) | yes, if assigned |
| Can manage other agents | no | no |

The `User.active` / `User.api_active` split is the key design decision: it keeps
agents invisible in human-facing queries (assignee dropdowns, user lists) while
allowing them to authenticate against the API.

---

## Data model

### Users table (no schema change)

The `role` column is a string enum. Adding `:agent` appends to the list at
position 4, leaving existing integer mappings stable:

```
owner=0, admin=1, member=2, system=3, agent=4
```

### `agent_settings` table

Stores per-agent configuration that has no natural home on the `users` table:

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid | primary key |
| `user_id` | uuid | foreign key → `users.id`, unique |
| `webhook_url` | string | nullable; HTTPS required |
| `all_access_boards` | boolean | default true |
| `created_at` / `updated_at` | datetime | — |

When `all_access_boards` is `false`, the agent's board visibility is determined
by `Access` records, the same model used for board-level human access control.

### `card_agent_completions` table

Stores idempotency keys for the `agent_completion` endpoint:

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid | primary key |
| `card_id` | uuid | foreign key → `cards.id` |
| `user_id` | uuid | foreign key → `users.id` |
| `idempotency_key` | string | from `Idempotency-Key` header |
| `response_body` | text | serialized first response |
| `created_at` | datetime | — |

Unique index on `(card_id, user_id, idempotency_key)`. When a duplicate key is
received, the controller returns `response_body` without re-running the
transaction.

---

## New files (zero upstream conflict)

The following files are entirely new. They have no upstream equivalent and will
never conflict during a sync:

```
app/controllers/agents_controller.rb
app/controllers/agents/tokens_controller.rb
app/controllers/agents/board_accesses_controller.rb
app/controllers/cards/agent_completions_controller.rb
app/models/agent_setting.rb
app/models/card/agent_completion.rb
app/views/agents/
app/views/agents/tokens/
app/views/agents/board_accesses/
app/views/cards/agent_completions/
db/migrate/TIMESTAMP_create_agent_settings.rb
db/migrate/TIMESTAMP_create_card_agent_completions.rb
db/postgresql_migrate/TIMESTAMP_create_agent_settings.rb
db/postgresql_migrate/TIMESTAMP_create_card_agent_completions.rb
config/initializers/jetkb_rate_limits.rb
test/controllers/agents_controller_test.rb
test/controllers/agents/tokens_controller_test.rb
test/controllers/agents/board_accesses_controller_test.rb
test/controllers/cards/agent_completions_controller_test.rb
test/models/card/agent_completion_test.rb
test/integration/agent_assign_complete_flow_test.rb
docs/api/sections/agents.md
docs/jetkb/agent-integration.md
docs/jetkb/agent-architecture.md
docs/jetkb/agent-qa-checklist.md
```

---

## Upstream files modified (minimal surface)

Only the following upstream-owned files were changed. Each change is small and
concentrated to a single logical addition:

| File | Change | Upstream PR candidate? |
|------|--------|----------------------|
| `app/models/user/role.rb` | Append `:agent` to the role enum; add `agent` scope, `api_active` scope, `agent?` predicate, `api_active?` predicate | Yes — upstream may want a generic bot/service-account role |
| `app/models/webhook.rb` | Add `card_assigned_to_agent` and `card_agent_completed` to `PERMITTED_ACTIONS` | Yes — upstream may want these if they adopt the agent concept |
| `app/controllers/concerns/authorization.rb` | Replace `user.active?` gate with `user.api_active?` in `ensure_can_access_account` | Yes — prerequisite for any API-only user |
| `app/controllers/users_controller.rb` | Widen `set_user` lookup to include `api_active` users so agents can be looked up by ID in API contexts | Yes |
| `app/controllers/cards/assignments_controller.rb` | Same widening for agent assignment lookup | Yes |
| `app/models/card/assignable.rb` | After tracking a `card_assigned` event, check if the new assignee is an agent and fire `card_assigned_to_agent` | Partial — upstream might not want the fan-out |
| `app/views/users/_user.json.jbuilder` | Add `is_agent: user.agent?` to the user JSON shape | Yes |

All modified upstream files are tagged with `[jetkb]` commits where the change
is fork-only, or without a prefix where the change is suitable for upstreaming.

---

## API surface

Routes added in `config/routes.rb`:

```ruby
resources :agents do
  scope module: :agents do
    resources :tokens,        only: %i[index create destroy]
    resources :board_accesses, only: %i[index create destroy]
  end
end

resources :cards do
  scope module: :cards do
    resource :agent_completion, only: %i[create]
  end
end
```

Authorization:

- `AgentsController`, `Agents::TokensController`, `Agents::BoardAccessesController`:
  require `ensure_admin` (owner or admin role).
- `Cards::AgentCompletionsController`: requires `Current.user.agent?` **and**
  `card.assigned_to?(Current.user)`. Any other caller receives `403`.

For the full request/response shapes, see [../api/sections/agents.md](../api/sections/agents.md).

---

## Webhook fan-out

When a card is assigned to a user with `role: :agent`, `Card::Assignable#assign`
records two events in sequence:

1. The standard `card_assigned` event (existing behavior, unchanged).
2. A new `card_assigned_to_agent` event with the same `eventable` and `creator`.

Webhook subscribers receive deliveries for each event they are subscribed to.
Subscribing to `card_assigned` continues to work without modification — the fan-out
is additive. Subscribers that only care about agent assignments use
`card_assigned_to_agent` to avoid filtering on the assignee's role themselves.

---

## Completion atomicity

`Card::AgentCompletion.record!` is the entry point called by
`Cards::AgentCompletionsController`. It runs a single database transaction:

```ruby
def record!(card:, agent:, params:, idempotency_key:)
  existing = find_by(card:, user: agent, idempotency_key:)
  return existing if existing

  ActiveRecord::Base.transaction do
    comment = card.comments.create!(
      creator: agent,
      body: build_comment_body(params)
    )
    apply_outcome(card, params[:outcome], agent)
    card.assignments.destroy_by(assignee: agent)
    event = Event.create!(
      action: "card_agent_completed",
      creator: agent,
      eventable: card,
      particulars: build_particulars(params, comment)
    )
    create!(
      card:, user: agent, idempotency_key:,
      response_body: build_response(card, params, comment, event).to_json
    )
  end
end
```

`apply_outcome` dispatches on the `outcome` string:

| Value | Action |
|-------|--------|
| `"closed"` | `card.close(closer: agent)` |
| `/\Atriaged:(.+)\z/` | `card.triage_into(column, by: agent)` |
| `"not_now"` | `card.postpone(by: agent)` |
| `"none"` or nil | no status change |

If `outcome` is not provided, it defaults to `"closed"` when `result` is
`succeeded` or `failed`, and `"none"` otherwise.

---

## Idempotency

The `Idempotency-Key` header maps to the `idempotency_key` column in
`card_agent_completions`. The unique index on `(card_id, user_id, idempotency_key)`
means that:

1. The first request with a given key runs the full transaction and stores the
   serialized response.
2. Any subsequent request with the same key skips the transaction and returns the
   stored response body with status `200 OK` instead of `201 Created`.

Clients should generate the key before starting their LLM call so the same key
can be resent on any retry (network timeout, 5xx, process crash).

---

## Rate limits

Implemented in `config/initializers/jetkb_rate_limits.rb` using `rack-attack`.
The cache key hashes the bearer token so the raw secret is never stored in the
rate-limit cache:

```ruby
throttle("agent_completion/token", limit: 60, period: 1.minute) do |req|
  if req.path.end_with?("/agent_completion") && req.post?
    Digest::SHA256.hexdigest(req.env["HTTP_AUTHORIZATION"].to_s)[0, 16]
  end
end
```

| Throttle | Limit | Period | Discriminator |
|----------|-------|--------|---------------|
| `agent_completion` | 60 | 1 minute | hashed bearer token |
| `agent_completion` | 5 000 | 1 day | hashed bearer token |
| `agents#create` | 10 | 1 hour | hashed bearer token (admin) |
| `agents/tokens#create` | 20 | 1 day | hashed bearer token |

All throttles respond with `429 Too Many Requests` and a `Retry-After` header.

---

## i18n

Agent-specific strings live in:

- `config/locales/en.yml` — keys under `agents.*` and `card_agent_completions.*`
- `config/locales/zh-CN.yml` — Chinese translations for the same keys

The `result` values (`succeeded`, `failed`, `cancelled`, `needs_human`) are
translated via `t("card_agent_completions.result.<value>")` when composing
comment bodies. This means the comment text is in the locale of the instance,
not hardcoded English.

---

## PostgreSQL adapter notes

The two new migrations have parallel copies in `db/postgresql_migrate/`. The PG
versions use `uuid` column types (via `PostgresqlUuid`) and `gen_random_uuid()`
defaults rather than `string` columns with application-level UUIDv7 generation.
See `docs/jetkb-postgresql.md` for the full PG adapter documentation.

When running `bin/rails db:migrate` under `DATABASE_ADAPTER=postgresql`, Rails
loads migrations from both `db/migrate/` and `db/postgresql_migrate/` (configured
in `config/application.rb`). Under MySQL or SQLite, only `db/migrate/` is used.

---

## Fork isolation summary

The agent feature was designed to land with minimal permanent divergence from
upstream:

- All new behavior is in new files. No upstream file has its logic restructured.
- Changes to upstream files are additive (append to enum, append to array,
  widen a scope predicate).
- Every upstream-file change is a candidate for an upstream PR. If accepted, the
  corresponding `[jetkb]` commit becomes a no-op that can be dropped on the next
  sync.
- The only permanently fork-exclusive files are those in `docs/jetkb/` and
  `config/initializers/jetkb_rate_limits.rb`.
