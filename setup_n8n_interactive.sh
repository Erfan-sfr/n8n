#!/usr/bin/env bash
set -euo pipefail

# Interactive n8n + Traefik installer (English prompts)
# Works on Debian/Ubuntu.  Run with:  sudo bash setup_n8n_interactive.sh
# Interactive n8n + Traefik installer
# - Detects public IP and uses it if domain is left empty (HTTP-only mode)
# - If domain is provided -> HTTPS with Let's Encrypt (Traefik)
# - English prompts, default-YES confirmation, auto-generate encryption key, opens link


update_progress() {
    local percent=$1
    local message=$2
    local filled=$((percent * 50 / 100))
    local empty=$((50 - filled))
    
    # Move cursor up 5 lines to update progress
    echo -ne "\033[7A"
    
    # Update progress bar
    printf "║  █  [%s%s]  %3d%% %-30s █  ║\n" \
        "$(printf '█%.0s' $(seq 1 $filled))" \
        "$(printf '░%.0s' $(seq 1 $empty))" \
        "$percent" "$message"
    
    # Move cursor back down
    echo -ne "\033[6B"
}

# ---------- helpers ----------
detect_public_ip() {
  local ip=""
  ip="$(curl -fsS https://api.ipify.org || true)"

prompt() {
  local varname="$1"; shift
  local question="$1"; shift
  local default="${1-}"
  local secret="${2-false}"
  local opts="${2-}"   # "secret", "allow-empty"

  local is_secret=false
  local allow_empty=false
  [[ "$opts" == *secret* ]] && is_secret=true
  [[ "$opts" == *allow-empty* ]] && allow_empty=true

  if [ "$secret" = "true" ]; then
    read -s -p "$question [$default]: " val
    echo
    val="${val:-$default}"   # اجازه به خالی
    eval "$varname=\"\$val\""
  local val=""
  if $is_secret; then
    read -s -p "$question [${default}]: " val; echo
  else
    read -p "$question [$default]: " val
    val="${val:-$default}"
    eval "$varname=\"\$val\""
    read -p "$question [${default}]: " val
  fi
  val="${val:-$default}"

  if ! $allow_empty; then
    while [ -z "$val" ]; do
      $is_secret && { read -s -p "$question [${default}]: " val; echo; } || read -p "$question [${default}]: " val
      val="${val:-$default}"
    done
  fi

  eval "$varname=\"\$val\""
}

confirm() {
@@ -32,27 +54,54 @@ confirm() {
  esac
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

# ---------- start ----------
echo "=== n8n + Traefik interactive installer ==="
[ "$(id -u)" -ne 0 ] && { echo "Please run as root (sudo)."; exit 1; }

<<<<<<< HEAD

=======
# --- Ask user for configuration ---
prompt DOMAIN        "Enter your domain for n8n"       "n8n.example.com"
prompt ACME_EMAIL    "Enter your email for Let's Encrypt" "admin@example.com"
>>>>>>> ea6e319e156370cb1ddecf64e797f529e2d9b97a
PUBIP="$(detect_public_ip)"
[ -z "$PUBIP" ] && PUBIP="YOUR_SERVER_IP"

echo
echo "Detected public IP: $PUBIP"
prompt DOMAIN "Enter domain for n8n (leave empty to use IP and HTTP)" "" "allow-empty"


if [ -n "$DOMAIN" ]; then
  update_progress 25 "Configuring HTTPS for $DOMAIN..."
  DEFAULT_EMAIL="admin@example.com"
  prompt ACME_EMAIL "Enter email for Let's Encrypt (used for renewal notices)" "$DEFAULT_EMAIL"
else
<<<<<<< HEAD
=======
  ACME_EMAIL=""  # not needed in IP/HTTP mode
fi

echo
echo "You can enter your own encryption key or leave empty to auto-generate."
prompt N8N_ENCRYPTION_KEY "Enter n8n encryption key" "" true
[ -z "${N8N_ENCRYPTION_KEY:-}" ] && {
prompt N8N_ENCRYPTION_KEY "Enter n8n encryption key" "" "secret allow-empty"
if [ -z "${N8N_ENCRYPTION_KEY:-}" ]; then
  echo "Generating a secure random encryption key..."
  N8N_ENCRYPTION_KEY="$(openssl rand -base64 48)"
  echo "Generated key (length ${#N8N_ENCRYPTION_KEY})."
}
fi

prompt TIMEZONE "Enter timezone" "Asia/Tehran"

echo
echo "Summary:"
echo "  Domain: $DOMAIN"
echo "  ACME Email: $ACME_EMAIL"
if [ -n "$DOMAIN" ]; then
  echo "  Domain: $DOMAIN (HTTPS via Let's Encrypt)"
  echo "  ACME Email: $ACME_EMAIL"
else
  echo "  Domain: (none) -> will use IP: $PUBIP (HTTP only)"
fi
echo "  Timezone: $TIMEZONE"
echo "  Encryption key length: ${#N8N_ENCRYPTION_KEY}"
echo
@@ -62,7 +111,7 @@ APP_DIR="/opt/n8n"
LE_DIR="$APP_DIR/letsencrypt"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"

# --- Install Docker if missing ---
>>>>>>> ea6e319e156370cb1ddecf64e797f529e2d9b97a
# ---------- install Docker if missing ----------
if ! command -v docker >/dev/null 2>&1; then
  echo "Installing Docker..."
  export DEBIAN_FRONTEND=noninteractive
<<<<<<< HEAD
  apt-get update -y
=======
@@ -80,26 +129,29 @@ if ! command -v docker >/dev/null 2>&1; then
  systemctl enable --now docker
fi

# --- Prepare folders ---
mkdir -p "$APP_DIR" "$LE_DIR"
touch "$LE_DIR/acme.json"
chmod 600 "$LE_DIR/acme.json"
chown root:root "$LE_DIR/acme.json"
# ---------- prepare folders & firewall ----------
mkdir -p "$APP_DIR"
# Only needed in domain/HTTPS mode
if [ -n "$DOMAIN" ]; then
  mkdir -p "$LE_DIR"
  touch "$LE_DIR/acme.json"
  chmod 600 "$LE_DIR/acme.json"
  chown root:root "$LE_DIR/acme.json"
fi

# open firewall ports if ufw present
if command -v ufw >/dev/null 2>&1; then
  ufw allow 80/tcp || true
  ufw allow 443/tcp || true
  # 443 only if using domain/HTTPS
  [ -n "$DOMAIN" ] && ufw allow 443/tcp || true
fi

# stop nginx if running
systemctl stop nginx 2>/dev/null || true
systemctl disable nginx 2>/dev/null || true

# --- Create docker-compose.yml ---
cat > "$COMPOSE_FILE" <<EOF
version: "3.9"

# ---------- write docker-compose ----------
if [ -n "$DOMAIN" ]; then
  # HTTPS mode (domain provided)
  cat > "$COMPOSE_FILE" <<EOF
services:
  traefik:
    image: traefik:v3.1
@@ -160,30 +212,87 @@ networks:
    name: web
    driver: bridge
EOF
else
  # HTTP-only mode (no domain; use IP)
  cat > "$COMPOSE_FILE" <<EOF
services:
  traefik:
    image: traefik:v3.1
    command:
      - --providers.docker=true
      - --providers.docker.exposedbydefault=false
      - --providers.docker.network=web
      - --entrypoints.web.address=:80
    ports:
      - "80:80"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    restart: always
    networks:
      - web

  n8n:
    image: n8nio/n8n:latest
    environment:
      - N8N_HOST=${PUBIP}
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - WEBHOOK_URL=http://${PUBIP}/
      - N8N_EDITOR_BASE_URL=http://${PUBIP}/
      - NODE_ENV=production
      - N8N_SECURE_COOKIE=false
      - GENERIC_TIMEZONE=${TIMEZONE}
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
      - N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
    labels:
      - traefik.enable=true
      - traefik.http.routers.n8n.rule=Host(\`${PUBIP}\`) || HostRegexp(\`{any:.+}\`)
      - traefik.http.routers.n8n.entrypoints=web
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
fi

>>>>>>> ea6e319e156370cb1ddecf64e797f529e2d9b97a
# ---------- launch ----------
cd "$APP_DIR"
docker compose pull || true
docker compose up -d
echo
echo "============================================================"
echo "✅ Installation completed successfully!"
echo
echo "Your n8n panel is available at:"
LINK="https://$DOMAIN"
echo "👉  $LINK"
docker compose ps
<<<<<<< HEAD
echo
=======
echo

# Try to open automatically if possible
if command -v xdg-open >/dev/null 2>&1; then
  xdg-open "$LINK" >/dev/null 2>&1 && echo "(Opened in your default browser!)"
elif command -v open >/dev/null 2>&1; then
  open "$LINK" >/dev/null 2>&1 && echo "(Opened in your default browser!)"
if [ -n "$DOMAIN" ]; then
  LINK="https://${DOMAIN}"
  echo "Your n8n panel is available at:"
  echo "👉  $LINK"
  echo
  echo "Check certificate logs (if needed):"
  echo "  docker compose logs --tail=200 traefik | egrep -i 'acme|certificate|challenge|myresolver'"
else
  echo "Note: Open the above link manually in your browser."
  LINK="http://${PUBIP}"
  echo "No domain provided. Running in HTTP-only mode."
  echo "Your n8n panel is available at:"
  echo "👉  $LINK"
  echo
  echo "Tip: Add a domain later for HTTPS, then re-run the installer or adjust docker-compose.yml accordingly."
fi

echo
echo "To check SSL certificate logs, run:"
echo "  docker compose logs --tail=200 traefik | egrep -i 'acme|certificate|challenge|myresolver'"
echo "============================================================"

# Try to open automatically
open_link "$LINK"
>>>>>>> ea6e319e156370cb1ddecf64e797f529e2d9b97a
