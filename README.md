# SentinelOne Skills for Amazon Quick

Turn Amazon Quick into a **Principal SOC Analyst** with full SentinelOne API access - threat hunting, alert triage, dashboard authoring, log parser development, and workflow automation, all from natural language.

## What's included

| Skill | Icon | What it does |
|-------|------|-------------|
| [sentinelone-mgmt-console-api](./sentinelone-mgmt-console-api/) | 🛡️ | Query and act on the Management Console: threats, alerts, agents, sites, RemoteOps, Deep Visibility, UAM, Purple AI, IOCs (781 API operations) |
| [sentinelone-powerquery](./sentinelone-powerquery/) | 🔍 | Write, debug, and run PowerQuery for threat hunting, STAR detection rules, SDL dashboards, and behavioral anomaly detection |
| [sentinelone-sdl-api](./sentinelone-sdl-api/) | 🗄️ | Ingest events, run queries, and manage configuration files (parsers, dashboards, lookups) via the Singularity Data Lake API |
| [sentinelone-sdl-dashboard](./sentinelone-sdl-dashboard/) | 📊 | Design, author, validate, and deploy SDL dashboards: panels, tabs, parameters, and full dashboard JSON |
| [sentinelone-sdl-log-parser](./sentinelone-sdl-log-parser/) | 📝 | Author and validate SDL log parsers for any log format, with OCSF field mapping by default |
| [sentinelone-hyperautomation](./sentinelone-hyperautomation/) | ⚡ | Design and generate Hyperautomation workflow JSON, with optional live console import |
| [sentinelone-mcp](./sentinelone-mcp/) | 🔌 | Node.js MCP server exposing 26 tools for direct SentinelOne API access |

## Quick start

### 1. Add the folder to Amazon Quick

Open Amazon Quick → **Settings** → **Capabilities** → **Folders** → **Add Folder** → select this repo's local path.

Alternatively: click the **folder icon** (📁) in the chat input area → **Add folder** → select this repo.

> **Why this works:** Amazon Quick auto-discovers skills by scanning added folders for `SKILL.md` files. Each skill folder in this repo has a `SKILL.md` with frontmatter that tells Amazon Quick when to load it. No plugin upload, no manual skill configuration - just add the folder and all six skills are available immediately.

### 2. Add the MCP servers

Go to **Settings → Capabilities → MCP** → click **"+ Add MCP / Skill"**. Add each server:

#### sentinelone-mcp

| Field | Value |
|-------|-------|
| **Name** | `sentinelone-mcp` |
| **Type** | `stdio` |
| **Command** | `npx` (or `docker` - see [Docker install](./docs/docker.md)) |
| **Args** | `-y @pmoses-s1/sentinelone-mcp` |

Add **Environment Variables**:

| Key | Value | Required |
|-----|-------|----------|
| `S1_CONSOLE_URL` | `https://usea1-yourorg.sentinelone.net` | ✅ |
| `S1_CONSOLE_API_TOKEN` | Your API token (Settings → Users → Service Users) | ✅ |
| `S1_HEC_INGEST_URL` | `https://ingest.us1.sentinelone.net` | For UAM ingest only |
| `SDL_XDR_URL` | `https://xdr.us1.sentinelone.net` | For SDL config/query ops |
| `SDL_LOG_WRITE_KEY` | Your SDL Log Write key | For `sdl_upload_logs` only |
| `SDL_LOG_READ_KEY` | Your SDL Log Read key | For log queries via SDL key |
| `SDL_CONFIG_WRITE_KEY` | Your SDL Config Write key | For `sdl_put_file` only |
| `SDL_CONFIG_READ_KEY` | Your SDL Config Read key | For config reads via SDL key |

#### purple-mcp

| Field | Value |
|-------|-------|
| **Name** | `purple-mcp` |
| **Type** | `stdio` |
| **Command** | `uvx` |
| **Args** | `--from git+https://github.com/Sentinel-One/purple-mcp.git purple-mcp --mode stdio` |

Add **Environment Variables**:

