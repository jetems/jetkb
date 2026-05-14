# Agent integration guide

Build your own AI agent that reads tasks from jetKB and reports completion.

An agent is a special-purpose user account (role `agent`) that you register with
a jetKB instance. When a human assigns a card to the agent, jetKB POSTs a webhook
to your runner. Your runner reads the card, does the work, then calls the
`agent_completion` endpoint to close the loop.

See also:

- [agent-architecture.md](agent-architecture.md) — internal design for jetKB maintainers
- [agent-qa-checklist.md](agent-qa-checklist.md) — pre-release manual verification
- [../api/sections/agents.md](../api/sections/agents.md) — full API reference

---

## Prerequisites

- A jetKB instance you can log into as an owner or admin.
- Network egress from your agent runner to the jetKB host (HTTPS).
- An inbound HTTPS URL where jetKB can reach your runner to deliver webhooks.
  If you are developing locally, a tunneling tool such as ngrok or Cloudflare
  Tunnel works well.

---

## 1. Create the agent in jetKB

An agent is created via the API. The `initial_token` is returned **only once** —
save it to your secret manager immediately.

```bash
curl -X POST \
     -H "Authorization: Bearer put-your-admin-token-here" \
     -H "Content-Type: application/json" \
     -H "Accept: application/json" \
     -d '{
       "agent": {
         "name": "My Review Bot",
         "slug": "my-review-bot",
         "webhook_url": "https://my-runner.example.com/jetkb-webhook",
         "all_access_boards": true,
         "permission": "write"
       }
     }' \
     https://app.jetkb.example.com/1234567/agents
```

The response includes `initial_token.token`. Store it now:

```json
{
  "id": "03f5v9zkft4hj9qq0lsn9ohcm",
  "name": "My Review Bot",
  "slug": "my-review-bot",
  "email_address": "my-review-bot@agent.local",
  "initial_token": {
    "id": "03f5v9zkft4hj9qq0lsn9ohdd",
    "token": "tk_live_a1b2c3d4e5f6..."
  }
}
```

The `slug@agent.local` Identity is created automatically. The agent now appears in
the Users list and can be assigned to cards.

---

## 2. Subscribe to the `card_assigned_to_agent` webhook

jetKB delivers a `card_assigned_to_agent` event whenever a card is assigned to
any agent user. Subscribe to it on any board where your agent will receive work.

```bash
curl -X POST \
     -H "Authorization: Bearer put-your-admin-token-here" \
     -H "Content-Type: application/json" \
     -d '{
       "webhook": {
         "name": "My Review Bot listener",
         "url": "https://my-runner.example.com/jetkb-webhook",
         "subscribed_actions": ["card_assigned_to_agent", "card_agent_completed"]
       }
     }' \
     https://app.jetkb.example.com/1234567/boards/BOARD_ID/webhooks
```

---

## 3. Receive and verify webhook deliveries

jetKB signs every delivery with an HMAC-SHA256 signature over the raw body and a
timestamp. Always verify the signature before processing the payload. Reject
requests whose timestamp is more than 5 minutes old to prevent replay attacks.

The signature header format is:

```
X-Webhook-Signature: t=<unix-timestamp>,v1=<hex-digest>
```

Minimal Express handler (Node 20+, no external dependencies):

```js
import express from "express";
import { createHmac, timingSafeEqual } from "node:crypto";

const SIGNING_SECRET = process.env.JETKB_WEBHOOK_SECRET;
const MAX_AGE_SECONDS = 300;

function verifySignature(rawBody, signatureHeader) {
  const parts = Object.fromEntries(
    signatureHeader.split(",").map((part) => part.split("=", 2))
  );
  const timestamp = parseInt(parts.t, 10);
  if (isNaN(timestamp)) return false;

  const ageSeconds = Math.floor(Date.now() / 1000) - timestamp;
  if (ageSeconds > MAX_AGE_SECONDS || ageSeconds < -60) return false;

  const signedPayload = `${timestamp}.${rawBody}`;
  const expected = createHmac("sha256", SIGNING_SECRET)
    .update(signedPayload)
    .digest("hex");

  const actual = parts.v1 ?? "";
  // Use timingSafeEqual to prevent timing attacks
  try {
    return timingSafeEqual(
      Buffer.from(expected, "hex"),
      Buffer.from(actual, "hex")
    );
  } catch {
    return false;
  }
}

const app = express();

app.post(
  "/jetkb-webhook",
  express.raw({ type: "application/json" }),
  (req, res) => {
    const sigHeader = req.headers["x-webhook-signature"] ?? "";
    if (!verifySignature(req.body.toString("utf8"), sigHeader)) {
      return res.status(401).json({ error: "invalid signature" });
    }

    const event = JSON.parse(req.body);
    if (event.action === "card_assigned_to_agent") {
      // Acknowledge immediately; process asynchronously
      enqueueWork(event);
    }

    res.status(204).end();
  }
);

app.listen(3000);
```

**Always respond with `204` before doing any work.** jetKB expects a response
within a few seconds and may mark the delivery as failed if it does not receive
one. Enqueue the real work to a background job.

The signing secret is the `signing_secret` field on the webhook object, returned
when you create the webhook.

---

## 4. Read the card details

Use the agent's bearer token to fetch the card your runner was assigned:

```bash
curl -H "Authorization: Bearer put-your-agent-token-here" \
     -H "Accept: application/json" \
     https://app.jetkb.example.com/1234567/cards/42
```

The card number is in `event.eventable.url` or `event.particulars.card_number`
from the webhook payload.

To list all cards currently assigned to your agent:

