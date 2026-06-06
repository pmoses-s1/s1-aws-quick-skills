# Changelog

## 1.1.0 — 2026-05-28 (rebuilt 2026-05-31)

### Fixed (rebuild)
- **`s1_api_get` now auto-injects `isLegacy=false` for `/cloud-detection/rules` listings.** Without `isLegacy=false` the S1 API silently omits `queryType="scheduled"` PowerQuery rules from the response — no error, no warning, the response just lies by omission. The handler now guards against this when the caller forgets, and the tool description loudly flags the requirement. This eliminates the "I see zero scheduled detections" failure mode that was producing wrong verdicts when listing Custom Detection rules. Same `1.1.0` version per the rebuild request.

### Added
- **Streamable HTTP transport.** New `--transport http` mode (default stays `stdio`). Single-endpoint POST `/mcp` per the MCP 2024-11-05 spec, plus `/healthz` for load balancer probes. Implementation is pure `node:http`, no new dependencies.
- **Per-user bearer token auth.** New `MCP_BEARER_TOKENS_FILE` env var pointing at a `{ "<name>": "<token>" }` JSON file gives each team member a stable name in audit logs and supports rotation. SIGHUP reloads tokens without dropping connections. `MCP_BEARER_TOKENS` env var (comma-separated raw tokens) is a fallback for small or quick-test setups.
- **Audit logging.** Every authenticated HTTP request emits `[audit] <ts> | <name> | <method> | <param-summary> | <status>` to stderr; systemd captures it via journald.
- **`S1_CREDS_FILE` credential resolver.** Highest-priority explicit path for credentials, useful for VM deployments and secret-store integrations (Vault, Doppler, 1Password Connect, sealed-secrets).
- **Deploy artifacts** under `deploy/`:
  - `install.sh` — one-shot installer for Mac and Linux. `--user` mode for individuals, `--server` mode for Linux VMs (creates `mcp` system user, generates an initial bearer token, installs systemd unit, starts the service).
  - `systemd/sentinelone-mcp.service` — hardened unit with `NoNewPrivileges`, `ProtectSystem=strict`, `MemoryDenyWriteExecute`, SIGHUP-as-reload.
  - `caddy/Caddyfile.example` — TLS reverse proxy template with bearer header gate and streaming-friendly flush.
  - `README.md` — full topology guide (single-user local, single-user HTTP, team VM-hosted) with day-2 operations.
- **Test suite.** Three new files under `tests/`, runnable via `npm test`:
  - `smoke.test.mjs` — source-of-truth tool inventory (26 tools by name).
  - `stdio-transport.test.mjs` — JSON-RPC round trip via spawned stdio process.
  - `http-transport.test.mjs` — HTTP transport end-to-end, bearer auth happy/sad paths.
- **README auto-regenerator** at `scripts/regen-readme-tools-table.mjs`. `npm run regen:readme` keeps the README table in sync with `ALL_TOOLS`. `npm run regen:readme -- --check` fails when stale (suitable for CI).

### Fixed
- **README tool table.** Previous count was 19; actual is 26. Auto-generated now.
- **Header comment in `index.js`.** Previously said 21; updated to 26.
- **`purple_ai_query`** removed from the documentation. The tool itself was removed 2026-05-03 because the underlying API requires a browser-session `teamToken` that service-account API tokens never obtain. The README, `index.js`, and `docs/mcp-tools.md` no longer reference it.
- **`uam_set_status` documentation.** Doc previously said valid status values include `CLOSED`. The source enum is `NEW`, `IN_PROGRESS`, `RESOLVED`; doc now matches.

### Changed
- **Refactored** dispatch out of `index.js` into `lib/server-core.js` so both transports use one code path. `lib/stdio-transport.js` is the extracted stdio loop; `lib/http-transport.js` is new.
- **package.json**:
  - `version` 1.0.0 → 1.1.0
  - new scripts: `start:http`, `test`, `regen:readme`
  - new files included in the npm tarball: `deploy/`, `scripts/`, `CHANGELOG.md`

### Compatibility
- Default invocation is unchanged: `npx -y @pmoses-s1/sentinelone-mcp` still produces a stdio MCP server with identical behavior to 1.0.0.
- Existing MCP client configs (Amazon Quick, `claude_desktop_config.json`, `.mcp.json`) work without modification.
- The 26 tools, 2 resources, and 2 prompts are unchanged from the late-1.0.0 line; only the documentation now matches reality.

## 1.0.0 — 2026-05-07

Initial public release.
- 19 tools across PowerQuery, S1 Mgmt REST, UAM, SDL API, Hyperautomation.
- stdio transport only.
- Credentials via env vars or auto-discovered `credentials.json`.
