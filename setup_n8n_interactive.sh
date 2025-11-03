#!/usr/bin/env bash
set -euo pipefail

# Interactive n8n + Traefik installer (English prompts)
# Works on Debian/Ubuntu.  Run with:  sudo bash setup_n8n_interactive.sh

prompt() {
  local varname="$1"; shift
  local question="$1"; shift
  local default="${1-}"
  local secret="${2-false}"

   if [ "$secret" = "true" ]; then
    read -s -p "$question [$default]: " val
    echo
    val="${val:-$default}"   # اجازه به خالی
    eval "$varname=\"\$val\""
  else
    read -p "$question [$default]: " val
    val="${val:-$default}"
    eval "$varname=\"\$val\""
  fi
}

confirm() {
  read -p "$1 [y/N]: " yn
  case "$yn" in [Yy]* ) return 0 ;; * ) return 1 ;; esac
}

echo "=== n8n + Traefik interactive installer ==="
[ "$(id -u)" -ne 0 ] && { echo "Please run as root (sudo)."; exit 1; }

# --- Ask user for configuration ---
prompt DOMAIN        "Enter your domain for n8n"       "n8n.example.com"
prompt ACME_EMAIL    "Enter your email for Let's Encrypt" "admin@example.com"
echo
echo "You can enter your own encryption key or leave empty to auto-generate."
prompt N8N_ENCRYPTION_KEY "Enter n8n encryption key" "" true
[ -z "${N8N_ENCRYPTION_KEY:-}" ] && {
  echo "Generating a secure random encryption key..."
  N8N_ENCRYPTION_KEY="$(openssl rand -base64 48)"
  echo "Generated key (length ${#N8N_ENCRYPTION_KEY})."
}
prompt TIMEZONE "Enter timezone" "Asia/Tehran"

echo
echo "Summary:"
echo "  Domain: $DOMAIN"
echo "  ACME Email: $ACME_EMAIL"
echo "  Timezone: $TIMEZONE"
echo "  Encryption key length: ${#N8N_ENCRYPTION_KEY}"
echo
confirm "Proceed with installation?" || { echo "Cancelled."; exit 0; }

APP_DIR="/opt/n8n"
LE_DIR="$APP_DIR/letsencrypt"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"

# --- Install Docker if missing ---
if ! command -v docker >/dev/null 2>&1; then
  echo "Installing Docker..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y ca-certificates curl gnupg openssl
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
fi

# --- Prepare folders ---
mkdir -p "$APP_DIR" "$LE_DIR"
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

# --- Create docker-compose.yml ---
cat > "$COMPOSE_FILE" <<EOF
version: "3.9"

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
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
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

volumes:
  n8n_data:

networks:
  web:
    name: web
    driver: bridge
EOF

cd "$APP_DIR"
docker compose pull || true
docker compose up -d

echo
echo "Installation complete."
docker compose ps
echo
echo "Check certificate logs:"
echo "  docker compose logs --tail=200 traefik | egrep -i 'acme|certificate|challenge|myresolver'"
echo
echo "Then open:  https://$DOMAIN"
echo "If using Cloudflare, make sure the DNS record for '$DOMAIN' is DNS-only (gray cloud) during certificate issuance."
echo
echo "Keep this encryption key safe.  Losing it means you can't decrypt stored credentials."
