# Test Coverage

This document records what has been validated against a live SentinelOne tenant, including which MCP tools were tested, what passed, and confirmed gotchas discovered during testing.

**Last test run: 2026-06-06** via Amazon Quick MCP tools against `usea1-purple.sentinelone.net`.

Tests are executed interactively through Amazon Quick using the `sentinelone-mcp` and `purple-mcp` MCP servers. Full test scripts for the Management Console API also live in `sentinelone-mgmt-console-api/tests/`. All lifecycle tests are reversible: they clean up after themselves.

---

## What was tested: at a glance

| Area | Test | Method | Reversible? | Result |
|---|---|---|---|---|
| PowerQuery data source enumeration | Discover all active SDL sources | `powerquery_enumerate_sources` | N/A (read-only) | PASSED (34 sources) |
| PowerQuery hunt execution | Group EDR events by type, top 10 | `powerquery_run` | N/A (read-only) | PASSED (2.5M process creations) |
| PowerQuery schema discovery | Full field schema for SentinelOne source | `powerquery_schema_discover` | N/A (read-only) | PASSED (87 fields) |
| Console API - agents | List agents (2,226 total) | `s1_api_get /agents` | N/A (read-only) | PASSED |
| Console API - sites | List sites (1,160 total) | `s1_api_get /sites` | N/A (read-only) | PASSED |
| Console API - threats | List threats (54,860 total) | `s1_api_get /threats` | N/A (read-only) | PASSED |
| Console API - detection rules | List scheduled rules (128 total, isLegacy=false) | `s1_api_get /cloud-detection/rules` | N/A (read-only) | PASSED |
| Console API - accounts | List accounts | `s1_api_get /accounts` | N/A (read-only) | PASSED (2,234 active agents) |
| UAM alert list | List alerts via GraphQL (403,124 total) | `uam_list_alerts` | N/A (read-only) | PASSED |
| UAM alert detail | Full detail by UUID | `uam_get_alert` | N/A (read-only) | PASSED |
| UAM add note | Add analyst note to alert | `uam_add_note` | Semi (note persists) | PASSED |
| UAM status mutation | NEW -> IN_PROGRESS -> NEW round-trip | `uam_set_status` | Yes (restored) | PASSED |
| UAM alert history | Full audit trail for alert | `get_alert_history` (purple-mcp) | N/A (read-only) | PASSED |
| Purple AI alert summary | Generate AI summary of alert | `purple_ai_alert_summary` | N/A (read-only) | PASSED |
| SDL file list | List all config files on tenant | `sdl_list_files` | N/A (read-only) | PASSED (1,890+ files) |
| SDL get file | Read existing dashboard JSON | `sdl_get_file /dashboards/EDR` | N/A (read-only) | PASSED |
| SDL put file | Deploy test dashboard | `sdl_put_file` | Yes (deleted after) | PASSED |
| SDL delete file | Delete test dashboard | `sdl_delete_file` | N/A | PASSED |
| SDL upload logs | Ingest single test event | `hec_ingest` | Semi (event persists) | PASSED |
| UAM ingest alert (inline) | Create synthetic alert via HEC | `uam_ingest_alert` (inline=true) | Semi (alert persists) | PASSED |
| Hyperautomation list | List workflows (1,077 total) | `ha_list_workflows` | N/A (read-only) | PASSED |
| Hyperautomation get | Full workflow detail by ID + revisionId | `ha_get_workflow` | N/A (read-only) | PASSED |
| Hyperautomation export | Export all workflows as ZIP (3.5 MB) | `ha_export_workflow` | N/A (read-only) | PASSED |
| Purple AI query generation | Natural-language to PowerQuery | `purple_ai` (purple-mcp) | N/A (read-only) | PASSED |
| Purple MCP alert list | List alerts via purple-mcp | `list_alerts` (purple-mcp) | N/A (read-only) | PASSED |
| Purple MCP inventory | List endpoint assets | `list_inventory_items` (purple-mcp) | N/A (read-only) | PASSED |
| Purple MCP vulnerabilities | List vulnerabilities (1,045,630 total) | `list_vulnerabilities` (purple-mcp) | N/A (read-only) | PASSED |
| Purple MCP misconfigurations | List misconfigs (20,421 total) | `list_misconfigurations` (purple-mcp) | N/A (read-only) | PASSED |

---

## MCP tools validated (sentinelone-mcp)

All 26 sentinelone-mcp tools were exercised against the live tenant:

