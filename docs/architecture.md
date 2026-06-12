# Architecture

This document explains how the three layers of the SentinelOne AI analyst stack fit together: the skills, the MCP servers, and the CLAUDE.md operating instructions.

---

## The three layers

```
┌─────────────────────────────────────────────────────────────────────┐
│  CLAUDE.md : SOC Analyst persona, evidence rules, session protocol │
│  Read by Amazon Quick from the added folder at conversation start   │
│  Also exposed as MCP resource (sentinelone://soc-context)           │
└────────────────────────────────┬────────────────────────────────────┘
                             │ instructs Amazon Quick how to investigate
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│  MCP Servers : live API access, bypasses sandbox proxy      │
│                                                                     │
│  sentinelone-mcp (this repo, Node.js, local process)               │
│    26 tools: PowerQuery, SDL API, Hyperautomation, Mgmt REST, UAM,  │
│              UAM Ingest                                              │
│                                                                     │
│  purple-mcp (Python, fetched via uvx from GitHub)                  │
│    alert triage, Purple AI NLQ, Deep Visibility, UAM, assets       │
│                                                                     │
│  threat-intel-mcp (required; use your org's approved provider)     │
│    external IOC enrichment; required for CRITICAL classification    │
│    VirusTotal shown as example: any equivalent MCP works          │
└────────────────────────────────┬────────────────────────────────────┘
                             │ tools the assistant calls
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Skills (SKILL.md files) : procedural knowledge Amazon Quick reads  │
│  Auto-discovered from the added folder; loaded on demand            │
│                                                                     │
│  sentinelone-mgmt-console-api   SDL query, Mgmt REST, UAM, Purple  │
│  sentinelone-powerquery         PowerQuery authoring and execution  │
│  sentinelone-sdl-api            SDL log ingest, config file ops     │
│  sentinelone-sdl-dashboard      Dashboard JSON authoring/deploy     │
│  sentinelone-sdl-log-parser     Parser authoring and validation     │
│  sentinelone-hyperautomation    Workflow JSON authoring/import      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## How the layers interact

### CLAUDE.md

`CLAUDE.md` defines the operating persona for every session: Principal SOC Analyst. It contains:

- Mandatory session initialization protocol (enumerate SDL sources, triage alerts in parallel)
- Evidence discipline rules (no fabrication, cite sources inline, mark assumptions explicitly)
- Investigation workflow (triage, enrichment, correlation, MITRE mapping, risk scoring)
- Alert classification rules (no CRITICAL verdict without independent threat intel confirmation)
- Anomaly detection checklist (frequency, timing, geolocation, privilege, chain anomalies)

**How it's loaded:** When you add the `s1-aws-quick-skills` folder to Amazon Quick, `CLAUDE.md` at the repo root is read automatically at conversation start. Additionally, `sentinelone-mcp` exposes it as an MCP resource (`sentinelone://soc-context`) and prompt (`soc_analyst`).

Editing `CLAUDE.md` and starting a new conversation immediately changes the assistant's operating behavior - no restart needed.

### sentinelone-mcp

A local Node.js process that runs outside the sandbox. Because the sandbox may block outbound HTTPS to `*.sentinelone.net`, all API calls go through this server instead, bypassing any proxy restrictions entirely.

It exposes 26 MCP tools across six groups:

| Group | Tools | API surface |
|---|---|---|
| PowerQuery | `powerquery_enumerate_sources`, `powerquery_run`, `powerquery_schema_discover` | SDL LRQ API |
| Mgmt Console | `s1_api_get`, `s1_api_post`, `s1_api_put`, `s1_api_patch`, `s1_api_delete` | S1 REST API v2.1 |
| UAM | `uam_list_alerts`, `uam_get_alert`, `uam_add_note`, `uam_set_status`, `uam_ingest_alert`, `uam_post_alert`, `uam_post_indicators` | UAM GraphQL + HEC ingest |
| SDL | `sdl_list_files`, `sdl_get_file`, `sdl_put_file`, `sdl_delete_file`, `hec_ingest` | SDL config + log write API |
| Hyperautomation | `ha_list_workflows`, `ha_get_workflow`, `ha_import_workflow`, `ha_export_workflow`, `ha_archive_workflow` | HA public + v1 API |
| Purple AI | `purple_ai_alert_summary` | Purple AI GraphQL |

