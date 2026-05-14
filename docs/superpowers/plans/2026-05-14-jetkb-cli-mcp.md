# jetkb-cli & MCP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a new TypeScript pnpm-workspace repo `jetkb-cli` that ships three packages — `@jetkb/core` (shared HTTP client), `@jetkb/cli` (the `jetkb` command), and `@jetkb/mcp` (the `jetkb-mcp` MCP server) — plus a Docker-compose end-to-end test suite that drives the server endpoints built by the companion plan.

**Architecture:** Single TypeScript monorepo using pnpm workspaces. All three packages share `@jetkb/core` which wraps the JetKB JSON API with an ergonomic resource-oriented client, ETag caching, pagination iterators, and webhook signature verification. CLI uses commander + @inquirer/prompts; MCP uses `@modelcontextprotocol/sdk` with stdio + optional HTTP transport.

**Tech Stack:** Node ≥18, TypeScript 5, pnpm workspace, undici HTTP client, vitest, @modelcontextprotocol/sdk, commander, @inquirer/prompts, changeset for releases, GitHub Actions for CI + npm publish with provenance.

**Companion plan:** `docs/superpowers/plans/2026-05-14-jetkb-server-agent-integration.md` covers the Rails server endpoints. This plan can begin Tasks 1-2 in parallel with server Tasks 1-3; Tasks 3-7 require server Tasks 4-5 to have landed (the agent + agent_completion endpoints must exist for the SDK + E2E to target).

**Spec reference:** `docs/superpowers/specs/2026-05-14-agent-integration-design.md` §4 (CLI + MCP) and §5.7 (client-side security).

**Working directory:** A new Git repository `jetkb-cli` sibling to `jetkb`. Create it at the start of Task 1. This plan file lives in `jetkb` for traceability; commit references in the plan are to the **`jetkb-cli` repo**, not the main jetKB repo.

---

## Task 1 (CLI-1): Repo scaffold + pnpm workspace + tooling

**Files (all in new `jetkb-cli/` repo):**
- `package.json` (root)
- `pnpm-workspace.yaml`
- `tsconfig.base.json`
- `.gitignore`
- `.editorconfig`
- `.npmrc`
- `.changeset/config.json`
- `.github/workflows/ci.yml`
- `README.md`
- `LICENSE`
- `packages/core/package.json` (placeholder)
- `packages/cli/package.json` (placeholder)
- `packages/mcp/package.json` (placeholder)

- [ ] **Step 1.1: Create the repo**

```bash
cd "$(dirname /Volumes/data/projects/jetems/jetkb)"   # parent dir of jetkb
mkdir jetkb-cli && cd jetkb-cli
git init -b main
```

- [ ] **Step 1.2: Root `package.json`**

```json
{
  "name": "jetkb-cli-workspace",
  "private": true,
  "version": "0.0.0",
  "description": "CLI and MCP server for jetKB",
  "license": "MIT",
  "engines": { "node": ">=18" },
  "packageManager": "pnpm@9.0.0",
  "scripts": {
    "build": "pnpm -r --filter './packages/*' build",
    "test": "pnpm -r --filter './packages/*' test",
    "lint": "pnpm -r --filter './packages/*' lint",
    "typecheck": "pnpm -r --filter './packages/*' typecheck",
    "e2e": "pnpm --filter ./apps/e2e test",
    "changeset": "changeset",
    "release": "changeset publish"
  },
  "devDependencies": {
    "@changesets/cli": "^2.27.0",
    "typescript": "^5.4.0"
  }
}
```

- [ ] **Step 1.3: `pnpm-workspace.yaml`**

```yaml
packages:
  - "packages/*"
  - "apps/*"
```

- [ ] **Step 1.4: `tsconfig.base.json`**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "esModuleInterop": true,
    "strict": true,
    "skipLibCheck": true,
    "declaration": true,
    "sourceMap": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "verbatimModuleSyntax": true
  }
}
```

- [ ] **Step 1.5: `.gitignore`**

```
node_modules/
dist/
*.log
.DS_Store
.env
.env.local
coverage/
.tsbuildinfo
.changeset/*-changeset.md
```

- [ ] **Step 1.6: Package placeholders**

`packages/core/package.json`:

```json
{
  "name": "@jetkb/core",
  "version": "0.0.0",
  "type": "module",
  "main": "./dist/index.js",
  "types": "./dist/index.d.ts",
  "files": ["dist"],
  "scripts": {
    "build": "tsc -p tsconfig.json",
    "test": "vitest run",
    "lint": "eslint src",
    "typecheck": "tsc --noEmit"
  }
}
```

`packages/cli/package.json`:

```json
{
  "name": "@jetkb/cli",
  "version": "0.0.0",
  "type": "module",
  "bin": { "jetkb": "./dist/index.js" },
  "main": "./dist/index.js",
  "files": ["dist"],
  "scripts": {
    "build": "tsc -p tsconfig.json",
    "test": "vitest run",
    "lint": "eslint src",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": { "@jetkb/core": "workspace:*" }
}
```

`packages/mcp/package.json`:

```json
{
  "name": "@jetkb/mcp",
  "version": "0.0.0",
  "type": "module",
  "bin": { "jetkb-mcp": "./dist/index.js" },
  "main": "./dist/index.js",
  "files": ["dist"],
  "scripts": {
    "build": "tsc -p tsconfig.json",
    "test": "vitest run",
    "lint": "eslint src",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": { "@jetkb/core": "workspace:*" }
}
```

- [ ] **Step 1.7: GitHub Actions CI workflow**

`.github/workflows/ci.yml`:

```yaml
name: ci
on:
  push: { branches: [main] }
  pull_request:
jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        node: [18, 20, 22]
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v3
        with: { version: 9 }
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node }}
          cache: pnpm
      - run: pnpm install --frozen-lockfile
      - run: pnpm typecheck
      - run: pnpm lint
      - run: pnpm test
      - run: pnpm build
```

- [ ] **Step 1.8: README skeleton**

`README.md`:

```markdown
# jetkb-cli

CLI and MCP server for [jetKB](https://github.com/<org>/jetkb).

## Packages

- [`@jetkb/core`](packages/core) — HTTP client SDK
- [`@jetkb/cli`](packages/cli) — `jetkb` command
- [`@jetkb/mcp`](packages/mcp) — `jetkb-mcp` MCP server for Claude Desktop / Cursor / etc.

## Quickstart

```bash
npm i -g @jetkb/cli
jetkb auth login
jetkb cards list
```

For MCP integration with Claude Desktop, see [packages/mcp/README.md](packages/mcp/README.md).
```

- [ ] **Step 1.9: Install dependencies and validate scaffold**

```bash
pnpm install
pnpm build   # should succeed even with empty packages (or skip if no source yet)
git status
```

- [ ] **Step 1.10: Commit**

```bash
git add .
git commit -m "Initial scaffold: pnpm workspace + three package skeletons + CI

Empty TypeScript packages for @jetkb/core, @jetkb/cli, and
@jetkb/mcp wired into a single pnpm workspace with vitest, eslint,
and tsc configured. GitHub Actions matrix tests Node 18/20/22.
Changeset is set up to manage independent semver per package.

Companion plan: jetkb/docs/superpowers/plans/2026-05-14-jetkb-cli-mcp.md"
```

- [ ] **Step 1.11: Create GitHub repo and push**

```bash
gh repo create <org>/jetkb-cli --public --source=. --remote=origin --push
```

---

## Task 2 (CLI-2): `@jetkb/core` foundation — HTTP client, auth, cards/boards/columns

**Files (all under `jetkb-cli/packages/core/`):**
- `tsconfig.json`
- `src/index.ts`
- `src/client.ts`
- `src/config.ts`
- `src/auth.ts`
- `src/errors.ts`
- `src/types.ts`
- `src/redact.ts`
- `src/resources/cards.ts`
- `src/resources/boards.ts`
- `src/resources/columns.ts`
- `src/__tests__/client.test.ts`
- `src/__tests__/config.test.ts`
- `src/__tests__/cards.test.ts`

- [ ] **Step 2.1: `tsconfig.json`**

```json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "outDir": "./dist",
    "rootDir": "./src"
  },
  "include": ["src/**/*"],
  "exclude": ["**/*.test.ts", "dist"]
}
```

- [ ] **Step 2.2: Install runtime deps**

```bash
cd packages/core
pnpm add undici
pnpm add -D vitest @types/node nock @smithy/util-base64
```

- [ ] **Step 2.3: Write failing test for the client constructor and basic fetch**

`src/__tests__/client.test.ts`:

```typescript
import { describe, it, expect, beforeAll, afterEach, afterAll } from "vitest";
import { JetkbClient } from "../client.js";
import { setGlobalDispatcher, MockAgent } from "undici";

const mockAgent = new MockAgent();
mockAgent.disableNetConnect();
setGlobalDispatcher(mockAgent);