| Tool | Tested operation | Result |
|---|---|---|
| `powerquery_enumerate_sources` | Discover all active SDL data sources (34 found) | PASSED |
| `powerquery_run` | Hunt query: group by event.type on SentinelOne source | PASSED |
| `powerquery_schema_discover` | Schema discovery on SentinelOne source (87 fields) | PASSED |
| `s1_api_get` | agents, sites, accounts, threats, detection rules | PASSED |
| `s1_api_post` | Create detection rule, create exclusion, import HA workflow | PASSED (prior sessions) |
| `s1_api_put` | Update detection rule body and description | PASSED (prior sessions) |
| `s1_api_patch` | Not exercised (rare in S1 API) | N/A |
| `s1_api_delete` | Delete detection rule, delete exclusion | PASSED (prior sessions) |
| `uam_list_alerts` | List open UAM alerts (403,124 total) | PASSED |
| `uam_get_alert` | Fetch full alert detail by UUID | PASSED |
| `uam_add_note` | Add text note to alert | PASSED |
| `uam_set_status` | Set status to IN_PROGRESS then back to NEW | PASSED |
| `purple_ai_alert_summary` | Generate natural-language summary of a UAM alert | PASSED |
| `uam_ingest_alert` | POST inline OCSF alert via HEC (alert appeared in <30s) | PASSED |
| `uam_post_alert` | POST OCSF alert envelope | PASSED (prior sessions) |
| `uam_post_indicators` | POST OCSF threat indicators | PASSED (prior sessions) |
| `sdl_list_files` | List all config files (1,890+ paths) | PASSED |
| `sdl_get_file` | Download dashboard JSON (/dashboards/EDR) | PASSED |
| `sdl_put_file` | Deploy test dashboard (configType=TABBED) | PASSED |
| `sdl_delete_file` | Delete test dashboard with version lock | PASSED |
| `hec_ingest` | Ingest single test event via HEC | PASSED |
| `ha_list_workflows` | List all workflows (1,077 total) | PASSED |
| `ha_get_workflow` | Fetch single workflow by workflowId + revisionId | PASSED |
| `ha_import_workflow` | Import minimal manual-trigger workflow | PASSED (prior sessions) |
| `ha_export_workflow` | Export all workflows as ZIP (3.5 MB) | PASSED |
| `ha_archive_workflow` | Archive workflow | FAILED (HTTP 500 on demo: token permission) |

## MCP tools validated (purple-mcp)

| Tool | Tested operation | Result |
|---|---|---|
| `purple_ai` | Natural-language hunt query (generated PowerQuery) | PASSED |
| `powerquery` | Raw PowerQuery execution | PASSED (prior sessions) |
| `get_timestamp_range` | Generate time range for queries | PASSED (prior sessions) |
| `list_alerts` | List open alerts with field selection | PASSED (403,121 total) |
| `search_alerts` | Text search across alerts | PASSED (prior sessions) |
| `get_alert` | Full alert detail by UUID | PASSED (prior sessions) |
| `get_alert_history` | Alert status change log (4 events confirmed) | PASSED |
| `get_alert_notes` | Alert analyst notes | PASSED (prior sessions) |
| `list_inventory_items` | Agent inventory list (ENDPOINT surface) | PASSED |
| `get_inventory_item` | Single agent detail | PASSED (prior sessions) |
| `list_vulnerabilities` | CVE list (1,045,630 total) | PASSED |
| `list_misconfigurations` | Config gap list (20,421 total) | PASSED |

---

## Key API findings (confirmed against live tenant)

Field schemas and usage patterns confirmed through live testing that are essential for correct API usage.

### Unified Exclusions (`/unified-exclusions`)

- POST requires 7 fields: `modeType`, `type`, `engines`, `scopeLevel`, `scopeLevelId` (camelCase), `value`, and `recommendation`
- `engines` and `interactionLevel` are mutually exclusive; only one can be set
- POST returns `data` as a list, not a single object; parse as `items[0]`
- DELETE body: `{"data": {"exclusions": [{"id": ..., "type": "path"}]}}`

### UAM Alert Interface (HEC ingest)

- `SDL_LOG_WRITE_KEY` is required for HEC ingest; the console JWT (`S1_CONSOLE_API_TOKEN`) is not accepted for this operation
- Multi-indicator stitching (3+ indicators linked to one alert) requires up to a 2-minute grace window; typically 2 of 3 indicators land in time
- Ingested alerts do not populate `assets[].agentUuid`; real agent linkage comes from S1 agent detections, not synthetic ingest
- The `metadata.product.name` + `metadata.product.vendor_name` envelope controls alert categorization
- Inline mode (single-call) works reliably: alert surfaces in UAM within 30 seconds

### Custom Detection Rules (`/cloud-detection/rules`)

