# MCP Tools Reference

<<<<<<< HEAD
Full reference for all tools exposed by `sentinelone-mcp` and `purple-mcp`, plus the UEBA behavioural baselining and anomaly detection pipeline. For architecture context, see [architecture.md](./architecture.md).
=======
Full reference for all tools exposed by `sentinelone-mcp` and `purple-mcp`, plus the UEBA behavioral baselining and anomaly detection pipeline. For architecture context see [architecture.md](./architecture.md).
>>>>>>> df3330b (sync tech content from upstream + Amazon Quick docs)

---

## sentinelone-mcp (26 tools)

Runs as a local Node.js process. Source: `sentinelone-mcp/index.js`. Install via the MCP configuration (Settings > Capabilities > MCP): see [installation.md](./installation.md).

### PowerQuery tools

**`powerquery_enumerate_sources`**

Discovers every active data source in your SDL tenant. Returns unique `dataSource.name`, `dataSource.vendor`, and `dataSource.category` values seen in the last N hours.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `hours` | number | 24 | Lookback window. Increase to 168 (7d) if 24h had low volume. |

Run this at the start of every session. Never assume which sources are present - integrations are added/removed between sessions.

**`powerquery_run`**

Executes a PowerQuery string via the SDL Long-Running Query (LRQ) API. Handles the full launch-poll-cancel lifecycle and returns tabular results.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `query` | string | required | PowerQuery string with pipe-separated commands |
| `startTime` | string | now - hours | ISO-8601 UTC start time |
| `endTime` | string | now | ISO-8601 UTC end time |
| `hours` | number | 24 | Lookback window when startTime/endTime omitted |
| `maxRows` | number | 1000 | Maximum rows to return (max 5000) |

Key constraints:
- Per-user rate limit: 3 concurrent LRQ requests
- Per-call deadline: ~60 seconds before timeout
- Wildcard rules: `field=*` for presence check, `* contains 'text'` for full-text search, never use bare `*` alone (causes HTTP 500)

**`powerquery_schema_discover`**

Fetches raw event JSON for a named data source via the V1 query endpoint. Returns full field names and sample values - essential before writing any query against a non-OCSF source.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `dataSourceName` | string | required | Exact case-sensitive `dataSource.name` value |
| `maxEvents` | number | 5 | Number of sample events (max 50) |
| `startTime` | string | "24h" | Lookback string or ISO date |

Use before authoring any hunt query, dashboard panel, or detection rule against a source you haven't queried in this session.

---

### Management Console REST tools

Generic REST wrappers over the S1 Management Console API v2.1 (781 operations, 113 tags). Path always starts with `/web/api/v2.1/`.

**`s1_api_get`**

Read any resource: agents, threats, sites, alerts, detection rules, exclusions, IOCs, accounts, groups, policies, and more.

| Parameter | Type | Description |
|-----------|------|-------------|
| `path` | string | API path, e.g. `/web/api/v2.1/agents` |
| `params` | object | Query string parameters as key-value pairs |

Supports pagination (cursor or skip/limit), filtering, sorting, count, and export. All reads are GET - never POST.

**`s1_api_post`**

Create or action: create IOC, create detection rule, isolate endpoint, add exclusion, import workflow, trigger RemoteOps, etc.

| Parameter | Type | Description |
|-----------|------|-------------|
| `path` | string | API path, e.g. `/web/api/v2.1/threats/mark-as-threats` |
| `body` | object | Complete request body (not auto-wrapped) |

The body is NOT auto-wrapped in `{"data": {...}}` - pass the complete envelope as required by each endpoint.

**`s1_api_put`**

Full-replacement update: update detection rule, update policy, replace exclusion. Requires all mandatory fields.

| Parameter | Type | Description |
|-----------|------|-------------|
| `path` | string | API path |
| `body` | object | Full replacement body |

**`s1_api_patch`**

Partial update. Rare in the S1 API - most endpoints use PUT.

| Parameter | Type | Description |
|-----------|------|-------------|
| `path` | string | API path |
| `body` | object | Fields to change (partial) |

