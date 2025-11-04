#!/bin/bash

# Configuration
N8N_DIR="/opt/n8n"
DOCKER_COMPOSE_FILE="$N8N_DIR/docker-compose.yml"
ENV_FILE="$N8N_DIR/.env"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check if a command exists
command_exists() {
    command -v "$@" >/dev/null 2>&1
}

# Function to print section header
print_section() {
    echo -e "\n${YELLOW}==> $1${NC}"
}

# Function to print success message
print_success() {
    echo -e "${GREEN}[✓] $1${NC}"
}

# Function to print info message
print_info() {
    echo -e "${BLUE}[i] $1${NC}"
}

# Function to print error message and exit
print_error() {
    echo -e "${RED}[✗] $1${NC}" >&2
}

# Function to check if n8n is installed
is_installed() {
    [ -d "$N8N_DIR" ] && [ -f "$DOCKER_COMPOSE_FILE" ]
}

# Function to install required packages
install_required_packages() {
    print_section "Updating package lists"
    apt-get update || return 1

    print_section "Installing required packages"
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        software-properties-common \
        wget \
        jq || return 1
}

# Function to install Docker
install_docker() {
    if ! command_exists docker; then
        print_section "Installing Docker"
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        rm get-docker.sh
        
        # Add current user to docker group
        usermod -aG docker $SUDO_USER
        
        # Start and enable Docker
        systemctl start docker
        systemctl enable docker
        
        print_success "Docker installed successfully"
    else
        print_success "Docker is already installed"
    fi
}

# Function to install Docker Compose
install_docker_compose() {
    if ! command_exists docker-compose; then
        print_section "Installing Docker Compose"
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        print_success "Docker Compose installed successfully"
    else
        print_success "Docker Compose is already installed"
    fi
}

# Function to create n8n directory structure
create_n8n_directory() {
    print_section "Creating n8n directory structure"
    mkdir -p "$N8N_DIR"
    cd "$N8N_DIR" || return 1
    
    # Create docker-compose.yml
    cat > "$DOCKER_COMPOSE_FILE" << 'EOF'
version: "3"
services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=secretpassword
      - N8N_HOST=mydomain.com
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - N8N_EMAIL_MODE=true
      - N8N_SMTP_HOST=smtp.yourdomain.com
      - N8N_SMTP_PORT=587
      - N8N_SMTP_USER=user@yourdomain.com
      - N8N_SMTP_PASSWORD=yourpassword
      - N8N_SMTP_SENDER=user@yourdomain.com
      - N8N_SECURE_COOKIE=false
    ports:
      - "5678:5678"
    volumes:
      - ~/.n8n:/root/.n8n
    restart: always

  cloudflared-quick:
    image: cloudflare/cloudflared:latest
    command: tunnel --no-autoupdate --url http://n8n:5678
    depends_on:
      - n8n
    restart: unless-stopped
EOF

    # Create .env file
    cat > "$ENV_FILE" << 'EOF'
# n8n Configuration
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=ChangeThisPassword123!
N8N_HOST=yourdomain.com
N8N_PORT=5678
N8N_PROTOCOL=http

# SMTP Configuration
N8N_EMAIL_MODE=true
N8N_SMTP_HOST=smtp.yourdomain.com
N8N_SMTP_PORT=587
N8N_SMTP_USER=user@yourdomain.com
N8N_SMTP_PASSWORD=your_smtp_password
N8N_SMTP_SENDER=noreply@yourdomain.com
N8N_SECURE_COOKIE=false
EOF
}

# Function to start n8n
start_n8n() {
    if ! is_installed; then
        print_error "n8n is not installed. Please install it first."
        return 1
    fi
    
    cd "$N8N_DIR" || return 1
    
    print_section "Starting n8n and Cloudflare tunnel"
    docker-compose up -d
    
    if [ $? -eq 0 ]; then
        print_success "n8n started successfully"
        print_info "Access n8n at: http://localhost:5678"
        print_info "Cloudflare tunnel is running"
    else
        print_error "Failed to start n8n"
        return 1
    fi
}

# Function to stop n8n
stop_n8n() {
    if ! is_installed; then
        print_error "n8n is not installed."
        return 1
    fi
    
    cd "$N8N_DIR" || return 1
    
    print_section "Stopping n8n and Cloudflare tunnel"
    docker-compose down
    
    if [ $? -eq 0 ]; then
        print_success "n8n stopped successfully"
    else
        print_error "Failed to stop n8n"
        return 1
    fi
}

# Function to uninstall n8n
uninstall_n8n() {
    if ! is_installed; then
        print_error "n8n is not installed."
        return 1
    fi
    
    print_section "Uninstalling n8n"
    
    # Stop and remove containers
    cd "$N8N_DIR" && docker-compose down
    
    # Remove n8n directory
    rm -rf "$N8N_DIR"
    
    # Remove Docker volumes (if any)
    docker volume rm -f n8n_data 2>/dev/null || true
    
    print_success "n8n has been uninstalled"
    print_info "Note: Docker and Docker Compose are still installed. Remove them manually if needed."
}

# Function to show n8n status
show_status() {
    if ! is_installed; then
        print_error "n8n is not installed."
        return 1
    fi
    
    cd "$N8N_DIR" || return 1
    
    print_section "n8n Status"
    echo "Installation directory: $N8N_DIR"
    echo ""
    
    # Show container status
    docker-compose ps
    
    # Show n8n logs
    echo -e "\n${YELLOW}=== n8n Logs (last 10 lines) ===${NC}"
    docker-compose logs --tail=10 n8n 2>/dev/null || echo "No logs available"
    
    # Show Cloudflare tunnel logs
    echo -e "\n${YELLOW}=== Cloudflare Tunnel Logs (last 10 lines) ===${NC}"
    docker-compose logs --tail=10 cloudflared-quick 2>/dev/null || echo "No logs available"
}