describe("JetkbClient", () => {
  const baseUrl = "https://app.example.test";
  const accountSlug = "/1234567";
  const token = "test-token-abc";

  afterEach(() => mockAgent.assertNoPendingInterceptors());

  it("constructs with explicit credentials", () => {
    const client = new JetkbClient({ baseUrl, accountSlug, token });
    expect(client.baseUrl).toBe(baseUrl);
    expect(client.accountSlug).toBe(accountSlug);
  });

  it("sends Authorization Bearer header", async () => {
    mockAgent.get(baseUrl).intercept({ path: "/1234567/cards.json", method: "GET" })
      .reply(200, [], { headers: { "content-type": "application/json", "etag": "abc" } })
      .matchHeaders({ authorization: `Bearer ${token}`, accept: "application/json" });

    const client = new JetkbClient({ baseUrl, accountSlug, token });
    const page = await client.cards.listPage();
    expect(page.items).toEqual([]);
  });

  it("throws JetkbAuthError on 401", async () => {
    mockAgent.get(baseUrl).intercept({ path: "/1234567/cards.json", method: "GET" })
      .reply(401, { error: "unauthorized" });

    const client = new JetkbClient({ baseUrl, accountSlug, token });
    await expect(client.cards.listPage()).rejects.toThrow("Unauthorized");
  });

  it("returns cached value on 304 with stored ETag", async () => {
    mockAgent.get(baseUrl).intercept({ path: "/1234567/cards.json", method: "GET" })
      .reply(200, [{ id: "c1", number: 1, title: "First" }], { headers: { etag: "v1" } });
    mockAgent.get(baseUrl).intercept({ path: "/1234567/cards.json", method: "GET" })
      .reply(304, "")
      .matchHeaders({ "if-none-match": "v1" });

    const client = new JetkbClient({ baseUrl, accountSlug, token });
    const first = await client.cards.listPage();
    const second = await client.cards.listPage();
    expect(second.items).toEqual(first.items);
  });
});
```

- [ ] **Step 2.4: Run test to confirm failure**

```bash
pnpm --filter @jetkb/core test
```

Expected: import errors — files don't exist yet.

- [ ] **Step 2.5: Implement `errors.ts`**

`src/errors.ts`:

```typescript
export class JetkbError extends Error {
  constructor(message: string) {
    super(message);
    this.name = this.constructor.name;
  }
}

export class JetkbApiError extends JetkbError {
  constructor(
    public readonly status: number,
    public readonly body: unknown,
    public readonly url: string,
    message?: string
  ) {
    super(message ?? `JetKB API error ${status} at ${url}`);
  }
}

export class JetkbAuthError extends JetkbApiError {
  constructor(url: string, body: unknown) {
    super(401, body, url, "Unauthorized — token is missing, expired, or invalid");
  }
}

export class JetkbForbiddenError extends JetkbApiError {
  constructor(url: string, body: unknown) {
    super(403, body, url, "Forbidden — token lacks permission for this resource");
  }
}

export class JetkbNetworkError extends JetkbError {
  constructor(public readonly cause: unknown) {
    super(`Network error: ${cause instanceof Error ? cause.message : String(cause)}`);
  }
}

export class JetkbRateLimitError extends JetkbApiError {
  constructor(public readonly retryAfterSeconds: number, url: string, body: unknown) {
    super(429, body, url, `Rate limited — retry after ${retryAfterSeconds}s`);
  }
}
```

- [ ] **Step 2.6: Implement `redact.ts`**

`src/redact.ts`:

```typescript
export function redactToken(value: string | undefined | null): string {
  if (!value) return "(none)";
  if (value.length < 8) return "***";
  return `${value.slice(0, 4)}...${value.slice(-4)}`;
}
```

- [ ] **Step 2.7: Implement `types.ts`** (initial subset — expand as later resources are added)

```typescript
export interface Card {
  id: string;
  number: number;
  title: string;
  status: "published" | "drafted";
  description?: string;
  description_html?: string;
  closed?: boolean;
  golden?: boolean;
  last_active_at: string;
  created_at: string;
  url: string;
  board: Board;
  creator: User;
  column?: Column;
  tags?: string[];
}

export interface Board {
  id: string;
  name: string;
  all_access: boolean;
  created_at: string;
  url: string;
  creator: User;
}

export interface Column {
  id: string;
  name: string;
  color?: { name: string; value: string };
  created_at: string;
}

export interface User {
  id: string;
  name: string;
  role: "owner" | "admin" | "member" | "system" | "agent";
  active: boolean;
  is_agent: boolean;
  email_address?: string;
  created_at: string;
  url?: string;
}
```

- [ ] **Step 2.8: Implement `client.ts`**

```typescript
import { request } from "undici";
import {
  JetkbApiError, JetkbAuthError, JetkbForbiddenError,
  JetkbNetworkError, JetkbRateLimitError
} from "./errors.js";
import { CardsResource } from "./resources/cards.js";
import { BoardsResource } from "./resources/boards.js";
import { ColumnsResource } from "./resources/columns.js";

export interface JetkbClientOptions {
  baseUrl: string;
  accountSlug: string;   // e.g. "/1234567" — leading slash required
  token: string;
  cache?: boolean;       // default true
  debug?: boolean;
}

interface CacheEntry { etag: string; body: unknown; }

export class JetkbClient {
  readonly baseUrl: string;
  readonly accountSlug: string;
  private readonly token: string;
  private readonly cacheEnabled: boolean;
  private readonly cache = new Map<string, CacheEntry>();
  readonly debug: boolean;

  readonly cards: CardsResource;
  readonly boards: BoardsResource;
  readonly columns: ColumnsResource;

  constructor(opts: JetkbClientOptions) {
    if (!opts.accountSlug.startsWith("/")) {
      throw new Error("accountSlug must start with '/'");
    }
    this.baseUrl = opts.baseUrl.replace(/\/$/, "");
    this.accountSlug = opts.accountSlug;
    this.token = opts.token;
    this.cacheEnabled = opts.cache ?? true;
    this.debug = opts.debug ?? false;

    this.cards = new CardsResource(this);
    this.boards = new BoardsResource(this);
    this.columns = new ColumnsResource(this);
  }

  async fetch<T>(method: string, path: string, body?: unknown): Promise<{ data: T; nextLink: string | null; etag: string | null }> {
    const url = `${this.baseUrl}${path}`;
    const headers: Record<string, string> = {
      "Authorization": `Bearer ${this.token}`,
      "Accept": "application/json",
    };
    if (body !== undefined) headers["Content-Type"] = "application/json";

    const cacheKey = `${method} ${url}`;
    if (this.cacheEnabled && method === "GET") {
      const cached = this.cache.get(cacheKey);
      if (cached) headers["If-None-Match"] = cached.etag;
    }

    let response: Awaited<ReturnType<typeof request>>;
    try {
      response = await request(url, {
        method: method as "GET" | "POST" | "PATCH" | "DELETE",
        headers,
        body: body !== undefined ? JSON.stringify(body) : undefined,
      });
    } catch (e) {
      throw new JetkbNetworkError(e);
    }

    const status = response.statusCode;
    const etag = response.headers["etag"] as string | undefined;
    const linkHeader = response.headers["link"] as string | undefined;
    const nextLink = parseNextLink(linkHeader);

    if (status === 304) {
      const cached = this.cache.get(cacheKey);
      if (!cached) throw new JetkbApiError(304, null, url, "304 without cached value");
      return { data: cached.body as T, nextLink, etag: cached.etag };
    }

    const text = await response.body.text();
    const parsed = text ? JSON.parse(text) : null;

    if (status === 401) throw new JetkbAuthError(url, parsed);
    if (status === 403) throw new JetkbForbiddenError(url, parsed);
    if (status === 429) {
      const retryAfter = parseInt(response.headers["retry-after"] as string ?? "60", 10);
      throw new JetkbRateLimitError(retryAfter, url, parsed);
    }
    if (status >= 400) throw new JetkbApiError(status, parsed, url);

    if (this.cacheEnabled && method === "GET" && etag) {
      this.cache.set(cacheKey, { etag, body: parsed });
    }

    return { data: parsed as T, nextLink, etag: etag ?? null };
  }
}

function parseNextLink(linkHeader: string | undefined): string | null {
  if (!linkHeader) return null;
  const match = linkHeader.match(/<([^>]+)>;\s*rel="next"/);
  return match?.[1] ?? null;
}
```

- [ ] **Step 2.9: Implement `resources/cards.ts`**

```typescript
import type { JetkbClient } from "../client.js";
import type { Card } from "../types.js";

export interface CardListParams {
  assigneeIds?: string[];
  boardIds?: string[];
  columnIds?: string[];
  tagIds?: string[];
  indexedBy?: "all" | "maybe" | "closed" | "not_now" | "stalled" | "postponing_soon" | "golden";
  sortedBy?: "latest" | "newest" | "oldest";
  page?: number;
}

export class CardsResource {
  constructor(private readonly client: JetkbClient) {}

