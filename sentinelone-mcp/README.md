# SentinelOne MCP Server

Model Context Protocol server orchestrating the SentinelOne Management Console, Singularity Data Lake, UAM Alert Interface, and Hyperautomation APIs. Pure Node.js 18+, zero external dependencies. Supports both stdio (for Amazon Quick) and Streamable HTTP (for team-shared VM deployments) transports.

- **Single-user, local:** install with `npx`, plug into Amazon Quick in 30 seconds.
- **Team, VM-hosted:** install on one Linux box, per-user bearer tokens, audit logs, SIGHUP-reloadable rotation.

See **[deploy/README.md](./deploy/README.md)** for the full deployment walkthrough across all three topologies.

## What this exposes

<!-- BEGIN AUTO-GENERATED TOOLS TABLE -->
**26 tools** across PowerQuery, Mgmt Console, SDL API, Hyperautomation, and UAM Ingest:

| Group | Tool | Skill |
|-------|------|-------|
| PowerQuery | `powerquery_enumerate_sources` | sentinelone-powerquery |
| PowerQuery | `powerquery_run` | sentinelone-powerquery |
| PowerQuery | `powerquery_schema_discover` | sentinelone-powerquery |
| Mgmt Console | `purple_ai_alert_summary` | sentinelone-mgmt-console-api |
| Mgmt Console | `s1_api_delete` | sentinelone-mgmt-console-api |
| Mgmt Console | `s1_api_get` | sentinelone-mgmt-console-api |
| Mgmt Console | `s1_api_patch` | sentinelone-mgmt-console-api |
| Mgmt Console | `s1_api_post` | sentinelone-mgmt-console-api |
| Mgmt Console | `s1_api_put` | sentinelone-mgmt-console-api |
| Mgmt Console | `uam_add_note` | sentinelone-mgmt-console-api |
| Mgmt Console | `uam_get_alert` | sentinelone-mgmt-console-api |
| Mgmt Console | `uam_list_alerts` | sentinelone-mgmt-console-api |
| Mgmt Console | `uam_set_status` | sentinelone-mgmt-console-api |
| SDL API | `sdl_delete_file` | sentinelone-sdl-api |
| SDL API | `sdl_get_file` | sentinelone-sdl-api / sdl-dashboard / sdl-log-parser |
| SDL API | `sdl_list_files` | sentinelone-sdl-api / sdl-dashboard / sdl-log-parser |
| SDL API | `sdl_put_file` | sentinelone-sdl-api / sdl-dashboard / sdl-log-parser |
| SDL API | `sdl_upload_logs` | sentinelone-sdl-api / sdl-log-parser |
| Hyperautomation | `ha_archive_workflow` | sentinelone-hyperautomation |
| Hyperautomation | `ha_export_workflow` | sentinelone-hyperautomation |
| Hyperautomation | `ha_get_workflow` | sentinelone-hyperautomation |
| Hyperautomation | `ha_import_workflow` | sentinelone-hyperautomation |
| Hyperautomation | `ha_list_workflows` | sentinelone-hyperautomation |
| UAM Ingest | `uam_ingest_alert` | sentinelone-mgmt-console-api (UAM Alert Interface) |
| UAM Ingest | `uam_post_alert` | sentinelone-mgmt-console-api (UAM Alert Interface) |
| UAM Ingest | `uam_post_indicators` | sentinelone-mgmt-console-api (UAM Alert Interface) |
<!-- END AUTO-GENERATED TOOLS TABLE -->

**2 resources:**
- `sentinelone://soc-context` - `CLAUDE.md`, the Principal SOC Analyst operating instructions.
- `sentinelone://credentials-status` - which credentials are configured and which API surfaces are available.

**2 prompts:**
- `soc_analyst` - embeds `CLAUDE.md` as a system prompt; call at session start.
- `session_init` - structured init: enumerate sources + triage alerts in parallel.

## Quick install

Two paths, pick one:

### Easiest: `npx` via Amazon Quick

Add this to the MCP configuration (or the Amazon Quick MCP settings):

```json
{
  "mcpServers": {
    "sentinelone-mcp": {
      "command": "npx",
      "args": ["-y", "@pmoses-s1/sentinelone-mcp@1.1.0"],
      "env": {
        "S1_CONSOLE_URL":       "https://usea1-yourorg.sentinelone.net",
        "S1_CONSOLE_API_TOKEN": "eyJ...",
        "S1_HEC_INGEST_URL":    "https://ingest.us1.sentinelone.net",
        "SDL_XDR_URL":          "https://xdr.us1.sentinelone.net",
        "SDL_LOG_READ_KEY":     "...",
        "SDL_LOG_WRITE_KEY":    "...",
        "SDL_CONFIG_READ_KEY":  "...",
        "SDL_CONFIG_WRITE_KEY": "..."
      }
    }
  }
}
```

Restart Amazon Quick. `npx -y` caches the package on first launch.

### Reproducible: install script

```bash
curl -fsSL https://raw.githubusercontent.com/pmoses-s1/s1-aws-quick-skills/main/sentinelone-mcp/deploy/install.sh | bash
```

