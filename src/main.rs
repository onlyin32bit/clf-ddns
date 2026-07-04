use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;

const CACHE_FILE: &str = "/tmp/current_ip.txt";
const CONFIG_FILE: &str = "/etc/clf-ddns/config.yaml";

#[derive(Deserialize)]
struct DomainConfig {
    zone_id: String,
    record_id: String,
    domain_name: String,
}

#[derive(Deserialize)]
struct Config {
    cloudflare_api_token: String,
    zone_id: Option<String>,
    record_id: Option<String>,
    domain_name: Option<String>,
    domains: Option<Vec<DomainConfig>>,
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

    let mut domains = Vec::new();
    if let (Some(zone_id), Some(record_id), Some(domain_name)) = (
        config.zone_id,
        config.record_id,
        config.domain_name,
    ) {
        domains.push(DomainConfig {
            zone_id,
            record_id,
            domain_name,
        });
    }

    if let Some(mut extra_domains) = config.domains {
        domains.append(&mut extra_domains);
    }

    if domains.is_empty() {
        eprintln!("No domains configured for update.");
        std::process::exit(1);
    }

    let mut all_success = true;
    for domain in &domains {
        let url = format!(
            "https://api.cloudflare.com/client/v4/zones/{}/dns_records/{}",
            domain.zone_id, domain.record_id
        );

        let payload = CloudflarePayload {
            r#type: "A".to_string(),
            name: domain.domain_name.clone(),
            content: current_ip.clone(),
            ttl: 1,
            proxied: true,
        };

        match ureq::put(&url)
            .set("Authorization", &format!("Bearer {}", config.cloudflare_api_token))
            .timeout(std::time::Duration::from_secs(5))
            .send_json(&payload)
        {
            Ok(res) => {
                if res.status() == 200 {
                    println!("Cloudflare DNS successfully updated for {} to: {}", domain.domain_name, current_ip);
                } else {
                    eprintln!(
                        "Cloudflare API returned unexpected status for {}: {}",
                        domain.domain_name,
                        res.status()
                    );
                    all_success = false;
                }
            }
            Err(ureq::Error::Status(code, response)) => {
                eprintln!(
                    "Cloudflare API returned error status for {}: {} - {}",
                    domain.domain_name,
                    code,
                    response.into_string().unwrap_or_default()
                );
                all_success = false;
            }
            Err(e) => {
                eprintln!("Error updating domain {}: {}", domain.domain_name, e);
                all_success = false;
            }
        }
    }

    if all_success {
        fs::write(CACHE_FILE, &current_ip)?;
    } else {
        std::process::exit(1);
    }

    Ok(())
}