| Key | Value |
|-----|-------|
| `PURPLEMCP_CONSOLE_TOKEN` | Same API token as `S1_CONSOLE_API_TOKEN` |
| `PURPLEMCP_CONSOLE_BASE_URL` | Same URL as `S1_CONSOLE_URL` |

#### virustotal (or your org's threat intel MCP)

| Field | Value |
|-------|-------|
| **Name** | `virustotal` |
| **Type** | `stdio` |
| **Command** | `npx` |
| **Args** | `-y @burtthecoder/mcp-virustotal` |

Add **Environment Variables**:

| Key | Value |
|-----|-------|
| `VIRUSTOTAL_API_KEY` | Your VirusTotal API key |

> **Minimum required:** `S1_CONSOLE_URL` + `S1_CONSOLE_API_TOKEN` on `sentinelone-mcp` gives you access to 20 of 26 tools. Add SDL keys only if you need log ingestion or parser/dashboard deployment.

### 3. Verify it works

Start a new Amazon Quick conversation and say:

```
enumerate all data sources on my SentinelOne tenant
```

You should see a list of all connected SDL data sources within seconds.

For a comprehensive check:

```
smoke test s1 skills
```

Amazon Quick verifies connectivity to all MCP servers, confirms each skill is loaded, and reports any missing credentials or unreachable endpoints.

## What you can do

### Threat hunting & investigations
```
hunt for powershell making outbound connections in the last 24 hours
```
```
triage today's open alerts and flag anything requiring immediate action
```
```
investigate alert ID <id> - full enrichment, verdict, and recommended response
```

### Alert management
```
list all critical alerts from the last 7 days
```
```
add a note to alert <id>: "Confirmed false positive - scheduled backup task"
```
```
resolve alert <id>
```

### Dashboard creation
```
build me a FortiGate security dashboard
```
```
create a SOC overview dashboard for all data sources
```

### Log parser development
```
write a parser for this syslog: <paste log sample>
```
```
debug why my Cisco ASA parser isn't extracting the destination port
```

### Workflow automation
```
build a Hyperautomation workflow that disables a user when a critical alert fires
```
```
create a scheduled workflow that runs a daily threat hunt and posts results to Slack
```

### Endpoint management
```
list all endpoints with high severity threats
```
```
how many agents are disconnected?
```
```
isolate endpoint <name>
```

## MCP server tools (26 total)

### PowerQuery (3 tools)
| Tool | Description |
|------|-------------|
| `powerquery_enumerate_sources` | Discover all active SDL data sources |
| `powerquery_run` | Execute PowerQuery against SDL (LRQ API) |
| `powerquery_schema_discover` | Fetch full event JSON for schema discovery |

### Management Console (8 tools)
| Tool | Description |
|------|-------------|
| `s1_api_get` | GET any S1 REST endpoint |
| `s1_api_post` | POST (actions, mutations) |
| `s1_api_put` | PUT (full updates) |
| `s1_api_delete` | DELETE operations |
| `s1_api_patch` | PATCH (partial updates) |
| `uam_list_alerts` | List UAM alerts via GraphQL |
| `uam_get_alert` | Get full alert details + notes |
| `uam_add_note` | Add analyst note to alert |
| `uam_set_status` | Update alert status |

### SDL API (5 tools)
| Tool | Description |
|------|-------------|
| `sdl_list_files` | List all config files (parsers, dashboards, etc.) |
| `sdl_get_file` | Read a config file |
| `sdl_put_file` | Deploy/update a config file |
| `sdl_delete_file` | Delete a config file |
| `sdl_upload_logs` | Ingest raw log events |

### Hyperautomation (5 tools)
| Tool | Description |
|------|-------------|
| `ha_list_workflows` | List workflows |
| `ha_get_workflow` | Get workflow definition |
| `ha_import_workflow` | Import workflow JSON |
| `ha_export_workflow` | Export workflows |
| `ha_archive_workflow` | Archive (soft-delete) workflow |

### UAM Ingest (3 tools)
| Tool | Description |
|------|-------------|
| `uam_ingest_alert` | Create synthetic test alert in UAM |
| `uam_post_indicators` | Push OCSF indicators to UAM |
| `uam_post_alert` | Push OCSF alert to UAM |

