use anyhow::{Context, Result};
use chrono::Utc;
use clap::Parser;
use indicatif::{ProgressBar, ProgressStyle};
use reqwest::Client;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::{HashMap, HashSet};
use std::path::PathBuf;
use std::sync::Arc;
use tokio::sync::Semaphore;

const CLEARSKY_API: &str = "https://public.api.clearsky.services";
const BSKY_PUBLIC: &str = "https://public.api.bsky.app";
const BSKY_SOCIAL: &str = "https://bsky.social";
const BLOCK_COLLECTION: &str = "app.bsky.graph.block";
const LIST_COLLECTION: &str = "app.bsky.graph.list";
const LIST_ITEM_COLLECTION: &str = "app.bsky.graph.listitem";
const CACHE_FILE: &str = "cache.json";

#[derive(Parser)]
#[command(name = "who-blocks-me")]
struct Args {
    handle: String,
    password: String,
    #[arg(short, long, default_value = "blocks.json")]
    output: PathBuf,
    #[arg(long)]
    block_back: bool,
    #[arg(long, default_value_t = 4)]
    block_workers: usize,
    #[arg(long)]
    list: Option<String>,
    #[arg(short, long, action = clap::ArgAction::Count)]
    verbose: u8,
}

#[derive(Default, Serialize, Deserialize)]
struct Cache {
    dids: HashMap<String, String>,
    handles: HashMap<String, String>,
    did_docs: HashMap<String, Value>,
}

impl Cache {
    fn load(path: &PathBuf) -> Result<Self> {
        if path.exists() {
            let content = std::fs::read_to_string(path)?;
            Ok(serde_json::from_str(&content).unwrap_or_default())
        } else {
            Ok(Self::default())
        }
    }

    fn save(&self, path: &PathBuf) -> Result<()> {
        std::fs::write(path, serde_json::to_string_pretty(self)?)?;
        Ok(())
    }
}

#[derive(Debug, Serialize)]
struct OutputRecord {
    did: String,
    handle: Option<String>,
    blocked_date: String,
}

#[derive(Debug, Serialize)]
struct Output {
    i_block_them: Vec<OutputRecord>,
    i_dont_block_them: Vec<OutputRecord>,
}

fn iso_now() -> String {
    Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string()
}

async fn bluesky_api(
    client: &Client,
    base: &str,
    nsid: &str,
    method: &str,
    query: &[(&str, &str)],
    body: Option<Value>,
    token: Option<&str>,
) -> Result<Value> {
    let url = format!("{}/xrpc/{}", base, nsid);
    let mut req = if method == "GET" {
        client.get(&url).query(query)
    } else {
        let mut r = client.post(&url);
        if let Some(b) = body {
            r = r.json(&b);
        }
        r
    };
    req = req
        .header("Accept", "application/json")
        .header("User-Agent", "who-blocks-me/1.0");
    if let Some(t) = token {
        req = req.header("Authorization", format!("Bearer {}", t));
    }
    let resp = req.send().await?;
    let status = resp.status();
    if !status.is_success() {
        let text = resp.text().await.unwrap_or_default();
        anyhow::bail!("{} HTTP {}: {}", nsid, status, &text[..text.len().min(200)]);
    }
    let text = resp.text().await?;
    if text.is_empty() {
        Ok(Value::Null)
    } else {
        Ok(serde_json::from_str(&text)?)
    }
}

async fn resolve_did(client: &Client, cache: &mut Cache, handle: &str) -> Result<String> {
    if let Some(did) = cache.dids.get(handle) {
        return Ok(did.clone());
    }
    let url = format!("{}/api/v1/anon/get-did/{}", CLEARSKY_API, handle);
    let val: Value = client
        .get(&url)
        .header("Accept", "application/json")
        .send()
        .await?
        .error_for_status()?
        .json()
        .await?;
    let did = val["data"]["did_identifier"]
        .as_str()
        .context("missing did_identifier")?
        .to_string();
    cache.dids.insert(handle.to_string(), did.clone());
    Ok(did)
}

async fn get_pds(client: &Client, cache: &mut Cache, did: &str) -> Result<String> {
    if let Some(doc) = cache.did_docs.get(did) {
        if let Some(pds) = extract_pds(doc) {
            return Ok(pds);
        }
    }
    let doc: Value = if did.starts_with("did:plc:") {
        client
            .get(format!("https://plc.directory/{}", did))
            .header("Accept", "application/json")
            .send()
            .await?
            .error_for_status()?
            .json()
            .await?
    } else if did.starts_with("did:web:") {
        let domain = &did["did:web:".len()..];
        client
            .get(format!("https://{}/.well-known/did.json", domain))
            .header("Accept", "application/json")
            .send()
            .await?
            .error_for_status()?
            .json()
            .await?
    } else {
        anyhow::bail!("Unsupported DID method: {}", did);
    };
    cache.did_docs.insert(did.to_string(), doc.clone());
    extract_pds(&doc).context("No PDS found in DID document")
}

