# Agents

Agents are automated users that can be assigned cards, receive webhook notifications when assigned, perform work autonomously, and report completion back to jetKB via a dedicated API endpoint. An agent differs from a human user in the following ways:

- An agent has role `agent` and a synthetic email address of the form `<slug>@agent.local`.
- Agent bearer tokens are issued through the agents API rather than through the personal access tokens flow.
- Agents are excluded from the `User.active` scope used by human-facing queries, but are included in the `User.api_active` scope so they can authenticate against the API.
- The `is_agent` field is present on every user object returned by the API, so clients can distinguish agents from humans without inspecting the role string.

Only account owners and admins can create, list, update, or delete agents or manage their tokens and board access. Agents authenticate using their own bearer tokens and interact with cards, comments, and other resources through the standard API endpoints. The [`agent_completion` endpoint](#post-account_slugcardscard_numberagent_completion) is a convenience wrapper that atomically posts a summary comment, applies an outcome, and unassigns the agent in a single request.

For a step-by-step guide to building your own agent runner, see [docs/jetkb/agent-integration.md](../../jetkb/agent-integration.md).

---

## `GET /:account_slug/agents`

Returns a paginated list of agents in the account. Only accessible by owners and admins.

__Example:__

```bash
curl -H "Authorization: Bearer put-your-access-token-here" \
     -H "Accept: application/json" \
     https://app.jetkb.example.com/1234567/agents
```

__Response:__

```json
[
  {
    "id": "03f5v9zkft4hj9qq0lsn9ohcm",
    "name": "Code Review Bot",
    "slug": "code-review-bot",
    "email_address": "code-review-bot@agent.local",
    "is_agent": true,
    "webhook_url": "https://my-agent.example.com/jetkb",
    "all_access_boards": true,
    "permission": "write",
    "active": true,
    "created_at": "2026-05-14T10:30:00.000Z",
    "last_active_at": "2026-05-14T15:20:00.000Z",
    "assigned_cards_count": 3,
    "completed_cards_count": 27,
    "url": "https://app.jetkb.example.com/1234567/agents/03f5v9zkft4hj9qq0lsn9ohcm"
  }
]
```

__Error codes:__

| Status | Reason |
|--------|--------|
| `401 Unauthorized` | Missing or invalid bearer token |
| `403 Forbidden` | Authenticated user is not an owner or admin |

---

## `POST /:account_slug/agents`

Creates a new agent. Atomically creates an Identity, a User with role `agent`, and an initial access token. The token is returned in plain text **only in this response** — jetKB does not store or display it again.

Only owners and admins can create agents.

__Example:__

```bash
curl -X POST \
     -H "Authorization: Bearer put-your-access-token-here" \
     -H "Content-Type: application/json" \
     -H "Accept: application/json" \
     -d '{
       "agent": {
         "name": "Code Review Bot",
         "slug": "code-review-bot",
         "webhook_url": "https://my-agent.example.com/jetkb",
         "all_access_boards": true,
         "permission": "write"
       }
     }' \
     https://app.jetkb.example.com/1234567/agents
```

__Parameters:__

| Parameter | Required | Description |
|-----------|----------|-------------|
| `name` | Yes | Display name shown in the UI and in comments posted by the agent |
| `slug` | Yes | Unique identifier within the account. Must match `\A[a-z0-9]([a-z0-9-]*[a-z0-9])?\z`, length 2–50. Immutable after creation. |
| `webhook_url` | No | URL where jetKB delivers `card_assigned_to_agent` events. Can be `null` for pull-mode agents that poll for assignments instead of receiving push notifications. |
| `all_access_boards` | No | When `true` (default), the agent can read any board it has API access to. When `false`, access is restricted to boards explicitly granted via the board_accesses sub-resource. |
| `permission` | No | `read` or `write`. Defaults to `write`. A `read` agent can read cards and boards but cannot post comments or call `agent_completion`. |

__Response:__

```
HTTP/1.1 201 Created
Location: https://app.jetkb.example.com/1234567/agents/03f5v9zkft4hj9qq0lsn9ohcm
```

```json
{
  "id": "03f5v9zkft4hj9qq0lsn9ohcm",
  "name": "Code Review Bot",
  "slug": "code-review-bot",
  "email_address": "code-review-bot@agent.local",
  "is_agent": true,
  "webhook_url": "https://my-agent.example.com/jetkb",
  "all_access_boards": true,
  "permission": "write",
  "active": true,
  "created_at": "2026-05-14T10:30:00.000Z",
  "last_active_at": null,
  "assigned_cards_count": 0,
  "completed_cards_count": 0,
  "url": "https://app.jetkb.example.com/1234567/agents/03f5v9zkft4hj9qq0lsn9ohcm",
  "initial_token": {
    "id": "03f5v9zkft4hj9qq0lsn9ohdd",
    "token": "tk_live_a1b2c3d4e5f6g7h8i9j0k1l2m3",
    "created_at": "2026-05-14T10:30:00.000Z"
  }
}
```

Store `initial_token.token` immediately in a secret manager. It will not be shown again.

__Error codes:__

| Status | Reason |
|--------|--------|
| `401 Unauthorized` | Missing or invalid bearer token |
| `403 Forbidden` | Authenticated user is not an owner or admin |
| `422 Unprocessable Entity` | `slug` already taken, format invalid, or `webhook_url` is not a valid HTTPS URL |

---

## `GET /:account_slug/agents/:id`

Returns a single agent. Only accessible by owners and admins.

__Example:__

```bash
curl -H "Authorization: Bearer put-your-access-token-here" \
     -H "Accept: application/json" \
     https://app.jetkb.example.com/1234567/agents/03f5v9zkft4hj9qq0lsn9ohcm
```

__Response:__

Returns the same agent shape shown in the list endpoint, without `initial_token`. The bearer token is never returned after creation.

__Error codes:__

| Status | Reason |
|--------|--------|
| `401 Unauthorized` | Missing or invalid bearer token |
| `403 Forbidden` | Authenticated user is not an owner or admin |
| `404 Not Found` | Agent does not exist or belongs to a different account |

---

## `PATCH /:account_slug/agents/:id`

Updates an agent. Only owners and admins can update agents.

The `slug` is immutable after creation and is ignored if included in the request body.

__Example:__

```bash
curl -X PATCH \
     -H "Authorization: Bearer put-your-access-token-here" \
     -H "Content-Type: application/json" \
     -H "Accept: application/json" \
     -d '{
       "agent": {
         "name": "Code Review Bot v2",
         "webhook_url": "https://my-agent.example.com/jetkb-v2",
         "all_access_boards": false
       }
     }' \
     https://app.jetkb.example.com/1234567/agents/03f5v9zkft4hj9qq0lsn9ohcm
```

__Parameters:__

| Parameter | Description |
|-----------|-------------|
| `name` | New display name |
| `webhook_url` | New webhook delivery URL, or `null` to disable push delivery |
| `all_access_boards` | Change board access mode (see `POST` description) |
| `permission` | Change permission level (`read` or `write`) |

__Response:__

Returns the updated agent object.

__Error codes:__

| Status | Reason |
|--------|--------|
| `401 Unauthorized` | Missing or invalid bearer token |
| `403 Forbidden` | Authenticated user is not an owner or admin |
| `404 Not Found` | Agent does not exist or belongs to a different account |
| `422 Unprocessable Entity` | `webhook_url` is not a valid HTTPS URL |

---

## `DELETE /:account_slug/agents/:id`

Deletes an agent. Cascades to destroy the associated Identity, all access tokens, and active sessions. Assignments, comments, and events authored by the agent are preserved by default.

Only owners and admins can delete agents.

__Example:__

```bash
curl -X DELETE \
     -H "Authorization: Bearer put-your-access-token-here" \
     https://app.jetkb.example.com/1234567/agents/03f5v9zkft4hj9qq0lsn9ohcm
```

__Response:__

Returns `204 No Content` on success.

__Error codes:__

| Status | Reason |
|--------|--------|
| `401 Unauthorized` | Missing or invalid bearer token |
| `403 Forbidden` | Authenticated user is not an owner or admin |
| `404 Not Found` | Agent does not exist or belongs to a different account |

---

## `GET /:account_slug/agents/:id/tokens`

Returns the list of active access tokens for an agent. Token values are never included — only metadata. Only owners and admins can list tokens.

__Example:__

```bash
curl -H "Authorization: Bearer put-your-access-token-here" \
     -H "Accept: application/json" \
     https://app.jetkb.example.com/1234567/agents/03f5v9zkft4hj9qq0lsn9ohcm/tokens
```

__Response:__

```json
[
  {
    "id": "03f5v9zkft4hj9qq0lsn9ohdd",
    "name": "initial",
    "last_used_at": "2026-05-14T15:20:00.000Z",
    "created_at": "2026-05-14T10:30:00.000Z"
  }
]
```

__Error codes:__

| Status | Reason |
|--------|--------|
| `401 Unauthorized` | Missing or invalid bearer token |
| `403 Forbidden` | Authenticated user is not an owner or admin |
| `404 Not Found` | Agent does not exist or belongs to a different account |

---

## `POST /:account_slug/agents/:id/tokens`

Creates a new access token for an agent. Use this to rotate credentials: create a new token, deploy it to your runner, verify it works, then delete the old token.

The token value is returned in plain text **only in this response**.

Rate-limited to 20 token creations per agent per day.

__Example:__

```bash
curl -X POST \
     -H "Authorization: Bearer put-your-access-token-here" \
     -H "Content-Type: application/json" \
     -H "Accept: application/json" \
     -d '{"token": {"name": "rotation-2026-05"}}' \
     https://app.jetkb.example.com/1234567/agents/03f5v9zkft4hj9qq0lsn9ohcm/tokens
```

__Parameters:__

| Parameter | Required | Description |
|-----------|----------|-------------|
| `name` | No | Human-readable label to help identify the token (e.g. `rotation-2026-05`) |

__Response:__

```
HTTP/1.1 201 Created
```

```json
{
  "id": "03f5v9zkft4hj9qq0lsn9ohee",
  "name": "rotation-2026-05",
  "token": "tk_live_z9y8x7w6v5u4t3s2r1q0p9o8",
  "last_used_at": null,
  "created_at": "2026-05-14T16:00:00.000Z"
}
```

__Error codes:__

| Status | Reason |
|--------|--------|
| `401 Unauthorized` | Missing or invalid bearer token |
| `403 Forbidden` | Authenticated user is not an owner or admin |
| `404 Not Found` | Agent does not exist or belongs to a different account |
| `429 Too Many Requests` | Exceeded 20 token creations per agent per day |

---

## `DELETE /:account_slug/agents/:id/tokens/:token_id`

Revokes an access token. Any in-flight requests using the revoked token will immediately begin receiving `401 Unauthorized`. Only owners and admins can revoke tokens.

__Example:__

```bash
curl -X DELETE \
     -H "Authorization: Bearer put-your-access-token-here" \
     https://app.jetkb.example.com/1234567/agents/03f5v9zkft4hj9qq0lsn9ohcm/tokens/03f5v9zkft4hj9qq0lsn9ohdd
```

__Response:__

Returns `204 No Content` on success.

__Error codes:__

| Status | Reason |
|--------|--------|
| `401 Unauthorized` | Missing or invalid bearer token |
| `403 Forbidden` | Authenticated user is not an owner or admin |
| `404 Not Found` | Agent or token does not exist, or belongs to a different account |

---

## `GET /:account_slug/agents/:id/board_accesses`

Returns the list of boards explicitly granted to this agent. Only relevant when `all_access_boards` is `false`. Only owners and admins can read board access records.

__Example:__

```bash
curl -H "Authorization: Bearer put-your-access-token-here" \
     -H "Accept: application/json" \
     https://app.jetkb.example.com/1234567/agents/03f5v9zkft4hj9qq0lsn9ohcm/board_accesses
```

__Response:__

```json
[
  {
    "id": "03f5v9zkft4hj9qq0lsn9ohff",
    "board": {
      "id": "03f5v9zkft4hj9qq0lsn9ohcy",
      "name": "Backend",
      "all_access": false,
      "created_at": "2026-05-14T09:00:00.000Z",
      "url": "https://app.jetkb.example.com/1234567/boards/03f5v9zkft4hj9qq0lsn9ohcy"
    },
    "created_at": "2026-05-14T10:35:00.000Z"
  }
]
```

__Error codes:__

| Status | Reason |
|--------|--------|
| `401 Unauthorized` | Missing or invalid bearer token |
| `403 Forbidden` | Authenticated user is not an owner or admin |
| `404 Not Found` | Agent does not exist or belongs to a different account |

---

## `POST /:account_slug/agents/:id/board_accesses`

Grants an agent access to a specific board. Only meaningful when `all_access_boards` is `false`. Only owners and admins can grant board access.

__Example:__

```bash
curl -X POST \
     -H "Authorization: Bearer put-your-access-token-here" \
     -H "Content-Type: application/json" \
     -H "Accept: application/json" \
     -d '{"board_access": {"board_id": "03f5v9zkft4hj9qq0lsn9ohcy"}}' \
     https://app.jetkb.example.com/1234567/agents/03f5v9zkft4hj9qq0lsn9ohcm/board_accesses
```

__Parameters:__

| Parameter | Required | Description |
|-----------|----------|-------------|
| `board_id` | Yes | ID of the board to grant access to |

__Response:__

```
HTTP/1.1 201 Created
```

Returns the created board access record in the response body (same shape as the list endpoint).

__Error codes:__

| Status | Reason |
|--------|--------|
| `401 Unauthorized` | Missing or invalid bearer token |
| `403 Forbidden` | Authenticated user is not an owner or admin |
| `404 Not Found` | Agent or board does not exist, or belongs to a different account |
| `422 Unprocessable Entity` | Board access already exists for this agent + board pair |

---

## `DELETE /:account_slug/agents/:id/board_accesses/:id`

Revokes an agent's access to a specific board. Only owners and admins can revoke board access.

__Example:__

```bash
curl -X DELETE \
     -H "Authorization: Bearer put-your-access-token-here" \
     https://app.jetkb.example.com/1234567/agents/03f5v9zkft4hj9qq0lsn9ohcm/board_accesses/03f5v9zkft4hj9qq0lsn9ohff
```

__Response:__

Returns `204 No Content` on success.

__Error codes:__

| Status | Reason |
|--------|--------|
| `401 Unauthorized` | Missing or invalid bearer token |
| `403 Forbidden` | Authenticated user is not an owner or admin |
| `404 Not Found` | Agent or board access record does not exist, or belongs to a different account |

---

## `POST /:account_slug/cards/:card_number/agent_completion`

Reports that an agent has finished working on a card. This is a convenience endpoint that atomically performs four operations in a single database transaction:

1. Posts a comment authored by the agent, containing `summary` and optional `details_html`.
2. Applies the `outcome` (close, triage into a column, postpone, or leave the card's status unchanged).
3. Unassigns the agent from the card.
4. Records a `card_agent_completed` event, which triggers any webhooks subscribed to that action.

Only the agent currently assigned to the card may call this endpoint. Calling it with a human bearer token returns `403`.

This endpoint is idempotent: include an `Idempotency-Key` header with a UUID. If a completion record with the same key already exists for this card and agent, the endpoint returns the original response without re-applying side effects. This makes it safe to retry on network failure.

Rate-limited to 60 calls per agent per minute and 5 000 calls per agent per day.

__Example:__

```bash
curl -X POST \
     -H "Authorization: Bearer put-your-agent-token-here" \
     -H "Content-Type: application/json" \
     -H "Accept: application/json" \
     -H "Idempotency-Key: 550e8400-e29b-41d4-a716-446655440000" \
     -d '{
       "agent_completion": {
         "result": "succeeded",
         "summary": "Analyzed PR #123, found 3 issues. Posted detailed comments on lines 42, 87, 102.",
         "details_html": "<p>See inline comments on the pull request for full context.</p>",
         "outcome": "closed",
         "artifacts": [
           {
             "label": "PR comment thread",
             "url": "https://github.com/org/repo/pull/123#discussion_r456"
           }
         ],
         "metrics": {
           "duration_ms": 18420,
           "tokens_used": 12500,
           "cost_usd": 0.34
         }
       }
     }' \
     https://app.jetkb.example.com/1234567/cards/42/agent_completion
```

__Parameters:__

| Parameter | Required | Description |
|-----------|----------|-------------|
| `result` | Yes | Outcome of the agent's work. One of: `succeeded`, `failed`, `cancelled`, `needs_human` |
| `summary` | Yes | Single-line plain-text summary. Becomes the body of the comment posted to the card. Maximum 2 000 characters. |
| `details_html` | No | Optional rich-text HTML that is appended to the comment body. Sanitized server-side. |
| `outcome` | No | What to do with the card after completion. One of: `closed`, `triaged:<column_id>`, `not_now`, `none`. Defaults to `closed` when `result` is `succeeded` or `failed`, and `none` otherwise. |
| `artifacts` | No | Array of up to 10 link objects, each with `label` (string) and `url` (string). Appended to the comment. |
| `metrics` | No | Arbitrary JSON object. Stored in the event `particulars` for operational observability. Not shown in the UI. |

The `Idempotency-Key` request header is strongly recommended. Use a UUID v4 generated before the LLM call so the same key can be re-sent on retry.

__Response:__

```
HTTP/1.1 201 Created
```

```json
{
  "id": "03f5v9zkft4hj9qq0lsn9ohgg",
  "card_number": 42,
  "result": "succeeded",
  "outcome": "closed",
  "comment_id": "03f5v9zkft4hj9qq0lsn9ohhh",
  "event_id": "03f5v9zkft4hj9qq0lsn9ohii",
  "created_at": "2026-05-14T15:30:00.000Z"
}
```

When the same `Idempotency-Key` is re-submitted, the response is `200 OK` with the same body (rather than `201 Created`), and no side effects are re-applied.

__Error codes:__

| Status | Reason |
|--------|--------|
| `401 Unauthorized` | Missing or invalid bearer token |
| `403 Forbidden` | Caller is not an agent, or the agent is not currently assigned to this card |
| `404 Not Found` | Card does not exist or is not accessible to this agent |
| `422 Unprocessable Entity` | Required fields missing, `result` is not a valid value, or `outcome` references a column that does not exist on this card's board |
| `429 Too Many Requests` | Rate limit exceeded. Includes a `Retry-After` header with the number of seconds to wait. |

---

## Webhook actions for agents

Two webhook actions are available for agent workflows. Subscribe to them when creating or updating a webhook on the board where the agent is assigned:

| Action | Emitted when |
|--------|-------------|
| `card_assigned_to_agent` | A card is assigned to any user with role `agent`. Delivered in addition to the standard `card_assigned` event, so existing subscribers are unaffected. |
| `card_agent_completed` | An agent calls `agent_completion` successfully. |

The webhook payload shape is identical to other card-related actions: the top-level `action` field contains the action string, and the `eventable` object describes the card.

To receive these events, include them in the `subscribed_actions` array when creating a webhook. See [webhooks.md](webhooks.md) for the full webhook API.

---

## Agent-to-card workflow

The typical integration loop:

1. An admin creates an agent and saves the `initial_token.token`.
2. The agent's `webhook_url` receives a `card_assigned_to_agent` delivery when a human assigns a card.
3. The agent reads the card using its bearer token and `GET /:account_slug/cards/:card_number`.
4. The agent performs its work (LLM call, CI pipeline, external API, etc.).
5. The agent posts `agent_completion` with a summary and the appropriate outcome.
6. jetKB closes or moves the card, posts the comment, and fires `card_agent_completed`.

The agent can post intermediate progress comments using the standard `POST /:account_slug/cards/:card_number/comments` endpoint at any point during step 4.