**Configuration:** Add in Amazon Quick → Settings → Capabilities → MCP. See [installation.md](./installation.md) for the full setup.

Full tool reference: [mcp-tools.md](./mcp-tools.md)

### purple-mcp

A separate MCP server (Python, fetched from GitHub via `uvx`) that provides the Purple AI investigation surface. It covers:

- `purple_ai`: natural-language queries against SDL telemetry
- `powerquery`: run raw PowerQuery strings via the SDL LRQ engine
- `list_alerts`, `search_alerts`, `get_alert`, `get_alert_history`, `get_alert_notes`: UAM alert access
- `list_inventory_items`, `search_inventory_items`, `get_inventory_item`: asset inventory
- `list_vulnerabilities`, `get_vulnerability`: CVE and patch gap reporting
- `list_misconfigurations`, `get_misconfiguration`: agent config hygiene
- `uam_add_note`, `uam_set_status`: alert annotation and triage

purple-mcp is complementary to sentinelone-mcp. They share credentials but serve different roles:

| Task | Use |
|---|---|
| SDL PowerQuery hunting | Either: `powerquery_run` (sentinelone-mcp) or `powerquery` (purple-mcp) |
| Natural-language Purple AI queries | purple-mcp `purple_ai` only |
| Alert triage, notes, status | purple-mcp is preferred (richer GraphQL fields); sentinelone-mcp UAM tools as fallback |
| Management Console REST ops (agents, threats, sites, exclusions, IOCs, detection rules) | sentinelone-mcp `s1_api_*` only |
| SDL log ingest, parser/dashboard deploy | sentinelone-mcp SDL tools only |
| Hyperautomation workflow import | sentinelone-mcp HA tools only |

### Skills (SKILL.md files)

Each skill folder contains a `SKILL.md` that Amazon Quick reads when a relevant request triggers the skill. SKILL.md files encode:

- API endpoint paths and required field schemas (confirmed against live API, not just swagger)
- Non-obvious requirements, gotchas, and field-name traps discovered by testing
- Python script reference for running operations locally
- MCP tool guidance (which tool to use for which operation)

The skills are read-only procedural knowledge. They do not execute API calls directly when loaded: they instruct the assistant on *how* to use the MCP tools and scripts to execute operations correctly.

**Skill discovery:** When you add the `s1-aws-quick-skills` folder to Amazon Quick (Settings → Capabilities → Folders), Amazon Quick scans the folder tree for `SKILL.md` files. Each `SKILL.md` has YAML frontmatter with a `name` and `description` field. The description contains trigger phrases - when your message matches, Amazon Quick loads that skill on demand.

No plugin upload, no per-skill installation, no configuration needed beyond adding the folder.

---

## Authentication flow

All four API surfaces use a single service user token (`S1_CONSOLE_API_TOKEN`) plus surface-specific keys for SDL write operations.

```
S1_CONSOLE_API_TOKEN  ──► S1 Mgmt REST API    (Authorization: ApiToken <jwt>)
                      ──► SDL config ops       (Authorization: Bearer <jwt>)
                      ──► UAM GraphQL          (Authorization: ApiToken <jwt>)
                      ──► Purple AI GraphQL    (Authorization: ApiToken <jwt>)
                      ──► LRQ PowerQuery       (Authorization: Bearer <jwt>)

SDL_LOG_WRITE_KEY     ──► SDL uploadLogs       (Authorization: Bearer <key>)
SDL_CONFIG_WRITE_KEY  ──► SDL putFile          (Authorization: Bearer <key>)
```

