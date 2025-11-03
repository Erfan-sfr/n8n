#!/usr/bin/env bash
set -euo pipefail

# Interactive n8n + Traefik installer
# Saves everything under /opt/n8n and creates docker-compose.yml, letsencrypt folder, volumes.
# Usage: sudo bash setup_n8n_interactive.sh

# --- utility funcs ---
prompt() {
  local varname="$1"; shift
  local prompt_text="$1"; shift
  local default="${1-}"
  local secret="${2-false}"

  if [ "$secret" = "true" ]; then
    while true; do
      read -s -p "$prompt_text [$default]: " val
      echo
      val="${val:-$default}"
      if [ -n "$val" ]; then
        eval "$varname=\"\$val\""
        break
      fi
      echo "مقدار خالی مجاز نیست."
    done
  else
    read -p "$prompt_text [$default]: " val
    val="${val:-$default}"
    eval "$varname=\"\$val\""
  fi
}

confirm() {
  # returns 0 if yes
  read -p "$1 [y/N]: " yn
  case "$yn" in
    [Yy]|[Yy][Ee][Ss]) return 0 ;;
    *) return 1 ;;
  esac
}

# --- welcome and checks ---
echo "=== n8n + Traefik interactive installer ==="
if [ "$(id -u)" -ne 0 ]; then
  echo "این اسکریپت باید با دسترسی root اجرا شود. لطفاً با sudo اجرا کن."
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker نصب نیست. این اسکریپت سعی می‌کند Docker را نصب کند (فقط برای Debian/Ubuntu)."
fi

# --- ask user ---
DEFAULT_DOMAIN="n8n.soulslegacy.top"
prompt DOMAIN "دامنه (Domain) برای n8n را وارد کن" "$DEFAULT_DOMAIN"

DEFAULT_EMAIL="youremail@example.com"
prompt ACME_EMAIL "ایمیل برای Let's Encrypt (برای هشدارها و بازیابی) را وارد کن" "$DEFAULT_EMAIL"

echo
echo "کلید رمزنگاری (N8N_ENCRYPTION_KEY) را می‌توانی خودت وارد کنی یا خالی بذاری تا اسکریپت یکی تولید کند."
prompt N8N_ENCRYPTION_KEY "کلید رمزنگاری (در صورت خالی، تولید می‌شود)" "" true
if [ -z "${N8N_ENCRYPTION_KEY:-}" ]; then
  echo "در حال تولید یک کلید امن..."
  N8N_ENCRYPTION_KEY="$(openssl rand -base64 48)"
  echo "تولید شد: (طول = ${#N8N_ENCRYPTION_KEY})"
fi

DEFAULT_TZ="Asia/Tehran"
prompt TIMEZONE "تایم‌زون را وارد کن" "$DEFAULT_TZ"

# base paths
APP_DIR="/opt/n8n"
LE_DIR="$APP_DIR/letsencrypt"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"

echo
echo "خلاصه تنظیمات:"
echo "  Domain: $DOMAIN"
echo "  ACME Email: $ACME_EMAIL"
echo "  Timezone: $TIMEZONE"
echo "  Encryption key length: ${#N8N_ENCRYPTION_KEY}"
echo
if ! confirm "آیا مایلید ادامه دهیم و فایل‌ها ساخته شوند؟"; then
  echo "لغو شد."
  exit 0
fi

# --- install prerequisites (Debian/Ubuntu) ---
if ! command -v docker >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y ca-certificates curl gnupg openssl
  install -m 0755 -d /etc/apt/keyrings
  if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
  fi
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
fi

# --- prepare directories and permissions ---
mkdir -p "$APP_DIR"
mkdir -p "$LE_DIR"
# acme.json bind-mount file
touch "$LE_DIR/acme.json"
chmod 600 "$LE_DIR/acme.json"
chown root:root "$LE_DIR/acme.json"

# open firewall ports if ufw exists
if command -v ufw >/dev/null 2>&1; then
  ufw allow 80/tcp || true
  ufw allow 443/tcp || true
fi

# stop nginx if present to free ports
systemctl stop nginx 2>/dev/null || true
systemctl disable nginx 2>/dev/null || true

# --- write docker-compose.yml ---
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
      # Redirect HTTP -> HTTPS
      - --entrypoints.web.http.redirections.entryPoint.to=websecure
      - --entrypoints.web.http.redirections.entryPoint.scheme=https
      # ACME (HTTP-01)
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

# ensure compose file ownership
chown root:root "$COMPOSE_FILE"
chmod 644 "$COMPOSE_FILE"

# --- bring up services ---
cd "$APP_DIR"
docker compose pull || true
docker compose up -d

echo
echo "==> تمام شد. وضعیت کانتینرها:"
docker compose ps

echo
echo "برای بررسی وضعیت صدور گواهی (ACME) این دستور را اجرا کن:"
echo "  docker compose logs --tail=200 traefik | egrep -i 'acme|certificate|challenge|myresolver'"
echo
echo "سپس در مرورگر به https://$DOMAIN برو."
echo
echo "نکته‌های مهم:"
echo " - اگر از Cloudflare استفاده می‌کنی و رکورد 'n8n' پروکسی (orange cloud) دارد، آن را موقتاً روی DNS only بگذار."
echo " - کلید رمزنگاری را جایی امن نگه دار؛ اگر آن را گم کنی، دسترسی به credential های قبلی سخت می‌شود."
echo
echo "اگر خواستی نسخه‌ای برای DNS-01 (Cloudflare) بسازم تا پروکسی روشن بمونه بگو."
