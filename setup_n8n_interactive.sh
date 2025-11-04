@@ -1,12 +1,48 @@
#!/usr/bin/env bash
set -euo pipefail

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
@@ -66,17 +102,33 @@ open_link() {
}

# ---------- start ----------
echo "=== n8n + Traefik interactive installer ==="
[ "$(id -u)" -ne 0 ] && { echo "Please run as root (sudo)."; exit 1; }


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
@@ -113,6 +165,7 @@ COMPOSE_FILE="$APP_DIR/docker-compose.yml"
# ---------- install Docker if missing ----------
if ! command -v docker >/dev/null 2>&1; then
  echo "Installing Docker..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
@@ -268,11 +321,14 @@ fi
# ---------- launch ----------
cd "$APP_DIR"
docker compose pull || true
docker compose up -d
echo
echo "============================================================"
echo "✅ Installation completed successfully!"
docker compose ps
echo