# 🚀 n8n Automation Platform with Cloudflare Tunnel

> **A complete solution for deploying n8n with high security and easy internet access**

## 📦 Repository Contents

This repository contains automated scripts for quick and easy n8n setup with secure Cloudflare Tunnel.

### Main Files:

1. **`setup-n8n.sh`** - Main installation and management script
2. **`.gitignore`** - Git settings to ignore sensitive files
3. **`README.md`** - This documentation file

## ✨ Key Features

- ✅ One-click n8n installation
- 🔒 High security with basic authentication
- 🌐 Secure internet access via Cloudflare Tunnel
- 🛠️ Interactive menu for easy management
- 🔄 Auto-update functionality

## 🚀 Quick Start

### Prerequisites:
- A Linux server (Ubuntu 20.04/22.04 recommended)
- Root access
- A valid domain name
- Cloudflare account

### Installation:

```bash
git clone https://github.com/Erfan-sfr/n8n.git
cd n8n
sudo bash setup-n8n.sh
```

## 🎮 Management Commands

Use these commands from the n8n directory:

### Interactive Menu:
```bash
sudo bash setup-n8n.sh
```

### Common Commands:

#### Start Service:
```bash
sudo bash setup-n8n.sh start
```

#### Stop Service:
```bash
sudo bash setup-n8n.sh stop
```

#### Restart Service:
```bash
sudo bash setup-n8n.sh restart
```

#### Check Status:
```bash
sudo bash setup-n8n.sh status
```

#### View Cloudflare Logs:
```bash
sudo bash setup-n8n.sh logs
```

#### Update from GitHub:
```bash
sudo bash setup-n8n.sh update
```

#### Complete Uninstall:
```bash
sudo bash setup-n8n.sh uninstall
```

## 🔧 Configuration

Configuration file is located at:
```
/opt/n8n/.env
```

### Important Settings:
- Admin username and password
- SMTP settings for email notifications
- Domain and port configurations
- Cloudflare security token

## 🔒 Security

- 🔑 Always change the default password
- 🔒 Use SSL certificates
- 🔄 Keep the software updated
- 🔍 Regularly check logs

## 🌐 Access

- Local access: `http://localhost:5678`
- Internet access: `https://yourdomain.com`

## 🤝 Contributing

Your contributions are welcome! Please:
1. Create a new issue
2. Use a separate branch
3. Submit a pull request


## 📞 Support

For issues or feature requests, please use the [Issues](https://github.com/Erfan-sfr/n8n/issues) section on GitHub.

---

<div align="center">
  Created with ❤️ by Erfansfr
</div>
