# clf-ddns

A lightweight DDNS updater that checks the current public IP via Cloudflare's trace service and updates an A record on Cloudflare if the IP has changed. It is built as a static binary with zero external dependencies.

## Installation

Install using the one-liner script (requires root privileges):

```bash
curl -sSL https://raw.githubusercontent.com/onlyin32bit/clf-ddns/main/install.sh | sudo bash
```

The script will download the latest pre-compiled static binary, install the systemd timer (running every 5 minutes), and prompt you to set up your configuration.

## Configuration

Edit `/etc/clf-ddns/config.yaml`:

```yaml
cloudflare_api_token: "YOUR_CLOUDFLARE_API_TOKEN"
zone_id: "YOUR_ZONE_ID"
record_id: "YOUR_RECORD_ID"
domain_name: "ddns.example.com"
```

## Running & Reloading

- **Run immediately / Test configuration**:
  ```bash
  sudo clf-ddns
  ```
  or run it via systemd:
  ```bash
  sudo systemctl start clf-ddns.service
  ```
- **Check last run logs**:
  ```bash
  sudo journalctl -u clf-ddns.service
  ```
- **Apply configuration changes**:
  Changes to `/etc/clf-ddns/config.yaml` are picked up automatically on the next scheduled run. No systemd reload is required.

## Releasing and Version Control

To publish a new version:
1. Create a tag matching `v*` (e.g. `v0.1.0`):
   ```bash
   git tag v0.1.0
   ```
2. Push the tag to GitHub:
   ```bash
   git push origin v0.1.0
   ```
This automatically triggers the GitHub Actions workflow to build the static Linux binary and publish it as a release asset.
