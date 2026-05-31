# PRD — Obsidian LiveSync

## Overview

Self-hosted vault sync for Obsidian using CouchDB on the VPS. Native Obsidian runs on every device; the server just holds the sync database. Replaces the old VNC-based linuxserver/obsidian approach.

## Goals

- Vault synced in real time across all devices (desktop, mobile)
- Self-hosted — no third-party sync services, data stays on VPS
- Lightweight — CouchDB uses ~200 MB RAM vs the old 3–6 GB VNC container
- Native Obsidian experience on every device (full plugin ecosystem, proper keyboard, mobile)

## Target User

Arun — personal knowledge base synced across devices.

## Tech Stack

| Layer | Choice |
|-------|--------|
| Sync server | CouchDB 3 |
| Client plugin | obsidian-livesync (community plugin) |
| Proxy | Nginx Proxy Manager (SSL + subdomain routing) |
| Network | `npm_default` Docker bridge |
| Auth | CouchDB built-in credentials (admin user) |
| Persistence | `/opt/obsidianRemote/couchdb/data` on VPS |
| CI/CD | GitHub Actions → SSH → `docker compose up -d` |

## Current Features

- CouchDB runs as a Docker container, accessible at `obsidian-sync.<domain>` via HTTPS
- CORS pre-configured for Obsidian desktop (`app://obsidian.md`) and mobile (`capacitor://localhost`)
- Admin credentials injected at deploy time from GitHub Secrets
- Persistent vault data at `/opt/obsidianRemote/couchdb/data`
- Automated deployment via GitHub Actions on push to `main`

## Security

- CouchDB requires credentials on every request — no anonymous access
- `.env` written to VPS with `chmod 600` during deploy; never committed to git
- All traffic over HTTPS via NPM + Let's Encrypt

## Deployment

- Deploy path: `/opt/obsidianRemote`
- Container: `obsidian_sync`
- Internal port: 5984
- NPM forward: `http://obsidian_sync:5984`

## Scope Boundaries

- Single user (Arun) only
- One vault database
- No backup automation included (relies on VPS-level backup)

## Future Roadmap

- [ ] Automated CouchDB backup (cron → rclone to cloud storage)
- [ ] End-to-end encryption via livesync plugin (passphrase-based)
- [ ] Monitoring: alert if CouchDB goes down