fn extract_pds(doc: &Value) -> Option<String> {
    for svc in doc["service"].as_array()? {
        let ep = svc["serviceEndpoint"].as_str()?;
        let id = svc["id"].as_str().unwrap_or("");
        let svc_type = svc["type"].as_str().unwrap_or("");
        if svc_type == "AtprotoPersonalDataServer" || id.ends_with("#atproto_pds") {
            return Some(ep.trim_end_matches('/').to_string());
        }
    }
    None
}

async fn login(client: &Client, identifier: &str, password: &str, pds: &str) -> Result<(String, String)> {
    for host in [pds, BSKY_SOCIAL] {
        let body = serde_json::json!({
            "identifier": identifier,
            "password": password,
        });
        match bluesky_api(client, host, "com.atproto.server.createSession", "POST", &[], Some(body), None).await {
            Ok(val) => {
                let token = val["accessJwt"].as_str().context("missing accessJwt")?.to_string();
                let did = val["did"].as_str().context("missing did")?.to_string();
                return Ok((token, did));
            }
            Err(e) => eprintln!("Auth failed on {}: {}", host, e),
        }
    }
    anyhow::bail!("Authentication failed")
}

async fn fetch_my_blocks(client: &Client, pds: &str, token: &str) -> Result<HashSet<String>> {
    let mut blocked = HashSet::new();
    let mut cursor: Option<String> = None;
    let pb = ProgressBar::new_spinner();
    pb.set_style(
        ProgressStyle::default_spinner()
            .template("{spinner:.green} {msg}")?
            .tick_chars("⠁⠂⠄⡀⢀⠠⠐⠈ "),
    );
    let mut pages = 0;

    loop {
        let mut query = vec![("limit", "100")];
        if let Some(ref c) = cursor {
            query.push(("cursor", c.as_str()));
        }
        let val = bluesky_api(client, pds, "app.bsky.graph.getBlocks", "GET", &query, None, Some(token)).await?;
        for prof in val["blocks"].as_array().unwrap_or(&vec![]) {
            if let Some(did) = prof["did"].as_str() {
                blocked.insert(did.to_string());
            }
        }
        pages += 1;
        pb.set_message(format!("Fetching my blocks (page {}, total {})", pages, blocked.len()));
        cursor = val["cursor"].as_str().map(|s| s.to_string());
        if cursor.is_none() {
            break;
        }
    }
    pb.finish_and_clear();
    Ok(blocked)
}

async fn get_blockers(client: &Client, identifier: &str) -> Result<Vec<(String, String)>> {
    let mut blockers = Vec::new();
    let mut page = 1;
    let pb = ProgressBar::new_spinner();
    pb.set_style(
        ProgressStyle::default_spinner()
            .template("{spinner:.green} {msg}")?
            .tick_chars("⠁⠂⠄⡀⢀⠠⠐⠈ "),
    );

    loop {
        let url = if page == 1 {
            format!("{}/api/v1/anon/single-blocklist/{}", CLEARSKY_API, identifier)
        } else {
            format!("{}/api/v1/anon/single-blocklist/{}/{}", CLEARSKY_API, identifier, page)
        };
        let val: Value = client
            .get(&url)
            .header("Accept", "application/json")
            .send()
            .await?
            .error_for_status()?
            .json()
            .await?;
        let entries: Vec<_> = val["data"]["blocklist"]
            .as_array()
            .map(|a| {
                a.iter()
                    .filter_map(|v| {
                        Some((
                            v["did"].as_str()?.to_string(),
                            v["blocked_date"].as_str()?.to_string(),
                        ))
                    })
                    .collect()
            })
            .unwrap_or_default();
        let count = entries.len();
        blockers.extend(entries);
        pb.set_message(format!("Fetching blockers (page {}, total {})", page, blockers.len()));
        if count < 100 {
            break;
        }
        page += 1;
        tokio::time::sleep(tokio::time::Duration::from_millis(250)).await;
    }
    pb.finish_and_clear();
    Ok(blockers)
}

