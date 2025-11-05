#!/bin/bash

# --- Config ---
COMPOSE_FILE="/opt/n8n/docker-compose.yml"
CLOUDFLARED_SERVICE="cloudflared-quick"
N8N_SERVICE="n8n"
ANCHOR_ENV_LINE="- N8N_SECURE_COOKIE=false"
WAIT_SECONDS=90
CHECK_INTERVAL_MS=1500
SINCE_WINDOW_SEC=1800
TAIL_LINES=800
# ---------------

function fail() {
    echo "ERROR: $1" >&2
    exit 1
}

[ -f "$COMPOSE_FILE" ] || fail "File not found: $COMPOSE_FILE"

COMPOSE_DIR=$(dirname "$COMPOSE_FILE")
cd "$COMPOSE_DIR" || fail "Failed to change to directory: $COMPOSE_DIR"

# Start cloudflared service
docker-compose -f "$COMPOSE_FILE" up -d "$CLOUDFLARED_SERVICE" || fail "Failed to start $CLOUDFLARED_SERVICE"

# Extract URL from logs
function get_last_url() {
    local logs="$1"
    if [ -z "$logs" ]; then
        return 1
    fi
    
    # Clean up the logs and find the URL
    local clean_logs=$(echo "$logs" | tr '|' ' ')
    local url=$(echo "$clean_logs" | grep -o 'https://[A-Za-z0-9.-]*trycloudflare\.com' | tail -n 1)
    
    if [ -n "$url" ]; then
        echo "${url%/}/"
        return 0
    fi
    return 1
}

function try_extract_url() {
    local since_sec=$1
    local tail_lines=$2
    
    # Try docker-compose logs first
    local logs=$(docker-compose -f "$COMPOSE_FILE" logs --no-color --since "${since_sec}s" --tail "$tail_lines" "$CLOUDFLARED_SERVICE" 2>/dev/null)
    local url=$(get_last_url "$logs")
    
    if [ -n "$url" ]; then
        echo "$url"
        return 0
    fi
    
    # Fallback to docker logs
    local container_id=$(docker-compose -f "$COMPOSE_FILE" ps -q "$CLOUDFLARED_SERVICE" 2>/dev/null | head -n 1)
    if [ -n "$container_id" ]; then
        local raw_logs=$(docker logs --since "${since_sec}s" --tail "$tail_lines" "$container_id" 2>/dev/null)
        url=$(get_last_url "$raw_logs")
        if [ -n "$url" ]; then
            echo "$url"
            return 0
        fi
    fi
    
    return 1
}

# Try to get URL from recent logs
echo "Looking for Cloudflare URL in recent logs..."
NEW_URL=$(try_extract_url "$SINCE_WINDOW_SEC" "$TAIL_LINES")

# If no URL found, restart cloudflared and wait for new URL
if [ -z "$NEW_URL" ]; then
    echo "No recent URL found, restarting cloudflared..."
    docker-compose -f "$COMPOSE_FILE" restart "$CLOUDFLARED_SERVICE" || fail "Failed to restart $CLOUDFLARED_SERVICE"
    
    echo "Waiting for cloudflared to emit a fresh URL (max ${WAIT_SECONDS}s)..."
    ELAPSED=0
    while [ $ELAPSED -lt $((WAIT_SECONDS * 1000)) ]; do
        sleep "$(echo "scale=3; $CHECK_INTERVAL_MS/1000" | bc)"
        ELAPSED=$((ELAPSED + CHECK_INTERVAL_MS))
        
        NEW_URL=$(try_extract_url 5 100)  # Check last 5 seconds, 100 lines
        if [ -n "$NEW_URL" ]; then
            break
        fi
    done

[ -n "$NEW_URL" ] || fail "Could not find a fresh trycloudflare URL in logs."
echo "URL found: $NEW_URL"

# Update docker-compose.yml with the new URL
if grep -q "WEBHOOK_URL=" "$COMPOSE_FILE"; then
    # Update existing WEBHOOK_URL
    sed -i "s|WEBHOOK_URL=.*|WEBHOOK_URL=$NEW_URL|" "$COMPOSE_FILE"
else
    # Add WEBHOOK_URL after the anchor line
    if grep -qF "$ANCHOR_ENV_LINE" "$COMPOSE_FILE"; then
        sed -i "/$ANCHOR_ENV_LINE/a\    - WEBHOOK_URL=$NEW_URL" "$COMPOSE_FILE"
    else
        # If anchor not found, try to add it to the n8n service environment
        if grep -q "  $N8N_SERVICE:" "$COMPOSE_FILE"; then
            if grep -A1 "  $N8N_SERVICE:" "$COMPOSE_FILE" | grep -q "environment:"; then
                # Environment section exists, add to it
                sed -i "/  $N8N_SERVICE:/,/^  [a-zA-Z]/ {/environment:/a\    - WEBHOOK_URL=$NEW_URL
                }" "$COMPOSE_FILE"
            else
                # Add environment section
                sed -i "/  $N8N_SERVICE:/a\    environment:\n      - WEBHOOK_URL=$NEW_URL" "$COMPOSE_FILE"
            fi
        else
            fail "Could not locate n8n service in docker-compose.yml"
        fi
    fi
fi

echo "Updated $COMPOSE_FILE with new webhook URL"

# Restart n8n service
echo "Restarting $N8N_SERVICE..."
docker-compose -f "$COMPOSE_FILE" up -d "$N8N_SERVICE" || fail "Failed to restart $N8N_SERVICE"

echo "Done."