**`s1_api_delete`**

Delete with optional filter body. Many S1 DELETE endpoints accept `{"filter": {"ids": [...]}}`.

| Parameter | Type | Description |
|-----------|------|-------------|
| `path` | string | API path |
| `body` | object | Optional filter body for batch deletes |

---

### UAM (Unified Alert Management) tools

**`uam_list_alerts`**

List UAM alerts via GraphQL. The PRIMARY alert API - covers all types (EDR, STAR, cloud, identity, third-party).

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `first` | number | 20 | Alerts per page (max 100) |
| `after` | string | - | Pagination cursor from prior call |
| `viewType` | string | "ALL" | Scope: ALL, ENDPOINT, IDENTITY, STAR, CUSTOM_ALERTS, CLOUD, THIRD_PARTY |
| `status` | string | - | Filter: "NEW", "IN_PROGRESS", "RESOLVED" (NOT "OPEN") |
| `severity` | string | - | Filter: "CRITICAL", "HIGH", "MEDIUM", "LOW" |
| `detectionProduct` | string | - | Filter: "EDR", "STAR", "CLOUD" |
| `searchText` | string | - | Full-text search across alert fields |
| `startTime` | string | - | ISO-8601 or epoch ms string |
| `endTime` | string | - | ISO-8601 or epoch ms string |

Important: "OPEN" is NOT a valid status value and silently returns 0 results. "FALSE_POSITIVE" is an analystVerdict, not a status.

**`uam_get_alert`**

Full alert detail by UUID including analyst notes, raw indicators, and history.

| Parameter | Type | Description |
|-----------|------|-------------|
| `alertId` | string | UAM alert UUID |

Always call this before making a verdict - notes may contain MDR verdicts that take precedence.

**`uam_add_note`**

Add an analyst note to an alert. Visible to all analysts and MDR.

| Parameter | Type | Description |
|-----------|------|-------------|
| `alertId` | string | UAM alert UUID |
| `note` | string | Note text (cite evidence inline) |

**`uam_set_status`**

Update alert status.

| Parameter | Type | Description |
|-----------|------|-------------|
| `alertId` | string | UAM alert UUID |
| `status` | string | "NEW", "IN_PROGRESS", or "RESOLVED" |

**`purple_ai_alert_summary`**

Generate a Purple AI natural-language summary for a specific alert. Synchronous - no polling.

| Parameter | Type | Description |
|-----------|------|-------------|
| `alertJson` | string | Full alert as JSON string (OCSF format from uam_get_alert) |

---

### UAM Ingest tools

For creating synthetic/test alerts and pushing external threat indicators into UAM.

**`uam_ingest_alert`**

Create a synthetic test alert via HEC. Supports two modes:
- **Two-call mode** (inline=false): POST indicator first, sleep, then POST alert referencing it
- **Inline mode** (inline=true): Single POST with indicator data embedded in alert

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `scope` | string | required | accountId or "accountId:siteId" |
| `title` | string | "MCP Test Alert" | Alert name in UAM |
| `description` | string | - | Alert description |
| `hostname` | string | "mcp-test-host" | Synthetic indicator hostname |
| `filename` | string | "test-payload.exe" | Indicator filename |
| `sha256` | string | zeroed hash | SHA-256 hash (64 hex chars) |
| `sleep_ms` | number | 3000 | Delay between indicator and alert POST (two-call only) |
| `inline` | boolean | false | Single-call mode with embedded indicators |

Requires `S1_HEC_INGEST_URL`.

**`uam_post_indicators`**

POST raw OCSF behavioral indicators to HEC. Batching supported.

| Parameter | Type | Description |
|-----------|------|-------------|
| `scope` | string | accountId or "accountId:siteId" |
| `indicators` | array | Array of OCSF indicator objects |

Each indicator must carry `metadata.profiles=["s1/security_indicator"]` and a unique `metadata.uid`.

**`uam_post_alert`**

POST a single raw OCSF SecurityAlert to HEC. One alert per call - the stitcher silently drops extras.