async fn get_profiles(client: &Client, cache: &mut Cache, dids: &[String]) -> Result<HashMap<String, String>> {
    let mut profiles: HashMap<String, String> = HashMap::new();
    let mut missing: Vec<String> = Vec::new();

    for did in dids {
        if let Some(handle) = cache.handles.get(did) {
            profiles.insert(did.clone(), handle.clone());
        } else {
            missing.push(did.clone());
        }
    }

    if missing.is_empty() {
        return Ok(profiles);
    }

    let batches: Vec<_> = missing.chunks(25).collect();
    let pb = ProgressBar::new(batches.len() as u64);
    pb.set_style(
        ProgressStyle::default_bar()
            .template("{spinner:.green} [{elapsed_precise}] [{bar:40.cyan/blue}] {pos}/{len} {msg}")?
            .progress_chars("#>-"),
    );
    pb.set_message("Resolving handles");

    let mut tasks = Vec::new();
    for batch in batches {
        let client = client.clone();
        let batch_owned: Vec<String> = batch.to_vec();
        let task = tokio::spawn(async move {
            let actors: Vec<_> = batch_owned.iter().map(|d| ("actors", d.as_str())).collect();
            let url = format!("{}/xrpc/app.bsky.actor.getProfiles", BSKY_PUBLIC);
            let resp = client.get(&url).query(&actors).send().await?;
            let val: Value = resp.json().await?;
            let mut result = HashMap::new();
            for p in val["profiles"].as_array().unwrap_or(&vec![]) {
                if let (Some(did), Some(handle)) = (p["did"].as_str(), p["handle"].as_str()) {
                    result.insert(did.to_string(), handle.to_string());
                }
            }
            Result::<_, reqwest::Error>::Ok(result)
        });
        tasks.push(task);
    }

    for task in tasks {
        match task.await? {
            Ok(result) => {
                for (did, handle) in result {
                    cache.handles.insert(did.clone(), handle.clone());
                    profiles.insert(did, handle);
                }
            }
            Err(e) => eprintln!("Profile batch failed: {}", e),
        }
        pb.inc(1);
    }
    pb.finish_and_clear();
    Ok(profiles)
}

async fn block_accounts(
    client: &Client,
    pds: &str,
    token: &str,
    my_did: &str,
    dids: &[String],
    max_workers: usize,
) -> Result<usize> {
    let semaphore = Arc::new(Semaphore::new(max_workers));
    let pb = ProgressBar::new(dids.len() as u64);
    pb.set_style(
        ProgressStyle::default_bar()
            .template("{spinner:.green} [{elapsed_precise}] [{bar:40.cyan/blue}] {pos}/{len} {msg}")?
            .progress_chars("#>-"),
    );
    pb.set_message("Blocking back");

    let mut tasks = Vec::new();
    for did in dids {
        let client = client.clone();
        let pds = pds.to_string();
        let token = token.to_string();
        let my_did = my_did.to_string();
        let did = did.clone();
        let sem = semaphore.clone();
        let task = tokio::spawn(async move {
            let _permit = sem.acquire().await.unwrap();
            let body = serde_json::json!({
                "repo": my_did,
                "collection": BLOCK_COLLECTION,
                "record": {
                    "$type": BLOCK_COLLECTION,
                    "subject": did,
                    "createdAt": iso_now(),
                }
            });
            let res = bluesky_api(&client, &pds, "com.atproto.repo.createRecord", "POST", &[], Some(body), Some(&token)).await;
            tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;
            match res {
                Ok(_) => true,
                Err(e) => {
                    eprintln!("Failed to block {}: {}", did, e);
                    false
                }
            }
        });
        tasks.push(task);
    }

    let mut count = 0;
    for task in tasks {
        if task.await? {
            count += 1;
        }
        pb.inc(1);
    }
    pb.finish_and_clear();
    Ok(count)
}

async fn create_list(
    client: &Client,
    pds: &str,
    token: &str,
    my_did: &str,
    name: &str,
) -> Result<String> {
    let body = serde_json::json!({
        "repo": my_did,
        "collection": LIST_COLLECTION,
        "record": {
            "$type": LIST_COLLECTION,
            "purpose": "app.bsky.graph.defs#curatelist",
            "name": name,
            "createdAt": iso_now(),
        }
    });
    let res = bluesky_api(client, pds, "com.atproto.repo.createRecord", "POST", &[], Some(body), Some(token)).await?;
    let uri = res["uri"].as_str().context("createRecord did not return a URI for the list")?;
    Ok(uri.to_string())
}

