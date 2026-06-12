# Detection rules — STAR / Custom Detection / PowerQuery Alerts

PowerQuery Alerts (and STAR / Custom Detection rules that use a PowerQuery body) have tighter limits than ad-hoc hunts. This file covers how to write detection rule bodies that are correct, cheap, and reliably fire.

## Hard limits

- **1,000 rows maximum** on any intermediate table (including inside `group` and `join`).
- **1 MB RAM** total.
- `nolimit` is not allowed.
- Subqueries are not supported (the Summary service evaluates at ingest time and can't compute inner queries).
- `compare` isn't useful here (alerts don't do timeshift).
- Depending on platform version, `transpose` may not be supported — prefer `group` + explicit columns.
- The rule should return **one row per finding** with stable, well-named columns (the detection engine maps these to alert fields).

If you hit the 1,000-row limit on an intermediate `group`, the alert silently under-counts. This is dangerous for detections — validate the filter is selective enough before saving as a rule.

## Shape of a good rule

```
<highly-selective-initial-filter>
| group
    count = count(),
    first_seen = oldest(timestamp),
    last_seen  = newest(timestamp),
    host       = any(endpoint.name),
    cmdline    = any(src.process.cmdline)
  by agent.uuid, src.process.storyline.id
| filter count >= 5            // the actual detection threshold
| sort -count
| limit 100
```

Why this shape:

- `group by agent.uuid, src.process.storyline.id` gives one row per (endpoint, activity cluster). That matches what the detection engine wants.
- `any(endpoint.name)` / `any(src.process.cmdline)` carry human-readable context through the group. Don't use `array_agg` in an alert body — arrays aren't supported by `savelookup` and bloat the 1 MB budget.
- `oldest(timestamp)` / `newest(timestamp)` are the canonical way to surface the detection window. They require *no* preceding `sort` / `group` / `limit` and must appear in the aggregation.
- `filter count >= N` is the threshold. Keeping the threshold inside the query (rather than tuning outside) keeps the rule self-contained.
- A final `limit` caps the emitted alert count per evaluation window — keeps you honest about alert fatigue.

## Patterns

### 1. Rare-event detection

Something that fires once per endpoint per unusual activity. Low threshold, high specificity.

```
indicator.name = 'EventViewerTampering'
| group
    first_seen = oldest(timestamp),
    last_seen  = newest(timestamp),
    host       = any(endpoint.name),
    count      = count()
  by agent.uuid, src.process.storyline.id
| sort -count
| limit 100
```

### 2. Threshold / rate detection

"More than N of X from one entity in the window."

```
event.login.loginIsSuccessful = false
| group
    fails     = count(),
    src_ips   = estimate_distinct(src.endpoint.ip.address),
    last_seen = newest(timestamp)
  by agent.uuid, event.login.userName
| filter fails >= 10
| sort -fails
| limit 100
```

### 3. Anomaly via combined signals

Combine filters with `and` in the initial filter, not `and` in a computed column — the initial filter is cheapest and gates what the Summary service scans.

```
event.type = 'Process Creation'
src.process.parent.name = 'winword.exe'
src.process.name in ('powershell.exe', 'pwsh.exe', 'cmd.exe', 'wscript.exe', 'cscript.exe', 'mshta.exe', 'regsvr32.exe', 'rundll32.exe')
| group
    count      = count(),
    first_seen = oldest(timestamp),
    last_seen  = newest(timestamp),
    host       = any(endpoint.name),
    cmdline    = any(src.process.cmdline)
  by agent.uuid, src.process.storyline.id
| sort -count
| limit 100
```

### 4. Allowlist via `lookup`

When a rule would otherwise fire too broadly, exclude known-good via a config-managed data table.

```
<filters producing candidate rows>
| lookup is_allowed = allowed from allowlist_hosts by endpoint.name
| filter is_allowed = null                   // kept rows had no allowlist entry
| group count = count(), last_seen = newest(timestamp) by agent.uuid, src.process.storyline.id
| sort -count
| limit 100
```

This uses `lookup` with a config data table (`/datatables/allowlist_hosts`). Keep the table ≤ 400 KB; prefer an opt-in allowlist, not an opt-out denylist, because the former is bounded.

### 5. Join-based correlation

`inner` / `left` joins work in alerts, bounded by the 1,000-row / 1 MB budget. Put strict filters inside each subquery; don't rely on the outer `filter` to prune.

```
| inner join
    lsass_access = (
      indicator.name = 'CredentialDumping'
      | group last = newest(timestamp), host = any(endpoint.name)
        by agent.uuid, src.process.storyline.id
      | sort -last
      | limit 500
    ),
    powershell = (
      event.type = 'Process Creation'
      src.process.name contains 'powershell'
      | group ps_cmdline = any(src.process.cmdline)
        by agent.uuid, src.process.storyline.id
      | limit 500
    )
    on agent.uuid, src.process.storyline.id
| columns agent.uuid, host, ps_cmdline, last
| limit 100
```

## Checklist before saving a rule

