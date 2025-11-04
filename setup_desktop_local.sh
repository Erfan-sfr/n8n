#!/bin/bash

# Update package list and upgrade existing packages
echo "Updating package list and upgrading existing packages..."
sudo apt update && sudo apt upgrade -y

# Install required packages for desktop environment and n8n
echo "Installing required packages..."
sudo apt install -y ubuntu-desktop xrdp nodejs npm

# Install n8n globally
echo "Installing n8n..."
sudo npm install n8n -g

# Create a systemd service for n8n
echo "Creating n8n systemd service..."
cat <<EOF | sudo tee /etc/systemd/system/n8n.service > /dev/null
[Unit]
Description=n8n Workflow Automation
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=/home/$USER
ExecStart=$(which n8n) start
Restart=always
RestartSec=10
Environment="NODE_OPTIONS=--max_old_space_size=4096"

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd to recognize new service
sudo systemctl daemon-reload

# Enable n8n to start on boot
sudo systemctl enable n8n.service

# Start n8n service
sudo systemctl start n8n.service

# Create a desktop shortcut to open n8n in browser
cat > ~/Desktop/Open\ n8n.desktop << EOL
[Desktop Entry]
Version=1.0
Type=Application
Name=Open n8n
Comment=Open n8n in web browser
Exec=xdg-open http://localhost:5678
Icon=internet-web-browser
Categories=Development;
EOL

# Make the desktop launcher executable
chmod +x ~/Desktop/Open\ n8n.desktop

echo ""
echo "========================================"
echo "n8n setup is complete!"
echo "n8n will start automatically on system boot"
echo "You can access n8n at: http://localhost:5678"
echo ""
echo "To manage n8n service:"
echo "- Start:   sudo systemctl start n8n"
echo "- Stop:    sudo systemctl stop n8n"
echo "- Restart: sudo systemctl restart n8n"
echo "- Status:  systemctl status n8n"
echo "- Logs:    journalctl -u n8n -f"
echo ""
echo "You can also use the 'Open n8n' icon on your desktop to access n8n in your browser."
