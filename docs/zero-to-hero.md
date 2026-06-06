# Zero to Hero: SentinelOne Skills for Amazon Quick

A practical onboarding guide for customers and partners new to Amazon Quick Skills. Read this start to finish (~20 minutes) and you'll understand what skills are, why they matter, and how to get a working SentinelOne AI analyst running in Amazon Quick.

This guide assumes no prior exposure to Amazon Quick Skills or MCP. It covers concepts, installation, and day-to-day use.

- [1. What are Amazon Quick Skills?](#1-what-are-amazon-quick-skills)
- [2. How to use the skills](#2-how-to-use-the-skills)
- [3. Install in 15 minutes](#3-install-in-15-minutes)
- [4. Your first session](#4-your-first-session)
- [5. Walkthroughs by use case](#5-walkthroughs-by-use-case)
- [6. When things don't work](#6-when-things-dont-work)
- [7. Going deeper](#7-going-deeper)

---

## 1. What are Amazon Quick Skills?

### The 30-second version

A **skill** is a folder containing a `SKILL.md` file that teaches Amazon Quick how to do a specific job correctly. The SKILL.md encodes confirmed API field names, validated procedures, gotchas, and the right tool to call for each operation. When your request matches a skill's trigger description, Amazon Quick loads that skill on demand and follows it.

You don't pick skills manually. You describe the outcome you want in plain English, and Amazon Quick routes to the right skill (or several) automatically.

### Why skills matter

Without a skill, Amazon Quick has to guess at the things every API has too many of: field names, endpoint paths, required parameters, output shapes, version-specific behavior. Guessing produces plausible-looking but broken code, wrong field references, and hallucinated fields. Skills replace guesswork with knowledge that has been validated against a live tenant.

For SentinelOne specifically: the Management Console exposes 781 operations across 113 tags. The SDL API has its own auth model, log ingest format, and configuration filesystem. PowerQuery has reserved-field rewrites, type-locked columns, and a per-call deadline that aggregates can blow through. STAR rules have one schema; PowerQuery Alerts have another. Skills capture all of this so the assistant doesn't have to rediscover it on every request.

### The three-layer mental model

Three pieces work together in every session:

```
CLAUDE.md            SOC Analyst persona, evidence rules, session protocol
       |
       v
MCP Servers          Live API access (bypasses the sandbox)
  sentinelone-mcp    26 tools: PowerQuery, SDL, Mgmt REST, UAM, UAM Ingest, Hyperautomation
  purple-mcp         Alert triage, Purple AI NLQ, Deep Visibility, assets, vulns
  threat-intel-mcp   External IOC enrichment (e.g. VirusTotal)
       |
       v
Skills (SKILL.md)    Procedural knowledge: confirmed schemas, field requirements,
                     usage patterns, validated against live tenants
```

A useful analogy: **MCP servers are hands** (they touch the API), **skills are training manuals** (they say how to use the hands), and **CLAUDE.md is the job description** (it says what kind of work to do, in what order, with what discipline).

### How Amazon Quick decides which skill to load

Every skill's `SKILL.md` has YAML frontmatter with a `description` field listing trigger phrases and example requests. When you add a folder to Amazon Quick, it scans for these files and registers them. When you send a message, Amazon Quick scans your text against every available skill description and loads the matching ones.

Triggers are deliberately broad: "hunt for PowerShell", "show me open alerts", "write a parser for this log", "build a dashboard panel" all map cleanly.

You can also be explicit. "Use the SDL log parser skill to..." or "switch to PowerQuery and..." both work, but you almost never need to. Describing the outcome is enough.

### What ships in this repo

| Skill | What it does |
|---|---|
| sentinelone-mgmt-console-api | Query and act on the Management Console: threats, alerts, agents, sites, RemoteOps, Deep Visibility, Hyperautomation, Purple AI, UAM. Includes the source-agnostic behavioral baselining + anomaly detection pipeline. |
| sentinelone-powerquery | Write, debug, and run PowerQuery for threat hunting, STAR detection rules, SDL dashboards, and statistical baseline / anomaly detection rule bodies. |
| sentinelone-sdl-api | Ingest events, run queries, and manage configuration files (parsers, dashboards, lookups) via the Singularity Data Lake API. |
| sentinelone-sdl-dashboard | Design, author, and deploy SDL dashboards: panels, tabs, parameters, and full dashboard JSON. |
| sentinelone-sdl-log-parser | Author and validate SDL log parsers for any log format, with OCSF field mapping by default. |
| sentinelone-hyperautomation | Design and generate Hyperautomation workflow JSON, with optional live console import. |

Plus `CLAUDE.md` at the repo root, which transforms the assistant into a **Principal SOC Analyst**: a structured investigator that runs the same enrichment, correlation, and reasoning process a senior analyst would, on every alert, every time.

### What this gets you (the outcomes)

| Outcome | How |
|---|---|
| Reduce L1 SOC workload by 70%+ | Automated triage, mandatory threat-intel enrichment, and verdict generation eliminate repetitive alert investigation. |
| Elevate every analyst to principal grade | Junior analysts get the same structured investigation framework as seniors. |
| External threat intelligence on every IOC | Mandatory enrichment on every IP, domain, hash, and URL before any verdict. |
| Mean investigation time under 5 minutes | 45-60 minute manual investigations compress to under 5 minutes. |
| Full data estate coverage | Queries OCSF-normalised logs, non-OCSF vendor logs, and raw syslog. Discovers field schemas dynamically per session. |
| Federated search across the data estate | Search and correlate across endpoint, network, identity, and cloud sources in a single session. |

---

## 2. How to use the skills

Your goal: ask Amazon Quick about your SentinelOne tenant in plain English and get correct, evidence-backed answers, dashboards, parsers, and workflows. You don't write any code, edit any SKILL.md files, or pick skills manually. You describe what you want and Amazon Quick routes the request.

Time to first value: about 15 minutes for the install, plus 5 minutes for your first real query.

Once installed, the skills are available in **any Amazon Quick conversation** where the `s1-aws-quick-skills` folder has been added. Start a new chat and describe what you need - that's it.

Amazon Quick reads `CLAUDE.md` from the folder and adopts the SOC Analyst persona automatically. The session protocol runs (data source enumeration, alert triage in parallel), and every skill is one prompt away.

Continue to [Section 3: Install](#3-install-in-15-minutes) to set this up.

---

## 3. Install in 15 minutes

The full reference is [`docs/installation.md`](./installation.md). This section is the compressed walkthrough.

### Prerequisites

| Requirement | Check | Install |
|---|---|---|
| Amazon Quick desktop app | App is open | Download from your internal distribution channel |
| Node.js 18+ | `node --version` | [nodejs.org](https://nodejs.org) |
| `uv` (for purple-mcp) | `uvx --version` | `curl -LsSf https://astral.sh/uv/install.sh \| sh`, then open a new terminal |
| SentinelOne API token | Settings → Users → Service Users | [Community guide](https://community.sentinelone.com/s/article/000005291) |
| SDL API keys | Singularity Data Lake → API Keys | [Community guide](https://community.sentinelone.com/s/article/000006763) |
| Regional endpoint URLs | n/a | [Endpoint URLs by Region](https://community.sentinelone.com/s/article/000004961) |
| Threat intel API key | e.g. [virustotal.com/gui/my-apikey](https://www.virustotal.com/gui/my-apikey) | Free tier is sufficient |

> **On a locked-down machine?** Skip Node/Python entirely and use the Docker install: [`docs/docker.md`](./docker.md).

### Step 1: Add the folder

1. Open Amazon Quick → **Settings** → **Capabilities** → **Folders** → **Add Folder**
2. Select the `s1-aws-quick-skills` directory on your local machine

That's it - all six skills are now available. Amazon Quick scans the folder tree for `SKILL.md` files and registers them automatically.

### Step 2: Add the MCP servers

Go to **Settings → Capabilities → MCP** → click **"+ Add MCP / Skill"** and add each server:

**sentinelone-mcp:**
- Command: `npx`
- Args: `-y @pmoses-s1/sentinelone-mcp`
- Environment Variables: `S1_CONSOLE_URL`, `S1_CONSOLE_API_TOKEN` (minimum), plus `SDL_XDR_URL`, `SDL_LOG_WRITE_KEY`, `SDL_LOG_READ_KEY`, `SDL_CONFIG_WRITE_KEY`, `SDL_CONFIG_READ_KEY` for full SDL access

**purple-mcp:**
- Command: `uvx`
- Args: `--from git+https://github.com/Sentinel-One/purple-mcp.git purple-mcp --mode stdio`
- Environment Variables: `PURPLEMCP_CONSOLE_TOKEN`, `PURPLEMCP_CONSOLE_BASE_URL`

**virustotal:**
- Command: `npx`
- Args: `-y @burtthecoder/mcp-virustotal`
- Environment Variables: `VIRUSTOTAL_API_KEY`

Things people get wrong here:

- `S1_CONSOLE_API_TOKEN` and `PURPLEMCP_CONSOLE_TOKEN` are the **same** token. One service user with read scope is enough for hunting and triage; IR Team scope or higher is needed for response actions like isolate.
- Region URLs vary. Check the [Endpoint URLs by Region](https://community.sentinelone.com/s/article/000004961) article for `S1_HEC_INGEST_URL` and `SDL_XDR_URL`.
- Replace VirusTotal with your organisation's approved threat intel MCP if different.
- `npx -y` answers "yes" to the install prompt the first time and caches the package. After that, launches are instant.

**Restart Amazon Quick after adding the MCP servers.**

### Step 3: Verify

Start a new conversation and say:

```
smoke test s1 skills
```

Amazon Quick verifies connectivity to all three MCPs, confirms each skill is loaded, and reports any missing credentials or unreachable endpoints.

If anything fails, jump to [Section 6: When things don't work](#6-when-things-dont-work).

---

## 4. Your first session

### What happens when you start a conversation

When you start a chat with the `s1-aws-quick-skills` folder added, Amazon Quick reads `CLAUDE.md` and runs the mandatory session protocol:

1. **Enumerates live `dataSource.name` values in your SDL.** This tells Amazon Quick exactly which sources are present (S1 internal, SentinelOne EDR, plus any third-party connectors like Okta, FortiGate, CloudTrail, Mimecast).
2. **Pulls open alerts in parallel** while enumeration runs.
3. **For any non-OCSF source it discovers, runs schema discovery** before authoring any query against it.

This isn't filler. It's why the answers you get later are correct: Amazon Quick never reuses cached field names from a previous session because parsers, reserved-field rewrites, and ingestion changes can drift between sessions.

### Three first prompts to try

Pick whichever feels most useful and run it:

**Triage**
```
Triage today's open alerts and flag anything requiring immediate action.
```
Expect a ranked list with verdicts, IOCs, threat-intel enrichment, MITRE mapping, and recommended response actions.

**Hunt**
```
Hunt for any process that opened a connection to a non-RFC1918 IP in the last 7 days, show me the top endpoints by hit count.
```
Expect a PowerQuery, validated against your data sources, executed, and a ranked endpoint table summarised in chat.

**Build**
```
Build me a SOC overview dashboard with a threat timeline by confidence,
top 10 noisiest endpoints, failed logins over time, and an outbound
connection breakdown by direction. Deploy it to /dashboards/soc-overview.
```
Expect dashboard JSON authored, queries validated against your tenant, the dashboard deployed to SDL, and a confirmation back.

### How to read what Amazon Quick is doing

A few signals tell you which skill is running and what API surface is being used:

- **Tool calls named `sentinelone_mcp_*`** are the local MCP server. Names like `powerquery_run`, `s1_api_get`, `sdl_put_file`, `uam_list_alerts`, `ha_import_workflow` map cleanly to the skill they belong to.
- **Tool calls named `purple_mcp_*`** are the Python Purple MCP. Use these for alert triage, Purple AI NLQ, vulnerabilities, inventory.
- **Tool calls named `virustotal_*`** (or your equivalent) are external threat intel.
- **Skill load indicators** appear inline: Amazon Quick mentions loading the relevant skill before it starts authoring a query.
- **Citations** appear in the assistant's prose. Every fact ties back to a specific tool call, with no fabrication.

### What good output looks like

A correct response has three properties:

1. **Evidence-backed.** Numbers, IOCs, and verdicts cite the tool call that produced them.
2. **Calibrated language.** Amazon Quick uses "confirmed" / "consistent with" / "suggests" / "possible" deliberately, scaled to the strength of the evidence.
3. **No CRITICAL verdict without independent threat intel.** This is enforced by `CLAUDE.md`. If you see a CRITICAL classification, you'll see VirusTotal (or equivalent) corroboration alongside it.

If a response is missing any of these, push back. Amazon Quick will recheck and recalibrate.

---

## 5. Walkthroughs by use case

Each subsection has a sample prompt and what to expect. Run them in your Amazon Quick session.

### Threat hunting

Skill: `sentinelone-powerquery` (plus `sentinelone-mgmt-console-api` for execution).

```
Find PowerShell scripts that encoded a Base64 command, group by endpoint,
and rank by hit count over the last 7 days.
```

What you'll get: a PowerQuery using `event.type`, `src.process.cmdline`, and `array_agg_distinct`, validated against your sources, run, and the top-N endpoints summarised. You can ask Amazon Quick to convert it to a STAR detection rule if it looks useful.

### Alert triage

Skills: `sentinelone-mgmt-console-api`, plus `purple-mcp` for richer GraphQL fields.

```
Triage alert ID abc123: get full details, check notes and history, enrich
any IOCs through the threat-intel MCP, and give me a verdict.
```

What you'll get: the full alert payload, prior analyst notes, MDR verdict, asset criticality lookup, every IOC enriched through the configured threat-intel MCP (VirusTotal in the default bundle), MITRE mapping, and a calibrated verdict. If the verdict is CRITICAL or TRUE POSITIVE, you'll see the threat intel evidence inline.

### Behavioral baselining and anomaly detection

Skill: `sentinelone-mgmt-console-api` (the `baseline_anomaly.py` pipeline) plus `sentinelone-powerquery` for the rule body.

```
Build a 30-day behavioral baseline for Okta and show me anomalies for today.
Use day-of-week stratification.
```

What you'll get: schema auto-discovery to pick the right `principal_field` (e.g. `actor.user.email_addr` for Okta) and `action_field`, 30 daily slices run in parallel under the per-user 3 rps cap, a 24-hour live slice, and three anomaly classes returned: matched z-score deviations (spike or drop), silent pairs (active in baseline, zero today), and new-behavior pairs (active today, no baseline at all).

For a recurring detection, ask Amazon Quick to productionise it as a PowerQuery Alert rule with a `| savelookup` baseline and `| lookup` join.

### Dashboard authoring

Skill: `sentinelone-sdl-dashboard` (plus `sentinelone-sdl-api` for deploy and `sentinelone-powerquery` for panel queries).

```
Create a Purple AI usage dashboard showing queries by analyst over time
and a timeline of usage. Deploy it to /dashboards/purple-ai-usage.
```

What you'll get: dashboard JSON with the right panel types (timeseries, table, single value), every panel query validated against your tenant before deploy, and a confirmation that the dashboard is live in SDL.

### Log parser authoring

Skill: `sentinelone-sdl-log-parser` (plus `sentinelone-sdl-api` for end-to-end validation).

```
Write an SDL parser for this Palo Alto syslog sample, with OCSF field
mapping:

  <paste raw log here>
```

What you'll get: a complete parser definition (`formats`, `patterns`, `lineGroupers`, `rewrites`, `discardAttributes`), OCSF field mapping, deploy to `/logParsers/<name>`, ingest of a test event, and a query confirming the fields appear correctly in SDL.

### Hyperautomation workflows

Skill: `sentinelone-hyperautomation`.

```
Build a workflow that, when a Ransomware indicator fires, isolates the
affected endpoint, creates an IOC for the SHA1 hash, and sends a Slack
notification to #soc-alerts.
```

What you'll get: workflow JSON ready to import. If you ask Amazon Quick to import it, it does so via `ha_import_workflow`. Important note: workflows imported with a service user token are invisible to human users in the console UI. If the workflow needs to be visible and editable in the UI, use a personal console user token.

### SOC reporting

```
Write a SOC Leader report for this investigation as a Word document:
executive summary, incident timeline, IOC table with VT verdicts, MITRE
mapping, root cause, and recommendations.
```

What you'll get: a structured `.docx` saved to your workspace, ready to share.

---

## 6. When things don't work

### "Skill didn't trigger"

Be more specific in your prompt. "Make a thing" is ambiguous; "build a Hyperautomation workflow that..." is unmissable. You can also be explicit: "Use the sentinelone-sdl-dashboard skill to..."

If a skill should have triggered and didn't, ask Amazon Quick `which skills are loaded?` to confirm the folder is connected and skills are registered.

### MCP server not connecting

Check, in order:

1. **MCP status in Settings → Capabilities → MCP.** Each server should show green. Click a red server to see its error output.
2. **Node.js is on PATH** for Amazon Quick. `npx` ships with Node, so this also covers `@burtthecoder/mcp-virustotal` and `sentinelone-mcp`. Restart Amazon Quick after a fresh Node install. On macOS, `which node` should return a path; on Windows, `where node`.
3. **`uvx --version` works in a fresh terminal.** Required for `purple-mcp`. If not, reinstall `uv` and open a new terminal.
4. **First-launch fetch took too long and timed out.** `npx -y @pmoses-s1/sentinelone-mcp` and `uvx purple-mcp` each download on first use. Run them once manually in a terminal to warm the cache, then restart Amazon Quick.
5. **Restart Amazon Quick** after any config change.
6. **Force-refresh the MCP packages** if you suspect a stale cache: `npx clear-npx-cache` and `uvx cache clean purple-mcp`.

### 401 / 403 errors

- **Wrong region URL.** `S1_CONSOLE_URL`, `S1_HEC_INGEST_URL`, and `SDL_XDR_URL` are region-specific. Cross-check against the [Endpoint URLs by Region](https://community.sentinelone.com/s/article/000004961) article.
- **Token scope too low.** Read operations need Viewer or higher; response actions need IR Team or higher.
- **Wrong key for the operation.** `SDL_CONFIG_WRITE_KEY` does NOT grant View Logs access; using it for a query returns 403. The console JWT works for SDL config and query operations on Mgmt Z SP5+; the dedicated SDL keys are only needed for `uploadLogs` and parser/dashboard `putFile`.

### "I imported a workflow but I can't see it in the console UI"

Workflows imported with a service user token are invisible to human users. Generate a personal console user token, update `S1_CONSOLE_API_TOKEN` in the sentinelone-mcp environment variables (Settings → Capabilities → MCP), and re-import.

### "The assistant said something I don't believe"

Push back. Tell Amazon Quick you don't believe a specific claim and ask it to recheck the underlying tool call. The session protocol forbids fabrication; if Amazon Quick can't cite the evidence, it has to retract or recalibrate. This is by design.

### Need a deeper look

Ask Amazon Quick:

```
smoke test s1 skills
```

It runs through every MCP and skill, reports what's healthy, and gives a precise error for anything that isn't.

---

## 7. Going deeper

### Read the full reference docs

| Doc | When to read it |
|---|---|
| [`docs/installation.md`](./installation.md) | Full install reference, including upgrade and credentials fallback |
| [`docs/architecture.md`](./architecture.md) | Data flow, auth model, sandbox proxy explanation |
| [`docs/skills.md`](./skills.md) | Per-skill capability reference |
| [`docs/mcp-tools.md`](./mcp-tools.md) | Every MCP tool with usage notes |
| [`docs/credentials.md`](./credentials.md) | Every credential key and where to find it |
| [`docs/sdl-dashboard.md`](./sdl-dashboard.md) | Every supported panel type with confirmed JSON examples |
| [`docs/testing.md`](./testing.md) | Test coverage matrix and confirmed API field requirements |
| [`sentinelone-mgmt-console-api/SKILL.md`](../sentinelone-mgmt-console-api/SKILL.md) | Confirmed field schemas and required parameters per endpoint |

### Operate at scale

Once you're past first-run, the next leverage points are:

- **Set up scheduled tasks** (Amazon Quick → Scheduled Tasks) for recurring monitoring: nightly behavioral baseline refresh, hourly alert digest, weekly threat summary.
- **Productionise hunts as detection rules.** Anything you find useful in chat can be promoted to a recurring detection.
- **Add custom data sources.** Author a parser, deploy it, and the skills handle every other source the same way (auto-discovery means no per-source hardcoding).

### Get help

- Re-run `smoke test s1 skills` whenever something feels off.
- File issues against the repo with the smoke test output attached.
- For SentinelOne API questions, the Community articles linked throughout this guide are the canonical references.

---

You're ready. Open Amazon Quick, start a new conversation, and ask it to triage today's alerts. Everything else builds from there.
