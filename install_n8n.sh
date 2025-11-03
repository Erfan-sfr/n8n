#!/usr/bin/env bash
set -euo pipefail

############################################
# تنظیمات را اینجا پر کن
DOMAIN="n8n.soulslegacy.top"                 # دامنه n8n
ACME_EMAIL="erfan.saffari51182@gmail.com"    # ایمیل برای Let's Encrypt
N8N_ENCRYPTION_KEY="CHANGE_ME_TO_A_LONG_RANDOM_STRING"  # کلید رمزنگاری ثابت
TIMEZONE="Asia/Tehran"                        # تایم‌زون
############################################

# مسیر کاری
APP_DIR="/opt/n8n"
LE_DIR="$APP_DIR/letsencrypt"

echo "==> 1) نصب پیش‌نیازها و Docker"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y ca-certificates curl gnupg jq
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

echo "==> 2) آماده‌سازی دایرکتوری‌ها و امنیت ACME"
mkdir -p "$APP_DIR" "$LE_DIR"
touch "$LE_DIR/acme.json"
chmod 600 "$LE_DIR/acme.json"
chown root:root "$LE_DIR/acme.json"

echo "==> 3) باز کردن پورت‌ها (اگر ufw فعاله)"
if command -v ufw >/dev/null 2>&1; then
  ufw allow 80/tcp || true
  ufw allow 443/tcp || true
fi

echo "==> 4) توقف nginx (اگر نصبه تا پورت‌ها آزاد شن)"
systemctl stop nginx 2>/dev/null || true
systemctl disable nginx 2>/dev/null || true

echo "==> 5) ساخت docker-compose.yml"
cat > "$APP_DIR/docker-compose.yml" <<'YAML'
services:
  traefik:
    image: traefik:v3.1
    command:
      - --providers.docker=true
      - --providers.docker.exposedbydefault=false
      # ورود/خروج
      - --entrypoints.web.address=:80
      - --entrypoints.websecure.address=:443
      # ریدایرکت اجباری HTTP→HTTPS
      - --entrypoints.web.http.redirections.entryPoint.to=websecure
      - --entrypoints.web.http.redirections.entryPoint.scheme=https
      # ACME (HTTP-01)
      - --certificatesresolvers.myresolver.acme.httpchallenge=true
      - --certificatesresolvers.myresolver.acme.httpchallenge.entrypoint=web
      - --certificatesresolvers.myresolver.acme.email=${ACME_EMAIL}
      - --certificatesresolvers.myresolver.acme.storage=/letsencrypt/acme.json
      # داشبورد (روی :8080 نیست؛ غیرفعاله مگر پورت بدی—برای امنیت همین خوبه)
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./letsencrypt:/letsencrypt
    restart: always

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
      - traefik.http.routers.n8n.rule=Host(`${DOMAIN}`)
      - traefik.http.routers.n8n.entrypoints=websecure
      - traefik.http.routers.n8n.tls=true
      - traefik.http.routers.n8n.tls.certresolver=myresolver
      - traefik.http.services.n8n.loadbalancer.server.port=5678
    volumes:
      - n8n_data:/home/node/.n8n
    restart: always
    depends_on:
      - traefik

volumes:
  n8n_data:
YAML

echo "==> 6) جایگذاری متغیرها داخل compose (envsubst ساده)"
# جایگذاری امن با sed
sed -i "s|\${ACME_EMAIL}|$ACME_EMAIL|g" "$APP_DIR/docker-compose.yml"
sed -i "s|\${DOMAIN}|$DOMAIN|g" "$APP_DIR/docker-compose.yml"
sed -i "s|\${TIMEZONE}|$TIMEZONE|g" "$APP_DIR/docker-compose.yml"
# برای کلید، کاراکترهای خاص رو اکسکیپ کن
KEY_ESCAPED=$(printf '%s\n' "$N8N_ENCRYPTION_KEY" | sed -e 's/[\/&]/\\&/g')
sed -i "s|\${N8N_ENCRYPTION_KEY}|$KEY_ESCAPED|g" "$APP_DIR/docker-compose.yml"

echo "==> 7) بالا آوردن سرویس‌ها"
cd "$APP_DIR"
docker compose pull
docker compose up -d

echo "==> 8) چک وضعیت"
docker compose ps
echo "==> چند ثانیه صبر کن، بعد این رو برای گواهی چک کن:"
echo "    docker compose logs --tail=200 traefik | egrep -i 'acme|certificate|challenge|myresolver'"
echo "==> وقتی OK شد، برو به: https://$DOMAIN"
