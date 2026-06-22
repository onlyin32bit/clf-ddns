#!/bin/sh
set -e

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run as root (e.g., sudo ./install.sh)"
  exit 1
fi

echo "Downloading pre-compiled binary (clf-ddns)..."
BINARY_URL="https://github.com/onlyin32bit/clf-ddns/releases/latest/download/clf-ddns"

if command -v curl >/dev/null 2>&1; then
  curl -L -o /usr/local/bin/clf-ddns "$BINARY_URL"
elif command -v wget >/dev/null 2>&1; then
  wget -O /usr/local/bin/clf-ddns "$BINARY_URL"
else
  echo "Error: curl or wget is required to download the binary."
  exit 1
fi

chmod +x /usr/local/bin/clf-ddns

echo "Setting up configuration directory..."
mkdir -p /etc/clf-ddns

CONFIG_FILE="/etc/clf-ddns/config.yaml"
if [ ! -f "$CONFIG_FILE" ]; then
  cat <<EOF > "$CONFIG_FILE"
cloudflare_api_token: "YOUR_CLOUDFLARE_API_TOKEN"
zone_id: "YOUR_ZONE_ID"
record_id: "YOUR_RECORD_ID"
domain_name: "ddns.example.com"
EOF
  echo "Created configuration template at $CONFIG_FILE"
  chmod 600 "$CONFIG_FILE"
else
  echo "Configuration file already exists at $CONFIG_FILE."
fi

INIT_SYSTEM="other"
if [ -d /run/systemd/system ]; then
  INIT_SYSTEM="systemd"
elif [ -x /sbin/openrc-run ] || [ -d /etc/runlevels ]; then
  INIT_SYSTEM="openrc"
fi

if [ "$INIT_SYSTEM" = "systemd" ]; then
  echo "Systemd detected. Installing service and timer..."
  cat <<EOF > /etc/systemd/system/clf-ddns.service
[Unit]
Description=Cloudflare DDNS Updater (clf-ddns)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/clf-ddns
User=root
EOF

  cat <<EOF > /etc/systemd/system/clf-ddns.timer
[Unit]
Description=Run clf-ddns every 5 minutes

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
EOF

  echo "Enabling and starting systemd timer..."
  systemctl daemon-reload
  systemctl enable --now clf-ddns.timer

elif [ "$INIT_SYSTEM" = "openrc" ]; then
  echo "OpenRC detected. Installing service script..."
  
  cat <<'EOF' > /etc/init.d/clf-ddns
#!/sbin/openrc-run

name="clf-ddns"
description="Cloudflare DDNS Updater Daemon"
pidfile="/run/clf-ddns.pid"

depend() {
    need net
}

start() {
    ebegin "Starting clf-ddns daemon"
    start-stop-daemon --start --background --make-pidfile --pidfile "$pidfile" \
        --exec /bin/sh -- -c "while true; do /usr/local/bin/clf-ddns; sleep 300; done"
    eend $?
}

stop() {
    ebegin "Stopping clf-ddns daemon"
    start-stop-daemon --stop --pidfile "$pidfile"
    eend $?
}
EOF

  chmod +x /etc/init.d/clf-ddns
  
  echo "Enabling and starting OpenRC service..."
  rc-update add clf-ddns default
  rc-service clf-ddns start

else
  echo "Unknown init system detected. Skipping automatic scheduler setup."
fi

echo ""
echo "Installation complete!"
echo "The configuration file is located at: $CONFIG_FILE"
echo ""

if [ "$INIT_SYSTEM" = "other" ]; then
  echo "=========================================================="
  echo "NOTE FOR CRON / OTHER USERS:"
  echo "To run clf-ddns periodically (every 5 minutes), please"
  echo "add a cron job. Run 'crontab -e' and add:"
  echo "*/5 * * * * /usr/local/bin/clf-ddns"
  echo "=========================================================="
  echo ""
fi

if [ -t 0 ] || [ -c /dev/tty ]; then
  printf "Would you like to edit the configuration file now? [y/N]: " >/dev/tty
  read choice </dev/tty
  case "$choice" in
    [yY][eE][sS]|[yY])
      EDITOR_BIN=""
      if [ -n "$EDITOR" ]; then
        EDITOR_BIN="$EDITOR"
      elif command -v nano >/dev/null 2>&1; then
        EDITOR_BIN="nano"
      elif command -v vim >/dev/null 2>&1; then
        EDITOR_BIN="vim"
      elif command -v vi >/dev/null 2>&1; then
        EDITOR_BIN="vi"
      fi

      if [ -n "$EDITOR_BIN" ]; then
        $EDITOR_BIN "$CONFIG_FILE" </dev/tty >/dev/tty
        echo "Configuration saved."
        echo "To test the updater manually, run: sudo clf-ddns"
      else
        echo "No terminal editor found. Please manually edit $CONFIG_FILE using your preferred editor."
      fi
      ;;
    *)
      echo "Skipped editing. Please configure $CONFIG_FILE before running the updater manually."
      ;;
  esac
fi
