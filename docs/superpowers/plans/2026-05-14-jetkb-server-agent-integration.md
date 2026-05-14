# jetKB Server-Side Agent Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add server-side support for the `agent` user role, the `agent_completion` sugar endpoint, agent-aware webhook events, and an `/agents` namespace — so external AI agents can be assigned cards via the existing assignment model and report completion atomically.

**Architecture:** New `agent` role appended to `User::Role` enum; existing `Identity::AccessToken` reused for agent auth; new `Agents` namespace for management; one new lightweight table `card_agent_completions` for idempotency keys; rack-attack added for per-agent rate limiting on the completion endpoint. All other behavior reuses existing `Assignment`, `Watch`, `Event`, `Webhook` infrastructure.

**Tech Stack:** Ruby on Rails (main branch), MySQL (Trilogy) / SQLite / PostgreSQL (fork-only), Solid Queue, jbuilder, Minitest, rack-attack (new dependency).

**Companion plan:** `docs/superpowers/plans/2026-05-14-jetkb-cli-mcp.md` covers the `jetkb-cli` TypeScript repo (CLI + MCP). Server plan must reach Task 5 before CLI-3 can target the live agent endpoints; otherwise the two plans progress independently.

**Spec reference:** `docs/superpowers/specs/2026-05-14-agent-integration-design.md`.

**Fork discipline:** Every commit carries a tag prefix per `CLAUDE.md`:

| Prefix | Meaning |
|---|---|
| _(none)_ | Intended to be PR'd back to upstream Fizzy |
| `[jetkb]` | Fork-only feature / config / ops |
| `[brand]` | Branding-only changes |
| `[zh-CN]` | Chinese localization |

When a task spans multiple categories, use multiple atomic commits, each with the appropriate tag.

---

## Task 1: PR-1 — User::Role + Webhook actions + is_agent serializer

**Files:**
- Modify: `app/models/user/role.rb`
- Modify: `app/models/webhook.rb`
- Modify: `app/views/users/_user.json.jbuilder`
- Test (modify): `test/models/user/role_test.rb` (create if absent)
- Test (modify): `test/models/webhook_test.rb`
- Test (modify): `test/integration/cards_api_test.rb` or `test/controllers/users_controller_test.rb` (whichever covers user JSON output)

**Goal:** Foundation for everything else. All later PRs depend on this landing.

- [ ] **Step 1.1: Read current state**

```bash
cat app/models/user/role.rb
cat app/models/webhook.rb | grep -A 15 PERMITTED_ACTIONS
cat app/views/users/_user.json.jbuilder
```

Confirm enum order is `owner / admin / member / system` and webhook actions array exists.

- [ ] **Step 1.2: Write failing tests for `User::Role` agent additions**

Create or open `test/models/user/role_test.rb`. Add:

```ruby
require "test_helper"

class User::RoleTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:fizzy)
    @identity = Identity.create!(email_address: "robot@agent.local")
  end

  test "agent is a valid role" do
    agent = @account.users.create!(role: :agent, name: "Bot", identity: @identity)
    assert agent.agent?
    assert_predicate agent, :api_active?
  end

  test "agent integer value is stable at 4" do
    # Guard against accidental enum reorder during upstream merges
    assert_equal 4, User.roles["agent"]
    assert_equal({ "owner" => 0, "admin" => 1, "member" => 2, "system" => 3, "agent" => 4 }, User.roles)
  end

  test "agent is not in active scope" do
    agent = @account.users.create!(role: :agent, name: "Bot", identity: @identity)
    refute_includes User.active, agent
  end

  test "agent is in api_active scope" do
    agent = @account.users.create!(role: :agent, name: "Bot", identity: @identity)
    assert_includes User.api_active, agent
  end

  test "agent is in agent scope" do
    agent = @account.users.create!(role: :agent, name: "Bot", identity: @identity)
    assert_includes User.agent, agent
    refute_includes User.agent, users(:david)
  end

  test "agent is not admin and not owner" do
    agent = @account.users.create!(role: :agent, name: "Bot", identity: @identity)
    refute agent.admin?
    refute agent.owner?
  end

  test "human users return false for agent?" do
    refute users(:david).agent?
  end
end
```

- [ ] **Step 1.3: Run the new tests and confirm they fail**

```bash
bin/rails test test/models/user/role_test.rb -v
```

Expected: `NoMethodError: undefined method 'agent?'` or `ArgumentError: 'agent' is not a valid role`.

- [ ] **Step 1.4: Implement enum + scope + predicate additions**

Edit `app/models/user/role.rb` to:

```ruby
module User::Role
  extend ActiveSupport::Concern

  included do
    enum :role, %i[ owner admin member system agent ].index_by(&:itself), scopes: false

    scope :owner,      -> { where(active: true, role: :owner) }
    scope :admin,      -> { where(active: true, role: %i[ owner admin ]) }
    scope :member,     -> { where(active: true, role: :member) }
    scope :agent,      -> { where(active: true, role: :agent) }
    scope :active,     -> { where(active: true, role: %i[ owner admin member ]) }
    scope :api_active, -> { where(active: true, role: %i[ owner admin member agent ]) }

    def admin?
      super || owner?
    end
  end

  def agent?
    role == "agent"
  end

  def api_active?
    active? && role.in?(%w[ owner admin member agent ])
  end

  def can_change?(other)
    (admin? && !other.owner?) || other == self
  end

  def can_administer?(other)
    admin? && !other.owner? && other != self
  end

  def can_administer_board?(board)
    admin? || board.creator == self
  end

  def can_administer_card?(card)
    admin? || card.creator == self
  end
end
```

- [ ] **Step 1.5: Run tests, confirm pass**

```bash
bin/rails test test/models/user/role_test.rb -v
```

Expected: all 7 tests pass.

- [ ] **Step 1.6: Run full model test suite to catch regressions**

```bash
bin/rails test test/models/ -v
```

Expected: all green. If something using `User.active` now breaks because tests assumed agents are absent (they were), you'll see it here.

- [ ] **Step 1.7: Commit role changes**

```bash
git add app/models/user/role.rb test/models/user/role_test.rb
git commit -m "Add agent role with api_active scope and predicate

agent is appended to the User::Role enum (integer 4) and exposed
through a dedicated agent scope, a new api_active scope that
includes agents alongside human roles, and an agent? predicate.
The existing active scope remains human-only so mention pickers,
seat counts, and member directories keep their current semantics.

A guard test asserts the integer value stays at 4 so an
accidental enum reorder during an upstream merge surfaces in CI."
```

(No tag prefix — this commit is an upstream PR candidate.)

- [ ] **Step 1.8: Write failing tests for webhook permitted actions**

Open `test/models/webhook_test.rb`. Add:

```ruby
test "card_assigned_to_agent is a permitted action" do
  webhook = webhooks(:fizzy).dup
  webhook.subscribed_actions = [ "card_assigned_to_agent" ]
  assert_equal [ "card_assigned_to_agent" ], webhook.subscribed_actions
end

test "card_agent_completed is a permitted action" do
  webhook = webhooks(:fizzy).dup
  webhook.subscribed_actions = [ "card_agent_completed" ]
  assert_equal [ "card_agent_completed" ], webhook.subscribed_actions
end

test "unknown actions are still filtered out" do
  webhook = webhooks(:fizzy).dup
  webhook.subscribed_actions = [ "card_agent_completed", "bogus_action" ]
  assert_equal [ "card_agent_completed" ], webhook.subscribed_actions
end
```

- [ ] **Step 1.9: Run tests, confirm failure**

```bash
bin/rails test test/models/webhook_test.rb -v
```

