# n8n with Cloudflare Tunnel

This repository contains a complete setup for running n8n with Cloudflare Tunnel for secure remote access.

## Features

- One-click installation and configuration
- Automatic Docker and Docker Compose setup
- Cloudflare Tunnel integration
- Interactive menu for easy management
- Secure by default with basic authentication

## Prerequisites

- Linux server (Ubuntu/Debian recommended)
- Root access
- Domain name (for Cloudflare Tunnel)
- Cloudflare account

## Quick Start

1. Clone this repository:
   ```bash
   git clone https://github.com/Erfan-sfr/n8n.git
   cd n8n
   ```

2. Make the setup script executable:
   ```bash
   chmod +x setup-n8n.sh
   ```

3. Run the installation:
   ```bash
   sudo ./setup-n8n.sh
   ```

4. Follow the interactive menu to complete the setup.

## Usage

### Start n8n
```bash
sudo ./setup-n8n.sh start
```

### Stop n8n
```bash
sudo ./setup-n8n.sh stop
```

### Check Status
```bash
sudo ./setup-n8n.sh status
```

### Uninstall
```bash
sudo ./setup-n8n.sh uninstall
```

## Accessing n8n

- Local access: `http://localhost:5678`
- Remote access: `https://yourdomain.com` (after Cloudflare Tunnel setup)

## Security

- Change the default admin password in the `.env` file
- Keep your Cloudflare Tunnel token secure
- Regularly update n8n and its dependencies

## License

MIT

## Support

For issues and feature requests, please use the [issue tracker](https://github.com/Erfan-sfr/n8n/issues).
