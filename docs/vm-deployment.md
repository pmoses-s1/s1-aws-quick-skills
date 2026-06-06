# Team VM deployment (sentinelone-mcp)

Run one shared `sentinelone-mcp` instance on a Linux VM. Team members all connect to the same instance, the underlying SentinelOne service-user token lives in one place, and each person gets their own bearer token for audit and revocation.

Supported from `sentinelone-mcp` v1.1.0 onward. Does not replace the per-laptop [`npx`/`uvx`](./installation.md) or [Docker](./docker.md) paths; it's a third option for teams.

- [When to use this](#when-to-use-this)
- [Prerequisites](#prerequisites)
- [One-line install](#one-line-install)
- [Fill in credentials](#fill-in-credentials)
- [TLS in front (Caddy)](#tls-in-front-caddy)
- [Adding and revoking team members](#adding-and-revoking-team-members)
- [Client config (per team member)](#client-config-per-team-member)
- [Verifying end-to-end](#verifying-end-to-end)
- [Day-2 operations](#day-2-operations)
- [Audit log](#audit-log)
- [Troubleshooting](#troubleshooting)
- [Full reference](#full-reference)

---

## When to use this

Pick this path when:

- More than one person needs to use `sentinelone-mcp` against the same SentinelOne tenant.
- You'd rather not hand out the underlying S1 service-user token + SDL keys to N laptops.
- You want per-user audit (who ran which tool, when) and easy revocation.

If you're a single user on your own Mac or Linux machine, the [npx/uvx](./installation.md) or [Docker](./docker.md) paths are simpler.

The other two MCPs (`purple-mcp`, `virustotal`) still install per-laptop in this topology; only `sentinelone-mcp` runs server-side. That keeps the threat-intel and Purple AI flows scoped to the analyst's session.

## Prerequisites

| Requirement | Notes |
|---|---|
| Linux VM with systemd | Ubuntu 22.04 LTS, Debian 12, Rocky/Alma 9, or any equivalent systemd distro |
| Node.js 18+ | Installer errors out with apt/dnf hints if missing |
| Reachable from team laptops | Tailscale, VPN, or a private DNS name |
| One SentinelOne service-user token | Settings → Users → Service Users on the S1 console |
| TLS plan | Recommended: Caddy (template provided). Acceptable: nginx, Tailscale TLS, internal CA |

## One-line install

On the target VM:

```bash
curl -fsSL https://raw.githubusercontent.com/pmoses-s1/s1-aws-quick-skills/main/sentinelone-mcp/deploy/install.sh | sudo bash -s -- --server
```

This single command:

1. Creates the `mcp` system user (no shell, no home interactive).
2. Installs `@pmoses-s1/sentinelone-mcp` globally via npm.
3. Drops `/etc/sentinelone-mcp/credentials.json` (placeholder, mode 0600).
4. Generates an initial admin bearer token, writes it to `/etc/sentinelone-mcp/bearer-tokens.json`, and prints it to stdout once.
5. Installs and starts a hardened systemd unit listening on `127.0.0.1:8765/mcp`.

Verify with:

```bash
sudo systemctl status sentinelone-mcp
curl -s http://127.0.0.1:8765/healthz   # -> ok
```

## Fill in credentials

The installer drops a placeholder. Edit it with your real values:

```bash
sudo vim /etc/sentinelone-mcp/credentials.json
```

```json
{
  "S1_CONSOLE_URL":       "https://usea1-yourorg.sentinelone.net",
  "S1_CONSOLE_API_TOKEN": "eyJ...",
  "S1_HEC_INGEST_URL":    "https://ingest.us1.sentinelone.net",
  "SDL_XDR_URL":          "https://xdr.us1.sentinelone.net",
  "SDL_LOG_READ_KEY":     "...",
  "SDL_LOG_WRITE_KEY":    "...",
  "SDL_CONFIG_READ_KEY":  "...",
  "SDL_CONFIG_WRITE_KEY": "..."
}
```

Apply without restart (full restart needed for credentials):

```bash
sudo systemctl restart sentinelone-mcp
```

`S1_CONSOLE_URL` + `S1_CONSOLE_API_TOKEN` are enough for most tools. `S1_HEC_INGEST_URL` is required only for `uam_ingest_alert`, `uam_post_indicators`, `uam_post_alert`. `SDL_*` keys gate the SDL tools per the table in [the MCP README](../sentinelone-mcp/README.md#credentials).

## TLS in front (Caddy)

The MCP binds to `127.0.0.1` only. Put Caddy in front for HTTPS + a second-layer bearer check.

```bash
sudo apt install -y caddy
sudo cp /usr/lib/node_modules/@pmoses-s1/sentinelone-mcp/deploy/caddy/Caddyfile.example /etc/caddy/Caddyfile
sudo vim /etc/caddy/Caddyfile   # change mcp.s1.internal to your DNS / Tailscale name
sudo systemctl reload caddy
```

Default Caddyfile uses `tls internal` (Caddy's built-in CA, suitable for private networks; distribute Caddy's root cert to clients). For a publicly resolvable hostname swap to `tls <your-email>` for Let's Encrypt. For an internal PKI use `tls /path/cert.pem /path/key.pem`. nginx equivalent is in the same example file.

## Adding and revoking team members

Each person gets their own random bearer token. Names appear in the audit log; revocation removes the line and reloads.

```bash
sudo bash -c 'cat > /etc/sentinelone-mcp/bearer-tokens.json' <<EOF
{
  "admin":  "$(openssl rand -hex 32)",
  "alice":  "$(openssl rand -hex 32)",
  "bob":    "$(openssl rand -hex 32)",
  "claire": "$(openssl rand -hex 32)"
}
EOF
sudo chmod 600 /etc/sentinelone-mcp/bearer-tokens.json
sudo chown mcp:mcp /etc/sentinelone-mcp/bearer-tokens.json
sudo systemctl reload sentinelone-mcp   # SIGHUP, zero downtime
```

Hand each person their token over a secure channel (1Password, Signal, etc.).

To revoke: delete the entry and reload. To rotate one token: generate a new value, replace the entry, reload, distribute.

## Client config (per team member)

Each team member adds the shared server in their own Amazon Quick: **Settings > Capabilities > MCP > "+ Add MCP / Skill"**.

For `sentinelone-mcp`, use the **Streamable HTTP** transport type:

| Field | Value |
|-------|-------|
| **Name** | `sentinelone-mcp` |
| **Type** | `http` |
| **URL** | `https://mcp.s1.internal/mcp` |
| **Headers** | `Authorization: Bearer <THEIR_PERSONAL_TOKEN>` |

`purple-mcp` and `virustotal` stay per-laptop (stdio transport). Only `sentinelone-mcp` points at the VM.

For reference, the equivalent JSON structure (useful for scripting or other MCP clients):

```json
{
  "mcpServers": {
    "sentinelone-mcp": {
      "type": "http",
      "url": "https://mcp.s1.internal/mcp",
      "headers": {
        "Authorization": "Bearer <THEIR_PERSONAL_TOKEN>"
      }
    },
    "purple-mcp":    { "command": "uvx",  "args": ["--from", "git+https://github.com/Sentinel-One/purple-mcp.git", "purple-mcp", "--mode", "stdio"], "env": { "PURPLEMCP_CONSOLE_TOKEN": "...", "PURPLEMCP_CONSOLE_BASE_URL": "..." } },
    "virustotal":    { "command": "npx",  "args": ["-y", "@burtthecoder/mcp-virustotal"], "env": { "VIRUSTOTAL_API_KEY": "..." } }
  }
}
```

## Verifying end-to-end

From any team member's machine, replacing `$TOKEN` with their bearer token:

```bash
curl -s -X POST https://mcp.s1.internal/mcp \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | jq '.result.tools | length'
# -> 26
```

`200 ok` with 26 tools listed = green path. `401` = bearer wrong or not in `/etc/sentinelone-mcp/bearer-tokens.json`. `502` from Caddy = MCP backend down (check `systemctl status sentinelone-mcp`).

## Day-2 operations

### Add a team member

```bash
sudo vim /etc/sentinelone-mcp/bearer-tokens.json   # add {"name": "<32 hex>"}
sudo systemctl reload sentinelone-mcp              # SIGHUP, no drops
```

### Revoke access

```bash
sudo vim /etc/sentinelone-mcp/bearer-tokens.json   # remove the entry
sudo systemctl reload sentinelone-mcp
```

### Rotate the SentinelOne service-user token

```bash
sudo vim /etc/sentinelone-mcp/credentials.json     # paste new S1_CONSOLE_API_TOKEN
sudo systemctl restart sentinelone-mcp             # full restart needed for creds
```

### Upgrade the MCP server

```bash
sudo npm install -g @pmoses-s1/sentinelone-mcp@<new-version>
sudo systemctl restart sentinelone-mcp
```

## Audit log

Every authenticated request logs to stderr, captured by journald:

```
[audit] 2026-05-28T15:01:22.413Z | alice | tools/call | name=powerquery_run | 200 ok
[audit] 2026-05-28T16:42:55.108Z | bob   | tools/list | -                  | 200 ok
[audit] 2026-05-28T17:03:11.221Z | -     | -          | -                  | 401 unauthorized
```

Quick filters:

```bash
# everything alice did in the last hour
sudo journalctl -u sentinelone-mcp --since="1 hour ago" | grep '\[audit\].*| alice |'

# all unauthorized attempts today
sudo journalctl -u sentinelone-mcp --since=today | grep '\[audit\].*401'

# all tool calls (not just listings)
sudo journalctl -u sentinelone-mcp -f | grep 'tools/call'
```

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Connection refused` on `127.0.0.1:8765` | Service not running | `sudo systemctl status sentinelone-mcp` then `journalctl -u sentinelone-mcp -n 50`. |
| 401 on every request | No bearer header, or wrong token | Confirm `Authorization: Bearer <token>` is sent. Confirm the token is in `/etc/sentinelone-mcp/bearer-tokens.json`. |
| `connect ECONNREFUSED` to `*.sentinelone.net` | S1 creds missing, or VM has no outbound | `curl -v https://$YOUR_CONSOLE_URL`. Check `/etc/sentinelone-mcp/credentials.json`. |
| `502 Bad Gateway` from Caddy | Backend died between Caddy reload and proxy attempt | `systemctl status sentinelone-mcp` and check journal. |
| Tools/list returns `0` tools | Wrong tag installed, or import error | `sentinelone-mcp --version` (must be 1.1.0+), then `journalctl -u sentinelone-mcp -n 100`. |

## Full reference

The canonical deploy guide lives alongside the MCP source so it stays in lock-step with the code:

**[`sentinelone-mcp/deploy/README.md`](../sentinelone-mcp/deploy/README.md)** - all three topologies (single-user local stdio, single-user HTTP, team VM-hosted), full alternative-deployment notes (Docker, supergateway), and the underlying systemd / Caddy templates.

This page (`docs/vm-deployment.md`) is the on-ramp; the deploy README is the manual.
