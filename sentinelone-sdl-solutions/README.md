# sentinelone-sdl-solutions

Deploy packaged, repeatable SentinelOne Singularity Data Lake (SDL) solutions into a specific
customer site from one short prompt. This skill is an orchestration layer: it collects a few
parameters, previews the rendered config, then deploys and validates through the primitive
SentinelOne skills (`sentinelone-powerquery`, `sentinelone-sdl-api`, `sentinelone-sdl-log-parser`,
`sentinelone-sdl-dashboard`, `sentinelone-mgmt-console-api`, `sentinelone-hyperautomation`). It does
not reimplement them.

Use it for whole solutions. For a single query, parser, dashboard, or workflow, use the matching
primitive skill directly.

## Solutions

| Solution | What it does | Guide | Playbook (Claude-facing) |
|---|---|---|---|
| Data source onboarding | Take a raw stream already reaching the tenant and operationalise it end to end: OCSF normalisation, device/user enrichment, dashboard, MITRE-mapped detections, and a SOC threat-response playbook | [guide](../docs/solutions/data-source-onboarding.md) | [`references/data-source-onboarding.md`](references/data-source-onboarding.md) |
| Asset enrichment | Enrich raw logs with device, user, vulnerability, misconfiguration, alert, or cloud context from the Asset Inventory, at ingest or at query time | [guide](../docs/solutions/asset-enrichment.md) | [`references/asset-enrichment.md`](references/asset-enrichment.md) |

## Run it with one prompt

- *"Onboard the cisco_meraki logs on the Acme site"*
- *"Bring our new FortiGate firewall source into AI SIEM and build detections and a dashboard"*
- *"Deploy the asset enrichment solution for Acme on the Acme site"*
- *"Enrich the firewall logs with device and user info"*

Adding an enrichment is a single multi-select question (Device, User/AD, Vulnerabilities,
Misconfigurations, Open alerts, Cloud). Everything else is auto-derived and shown in the preview.

## How it runs

Pick the solution, collect parameters with a short prompt set (sensible defaults), confirm the
target site, preview the rendered config, deploy in dependency order, validate against live data,
and summarise the deployed artifacts. Full loop and conventions are in
[`SKILL.md`](SKILL.md) (the file Claude loads).

## Layout

- `SKILL.md` - what Claude reads: the router, the deployment loop, conventions, dependencies.
- `references/` - one self-contained playbook per solution (execution detail).
- `assets/` - parameterized templates (savelookup queries, parser, dashboard, detection, workflows) with `{{TOKEN}}` placeholders.

## Adding a new solution

Add `references/<solution>.md` (a self-contained playbook), its templates under `assets/`, a row
in the Solutions table above and in `SKILL.md`, and name the solution in the `SKILL.md` frontmatter
description so it triggers. A human guide under `docs/solutions/<solution>.md` linked from the repo
README is recommended.