| Parameter | Type | Description |
|-----------|------|-------------|
| `scope` | string | accountId or "accountId:siteId" |
| `alert` | object | Single OCSF SecurityAlert (class_uid 2002) |

Always post indicators first and wait 3+ seconds before posting the alert.

---

### SDL (Singularity Data Lake) tools

**`sdl_list_files`**

List all configuration files on the SDL tenant. Returns paths organized by type: /logParsers/, /dashboards/, /alerts/, /lookups/, /datatables/.

No parameters.

**`sdl_get_file`**

Read a configuration file's content and version number. Always read before overwriting to prevent concurrent-edit conflicts.

| Parameter | Type | Description |
|-----------|------|-------------|
| `path` | string | Full SDL config path, e.g. "/logParsers/FortiGate" |

**`sdl_put_file`**

Deploy or update a configuration file. Requires `SDL_CONFIG_WRITE_KEY`.

| Parameter | Type | Description |
|-----------|------|-------------|
| `path` | string | Full SDL config path |
| `content` | string | File content (dashboard JSON, parser definition, etc.) |
| `expectedVersion` | number | Current version from sdl_get_file (omit for new files) |

Key constraint: Dashboard JSON requires a `configType` field ("TABBED" or "SIMPLE") or returns HTTP 400. Paths are case-sensitive.

**`sdl_delete_file`**

Delete a configuration file permanently.

| Parameter | Type | Description |
|-----------|------|-------------|
| `path` | string | Full SDL config path |
| `expectedVersion` | number | Current version (strongly recommended) |

**`sdl_upload_logs`**

Ingest raw log events into SDL. Requires `SDL_LOG_WRITE_KEY` (console JWT is NOT accepted).

| Parameter | Type | Description |
|-----------|------|-------------|
| `logContent` | string | Raw log text, newline-separated |
| `parser` | string | Parser name to apply |
| `logfile` | string | Logical logfile identifier |
| `serverHost` | string | Source hostname |

Max 6 MB per request, 10 GB per day.

---

### Hyperautomation tools

**`ha_list_workflows`**

List all Hyperautomation workflows with scope, state, trigger types, and action types.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `limit` | number | 50 | Max per page (max 200) |
| `skip` | number | 0 | Pagination offset |
| `siteIds` | string | - | Comma-separated site IDs |
| `sortBy` | string | "updated_at" | Sort field |
| `sortOrder` | string | "desc" | "asc" or "desc" |

**`ha_get_workflow`**

Fetch a single workflow by workflowId and revisionId.

| Parameter | Type | Description |
|-----------|------|-------------|
| `workflowId` | string | Workflow UUID |
| `revisionId` | string | Revision UUID (from ha_list_workflows) |

**`ha_import_workflow`**

Import workflow JSON into the tenant. Creates in draft state.

| Parameter | Type | Description |
|-----------|------|-------------|
| `workflowJson` | string | Full Hyperautomation workflow JSON |

Requires `Hyper Automate.write` permission. Workflows imported with service user tokens are invisible in the console UI.

**`ha_export_workflow`**

Export all workflows as a ZIP archive. No per-workflow filter.

No parameters.

**`ha_archive_workflow`**

Soft-delete (archive) one or more workflows. NOT easily reversible.

| Parameter | Type | Description |
|-----------|------|-------------|
| `workflowIds` | array | Workflow UUIDs to archive |

---

## purple-mcp (22 tools)

Fetched automatically from GitHub via `uvx`. Source: `github.com/Sentinel-One/purple-mcp`.

### Alert tools

| Tool | Description |
|------|-------------|
| `list_alerts` | List UAM alerts with rich filtering (status, severity, product, date range) |
| `search_alerts` | Text search across alert fields |
| `get_alert` | Full alert detail: indicators, assets, threat info, notes, history |
| `get_alert_history` | Audit log of all status/verdict changes |
| `get_alert_notes` | All analyst notes (including MDR closure notes) |
| `uam_add_note` | Add note to alert (richer field access than sentinelone-mcp) |
| `uam_set_status` | Set alert status |