The console JWT (`S1_CONSOLE_API_TOKEN`) grants access to SDL config and query operations from Management version Z SP5+. The dedicated SDL keys (`SDL_LOG_WRITE_KEY`, `SDL_CONFIG_WRITE_KEY`) are only needed for log ingest and parser/dashboard deployment respectively.

Credential resolution order (highest priority first):

1. Environment variables in MCP configuration (Settings → Capabilities → MCP) - **recommended**
2. `credentials.json` in the repo folder or parent directory (auto-discovered)
3. `~/.config/sentinelone/credentials.json` (terminal fallback)

For the MCP servers, credentials are passed via environment variables in the MCP configuration UI: see [credentials.md](./credentials.md).

---

## Sandbox proxy and why MCP is needed

Amazon Quick's code execution sandbox may restrict outbound HTTPS to certain domains. There are two solutions:

**Option A (recommended): MCP servers.** sentinelone-mcp and purple-mcp run as local processes on your machine, outside the sandbox. API calls go directly from your machine to SentinelOne. No allowlist changes needed.

**Option B: Network allowlist.** If your Amazon Quick configuration supports domain allowlisting, add `*.sentinelone.net` to allowed domains. This lets the skills' Python scripts (`s1_client.py`, `sdl_client.py`) reach the API from inside the sandbox. No MCP server needed, but may require admin configuration.

Most users should use Option A.

---

## Data flow in a typical investigation

```
User: "Investigate alert abc-123"
       │
       ▼
Amazon Quick reads CLAUDE.md instructions for investigation protocol
       │
       ├── purple-mcp: get_alert(abc-123) → alert details, notes, history
       ├── purple-mcp: get_inventory_item(agent_uuid) → asset criticality
       ├── sentinelone-mcp: s1_api_get(/threats, filter=alert) → threat context
       │
       ▼
Amazon Quick reads sentinelone-powerquery SKILL.md → writes hunt query
       │
       ├── sentinelone-mcp: powerquery_enumerate_sources → confirm data sources present
       └── sentinelone-mcp: powerquery_run(hunt_query) → corroborating telemetry
              │
              ▼
       IOC extracted from telemetry
              │
              ├── threat-intel-mcp: get_file_report(hash) → multi-engine verdict
              └── threat-intel-mcp: get_ip_report(ip) → threat actor attribution
                     │
                     ▼
              Amazon Quick generates SOC report with verdict, MITRE mapping,
              IOC table, and recommendations
```

---

## Directory layout

```
s1-aws-quick-skills/
  CLAUDE.md                     SOC Analyst persona and operating instructions
  README.md                     High-level overview (this project)
  credentials.example.json      Template (copy → credentials.json, fill in)
  docs/                         Detailed documentation
    installation.md             Install guide for Amazon Quick
    docker.md                   Docker-based install (alternate)
    architecture.md             How all layers fit together (this file)
    skills.md                   Per-skill capability reference
    mcp-tools.md                All MCP tool schemas and usage notes
    credentials.md              Credential keys, resolution order, where to find each
    testing.md                  Test coverage: what was validated, gotchas per surface
    zero-to-hero.md             Practical onboarding guide (concepts → install → use)
  sentinelone-mgmt-console-api/ Skill: Management Console REST + SDL + UAM + Purple AI
  sentinelone-powerquery/       Skill: PowerQuery authoring and execution
  sentinelone-sdl-api/          Skill: SDL log ingest and config file operations
  sentinelone-sdl-dashboard/    Skill: SDL dashboard authoring and deployment
  sentinelone-sdl-log-parser/   Skill: SDL log parser authoring and validation
  sentinelone-hyperautomation/  Skill: Hyperautomation workflow authoring and import
  sentinelone-mcp/              MCP server (Node.js): 26 tools, stdio transport
```