This sets up a per-user npm prefix if needed, installs the package, drops a credentials skeleton at `~/.config/sentinelone/credentials.json` (mode 0600), and prints the wiring instructions for Amazon Quick.

For VM deployments, the same script in `--server` mode does everything (system user, systemd unit, initial bearer token, service start). See [deploy/README.md](./deploy/README.md).

## Credentials

`S1_CONSOLE_URL` and `S1_CONSOLE_API_TOKEN` are sufficient for the PowerQuery, Mgmt Console REST, Purple AI summary, and UAM tools (16 of the 26).

`S1_HEC_INGEST_URL` is **required** for the three UAM Ingest tools (`uam_ingest_alert`, `uam_post_indicators`, `uam_post_alert`). Without it those tools error at call time, the rest still work.

`SDL_*` keys gate the SDL tools as follows:

| Variable | Description | Required for |
|----------|-------------|--------------|
| `S1_CONSOLE_URL` | Console URL, e.g. `https://usea1-acme.sentinelone.net` | All Mgmt + PowerQuery tools |
| `S1_CONSOLE_API_TOKEN` | Mgmt Console API token (Settings → Users → Service Users) | All Mgmt + PowerQuery + UAM tools |
| `S1_HEC_INGEST_URL` | HEC ingest host, e.g. `https://ingest.us1.sentinelone.net` | `uam_ingest_alert`, `uam_post_indicators`, `uam_post_alert` |
| `SDL_XDR_URL` | SDL tenant URL, e.g. `https://xdr.us1.sentinelone.net` | All `sdl_*` tools and `powerquery_schema_discover` |
| `SDL_LOG_READ_KEY` | SDL Log Read key | SDL query operations |
| `SDL_LOG_WRITE_KEY` | SDL Log Write key (console JWT NOT accepted by this endpoint) | `sdl_upload_logs` |
| `SDL_CONFIG_READ_KEY` | SDL Config Read key | `sdl_list_files`, `sdl_get_file` |
| `SDL_CONFIG_WRITE_KEY` | SDL Config Write key | `sdl_put_file`, `sdl_delete_file` |

### Credential resolution order (highest priority wins)

1. Environment variables (set in the MCP configuration (Settings → Capabilities → MCP) `env`, systemd `EnvironmentFile`, or your shell).
2. `S1_CREDS_FILE` - explicit path to a JSON file (recommended for VM deployments and secret-store integrations).
3. `credentials.json` in the Amazon Quick workspace folder.
4. Walk-up from the current working directory looking for `credentials.json`.
5. `~/mnt/<folder>/credentials.json` (Amazon Quick workspace mounts).
6. `$CLAUDE_CONFIG_DIR/sentinelone/credentials.json`.
7. `~/.config/sentinelone/credentials.json`.

The server logs the resolved credential source at startup so you can diagnose surprise overrides.

## Transport modes

### stdio (default)

The transport used by Amazon Quick, Amazon Quick (CLI), Amazon Quick, and any other client launched via `npx` / `node index.js`.

```bash
sentinelone-mcp                          # auto-discovers credentials
node index.js                            # same as above, from a local clone
```

### Streamable HTTP

```bash
sentinelone-mcp --transport http                       # 127.0.0.1:8765/mcp, no auth
sentinelone-mcp --transport http --host 0.0.0.0        # all interfaces, no auth (loud warning)
MCP_BEARER_TOKENS_FILE=/etc/sentinelone-mcp/bearer-tokens.json \
  sentinelone-mcp --transport http --host 0.0.0.0      # team mode with per-user tokens
```

Configuration via flags or environment variables:

| Flag | Env var | Default | Purpose |
|------|---------|---------|---------|
| `--transport` | `MCP_TRANSPORT` | `stdio` | `stdio` or `http`. |
| `--host` | `MCP_HTTP_HOST` | `127.0.0.1` | HTTP bind address. Use `0.0.0.0` for cross-host access. |
| `--port` | `MCP_HTTP_PORT` | `8765` | HTTP port. |
| `--path` | `MCP_HTTP_PATH` | `/mcp` | MCP endpoint path. |

In HTTP mode the server exposes:

- `POST /mcp` - accepts JSON-RPC, returns JSON-RPC. The MCP entry point.
- `GET /healthz` - returns `200 ok`. For load balancer probes; no auth.

### Team auth: bearer tokens

To enable team auth, set one of:

- `MCP_BEARER_TOKENS_FILE=/path/to/file.json` (recommended). The file is `{ "<name>": "<token>", ... }`. Names appear in audit logs; revoking a user is a one-line edit. SIGHUP reloads without restart.
- `MCP_BEARER_TOKENS="token1,token2,..."` (fallback, no per-user names).

Token rotation:

```bash
sudo vim /etc/sentinelone-mcp/bearer-tokens.json   # add/remove entries
sudo systemctl reload sentinelone-mcp              # SIGHUP, no connection drops
```

If neither env var is set, HTTP transport runs **without** authentication and the server logs a warning at startup. That's acceptable for `--host 127.0.0.1` single-user use; never use it on `0.0.0.0` in production.

