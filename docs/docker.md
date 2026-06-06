# Docker install (alternate)

A single Docker image bundling all three MCPs (`sentinelone-mcp`, `purple-mcp`, `virustotal-mcp`). Use this path on machines where you can install Docker but cannot install Node, Python, or `uv` directly.

The recommended path is still [npx/uvx](./installation.md). Pick this one when:

- IT policy blocks `npm install -g`, `pip install`, or arbitrary CLI binaries
- You want the three MCPs version-locked together at a known good combo
- You prefer one tool (`docker pull`) for upgrades

Image: `ghcr.io/pmoses-s1/s1-mcps`
Tags: `latest` (main), `1` / `1.1` / `1.1.0` (pinned semver, current), `sha-<short>` (any commit)

- [Prerequisites](#prerequisites)
- [Step 1: Pull the image](#step-1-pull-the-image)
- [Step 2: Add the folder to Amazon Quick](#step-2-add-the-folder-to-amazon-quick)
- [Step 3: Configure MCP servers](#step-3-configure-mcp-servers)
- [Step 4: Verify the install](#step-4-verify-the-install)
- [Troubleshooting](#troubleshooting)
- [CLAUDE.md customization](#claudemd-customization)
- [Upgrading](#upgrading)
- [Trade-offs vs the npx path](#trade-offs-vs-the-npx-path)
- [Building from source](#building-from-source)

---

## Prerequisites

| Requirement | Check | Install |
|---|---|---|
| Docker (Desktop on macOS/Windows, Engine on Linux) | `docker --version` | [docker.com/get-started](https://www.docker.com/get-started/) |
| Amazon Quick desktop app | App is open | Download from your internal distribution channel |
| SentinelOne API token | Settings → Users → Service Users | [Community guide](https://community.sentinelone.com/s/article/000005291) |
| SDL API keys | Singularity Data Lake → API Keys | [Community guide](https://community.sentinelone.com/s/article/000006763) |
| Regional endpoint URLs | `S1_CONSOLE_URL`, `SDL_XDR_URL`, `S1_HEC_INGEST_URL` | [Endpoint URLs by Region](https://community.sentinelone.com/s/article/000004961) |
| VirusTotal API key | [virustotal.com/gui/my-apikey](https://www.virustotal.com/gui/my-apikey) | Free tier is sufficient |

Apple Silicon and Intel are both supported; the image is multi-arch (`linux/amd64` + `linux/arm64`) so qemu emulation is never used.

---

## Step 1: Pull the image

```bash
docker pull ghcr.io/pmoses-s1/s1-mcps:1.1.0
```

Pin to a specific tag (`:1.1.0` or `:1`). Pulling `:latest` works but you'll silently inherit upgrades whenever you re-pull, which makes incident triage harder. About 250 MB compressed, ~600 MB unpacked.

Verify the dispatcher works:

```bash
docker run --rm ghcr.io/pmoses-s1/s1-mcps:1.1.0 help
```

---

## Step 2: Add the folder to Amazon Quick

Add this repo's folder so skills are auto-discovered:

1. Open Amazon Quick → **Settings** → **Capabilities** → **Folders** → **Add Folder**
2. Select the `s1-aws-quick-skills` directory

Amazon Quick scans for `SKILL.md` files and all six skills become available immediately. See the [main installation guide](./installation.md#step-1-add-the-folder-to-amazon-quick) for details.

---

## Step 3: Configure MCP servers

Go to **Settings → Capabilities → MCP** and click **"+ Add MCP / Skill"** for each server. The Docker path uses the same image for all three, with a different entrypoint argument.

### sentinelone-mcp

| Field | Value |
|-------|-------|
| **Name** | `sentinelone-mcp` |
| **Type** | `stdio` |
| **Command** | `docker` |
| **Args** | `run -i --rm --pull=missing -e S1_CONSOLE_URL -e S1_CONSOLE_API_TOKEN -e S1_HEC_INGEST_URL -e SDL_XDR_URL -e SDL_LOG_WRITE_KEY -e SDL_LOG_READ_KEY -e SDL_CONFIG_WRITE_KEY -e SDL_CONFIG_READ_KEY ghcr.io/pmoses-s1/s1-mcps:1.1.0 sentinelone-mcp` |

**Environment Variables:**

| Key | Value |
|-----|-------|
| `S1_CONSOLE_URL` | `https://usea1-yourorg.sentinelone.net` |
| `S1_CONSOLE_API_TOKEN` | `eyJ...your-api-token...` |
| `S1_HEC_INGEST_URL` | `https://ingest.us1.sentinelone.net` |
| `SDL_XDR_URL` | `https://xdr.us1.sentinelone.net` |
| `SDL_LOG_WRITE_KEY` | Your Log Write key |
| `SDL_LOG_READ_KEY` | Your Log Read key |
| `SDL_CONFIG_WRITE_KEY` | Your Config Write key |
| `SDL_CONFIG_READ_KEY` | Your Config Read key |

### purple-mcp

| Field | Value |
|-------|-------|
| **Name** | `purple-mcp` |
| **Type** | `stdio` |
| **Command** | `docker` |
| **Args** | `run -i --rm --pull=missing -e PURPLEMCP_CONSOLE_TOKEN -e PURPLEMCP_CONSOLE_BASE_URL ghcr.io/pmoses-s1/s1-mcps:1.1.0 purple-mcp` |

**Environment Variables:**

| Key | Value |
|-----|-------|
| `PURPLEMCP_CONSOLE_TOKEN` | Same API token as `S1_CONSOLE_API_TOKEN` |
| `PURPLEMCP_CONSOLE_BASE_URL` | Same URL as `S1_CONSOLE_URL` |

### virustotal

| Field | Value |
|-------|-------|
| **Name** | `virustotal` |
| **Type** | `stdio` |
| **Command** | `docker` |
| **Args** | `run -i --rm --pull=missing -e VIRUSTOTAL_API_KEY ghcr.io/pmoses-s1/s1-mcps:1.1.0 virustotal-mcp` |

**Environment Variables:**

| Key | Value |
|-----|-------|
| `VIRUSTOTAL_API_KEY` | Your VirusTotal API key |

**Notes:**

- `-i` is required so Amazon Quick can speak JSON-RPC over stdin.
- `--rm` cleans up the container when the session ends; without it stopped containers accumulate.
- `--pull=missing` makes the first launch pull, subsequent launches skip the registry. Use `--pull=always` if you want to chase `:latest`.
- The `-e VAR` form (no value) tells Docker to inherit the env var from the parent process; the value comes from the environment variables you set in the MCP configuration UI.
- Both `S1_CONSOLE_API_TOKEN` and `PURPLEMCP_CONSOLE_TOKEN` are the same Management Console API token.

After adding all three, **restart Amazon Quick**.

---

## Step 4: Verify the install

Start a new conversation and run:

```
smoke test s1 skills
```

Amazon Quick verifies connectivity to all three Docker-backed MCPs, confirms each skill is loaded, and reports any missing credentials or unreachable endpoints.

To check the image you have running:

```bash
docker run --rm ghcr.io/pmoses-s1/s1-mcps:1.1.0 help
docker image inspect ghcr.io/pmoses-s1/s1-mcps:1.1.0 \
  --format '{{index .Config.Labels "org.opencontainers.image.version"}}'
```

---

## Troubleshooting

If a server shows red/disconnected in Settings → Capabilities → MCP, work through these in order.

### 1. Confirm Docker Desktop is actually running

```bash
docker info | head -3
```

Expected: `Server Version: ...`. If you see `Cannot connect to the Docker daemon`, start Docker Desktop, wait until the whale icon stops animating, and restart Amazon Quick.

### 2. Check MCP server status in Amazon Quick

Go to **Settings → Capabilities → MCP**. Each server shows a status indicator:
- 🟢 Green = connected and healthy
- 🔴 Red = failed to start or crashed

Click a red server to see its error output.

### 3. Run the MCP container by hand

This bypasses Amazon Quick entirely and confirms the image and credentials work end-to-end:

```bash
# Replace placeholders with your real values; this is a one-off test
docker run -i --rm --pull=missing \
  -e S1_CONSOLE_URL='https://usea1-yourorg.sentinelone.net' \
  -e S1_CONSOLE_API_TOKEN='eyJ...' \
  -e SDL_XDR_URL='https://xdr.us1.sentinelone.net' \
  -e SDL_LOG_READ_KEY='...' \
  -e SDL_CONFIG_READ_KEY='...' \
  ghcr.io/pmoses-s1/s1-mcps:1.1.0 sentinelone-mcp <<< '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"smoke","version":"0.1"}}}'
```

Expected: a single JSON line back on stdout with `serverInfo.name = "sentinelone-mcp-server"`. Stderr should show `Tools: 26 registered` and one of the `configured`/`NOT configured` summaries per API surface.

For a less verbose env-source pattern, put the values in a `.env` file and pass it with `--env-file`:

```bash
docker run -i --rm --pull=missing --env-file ~/.config/sentinelone/s1-mcp.env \
  ghcr.io/pmoses-s1/s1-mcps:1.1.0 sentinelone-mcp <<< '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"smoke","version":"0.1"}}}'
```

### Common error signatures

| Error | Meaning |
|---|---|
| `Cannot connect to the Docker daemon` | Docker Desktop is not running, see step 1 |
| `Unable to find image ... pulling from ghcr.io` | First-launch pull, normal, takes 30–90 s |
| `denied: permission_denied` from ghcr.io | Image is private or your network blocks ghcr.io. Run `docker login ghcr.io` if you have a token, or check VPN/proxy. |
| `VIRUSTOTAL_API_KEY environment variable is required` | The env value did not propagate. Re-check the environment variables in Settings → Capabilities → MCP and that the `-e VAR` in Args matches the key name. |
| `pydantic_core.ValidationError ... PURPLEMCP_*` | Same root cause for purple-mcp - env var not reaching the container. |
| `S1 Mgmt API: NOT configured` | sentinelone-mcp boots but no console token reached it; check `S1_CONSOLE_URL` + `S1_CONSOLE_API_TOKEN`. |

---

## CLAUDE.md customization

The Docker image ships a default `CLAUDE.md`. When you add the `s1-aws-quick-skills` folder to Amazon Quick, the repo's `CLAUDE.md` takes precedence - Amazon Quick reads it directly from the folder.

To customize:
1. Edit `s1-aws-quick-skills/CLAUDE.md` locally
2. The changes take effect in the next conversation (no restart needed)

If you want `sentinelone-mcp` to also serve the customized `CLAUDE.md` as an MCP resource, set `S1_CLAUDE_MD_PATH` in the sentinelone-mcp environment variables (Settings → Capabilities → MCP) to the absolute path of your customized file.

---

## Upgrading

```bash
docker pull ghcr.io/pmoses-s1/s1-mcps:1.1.0    # or :latest
```

Then restart Amazon Quick. The next session uses the new image.

To pin to a specific version, update the tag in the Args field for each MCP server in Settings → Capabilities → MCP.

**Skills**: `git pull` in the repo folder and the updated `SKILL.md` files take effect on the next conversation.

---

## Trade-offs vs the npx path

| | npx/uvx path | Docker path |
|---|---|---|
| Host dependencies | Node 18+, uv | Docker only |
| Version management | Each MCP resolves independently | All three locked to one image tag |
| Cold start | ~3 s (cached) | ~5 s (image already pulled) |
| First-ever launch | ~30 s (download) | ~60 s (pull 250 MB) |
| Upgrade | Automatic on launch | Manual `docker pull` |
| Disk | ~100 MB total | ~600 MB image |
| Offline | ❌ (needs registry on first run) | ✅ (once pulled) |
| Restricted environments | May be blocked by IT | Usually Docker is allowed |

---

## Building from source

```bash
git clone https://github.com/pmoses-s1/s1-aws-quick-skills.git
cd s1-aws-quick-skills
docker build -t s1-mcps:local .
```

Then update each MCP server's Args in Settings → Capabilities → MCP to use `s1-mcps:local` instead of `ghcr.io/pmoses-s1/s1-mcps:1.1.0`.
