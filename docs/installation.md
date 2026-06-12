# Installation and Upgrade Guide

Three steps from zero to a working PrincipalSOCAnalyst session: add the folder, configure MCP servers, verify.

Skills are auto-discovered from the folder - no plugin upload, no per-skill install. MCP servers run via package managers (`npx` and `uvx`). New machine = add the folder, paste the MCP config, paste the tokens, done.

> **On a locked-down machine?** A Docker-based install path is also available: one image bundles all three MCPs, no host-level Node/Python/uv required. See [`docker.md`](./docker.md).

- [Prerequisites](#prerequisites)
- [Step 1: Add the folder to Amazon Quick](#step-1-add-the-folder-to-amazon-quick)
- [Step 2: Configure MCP servers](#step-2-configure-mcp-servers)
- [Step 3: Verify the install](#step-3-verify-the-install)
- [Upgrading](#upgrading)
- [Configuration reference](#configuration-reference)
- [Building from source](#building-from-source)

---

## Prerequisites

| Requirement | Check | Install |
|---|---|---|
| Amazon Quick desktop app | App is open | Download from your internal distribution channel |
| Node.js 18+ | `node --version` | [nodejs.org](https://nodejs.org) |
| `uv` (for purple-mcp) | `uvx --version` | `curl -LsSf https://astral.sh/uv/install.sh \| sh`, then open a new terminal |
| SentinelOne API token | Settings → Users → Service Users | [Community guide](https://community.sentinelone.com/s/article/000005291) |
| SDL API keys | Singularity Data Lake → API Keys | [Community guide](https://community.sentinelone.com/s/article/000006763) |
| Regional endpoint URLs | `S1_CONSOLE_URL`, `SDL_XDR_URL`, `S1_HEC_INGEST_URL` | [SentinelOne Endpoint URLs by Region](https://community.sentinelone.com/s/article/000004961) |
| VirusTotal API key | [virustotal.com/gui/my-apikey](https://www.virustotal.com/gui/my-apikey) | Free tier is sufficient |

---

## Step 1: Add the folder to Amazon Quick

Open Amazon Quick and add this repo's folder so skills are auto-discovered:

**Option A - via Settings:**
1. Open **Settings** → **Capabilities** → **Folders**
2. Click **Add Folder**
3. Select the `s1-aws-quick-skills` directory on your local machine

**Option B - via chat input:**
1. Click the **folder icon** (📁) in the chat input area
2. Click **Add folder**
3. Select the `s1-aws-quick-skills` directory

> **What this does:** Amazon Quick scans the folder tree for `SKILL.md` files. Each skill subfolder (`sentinelone-mgmt-console-api/`, `sentinelone-powerquery/`, etc.) has a `SKILL.md` with YAML frontmatter that defines the skill's name, description, and trigger phrases. All six skills become available immediately - no upload, no plugin, no per-skill configuration.

Amazon Quick also reads `CLAUDE.md` from the repo root, which activates the PrincipalSOCAnalyst persona with structured investigation protocols.

---

## Step 2: Configure MCP servers

Go to **Settings → Capabilities → MCP** and click **"+ Add MCP / Skill"** for each server.

### sentinelone-mcp

| Field | Value |
|-------|-------|
| **Name** | `sentinelone-mcp` |
| **Type** | `stdio` |
| **Command** | `npx` |
| **Args** | `-y @pmoses-s1/sentinelone-mcp` |

**Environment Variables:**

| Key | Value | Required |
|-----|-------|----------|
| `S1_CONSOLE_URL` | `https://usea1-yourorg.sentinelone.net` | ✅ |
| `S1_CONSOLE_API_TOKEN` | `eyJ...your-api-token...` | ✅ |
| `S1_HEC_INGEST_URL` | `https://ingest.us1.sentinelone.net` | For UAM ingest |
| `SDL_XDR_URL` | `https://xdr.us1.sentinelone.net` | For SDL ops |
| `SDL_LOG_WRITE_KEY` | Your Log Write key | For `hec_ingest` |
| `SDL_LOG_READ_KEY` | Your Log Read key | For log queries |
| `SDL_CONFIG_WRITE_KEY` | Your Config Write key | For `sdl_put_file` |
| `SDL_CONFIG_READ_KEY` | Your Config Read key | For config reads |

### purple-mcp

| Field | Value |
|-------|-------|
| **Name** | `purple-mcp` |
| **Type** | `stdio` |
| **Command** | `uvx` |
| **Args** | `--from git+https://github.com/Sentinel-One/purple-mcp.git purple-mcp --mode stdio` |

**Environment Variables:**

| Key | Value |
|-----|-------|
| `PURPLEMCP_CONSOLE_TOKEN` | Same API token as `S1_CONSOLE_API_TOKEN` |
| `PURPLEMCP_CONSOLE_BASE_URL` | Same URL as `S1_CONSOLE_URL` |

### virustotal (or your org's threat intel MCP)

| Field | Value |
|-------|-------|
| **Name** | `virustotal` |
| **Type** | `stdio` |
| **Command** | `npx` |
| **Args** | `-y @burtthecoder/mcp-virustotal` |

**Environment Variables:**

| Key | Value |
|-----|-------|
| `VIRUSTOTAL_API_KEY` | Your VirusTotal API key |

**Notes:**

- Both `S1_CONSOLE_API_TOKEN` and `PURPLEMCP_CONSOLE_TOKEN` are the same Management Console API token. Generate one under Settings → Users → Service Users.
- Region URLs vary. Look up your region in the [SentinelOne Endpoint URLs by Region](https://community.sentinelone.com/s/article/000004961) article.
- The VirusTotal MCP shown is one example. Replace it with your organisation's approved threat intel MCP if different.
- `npx -y` answers "yes" to the install prompt on first run, then caches. `uvx` does the same for the Python side.

After adding all three, **restart Amazon Quick** (or close and reopen the app).

Full credential reference: [credentials.md](./credentials.md)

---

## Step 3: Verify the install

Start a **new conversation** in Amazon Quick. The SentinelOne skills should now be available. Run a smoke test:

```
smoke test s1 skills
```

Amazon Quick verifies connectivity to `sentinelone-mcp`, `purple-mcp`, and the threat intel MCP, confirms each skill is loaded, and reports any missing credentials or unreachable endpoints.

You can also verify piece by piece:

```
enumerate all data sources on my SentinelOne tenant
```

You should see a list of all connected SDL data sources within seconds.

**If anything fails, check:**

1. All three MCPs show a green status indicator in Settings → Capabilities → MCP
2. The API token has the right scope (Viewer or higher for read; IR Team or higher for response actions)
3. `SDL_XDR_URL` and the SDL keys match your region
4. Node.js 18+ is on your PATH (`node --version`)
5. `uvx --version` works in a fresh terminal

---

## Upgrading

**MCP servers** (`sentinelone-mcp`, `purple-mcp`, `virustotal`): nothing to do. `npx -y` and `uvx` re-resolve to the latest published version on each Amazon Quick launch. To force a refresh:

```bash
# npx-based
npx clear-npx-cache

# uvx-based
uvx cache clean purple-mcp
```

Then restart Amazon Quick.

**Skills**: Since skills are loaded directly from the folder, just `git pull` (or update the folder contents) and the updated `SKILL.md` files take effect on the next conversation.

**CLAUDE.md**: If you customised it, your copy stays as-is. To pick up upstream improvements, diff against the latest [`CLAUDE.md`](../CLAUDE.md) in this repo.

---

## Configuration reference

**Recommended:** Credentials live in the MCP configuration (Settings → Capabilities → MCP) as environment variables on each MCP server (Step 2). No file in any workspace folder needed.

**Backwards-compatible fallback** (for direct skill usage without `sentinelone-mcp`): place a `credentials.json` in this repo folder or a parent directory. The skill scripts auto-discover it.

```bash
# macOS / Linux
cp credentials.example.json credentials.json
${EDITOR:-nano} credentials.json
```

Resolution order (highest priority wins):
1. Environment variables in the MCP configuration (Settings → Capabilities → MCP) - recommended
2. `credentials.json` in the repo folder or a parent directory
3. `~/.config/sentinelone/credentials.json` (terminal fallback)

| Credential key | Required for | How to get it |
|---|---|---|
| `S1_CONSOLE_URL` | All management console skills | Your console URL, e.g. `https://usea1-acme.sentinelone.net` |
| `S1_CONSOLE_API_TOKEN` | `sentinelone-mgmt-console-api`, `sentinelone-powerquery`, plus SDL query and config methods (not `uploadLogs`) | Settings → Users → Service Users → Create New Service User → copy the API token. The same JWT works for the SDL API from Management version Z SP5+. See [Creating service users](https://community.sentinelone.com/s/article/000005291) and [SDL API Keys](https://community.sentinelone.com/s/article/000006763) |
| `S1_HEC_INGEST_URL` | UAM alert/indicator ingest and log ingest via HEC | The SentinelOne HEC ingest host for your region, e.g. `https://ingest.us1.sentinelone.net`. See [Endpoint URLs by Region](https://community.sentinelone.com/s/article/000004961) |
| `SDL_XDR_URL` | SDL configuration operations + LRQ PowerQuery | Your SDL tenant URL, e.g. `https://xdr.us1.sentinelone.net` |
| `SDL_LOG_WRITE_KEY` | `hec_ingest` | SDL tenant → Admin → API Keys → Log Write |
| `SDL_LOG_READ_KEY` | Log queries via SDL key | SDL tenant → Admin → API Keys → Log Read |
| `SDL_CONFIG_WRITE_KEY` | `sdl_put_file` (parser/dashboard deploy) | SDL tenant → Admin → API Keys → Config Write |
| `SDL_CONFIG_READ_KEY` | Config file reads via SDL key | SDL tenant → Admin → API Keys → Config Read |

---

## Building from source

If you're developing the MCP server locally instead of using `npx`:

```bash
cd sentinelone-mcp
npm install
```

Then in Amazon Quick → Settings → Capabilities → MCP, change the `sentinelone-mcp` entry:

| Field | Value |
|-------|-------|
| **Command** | `node` |
| **Args** | `/absolute/path/to/s1-aws-quick-skills/sentinelone-mcp/index.js` |

Keep the same environment variables. Restart Amazon Quick after the change.
