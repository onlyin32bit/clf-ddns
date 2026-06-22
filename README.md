# cloudflare-ddns

A lightweight DDNS updater that checks the current public IP via Cloudflare's trace service and updates a DNS record if the IP changes.

## Installation

Run the install script as root:

```bash
sudo ./install.sh
```

## Configuration

Edit `/etc/cloudflare-ddns/config.yaml`:

```yaml
cloudflare_api_token: "YOUR_CLOUDFLARE_API_TOKEN"
zone_id: "YOUR_ZONE_ID"
record_id: "YOUR_RECORD_ID"
domain_name: "ddns.example.com"
```

## Details

- Runs every 5 minutes via a systemd timer.
- Caches the current IP at `/tmp/current_ip.txt` to avoid redundant API requests.
