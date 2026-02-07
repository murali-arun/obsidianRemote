# Agent Knowledge Base - Obsidian + Authelia SSO Setup

This document captures all learnings, common mistakes, and troubleshooting steps to prevent repeating issues.

## Table of Contents
1. [Critical Network Configuration](#critical-network-configuration)
2. [Port Configuration](#port-configuration)
3. [NPM (Nginx Proxy Manager) Setup](#npm-nginx-proxy-manager-setup)
4. [Common Mistakes & Fixes](#common-mistakes--fixes)
5. [Troubleshooting Steps](#troubleshooting-steps)
6. [How Authentication Flow Works](#how-authentication-flow-works)
7. [Deployment Checklist](#deployment-checklist)

---

## Critical Network Configuration

### ❌ WRONG - Network Isolation Issue
```yaml
services:
  obsidian:
    networks:
      - obsidian_internal  # ❌ NPM can't reach this!
  
  authelia:
    networks:
      - obsidian_internal
      - npm_default
      
networks:
  obsidian_internal:
    internal: true  # ❌ Isolated from NPM!
  npm_default:
    external: true
```

**Problem**: When Obsidian is only on `obsidian_internal` network:
- NPM cannot reach the container
- Results in **blank page** or connection timeout
- Authelia can't communicate properly

### ✅ CORRECT - All services on npm_default
```yaml
services:
  obsidian:
    networks:
      - npm_default  # ✅ NPM can reach it!
  
  authelia:
    networks:
      - npm_default  # ✅ NPM can reach it!
  
  redis:
    networks:
      - npm_default  # ✅ Authelia can reach it!
      
networks:
  npm_default:
    external: true  # Shared with NPM
```

**Why this works**:
- All services share NPM's network
- NPM can proxy to containers by name
- Authelia can talk to Redis
- Services can communicate with each other

---

## Port Configuration

### Service Ports (IMPORTANT)

| Service | Container Port | Exposed Port | NPM Forward To |
|---------|---------------|--------------|----------------|
| Obsidian | **3000** | N/A (internal) | `obsidian:3000` or `obsidian_remote:3000` |
| Authelia | **9091** | N/A (internal) | `authelia:9091` |
| Redis | 6379 | N/A (internal) | `redis:6379` |

### ❌ Common Port Mistakes
- Using port **3001** instead of **3000** for Obsidian
- Exposing ports in docker-compose (not needed with NPM)
- Wrong port in NPM forward configuration

### ✅ Correct Port Usage
- **No `ports:` section needed** in docker-compose.yml
- NPM handles all external routing
- Services communicate via container name on internal ports

---

## NPM (Nginx Proxy Manager) Setup

### Host A: Authelia Portal (auth.yourdomain.com)

**Details Tab:**
- **Domain Names**: `auth.yourdomain.com`
- **Scheme**: `http`
- **Forward Hostname/IP**: `authelia` (or `obsidian_authelia`)
- **Forward Port**: `9091`
- **Block Common Exploits**: ☑
- **Websockets Support**: ☑
- **Access List**: None

**SSL Tab:**
- **SSL Certificate**: Request New SSL Certificate
- **Force SSL**: ☑
- **HTTP/2 Support**: ☑
- **HSTS Enabled**: ☑

**Advanced Tab:**
- Leave empty (default config is fine)

---

### Host B: Obsidian with Forward Auth (obsidian.yourdomain.com)

**Details Tab:**
- **Domain Names**: `obsidian.yourdomain.com`
- **Scheme**: `http`
- **Forward Hostname/IP**: `obsidian_remote` (or `obsidian`)
- **Forward Port**: `3000` ⚠️ **NOT 3001**
- **Block Common Exploits**: ☑
- **Websockets Support**: ☑ **CRITICAL for Obsidian**
- **Access List**: None (Authelia handles auth)

**SSL Tab:**
- **SSL Certificate**: Request New SSL Certificate
- **Force SSL**: ☑
- **HTTP/2 Support**: ☑
- **HSTS Enabled**: ☑

**Advanced Tab** - Add this custom nginx config:
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

    # Redirect to Authelia if not authenticated
    error_page 401 =302 https://auth.yourdomain.com/?rd=$target_url;

    # Proxy to Obsidian
    proxy_pass http://obsidian_remote:3000;
}

location /authelia {
    internal;
    proxy_pass http://authelia:9091/api/verify;
}
```

**⚠️ CRITICAL**: Replace `auth.yourdomain.com` with your actual domain!

---

## Common Mistakes & Fixes

### 1. Blank Page Issues

**Symptoms**: White/blank page, no content loads

**Causes & Fixes**:

| Cause | How to Check | Fix |
|-------|-------------|-----|
| Wrong network | `docker inspect obsidian_remote \| grep NetworkMode` | Add to `npm_default` network |
| Wrong port | Check NPM uses port 3000 | Change to `3000` in NPM |
| Container not started | `docker ps \| grep obsidian` | `docker-compose up -d` |
| Container crashed | `docker logs obsidian_remote` | Check logs, fix issue |
| NPM using wrong name | Check Forward Hostname | Use `obsidian_remote` or `obsidian` |
| Websockets disabled | Check NPM settings | Enable Websockets Support |

### 2. Authentication Not Working

**Symptoms**: Not redirected to auth portal, or auth doesn't persist

**Causes & Fixes**:

| Cause | Fix |
|-------|-----|
| Authelia not running | `docker-compose up -d authelia` |
| Wrong domain in config | Update `authelia/configuration.yml` with correct domain |
| Redis not connected | Check `docker logs obsidian_authelia` for Redis errors |
| Wrong nginx config in NPM | Copy exact config from above |
| Session domain mismatch | Ensure `session.domain` matches your domain |

### 3. Passkey Registration Fails

**Causes**:
- Not using HTTPS (passkeys require secure context)
- Domain mismatch in Authelia config
- Browser doesn't support WebAuthn

**Fixes**:
- Ensure SSL is enabled in NPM
- Check `authelia/configuration.yml` has correct domain
- Use modern browser (Chrome, Safari, Edge, Firefox)

---

## Troubleshooting Steps

### Step 1: Check Container Status
```bash
# On VPS
docker ps -a | grep -E "obsidian|authelia|redis"
```

Expected output:
- All 3 containers should be `Up`
- If any are `Exited`, check logs

### Step 2: Check Container Logs
```bash
# Obsidian logs
docker logs obsidian_remote --tail 50

# Authelia logs
docker logs obsidian_authelia --tail 50

# Redis logs
docker logs obsidian_redis --tail 50
```

**What to look for**:
- Obsidian: Should show "GUI startup complete"
- Authelia: Should show "Authelia is listening on :9091"
- Redis: Should show "Ready to accept connections"

### Step 3: Check Network Connectivity
```bash
# Check what networks containers are on
docker inspect obsidian_remote | grep -A 10 Networks
docker inspect obsidian_authelia | grep -A 10 Networks

# Test connectivity from NPM to Obsidian
docker exec nginx-proxy-manager curl -I http://obsidian_remote:3000

# Test connectivity to Authelia
docker exec nginx-proxy-manager curl -I http://authelia:9091
```

### Step 4: Test Authelia Directly
```bash
# From VPS, test Authelia API
curl http://localhost:9091/api/health
```

Should return: `{"status":"UP"}`

### Step 5: Check Authelia Configuration
```bash
# Verify secrets are generated (not placeholder text)
cat authelia/configuration.yml | grep "CHANGE_THIS"
```

Should return nothing. If it returns lines, run `./setup-passkey.sh` again.

### Step 6: Restart Services
```bash
cd /opt/obsidianRemote
docker-compose down
docker-compose up -d

# Watch logs in real-time
docker-compose logs -f
```

---

## How Authentication Flow Works

```
1. User visits https://obsidian.yourdomain.com
   ↓
2. NPM receives request
   ↓
3. NPM sends auth_request to http://authelia:9091/api/verify
   ↓
4. Authelia checks for valid session
   ↓
   ├─→ [Session Valid] → Authelia returns 200 → NPM proxies to Obsidian
   │
   └─→ [No Session] → Authelia returns 401 → NPM redirects to https://auth.yourdomain.com
       ↓
5. User lands on Authelia login page
   ↓
6. User authenticates (password + passkey)
   ↓
7. Authelia creates session in Redis
   ↓
8. Authelia redirects back to https://obsidian.yourdomain.com
   ↓
9. NPM re-checks auth → Now valid → User accesses Obsidian
```

**Key Points**:
- Session stored in Redis (shared across services)
- Login once, access all protected services
- Passkey replaces password after first registration

---

## Deployment Checklist

### Initial Setup (One Time)

- [ ] Set GitHub Secrets:
  - [ ] `VPS_HOST`, `VPS_USERNAME`, `VPS_PORT`, `VPS_SSH_KEY`
  - [ ] `AUTH_DOMAIN`, `AUTH_USERNAME`, `AUTH_PASSWORD`, `AUTH_EMAIL`
  
- [ ] Create NPM Proxy Host for Authelia (`auth.yourdomain.com`)
  - [ ] Port: 9091
  - [ ] SSL: Enabled
  - [ ] Websockets: ON

- [ ] Create NPM Proxy Host for Obsidian (`obsidian.yourdomain.com`)
  - [ ] Port: 3000 (not 3001!)
  - [ ] SSL: Enabled
  - [ ] Websockets: ON
  - [ ] Advanced config: Added forward auth

- [ ] Push to `main` branch → Auto-deploy runs

- [ ] Visit `https://obsidian.yourdomain.com`
  - [ ] Redirected to auth portal
  - [ ] Login with username/password
  - [ ] Register passkey
  - [ ] Access Obsidian

### Adding New Services to SSO

- [ ] Add service to `docker-compose.yml` on `npm_default` network
- [ ] Create NPM Proxy Host with same forward auth config
- [ ] Update `authelia/configuration.yml` access_control rules
- [ ] Restart containers: `docker-compose up -d`

### Regular Maintenance

- [ ] Check logs periodically: `docker logs obsidian_remote`
- [ ] Monitor disk space: `/opt/obsidianRemote/config`
- [ ] Update images: `docker-compose pull && docker-compose up -d`
- [ ] Backup Authelia data: `authelia/db.sqlite3`, `authelia/users_database.yml`

---

## Quick Reference Commands

```bash
# Restart everything
cd /opt/obsidianRemote && docker-compose restart

# View logs
docker-compose logs -f

# Check container health
docker ps --filter "name=obsidian"

# Reset Authelia (WARNING: Deletes all users/sessions)
rm authelia/db.sqlite3 && ./setup-passkey.sh

# Test NPM can reach services
docker exec nginx-proxy-manager curl http://obsidian_remote:3000
docker exec nginx-proxy-manager curl http://authelia:9091/api/health

# View current networks
docker network ls
docker network inspect npm_default
```

---

## Configuration File Locations

| File | Purpose | Contains Secrets? |
|------|---------|-------------------|
| `docker-compose.yml` | Container definitions | No |
| `authelia/configuration.yml` | Authelia settings | **Yes** (JWT, session secrets) |
| `authelia/users_database.yml` | User credentials | **Yes** (password hashes) |
| `authelia/db.sqlite3` | Sessions, passkeys | **Yes** (runtime data) |
| `.env.example` | Template for local testing | No |

**Never commit**: `authelia/configuration.yml` (after setup), `authelia/users_database.yml`, `authelia/db.sqlite3`

---

## Security Best Practices

1. **SSL/TLS Required**
   - Passkeys only work over HTTPS
   - Always enable SSL in NPM

2. **Strong Passwords**
   - Initial password should be strong
   - Will be replaced by passkey anyway

3. **Regular Updates**
   - Update container images monthly
   - Check Authelia changelog for security updates

4. **Backup Authelia Database**
   - Contains user data and passkey registrations
   - Backup before major updates

5. **Monitor Failed Logins**
   - Check `authelia/notification.txt` for alerts
   - Configure email notifications (optional)

---

## Environment Variables Reference

| Variable | Used By | Purpose | Example |
|----------|---------|---------|---------|
| `AUTH_DOMAIN` | setup-passkey.sh | Your domain | `yourdomain.com` |
| `AUTH_USERNAME` | setup-passkey.sh | Admin username | `admin` |
| `AUTH_PASSWORD` | setup-passkey.sh | Admin password | `SecurePass123!` |
| `AUTH_EMAIL` | setup-passkey.sh | Admin email | `admin@yourdomain.com` |
| `PUID/PGID` | Obsidian | File ownership | `1000` |
| `TZ` | All services | Timezone | `America/Los_Angeles` |

---

## Support & Resources

- **Authelia Docs**: https://www.authelia.com/
- **WebAuthn Guide**: https://webauthn.guide/
- **LinuxServer Obsidian**: https://docs.linuxserver.io/images/docker-obsidian
- **NPM Docs**: https://nginxproxymanager.com/

---

## Version History

- **v1.0** (2026-02-07): Initial setup with network isolation fix
  - Fixed: Obsidian on npm_default network
  - Fixed: Port 3000 (not 3001)
  - Added: Complete NPM configuration guide
  - Added: Troubleshooting steps for blank page

---

*Last Updated: 2026-02-07*
*Keep this document updated when making configuration changes!*
