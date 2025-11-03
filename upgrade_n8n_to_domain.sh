#!/usr/bin/env bash
set -euo pipefail

# Upgrade existing IP/HTTP n8n deployment to Domain/HTTPS with Traefik + Let's Encrypt
# Assumes current install lives in /opt/n8n created by the previous installer.

APP_DIR="/opt/n8n"
LE_DIR="$APP_DIR/letsencrypt"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"
BACKUP_FILE="$APP_DIR/docker-compose.backup.$(date +%Y%m%d-%H%M%S).yml"

# --- helpers ---
confirm() {
  local prompt_text="$1"
  read -p "$prompt_text [Y/n]: " yn
  yn="${yn:-Y}"
  case "$yn" in [Yy]* ) return 0 ;; * ) return 1 ;; esac
}

open_link() {
  local url="$1"
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$url" >/dev/null 2>&1 && echo "(Opened in your default browser!)"
  elif command -v open >/dev/null 2>&1; then
    open "$url" >/dev/null 2>&1 && echo "(Opened in your default browser!)"
  else
    echo "Note: Open the above link manually in your browser."
  fi
}

die() { echo "Error: $*" >&2; exit 1; }

# --- prechecks ---
[ "$(id -u)" -ne 0 ] && die "Please run as root (sudo)."
command -v docker >/dev/null 2>&1 || die "Docker is not installed on this host."
[ -d "$APP_DIR" ] || die "Directory $APP_DIR not found. Is n8n installed there?"

echo "=== Upgrade n8n to Domain + HTTPS (Traefik + Let's Encrypt) ==="

# --- ask for domain & email ---
read -p "Enter your domain (e.g. n8n.example.com): " DOMAIN
[ -z "${DOMAIN:-}" ] && die "Domain is required."

read -p "Enter ACME email for Let's Encrypt (e.g. admin@example.com): " ACME_EMAIL
[ -z "${ACME_EMAIL:-}" ] && die "ACME email is required."

# --- find current encryption key from volume (so credentials remain valid) ---
echo "Reading current encryption key from container/volume (if available)..."
N8N_KEY=""

# Try to read from a running container
if docker compose -f "$COMPOSE_FILE" ps --status running >/dev/null 2>&1; then
  if docker compose -f "$COMPOSE_FILE" ps | grep -q 'n8n'; then
    set +e
    N8N_KEY=$(docker compose -f "$COMPOSE_FILE" exec -T n8n sh -lc 'jq -r .encryptionKey /home/node/.n8n/config 2>/dev/null' 2>/dev/null)
    [ "$N8N_KEY" = "null" ] && N8N_KEY=""
    set -e
  fi
fi

# If still empty, try to mount the volume in a temp container to read it
if [ -z "$N8N_KEY" ]; then
  # find the n8n_data volume name from compose
  VOL_NAME=$(docker volume ls --format '{{.Name}}' | grep -E '^n8n_|^n8n$|n8n_data' | head -n1 || true)
  if [ -n "$VOL_NAME" ]; then
    set +e
    N8N_KEY=$(docker run --rm -v "${VOL_NAME}":/v alpine sh -lc "apk add --no-cache jq >/dev/null 2>&1 || true; jq -r .encryptionKey /v/config 2>/dev/null")
    [ "$N8N_KEY" = "null" ] && N8N_KEY=""
    set -e
  fi
fi

if [ -z "$N8N_KEY" ]; then
  echo "Could not auto-detect encryption key. You can paste it now (leave empty to auto-generate a NEW one—old credentials will NOT decrypt):"
  read -s -p "N8N_ENCRYPTION_KEY: " N8N_KEY; echo
  if [ -z "$N8N_KEY" ]; then
    echo "Generating a NEW encryption key..."
    N8N_KEY="$(openssl rand -base64 48)"
    echo "Generated new key (length ${#N8N_KEY}). NOTE: old encrypted credentials will not be readable."
  fi
else
  echo "Found existing encryption key (length ${#N8N_KEY})."
fi

# --- detect current timezone from compose or default ---
TIMEZONE="Asia/Tehran"
if [ -f "$COMPOSE_FILE" ]; then
  tz_guess=$(grep -A20 -F 'n8n:' "$COMPOSE_FILE" | grep -E 'GENERIC_TIMEZONE=' | head -n1 | sed 's/.*GENERIC_TIMEZONE=//')
  [ -n "${tz_guess:-}" ] && TIMEZONE="$tz_guess"
