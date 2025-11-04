#!/bin/bash

# Update package list and upgrade existing packages
echo "Updating package list and upgrading existing packages..."
sudo apt update && sudo apt upgrade -y

# Install required packages for desktop environment
echo "Installing required packages for desktop environment..."
sudo apt install -y ubuntu-desktop xrdp

# Install n8n locally
echo "Installing n8n locally..."
npm install n8n -g

# Create a manual start script for n8n
echo "Creating n8n manual start script..."
cat > ~/start_n8n.sh << 'EOL'
#!/bin/bash
# Start n8n in the background
echo "Starting n8n..."
n8n start

# Open n8n in default browser (uncomment the line below if you want the browser to open automatically)
# xdg-open http://localhost:5678
EOL

# Make the script executable
chmod +x ~/start_n8n.sh

# Create a desktop shortcut for easy access
cat > ~/Desktop/Start\ n8n.desktop << EOL
[Desktop Entry]
Version=1.0
Type=Application
Name=Start n8n
Comment=Start n8n workflow automation
Exec=$HOME/start_n8n.sh
Icon=utilities-terminal
Terminal=true
Categories=Development;
EOL

# Make the desktop launcher executable
chmod +x ~/Desktop/Start\ n8n.desktop

echo "Setup complete!"
echo "To start n8n, double-click the 'Start n8n' icon on your desktop."
echo "You can access n8n at http://localhost:5678"