  async listPage(params: CardListParams = {}): Promise<{ items: Card[]; nextUrl: string | null }> {
    const path = `${this.client.accountSlug}/cards.json${stringifyQuery(params)}`;
    const { data, nextLink } = await this.client.fetch<Card[]>("GET", path);
    return { items: data, nextUrl: nextLink };
  }

  async *list(params: CardListParams = {}): AsyncGenerator<Card> {
    let { items, nextUrl } = await this.listPage(params);
    for (const item of items) yield item;
    while (nextUrl) {
      const rel = nextUrl.startsWith("http") ? nextUrl.slice(this.client.baseUrl.length) : nextUrl;
      const { data, nextLink } = await this.client.fetch<Card[]>("GET", rel);
      for (const item of data) yield item;
      nextUrl = nextLink;
    }
  }

  async get(number: number): Promise<Card> {
    const { data } = await this.client.fetch<Card>("GET", `${this.client.accountSlug}/cards/${number}.json`);
    return data;
  }

  async update(number: number, attrs: Partial<Pick<Card, "title" | "description">>): Promise<Card> {
    const { data } = await this.client.fetch<Card>("PUT", `${this.client.accountSlug}/cards/${number}.json`, { card: attrs });
    return data;
  }

  async close(number: number): Promise<void> {
    await this.client.fetch<void>("POST", `${this.client.accountSlug}/cards/${number}/closure.json`);
  }

  async reopen(number: number): Promise<void> {
    await this.client.fetch<void>("DELETE", `${this.client.accountSlug}/cards/${number}/closure.json`);
  }
}

function stringifyQuery(p: CardListParams): string {
  const params = new URLSearchParams();
  if (p.indexedBy) params.set("indexed_by", p.indexedBy);
  if (p.sortedBy) params.set("sorted_by", p.sortedBy);
  if (p.page) params.set("page", String(p.page));
  for (const id of p.assigneeIds ?? []) params.append("assignee_ids[]", id);
  for (const id of p.boardIds ?? []) params.append("board_ids[]", id);
  for (const id of p.columnIds ?? []) params.append("column_ids[]", id);
  for (const id of p.tagIds ?? []) params.append("tag_ids[]", id);
  const qs = params.toString();
  return qs ? `?${qs}` : "";
}
```

- [ ] **Step 2.10: Implement minimal `resources/boards.ts` and `resources/columns.ts`**

`src/resources/boards.ts`:

```typescript
import type { JetkbClient } from "../client.js";
import type { Board } from "../types.js";

export class BoardsResource {
  constructor(private readonly client: JetkbClient) {}

  async list(): Promise<Board[]> {
    const { data } = await this.client.fetch<Board[]>("GET", `${this.client.accountSlug}/boards.json`);
    return data;
  }

  async get(id: string): Promise<Board> {
    const { data } = await this.client.fetch<Board>("GET", `${this.client.accountSlug}/boards/${id}.json`);
    return data;
  }
}
```

`src/resources/columns.ts`:

```typescript
import type { JetkbClient } from "../client.js";
import type { Column } from "../types.js";

export class ColumnsResource {
  constructor(private readonly client: JetkbClient) {}

  async list(boardId: string): Promise<Column[]> {
    const { data } = await this.client.fetch<Column[]>("GET", `${this.client.accountSlug}/boards/${boardId}/columns.json`);
    return data;
  }
}
```

- [ ] **Step 2.11: `src/index.ts`**

```typescript
export { JetkbClient } from "./client.js";
export * from "./errors.js";
export * from "./types.js";
export { redactToken } from "./redact.js";
```

- [ ] **Step 2.12: Run tests, iterate to green**

```bash
pnpm --filter @jetkb/core test
```

- [ ] **Step 2.13: Implement `config.ts` and `auth.ts`**

`src/config.ts`:

```typescript
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { execFileSync } from "node:child_process";

export interface ProfileConfig {
  base_url: string;
  account_slug: string;
  token?: string;
  token_command?: string;
}

export interface JetkbConfig {
  default_profile?: string;
  profiles: Record<string, ProfileConfig>;
}

const CONFIG_PATH = join(homedir(), ".config", "jetkb", "config.toml");

export function readConfig(path = CONFIG_PATH): JetkbConfig | null {
  try {
    const text = readFileSync(path, "utf8");
    return parseToml(text);
  } catch (e: any) {
    if (e.code === "ENOENT") return null;
    throw e;
  }
}

export function resolveToken(profile: ProfileConfig): string {
  if (profile.token) return profile.token;
  if (profile.token_command) {
    const [cmd, ...args] = profile.token_command.split(/\s+/);
    return execFileSync(cmd, args, { encoding: "utf8" }).trim();
  }
  throw new Error("Profile has neither token nor token_command");
}

// Minimal TOML parser sufficient for our schema. Replace with @iarna/toml
// if more complex tables are ever needed.
function parseToml(text: string): JetkbConfig {
  const result: JetkbConfig = { profiles: {} };
  let currentProfile: string | null = null;
  for (const line of text.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const section = trimmed.match(/^\[profiles\.([a-z0-9_-]+)\]$/i);
    if (section) {
      currentProfile = section[1]!;
      result.profiles[currentProfile] = {} as ProfileConfig;
      continue;
    }
    const kv = trimmed.match(/^([a-z_][a-z0-9_]*)\s*=\s*"([^"]*)"$/i);
    if (kv) {
      const [, key, val] = kv;
      if (currentProfile) {
        (result.profiles[currentProfile] as any)[key!] = val;
      } else if (key === "default_profile") {
        result.default_profile = val;
      }
    }
  }
  return result;
}
```

(For Tasks beyond CLI-1's MVP, swap `parseToml` for `@iarna/toml`. For now keep zero-dep.)

`src/auth.ts`:

```typescript
import { readConfig, resolveToken, ProfileConfig } from "./config.js";

export interface ResolvedAuth {
  baseUrl: string;
  accountSlug: string;
  token: string;
  source: "env" | "config" | "argument";
}

export function resolveAuth(explicit?: Partial<ResolvedAuth>, profileName?: string): ResolvedAuth {
  if (explicit?.baseUrl && explicit?.accountSlug && explicit?.token) {
    return { ...explicit, source: "argument" } as ResolvedAuth;
  }
  const envToken = process.env.JETKB_TOKEN;
  const envBase = process.env.JETKB_BASE_URL;
  const envSlug = process.env.JETKB_ACCOUNT_SLUG;
  if (envToken && envBase && envSlug) {
    return { token: envToken, baseUrl: envBase, accountSlug: envSlug, source: "env" };
  }
  const config = readConfig();
  if (!config) throw new Error("No credentials found in env or ~/.config/jetkb/config.toml");
  const name = profileName ?? config.default_profile ?? Object.keys(config.profiles)[0];
  if (!name) throw new Error("No profile selected and config has no default_profile");
  const profile = config.profiles[name];
  if (!profile) throw new Error(`Profile '${name}' not found in config`);
  return {
    baseUrl: profile.base_url,
    accountSlug: profile.account_slug,
    token: resolveToken(profile),
    source: "config",
  };
}
```

Add `src/__tests__/config.test.ts` covering: missing file returns null, parses minimal TOML, `resolveAuth` prefers explicit > env > config, `token_command` is invoked.

- [ ] **Step 2.14: Run full core test suite**

```bash
pnpm --filter @jetkb/core test
pnpm --filter @jetkb/core typecheck
```

- [ ] **Step 2.15: Commit**

```bash
git add packages/core/
git commit -m "@jetkb/core: HTTP client foundation + cards/boards/columns + auth

- JetkbClient with bearer auth, ETag caching, 4xx/5xx/network
  error hierarchy, and Link rel=next pagination
- CardsResource (list/get/update/close/reopen) with async
  iterator for page traversal
- BoardsResource and ColumnsResource minimal coverage
- Config resolution from explicit > JETKB_* env > TOML profile,
  with token_command shelling out via execFile (no shell)
- Token redaction helper

Targets server endpoints documented in
jetkb/docs/api/sections/cards.md and boards.md."
```

---

## Task 3 (CLI-3): `@jetkb/core` — comments, assignments, agents, agent_completion, webhooks

**Files (new under `packages/core/src/`):**
- `src/resources/comments.ts`
- `src/resources/assignments.ts`
- `src/resources/agents.ts`
- `src/resources/agent_completion.ts`
- `src/resources/webhooks.ts`
- `src/webhooks/signature.ts` (verifier helper)
- `src/__tests__/agents.test.ts`
- `src/__tests__/agent_completion.test.ts`
- `src/__tests__/signature.test.ts`

**Goal:** Cover the rest of the JetKB API surface needed by CLI and MCP, including the new agent + agent_completion endpoints from server Tasks 4-5.

- [ ] **Step 3.1: Write failing tests for agents resource**

`src/__tests__/agents.test.ts`:

```typescript
import { describe, it, expect, afterEach } from "vitest";
import { JetkbClient } from "../client.js";
import { setGlobalDispatcher, MockAgent } from "undici";

const mockAgent = new MockAgent();
mockAgent.disableNetConnect();
setGlobalDispatcher(mockAgent);

