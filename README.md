# Obsidian LiveSync (Self-hosted CouchDB)

Syncs your Obsidian vault across all devices via a self-hosted CouchDB instance on your VPS. Native Obsidian app on each device — no VNC, no remote desktop.

## What you get
- Real-time vault sync between desktop, mobile, and any other Obsidian install
- Vault data stays on your VPS (no third-party sync)
- ~200 MB RAM vs the old VNC approach's 3–6 GB
- CouchDB accessible at `obsidian-sync.<domain>` via HTTPS

## Requirements
- VPS with Docker + Docker Compose
- Nginx Proxy Manager on the same VPS (`npm_default` network)
- Obsidian installed on each device with the [obsidian-livesync plugin](https://github.com/vrtmrz/obsidian-livesync)

---

## 1) GitHub Secrets

Add these to your repo → Settings → Secrets → Actions:

| Secret | Value |
|--------|-------|
| `VPS_HOST` | VPS IP or hostname |
| `VPS_USERNAME` | SSH user |
| `VPS_PORT` | SSH port (usually 22) |
| `VPS_SSH_KEY` | Private SSH key |
| `COUCHDB_USER` | CouchDB admin username |
| `COUCHDB_PASSWORD` | CouchDB admin password (make it strong) |

## 2) Deploy

Push to `main`. The GitHub Action will:
1. Create `/opt/obsidianRemote/couchdb/data` and `config` dirs on VPS
2. Copy `docker-compose.yml` and `couchdb/local.ini`
3. Write `.env` with your CouchDB credentials
4. `docker compose pull && up -d`

## 3) Nginx Proxy Manager

Create a Proxy Host:
- Domain: `obsidian-sync.yourdomain.com`
- Scheme: `http`
- Forward Hostname/IP: `obsidian_sync`
- Forward Port: `5984`
- SSL: Let's Encrypt
- Websockets: ON (needed for live sync)

No forward auth needed — CouchDB requires credentials on every request.

## 4) Plugin setup (each device)

1. Install **Self-hosted LiveSync** from Obsidian community plugins
2. Open plugin settings → Setup wizard → "Use the setup wizard"
3. Enter:
   - Remote server URL: `https://obsidian-sync.yourdomain.com`
   - Username: your `COUCHDB_USER`
   - Password: your `COUCHDB_PASSWORD`
   - Database name: `obsidian` (or anything consistent across devices)
4. Let the wizard configure CORS and create the database
5. Enable sync

On subsequent devices, use the wizard's "Copy setup from another device" option (generates a passphrase you paste on the new device).

---

## Vault data location

CouchDB data lives at `/opt/obsidianRemote/couchdb/data` on the VPS. Back this up to keep your vault safe.

## CouchDB admin UI

Available at `https://obsidian-sync.yourdomain.com/_utils/` — log in with your admin credentials to inspect databases, users, and config.