fi
echo "Using timezone: $TIMEZONE"

echo
echo "Summary:"
echo "  Domain:      $DOMAIN"
echo "  ACME Email:  $ACME_EMAIL"
echo "  Timezone:    $TIMEZONE"
echo "  Key length:  ${#N8N_KEY}"
echo
confirm "Proceed with upgrade?" || { echo "Cancelled."; exit 0; }

# --- prepare directories & files ---
mkdir -p "$APP_DIR"
mkdir -p "$LE_DIR"
touch "$LE_DIR/acme.json"
chmod 600 "$LE_DIR/acme.json"
chown root:root "$LE_DIR/acme.json"

# open firewall ports if ufw present
if command -v ufw >/dev/null 2>&1; then
  ufw allow 80/tcp || true
  ufw allow 443/tcp || true
fi

# stop nginx if running
systemctl stop nginx 2>/dev/null || true
systemctl disable nginx 2>/dev/null || true

# ensure docker network is present
docker network inspect web >/dev/null 2>&1 || docker network create web >/dev/null 2>&1 || true

# backup existing compose
if [ -f "$COMPOSE_FILE" ]; then
  cp -a "$COMPOSE_FILE" "$BACKUP_FILE"
  echo "Backed up current compose to: $BACKUP_FILE"
fi

# --- write new HTTPS compose ---
cat > "$COMPOSE_FILE" <<EOF
services:
  traefik:
    image: traefik:v3.1
    command:
      - --providers.docker=true
      - --providers.docker.exposedbydefault=false
      - --providers.docker.network=web
      - --entrypoints.web.address=:80
      - --entrypoints.websecure.address=:443
      - --entrypoints.web.http.redirections.entryPoint.to=websecure
      - --entrypoints.web.http.redirections.entryPoint.scheme=https
      - --certificatesresolvers.myresolver.acme.httpchallenge=true
      - --certificatesresolvers.myresolver.acme.httpchallenge.entrypoint=web
      - --certificatesresolvers.myresolver.acme.email=${ACME_EMAIL}
      - --certificatesresolvers.myresolver.acme.storage=/letsencrypt/acme.json
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./letsencrypt:/letsencrypt
    restart: always
    networks:
      - web

  n8n:
    image: n8nio/n8n:latest
    environment:
      - N8N_HOST=${DOMAIN}
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - WEBHOOK_URL=https://${DOMAIN}/
      - N8N_EDITOR_BASE_URL=https://${DOMAIN}/
      - NODE_ENV=production
      - N8N_SECURE_COOKIE=true
      - GENERIC_TIMEZONE=${TIMEZONE}
      - N8N_ENCRYPTION_KEY=${N8N_KEY}
      - N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
    labels:
      - traefik.enable=true
      - traefik.http.routers.n8n.rule=Host(\`${DOMAIN}\`)
      - traefik.http.routers.n8n.entrypoints=websecure
      - traefik.http.routers.n8n.tls=true
      - traefik.http.routers.n8n.tls.certresolver=myresolver
      - traefik.http.services.n8n.loadbalancer.server.port=5678
      - traefik.docker.network=web
    volumes:
      - n8n_data:/home/node/.n8n
    restart: always
    networks:
      - web
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://localhost:5678 >/dev/null 2>&1 || exit 1"]
      interval: 10s
      timeout: 3s
      retries: 10

volumes:
  n8n_data:

networks:
  web:
    name: web
    driver: bridge
EOF

# --- bring up ---
cd "$APP_DIR"
docker compose pull || true
docker compose up -d

echo
echo "============================================================"
echo "✅ Upgrade completed. Services are now running with domain + HTTPS."
docker compose ps
echo
echo "Check certificate logs (for issuance/renewal):"
echo "  docker compose logs --tail=200 traefik | egrep -i 'acme|certificate|challenge|myresolver'"
echo
LINK="https://$DOMAIN"
echo "Your n8n panel:"
echo "👉  $LINK"
echo "============================================================"

open_link "$LINK"

echo
echo "If you use Cloudflare: set the DNS record for '$DOMAIN' to DNS-only (gray cloud) during the first certificate issuance,"
echo "or switch to DNS-01 later if you want to keep the orange proxy ON."