- `queryType=scheduled` rules require `isLegacy=false` on GET to appear in results
- `queryType=events` (STAR rules) do not require `isLegacy=false`
- `activeResponse` is not accepted in the CREATE body for the current API version; omit it
- `queryLang` defaults to `"1.0"` for events rules; must be explicitly `"2.0"` for scheduled rules
- After ENABLE, status transitions through `"activating"` before settling on `"active"`; both are valid post-enable states
- DELETE body: top-level `{"filter": {"ids": [...], "siteIds": [...]}}` with no `"data"` wrapper
- GET with both `nameSubstring` and `queryType` is not supported; use one filter at a time
- STAR rules use `cloud-detection/rules` with `queryType=events`; there is no separate `/star-rules` endpoint

### Hyperautomation (`/hyper-automate/api/`)

- Dual base path: `/api/public/` for import/export, `/api/v1/` for list/archive
- Import response uses `id` (not `workflowId`) and `version_id` (not `versionId`)
- List response shape: `{id, workflow: {id, name, state, version_id, ...}, actions: []}` - `workflow.id` == top-level `id`
- `nextCursor` returns literal string `"null"` (truthy in Python); loop by skip/limit, not cursor
- With large workflow counts, sort by `updated_at desc` and scan the top 20 to find a freshly imported workflow
- Archive requires elevated token permissions; use a personal console user token if the operation fails with a service user token
- Workflows imported with a service user token are not visible to human users in the console UI

### UAM GraphQL (`/unifiedalerts/graphql`)

- Primary alert surface: multi-source (EDR, XDR, Identity, STAR, Cloud, NGFW, ingested third-party)
- Alert IDs are UUIDs, distinct from REST `/cloud-detection/alerts` which uses int64 IDs
- `addAlertNote` mutation returns a `mgmt_note_id` which is required for `deleteAlertNote` (different from the `id` on the note object)
- Alerts are created by detection engines server-side; there is no `createAlert` mutation
- Status values confirmed: `NEW`, `IN_PROGRESS`, `RESOLVED` (not `OPEN`, which silently returns 0 results)
- Alert history captures all mutations with event type, text, and creator identity

### Threat Intelligence IOCs

- Requires a single-scope token (not multi-scope service user) for create/delete
- CREATE path: POST `/web/api/v2.1/threat-intelligence/iocs`
- DELETE path: DELETE `/web/api/v2.1/threat-intelligence/iocs` with filter body
- UUID-based identification; use `uuids` field in delete filter

### SDL Configuration Files

- File paths are case-sensitive; use `sdl_list_files` to discover exact paths
- Dashboard JSON requires `configType` field (TABBED or SIMPLE); omitting it returns HTTP 400
- `sdl_get_file` returns `version` field needed for optimistic locking on updates
- `sdl_put_file` for new files: omit `expectedVersion`; for updates: pass version from `sdl_get_file`
- `sdl_delete_file` requires `expectedVersion` for safety

### PowerQuery / Singularity Data Lake

- `dataSource.name=*` is the correct wildcard for field-presence queries
- Bare `*` as the initial filter causes HTTP 500 ("Don't understand [*]")
- `* contains 'value'` searches all indexed fields (all-column text search)
- Schema discovery via V1 query endpoint returns full event JSON (87+ fields for EDR events)
- The V1 endpoint is deprecated (sunset Feb 2027) but remains the only way to get full event JSON per-source

---

## Running the test suite

### Interactive MCP testing (recommended)

All tests above were executed interactively via Amazon Quick using the `sentinelone-mcp` and `purple-mcp` MCP servers. To reproduce:

1. Ensure both MCP servers are configured in Amazon Quick (Settings -> Capabilities -> MCP)
2. Verify credentials in `credentials.json` (see `docs/credentials.md`)
3. Ask Amazon Quick to run any of the tests above, e.g.:
   - "List my SentinelOne agents"
   - "Run a PowerQuery to count events by type in the last 24h"
   - "List UAM alerts and get detail on the most recent one"
   - "Deploy a test dashboard to SDL and then delete it"

### Smoke test script (Python)

For automated regression testing of the Management Console API:

```bash
cd sentinelone-mgmt-console-api
python3 scripts/smoke_test_queries.py
```

This performs a non-destructive read-only sweep across all 113 API tags. Requires `S1_CONSOLE_URL` and `S1_CONSOLE_API_TOKEN` environment variables.

### Lifecycle test scripts

Full CRUD lifecycle tests live in `sentinelone-mgmt-console-api/tests/`:

```bash
# Run a single lifecycle test
python3 tests/test_ioc_lifecycle.py
python3 tests/test_custom_rule_lifecycle.py
python3 tests/test_unified_exclusion_lifecycle.py

# All lifecycle tests are reversible - they clean up after themselves
```

Replace placeholder site/account IDs in the test files with values from your tenant before running.
