# Playbook: Asset enrichment of raw logs

Enrich ingested events with device and user context from the Singularity Asset Inventory. A
thin source log such as `hostname=ABRAX username=adm.webb action=logon` becomes a contextualised
event carrying OS, IP, agent UUID, site, AD principal, SID, group membership, privilege flag,
asset criticality and risk factors, so an analyst can triage without leaving the event.

The asset attributes are not in event telemetry and the unified inventory REST API returns them
null on at least one tenant. The only query path to them is the PowerQuery `datasource` command
(`datasource assets from 'surface/identity'` and `'surface/endpoint'`). See
`sentinelone-powerquery/references/datasource-command.md`.

## Prompts (one required question, the rest defaulted)

Adding an enrichment should take ONE multi-select question. Everything else has a safe default,
so do not ask for it unless the answer is genuinely ambiguous or the user volunteers a change.

- **Required, multi-select:** "What should each event be enriched with?" Offer the enrichment
  source catalog below and let the user pick any combination (for example Device + User, or
  Device + Vulnerabilities + Alerts).
- **Optional toggle (default: parser):** ingest-time parser, or query-time `| lookup`. See the mode table.
- **Optional toggle (default: daily):** Hyperautomation refresh cadence, or none.

Auto-derived, do NOT prompt for these (state them in the preview instead):

- `PREFIX` from the customer or site code.
- `DATASOURCE_NAME` (the source being enriched) from the onboarding context; ask only if unknown.
- Event key fields: `HOSTNAME_FIELD` default `hostname`, `USERNAME_FIELD` default `username`;
  identity key `samAccountName` (switch to `principalName` only if the logs carry `DOMAIN\user`).
- Field set per source: the catalog defaults.
- Empty suppression: on.
- Site: from the active deployment; resolve the name to a siteId.

### Enrichment source catalog (all `datasource` options)

Each row is one selectable enrichment. The builder query, join key, and default fields are fixed,
so the user only picks the row(s); the playbook renders the rest.

| Pick | Builder source | Joins event by | Default enriched fields | Lookup table |
|---|---|---|---|---|
| Device context | `datasource assets from 'surface/endpoint'` | hostname | device_os, device_ip, device_agentuuid, device_lastuser, device_site, device_criticality, device_riskfactors | `{{PREFIX}}EndpointLookup` |
| User / AD context | `datasource assets from 'surface/identity'` | username (samAccountName) | user_principal, user_sid, user_domain, user_dn, user_groups, user_privileged, user_criticality, user_riskfactors | `{{PREFIX}}IdentityLookup` |
| Vulnerabilities | `datasource vulnerabilities` | hostname (assetName) | vuln_open_count, vuln_critical, vuln_high, vuln_max_cvss | `{{PREFIX}}VulnLookup` |
| Misconfigurations | `datasource misconfigurations` | hostname (assetName) | misconfig_count, misconfig_high | `{{PREFIX}}MisconfigLookup` |
| Open alerts | `datasource alerts` | hostname (assetName) or user | alert_open_count, alert_max_severity | `{{PREFIX}}AlertLookup` |
| Cloud resource | `datasource assets from 'surface/cloud'` | hostname or instanceId | cloud_provider, cloud_account, region, instance_type | `{{PREFIX}}CloudLookup` |

Device and User columns are tenant-validated. For Vulnerabilities, Misconfigurations, Alerts, and
Cloud, confirm the real source columns first with `| datasource <name> [from <dataset>] | limit 1`
(field names vary by tenant), then map them into the builder. The aggregate sources
(vulnerabilities, misconfigurations, alerts) group to one row per asset before savelookup:

```
| datasource vulnerabilities
| filter assetName = *
| group vuln_open_count = count(),
        vuln_critical = count(severity == 'CRITICAL'),
        vuln_high = count(severity == 'HIGH')
  by hostname = assetName
| limit 150000
| savelookup '{{PREFIX}}VulnLookup'
```

### Enrichment mode (the optional toggle)

| Mode | Applied | Stored on event | Table size limit | Best for |
|---|---|---|---|---|
| parser (computeFields lookup) | ingest | yes, all fields | up to 150 MB per table | always-on context on a source |
| query (`\| lookup`) | query time | no | up to 150 MB per table | lean storage, analyst picks fields, works in dashboards |
| auto (automatic lookup) | query time, tenant-wide | no | 100 rows, 5 MB, 50 cols | small shared reference sets only |

Automatic lookups do not apply inside dashboards, alert triggers, or parser PowerQueries, and the
100-row cap rules out the full asset tables. Use parser or query mode for the full tables; reserve
auto for small sets. See `sentinelone-powerquery/references/automatic-lookups.md`.

## Step 1: build the selected lookup tables

Build only the tables for the enrichments the user picked in the catalog (not always both). For
each selected row, run its builder through the LRQ runner (sentinelone-powerquery): it reads the
`datasource` and persists with `savelookup`. The shipped builders cover Device
(`assets/savelookup_endpoint.pq`) and User (`assets/savelookup_identity.pq`); render the catalog's
aggregate pattern for Vulnerabilities / Misconfigurations / Alerts / Cloud after confirming their
columns. Empty `riskFactors` (`"[]"`) is converted to null. Verify each table with a `\| lookup`
readback before continuing.