describe("AgentsResource", () => {
  const baseUrl = "https://app.example.test";
  const accountSlug = "/1234567";
  afterEach(() => mockAgent.assertNoPendingInterceptors());

  it("lists agents", async () => {
    mockAgent.get(baseUrl).intercept({ path: "/1234567/agents.json", method: "GET" })
      .reply(200, [{ id: "a1", name: "Bot", slug: "bot", is_agent: true }]);
    const client = new JetkbClient({ baseUrl, accountSlug, token: "t" });
    const agents = await client.agents.list();
    expect(agents).toHaveLength(1);
    expect(agents[0]!.slug).toBe("bot");
  });

  it("creates an agent and returns initial_token once", async () => {
    mockAgent.get(baseUrl).intercept({ path: "/1234567/agents.json", method: "POST" })
      .reply(201, { id: "a1", name: "Bot", slug: "bot", initial_token: { token: "secret", permission: "write" } })
      .matchHeaders({ "content-type": "application/json" });

    const client = new JetkbClient({ baseUrl, accountSlug, token: "t" });
    const result = await client.agents.create({ name: "Bot", slug: "bot", webhookUrl: "https://x" });
    expect(result.initial_token?.token).toBe("secret");
  });

  it("rotates a token", async () => {
    mockAgent.get(baseUrl).intercept({ path: "/1234567/agents/a1/tokens.json", method: "POST" })
      .reply(201, { id: "t1", token: "new", permission: "write" });
    const client = new JetkbClient({ baseUrl, accountSlug, token: "t" });
    const newToken = await client.agents.rotateToken("a1");
    expect(newToken.token).toBe("new");
  });
});
```

- [ ] **Step 3.2: Implement `resources/agents.ts`**

```typescript
import type { JetkbClient } from "../client.js";

export interface AgentCreateInput {
  name: string;
  slug: string;
  webhookUrl?: string;
  allAccessBoards?: boolean;
  permission?: "read" | "write";
}

export interface Agent {
  id: string;
  name: string;
  slug: string;
  email_address: string;
  webhook_url: string | null;
  all_access_boards: boolean;
  permission: "read" | "write";
  active: boolean;
  created_at: string;
  last_active_at: string;
  assigned_cards_count: number;
  completed_cards_count: number;
  url: string;
  initial_token?: { id: string; token: string; permission: string; description?: string };
}

export interface AgentToken {
  id: string;
  description: string;
  permission: "read" | "write";
  token?: string;     // only on create
  created_at: string;
}

export class AgentsResource {
  constructor(private readonly client: JetkbClient) {}

  async list(): Promise<Agent[]> {
    const { data } = await this.client.fetch<Agent[]>("GET", `${this.client.accountSlug}/agents.json`);
    return data;
  }

  async get(id: string): Promise<Agent> {
    const { data } = await this.client.fetch<Agent>("GET", `${this.client.accountSlug}/agents/${id}.json`);
    return data;
  }

  async create(input: AgentCreateInput): Promise<Agent> {
    const { data } = await this.client.fetch<Agent>("POST", `${this.client.accountSlug}/agents.json`, {
      agent: {
        name: input.name,
        slug: input.slug,
        webhook_url: input.webhookUrl,
        all_access_boards: input.allAccessBoards ?? true,
        permission: input.permission ?? "write",
      },
    });
    return data;
  }

  async update(id: string, input: Partial<Pick<AgentCreateInput, "name" | "webhookUrl" | "allAccessBoards">>): Promise<Agent> {
    const { data } = await this.client.fetch<Agent>("PATCH", `${this.client.accountSlug}/agents/${id}.json`, {
      agent: {
        name: input.name,
        webhook_url: input.webhookUrl,
        all_access_boards: input.allAccessBoards,
      },
    });
    return data;
  }

  async delete(id: string): Promise<void> {
    await this.client.fetch<void>("DELETE", `${this.client.accountSlug}/agents/${id}.json`);
  }

  async listTokens(id: string): Promise<AgentToken[]> {
    const { data } = await this.client.fetch<AgentToken[]>("GET", `${this.client.accountSlug}/agents/${id}/tokens.json`);
    return data;
  }

  async rotateToken(id: string, description = "Rotated"): Promise<AgentToken> {
    const { data } = await this.client.fetch<AgentToken>("POST", `${this.client.accountSlug}/agents/${id}/tokens.json`, {
      token: { description, permission: "write" },
    });
    return data;
  }

  async revokeToken(id: string, tokenId: string): Promise<void> {
    await this.client.fetch<void>("DELETE", `${this.client.accountSlug}/agents/${id}/tokens/${tokenId}.json`);
  }
}
```

- [ ] **Step 3.3: Wire `agents` into `JetkbClient`**

Edit `src/client.ts` to add:

```typescript
import { AgentsResource } from "./resources/agents.js";
// ... in class:
readonly agents: AgentsResource;
// ... in constructor:
this.agents = new AgentsResource(this);
```

- [ ] **Step 3.4: Implement `resources/agent_completion.ts`**

```typescript
import type { JetkbClient } from "../client.js";
import { randomUUID } from "node:crypto";

export type AgentCompletionResult = "succeeded" | "failed" | "cancelled" | "needs_human";

export interface AgentCompletionInput {
  result: AgentCompletionResult;
  summary: string;
  detailsHtml?: string;
  outcome?: "closed" | "not_now" | "none" | `triaged:${string}`;
  artifacts?: Array<{ label: string; url: string }>;
  metrics?: Record<string, unknown>;
  idempotencyKey?: string;   // auto-generated if absent
}

export interface AgentCompletionResponse {
  id: string;
  card_number: number;
  result: AgentCompletionResult;
  outcome: string;
  comment_id: string;
  event_id: string;
  created_at: string;
}

export class AgentCompletionResource {
  constructor(private readonly client: JetkbClient) {}

  async create(cardNumber: number, input: AgentCompletionInput): Promise<AgentCompletionResponse> {
    const idempotencyKey = input.idempotencyKey ?? randomUUID();
    const path = `${this.client.accountSlug}/cards/${cardNumber}/agent_completion.json`;
    const body = {
      agent_completion: {
        result: input.result,
        summary: input.summary,
        details_html: input.detailsHtml,
        outcome: input.outcome,
        artifacts: input.artifacts,
        metrics: input.metrics,
      },
    };
    const headers = { "Idempotency-Key": idempotencyKey };
    // Extend client.fetch to accept extra headers, OR add a thin helper:
    const { data } = await this.client.fetchWithHeaders<AgentCompletionResponse>("POST", path, body, headers);
    return data;
  }
}
```

(This requires extending `JetkbClient.fetch` to accept extra headers. Add a sibling method `fetchWithHeaders` or thread an optional `headers` parameter into `fetch`. Update `client.ts` accordingly and add a single test that asserts the Idempotency-Key header is sent.)

- [ ] **Step 3.5: Implement `resources/comments.ts` and `resources/assignments.ts`**

Both follow the same pattern as cards. Cover:

- `comments.list(cardNumber)`, `comments.create(cardNumber, { body })`
- `assignments.toggle(cardNumber, { assigneeId })`

Tests mirror the agents resource tests.

- [ ] **Step 3.6: Implement `webhooks/signature.ts`**

```typescript
import { createHmac, timingSafeEqual } from "node:crypto";

export interface VerifyOptions {
  body: Buffer | string;
  signatureHeader: string;
  timestampHeader: string;
  secret: string;
  maxAgeSeconds?: number;
}

export function verifyWebhookSignature(opts: VerifyOptions): boolean {
  const maxAge = opts.maxAgeSeconds ?? 300;
  const t = Number(opts.timestampHeader);
  if (!Number.isFinite(t)) return false;
  const ageSeconds = Math.abs(Date.now() / 1000 - t);
  if (ageSeconds > maxAge) return false;

  // Header format: t=<timestamp>,v1=<hex-sig>  (per spec §5.4 upgraded format)
  // Fall back to bare hex if the upgrade hasn't shipped yet (interim phase).
  const v1Match = opts.signatureHeader.match(/v1=([0-9a-f]+)/i);
  const provided = (v1Match?.[1] ?? opts.signatureHeader.trim()).toLowerCase();

  const payload = Buffer.isBuffer(opts.body) ? opts.body : Buffer.from(opts.body, "utf8");
  const signedString = v1Match
    ? Buffer.concat([ Buffer.from(`${opts.timestampHeader}.`, "utf8"), payload ])
    : payload;

  const expected = createHmac("sha256", opts.secret).update(signedString).digest("hex");

  if (provided.length !== expected.length) return false;
  return timingSafeEqual(Buffer.from(provided, "hex"), Buffer.from(expected, "hex"));
}
```

Test (`src/__tests__/signature.test.ts`):

```typescript
import { describe, it, expect } from "vitest";
import { createHmac } from "node:crypto";
import { verifyWebhookSignature } from "../webhooks/signature.js";