- [ ] Initial filter is specific enough that you'd expect far fewer than 1,000 intermediate rows in any realistic window.
- [ ] No `nolimit`, no `compare`, no subqueries.
- [ ] `group` carries `agent.uuid` (or equivalent) so the detection engine can map to an alert asset.
- [ ] `group` includes `oldest(timestamp)` and `newest(timestamp)` (or a `last_seen = …` single value), so the alert has a time.
- [ ] Final `| sort -count | limit N` caps alert volume.
- [ ] Threshold (`filter count >= N`) is set to something your team will actually triage, not 1.
- [ ] Tested in Event Search over a realistic 24-hour window and produces a plausible number of rows (0-5 is good for most detections).

## Mapping fields to alert properties

When a detection rule fires, the detection engine looks for these columns to populate the alert row. Use them verbatim.

| Alert field | Column to emit |
|---|---|
| Storyline | `src.process.storyline.id` |
| Timestamp | `timestamp` (or a `.timestamp`-suffixed column like `last_seen.timestamp`) |
| Evidence | `cmdline = any(src.process.cmdline)`, `path = any(tgt.file.path)`, etc. |
| Count / severity driver | `count = count()` |

Renames are fine: the engine resolves by name, so `host = any(endpoint.name)` is fine; it just helps the analyst read the row.

### Target Asset / entity binding (scheduled rules need `entityMappings`)

A scheduled (PowerQuery) rule **binds the Target Asset via an explicit `entityMappings` config — it is not automatic.** Out of the box a scheduled-rule alert shows "Unknown Device" (`agentUuid: null`); projecting `endpoint.name` / `agent.uuid` columns is necessary but **not sufficient on its own**. The rule must also declare which result columns are the entity, via the top-level `entityMappings` array (the **"Entity column mapping"** field in the rule UI):

```json
"entityMappings": [ { "columnName": "endpoint.name" }, { "columnName": "src_ip" } ]
```

Working recipe for a scheduled rule with a mapped asset — two parts that must agree:

1. Project the entity column(s) in the query body, e.g. `| columns endpoint.name = device.hostname, src_ip = src_endpoint.ip, ...`.
2. Set `data.entityMappings` to those exact output column names: `[{ "columnName": "endpoint.name" }, { "columnName": "src_ip" }]`.

Confirmed on a live tenant: the same rule that showed "Unknown Device" with no `entityMappings` mapped the asset once `entityMappings` was configured on its `endpoint.name` / `src_ip` columns. (The earlier A/B tests showed Unknown Device only because they never set `entityMappings`.)

Other paths that bind the entity:
- **Events-type rules** (`queryType: "events"`) — entity is taken from the matched event automatically. Type follows OCSF `class_uid`: auth/identity classes (e.g. `3002`) bind an **Identity** (user); endpoint classes (e.g. `1008`) bind a **Device**, reconciled via `device.agent.uuid` against inventory.
- **UAM ingest** (indicator/alert posted to `/v1/*`) — asset built from the event's `device` object.

`storylineId` is NOT required for binding.

## Scheduled detection rule — full option set (UI ↔ API)

Every option on the rule's Overview page maps to a field in the `POST/PUT /cloud-detection/rules` body (`data` object unless noted). Confirmed against a live rule.

| UI label | API field | Notes |
|---|---|---|
| Detection name | `data.name` | |
| Description | `data.description` | |
| Severity | `data.severity` | `Critical` / `High` / `Medium` / `Low` |
| Scope | `filter.siteIds` / `accountIds` / `groupIds` / `tenant:true` | site / account / group / global |
| Expiration date | `data.expirationMode` (`Permanent`/`Temporary`) + `data.expiration` | |
| Rule type | `data.queryType` | `scheduled` for PowerQuery bodies |
| Query language | `data.queryLang` | `2.0` for scheduled PowerQuery |
| Query | `data.scheduledParams.query` | PowerQuery body (S1QL goes in `data.s1ql` for `events` rules) |
| **Entity column mapping** | **`data.entityMappings: [{ "columnName": "..." }]`** | maps result columns to the alert entity/asset; without it the alert is "Unknown Device" |
| Run every | `data.scheduledParams.runIntervalMinutes` | |
| Lookup data from the last | `data.scheduledParams.lookbackWindowMinutes` | e.g. 360 = "6 hours" |
| Threshold criteria | `data.scheduledParams.threshold.operator` | e.g. `Greater` |
| Threshold | `data.scheduledParams.threshold.value` | |
| Generate alert per row | `data.scheduledParams.alertPerRow` | bool |
| Deduplication logic | `data.scheduledParams.disableStreaksLogic` | inverse: dedup ON ⇔ `disableStreaksLogic:false` |
| Cool off period | `data.scheduledParams` cool-off settings | suppression window; only present in the payload when enabled (exact key not captured here because it was disabled) |
| Hide logic | `data.hideLogic` | bool |
| Treat as threat (Active Response) | `data.treatAsThreat` | `UNDEFINED` / `Suspicious` / `Malicious`. Scheduled rules must use `UNDEFINED` — mitigation/active-response is not supported on scheduled rules |
| Network quarantine | `data.networkQuarantine` | bool; not supported on scheduled rules |

