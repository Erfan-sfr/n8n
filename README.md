# 🚀 n8n Automation Platform with Easy Setup Scripts

> **A complete solution for deploying and managing n8n with high security and easy internet access**

## 📋 Project Overview

This repository contains a set of automated scripts for installing, configuring, and managing the n8n automation platform. These scripts allow you to easily set up n8n with either Cloudflare Tunnel or Traefik for secure remote access.

## 📁 File Structure and Descriptions

### 1. `setup-n8n.sh`
**Purpose:** Main installation and management script for n8n with Cloudflare Tunnel  
**Description:**
- Automated installation of Docker and Docker Compose
- Initial n8n configuration
- Cloudflare Tunnel setup for secure internet access
- Interactive menu for service management

**Usage:**
```bash
sudo bash setup-n8n.sh
```

**Available Commands:**
```bash
# Full installation
sudo bash setup-n8n.sh install

# Start service
sudo bash setup-n8n.sh start

# Stop service
sudo bash setup-n8n.sh stop

# Restart service
sudo bash setup-n8n.sh restart

# Check status
sudo bash setup-n8n.sh status

# View logs
sudo bash setup-n8n.sh logs

# Update from GitHub
sudo bash setup-n8n.sh update

# Complete uninstallation
sudo bash setup-n8n.sh uninstall
```

### 2. `setup_n8n_interactive.sh`
**Purpose:** Interactive n8n installation with Traefik and HTTPS support  
**Description:**
- Interactive installation interface
- Domain support with SSL (Let's Encrypt)
- HTTP-only mode for IP access
- Automatic public IP detection
- Automatic encryption key generation

**Usage:**
```bash
sudo bash setup_n8n_interactive.sh
```

**Installation Steps:**
1. Enter domain (optional - uses IP if left blank)
2. Enter email for Let's Encrypt (when using domain)
3. Set encryption key (auto-generated if not provided)
4. Select timezone
5. Confirm and start installation

### 3. `upgrade_n8n_to_domain.sh`
**Purpose:** Upgrade existing n8n installation to use a domain with HTTPS  
**Description:**
- Converts HTTP-only installation to HTTPS with domain
- Preserves existing encryption keys
- Backs up previous configuration
- Sets up Traefik with Let's Encrypt

**Usage:**
```bash
sudo bash upgrade_n8n_to_domain.sh
```

**Prerequisites:**
- n8n must be previously installed using the interactive script
- Root access to the system

### 4. `.gitignore`
**Purpose:** Git configuration to ignore sensitive files  
**Description:**
- Ignores environment files (.env)
- Ignores n8n data files
- Ignores log and system files

## 🚀 Quick Start Guide

### Prerequisites:
- Linux server (Ubuntu 20.04/22.04 recommended)
- Root (sudo) access
- Valid domain (optional)
- Cloudflare account (for first script)

### Method 1: Install with Cloudflare Tunnel 
```bash
git clone https://github.com/Erfan-sfr/n8n.git
cd n8n
sudo bash setup-n8n.sh
```

### Method 2: Interactive Installation with Traefik
```bash
git clone https://github.com/Erfan-sfr/n8n.git
cd n8n
sudo bash setup_n8n_interactive.sh
```

## ⚙️ Configuration

### Main Configuration File:
```
/opt/n8n/.env
```

### Key Settings:
- **N8N_BASIC_AUTH_USER:** Admin username
- **N8N_BASIC_AUTH_PASSWORD:** Admin password
- **N8N_HOST:** Server domain or IP
- **N8N_SMTP_*:** Email settings
- **N8N_ENCRYPTION_KEY:** Data encryption key

## 🌐 Accessing n8n

### After Cloudflare Tunnel Installation:
- Local access: `http://localhost:5678`
- Internet access: `https://yourdomain.com` (via Cloudflare Tunnel)

### After Traefik Installation:
- With domain: `https://yourdomain.com`
- Without domain: `http://YOUR_SERVER_IP`

## 🔧 Daily Management

### Check Service Status:
```bash
cd /opt/n8n
docker compose ps
```

### View Logs:
```bash
# n8n logs
docker compose logs -f n8n

# Traefik logs
docker compose logs -f traefik

# Cloudflare Tunnel logs
docker compose logs -f cloudflared-quick
```

### Restart Services:
```bash
cd /opt/n8n
docker compose restart
```

### Stop Services:
```bash
cd /opt/n8n
docker compose down
```

## 🔒 Security Best Practices

- ✅ Always change default credentials
- 🔒 Use domain with HTTPS
- 🔄 Keep software updated
- 🔍 Regularly check logs
- 🛡️ Configure server firewall

## 🔄 Updating

### Update Scripts:
```bash
cd n8n
git pull origin main
```

### Update n8n:
```bash
cd /opt/n8n
docker compose pull
docker compose up -d
```

## 🛠️ Troubleshooting

### Common Issues:

**1. n8n won't start:**
```bash
# Check container status
docker compose ps

# Check logs
docker compose logs n8n
```

**2. Cloudflare Tunnel not working:**
```bash
# Check Cloudflare logs
docker compose logs cloudflared-quick

# View tunnel URL
docker compose logs cloudflared-quick | grep trycloudflare.com
```

**3. SSL issues:**
```bash
# Check Traefik logs
docker compose logs traefik | grep -i certificate
```

## 📚 Useful Resources

- [Official n8n Documentation](https://docs.n8n.io/)
- [Docker Documentation](https://docs.docker.com/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)

---

<div align="center">
  Created with ❤️ by Erfansfr
</div>