describe("verifyWebhookSignature", () => {
  const secret = "test-secret";
  const body = JSON.stringify({ hello: "world" });
  const timestamp = Math.floor(Date.now() / 1000).toString();
  const v1 = createHmac("sha256", secret).update(`${timestamp}.${body}`).digest("hex");

  it("accepts a valid v1 signature", () => {
    expect(verifyWebhookSignature({ body, timestampHeader: timestamp, signatureHeader: `t=${timestamp},v1=${v1}`, secret })).toBe(true);
  });

  it("rejects tampered body", () => {
    expect(verifyWebhookSignature({ body: body + "x", timestampHeader: timestamp, signatureHeader: `t=${timestamp},v1=${v1}`, secret })).toBe(false);
  });

  it("rejects expired timestamp", () => {
    const oldTs = (Math.floor(Date.now() / 1000) - 600).toString();
    const oldSig = createHmac("sha256", secret).update(`${oldTs}.${body}`).digest("hex");
    expect(verifyWebhookSignature({ body, timestampHeader: oldTs, signatureHeader: `t=${oldTs},v1=${oldSig}`, secret })).toBe(false);
  });

  it("accepts bare hex signature in interim format", () => {
    const bare = createHmac("sha256", secret).update(body).digest("hex");
    expect(verifyWebhookSignature({ body, timestampHeader: timestamp, signatureHeader: bare, secret })).toBe(true);
  });
});
```

- [ ] **Step 3.7: Export new modules in `index.ts`**

```typescript
export { JetkbClient } from "./client.js";
export * from "./errors.js";
export * from "./types.js";
export { redactToken } from "./redact.js";
export { resolveAuth } from "./auth.js";
export { readConfig } from "./config.js";
export { verifyWebhookSignature } from "./webhooks/signature.js";
export type { Agent, AgentCreateInput, AgentToken } from "./resources/agents.js";
export type { AgentCompletionInput, AgentCompletionResponse, AgentCompletionResult } from "./resources/agent_completion.js";
```

- [ ] **Step 3.8: Run full core test suite**

```bash
pnpm --filter @jetkb/core test
pnpm --filter @jetkb/core typecheck
pnpm --filter @jetkb/core build
```

- [ ] **Step 3.9: Commit**

```bash
git add packages/core/
git commit -m "@jetkb/core: comments, assignments, agents, agent_completion, signature

- agents resource covers full CRUD + token rotation
- agent_completion resource sends Idempotency-Key on every call
  and accepts artifacts + metrics
- comments and assignments cover the endpoints CLI/MCP need
- verifyWebhookSignature supports both the upgraded
  t=<ts>,v1=<hex> format and the interim bare-hex format so
  agent runners work across the server's signature transition"
```

---

## Task 4 (CLI-4): `@jetkb/cli` — auth + cards + agents commands

**Files (under `packages/cli/`):**
- `tsconfig.json`
- `src/index.ts` (commander root)
- `src/commands/auth.ts`
- `src/commands/cards.ts`
- `src/commands/agents.ts`
- `src/commands/config.ts`
- `src/output/table.ts`
- `src/output/json.ts`
- `src/interactive/login.ts`
- `src/__tests__/commands.test.ts`

- [ ] **Step 4.1: Install deps**

```bash
cd packages/cli
pnpm add commander @inquirer/prompts chalk @iarna/toml
pnpm add -D vitest @types/node
```

- [ ] **Step 4.2: `src/index.ts`**

```typescript
#!/usr/bin/env node
import { Command } from "commander";
import { registerAuthCommands } from "./commands/auth.js";
import { registerCardsCommands } from "./commands/cards.js";
import { registerAgentsCommands } from "./commands/agents.js";
import { registerConfigCommands } from "./commands/config.js";

const program = new Command();
program.name("jetkb").description("jetKB command-line interface").version("0.1.0");
program.option("--profile <name>", "Profile to use from config")
       .option("--json", "Output JSON instead of human-readable table")
       .option("--debug", "Print debug info (HTTP requests with redacted tokens)");

registerAuthCommands(program);
registerCardsCommands(program);
registerAgentsCommands(program);
registerConfigCommands(program);

program.parseAsync(process.argv).catch(err => {
  if (err?.constructor?.name === "JetkbAuthError") { console.error("Auth failed. Run: jetkb auth login"); process.exit(4); }
  if (err?.constructor?.name === "JetkbForbiddenError") { console.error("Forbidden:", err.message); process.exit(5); }
  if (err?.constructor?.name === "JetkbApiError" && err.status === 422) { console.error("Validation:", JSON.stringify(err.body)); process.exit(6); }
  console.error(err?.message ?? err);
  process.exit(1);
});
```

- [ ] **Step 4.3: `src/commands/auth.ts` (login + status + whoami)**

```typescript
import { Command } from "commander";
import { JetkbClient, resolveAuth, redactToken } from "@jetkb/core";
import { interactiveLogin } from "../interactive/login.js";

export function registerAuthCommands(parent: Command) {
  const auth = parent.command("auth").description("Authentication");

  auth.command("login").description("Sign in via magic link and store a CLI token")
    .option("--instance <url>", "jetKB instance URL")
    .option("--email <email>", "Email address")
    .action(async (opts) => {
      await interactiveLogin(opts);
    });

  auth.command("status").description("Show current credentials").action(async () => {
    try {
      const auth = resolveAuth();
      console.log(`Instance:  ${auth.baseUrl}`);
      console.log(`Account:   ${auth.accountSlug}`);
      console.log(`Token:     ${redactToken(auth.token)}`);
      console.log(`Source:    ${auth.source}`);
    } catch (e: any) {
      console.error(e.message);
      process.exit(2);
    }
  });

  auth.command("whoami").description("Print authenticated identity").action(async () => {
    const auth = resolveAuth();
    const client = new JetkbClient(auth);
    // Hit /my/identity once it's exposed by core. For now hit a known endpoint:
    const cards = await client.cards.listPage({ page: 1 });
    console.log(`Authenticated. Sample card visible: ${cards.items[0]?.title ?? "(none)"}`);
  });
}
```

- [ ] **Step 4.4: `src/interactive/login.ts`**

```typescript
import { input, select, confirm } from "@inquirer/prompts";
import { request } from "undici";
import { writeFileSync, mkdirSync, existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

export async function interactiveLogin(opts: { instance?: string; email?: string }) {
  const instance = opts.instance ?? await input({ message: "jetKB instance URL:", default: "https://app.jetkb.example.com" });
  const email = opts.email ?? await input({ message: "Your email address:" });

  // Step 1: request magic link
  const sessionResp = await request(`${instance}/session`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "Accept": "application/json" },
    body: JSON.stringify({ email_address: email }),
  });
  if (sessionResp.statusCode !== 201) throw new Error(`Failed to request magic link: ${sessionResp.statusCode}`);
  const setCookie = sessionResp.headers["set-cookie"];
  const pendingCookie = Array.isArray(setCookie) ? setCookie.find(c => c.startsWith("pending_authentication_token=")) : setCookie?.toString();

  console.log("Magic link sent. Check your email.");
  const code = await input({ message: "Enter the 6-character code:" });

  // Step 2: submit code
  const codeResp = await request(`${instance}/session/magic_link`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "Accept": "application/json", "Cookie": pendingCookie ?? "" },
    body: JSON.stringify({ code }),
  });
  if (codeResp.statusCode !== 200 && codeResp.statusCode !== 201) throw new Error(`Magic link rejected: ${codeResp.statusCode}`);
  const sessionToken = (await codeResp.body.json() as { session_token: string }).session_token;

  // Pick account: query a known endpoint that lists accessible accounts
  // (Approach: list boards to detect account_slug from URL — or hit /my/identity once available)
  // For now, ask interactively.
  const accountSlug = await input({ message: "Account slug (with leading /):", default: "/1234567" });

  // Create access token
  const tokenResp = await request(`${instance}${accountSlug}/my/access_tokens`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "Accept": "application/json", "Cookie": `session_token=${sessionToken}` },
    body: JSON.stringify({ access_token: { description: "jetKB CLI", permission: "write" } }),
  });
  if (tokenResp.statusCode !== 201) throw new Error(`Token creation failed: ${tokenResp.statusCode}`);
  const tokenBody = await tokenResp.body.json() as { token: string };

  const profileName = await input({ message: "Profile name:", default: "default" });

  const configDir = join(homedir(), ".config", "jetkb");
  if (!existsSync(configDir)) mkdirSync(configDir, { recursive: true, mode: 0o700 });
  const configPath = join(configDir, "config.toml");
  const toml = [
    `default_profile = "${profileName}"`,
    "",
    `[profiles.${profileName}]`,
    `base_url = "${instance}"`,
    `account_slug = "${accountSlug}"`,
    `token = "${tokenBody.token}"`,
  ].join("\n");
  writeFileSync(configPath, toml, { mode: 0o600 });
  console.log(`✓ Saved to ${configPath}`);
  console.log(`Try: jetkb cards list`);
}
```

- [ ] **Step 4.5: `src/output/table.ts` and `src/output/json.ts`**

`table.ts`:

```typescript
export function renderTable(rows: Array<Record<string, string>>, columns: string[]): string {
  if (rows.length === 0) return "(no results)";
  const widths = columns.map(c => Math.max(c.length, ...rows.map(r => (r[c] ?? "").length)));
  const header = columns.map((c, i) => c.padEnd(widths[i]!)).join("  ");
  const sep = widths.map(w => "-".repeat(w)).join("  ");
  const body = rows.map(r => columns.map((c, i) => (r[c] ?? "").padEnd(widths[i]!)).join("  ")).join("\n");
  return [header, sep, body].join("\n");
}
```

`json.ts`:

```typescript
export function renderJson(value: unknown): string { return JSON.stringify(value, null, 2); }
export function renderNdjson(values: unknown[]): string { return values.map(v => JSON.stringify(v)).join("\n"); }
```

- [ ] **Step 4.6: `src/commands/cards.ts`**

```typescript
import { Command } from "commander";
import { JetkbClient, resolveAuth } from "@jetkb/core";
import { renderTable } from "../output/table.js";
import { renderJson, renderNdjson } from "../output/json.js";