### Purple AI tools

| Tool | Description |
|------|-------------|
| `purple_ai` | Natural-language query against SDL telemetry (NLQ > PowerQuery > results) |
| `powerquery` | Run raw PowerQuery via LRQ engine |
| `get_timestamp_range` | Convert "last 7 days" to epoch ms |
| `iso_to_unix_timestamp` | Convert ISO-8601 to Unix ms |

### Asset and inventory tools

| Tool | Description |
|------|-------------|
| `list_inventory_items` | Agent inventory: OS, version, groups, policy, last-seen |
| `search_inventory_items` | Search agents by hostname, IP, UUID |
| `get_inventory_item` | Single agent detail (use for asset criticality during triage) |

### Vulnerability tools

| Tool | Description |
|------|-------------|
| `list_vulnerabilities` | CVE and patch gap data per agent |
| `get_vulnerability` | Single CVE detail |

### Misconfiguration tools

| Tool | Description |
|------|-------------|
| `list_misconfigurations` | Agent config hygiene findings |
| `get_misconfiguration` | Single misconfiguration detail |

---

## UEBA: Behavioral Baselining and Anomaly Detection

The skills include a complete UEBA (User and Entity Behavior Analytics) pipeline that works on ANY data source ingested into SDL. This is not a separate tool - it composes the MCP tools above into an end-to-end anomaly detection workflow.

### What it does

For each `(principal, action)` pair in a data source:

1. **Schema discovery** - auto-discovers the right principal field (user/host/IP/role) and action field (event.type/activity_name/action) per source
2. **Baseline building** - runs N daily count slices (default 30 days) to establish normal behavior
3. **Live comparison** - runs a 24h live slice and computes z-scores against the baseline
4. **Anomaly classification** - surfaces three anomaly classes:
   - **SPIKE/DROP** - z-score exceeds threshold (default 2.0) for a known pair
   - **Silent pairs** - pairs active in baseline but zero events in live window (went quiet)
   - **New behavior** - pairs seen in live that have no baseline (first-time activity)

### Principal and action field mapping by source

| Source category | Typical principal | Typical action |
|---|---|---|
| Identity (Okta, Azure AD, Authentik) | `actor.user.email_addr` | `event.type` |
| Email security (Mimecast, Proofpoint) | `actor.user.email_addr` | `event.type` |
| Cloud audit (CloudTrail, GCP, M365) | `actor.user.name` | `event.type` |
| EDR (SentinelOne, Windows Event Logs) | `src.process.user` + `endpoint.name` | `event.type` |
| Firewall (FortiGate, Palo Alto) | `src.ip.address` | `unmapped.action` |
| SaaS (Google Workspace, Microsoft O365) | `actor.user.email_addr` | `event.type` |
| Custom app logs | Auto-discovered via schema probe | Auto-discovered |

### How to use it

**Ad-hoc investigation (via Amazon Quick prompt):**
```
Build a 30-day behavioral baseline for Okta and show me anomalies for today.
Use day-of-week stratification.
```

**Productionised detection (via PowerQuery Alert rule):**
```
Write a PowerQuery Alert rule that detects when any Okta user performs
more than 3 standard deviations above their normal daily activity count.
Use a savelookup baseline refreshed weekly.
```

### Architecture (two patterns)

**Pattern 1: Script-based (ad-hoc)**
Uses `scripts/baseline_anomaly.py` which chains `powerquery_enumerate_sources` > `powerquery_schema_discover` > `powerquery_run` (N daily slices) > client-side z-score computation.

```
powerquery_enumerate_sources  -->  discover source
powerquery_schema_discover    -->  pick principal + action fields
powerquery_run (x30 days)     -->  collect daily counts per (principal, action)
powerquery_run (live 24h)     -->  collect live counts
client-side merge + z-score   -->  surface anomalies
```

Supports:
- Day-of-week stratification (eliminates weekday/weekend false positives)
- Checkpointing to disk (resumable across sessions)
- Per-source field overrides for non-standard schemas
- 3 rps rate limiting (respects per-user LRQ cap)

