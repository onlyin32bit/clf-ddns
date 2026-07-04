# clf-ddns

A lightweight DDNS updater that checks the current public IP via Cloudflare's trace service and updates an A record on Cloudflare if the IP has changed.

## Installation

Install using the script (requires root privileges):

```bash
curl -sSL https://raw.githubusercontent.com/onlyin32bit/clf-ddns/main/install.sh | sudo sh
```

## Configuration

Edit `/etc/clf-ddns/config.yaml`. You can specify a single domain or a list of multiple domains:

### Single Domain
```yaml
cloudflare_api_token: "YOUR_CLOUDFLARE_API_TOKEN"
zone_id: "YOUR_ZONE_ID"
record_id: "YOUR_RECORD_ID"
domain_name: "ddns.example.com"
```

### Multiple Domains
```yaml
cloudflare_api_token: "YOUR_CLOUDFLARE_API_TOKEN"
domains:
  - zone_id: "ZONE_ID_1"
    record_id: "RECORD_ID_1"
    domain_name: "ddns1.example.com"
  - zone_id: "ZONE_ID_2"
    record_id: "RECORD_ID_2"
    domain_name: "ddns2.example.com"
```

## Running & Reloading

- **Run immediately / Test configuration**:
  ```bash
  sudo clf-ddns
  ```

### systemd:

- **Trigger update immediately**:
  ```bash
  sudo systemctl start clf-ddns.service
  ```
- **Check last run logs**:
  ```bash
  sudo journalctl -u clf-ddns.service
  ```

### OpenRC:

- **Trigger update / Restart daemon**:
  ```bash
  sudo rc-service clf-ddns restart
  ```
- **Check service status**:
  ```bash
  sudo rc-service clf-ddns status
  ```
- **Stop daemon**:
  ```bash
  sudo rc-service clf-ddns stop
  ```

### Under other (via Cron):

- **Set up scheduler**:
  Open your crontab configuration (`sudo crontab -e`) and add:
  ```cron
  */5 * * * * /usr/local/bin/clf-ddns
  ```