export function registerCardsCommands(parent: Command) {
  const cards = parent.command("cards").description("Cards");

  cards.command("list").description("List cards")
    .option("--indexed-by <kind>", "Filter (all|maybe|closed|not_now|stalled|postponing_soon|golden)")
    .option("--sorted-by <how>", "Sort (latest|newest|oldest)")
    .option("--assignee <id>", "Filter by assignee user ID (repeat for multiple)", collect, [] as string[])
    .option("--limit <n>", "Maximum number of cards", parseInt)
    .action(async (opts) => {
      const global = parent.optsWithGlobals();
      const auth = resolveAuth(undefined, global.profile);
      const client = new JetkbClient({ ...auth, debug: !!global.debug });
      const items: any[] = [];
      for await (const card of client.cards.list({ indexedBy: opts.indexedBy, sortedBy: opts.sortedBy, assigneeIds: opts.assignee })) {
        items.push(card);
        if (opts.limit && items.length >= opts.limit) break;
      }
      if (global.json) console.log(renderJson(items));
      else console.log(renderTable(items.map(c => ({
        NUMBER: String(c.number), TITLE: c.title, BOARD: c.board?.name ?? "", ASSIGNEES: (c.assignees ?? []).map((a: any) => a.name).join(", "),
      })), ["NUMBER", "TITLE", "BOARD", "ASSIGNEES"]));
    });

  cards.command("get <number>").description("Show a card").action(async (number) => {
    const global = parent.optsWithGlobals();
    const auth = resolveAuth(undefined, global.profile);
    const client = new JetkbClient({ ...auth });
    const card = await client.cards.get(parseInt(number, 10));
    console.log(global.json ? renderJson(card) : `#${card.number} ${card.title}\n${card.description ?? ""}`);
  });

  cards.command("close <number>").description("Close a card").action(async (number) => {
    const auth = resolveAuth(undefined, parent.optsWithGlobals().profile);
    const client = new JetkbClient({ ...auth });
    await client.cards.close(parseInt(number, 10));
    console.log(`Closed #${number}`);
  });
}

function collect(value: string, prev: string[]): string[] { return [...prev, value]; }
```

- [ ] **Step 4.7: `src/commands/agents.ts`**

Mirror the agents resource surface: `list`, `create --name --slug --webhook-url`, `show <id>`, `delete <id>`, `token rotate <id>`, `token list <id>`. Each command resolves auth, instantiates client, prints table or JSON.

- [ ] **Step 4.8: `src/commands/config.ts`**

Implement `list`, `get`, `set`, `unset`, `profiles` — operating on `~/.config/jetkb/config.toml`.

- [ ] **Step 4.9: Tests**

`src/__tests__/commands.test.ts`: spawn the CLI as a subprocess against an Undici MockAgent (or write a thin "memory transport" for `JetkbClient`). Assert:

- `jetkb cards list --json` produces parseable JSON
- `jetkb cards list` produces a table with the expected columns
- Missing token → exit code 4 with `auth login` hint
- 403 → exit code 5
- 422 → exit code 6 with validation error printed

- [ ] **Step 4.10: Run + commit**

```bash
pnpm --filter @jetkb/cli test
pnpm --filter @jetkb/cli typecheck
pnpm --filter @jetkb/cli build

git add packages/cli/
git commit -m "@jetkb/cli: auth login flow + cards + agents + config commands

- jetkb auth login walks the magic-link flow end-to-end and
  writes a chmod 600 TOML config
- jetkb cards list/get/close cover the common loop
- jetkb agents list/create/show/delete + token rotate cover
  admin tasks
- jetkb config list/get/set manage the TOML
- Global flags --profile, --json, --debug
- Standardised exit codes (4=auth, 5=forbidden, 6=validation)"
```

---

## Task 5 (CLI-5): `@jetkb/mcp` — 14 tools + Claude Desktop integration

**Files (under `packages/mcp/`):**
- `tsconfig.json`
- `src/index.ts` (server entrypoint)
- `src/server.ts`
- `src/tools/index.ts`
- `src/tools/list_my_cards.ts`
- `src/tools/list_cards.ts`
- `src/tools/get_card.ts`
- `src/tools/create_card.ts`
- `src/tools/update_card.ts`
- `src/tools/move_card.ts`
- `src/tools/comment_on_card.ts`
- `src/tools/assign_card.ts`
- `src/tools/tag_card.ts`
- `src/tools/complete_card_as_agent.ts`
- `src/tools/list_boards.ts`
- `src/tools/list_columns.ts`
- `src/tools/search.ts`
- `src/tools/get_my_identity.ts`
- `src/resources.ts` (MCP resources: card/board/inbox)
- `src/__tests__/tools.test.ts`
- `README.md` (Claude Desktop config example)

- [ ] **Step 5.1: Install deps**

```bash
cd packages/mcp
pnpm add @modelcontextprotocol/sdk
pnpm add -D vitest
```

- [ ] **Step 5.2: `src/index.ts`** (stdio launcher)

```typescript
#!/usr/bin/env node
import { startServer } from "./server.js";

const transport = process.argv.includes("--transport=http") ? "http" : "stdio";
const port = parseInt(process.argv.find(a => a.startsWith("--port="))?.split("=")[1] ?? "3344", 10);

await startServer({ transport, port });
```

- [ ] **Step 5.3: `src/server.ts`**

```typescript
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { JetkbClient, resolveAuth } from "@jetkb/core";
import { allTools } from "./tools/index.js";
import { listResources, readResource } from "./resources.js";

export async function startServer(opts: { transport: "stdio" | "http"; port?: number }) {
  const auth = resolveAuth();
  const client = new JetkbClient(auth);

  const server = new Server({ name: "jetkb", version: "0.1.0" }, {
    capabilities: { tools: {}, resources: {} },
  });

  server.setRequestHandler("tools/list", async () => ({ tools: allTools.map(t => ({ name: t.name, description: t.description, inputSchema: t.inputSchema })) }));
  server.setRequestHandler("tools/call", async (req) => {
    const tool = allTools.find(t => t.name === req.params.name);
    if (!tool) throw new Error(`Unknown tool: ${req.params.name}`);
    return await tool.execute(req.params.arguments, client);
  });
  server.setRequestHandler("resources/list", () => listResources(client));
  server.setRequestHandler("resources/read", (req) => readResource(req.params.uri, client));

  if (opts.transport === "stdio") {
    await server.connect(new StdioServerTransport());
  } else {
    throw new Error("HTTP transport: implement in P2");
  }
}
```

- [ ] **Step 5.4: `src/tools/index.ts` and one example tool**

`src/tools/index.ts`:

```typescript
import type { JetkbClient } from "@jetkb/core";
import { listMyCards } from "./list_my_cards.js";
import { listCards } from "./list_cards.js";
import { getCard } from "./get_card.js";
import { createCard } from "./create_card.js";
import { updateCard } from "./update_card.js";
import { moveCard } from "./move_card.js";
import { commentOnCard } from "./comment_on_card.js";
import { assignCard } from "./assign_card.js";
import { tagCard } from "./tag_card.js";
import { completeCardAsAgent } from "./complete_card_as_agent.js";
import { listBoards } from "./list_boards.js";
import { listColumns } from "./list_columns.js";
import { search } from "./search.js";
import { getMyIdentity } from "./get_my_identity.js";

export interface JetkbTool {
  name: string;
  description: string;
  inputSchema: object;
  execute: (args: unknown, client: JetkbClient) => Promise<{ content: Array<{ type: "text"; text: string }> }>;
}

export const allTools: JetkbTool[] = [
  listMyCards, listCards, getCard, createCard, updateCard, moveCard,
  commentOnCard, assignCard, tagCard, completeCardAsAgent,
  listBoards, listColumns, search, getMyIdentity,
];
```

`src/tools/complete_card_as_agent.ts` (the most important new tool):

```typescript
import type { JetkbTool } from "./index.js";