**Pattern 2: Rule-based (productionised detection)**
Uses PowerQuery `| savelookup` to persist a baseline table in SDL, then a scheduled PowerQuery Alert rule that joins live counts against the baseline via `| lookup` and fires when z > threshold.

Building blocks: `sentinelone-powerquery/examples/behavioral-baselines.md`

### Use cases beyond security

The pipeline is source-agnostic. Any numerical or categorical field works:

| Use case | Source | Principal | Action | Anomaly meaning |
|---|---|---|---|---|
| Insider threat | Okta | user email | event.type | User suddenly performing admin actions they never did before |
| Fraud detection | Custom app logs | user_id | transaction_type | Account doing 10x normal transaction volume |
| Service degradation | CloudTrail | service_name | error_code | API error rate spike for a specific service |
| Shadow IT | FortiGate | src.ip.address | dst_category | User accessing new SaaS categories |
| Data exfiltration | EDR | src.process.user | file_write_count | User writing 5x normal file volume |

---

## Which tool to use for what

| Task | Tool |
|---|---|
| Hunt for process/network/file events | `powerquery_run` or purple-mcp `powerquery` |
| Natural-language investigation query | purple-mcp `purple_ai` |
| List/triage/annotate alerts | purple-mcp alert tools (richer); sentinelone-mcp UAM tools as fallback |
| Agent inventory, vulnerability, misconfiguration | purple-mcp inventory tools |
| Agents, threats, sites, groups, policies (REST) | `s1_api_get` / `s1_api_post` |
| Create/update/delete detection rules or exclusions | `s1_api_post` / `s1_api_put` / `s1_api_delete` |
| Deploy parser or dashboard to SDL | `sdl_put_file` |
| Ingest custom log events | `sdl_upload_logs` |
| Import Hyperautomation workflow | `ha_import_workflow` |
| Behavioral baseline + anomaly detection | `powerquery_run` (chained via baseline_anomaly.py) |
| Enrich IOC (IP, hash, domain, URL) | Threat-intel MCP (default: virustotal) |

---

## Rate limits and constraints

| Constraint | Value | Applies to |
|---|---|---|
| LRQ concurrent requests | 3 per user | `powerquery_run`, purple-mcp `powerquery` |
| LRQ per-call deadline | ~60 seconds | All PowerQuery execution |
| SDL log upload size | 6 MB per request, 10 GB/day | `sdl_upload_logs` |
| UAM alert list page size | 100 max | `uam_list_alerts` |
| HA workflow list page size | 200 max | `ha_list_workflows` |
| Console API rate limit | Varies by endpoint (typically 50-100 req/s) | All `s1_api_*` tools |

---

## Credential requirements by tool group

| Tool group | Required credentials |
|---|---|
| PowerQuery (enumerate, run) | `S1_CONSOLE_URL` + `S1_CONSOLE_API_TOKEN` |
| PowerQuery (schema_discover) | Above + `SDL_XDR_URL` |
| Mgmt Console REST | `S1_CONSOLE_URL` + `S1_CONSOLE_API_TOKEN` |
| UAM (list, get, note, status) | `S1_CONSOLE_URL` + `S1_CONSOLE_API_TOKEN` |
| UAM Ingest | Above + `S1_HEC_INGEST_URL` |
| Purple AI summary | `S1_CONSOLE_URL` + `S1_CONSOLE_API_TOKEN` |
| SDL list/get | `SDL_XDR_URL` + `SDL_CONFIG_READ_KEY` (or console JWT) |
| SDL put/delete | `SDL_XDR_URL` + `SDL_CONFIG_WRITE_KEY` |
| SDL upload_logs | `SDL_XDR_URL` + `SDL_LOG_WRITE_KEY` (console JWT rejected) |
| Hyperautomation | `S1_CONSOLE_URL` + `S1_CONSOLE_API_TOKEN` |
<<<<<<< HEAD
````
=======
>>>>>>> df3330b (sync tech content from upstream + Amazon Quick docs)