## Deploying a rule via the API

**For any PowerQuery-bodied detection rule, always deploy as `queryType: "scheduled"` with `queryLang: "2.0"`.** This is the supported PowerQuery detection path on the `cloud-detection/rules` endpoint. The other combinations do not work:

| `queryType` | `queryLang` | Result |
|---|---|---|
| `scheduled` | `"2.0"` | **Correct path for PowerQuery rules.** Accepts pipe syntax. |
| `events` | `"2.0"` | HTTP 400 `Don't understand [|]`. `queryLang: 2.0` is only accepted alongside `queryType: scheduled`. |
| `events` | `"2.1"` | HTTP 400 `queryLang: "2.1" is not a valid choice`. The 2.1 dialect is not in the enum. |
| `events` | `"1.0"` (default) | S1QL log-search syntax only — no pipe syntax. Use this only when the rule body really is S1QL, not PowerQuery. |

The query string goes inside `data.scheduledParams.query`, not in `data.s1ql`. The `s1ql` field is for `queryType: "events"` rules.

### Canonical body for a PowerQuery scheduled detection rule

```json
{
  "data": {
    "name": "Rule name",
    "description": "What it detects (include MITRE technique IDs).",
    "queryType": "scheduled",
    "queryLang": "2.0",
    "severity": "High",
    "status": "Disabled",
    "expirationMode": "Permanent",
    "scheduledParams": {
      "query": "<your PowerQuery here>",
      "runIntervalMinutes": 60,
      "lookbackWindowMinutes": 60,
      "threshold": {"value": 0, "operator": "Greater"}
    }
  },
  "filter": {"accountIds": ["<accountId>"]}
}
```

Notes on the shape:

- **Scope:** `filter` accepts `accountIds` or `siteIds`. Pick the layer the rule should fire at. Account-level rules cover all sites under the account.
- **Threshold:** the trigger threshold is the alert-firing threshold (`scheduledParams.threshold`), not the internal `| filter` inside the PowerQuery. `{value: 0, operator: "Greater"}` means "alert if the PQ returns any rows at all" — combined with an internal `| filter hits >= N`, you get N as the effective threshold.
- **Run interval and lookback:** match these (e.g. 60 / 60) for non-overlapping evaluation. Setting `lookbackWindowMinutes` higher than `runIntervalMinutes` causes overlap and duplicate alerts.
- **`status`:** new rules land as `Draft` on creation regardless of the requested status. Enable separately with `PUT /web/api/v2.1/cloud-detection/rules/enable` (body `{"filter": {"ids": [...], "accountIds": [...]}}`).
- **No `disableAgentMitigation` field:** that property is not part of the scheduled-rule schema. Including it returns HTTP 400 `Unknown field`. Cloud-source PQ rules do not need it.
- **No `treatAsThreat: "Malicious"`:** scheduled rules accept `treatAsThreat: "UNDEFINED"` (or omit) and `networkQuarantine: false`. Mitigation actions are not supported on scheduled rules.

### If creation fails with `feature not enabled` or equivalent

If `POST /web/api/v2.1/cloud-detection/rules` returns an error indicating Scheduled Detections / PowerQuery Alerts are not licensed or not turned on for the tenant, do not retry, do not silently downgrade to S1QL. **Stop and tell the user to enable the Scheduled Detections feature on the tenant before deploying.** Common surface for this in the console: *Settings → Account → Detection / SDL Add-Ons → Scheduled Detections* (exact path varies by platform version). The user needs to enable it (or have their CS/SE enable it) and then the same POST will succeed.

Do not use Hyperautomation workflows to schedule PQ detections. `cloud-detection/rules` is the correct mechanism. HA is for SOAR-style response playbooks.

### Updating and enabling a rule

```
PUT /web/api/v2.1/cloud-detection/rules/{id}        # full-replacement update; all 5 data fields required, plus filter
PUT /web/api/v2.1/cloud-detection/rules/enable      # body: {"filter": {"ids": [...], "accountIds": [...]}}
PUT /web/api/v2.1/cloud-detection/rules/disable     # same shape
```

`GET /cloud-detection/rules?ids=...&accountIds=...&isLegacy=false` requires `isLegacy=false` for scheduled rules — without it the list call returns zero results even when the rules exist and the POST response gave you their IDs.

---

## Testing a rule body before deploying

1. Run it with the Purple MCP `powerquery` tool over the last 24 hours. Confirm it parses and returns 0–N rows (not an error, not thousands).
2. Confirm the threshold (`filter count >= N`) doesn't zero out the result for a known-good example — walk `N` down until you see a row, then set `N` slightly above what a benign environment would produce.
3. Run it over 7 days for baseline volume: expected row count × 7 ≈ what a week of alerting will look like.
4. If the `group`-intermediate ever exceeds 1,000 rows in a 24-hour window, tighten the initial filter.