export const completeCardAsAgent: JetkbTool = {
  name: "complete_card_as_agent",
  description: `
    Mark a card as completed by you (an agent). Atomically:
    1. Posts a comment with your summary and artifacts
    2. Closes the card (or moves it as specified in 'outcome')
    3. Unassigns you from the card
    4. Emits a 'card_agent_completed' webhook

    ONLY use this when you have actually finished working on a card assigned to you.
    Do NOT use this for partial progress — use 'comment_on_card' for status updates.
    Do NOT use this if you are not currently assigned to the card.
  `.trim(),
  inputSchema: {
    type: "object",
    required: ["card_number", "result", "summary"],
    properties: {
      card_number: { type: "integer", description: "Card number on the board" },
      result: { type: "string", enum: ["succeeded", "failed", "cancelled", "needs_human"] },
      summary: { type: "string", description: "One-line summary that appears in the auto-generated comment" },
      details_html: { type: "string", description: "Optional rich-text detail to include in the comment body" },
      outcome: { type: "string", description: "Optional. closed | not_now | none | triaged:<column_id>" },
      artifacts: {
        type: "array",
        maxItems: 10,
        items: { type: "object", required: ["label", "url"], properties: { label: { type: "string" }, url: { type: "string" } } },
      },
      metrics: { type: "object" },
    },
  },
  async execute(args: any, client) {
    const result = await client.agentCompletion.create(args.card_number, {
      result: args.result, summary: args.summary, detailsHtml: args.details_html,
      outcome: args.outcome, artifacts: args.artifacts, metrics: args.metrics,
    });
    return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
  },
};
```

(Implement the other 13 tools to the same template. Keep each file under 50 lines.)

- [ ] **Step 5.5: `src/resources.ts`**

```typescript
import type { JetkbClient } from "@jetkb/core";

export function listResources(client: JetkbClient) {
  return {
    resources: [
      { uri: "jetkb://my/inbox", name: "My Inbox", description: "Cards assigned to me", mimeType: "application/json" },
    ],
  };
}

export async function readResource(uri: string, client: JetkbClient) {
  const cardMatch = uri.match(/^jetkb:\/\/card\/(\d+)$/);
  if (cardMatch) {
    const card = await client.cards.get(parseInt(cardMatch[1]!, 10));
    return { contents: [{ uri, mimeType: "application/json", text: JSON.stringify(card, null, 2) }] };
  }
  const boardMatch = uri.match(/^jetkb:\/\/board\/(.+)$/);
  if (boardMatch) {
    const board = await client.boards.get(boardMatch[1]!);
    return { contents: [{ uri, mimeType: "application/json", text: JSON.stringify(board, null, 2) }] };
  }
  if (uri === "jetkb://my/inbox") {
    const cards = [];
    for await (const c of client.cards.list({ indexedBy: "all" })) cards.push(c);
    return { contents: [{ uri, mimeType: "application/json", text: JSON.stringify(cards, null, 2) }] };
  }
  throw new Error(`Unknown resource: ${uri}`);
}
```

- [ ] **Step 5.6: Tests**

`src/__tests__/tools.test.ts`:

```typescript
import { describe, it, expect } from "vitest";
import { allTools } from "../tools/index.js";

describe("MCP tools", () => {
  it("exposes exactly 14 tools", () => {
    expect(allTools).toHaveLength(14);
  });
  it("each tool has a name, description, and inputSchema", () => {
    for (const tool of allTools) {
      expect(tool.name).toMatch(/^[a-z_]+$/);
      expect(tool.description.length).toBeGreaterThan(20);
      expect(typeof tool.inputSchema).toBe("object");
    }
  });
  it("complete_card_as_agent requires card_number, result, summary", () => {
    const tool = allTools.find(t => t.name === "complete_card_as_agent")!;
    expect((tool.inputSchema as any).required).toEqual(["card_number", "result", "summary"]);
  });
});
```

- [ ] **Step 5.7: README with Claude Desktop config**

`packages/mcp/README.md`:

```markdown
# @jetkb/mcp

Model Context Protocol server for jetKB.

## Claude Desktop

Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

\`\`\`json
{
  "mcpServers": {
    "jetkb": {
      "command": "npx",
      "args": ["-y", "@jetkb/mcp"],
      "env": {
        "JETKB_BASE_URL": "https://app.jetkb.example.com",
        "JETKB_ACCOUNT_SLUG": "/1234567",
        "JETKB_TOKEN": "your-personal-access-token"
      }
    }
  }
}
\`\`\`

## Tools (14)

list_my_cards, list_cards, get_card, create_card, update_card, move_card,
comment_on_card, assign_card, tag_card, complete_card_as_agent, list_boards,
list_columns, search, get_my_identity
```

- [ ] **Step 5.8: Commit**

```bash
pnpm --filter @jetkb/mcp test build
git add packages/mcp/
git commit -m "@jetkb/mcp: MCP server with 14 tools and 3 resources

Tools are deliberately mid-grained (not 1:1 REST wrappers) to
give LLMs high-signal verbs: list_my_cards, complete_card_as_agent,
move_card with a unified target argument, etc. Dangerous
operations (deleting cards, agents CRUD, token ops) are
intentionally excluded — humans use the CLI for those.

Resources jetkb://my/inbox, jetkb://card/<n>, jetkb://board/<id>
let Claude Desktop users @-reference jetKB content directly in
prompts without the LLM having to call get_card first."
```

---

## Task 6 (CLI-6): End-to-end test suite

**Files (under `jetkb-cli/apps/e2e/`):**
- `package.json`
- `tsconfig.json`
- `docker-compose.yml`
- `seed.sh`
- `tests/full-loop.test.ts`
- `tests/mcp-direct.test.ts`
- `tests/token-rotation.test.ts`
- `tests/multi-profile.test.ts`
- `tests/error-experience.test.ts`
- `tests/webhook-signature.test.ts`

**Goal:** Bring up a real jetKB server (via the `jetkb-agents-v0.1-server` Docker image tagged at the end of the server plan) and exercise the full CLI + MCP + agent flow.

- [ ] **Step 6.1: `apps/e2e/package.json`**

```json
{
  "name": "e2e",
  "private": true,
  "type": "module",
  "scripts": { "test": "vitest run --testTimeout 60000 --hookTimeout 60000" },
  "dependencies": { "@jetkb/core": "workspace:*", "@jetkb/cli": "workspace:*" },
  "devDependencies": { "vitest": "^1.4.0", "execa": "^9.0.0" }
}
```

- [ ] **Step 6.2: `docker-compose.yml`**

```yaml
services:
  mysql:
    image: mysql:8
    environment:
      MYSQL_ROOT_PASSWORD: rootpw
      MYSQL_DATABASE: jetkb_e2e
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 5s
      retries: 10
  jetkb:
    image: ghcr.io/<org>/jetkb:e2e
    depends_on:
      mysql: { condition: service_healthy }
    environment:
      RAILS_ENV: production
      DATABASE_URL: mysql2://root:rootpw@mysql:3306/jetkb_e2e
      SECRET_KEY_BASE: e2e-secret-key-base-do-not-use-in-prod
    ports: ["3006:3006"]
```

- [ ] **Step 6.3: `seed.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
# Wait for jetKB to come up
until curl -sf http://localhost:3006/up; do sleep 1; done
# Load fixture data and capture an admin token via a one-shot Rails runner.
docker compose exec -T jetkb bin/rails runner '
  account = Account.create_with_owner(account: { name: "E2E" }, owner: { email_address: "admin@example.com", name: "Admin" })
  token = account.users.find_by(role: :owner).identity.access_tokens.create!(description: "e2e", permission: :write).token
  puts "ADMIN_TOKEN=#{token}"
  puts "ACCOUNT_SLUG=#{account.slug}"
' > .env.e2e
```

- [ ] **Step 6.4: `tests/full-loop.test.ts`**

```typescript
import { describe, it, beforeAll, expect } from "vitest";
import { JetkbClient } from "@jetkb/core";
import { readFileSync } from "node:fs";
import { execa } from "execa";

let baseUrl = "http://localhost:3006";
let accountSlug = "";
let adminToken = "";

beforeAll(async () => {
  await execa("docker", ["compose", "up", "-d"], { stdio: "inherit" });
  await execa("bash", ["./seed.sh"], { stdio: "inherit" });
  const env = readFileSync(".env.e2e", "utf8");
  adminToken   = env.match(/ADMIN_TOKEN=(.+)/)![1]!;
  accountSlug  = env.match(/ACCOUNT_SLUG=(.+)/)![1]!;
});

describe("Full loop", () => {
  it("create agent, assign card, complete card", async () => {
    const admin = new JetkbClient({ baseUrl, accountSlug, token: adminToken });

    // 1. Create board + card (admin acts)
    // For brevity assume seed already created a board + card. Otherwise add helpers.

    // 2. Create agent
    const agent = await admin.agents.create({ name: "E2E Bot", slug: "e2e-bot" });
    expect(agent.initial_token?.token).toBeTruthy();

    // 3. Assign card #1 to agent
    await admin.assignments.toggle(1, { assigneeId: agent.id });

    // 4. Agent reports completion
    const agentClient = new JetkbClient({ baseUrl, accountSlug, token: agent.initial_token!.token });
    const completion = await agentClient.agentCompletion.create(1, {
      result: "succeeded", summary: "Done.", outcome: "closed",
    });
    expect(completion.result).toBe("succeeded");

    // 5. Verify state
    const card = await admin.cards.get(1);
    expect(card.closed).toBe(true);
  }, 120_000);
});
```