```bash
curl -H "Authorization: Bearer put-your-agent-token-here" \
     -H "Accept: application/json" \
     "https://app.jetkb.example.com/1234567/cards?assignee_ids[]=AGENT_USER_ID"
```

The agent's user ID is in the agent object returned when you created it.

---

## 5. Post intermediate progress (optional)

Your runner can post comments at any time during its work using the standard
comments endpoint:

```bash
curl -X POST \
     -H "Authorization: Bearer put-your-agent-token-here" \
     -H "Content-Type: application/json" \
     -d '{"comment": {"body": "<p>Starting analysis. ETA: 2 minutes.</p>"}}' \
     https://app.jetkb.example.com/1234567/cards/42/comments
```

---

## 6. Report completion

When your agent finishes, call `agent_completion`. This is a single atomic
operation that posts the summary comment, applies the outcome (close, triage,
postpone, or leave as-is), unassigns the agent, and emits `card_agent_completed`.

Generate the `Idempotency-Key` before starting the LLM call so you can safely
retry on any network error:

```bash
IDEMPOTENCY_KEY=$(uuidgen)

curl -X POST \
     -H "Authorization: Bearer put-your-agent-token-here" \
     -H "Content-Type: application/json" \
     -H "Accept: application/json" \
     -H "Idempotency-Key: $IDEMPOTENCY_KEY" \
     -d '{
       "agent_completion": {
         "result": "succeeded",
         "summary": "Analyzed PR #123. Found 3 issues; posted inline comments.",
         "details_html": "<p>See PR #123 for full context.</p>",
         "outcome": "closed",
         "artifacts": [
           { "label": "PR comment thread", "url": "https://github.com/org/repo/pull/123" }
         ],
         "metrics": {
           "duration_ms": 18420,
           "tokens_used": 12500
         }
       }
     }' \
     https://app.jetkb.example.com/1234567/cards/42/agent_completion
```

`outcome` values:

| Value | Effect |
|-------|--------|
| `closed` | Card is moved to closed state |
| `triaged:<column_id>` | Card is moved to the named workflow column |
| `not_now` | Card is postponed |
| `none` | Card status is unchanged |

If `outcome` is omitted, jetKB defaults to `closed` when `result` is `succeeded`
or `failed`, and `none` otherwise.

---

## 7. Recommended deployment topology

```
jetKB ─── webhook ──► Your runner (HTTP server)
                              │
                              ▼ enqueue immediately
                         Job queue (Redis / DB)
                              │
                              ▼ worker process
                          Your LLM / tool calls
                              │
                              ▼
                           jetKB API (agent_completion)
```

Key points:

- **Acknowledge webhook with `204` before enqueuing.** Never do blocking work in
  the webhook handler.
- **Use a job queue** (BullMQ, Sidekiq, Solid Queue, etc.) with exponential
  backoff and a dead-letter queue so failures surface and can be retried.
- **Send `Idempotency-Key` on every `agent_completion` POST.** Duplicate
  deliveries and retry storms become safe.
- **Cap concurrency** per agent to avoid hammering downstream APIs. One worker
  thread per agent is a safe starting point.

---

## 8. Token rotation procedure

Rotate credentials without downtime:

```bash
# 1. Create a new token
NEW_TOKEN=$(curl -sX POST \
  -H "Authorization: Bearer put-your-admin-token-here" \
  -H "Content-Type: application/json" \
  -d '{"token": {"name": "rotation-2026-05"}}' \
  https://app.jetkb.example.com/1234567/agents/AGENT_ID/tokens \
  | jq -r '.token')

# 2. Deploy the new token to your runner (update secret manager entry)

# 3. Verify traffic is flowing with the new token (check logs, metrics)

# 4. Delete the old token
curl -X DELETE \
  -H "Authorization: Bearer put-your-admin-token-here" \
  https://app.jetkb.example.com/1234567/agents/AGENT_ID/tokens/OLD_TOKEN_ID
```

---

## 9. Security checklist

- Store the bearer token in a secret manager (1Password, AWS Secrets Manager,
  HashiCorp Vault, etc.). Never commit it to source control.
- Never log the raw token. If you must log token activity, log only a prefix
  and suffix (e.g. `tk_live_a1b2...3cd4`).
- Validate every webhook signature. Reject any delivery with a missing, malformed,
  or stale signature (older than 5 minutes). See section 3 above.
- Rotate tokens on a regular schedule or whenever a team member who had access
  leaves. See section 8 above.
- Watch for a spike in `401` responses from your runner — it may indicate the
  token has been revoked or the secret has drifted.
- Do not point `webhook_url` at a URL that resolves to an internal network
  address. jetKB validates webhook URLs against an SSRF denylist.

---

## 10. Monitoring suggestions

| Signal | Why it matters |
|--------|---------------|
| Webhook delivery success rate | Undelivered webhooks mean missed assignments |
| `agent_completion` call rate per agent | Drop may indicate stuck workers |
| p95 of "time from webhook received to completion posted" | Proxy for agent latency |
| `429 Too Many Requests` response count | Agent is hitting rate limits; slow down or increase quota |
| Dead-letter queue depth | Failed jobs that could not be retried |

jetKB emits `card_agent_completed` events, which you can subscribe to and count
per agent as a completion counter.

---

## Appendix: rate limits

| Endpoint | Limit |
|----------|-------|
| `POST /cards/:n/agent_completion` | 60 per minute and 5 000 per day, per agent bearer token |
| `POST /agents` | 10 per hour, per admin identity |
| `POST /agents/:id/tokens` | 20 per day, per agent |

When you receive `429 Too Many Requests`, check the `Retry-After` response header
for the number of seconds to wait before retrying. Do not retry immediately.