# Function to show menu
show_menu() {
    clear
    echo -e "${BLUE}=== n8n Management Script ===${NC}"
    echo -e "${GREEN}1. Install n8n with Cloudflare Tunnel"
    echo "2. Start n8n"
    echo "3. Stop n8n"
    echo "4. Restart n8n"
    echo "5. Show status"
    echo -e "${RED}6. Uninstall n8n${NC}"
    echo "0. Exit"
    echo -e "${BLUE}============================${NC}"
}

# Main function
main() {
    # Check if script is run as root
    if [ "$(id -u)" -ne 0 ]; then
        print_error "This script must be run as root"
        exit 1
    fi
    
    # Check for command line arguments
    case "$1" in
        install)
            install_required_packages || exit 1
            install_docker || exit 1
            install_docker_compose || exit 1
            create_n8n_directory || exit 1
            start_n8n
            ;;
        start)
            start_n8n
            ;;
        stop)
            stop_n8n
            ;;
        restart)
            stop_n8n
            start_n8n
            ;;
        status)
            show_status
            ;;
        uninstall)
            uninstall_n8n
            ;;
        *)
            # Interactive menu
            while true; do
                show_menu
                read -p "Select an option (0-6): " choice
                case $choice in
                    1)
                        install_required_packages || continue
                        install_docker || continue
                        install_docker_compose || continue
                        create_n8n_directory || continue
                        start_n8n
                        ;;
                    2)
                        start_n8n
                        ;;
                    3)
                        stop_n8n
                        ;;
                    4)
                        stop_n8n
                        start_n8n
                        ;;
                    5)
                        show_status
                        ;;
                    6)
                        read -p "Are you sure you want to uninstall n8n? This will remove all data. (y/N): " confirm
                        if [[ $confirm =~ ^[Yy]$ ]]; then
                            uninstall_n8n
                            exit 0
                        fi
                        ;;
                    0)
                        echo "Exiting..."
                        exit 0
                        ;;
                    *)
                        echo "Invalid option. Please try again."
                        ;;
                esac
                read -n 1 -s -r -p "Press any key to continue..."
            done
            ;;
    esac
}

# Run main function
main "$@"

# Install Docker if not installed
if ! command_exists docker; then
    print_section "Installing Docker"
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io || print_error "Failed to install Docker"
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    print_success "Docker installed successfully"
else
    print_success "Docker is already installed"
fi

# Install Docker Compose if not installed
if ! command_exists docker-compose; then
    print_section "Installing Docker Compose"
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    print_success "Docker Compose installed successfully"
else
    print_success "Docker Compose is already installed"
fi

# Create n8n directory
N8N_DIR="/opt/n8n"
mkdir -p $N8N_DIR
cd $N8N_DIR || print_error "Failed to change to n8n directory"

# Create docker-compose.yml
print_section "Creating docker-compose.yml"
cat > docker-compose.yml << 'EOF'
version: "3"
services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=secretpassword
      - N8N_HOST=mydomain.com
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - N8N_EMAIL_MODE=true
      - N8N_SMTP_HOST=smtp.yourdomain.com
      - N8N_SMTP_PORT=587
      - N8N_SMTP_USER=user@yourdomain.com
      - N8N_SMTP_PASSWORD=yourpassword
      - N8N_SMTP_SENDER=user@yourdomain.com
      - N8N_SECURE_COOKIE=false
    ports:
      - "5678:5678"
    volumes:
      - ~/.n8n:/root/.n8n
    restart: always

  cloudflared-quick:
    image: cloudflare/cloudflared:latest
    command: tunnel --no-autoupdate --url http://n8n:5678
    depends_on:
      - n8n
    restart: unless-stopped
EOF

print_success "docker-compose.yml created successfully"

# Create environment configuration file
print_section "Creating .env file for configuration"
cat > .env << 'EOF'
# n8n Configuration
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=ChangeThisPassword123!
N8N_HOST=yourdomain.com
N8N_PORT=5678
N8N_PROTOCOL=http

# SMTP Configuration
N8N_EMAIL_MODE=true
N8N_SMTP_HOST=smtp.yourdomain.com
N8N_SMTP_PORT=587
N8N_SMTP_USER=user@yourdomain.com
N8N_SMTP_PASSWORD=your_smtp_password
N8N_SMTP_SENDER=noreply@yourdomain.com
N8N_SECURE_COOKIE=false
EOF

print_success ".env file created. Please edit it with your configuration."

# Pull Docker images
print_section "Pulling Docker images"
docker-compose pull || print_error "Failed to pull Docker images"

# Start services
print_section "Starting n8n and Cloudflare tunnel"
docker-compose up -d || print_error "Failed to start services"

# Show status
print_section "Service Status"
docker-compose ps

echo -e "\n${GREEN}Installation completed successfully!${NC}"
echo -e "\n${YELLOW}Next steps:${NC}"
echo "1. Edit the configuration in: $N8N_DIR/.env"
echo "2. Restart services with: docker-compose down && docker-compose up -d"
echo -e "\n${GREEN}n8n is now running on: http://localhost:5678${NC}"
echo -e "Cloudflare tunnel is set up and running.${NC}"
