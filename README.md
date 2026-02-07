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

**VPS Connection:**
- `VPS_HOST` - Your VPS IP address
- `VPS_USERNAME` - SSH username
- `VPS_PORT` - SSH port (default: 22)
- `VPS_SSH_KEY` - Your SSH private key

**Authelia/Passkey Config:**
- `AUTH_DOMAIN` - Your domain (e.g., `yourdomain.com`)
- `AUTH_USERNAME` - Admin username for first login
- `AUTH_PASSWORD` - Admin password for first login
- `AUTH_EMAIL` - Admin email (optional)

## 3) Nginx Proxy Manager (NPM) config

### Automated Deployment
The setup runs automatically via GitHub Actions when you push to `main`. The workflow will:
1. Upload all files to your VPS
2. Run `setup-passkey.sh` (only on first deploy or if not already configured)
3. Start all containers

### Manual Setup (optional)
If you prefer to run setup manually on your VPS:
```bash
cd /opt/obsidianRemote
./setup-passkey.sh
```

Or use environment variables for scripting:
```bash
AUTH_DOMAIN=yourdomain.com \
AUTH_USERNAME=admin \
AUTH_PASSWORD=yourpassword \
AUTH_EMAIL=admin@yourdomain.com \
./setup-passkey.sh
```

### NPM Configuration
Create **two** Proxy Hosts in NPM:

#### A) Authelia Portal (auth.yourdomain.com)
- Domain: `auth.yourdomain.com`
- Scheme: `http`
- Forward Hostname/IP: `authelia`
- Forward Port: `9091`
- SSL: Request a Let's Encrypt cert
- Websockets Support: ON

#### B) Obsidian with Passkey Auth (obsidian.yourdomain.com)
- Domain: `obsidian.yourdomain.com`
- Scheme: `http`
- Forward Hostname/IP: `obsidian`
- Forward Port: `3000`
- SSL: Request a Let's Encrypt cert
- Websockets Support: ON
- **Advanced** tab: Add this custom nginx config:

```nginx
location / {
    # Forward auth to Authelia
    auth_request /authelia;
    auth_request_set $target_url $scheme://$http_host$request_uri;
    auth_request_set $user $upstream_http_remote_user;
    auth_request_set $groups $upstream_http_remote_groups;
    auth_request_set $name $upstream_http_remote_name;
    auth_request_set $email $upstream_http_remote_email;
    proxy_set_header Remote-User $user;
    proxy_set_header Remote-Groups $groups;
    proxy_set_header Remote-Name $name;
    proxy_set_header Remote-Email $email;

    error_page 401 =302 https://auth.yourdomain.com/?rd=$target_url;

    proxy_pass http://obsidian:3000;
}

location /authelia {
    internal;
    proxy_pass http://authelia:9091/api/verify;
}
```

### Using Passkeys
1. Visit https://obsidian.yourdomain.com
2. First login: use username/password
3. Navigate to settings and register your passkey (Face ID, Touch ID, or Windows Hello)
4. Future logins: just use your passkey!

## Security
✅ **Protected with WebAuthn passkeys** - uses your device's biometric authentication (Face ID, Touch ID, Windows Hello)
- Phishing-resistant
- No passwords to steal
- Hardware-backed security

## Notes
- Vault/config persists under `/opt/obsidianRemote/config`.
- If you want a different server path, change the compose volume.

