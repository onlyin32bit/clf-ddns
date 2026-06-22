use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;

const CACHE_FILE: &str = "/tmp/current_ip.txt";
const CONFIG_FILE: &str = "/etc/cloudflare-ddns/config.yaml";

#[derive(Deserialize)]
struct Config {
    cloudflare_api_token: String,
    zone_id: String,
    record_id: String,
    domain_name: String,
}

#[derive(Serialize)]
struct CloudflarePayload {
    r#type: String,
    name: String,
    content: String,
    ttl: u32,
    proxied: bool,
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let trace_resp = ureq::get("https://1.1.1.1/cdn-cgi/trace")
        .timeout(std::time::Duration::from_secs(5))
        .call()?
        .into_string()?;

    let current_ip = trace_resp
        .lines()
        .find(|line| line.starts_with("ip="))
        .map(|line| line.replace("ip=", ""))
        .ok_or("Failed to parse IP from Cloudflare trace")?;

    if let Ok(cached_ip) = fs::read_to_string(CACHE_FILE) {
        if cached_ip.trim() == current_ip {
            return Ok(());
        }
    }

    let config_path = Path::new(CONFIG_FILE);
    if !config_path.exists() {
        eprintln!("Configuration file missing at {}", CONFIG_FILE);
        std::process::exit(1);
    }
    
    let config_str = fs::read_to_string(config_path)?;
    let config: Config = serde_yaml::from_str(&config_str)?;

    let url = format!(
        "https://api.cloudflare.com/client/v4/zones/{}/dns_records/{}",
        config.zone_id, config.record_id
    );

    let payload = CloudflarePayload {
        r#type: "A".to_string(),
        name: config.domain_name,
        content: current_ip.clone(),
        ttl: 1,
        proxied: true,
    };

    let res = match ureq::put(&url)
        .set("Authorization", &format!("Bearer {}", config.cloudflare_api_token))
        .timeout(std::time::Duration::from_secs(5))
        .send_json(&payload)
    {
        Ok(response) => response,
        Err(ureq::Error::Status(code, response)) => {
            eprintln!("Cloudflare API returned error status: {} - {}", code, response.into_string().unwrap_or_default());
            std::process::exit(1);
        }
        Err(e) => return Err(Box::new(e)),
    };

    if res.status() == 200 {
        fs::write(CACHE_FILE, &current_ip)?;
        println!("Cloudflare DNS successfully updated to: {}", current_ip);
    } else {
        eprintln!("Cloudflare API returned unexpected status: {}", res.status());
        std::process::exit(1);
    }

    Ok(())
}