- [ ] **Step 6.5: Implement remaining E2E scenarios**

- `mcp-direct.test.ts`: spawn `jetkb-mcp` as subprocess, send `tools/list` and `tools/call` over stdio, assert responses
- `token-rotation.test.ts`: rotate token, verify old token still works briefly, delete old, verify it stops
- `multi-profile.test.ts`: write two profiles, verify `--profile` switches
- `error-experience.test.ts`: 401/403/422/429 each produce correct exit code + readable message
- `webhook-signature.test.ts`: trigger a card_assigned, capture webhook payload via local webhook receiver, verify signature

- [ ] **Step 6.6: CI integration**

Add to `.github/workflows/ci.yml`:

```yaml
  e2e:
    runs-on: ubuntu-latest
    needs: test
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v3
        with: { version: 9 }
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: pnpm }
      - run: pnpm install --frozen-lockfile
      - run: pnpm build
      - name: Pull jetKB image
        run: docker pull ghcr.io/<org>/jetkb:e2e
      - run: pnpm e2e
```

- [ ] **Step 6.7: Commit**

```bash
git add apps/e2e/ .github/workflows/ci.yml
git commit -m "Cross-stack e2e suite against jetKB docker image

Spins up a real Rails + MySQL stack and runs the full
agent-loop scenarios. Six scenarios cover the assign-complete
happy path, MCP tool invocation over stdio, token rotation,
multi-profile config switching, error experience codes, and
webhook signature verification against a local receiver.

CI pulls ghcr.io/<org>/jetkb:e2e which is published at the
end of the server-side plan."
```

---

## Task 7 (CLI-7): npm publish workflow + changeset + 0.1.0

**Files:**
- `.changeset/initial.md`
- `.github/workflows/release.yml`
- `packages/*/package.json` version bumps to `0.1.0`
- Each `packages/*/README.md`

- [ ] **Step 7.1: Configure changeset**

```bash
pnpm changeset init
```

Edit `.changeset/config.json`:

```json
{
  "$schema": "https://unpkg.com/@changesets/config@3.0.0/schema.json",
  "changelog": "@changesets/cli/changelog",
  "commit": false,
  "fixed": [["@jetkb/core", "@jetkb/cli", "@jetkb/mcp"]],
  "linked": [],
  "access": "public",
  "baseBranch": "main",
  "updateInternalDependencies": "patch",
  "ignore": []
}
```

(`fixed` keeps all three packages on the same version — simpler for the v0.1 release. Switch to independent versioning later if needed.)

- [ ] **Step 7.2: Create initial changeset**

```bash
pnpm changeset
```

Select all three packages, choose `minor`, write description:

```
Initial public release. Three packages:

- @jetkb/core: HTTP client SDK for the jetKB JSON API
- @jetkb/cli: command-line tool (`jetkb`)
- @jetkb/mcp: MCP server (`jetkb-mcp`) for Claude Desktop, Cursor, etc.

See https://github.com/<org>/jetkb-cli for usage.
```

- [ ] **Step 7.3: Release workflow**

`.github/workflows/release.yml`:

```yaml
name: release
on:
  push: { branches: [main] }
jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
      id-token: write    # for npm provenance
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v3
        with: { version: 9 }
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: pnpm, registry-url: 'https://registry.npmjs.org' }
      - run: pnpm install --frozen-lockfile
      - run: pnpm build
      - uses: changesets/action@v1
        with:
          publish: pnpm release
          version: pnpm changeset version
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
          NPM_CONFIG_PROVENANCE: "true"
```

- [ ] **Step 7.4: Per-package READMEs**

`packages/core/README.md`, `packages/cli/README.md`, `packages/mcp/README.md` — each ~30 lines. Quickstart + link to the monorepo README.

- [ ] **Step 7.5: Publish dry-run locally**

```bash
pnpm install
pnpm build
pnpm changeset version   # bumps to 0.1.0
git diff
pnpm changeset publish --dry-run
```

Confirm three packages would publish at 0.1.0.

- [ ] **Step 7.6: Commit version bumps and CHANGELOG**

```bash
git add packages/ .changeset/ CHANGELOG.md
git commit -m "Release 0.1.0

First public release of @jetkb/core, @jetkb/cli, @jetkb/mcp.
See CHANGELOG for details."
```

- [ ] **Step 7.7: Push, let CI publish**

```bash
git push origin main
```

The release workflow runs `changeset version` (creates a versioning PR) or, if the version PR was already merged, runs `pnpm release` which calls `changeset publish` and pushes to npm with provenance.

- [ ] **Step 7.8: Verify**

```bash
npm view @jetkb/core
npm view @jetkb/cli
npm view @jetkb/mcp
```

Each should report version 0.1.0.

- [ ] **Step 7.9: Tag the release**

```bash
git tag jetkb-cli-v0.1.0 -m "First public release"
git push origin jetkb-cli-v0.1.0
```

---

## Final verification

- [ ] **Run the full suite**

```bash
pnpm install
pnpm typecheck
pnpm lint
pnpm test
pnpm build
pnpm e2e        # requires docker
```

Expected: all green.

- [ ] **Manual smoke test against a real jetKB instance**

```bash
npm i -g @jetkb/cli @jetkb/mcp
jetkb auth login   # walks through magic link flow
jetkb cards list
jetkb agents create --name "Smoke Bot" --slug smoke-bot --webhook-url https://example.com/hook
JETKB_TOKEN=<smoke-bot-token> jetkb-mcp   # stdio mode, exit with Ctrl-C after listing tools
```

- [ ] **Claude Desktop integration check**

Edit Claude Desktop config (`~/Library/Application Support/Claude/claude_desktop_config.json`) to add the `jetkb` MCP server (see `packages/mcp/README.md`). Restart Claude Desktop. In a conversation:

1. Verify the tools picker shows 14 jetKB tools
2. Ask "list my jetKB cards" — should invoke `list_my_cards`
3. Reference `@jetkb://my/inbox` — should pull resource content into context

---

## Spec coverage check

| Spec section | Plan task |
|---|---|
| §4.1 (repo layout) | Task 1 |
| §4.2 (`@jetkb/core` SDK) | Tasks 2 + 3 |
| §4.3 (auth resolution + TOML + `token_command`) | Task 2 (Step 2.13) + Task 4 (config commands) |
| §4.4 (`@jetkb/cli` commands) | Task 4 |
| §4.5 (14 MCP tools + resources) | Task 5 |
| §4.6 (distribution channels) | Task 7 (npm/npx). Homebrew + binary deferred to P2 per spec §8.3 |
| §4.7 (versioning) | Task 7 (changeset fixed) |
| §4.8 (CLI i18n) | Deferred to P1 per spec §8.2 |
| §5.4 (webhook signature verifier) | Task 3 Step 3.6 |
| §5.7 (token redaction, file perms, `token_command`) | Task 2 (redact) + Task 4 (login writes mode 0600) |
| §7.6 (CLI/MCP unit tests) | Throughout Tasks 2-5 |
| §7.7 (E2E) | Task 6 |

P2 items deliberately excluded from this plan: Homebrew tap, single-file binaries, Docker image for MCP server, `--transport http` for the MCP server. These belong to a follow-up plan once 0.1.0 is in users' hands.

---

## Execution sequencing across both plans

Two engineers (or two Claude Code sessions) can work in parallel:

```
Week 1   Server: PR-1 (Task 1) ──┐
         CLI:    CLI-1 + CLI-2 (Tasks 1-2)
                                  │
Week 2   Server: PR-2..PR-7 (Tasks 2-7) ─┐
         CLI:    CLI-3 (Task 3)          │   ← CLI-3 needs server PR-5 (agent_completion endpoint)
                                          │      so CLI-3 lands after server PR-5
Week 3   Server: PR-8..PR-10 (Tasks 8-10)
         CLI:    CLI-4 + CLI-5 (Tasks 4-5)
Week 4   Both:   CLI-6 + CLI-7 (Tasks 6-7) — E2E needs the jetKB:e2e image
                 which is produced by server's "Final verification" step.
```

The hard dependency is **server Task 4 (Agents controllers) → CLI Task 3 (agents resource)**, because `core` can't be tested against a real server until those endpoints exist. The MockAgent unit tests in CLI Task 3 work without the server, but the e2e suite (Task 6) needs the server tag.
