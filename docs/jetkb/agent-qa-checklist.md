# Agent QA checklist

Run through this before tagging a release that includes agent feature changes.

Mark every item before signing off. If an item cannot be verified in the current
environment, note why and get a second reviewer to confirm.

---

## Functional

- [ ] Create an agent via the API; confirm `201 Created` with `initial_token.token` in the response body.
- [ ] Attempt to fetch the agent again via `GET /agents/:id`; confirm `initial_token` is **not** present.
- [ ] Confirm a `<slug>@agent.local` Identity was created in the database.
- [ ] Confirm the agent User has `role: "agent"`.
- [ ] Assign a card to the agent (via the UI or `POST /cards/:n/assignments`).
  - [ ] Confirm a `card_assigned` event is recorded with the agent as `eventable` assignee.
  - [ ] Confirm a `card_assigned_to_agent` event is **also** recorded for the same card.
- [ ] Verify a webhook subscribed to `card_assigned_to_agent` receives a delivery.
  - [ ] Delivery `state` is `completed`.
  - [ ] Payload `action` is `"card_assigned_to_agent"`.
- [ ] Call `agent_completion` with a valid agent bearer token and `result: "succeeded"`:
  - [ ] Response is `201 Created` with a JSON body including `card_number`, `result`, `outcome`, `comment_id`, `event_id`.
  - [ ] The card is now closed (or in the column specified by `outcome`).
  - [ ] The agent is no longer listed as an assignee on the card.
  - [ ] A comment authored by the agent appears on the card, containing the `summary` text.
  - [ ] A `card_agent_completed` event is recorded with the agent as `creator`.
  - [ ] A webhook subscribed to `card_agent_completed` receives a delivery.
- [ ] Re-submit the same `agent_completion` request with the identical `Idempotency-Key`:
  - [ ] Response is `200 OK` with the same body as the first call.
  - [ ] No additional comment is posted to the card.
  - [ ] No additional event is recorded.
  - [ ] Card state has not changed again.
- [ ] With `all_access_boards: false`, confirm the agent receives `404` when reading a board it has not been granted access to via `board_accesses`.
- [ ] Grant the agent access to that board via `POST /agents/:id/board_accesses`; confirm the agent can now read it.
- [ ] Remove the board access via `DELETE /agents/:id/board_accesses/:id`; confirm the agent receives `404` again.

---

## Authorization

- [ ] A human bearer token receives `403` when calling `POST /cards/:n/agent_completion`.
- [ ] An agent bearer token receives `403` when calling `GET /agents` (agents cannot list agents).
- [ ] An agent bearer token receives `403` when calling `POST /agents/:id/tokens` (agents cannot rotate their own token).
- [ ] A member-role bearer token (not owner or admin) receives `403` when calling `GET /agents`.
- [ ] An unauthenticated request (no `Authorization` header) receives `401` on all agent endpoints.
- [ ] Cross-account isolation: an agent bearer token from account A receives `404` when accessing resources in account B.
- [ ] An agent that is **not** assigned to a card receives `403` when calling `agent_completion` for that card.

---

## Rate limits

- [ ] Send 61 `agent_completion` requests within one minute from the same agent token.
  - [ ] The 61st request returns `429 Too Many Requests`.
  - [ ] The response includes a `Retry-After` header with a positive integer.
- [ ] Wait for the `Retry-After` duration to elapse; confirm the next request succeeds.
- [ ] Send the same 61st call from a **different** agent token; confirm it succeeds (counters are per-token, not global).
- [ ] Send 11 `POST /agents` requests within one hour from the same admin token.
  - [ ] The 11th request returns `429 Too Many Requests`.
- [ ] Send 21 `POST /agents/:id/tokens` requests within one day for the same agent.
  - [ ] The 21st request returns `429 Too Many Requests`.

---

## i18n

- [ ] Set `I18n.locale = :"zh-CN"` at the console (or set `RAILS_LOCALE=zh-CN` and restart).
- [ ] Call `agent_completion` with `result: "succeeded"`; confirm the summary comment body begins with the localized result label (e.g. "已完成").
- [ ] Confirm `result: "failed"` renders "已失败", `result: "cancelled"` renders "已取消", and `result: "needs_human"` renders "需要人工处理" (or the current zh-CN translations).
- [ ] Create an agent via the API while zh-CN locale is active; confirm any flash messages are in Chinese.

---

## Security

- [ ] The `initial_token.token` value is not present on subsequent `GET /agents/:id` or `GET /agents` responses.
- [ ] The rate-limit cache key does not contain the raw bearer token (inspect the cache store; value should be a hex digest).
- [ ] Attempt to set `webhook_url` to `http://169.254.169.254/` (AWS IMDS) or `http://localhost/`; confirm `422 Unprocessable Entity` is returned.
- [ ] Attempt to set `webhook_url` to `http://10.0.0.1/` or another RFC-1918 address; confirm `422 Unprocessable Entity` is returned.
- [ ] Delete an agent; confirm:
  - [ ] The associated Identity record is removed.
  - [ ] All `Identity::AccessToken` records for that agent are removed.
  - [ ] Active sessions are invalidated.
  - [ ] Comments and events authored by the agent are preserved.

---

## Multi-adapter

- [ ] Run `bin/rails db:migrate` on a **MySQL/Trilogy** database; confirm both `agent_settings` and `card_agent_completions` tables are created without errors.
- [ ] Run `bin/rails db:migrate` on a **SQLite** database; confirm both tables are created without errors.
- [ ] Run the corresponding migration from `db/postgresql_migrate/` on a **PostgreSQL** database; confirm both tables are created without errors and use `uuid` column types.
- [ ] Confirm that after running migrations under MySQL or SQLite, `db/structure.sql` is **not** updated (only `db/schema.rb` changes).
- [ ] Confirm that after running migrations under PostgreSQL, `db/structure.sql` is updated and `db/schema.rb` is **not** updated.

---

## Documentation

- [ ] `docs/api/sections/agents.md` is present and linked from `docs/api/README.md`.
- [ ] All curl examples in `docs/api/sections/agents.md` use the correct placeholder host (`https://app.jetkb.example.com`) and account slug (`/1234567`).
- [ ] `docs/jetkb/agent-integration.md` reflects the current endpoint signatures (compare `result` values, `outcome` values, and response shapes against the implementation).
- [ ] `docs/jetkb/agent-architecture.md` accurately describes the current set of modified upstream files.
- [ ] Brand audit passes — no "Fizzy" string in any of the new agent docs:
  ```bash
  git grep -i fizzy -- 'docs/api/sections/agents.md' 'docs/jetkb/agent-*.md'
  ```
  Expected: zero hits.
- [ ] CHANGELOG or VERSION bumped if this is a tagged release.
