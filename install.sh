#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (e.g., sudo ./install.sh)"
  exit 1
fi

echo "Building release binary..."
cargo build --release

echo "Installing binary..."
cp target/release/clf-ddns /usr/local/bin/cloudflare-ddns
chmod +x /usr/local/bin/cloudflare-ddns

echo "Setting up configuration..."
mkdir -p /etc/cloudflare-ddns

CONFIG_FILE="/etc/cloudflare-ddns/config.yaml"
if [ ! -f "$CONFIG_FILE" ]; then
  cat <<EOF > "$CONFIG_FILE"
cloudflare_api_token: "YOUR_CLOUDFLARE_API_TOKEN"
zone_id: "YOUR_ZONE_ID"
record_id: "YOUR_RECORD_ID"
domain_name: "ddns.example.com"
EOF
  echo "Created template configuration at $CONFIG_FILE"
  chmod 600 "$CONFIG_FILE"
else
  echo "Configuration file already exists at $CONFIG_FILE."
fi

echo "Installing systemd service and timer..."
cp cloudflare-ddns.service /etc/systemd/system/cloudflare-ddns.service
cp cloudflare-ddns.timer /etc/systemd/system/cloudflare-ddns.timer

echo "Enabling systemd timer..."
systemctl daemon-reload
systemctl enable --now cloudflare-ddns.timer

echo "Installation complete! Please configure: $CONFIG_FILE"