Expected: first two fail (actions get normalized to empty array because they're not in PERMITTED_ACTIONS).

- [ ] **Step 1.10: Add two actions to `PERMITTED_ACTIONS`**

Edit `app/models/webhook.rb`. In the `PERMITTED_ACTIONS` array, add `card_assigned_to_agent` (alphabetically after `card_assigned`) and `card_agent_completed` (after `card_auto_postponed`):

```ruby
PERMITTED_ACTIONS = %w[
  card_assigned
  card_assigned_to_agent
  card_closed
  card_postponed
  card_auto_postponed
  card_agent_completed
  card_board_changed
  card_published
  card_reopened
  card_sent_back_to_triage
  card_triaged
  card_unassigned
  comment_created
].freeze
```

- [ ] **Step 1.11: Run tests, confirm pass**

```bash
bin/rails test test/models/webhook_test.rb -v
```

Expected: all green.

- [ ] **Step 1.12: Commit webhook actions**

```bash
git add app/models/webhook.rb test/models/webhook_test.rb
git commit -m "Add card_assigned_to_agent and card_agent_completed webhook actions

These two actions support the assign-to-agent / agent-completion
loop. card_assigned_to_agent fires alongside card_assigned when
the assignee is role=agent so subscribers can target agent
assignments without filtering. card_agent_completed fires from
the new agent_completion endpoint described in
docs/api/sections/agents.md."
```

(No tag prefix — upstream PR candidate.)

- [ ] **Step 1.13: Write failing test for `is_agent` in user JSON output**

Find an existing API test that exercises user JSON. Most likely candidate: `test/controllers/users_controller_test.rb`. Add (adjust fixture references to match what exists):

```ruby
test "user JSON includes is_agent boolean" do
  sign_in_as :david
  get user_url(users(:david)), headers: { "Accept" => "application/json" }
  assert_response :ok
  body = response.parsed_body
  assert_equal false, body["is_agent"], "Human users must have is_agent=false"
end

test "agent user JSON has is_agent true" do
  agent_identity = Identity.create!(email_address: "robot@agent.local")
  agent = accounts(:fizzy).users.create!(role: :agent, name: "Bot", identity: agent_identity)
  sign_in_as :david
  get user_url(agent), headers: { "Accept" => "application/json" }
  assert_response :ok
  assert_equal true, response.parsed_body["is_agent"]
end
```

- [ ] **Step 1.14: Run, confirm failure**

```bash
bin/rails test test/controllers/users_controller_test.rb -v -n "/is_agent/"
```

Expected: missing key.

- [ ] **Step 1.15: Add `is_agent` field to the user serializer**

Edit `app/views/users/_user.json.jbuilder`:

```ruby
json.cache! user do
  json.(user, :id, :name, :role, :active)
  json.is_agent user.agent?

  json.email_address user.identity&.email_address
  json.created_at user.created_at.utc

  json.url user_url(user)
  json.avatar_url user_avatar_url(user)
end
```

- [ ] **Step 1.16: Run, confirm pass**

```bash
bin/rails test test/controllers/users_controller_test.rb -v -n "/is_agent/"
```

Expected: both tests green.

- [ ] **Step 1.17: Run full CI to confirm no regressions**

```bash
bin/ci
```

Expected: all green. ETag cache busting on the `_user` partial is automatic because the partial source changed.

- [ ] **Step 1.18: Commit serializer change**

```bash
git add app/views/users/_user.json.jbuilder test/controllers/users_controller_test.rb
git commit -m "Expose is_agent boolean in user JSON serializer

Clients (CLI, MCP server, downstream consumers) use this flag to
visually distinguish AI agents from human users in card assignee
lists, comment authors, and timeline events.

Field is true if and only if user.agent? returns true; the role
string remains the source of truth."
```

(No tag prefix — upstream PR candidate.)

---

## Task 2: PR-2 — Allow agent tokens through `ensure_can_access_account`

**Files:**
- Modify: `app/controllers/concerns/authorization.rb`
- Test (create): `test/integration/agent_api_access_test.rb`

**Goal:** Agent bearer tokens must pass the `ensure_can_access_account` gate. The gate currently checks `Current.user&.active?` (the DB column) which works for agents IF we also expand the predicate to be role-aware. We use the new `api_active?` predicate from Task 1.

- [ ] **Step 2.1: Read current state**

```bash
cat app/controllers/concerns/authorization.rb
```

Confirm `ensure_can_access_account` reads `Current.user&.active?`.

- [ ] **Step 2.2: Write failing integration test for agent token access**

Create `test/integration/agent_api_access_test.rb`:

```ruby
require "test_helper"

class AgentApiAccessTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:fizzy)
    @agent_identity = Identity.create!(email_address: "test-bot@agent.local")
    @agent = @account.users.create!(role: :agent, name: "Test Bot", identity: @agent_identity, active: true)
    @token = @agent_identity.access_tokens.create!(description: "test", permission: :write).token
  end

  test "agent token can list cards via JSON" do
    get "#{@account.slug}/cards", headers: bearer(@token).merge("Accept" => "application/json")
    assert_response :ok
  end

  test "agent token can fetch its own identity" do
    get "/my/identity", headers: bearer(@token).merge("Accept" => "application/json")
    assert_response :ok
  end

  test "missing token returns 401 not 403" do
    get "#{@account.slug}/cards", headers: { "Accept" => "application/json" }
    assert_response :unauthorized
  end

  test "agent token from another account is rejected with 404" do
    other_account = accounts(:initech)
    get "#{other_account.slug}/cards", headers: bearer(@token).merge("Accept" => "application/json")
    # Expect either 404 (account slug not accessible) or 403 — depending on current account resolution.
    # The point is: must NOT be 200.
    assert response.status >= 400
  end

  private
    def bearer(token)
      { "Authorization" => "Bearer #{token}" }
    end
end
```

- [ ] **Step 2.3: Run test, confirm failure**

```bash
bin/rails test test/integration/agent_api_access_test.rb -v
```

Expected: `agent token can list cards via JSON` fails — likely 403 because `Current.user&.active?` returns true (DB column) BUT `ensure_can_access_account`'s response is sensitive to scope (verify). If it actually passes, the failure mode is different but we still need the explicit `api_active?` guard for clarity and future-proofing.

- [ ] **Step 2.4: Update `ensure_can_access_account` to use `api_active?`**

Edit `app/controllers/concerns/authorization.rb`. Change:

```ruby
    def ensure_can_access_account
      unless Current.account.active? && Current.user&.active?
        respond_to do |format|
          format.html { redirect_to session_menu_path(script_name: nil) }
          format.json { head :forbidden }
        end
      end
    end
```

to:

```ruby
    def ensure_can_access_account
      unless Current.account.active? && Current.user&.api_active?
        respond_to do |format|
          format.html { redirect_to session_menu_path(script_name: nil) }
          format.json { head :forbidden }
        end
      end
    end
```

- [ ] **Step 2.5: Run tests, confirm pass**

```bash
bin/rails test test/integration/agent_api_access_test.rb -v
bin/rails test test/controllers/ test/integration/ -v
```

Expected: agent tests pass; no human-user regressions.

- [ ] **Step 2.6: Commit**

```bash
git add app/controllers/concerns/authorization.rb test/integration/agent_api_access_test.rb
git commit -m "[jetkb] Use api_active? in ensure_can_access_account

Agent bearer tokens now pass the account-access gate. The check
is semantically equivalent for human users (api_active? returns
the same value as active? when role is human) but additionally
admits role=agent users so the new agent-driven endpoints work
under bearer-token auth."
```

(`[jetkb]` tag: this is a fork-only behavior change that may not match upstream needs verbatim. An upstream PR can be opened in parallel.)

---

## Task 3: PR-3 — `card_agent_completions` table + `Card::AgentCompletion` model

**Files:**
- Create: `db/migrate/YYYYMMDDHHMMSS_create_card_agent_completions.rb` (timestamp by `rails g`)
- Create: `db/postgresql_migrate/YYYYMMDDHHMMSS_create_card_agent_completions.rb`
- Modify: `db/schema.rb` (auto-regenerated for MySQL/SQLite)
- Modify: `db/structure.sql` (auto-regenerated for PG)
- Create: `app/models/card/agent_completion.rb`
- Create: `test/models/card/agent_completion_test.rb`
- Create: `test/fixtures/card/agent_completions.yml` (empty placeholder)

**Goal:** Persisted idempotency keys + structured event payload for agent completions.

- [ ] **Step 3.1: Generate MySQL/SQLite migration**

```bash
bin/rails generate migration CreateCardAgentCompletions card:references user:references idempotency_key:string result:string comment:references event:references particulars:json
```

This creates `db/migrate/<timestamp>_create_card_agent_completions.rb`. Edit it to:

```ruby
class CreateCardAgentCompletions < ActiveRecord::Migration[8.1]
  def change
    create_table :card_agent_completions, id: :string, limit: 25 do |t|
      t.references :card, null: false, foreign_key: true, type: :string, limit: 25
      t.references :user, null: false, foreign_key: true, type: :string, limit: 25
      t.string :idempotency_key
      t.string :result, null: false
      t.references :comment, foreign_key: true, type: :string, limit: 25
      t.references :event, foreign_key: true, type: :string, limit: 25
      t.json :particulars, null: false, default: {}
      t.datetime :created_at, null: false
    end

    add_index :card_agent_completions,
      %i[ card_id user_id idempotency_key ],
      unique: true,
      where: "idempotency_key IS NOT NULL",
      name: "idx_agent_completions_idempotency"
  end
end
```

(UUID string IDs match upstream UUIDv7 convention; `id:` and FK `type:` set to `:string, limit: 25` per `app/models/board/accessible.rb` precedent.)

- [ ] **Step 3.2: Write equivalent PostgreSQL migration**

Create `db/postgresql_migrate/<same-timestamp>_create_card_agent_completions.rb`:

```ruby
class CreateCardAgentCompletions < ActiveRecord::Migration[8.1]
  def change
    create_table :card_agent_completions, id: :uuid do |t|
      t.references :card, null: false, foreign_key: true, type: :uuid
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :idempotency_key
      t.string :result, null: false
      t.references :comment, foreign_key: true, type: :uuid
      t.references :event, foreign_key: true, type: :uuid
      t.jsonb :particulars, null: false, default: {}
      t.datetime :created_at, null: false
    end

    add_index :card_agent_completions,
      %i[ card_id user_id idempotency_key ],
      unique: true,
      where: "idempotency_key IS NOT NULL",
      name: "idx_agent_completions_idempotency"
  end
end
```

- [ ] **Step 3.3: Run migration against active adapter**

```bash
bin/rails db:migrate
```

Expected: migration runs cleanly; `db/schema.rb` (MySQL/SQLite) or `db/structure.sql` (PG) updates. Verify with `git diff db/`.

- [ ] **Step 3.4: Write failing model tests**

Create `test/models/card/agent_completion_test.rb`:

```ruby
require "test_helper"

class Card::AgentCompletionTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:fizzy)
    @card = cards(:plant_a_garden)  # any published card belonging to @account
    @agent_identity = Identity.create!(email_address: "completion-bot@agent.local")
    @agent = @account.users.create!(role: :agent, name: "Completion Bot", identity: @agent_identity, active: true)
    @card.assignments.create!(assignee: @agent, assigner: users(:david))
  end

  test "create writes comment, closes card, unassigns agent, emits event" do
    completion = Card::AgentCompletion.record!(
      card: @card,
      agent: @agent,
      result: "succeeded",
      summary: "Looks great.",
      outcome: "closed",
      idempotency_key: SecureRandom.uuid
    )

    assert_predicate completion, :persisted?
    assert_equal "succeeded", completion.result
    assert_predicate @card.reload, :closed?
    refute @card.assigned_to?(@agent)
    assert_equal 1, @card.comments.where(creator: @agent).count
    assert_equal "card_agent_completed", Event.where(eventable: @card).order(:created_at).last.action
  end

  test "non-assignee raises NotAssigned" do
    @card.assignments.destroy_all
    assert_raises(Card::AgentCompletion::NotAssigned) do
      Card::AgentCompletion.record!(card: @card, agent: @agent, result: "succeeded", summary: "x", outcome: "closed")
    end
  end

  test "same idempotency_key returns first record without side effects" do
    key = SecureRandom.uuid
    first  = Card::AgentCompletion.record!(card: @card, agent: @agent, result: "succeeded", summary: "First", outcome: "closed", idempotency_key: key)
    second = Card::AgentCompletion.record!(card: @card, agent: @agent, result: "succeeded", summary: "Second", outcome: "closed", idempotency_key: key)

    assert_equal first.id, second.id
    assert_equal 1, @card.comments.where(creator: @agent).count, "Second call must not write another comment"
  end

  test "result=failed with outcome nil does not close the card" do
    Card::AgentCompletion.record!(card: @card, agent: @agent, result: "failed", summary: "Broken.", outcome: nil)
    refute_predicate @card.reload, :closed?
  end

  test "outcome triaged:<column_id> moves card to that column" do
    column = @card.board.columns.first
    @card.triage_into(column, by: users(:david)) rescue nil   # reset state if needed
    Card::AgentCompletion.record!(card: @card, agent: @agent, result: "succeeded", summary: "Moved.", outcome: "triaged:#{column.id}")
    assert_equal column, @card.reload.column
  end

  test "artifacts limited to 10" do
    assert_raises(ActiveRecord::RecordInvalid) do
      Card::AgentCompletion.record!(
        card: @card, agent: @agent, result: "succeeded", summary: "Many",
        outcome: "closed",
        artifacts: 11.times.map { |i| { "label" => "a#{i}", "url" => "https://example.com/#{i}" } }
      )
    end
  end
end
```

- [ ] **Step 3.5: Run, confirm all fail**

```bash
bin/rails test test/models/card/agent_completion_test.rb -v
```

Expected: model not defined yet.

- [ ] **Step 3.6: Create `Card::AgentCompletion` model**

Create `app/models/card/agent_completion.rb`:

```ruby
class Card::AgentCompletion < ApplicationRecord
  self.table_name = "card_agent_completions"

  RESULTS  = %w[ succeeded failed cancelled needs_human ].freeze
  OUTCOMES_REGEX = /\A(closed|not_now|none|triaged:[a-z0-9]{25})\z/i

  class NotAssigned < StandardError; end

  belongs_to :card
  belongs_to :user
  belongs_to :comment, optional: true
  belongs_to :event,   optional: true

  validates :result, inclusion: { in: RESULTS }
  validate  :artifacts_within_limit

  def self.record!(card:, agent:, result:, summary:, outcome: nil, details_html: nil, artifacts: [], metrics: {}, idempotency_key: nil)
    raise NotAssigned, "agent #{agent.id} is not assigned to card #{card.id}" unless card.assigned_to?(agent)

    if idempotency_key.present? && (existing = where(card: card, user: agent, idempotency_key: idempotency_key).first)
      return existing
    end

    transaction do
      derived_outcome = outcome.presence || derive_outcome(result)

      comment = card.comments.create!(creator: agent, body: render_comment_body(result:, summary:, details_html:, artifacts:))
      apply_outcome!(card: card, outcome: derived_outcome, agent: agent)
      card.assignments.destroy_by(assignee: agent)

      event = card.events.create!(
        board: card.board,
        creator: agent,
        action: "card_agent_completed",
        particulars: { result:, summary:, outcome: derived_outcome, artifacts: artifacts, metrics: metrics }
      )

      create!(
        card: card, user: agent, idempotency_key: idempotency_key, result: result,
        comment: comment, event: event,
        particulars: { summary:, outcome: derived_outcome, artifacts:, metrics: }
      )
    end
  end

  private_class_method def self.derive_outcome(result)
    case result
    when "succeeded"               then "closed"
    when "cancelled"               then "not_now"
    when "failed", "needs_human"   then "none"
    end
  end

  private_class_method def self.apply_outcome!(card:, outcome:, agent:)
    case outcome
    when "closed"      then card.close(closer: agent)
    when "not_now"     then card.postpone(by: agent)
    when "none"        then # no state change
    when /\Atriaged:(?<column_id>.+)\z/
      column = card.board.columns.find(Regexp.last_match[:column_id])
      card.triage_into(column, by: agent)
    end
  end

  private_class_method def self.render_comment_body(result:, summary:, details_html:, artifacts:)
    label = I18n.t("cards.agent_completions.results.#{result}")
    parts = [ "<p><strong>#{label}</strong> · #{ERB::Util.html_escape(summary)}</p>" ]
    parts << details_html if details_html.present?
    if artifacts.present?
      list = artifacts.map { |a| "<li><a href=\"#{ERB::Util.html_escape(a['url'] || a[:url])}\" target=\"_blank\" rel=\"noopener\">#{ERB::Util.html_escape(a['label'] || a[:label])}</a></li>" }.join
      parts << "<ul>#{list}</ul>"
    end
    parts.join
  end

  private
    def artifacts_within_limit
      artifacts = particulars["artifacts"] || particulars[:artifacts] || []
      errors.add(:artifacts, "exceeds 10 entries") if artifacts.size > 10
    end
end
```

(Note: this assumes `card.close`, `card.postpone`, `card.triage_into` and `card.assigned_to?` exist. The first three are placeholders mapping to whatever upstream method does that work — verify and substitute exact names in the implementation: `Card::Closeable#close`, `Card::Postponable#postpone`, `Card::Triageable#triage_into`. If method signatures differ, adjust here.)

- [ ] **Step 3.7: Check existing card lifecycle methods, adjust calls if names differ**

```bash
cat app/models/card/closeable.rb app/models/card/postponable.rb app/models/card/triageable.rb
```

Update the `apply_outcome!` private method to use the exact method names exposed by those concerns.

- [ ] **Step 3.8: Run tests, iterate until green**

```bash
bin/rails test test/models/card/agent_completion_test.rb -v
```

If `card.close` or similar fails, adjust. Run until all 6 tests pass.

- [ ] **Step 3.9: Add `Event::WebhookDispatchJob` regression test**

Append to `test/models/card/agent_completion_test.rb`:

```ruby
test "writing a completion enqueues a webhook dispatch job for card_agent_completed" do
  assert_enqueued_with(job: Event::WebhookDispatchJob) do
    Card::AgentCompletion.record!(card: @card, agent: @agent, result: "succeeded", summary: "Done.", outcome: "closed")
  end
end
```

Run and confirm green.

- [ ] **Step 3.10: Commit migration + model**

```bash
git add db/migrate/*_create_card_agent_completions.rb \
        db/postgresql_migrate/*_create_card_agent_completions.rb \
        db/schema.rb db/structure.sql \
        app/models/card/agent_completion.rb \
        test/models/card/agent_completion_test.rb
git commit -m "[jetkb] Add Card::AgentCompletion model and idempotency table

card_agent_completions stores one row per agent completion call so
the agent_completion endpoint can dedupe Idempotency-Key retries
without rerunning the side effects (comment, state transition,
event emission). Particulars are stored as json/jsonb depending on
the active adapter.

Both MySQL and PostgreSQL migration paths are provided so the
fork-only PG adapter stays in lock-step with the MySQL/SQLite
upstream path; per CLAUDE.md we never commit schema.rb and
structure.sql for the same adapter run."
```

(`[jetkb]` — fork-only feature.)

---

## Task 4: PR-4 — `Agents` controllers (CRUD + tokens + board_accesses)

**Files:**
- Create: `app/controllers/agents_controller.rb`
- Create: `app/controllers/agents/tokens_controller.rb`
- Create: `app/controllers/agents/board_accesses_controller.rb`
- Create: `app/views/agents/index.json.jbuilder`
- Create: `app/views/agents/show.json.jbuilder`
- Create: `app/views/agents/create.json.jbuilder`
- Create: `app/views/agents/_agent.json.jbuilder`
- Create: `app/views/agents/tokens/index.json.jbuilder`
- Create: `app/views/agents/tokens/create.json.jbuilder`
- Create: `app/views/agents/board_accesses/index.json.jbuilder`
- Modify: `config/routes.rb`
- Create: `test/controllers/agents_controller_test.rb`
- Create: `test/controllers/agents/tokens_controller_test.rb`
- Create: `test/controllers/agents/board_accesses_controller_test.rb`
- Create: `test/fixtures/users.yml` — append 1-2 agent rows (do NOT replace file)
- Create: `test/fixtures/identities.yml` — append agent identities

**Goal:** REST CRUD for agent lifecycle. Admin-gated. Atomically creates `Identity` + `User` + initial `Identity::AccessToken` on POST.

- [ ] **Step 4.1: Add routes**

Edit `config/routes.rb`. After the `resources :webhooks ... do ... end` block inside the `resources :boards` block (or at any appropriate top-level position aligned with `:users` / `:boards`), add:

```ruby
  resources :agents do
    scope module: :agents do
      resources :tokens, only: %i[ index create destroy ]
      resources :board_accesses, only: %i[ index create destroy ]
    end
  end
```

- [ ] **Step 4.2: Append agent fixtures**

Add to `test/fixtures/identities.yml`:

```yaml
fizzy_review_bot:
  email_address: review-bot@agent.local

initech_qa_bot:
  email_address: qa-bot@agent.local
```

Add to `test/fixtures/users.yml`:

```yaml
review_bot:
  id: <%= ActiveRecord::FixtureSet.identify("review_bot", :uuid) %>
  name: Review Bot
  role: agent
  identity: fizzy_review_bot
  account: 37s_uuid
  active: true

qa_bot:
  id: <%= ActiveRecord::FixtureSet.identify("qa_bot", :uuid) %>
  name: QA Bot
  role: agent
  identity: initech_qa_bot
  account: initech_uuid
  active: true
```

(Names `37s_uuid` / `initech_uuid` follow the existing fixture-account convention; verify in `test/fixtures/accounts.yml`.)

- [ ] **Step 4.3: Write failing controller tests for index/create/show**

Create `test/controllers/agents_controller_test.rb`:

```ruby
require "test_helper"

class AgentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:fizzy)
    @admin   = users(:david)         # owner
    @member  = users(:jz)            # member
    @admin_token  = @admin.identity.access_tokens.create!(description: "test", permission: :write).token
    @member_token = @member.identity.access_tokens.create!(description: "test", permission: :write).token
  end

  test "admin can list agents" do
    get "#{@account.slug}/agents", headers: bearer(@admin_token).merge("Accept" => "application/json")
    assert_response :ok
    body = response.parsed_body
    assert body.is_a?(Array)
    assert_includes body.map { |a| a["name"] }, "Review Bot"
  end

  test "member cannot list agents" do
    get "#{@account.slug}/agents", headers: bearer(@member_token).merge("Accept" => "application/json")
    assert_response :forbidden
  end

  test "anonymous cannot list agents" do
    get "#{@account.slug}/agents", headers: { "Accept" => "application/json" }
    assert_response :unauthorized
  end

  test "admin can create agent and receives initial token once" do
    assert_difference -> { @account.users.where(role: :agent).count } => 1 do
      post "#{@account.slug}/agents",
        params: { agent: { name: "New Bot", slug: "new-bot", webhook_url: "https://example.com/hook" } }.to_json,
        headers: bearer(@admin_token).merge("Accept" => "application/json", "Content-Type" => "application/json")
    end
    assert_response :created
    body = response.parsed_body
    assert_equal "new-bot", body["slug"]
    assert_equal "new-bot@agent.local", body["email_address"]
    assert body.dig("initial_token", "token").present?, "initial token must be returned"
  end

  test "agent slug must be unique within account" do
    post "#{@account.slug}/agents",
      params: { agent: { name: "Dup", slug: "review-bot" } }.to_json,   # existing fixture slug
      headers: bearer(@admin_token).merge("Accept" => "application/json", "Content-Type" => "application/json")
    assert_response :unprocessable_entity
  end

  test "agent slug format is enforced" do
    post "#{@account.slug}/agents",
      params: { agent: { name: "Bad", slug: "BadCaseAndStuff!" } }.to_json,
      headers: bearer(@admin_token).merge("Accept" => "application/json", "Content-Type" => "application/json")
    assert_response :unprocessable_entity
  end

  test "admin can delete agent — Identity + tokens are destroyed, comments are preserved" do
    agent = users(:review_bot)
    agent_token = agent.identity.access_tokens.create!(description: "x", permission: :write)
    delete "#{@account.slug}/agents/#{agent.id}",
      headers: bearer(@admin_token).merge("Accept" => "application/json")
    assert_response :no_content
    assert_nil Identity.find_by(id: agent.identity_id)
    assert_nil Identity::AccessToken.find_by(id: agent_token.id)
  end

  test "patch cannot change slug" do
    agent = users(:review_bot)
    patch "#{@account.slug}/agents/#{agent.id}",
      params: { agent: { name: "Renamed", slug: "different" } }.to_json,
      headers: bearer(@admin_token).merge("Accept" => "application/json", "Content-Type" => "application/json")
    assert_response :ok
    assert_equal "Renamed", agent.reload.name
    # slug derived from email_address: must remain stable
    assert_equal "review-bot@agent.local", agent.identity.reload.email_address
  end

  test "cross-account access returns 404" do
    other_admin_token = users(:mike).identity.access_tokens.create!(description: "x", permission: :write).token
    get "#{@account.slug}/agents/#{users(:review_bot).id}",
      headers: bearer(other_admin_token).merge("Accept" => "application/json")
    assert_response :not_found
  end

  private
    def bearer(token)
      { "Authorization" => "Bearer #{token}" }
    end
end
```

- [ ] **Step 4.4: Run, confirm all fail (no controller yet)**

```bash
bin/rails test test/controllers/agents_controller_test.rb -v
```

Expected: routing or NameError failures.

- [ ] **Step 4.5: Inspect the existing `User#settings` API**

Agent-specific config (`webhook_url`, `all_access_boards`) reuses the upstream `User::Configurable` JSON settings column rather than adding a new table. Read the existing API first so the controller writes the right method calls:

```bash
cat app/models/user/configurable.rb app/models/user/settings.rb
```

Observe the exact accessor/writer shape (typically `user.settings.foo = ...` plus `user.save!`, or a single `update_setting(key, value)` helper). The code in Step 4.6 below assumes assign-then-save; if your inspection reveals a different shape (e.g. `user.update!(settings: user.settings.merge(...))`), substitute consistently.

If the existing `settings` column genuinely cannot store these two fields (e.g. it's a typed `User::Settings` object with a closed key set), stop and either: (a) extend `User::Settings` upstream-style — add `webhook_url` and `all_access_boards` accessors there in the same commit, or (b) introduce a small `AgentSetting` model. Prefer (a). Document the choice in the commit message.

- [ ] **Step 4.6: Implement `AgentsController`**

Create `app/controllers/agents_controller.rb`:

```ruby
class AgentsController < ApplicationController
  SLUG_FORMAT = /\A[a-z0-9]([a-z0-9-]*[a-z0-9])?\z/

  wrap_parameters :agent, include: %i[ name slug webhook_url all_access_boards permission ]

  before_action :ensure_admin
  before_action :set_agent, only: %i[ show update destroy ]

  def index
    @agents = Current.account.users.where(role: :agent).order(:name)
  end

  def show
  end

  def create
    params_hash = agent_params
    slug = params_hash[:slug].to_s
    unless slug.match?(SLUG_FORMAT) && slug.length.between?(2, 50)
      return render json: { errors: { slug: [ "format invalid" ] } }, status: :unprocessable_entity
    end

    if Identity.exists?(email_address: "#{slug}@agent.local")
      return render json: { errors: { slug: [ "already taken in this account" ] } }, status: :unprocessable_entity
    end

    identity = Identity.new(email_address: "#{slug}@agent.local")
    user = Current.account.users.new(role: :agent, name: params_hash[:name], active: true, identity: identity)

    ApplicationRecord.transaction do
      identity.save!
      user.save!
      apply_agent_settings(user, params_hash)
      @initial_token = identity.access_tokens.create!(
        description: "Initial token",
        permission: params_hash[:permission].presence || "write"
      )
      @agent = user
    end

    render :create, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.as_json }, status: :unprocessable_entity
  end

  def update
    permitted = agent_params.slice(:name, :webhook_url, :all_access_boards)
    ApplicationRecord.transaction do
      @agent.update!(name: permitted[:name]) if permitted[:name].present?
      apply_agent_settings(@agent, permitted) if permitted.key?(:webhook_url) || permitted.key?(:all_access_boards)
    end
    render :show
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.as_json }, status: :unprocessable_entity
  end

  def destroy
    ApplicationRecord.transaction do
      identity = @agent.identity
      @agent.assignments.destroy_all
      identity.destroy!   # cascades to access_tokens, sessions, magic_links
      @agent.destroy!     # comments/events nullify creator per upstream behavior
    end
    head :no_content
  end

  private
    def set_agent
      @agent = Current.account.users.where(role: :agent).find(params[:id])
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    def agent_params
      params.expect(agent: [ :name, :slug, :webhook_url, :all_access_boards, :permission ])
    end

    # Writes both fields through the existing User#settings API (see Step 4.5).
    # If the inspection in 4.5 revealed a different settings shape, adjust this
    # method to match — keep the call site (create/update) unchanged.
    def apply_agent_settings(user, params_hash)
      user.settings.webhook_url       = params_hash[:webhook_url] if params_hash.key?(:webhook_url)
      user.settings.all_access_boards = params_hash.fetch(:all_access_boards, true) if params_hash.key?(:all_access_boards) || user.settings.all_access_boards.nil?
      user.save!
    end
end
```

- [ ] **Step 4.7: Build jbuilder views**

`app/views/agents/_agent.json.jbuilder`:

```ruby
json.cache! agent do
  json.(agent, :id, :name, :active)
  json.slug agent.identity.email_address.split("@").first
  json.email_address agent.identity.email_address
  json.webhook_url agent.settings.webhook_url
  json.all_access_boards agent.settings.all_access_boards
  json.permission agent.identity.access_tokens.order(:created_at).last&.permission
  json.created_at agent.created_at.utc
  json.last_active_at agent.updated_at.utc
  json.assigned_cards_count agent.assigned_cards.count
  json.completed_cards_count Event.where(creator: agent, action: "card_agent_completed").count
  json.url agent_url(agent)
end
```

`app/views/agents/index.json.jbuilder`:

```ruby
json.array! @agents, partial: "agents/agent", as: :agent
```

`app/views/agents/show.json.jbuilder`:

```ruby
json.partial! "agents/agent", agent: @agent
```

`app/views/agents/create.json.jbuilder`:

```ruby
json.partial! "agents/agent", agent: @agent
json.initial_token do
  json.id @initial_token.id
  json.token @initial_token.token
  json.permission @initial_token.permission
  json.description @initial_token.description
end
```

- [ ] **Step 4.8: Run controller tests, iterate**

```bash
bin/rails test test/controllers/agents_controller_test.rb -v
```

Fix any compile / route / view errors until green.

- [ ] **Step 4.9: Write failing tests for tokens sub-controller**

Create `test/controllers/agents/tokens_controller_test.rb`:

```ruby
require "test_helper"

class Agents::TokensControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:fizzy)
    @admin = users(:david)
    @admin_token = @admin.identity.access_tokens.create!(description: "test", permission: :write).token
    @agent = users(:review_bot)
  end

  test "admin can rotate agent token (create returns plaintext once)" do
    assert_difference -> { @agent.identity.access_tokens.count } => 1 do
      post "#{@account.slug}/agents/#{@agent.id}/tokens",
        params: { token: { description: "rotation" } }.to_json,
        headers: bearer(@admin_token).merge("Accept" => "application/json", "Content-Type" => "application/json")
    end
    assert_response :created
    assert response.parsed_body["token"].present?
  end

  test "admin can list agent tokens (plaintext NOT returned)" do
    @agent.identity.access_tokens.create!(description: "existing", permission: :read)
    get "#{@account.slug}/agents/#{@agent.id}/tokens",
      headers: bearer(@admin_token).merge("Accept" => "application/json")
    assert_response :ok
    assert response.parsed_body.first["description"] == "existing"
    refute response.parsed_body.first.key?("token"), "Plaintext token must not appear in list"
  end

  test "admin can revoke a single token" do
    token = @agent.identity.access_tokens.create!(description: "to_delete", permission: :read)
    delete "#{@account.slug}/agents/#{@agent.id}/tokens/#{token.id}",
      headers: bearer(@admin_token).merge("Accept" => "application/json")
    assert_response :no_content
    assert_nil Identity::AccessToken.find_by(id: token.id)
  end

  test "agent cannot rotate its own token" do
    agent_token = @agent.identity.access_tokens.create!(description: "agent-self", permission: :write).token
    post "#{@account.slug}/agents/#{@agent.id}/tokens",
      params: { token: { description: "self-rotate" } }.to_json,
      headers: bearer(agent_token).merge("Accept" => "application/json", "Content-Type" => "application/json")
    assert_response :forbidden
  end

  private
    def bearer(token)
      { "Authorization" => "Bearer #{token}" }
    end
end
```

- [ ] **Step 4.10: Implement `Agents::TokensController`**

Create `app/controllers/agents/tokens_controller.rb`:

```ruby
class Agents::TokensController < ApplicationController
  before_action :ensure_admin
  before_action :set_agent

  def index
    @tokens = @agent.identity.access_tokens.order(created_at: :desc)
  end

  def create
    @token = @agent.identity.access_tokens.create!(
      description: params.dig(:token, :description) || "Rotated",
      permission: params.dig(:token, :permission) || "write"
    )
    render :create, status: :created
  end

  def destroy
    token = @agent.identity.access_tokens.find(params[:id])
    token.destroy!
    head :no_content
  end

  private
    def set_agent
      @agent = Current.account.users.where(role: :agent).find(params[:agent_id])
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end
end
```

- [ ] **Step 4.11: Build token views**

`app/views/agents/tokens/index.json.jbuilder`:

```ruby
json.array! @tokens do |token|
  json.(token, :id, :description, :permission)
  json.created_at token.created_at.utc
end
```

`app/views/agents/tokens/create.json.jbuilder`:

```ruby
json.id @token.id
json.token @token.token
json.description @token.description
json.permission @token.permission
json.created_at @token.created_at.utc
```

- [ ] **Step 4.12: Run tests, iterate to green**

```bash
bin/rails test test/controllers/agents/tokens_controller_test.rb -v
```

- [ ] **Step 4.13: Build `Agents::BoardAccessesController` analogously**

Create `app/controllers/agents/board_accesses_controller.rb`:

```ruby
class Agents::BoardAccessesController < ApplicationController
  before_action :ensure_admin
  before_action :set_agent

  def index
    @accesses = @agent.accesses.includes(:board)
  end

  def create
    board = Current.account.boards.find(params.dig(:board_access, :board_id))
    @access = Access.find_or_create_by!(user: @agent, board: board)
    render :show, status: :created
  end

  def destroy
    Access.where(user: @agent, board_id: params[:id]).destroy_all
    head :no_content
  end

  private
    def set_agent
      @agent = Current.account.users.where(role: :agent).find(params[:agent_id])
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end
end
```

Write parallel tests in `test/controllers/agents/board_accesses_controller_test.rb` (mirror token tests). Build minimal jbuilder views. Run until green.

- [ ] **Step 4.14: Full CI**

```bash
bin/ci
```

Expected: all green. If `bin/rails routes | grep agent` shows routes are wired correctly, you're good.

- [ ] **Step 4.15: Commit**

```bash
git add config/routes.rb \
        app/controllers/agents_controller.rb \
        app/controllers/agents/ \
        app/views/agents/ \
        test/controllers/agents_controller_test.rb \
        test/controllers/agents/ \
        test/fixtures/users.yml \
        test/fixtures/identities.yml
git commit -m "[jetkb] Add Agents namespace with CRUD, tokens, and board accesses

Admins can create and manage AI agent users from a new
/:account/agents endpoint family:

- POST creates Identity + User(role: agent) + initial access token
  in one transaction. Token plaintext is returned ONCE and stored
  identically to existing Identity::AccessToken records.
- Per-agent token rotation lives at /:account/agents/:id/tokens.
- Board grants for non-all-access boards live at
  /:account/agents/:id/board_accesses.

Synthetic email <slug>@agent.local satisfies the existing
Identity EMAIL_REGEXP validator without ever resolving to a real
mailbox. Slug is immutable after creation.

All endpoints are admin-gated; agents themselves receive 403."
```

(`[jetkb]` — pure fork-only namespace.)

---

## Task 5: PR-5 — `Cards::AgentCompletionsController`

**Files:**
- Create: `app/controllers/cards/agent_completions_controller.rb`
- Create: `app/views/cards/agent_completions/create.json.jbuilder`
- Modify: `config/routes.rb` (add `resource :agent_completion, only: %i[ create ]` inside `resources :cards do scope module: :cards do ... end end`)
- Create: `test/controllers/cards/agent_completions_controller_test.rb`

**Goal:** Expose `POST /:account/cards/:n/agent_completion` backed by `Card::AgentCompletion.record!` from Task 3.

- [ ] **Step 5.1: Add route**

In `config/routes.rb`, inside the existing `resources :cards do scope module: :cards do ... end end` block, add:

```ruby
      resource :agent_completion, only: %i[ create ]
```

- [ ] **Step 5.2: Write failing controller tests**

Create `test/controllers/cards/agent_completions_controller_test.rb`:

```ruby
require "test_helper"

class Cards::AgentCompletionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:fizzy)
    @card = cards(:plant_a_garden)
    @agent = users(:review_bot)
    @agent_token = @agent.identity.access_tokens.create!(description: "x", permission: :write).token
    @card.assignments.create!(assignee: @agent, assigner: users(:david))
  end

  test "agent completes assigned card" do
    post "#{@account.slug}/cards/#{@card.number}/agent_completion",
      params: { agent_completion: { result: "succeeded", summary: "Done.", outcome: "closed" } }.to_json,
      headers: bearer(@agent_token).merge("Accept" => "application/json", "Content-Type" => "application/json")
    assert_response :created
    body = response.parsed_body
    assert_equal "succeeded", body["result"]
    assert_equal "closed", body["outcome"]
    assert_predicate @card.reload, :closed?
  end

  test "human cannot complete a card as agent" do
    human_token = users(:david).identity.access_tokens.create!(description: "x", permission: :write).token
    post "#{@account.slug}/cards/#{@card.number}/agent_completion",
      params: { agent_completion: { result: "succeeded", summary: "x", outcome: "closed" } }.to_json,
      headers: bearer(human_token).merge("Accept" => "application/json", "Content-Type" => "application/json")
    assert_response :forbidden
  end

  test "agent cannot complete card they aren't assigned to" do
    @card.assignments.destroy_all
    post "#{@account.slug}/cards/#{@card.number}/agent_completion",
      params: { agent_completion: { result: "succeeded", summary: "x", outcome: "closed" } }.to_json,
      headers: bearer(@agent_token).merge("Accept" => "application/json", "Content-Type" => "application/json")
    assert_response :forbidden
  end

  test "Idempotency-Key dedupes repeat calls" do
    key = SecureRandom.uuid
    headers = bearer(@agent_token).merge("Accept" => "application/json", "Content-Type" => "application/json", "Idempotency-Key" => key)
    body = { agent_completion: { result: "succeeded", summary: "Done.", outcome: "closed" } }.to_json

    assert_difference -> { @card.comments.count } => 1 do
      post "#{@account.slug}/cards/#{@card.number}/agent_completion", params: body, headers: headers
      post "#{@account.slug}/cards/#{@card.number}/agent_completion", params: body, headers: headers
    end
  end

  test "missing required field result returns 422" do
    post "#{@account.slug}/cards/#{@card.number}/agent_completion",
      params: { agent_completion: { summary: "x", outcome: "closed" } }.to_json,
      headers: bearer(@agent_token).merge("Accept" => "application/json", "Content-Type" => "application/json")
    assert_response :unprocessable_entity
  end

  private
    def bearer(token)
      { "Authorization" => "Bearer #{token}" }
    end
end
```

- [ ] **Step 5.3: Implement controller**

Create `app/controllers/cards/agent_completions_controller.rb`:

```ruby
class Cards::AgentCompletionsController < ApplicationController
  include CardScoped

  before_action :ensure_agent
  before_action :ensure_assigned

  def create
    raw = params.expect(agent_completion: [ :result, :summary, :details_html, :outcome, artifacts: [ :label, :url ], metrics: {} ])

    @completion = Card::AgentCompletion.record!(
      card: @card,
      agent: Current.user,
      result: raw[:result],
      summary: raw[:summary],
      details_html: raw[:details_html],
      outcome: raw[:outcome],
      artifacts: raw[:artifacts] || [],
      metrics: raw[:metrics] || {},
      idempotency_key: request.headers["Idempotency-Key"]
    )

    render :create, status: :created, location: card_url(@card)
  rescue Card::AgentCompletion::NotAssigned
    head :forbidden
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.as_json }, status: :unprocessable_entity
  rescue ArgumentError => e
    render json: { errors: { base: [ e.message ] } }, status: :unprocessable_entity
  end

  private
    def ensure_agent
      head :forbidden unless Current.user&.agent?
    end

    def ensure_assigned
      head :forbidden unless @card.assigned_to?(Current.user)
    end
end
```

- [ ] **Step 5.4: Build response view**

Create `app/views/cards/agent_completions/create.json.jbuilder`:

```ruby
json.(@completion, :id)
json.card_number @completion.card.number
json.result @completion.result
json.outcome @completion.particulars["outcome"]
json.comment_id @completion.comment_id
json.event_id @completion.event_id
json.created_at @completion.created_at.utc
```

- [ ] **Step 5.5: Run tests, iterate**

```bash
bin/rails test test/controllers/cards/agent_completions_controller_test.rb -v
```

- [ ] **Step 5.6: Commit**

```bash
git add config/routes.rb \
        app/controllers/cards/agent_completions_controller.rb \
        app/views/cards/agent_completions/ \
        test/controllers/cards/agent_completions_controller_test.rb
git commit -m "[jetkb] Add agent_completion endpoint

POST /:account/cards/:n/agent_completion is the atomic sugar
endpoint for an agent reporting completion. Behind the route is
Card::AgentCompletion.record! which writes the comment, applies
the outcome (close / triage / postpone / no-op), unassigns the
agent, and emits a card_agent_completed event in one transaction.

The endpoint enforces:
- Current.user.agent? (humans get 403)
- card.assigned_to?(current_agent) (unassigned agents get 403)
- Idempotency-Key request header (replays return the first record)"
```

(`[jetkb]`.)

---

## Task 6: PR-6 — Webhook fan-out for agent events

**Files:**
- Modify: `app/models/event.rb` (or the existing webhook dispatch job)
- Or create: `app/models/event/agent_fanout.rb` (Concern)
- Modify: `app/models/card/assignable.rb` if the event creation is centralised there
- Create: `test/models/event/agent_fanout_test.rb`

**Goal:** When an `Event` with action `card_assigned` is committed and any of its assignees is `role=agent`, **also** emit a parallel `card_assigned_to_agent` event so subscribers can target it directly.

- [ ] **Step 6.1: Locate where `card_assigned` events are tracked**

```bash
grep -rn "card_assigned\|track_event :assigned" app/models app/controllers --include="*.rb"
```

Likely hit: `app/models/card/assignable.rb` `track_event :assigned`. Locate the exact line; this is where we'll add the agent fan-out.

- [ ] **Step 6.2: Write failing test**

Create `test/models/event/agent_fanout_test.rb`:

```ruby
require "test_helper"

class Event::AgentFanoutTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:fizzy)
    @card = cards(:plant_a_garden)
    @human = users(:jz)
    @agent = users(:review_bot)
  end

  test "assigning a human does not emit card_assigned_to_agent" do
    Current.user = users(:david)
    @card.toggle_assignment(@human)
    actions = Event.where(eventable: @card).pluck(:action)
    assert_includes actions, "card_assigned"
    refute_includes actions, "card_assigned_to_agent"
  end

  test "assigning an agent emits both card_assigned and card_assigned_to_agent" do
    Current.user = users(:david)
    @card.toggle_assignment(@agent)
    actions = Event.where(eventable: @card).pluck(:action)
    assert_includes actions, "card_assigned"
    assert_includes actions, "card_assigned_to_agent"
  end

  test "agent fanout event has same assignee particulars" do
    Current.user = users(:david)
    @card.toggle_assignment(@agent)
    fanout = Event.where(eventable: @card, action: "card_assigned_to_agent").last
    refute_nil fanout
    assert_equal [ @agent.id ], fanout.particulars["assignee_ids"]
  end
end
```

- [ ] **Step 6.3: Run, confirm failure**

```bash
bin/rails test test/models/event/agent_fanout_test.rb -v
```

- [ ] **Step 6.4: Add fan-out logic**

In `app/models/card/assignable.rb`, modify the private `assign` method:

```ruby
    def assign(user)
      assignment = assignments.create assignee: user, assigner: Current.user

      if assignment.persisted?
        watch_by user
        track_event :assigned, assignee_ids: [ user.id ]
        track_event :assigned_to_agent, assignee_ids: [ user.id ] if user.agent?
      end
    rescue ActiveRecord::RecordNotUnique
      # Already assigned
    end
```

- [ ] **Step 6.5: Run, iterate**

```bash
bin/rails test test/models/event/agent_fanout_test.rb -v
```

Expected: green. If the second test fails because `track_event :assigned_to_agent` creates an action `card_assigned_to_agent` (verify the upstream `track_event` convention — it prefixes with the model name), that's the desired behavior.

- [ ] **Step 6.6: Confirm webhook dispatch picks up the new action**

```bash
bin/rails test test/models/webhook_test.rb test/jobs/event/webhook_dispatch_job_test.rb -v
```

(Existing tests should still pass — we only added a new permitted action, the dispatch mechanism is unchanged.)

- [ ] **Step 6.7: Commit**

```bash
git add app/models/card/assignable.rb test/models/event/agent_fanout_test.rb
git commit -m "[jetkb] Fan out card_assigned_to_agent event for agent assignees

When an assignment lands on a role=agent user, emit a parallel
card_assigned_to_agent event in addition to the standard
card_assigned. Webhook subscribers can then route agent
assignments to dedicated runners without filtering the global
assignment feed. The two events share assignee_ids particulars
so a subscriber that listens to only the new action receives the
same context."
```

(`[jetkb]` — touches an upstream file, fork-specific behavior.)

---

## Task 7: PR-7 — `rack-attack` + `jetkb_rate_limits.rb`

**Files:**
- Modify: `Gemfile`, `Gemfile.lock`
- Modify: `config/application.rb` or `config/initializers/` (insert `Rack::Attack` middleware)
- Create: `config/initializers/jetkb_rate_limits.rb`
- Create: `test/integration/agent_rate_limit_test.rb`

**Goal:** Per-agent throttle on the agent_completion endpoint and on agent CRUD operations.

- [ ] **Step 7.1: Add gem**

Append to `Gemfile`:

```ruby
gem "rack-attack"
```

Then:

```bash
bundle install
```

Verify in `Gemfile.lock` that `rack-attack` is present.

- [ ] **Step 7.2: Insert middleware**

If upstream already includes `Rack::Attack` (unlikely), do nothing. Otherwise, add to `config/application.rb` inside `class Application < Rails::Application`:

```ruby
    config.middleware.use Rack::Attack
```

- [ ] **Step 7.3: Write failing test**

Create `test/integration/agent_rate_limit_test.rb`:

```ruby
require "test_helper"

class AgentRateLimitTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:fizzy)
    @card = cards(:plant_a_garden)
    @agent = users(:review_bot)
    @token = @agent.identity.access_tokens.create!(description: "x", permission: :write).token
    @card.assignments.create!(assignee: @agent, assigner: users(:david))
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  end

  test "agent_completion 61st call in a minute returns 429" do
    headers = { "Authorization" => "Bearer #{@token}", "Accept" => "application/json", "Content-Type" => "application/json" }
    body    = { agent_completion: { result: "succeeded", summary: "x", outcome: "none" } }.to_json

    60.times do
      post "#{@account.slug}/cards/#{@card.number}/agent_completion", params: body, headers: headers
      assert_response :created
    end

    post "#{@account.slug}/cards/#{@card.number}/agent_completion", params: body, headers: headers
    assert_response :too_many_requests
    assert response.headers["Retry-After"].present?
  end
end
```

(60 calls is slow. Acceptable for one integration test; consider using `--seed` excluding if too slow.)

- [ ] **Step 7.4: Configure throttles**

Create `config/initializers/jetkb_rate_limits.rb`:

```ruby
return unless defined?(Rack::Attack)

Rack::Attack.throttled_responder = ->(req) {
  retry_after = (req.env["rack.attack.match_data"] || {})[:period] || 60
  [ 429, { "Content-Type" => "application/json", "Retry-After" => retry_after.to_s }, [ { error: "rate_limited" }.to_json ] ]
}

Rack::Attack.throttle("agent_completion_per_minute", limit: 60, period: 60.seconds) do |req|
  if req.path.match?(%r{/cards/\d+/agent_completion}) && req.post?
    JetkbBearerSubject.discriminator(req)
  end
end

Rack::Attack.throttle("agent_completion_per_day", limit: 5_000, period: 1.day) do |req|
  if req.path.match?(%r{/cards/\d+/agent_completion}) && req.post?
    JetkbBearerSubject.discriminator(req)
  end
end

Rack::Attack.throttle("agent_create_per_hour", limit: 10, period: 1.hour) do |req|
  if req.path.match?(%r{/agents\z}) && req.post?
    JetkbBearerSubject.discriminator(req)
  end
end

Rack::Attack.throttle("agent_token_create_per_day", limit: 20, period: 1.day) do |req|
  if req.path.match?(%r{/agents/[^/]+/tokens\z}) && req.post?
    JetkbBearerSubject.discriminator(req)
  end
end

module JetkbBearerSubject
  def self.discriminator(req)
    if (header = req.env["HTTP_AUTHORIZATION"]) && header.start_with?("Bearer ")
      token = header.split(" ", 2).last
      Digest::SHA256.hexdigest(token)[0, 32]
    end
  end
end
```

(The discriminator hashes the token so the cache key never leaks the raw value.)

- [ ] **Step 7.5: Run test**

```bash
bin/rails test test/integration/agent_rate_limit_test.rb -v
```

Expected: passes after some seconds. If too slow, lower the limits in the initializer using `Rails.env.test? ? 5 : 60` for the test path — but that mixes test config into prod, so prefer to keep the real limit and reduce iterations:

Alternative: stub the limit via env var:

```ruby
AGENT_COMPLETION_PER_MINUTE = ENV.fetch("AGENT_COMPLETION_PER_MINUTE", 60).to_i
Rack::Attack.throttle("agent_completion_per_minute", limit: AGENT_COMPLETION_PER_MINUTE, period: 60.seconds) do |req|
  ...
end
```

In the test, set `ENV["AGENT_COMPLETION_PER_MINUTE"] = "3"` and assert 4th call is 429.

- [ ] **Step 7.6: Commit**

```bash
git add Gemfile Gemfile.lock config/application.rb config/initializers/jetkb_rate_limits.rb test/integration/agent_rate_limit_test.rb
git commit -m "[jetkb] Add rack-attack rate limits for agent endpoints

- POST /:account/cards/:n/agent_completion: 60/min, 5000/day per agent token
- POST /:account/agents: 10/hour per admin token
- POST /:account/agents/:id/tokens: 20/day per token

Discriminator hashes the bearer token so the cache key never
contains the raw secret. All throttles return 429 with a
Retry-After header that the @jetkb/core client uses for
exponential backoff."
```

(`[jetkb]`.)

---

## Task 8: PR-8 — i18n + zh-CN + branding initializer

**Files:**
- Modify: `config/locales/en.yml` (append agent-related keys)
- Create: `config/locales/zh-CN.yml` (or modify if exists)
- Create: `config/initializers/jetkb_branding.rb`
- Test (modify): existing tests that depend on i18n lookups

**Goal:** All agent-related strings come from i18n; provide zh-CN; centralise brand-name constants.

- [ ] **Step 8.1: Append en.yml keys**

In `config/locales/en.yml`, append (mind YAML indentation against the existing `en:` root):

```yaml
  agents:
    page_title: "Agents"
    new: "New agent"
    create_button: "Create agent"
    fields:
      name: "Display name"
      slug: "Slug"
      webhook_url: "Webhook URL"
      all_access_boards: "Access to all open boards"
      permission: "Permission"
    validation:
      slug_taken: "is already taken in this account"
      slug_format: "may only contain lowercase letters, numbers, and hyphens"
    flash:
      created: "Agent created"
      token_rotated: "Token rotated. Copy it now — it won't be shown again."
      destroyed: "Agent deleted"
    list:
      empty: "No agents yet. Create one to delegate tasks to AI."
      assigned_count:
        zero: "No active assignments"
        one: "1 active assignment"
        other: "%{count} active assignments"
  cards:
    agent_completions:
      results:
        succeeded: "Completed"
        failed: "Failed"
        cancelled: "Cancelled"
        needs_human: "Needs human review"
```

- [ ] **Step 8.2: Create or update zh-CN.yml**

Check if `config/locales/zh-CN.yml` exists. If yes, **append** (never duplicate the `zh-CN:` root — see memory: YAML duplicate top-level keys). If no, create with full structure.

```bash
ls config/locales/zh-CN.yml 2>&1
```

If absent, create:

```yaml
zh-CN:
  agents:
    page_title: "Agent"
    new: "新建 Agent"
    create_button: "创建 Agent"
    fields:
      name: "显示名称"
      slug: "标识符"
      webhook_url: "Webhook 地址"
      all_access_boards: "可访问所有开放看板"
      permission: "权限"
    validation:
      slug_taken: "在本账号下已存在"
      slug_format: "只能包含小写字母、数字、连字符"
    flash:
      created: "Agent 已创建"
      token_rotated: "Token 已轮换。请立即复制 —— 不会再次显示。"
      destroyed: "Agent 已删除"
    list:
      empty: "还没有 Agent。创建一个以便把任务委托给 AI。"
      assigned_count:
        other: "%{count} 个进行中任务"
  cards:
    agent_completions:
      results:
        succeeded: "已完成"
        failed: "失败"
        cancelled: "已取消"
        needs_human: "需人工介入"
```

If present, search for `zh-CN:` at column 0 — there should be exactly one. Append new branches under existing `agents:` / `cards:` if those keys already exist; otherwise add under the root.

- [ ] **Step 8.3: Create branding initializer**

Create `config/initializers/jetkb_branding.rb`:

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

- [ ] **Step 8.4: Verify i18n lookups by running affected tests**

```bash
bin/rails test test/models/card/agent_completion_test.rb test/controllers/agents_controller_test.rb -v
```

`Card::AgentCompletion#render_comment_body` calls `I18n.t("cards.agent_completions.results.#{result}")` — confirm the lookup resolves under both locales:

```bash
bin/rails runner 'puts I18n.t("cards.agent_completions.results.succeeded")'
bin/rails runner 'I18n.with_locale(:"zh-CN") { puts I18n.t("cards.agent_completions.results.succeeded") }'
```

Expected: `Completed` and `已完成`.

- [ ] **Step 8.5: Commit branding initializer**

```bash
git add config/initializers/jetkb_branding.rb
git commit -m "[brand] Add jetkb_branding initializer with env-overridable constants

Centralises brand-facing constants (name, mailer from, docs URL,
CLI command, npm package prefix) so views and docs reference one
source. Env vars override defaults to support white-label
deployments and local development without touching files."
```

- [ ] **Step 8.6: Commit en.yml additions**

```bash
git add config/locales/en.yml
git commit -m "Add agents and agent_completions i18n keys to en.yml

Keys cover the agents management UI (fields, validation, flash,
list strings) and the agent_completion result labels rendered
inside auto-generated comment bodies."
```

(No tag — upstream PR candidate since the keys live in the upstream file.)

- [ ] **Step 8.7: Commit zh-CN.yml additions**

```bash
git add config/locales/zh-CN.yml
git commit -m "[zh-CN] Translate agents and agent_completions strings

Mirrors the en.yml keys added for the new agent management UI
and agent completion result labels."
```

---

## Task 9: PR-9 — End-to-end integration tests

**Files:**
- Create: `test/integration/agent_assign_complete_flow_test.rb`
- Create: `test/integration/agent_multi_tenant_test.rb`
- (Already created in earlier tasks: `agent_api_access_test.rb`, `agent_rate_limit_test.rb`)

**Goal:** Validate the full assignment → webhook → agent → completion → webhook loop, plus tenant isolation.

- [ ] **Step 9.1: Write the assign-complete flow test**

Create `test/integration/agent_assign_complete_flow_test.rb`:

```ruby
require "test_helper"

class AgentAssignCompleteFlowTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:fizzy)
    @board   = boards(:fizzy)
    @card    = cards(:plant_a_garden)
    @admin   = users(:david)
    @admin_token = @admin.identity.access_tokens.create!(description: "test", permission: :write).token
    @webhook = @board.webhooks.create!(
      name: "Agent hook",
      url: "https://hook.example.com/jetkb",
      subscribed_actions: [ "card_assigned_to_agent", "card_agent_completed" ]
    )
  end

  test "full loop: create agent, assign card, agent completes, both webhooks fire" do
    # 1. Create agent
    post "#{@account.slug}/agents",
      params: { agent: { name: "Flow Bot", slug: "flow-bot" } }.to_json,
      headers: bearer(@admin_token).merge("Accept" => "application/json", "Content-Type" => "application/json")
    assert_response :created
    agent_id = response.parsed_body["id"]
    agent_token = response.parsed_body.dig("initial_token", "token")

    # 2. Assign card to agent
    assert_enqueued_with(job: Event::WebhookDispatchJob) do
      post "#{@account.slug}/cards/#{@card.number}/assignments",
        params: { assignee_id: agent_id }.to_json,
        headers: bearer(@admin_token).merge("Accept" => "application/json", "Content-Type" => "application/json")
      assert_response :success
    end

    assert_includes Event.where(eventable: @card).pluck(:action), "card_assigned"
    assert_includes Event.where(eventable: @card).pluck(:action), "card_assigned_to_agent"

    # 3. Agent reports completion
    assert_enqueued_with(job: Event::WebhookDispatchJob) do
      post "#{@account.slug}/cards/#{@card.number}/agent_completion",
        params: { agent_completion: { result: "succeeded", summary: "All done.", outcome: "closed" } }.to_json,
        headers: bearer(agent_token).merge("Accept" => "application/json", "Content-Type" => "application/json", "Idempotency-Key" => SecureRandom.uuid)
      assert_response :created
    end

    # 4. Verify final state
    @card.reload
    assert_predicate @card, :closed?
    refute @card.assigned_to?(Current.account.users.find(agent_id))
    assert_equal "card_agent_completed", Event.where(eventable: @card).order(:created_at).last.action
    assert_equal 1, @card.comments.where(creator_id: agent_id).count
  end

  private
    def bearer(token)
      { "Authorization" => "Bearer #{token}" }
    end
end
```

- [ ] **Step 9.2: Write multi-tenant isolation test**

Create `test/integration/agent_multi_tenant_test.rb`:

```ruby
require "test_helper"

class AgentMultiTenantTest < ActionDispatch::IntegrationTest
  setup do
    @account_x = accounts(:fizzy)
    @account_y = accounts(:initech)
    @agent_x = users(:review_bot)        # belongs to fizzy
    @token_x = @agent_x.identity.access_tokens.create!(description: "x", permission: :write).token
  end

  test "agent token from account X cannot list cards in account Y" do
    get "#{@account_y.slug}/cards",
      headers: bearer(@token_x).merge("Accept" => "application/json")
    refute_equal 200, response.status, "Must not return success cross-account"
    assert_includes [ 401, 403, 404 ], response.status
  end

  test "agent_completion on a card in account Y returns 404" do
    other_card = cards(:initech_card)  # adjust to a real fixture
    post "#{@account_y.slug}/cards/#{other_card.number}/agent_completion",
      params: { agent_completion: { result: "succeeded", summary: "x", outcome: "none" } }.to_json,
      headers: bearer(@token_x).merge("Accept" => "application/json", "Content-Type" => "application/json")
    assert_response :not_found
  end

  private
    def bearer(token)
      { "Authorization" => "Bearer #{token}" }
    end
end
```

- [ ] **Step 9.3: Run integration suite**

```bash
bin/rails test test/integration/ -v
```

Expected: all green. Iterate on fixture references if any are missing (`cards(:initech_card)` may need an existing fixture name).

- [ ] **Step 9.4: Commit**

```bash
git add test/integration/agent_assign_complete_flow_test.rb \
        test/integration/agent_multi_tenant_test.rb
git commit -m "[jetkb] Integration tests for assign-complete flow and tenant isolation

Cross-controller and cross-job test that:
- creating an agent + assigning a card + completing it produces
  the correct sequence of events, comments, assignment removal,
  and webhook dispatch enqueues
- a token bound to account X cannot operate on cards in
  account Y (404, never 200)"
```

(`[jetkb]`.)

---

## Task 10: PR-10 — API docs + jetKB internal docs

**Files:**
- Create: `docs/api/sections/agents.md`
- Modify: `docs/api/README.md` (add link in TOC)
- Create: `docs/jetkb/agent-integration.md`
- Create: `docs/jetkb/agent-architecture.md`
- Create: `docs/jetkb/agent-qa-checklist.md`

**Goal:** Document everything users and operators need.

- [ ] **Step 10.1: Write `docs/api/sections/agents.md`**

Mirror the style of `docs/api/sections/webhooks.md`. Cover:

- `GET /:account_slug/agents`
- `POST /:account_slug/agents`
- `GET /:account_slug/agents/:id`
- `PATCH /:account_slug/agents/:id`
- `DELETE /:account_slug/agents/:id`
- `GET/POST/DELETE /:account_slug/agents/:id/tokens[/:token_id]`
- `GET/POST/DELETE /:account_slug/agents/:id/board_accesses[/:id]`
- `POST /:account_slug/cards/:n/agent_completion`

For each: request example (curl), parameters table, response shape, error codes. Use the spec's Section 3 (`docs/superpowers/specs/2026-05-14-agent-integration-design.md` §3) as the source of truth for shapes.

- [ ] **Step 10.2: Update API README TOC**

In `docs/api/README.md`, add `- [Agents](sections/agents.md)` between `[Webhooks]` and any natural follow-up section.

- [ ] **Step 10.3: Write `docs/jetkb/agent-integration.md`**

Audience: an engineer about to build their own agent runner. Sections:

1. Quickstart (create agent via UI, copy token, paste into env)
2. Receive webhooks: minimal Express / Fastify / FastAPI handlers with signature verification
3. Read assigned cards: `GET /:account/cards?assignee_ids[]=<your-user-id>` curl
4. Report completion: POST to `agent_completion` with Idempotency-Key
5. Recommended deployment: webhook → queue → worker → LLM API → completion
6. Security checklist (token rotation, replay window, exponential backoff)
7. Monitoring suggestions (webhook delivery rate, 401 rate, p95 latency)

- [ ] **Step 10.4: Write `docs/jetkb/agent-architecture.md`**

Internal-facing. 2-3 pages. Recap of Section 1 + 2 + 5 of the spec, focused on "why these decisions" rather than "what to type". Cross-link to the spec for full detail.

- [ ] **Step 10.5: Write `docs/jetkb/agent-qa-checklist.md`**

Copy the 10-item checklist from spec §7.10 verbatim. Format as a `- [ ]` Markdown checklist so reviewers can tick items.

- [ ] **Step 10.6: Verify brand audit still passes**

```bash
git grep -i fizzy -- 'app/views/**' 'app/mailers/**' 'config/locales/**' 'public/**' 'docs/**' 'README.md'
```

Expected: no hits in user-facing surfaces (some hits in upstream docs are fine; new docs should reference jetKB).

- [ ] **Step 10.7: Commit**

```bash
git add docs/api/sections/agents.md docs/api/README.md
git commit -m "Add agents API documentation

New /agents namespace + agent_completion endpoint documented
alongside existing API sections."
```

(No tag — upstream PR candidate; the API doc benefits Fizzy too if they accept the agent role.)

```bash
git add docs/jetkb/agent-integration.md docs/jetkb/agent-architecture.md docs/jetkb/agent-qa-checklist.md
git commit -m "[jetkb] Add agent integration guide, architecture overview, and QA checklist

- agent-integration.md walks an engineer through building their
  own agent runner against jetKB
- agent-architecture.md is the internal design reference
- agent-qa-checklist.md is the pre-release manual verification
  procedure"
```

(`[jetkb]`.)

---

## Final verification

- [ ] **Run the full CI suite**

```bash
bin/ci
```

Expected: all green.

- [ ] **Verify integer-stable enum guard test runs in CI**

```bash
bin/rails test test/models/user/role_test.rb -n "/integer_value/"
```

Expected: passes — guarding future upstream merges.

- [ ] **Run brand audit one more time**

```bash
git grep -i fizzy -- 'app/views/**' 'app/mailers/**' 'config/locales/**' 'public/**' 'docs/**' 'README.md'
```

Expected: no user-facing leaks.

- [ ] **Confirm DB schema files are consistent with active adapter**

```bash
git status db/
```

Expected: only the active adapter's dump file shows changes (either `schema.rb` or `structure.sql`, never both).

- [ ] **Open upstream PRs for the candidate commits**

Identify the no-prefix commits from Tasks 1, 6 (the additions to `PERMITTED_ACTIONS`), 8 (en.yml keys), and 10 (api docs). Cherry-pick or format-patch them to a branch off `upstream/main` and open PRs at `basecamp/fizzy`. These are upstream-friendly and shrink jetKB's fork surface if accepted.

- [ ] **Tag the milestone**

```bash
git tag jetkb-agents-v0.1-server -m "Server-side agent integration complete (PR-1..PR-10)"
git push origin jetkb-agents-v0.1-server
```

This tag is what the CLI plan's `apps/e2e/` docker-compose pulls when building the jetKB image for cross-stack tests.

---

## Spec coverage check

Quick map from spec sections to this plan's tasks:

| Spec section | Plan task |
|---|---|
| §2.1-2.3 (role, system vs agent) | Task 1 |
| §2.4 (synthetic email) | Task 4 (controller create logic) |
| §2.5 (api_active?) | Task 1 + Task 2 |
| §2.6 (Access/ACL) | Task 4 (board_accesses) |
| §2.7 (webhook actions) | Task 1 + Task 6 |
| §2.8 (idempotency table) | Task 3 |
| §3.1 (routes) | Task 4 + Task 5 |
| §3.2 (Agents CRUD) | Task 4 |
| §3.3 (agent self-use, existing endpoints) | Task 2 (auth gate) |
| §3.4 (agent_completion) | Task 3 (model) + Task 5 (controller) |
| §3.5 (`is_agent` field) | Task 1 |
| §3.6 (errors) | Tasks 4, 5 |
| §3.7 (rate limits) | Task 7 |
| §5.x (security) | Spread across Tasks 4, 5 (authz), 7 (limit) |
| §6.x (i18n + brand) | Task 8 |
| §7.x (tests) | Tasks 1-9 (TDD throughout) |

Section §3.8 (OpenAPI) is explicitly deferred per spec §3.8 ("YAGNI, P4"). Section §5.4 webhook signature *upgrade* (timestamp + version) is **not** in this plan — it remains an upstream-PR candidate per spec §8.2 and is handled separately.

---

## Companion plan handoff

After this plan reaches "Final verification", proceed to `docs/superpowers/plans/2026-05-14-jetkb-cli-mcp.md` which implements `@jetkb/core`, `@jetkb/cli`, `@jetkb/mcp` and the E2E suite that exercises this server's endpoints.