Keys: identity table keyed on `{{USERNAME_KEY}}`; endpoint and the aggregate tables keyed on
hostname. If `USERNAME_KEY` is samAccountName, note in the preview that it is not unique across AD
domains and that principalName (DOMAIN\\sam) is the multi-domain-safe key, provided the source logs
carry that form.

## Step 2: deliver the enrichment

**parser mode.** Render `assets/parser.template.json` (parser `{{PREFIX}}_enrich`, dataSource.name
`{{DATASOURCE_NAME}}`, two computeFields `\| lookup` rewrites against the two tables) and deploy
with `sdl_put_file` to `/logParsers/{{PREFIX}}_enrich`. Bump `metadata.version` on every change.

**query mode.** Do not deploy a parser. Give the analyst ready-to-run `\| lookup` snippets, for
example `<source query> \| lookup <fields> from {{ENDPOINT_TABLE}} by hostname = {{HOSTNAME_FIELD}}`.
Recommend lookup-after-group so the join runs once per key.

**auto mode.** Only for a small table. Add a spec to `/automaticLookups` (read current version
first, append, write back with expectedVersion). Output value field names must be unique across
all specs.

## Step 3: validate

Ingest a sample whose hostname and username exist in the tables, with the parser bound via the
HEC sourcetype, then query back:

```
hostname=<known host> username=<known user> action=logon outcome=success
```

```
dataSource.name = '{{DATASOURCE_NAME}}'
| sort -timestamp | limit 10
| columns timestamp, metadata.version, {{HOSTNAME_FIELD}}, {{USERNAME_FIELD}},
          device_os, device_ip, device_site, device_criticality, device_riskfactors,
          user_principal, user_sid, user_domain, user_groups, user_privileged,
          user_criticality, user_riskfactors
```

Confirm the expected fields populate and that empty values are null, not `"[]"`. Parser changes
take a few minutes to propagate; poll until the new `metadata.version` appears on fresh events.

## Step 4: keep the tables current (Hyperautomation)

If `SCHEDULE_HOUR` is set, render `assets/refresh_workflow.template.json` and deploy it with the
sentinelone-hyperautomation skill. It is a scheduled workflow with two HTTP actions that re-run
the two savelookup queries against the LRQ API, so the tables stay current and keep the empty
suppression. Deploy scoped to the site:

- Import: `POST /web/api/v2.1/hyper-automate/api/public/workflow-import-export/import?siteIds={{SITE_ID}}` with body `{ "data": <workflow> }`.
- To make it visible to the team without running it: `POST /hyper-automate/api/v1/workflows/{id}/publish` (bodyless, `?siteIds={{SITE_ID}}`, returns `204`); it lands as an inactive Shared Draft.
- **Bind the "SentinelOne SDL" connection (Bearer), NOT the "SentinelOne" mgmt connection.** The SDL query endpoint `/sdl/v2/api/queries` requires `Authorization: Bearer`. The mgmt connection signs as `ApiToken` and the action returns HTTP 500 "Header must start with Bearer". The "SentinelOne SDL" connection uses Bearer by default. Tenant-validated 2026-06-13.

## Gotchas

- Single-quote slash dataset names: `from 'surface/identity'`, `from 'surface/endpoint'`.
- `from identity` / `from device` are sparse; use the `surface/*` datasets for full attributes.
- samAccountName is not unique across domains; principalName is the safe key.
- The identity builder filters `objectSid = *`, so SID-less objects return null on lookup (a no-match, not suppression).
- Parsers apply to new events only; re-ingest after each change when validating.
- Automatic lookups: 100 rows / 5 MB / 50 cols combined, and not in dashboards, alert triggers, or parser PQ.
- Lookup datatables (savelookup / `| lookup`) can be up to 150 MB per table, so the `| limit` in the builder queries can be raised well beyond 1000 / 2000 when the inventory is larger. The small 100-row / 5 MB cap applies only to automatic lookups.

## Extending the enrichment

Add fields by extending the savelookup `columns` and the lookup field lists. High-value extras:
identity (serviceAccount, adminCount, groupType, objectGuid, whenChanged), endpoint
(agentVersion, agentNetworkStatus, agentIsInfected, isDcServer, osVersion, lastActiveDt),
and cross-datasource tables from `datasource vulnerabilities` / `misconfigurations` / `alerts`
keyed by assetName or user.

## Reference deployment (validated)

A first deployment was validated on tenant usea1-purple, site pmoses demo: tables
`assetIdentityLookup` (292 rows) and `assetEndpointLookup` (2000 rows), parser
`/logParsers/testLookup` (metadata.version 1.1.0), and the workflow "Refresh Asset Lookups
(testLookup)" (deactivated). The line `hostname=ABRAX username=adm.webb action=logon` enriched to
device_os "Windows 11 Pro", device_criticality "high", device_riskfactors ["High Value"],
user_principal IMPERIUM\\adm.webb, user_sid S-1-5-21-1068759508-3553314729-511895651-1136,
user_groups ["Domain Admins"], with user_criticality and user_riskfactors suppressed to null.
