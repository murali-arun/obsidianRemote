# Obsidian Remote (Docker + Nginx Proxy Manager)

This repo deploys **Obsidian in your browser** using the LinuxServer.io container image (`lscr.io/linuxserver/obsidian`).

## What you get
- Obsidian running as a Docker container on your VPS
- Access via a subdomain through **Nginx Proxy Manager (NPM)**
- Persistent vault/config storage at: `/opt/obsidianRemote/config`

## Requirements
- A VPS with Docker + Docker Compose installed
- Nginx Proxy Manager already running on the same VPS
- A Docker network shared with NPM (commonly: `npm_default`)

## 1) VPS setup (one-time)
Create the external network if it doesn't exist:

```bash
docker network ls | grep npm_default || docker network create npm_default
```

## 2) Deploy
Push to `main`. The included GitHub Action:
- Copies `docker-compose.yml` to `/opt/obsidianRemote`
- Runs `docker compose pull && docker compose up -d`

### GitHub Secrets needed
Set these in your GitHub repo settings → **Secrets and variables** → **Actions**:
- `VPS_HOST`
- `VPS_USERNAME`
- `VPS_PORT`
- `VPS_SSH_KEY`

## 3) Nginx Proxy Manager (NPM) config
Create a Proxy Host:
- Domain: `obsidian.yourdomain.com`
- Scheme: `http`
- Forward Hostname/IP: `obsidian_remote`
- Forward Port: `3001`
- SSL: Request a Let's Encrypt cert for your domain
- Websockets Support: ON

## Security warning (important)
Do **not** expose this app directly to the public internet without strong access control.
Add at least one of:
- Cloudflare Access / Zero Trust
- Authelia / OAuth / SSO
- NPM Basic Auth (minimum baseline)

## Notes
- Vault/config persists under `/opt/obsidianRemote/config`.
- If you want a different server path, change the compose volume.