async fn add_to_list_batch(
    client: &Client,
    pds: &str,
    token: &str,
    my_did: &str,
    list_uri: &str,
    dids: &[String],
) -> Result<usize> {
    const BATCH_SIZE: usize = 200;
    let mut total_added = 0;
    let pb = ProgressBar::new(dids.len() as u64);
    pb.set_style(
        ProgressStyle::default_bar()
            .template("{spinner:.green} [{elapsed_precise}] [{bar:40.cyan/blue}] {pos}/{len} {msg}")?
            .progress_chars("#>-"),
    );
    pb.set_message("Adding to list");

    for chunk in dids.chunks(BATCH_SIZE) {
        let mut writes = Vec::new();
        for did in chunk {
            writes.push(serde_json::json!({
                "$type": "com.atproto.repo.applyWrites#create",
                "collection": LIST_ITEM_COLLECTION,
                "value": {
                    "$type": LIST_ITEM_COLLECTION,
                    "subject": did,
                    "list": list_uri,
                    "createdAt": iso_now(),
                }
            }));
        }
        let body = serde_json::json!({
            "repo": my_did,
            "writes": writes,
        });
        match bluesky_api(client, pds, "com.atproto.repo.applyWrites", "POST", &[], Some(body), Some(token)).await {
            Ok(_) => {
                total_added += chunk.len();
                pb.inc(chunk.len() as u64);
            }
            Err(e) => {
                eprintln!("Batch add failed: {}, falling back to individual creates", e);
                for did in chunk {
                    let fallback = serde_json::json!({
                        "repo": my_did,
                        "collection": LIST_ITEM_COLLECTION,
                        "record": {
                            "$type": LIST_ITEM_COLLECTION,
                            "subject": did,
                            "list": list_uri,
                            "createdAt": iso_now(),
                        }
                    });
                    match bluesky_api(client, pds, "com.atproto.repo.createRecord", "POST", &[], Some(fallback), Some(token)).await {
                        Ok(_) => {
                            total_added += 1;
                            pb.inc(1);
                        }
                        Err(e2) => eprintln!("Failed to add {} to list: {}", did, e2),
                    }
                }
            }
        }
        tokio::time::sleep(tokio::time::Duration::from_millis(250)).await;
    }
    pb.finish_and_clear();
    Ok(total_added)
}

#[tokio::main]
async fn main() -> Result<()> {
    let args = Args::parse();

    let cache_path = PathBuf::from(CACHE_FILE);
    let mut cache = Cache::load(&cache_path)?;
    let client = Client::new();

    let ident = if args.handle.starts_with("did:") {
        args.handle.clone()
    } else {
        resolve_did(&client, &mut cache, &args.handle).await?
    };

    let pds = get_pds(&client, &mut cache, &ident).await?;
    if args.verbose > 0 {
        eprintln!("PDS: {}", pds);
    }

    let (token, my_did) = login(&client, &args.handle, &args.password, &pds).await?;
    if args.verbose > 0 {
        eprintln!("Authenticated as {}", my_did);
    }

    let blockers = get_blockers(&client, &ident).await?;
    let my_blocks = fetch_my_blocks(&client, &pds, &token).await?;

    if blockers.is_empty() {
        println!("No accounts are blocking you.");
        let output = Output {
            i_block_them: vec![],
            i_dont_block_them: vec![],
        };
        std::fs::write(&args.output, serde_json::to_string_pretty(&output)?)?;
        cache.save(&cache_path)?;
        return Ok(());
    }

    let dids: Vec<String> = blockers.iter().map(|(d, _)| d.clone()).collect();
    let profiles = get_profiles(&client, &mut cache, &dids).await?;

    let mut i_block_them = Vec::new();
    let mut i_dont_block_them = Vec::new();

    for (did, blocked_date) in &blockers {
        let record = OutputRecord {
            did: did.clone(),
            handle: profiles.get(did).cloned(),
            blocked_date: blocked_date.clone(),
        };
        if my_blocks.contains(did) {
            i_block_them.push(record);
        } else {
            i_dont_block_them.push(record);
        }
    }

    if args.block_back && !i_dont_block_them.is_empty() {
        let to_block: Vec<String> = i_dont_block_them.iter().map(|r| r.did.clone()).collect();
        let blocked_now = block_accounts(&client, &pds, &token, &my_did, &to_block, args.block_workers).await?;
        eprintln!("Blocked back {} account(s).", blocked_now);
    }

    if let Some(list_name) = &args.list {
        if !blockers.is_empty() {
            let list_uri = create_list(&client, &pds, &token, &my_did, list_name).await?;
            eprintln!("Created list: {}", list_uri);
            let to_add: Vec<String> = blockers.iter().map(|(did, _)| did.clone()).collect();
            let added_now = add_to_list_batch(&client, &pds, &token, &my_did, &list_uri, &to_add).await?;
            eprintln!("Added {} account(s) to list.", added_now);
        }
    }

    let output = Output {
        i_block_them,
        i_dont_block_them,
    };

    std::fs::write(&args.output, serde_json::to_string_pretty(&output)?)?;
    eprintln!(
        "Wrote {} records to {} ({} mutual, {} one-way)",
        blockers.len(),
        args.output.display(),
        output.i_block_them.len(),
        output.i_dont_block_them.len()
    );

    cache.save(&cache_path)?;
    Ok(())
}