### Purple AI (1 tool)
| Tool | Description |
|------|-------------|
| `purple_ai_alert_summary` | Get AI-generated alert summary |

## Architecture

```
s1-aws-quick-skills/
├── sentinelone-mcp/              # MCP server (entry point for all API access)
│   ├── index.js                  # JSON-RPC stdio server
│   ├── lib/                      # Core libs (credentials, s1.js, sdl.js)
│   └── tools/                    # Tool definitions by domain
├── sentinelone-mgmt-console-api/ # Skill: Console API reference + scripts
│   ├── SKILL.md                  # Skill definition (loaded by Amazon Quick)
│   ├── scripts/                  # Python utilities (s1_client, pq runner, etc.)
│   └── references/               # Per-tag API docs, workflows, capability map
├── sentinelone-powerquery/       # Skill: PQ grammar, rules, examples
├── sentinelone-sdl-api/          # Skill: SDL methods, auth, schema discovery
├── sentinelone-sdl-dashboard/    # Skill: Dashboard JSON authoring + validation
├── sentinelone-sdl-log-parser/   # Skill: Parser authoring + OCSF mapping
├── sentinelone-hyperautomation/  # Skill: Workflow JSON generation
├── docs/                         # Architecture guides
├── CLAUDE.md                     # SOC Analyst operating instructions
└── credentials.example.json      # Template (copy → credentials.json, fill in)
```

## How skills are discovered

When you add this repo folder to Amazon Quick, it scans the directory tree for `SKILL.md` files. Each `SKILL.md` has YAML frontmatter with a `description` field containing trigger phrases. When your message matches a skill's triggers, Amazon Quick loads that `SKILL.md` on demand and follows its instructions.

You don't need to install, upload, or configure individual skills. Adding the folder is the entire install.

## Authentication

The MCP server supports two credential sources (environment variables take precedence):

1. **Environment variables** (set in Amazon Quick → Settings → Capabilities → MCP) - recommended
2. **`credentials.json`** file - auto-discovered by walking up from the server's directory

See [`credentials.example.json`](./credentials.example.json) for the template.

### Token types

| Token | Where to get it | What it unlocks |
|-------|----------------|-----------------|
| **Console API Token** | S1 Console → Settings → Users → Service Users → Generate API Token | All 781 REST endpoints + UAM GraphQL + Purple AI + LRQ PowerQuery |
| **SDL Log Write Key** | SDL tenant → Admin → API Keys → Log Write | `sdl_upload_logs` (console token rejected) |
| **SDL Config Write Key** | SDL tenant → Admin → API Keys → Config Write | `sdl_put_file` (parser/dashboard deploy) |

## Prerequisites

- **Node.js ≥ 18** (for `npx`-based MCP servers)
- **`uv`** (for `uvx`-based purple-mcp) - install: `curl -LsSf https://astral.sh/uv/install.sh | sh`
- **Amazon Quick** desktop app
- A SentinelOne tenant with API access

> **On a locked-down machine?** A Docker-based install is available - one image bundles all three MCPs, no host-level Node/Python/uv required. See [`docs/docker.md`](./docs/docker.md).

## PrincipalSOCAnalyst Mode

The `CLAUDE.md` file at the root transforms the assistant into a **Principal SOC Analyst** that runs structured investigations:

1. **Session init**: Enumerates all data sources, triages open alerts in parallel
2. **Investigation**: VirusTotal enrichment on every IOC, cross-source correlation, MITRE ATT&CK mapping
3. **Reporting**: Generates structured SOC reports with evidence, timeline, and recommendations

To activate: add this folder to your Amazon Quick conversation. Amazon Quick reads `CLAUDE.md` automatically and adopts the SOC Analyst persona. Alternatively, the `sentinelone-mcp` server exposes it as an MCP resource (`sentinelone://soc-context`) and prompt (`soc_analyst`).

## Contributing

1. Fork this repo
2. Make changes to skills or the MCP server
3. Test against a live SentinelOne tenant
4. Submit a PR

## License

MIT