### Audit log

Every authenticated HTTP request emits a structured stderr line that systemd captures via journald:

```
[audit] 2026-05-28T15:01:22.413Z | alice | tools/call | name=powerquery_run | 200 ok
[audit] 2026-05-28T15:01:34.221Z | bob   | tools/list | -                  | 200 ok
[audit] 2026-05-28T17:03:11.221Z | -     | -          | -                  | 401 unauthorized
```

## CLI reference

```
sentinelone-mcp [options]

OPTIONS
  --transport <stdio|http>    Transport. Default: stdio.
  --host <host>               HTTP bind address. Default: 127.0.0.1.
  --port <port>               HTTP port. Default: 8765.
  --path <path>               HTTP MCP endpoint path. Default: /mcp.
  -h, --help                  Show help.
  -v, --version               Show server version.
```

## Architecture

```
sentinelone-mcp/
  index.js                    Entry: flag parsing + transport selection
  lib/
    server-core.js            Tool registry, JSON-RPC dispatch (transport-agnostic)
    stdio-transport.js        stdin/stdout JSON-RPC loop
    http-transport.js         Streamable HTTP (node:http, zero deps)
    auth.js                   Bearer token allowlist with SIGHUP reload
    credentials.js            S1 + SDL credential resolution
    s1.js                     Mgmt REST + LRQ PowerQuery + Purple AI + UAM GraphQL
    sdl.js                    SDL config files + V1 query + uploadLogs
    uam-ingest.js             HEC alert/indicator ingestion
  tools/
    powerquery.js             PowerQuery enumerate/run/schema-discover
    mgmt-console.js           S1 REST verbs + Purple AI summary + UAM
    sdl-api.js                SDL config file + log ingestion tools
    hyperautomation.js        Hyperautomation list/get/import/export/archive
    uam-ingest.js             UAM Alert Interface ingestion tools
  deploy/
    install.sh                One-shot installer (Mac and Linux)
    systemd/                  Service unit for Linux VM deployments
    caddy/                    TLS reverse proxy template
    README.md                 Deployment walkthrough
  scripts/
    regen-readme-tools-table.mjs   Tools-table regenerator (no drift)
  tests/                      Smoke + stdio + HTTP test suites (node --test)
```

## Auth patterns (implemented)

| API surface | Auth header | Key |
|-------------|-------------|-----|
| S1 Mgmt REST API | `Authorization: ApiToken <jwt>` | `S1_CONSOLE_API_TOKEN` |
| LRQ PowerQuery | `Authorization: Bearer <jwt>` | Same token, different prefix |
| Purple AI GraphQL | `Authorization: ApiToken <jwt>` | `S1_CONSOLE_API_TOKEN` |
| UAM GraphQL | `Authorization: ApiToken <jwt>` | `S1_CONSOLE_API_TOKEN` |
| UAM HEC ingest | `Authorization: Bearer <jwt>` | `S1_CONSOLE_API_TOKEN` |
| SDL config ops | `Authorization: Bearer <key>` | `SDL_CONFIG_WRITE_KEY` or console JWT |
| SDL uploadLogs | `Authorization: Bearer <key>` | `SDL_LOG_WRITE_KEY` only (console JWT rejected) |

## Testing

```bash
npm test
```

Three test suites under `tests/`:

- `smoke.test.mjs` - introspects `ALL_TOOLS` directly, no spawning. Asserts 26 tools by name; catches any drift between code and the README regenerator.
- `stdio-transport.test.mjs` - spawns the server in stdio mode, exercises `initialize`, `tools/list`, `resources/list`, `prompts/list`, and error handling.
- `http-transport.test.mjs` - spawns in HTTP mode on a random ephemeral port, exercises `/healthz`, `POST /mcp`, both auth-required and auth-optional flows, and the env-var token fallback.

The smoke suite is the source of truth for the tool count and is what `scripts/regen-readme-tools-table.mjs` derives the README table from. If the table goes stale, `npm run regen:readme -- --check` fails CI; `npm run regen:readme` fixes it.

## Updating CLAUDE.md

The `sentinelone://soc-context` resource and `soc_analyst` prompt load `CLAUDE.md` at server startup. Resolution order:

1. `S1_CLAUDE_MD_PATH` env var (explicit absolute path).
2. `<cwd>/CLAUDE.md` - your workspace folder, when launched from there.
3. Same-dir / parent / grandparent of the server's `index.js` - when running from a git clone.

For npx installs without a CLAUDE.md nearby, set `S1_CLAUDE_MD_PATH` in the MCP server's environment variables (Settings > Capabilities > MCP) to point at the file on disk. Restart Amazon Quick to pick up edits.

## Removed tools

`purple_ai_query` and `purple_ai_investigate` were removed on 2026-05-03. Both required a browser-session `teamToken` from `/sdl/v2/graphql` that service-account API tokens never obtain (returns `AsimovError` / `SERVICE_ERROR`). Use `mcp__purple-mcp__purple_ai` instead, which holds the right credentials.

## Version history

See [CHANGELOG.md](./CHANGELOG.md).
