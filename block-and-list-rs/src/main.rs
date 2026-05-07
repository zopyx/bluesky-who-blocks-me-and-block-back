//! block-and-list-rs
//!
//! Merged Rust implementation of the Bluesky "who-blocks-me" and
//! "blocks-to-list" tools.
//!
//! # Modes
//!
//! 1. **Default mode** — discovers who blocks the user, split by whether the
//!    user blocks them back.
//! 2. **`--my-blocks` mode** — lists every account the user blocks.
//!
//! # Architecture
//!
//! 1. Resolve the user's handle → DID via Clearsky anonymous API.
//! 2. Resolve DID → PDS via `plc.directory` or `did:web` well-known document.
//! 3. Authenticate against the PDS (falling back to `bsky.social`).
//! 4. Depending on mode:
//!    - Default: fetch blockers (Clearsky) and own blocks, compare, resolve
//!      handles, emit JSON.
//!    - `--my-blocks`: fetch own blocks with handles, resolve missing handles,
//!      emit JSON; optionally sync to a moderation list.
//! 5. Optionally block back, create curation lists, or create moderation lists.
//!
//! # Concurrency
//!
//! - Profile resolution is capped at 10 concurrent batches.
//! - Block-back creation is capped by `--block-workers` (default 10).
//! - List additions use `applyWrites` in batches of 200; fallback individual
//!   creates are capped at 10 concurrent.
//!
//! # Caching
//!
//! A local `cache.json` stores:
//! - Handle → DID mappings
//! - DID → handle mappings
//! - DID documents (PDS endpoints)
//!
//! Pass `--no-cache` to skip all cache reads and writes.

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

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const CLEARSKY_API: &str = "https://public.api.clearsky.services";
const BSKY_PUBLIC: &str = "https://public.api.bsky.app";
const BSKY_SOCIAL: &str = "https://bsky.social";
const BLOCK_COLLECTION: &str = "app.bsky.graph.block";
const LIST_COLLECTION: &str = "app.bsky.graph.list";
const LIST_ITEM_COLLECTION: &str = "app.bsky.graph.listitem";
const CACHE_FILE: &str = "cache.json";

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

/// Command-line arguments for `block-and-list`.
#[derive(Parser)]
#[command(name = "block-and-list")]
struct Args {
    /// Your Bluesky handle or DID
    handle: String,
    /// Your Bluesky app password
    password: String,
    /// Output JSON file path
    #[arg(short, long)]
    output: Option<PathBuf>,
    /// List every account you block instead of who blocks you
    #[arg(long)]
    my_blocks: bool,
    /// Skip all cache reads and writes
    #[arg(long)]
    no_cache: bool,
    /// Block all one-way blockers back
    #[arg(long)]
    block_back: bool,
    /// Max concurrent block requests
    #[arg(long, default_value_t = 10)]
    block_workers: usize,
    /// Create a curation list with NAME and add all blockers
    #[arg(long)]
    list: Option<String>,
    /// Create or locate a moderation list by name
    #[arg(long)]
    moderation_list: Option<String>,
    /// Add blocked accounts to the moderation list
    #[arg(long)]
    add_to_list: bool,
    /// Increase verbosity (-v, -vv)
    #[arg(short, long, action = clap::ArgAction::Count)]
    verbose: u8,
}

// ---------------------------------------------------------------------------
// Cache
// ---------------------------------------------------------------------------

/// Simple JSON-on-disk cache for DID / handle / DID-document lookups.
#[derive(Default, Serialize, Deserialize)]
struct Cache {
    dids: HashMap<String, String>,
    handles: HashMap<String, String>,
    did_docs: HashMap<String, Value>,
}

impl Cache {
    /// Load cache from disk, or return an empty cache if the file does not exist.
    fn load(path: &PathBuf) -> Result<Self> {
        if path.exists() {
            let content = std::fs::read_to_string(path)?;
            Ok(serde_json::from_str(&content).unwrap_or_default())
        } else {
            Ok(Self::default())
        }
    }

    /// Atomically write cache back to disk as pretty-printed JSON.
    fn save(&self, path: &PathBuf) -> Result<()> {
        std::fs::write(path, serde_json::to_string_pretty(self)?)?;
        Ok(())
    }
}

// ---------------------------------------------------------------------------
// Output types
// ---------------------------------------------------------------------------

/// A single record in the "who blocks me" output.
#[derive(Debug, Serialize)]
struct OutputRecord {
    did: String,
    handle: Option<String>,
    blocked_date: String,
}

/// Top-level output structure for default mode.
#[derive(Debug, Serialize)]
struct WhoBlocksOutput {
    i_block_them: Vec<OutputRecord>,
    i_dont_block_them: Vec<OutputRecord>,
}

/// A blocked account with DID and optional handle.
#[derive(Debug, Serialize, Clone)]
struct BlockedAccount {
    did: String,
    handle: Option<String>,
}

/// Top-level output structure for `--my-blocks` mode.
#[derive(Debug, Serialize)]
struct MyBlocksOutput {
    blocked: Vec<BlockedAccount>,
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Return the current UTC timestamp in ATProto ISO-8601 format.
fn iso_now() -> String {
    Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string()
}

/// Low-level Bluesky / XRPC helper.
///
/// Automatically injects `Accept`, `User-Agent` and `Authorization` headers.
/// Returns parsed JSON on success; bails with a truncated body preview on failure.
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
        .header("User-Agent", "block-and-list/1.0");
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

// ---------------------------------------------------------------------------
// Identity resolution
// ---------------------------------------------------------------------------

/// Resolve a Bluesky handle to a DID via Clearsky's anonymous endpoint.
///
/// Checks the in-memory cache first.
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

/// Resolve a DID to its ATProto PDS endpoint.
///
/// Supports `did:plc` (via plc.directory) and `did:web` (via `.well-known/did.json`).
/// Caches DID documents to avoid redundant lookups.
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

/// Extract the PDS endpoint from a DID document JSON value.
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

/// Authenticate and return `(accessJwt, did)`.
///
/// Tries the user's own PDS first, then falls back to `bsky.social`.
async fn login(
    client: &Client,
    identifier: &str,
    password: &str,
    pds: &str,
) -> Result<(String, String)> {
    for host in [pds, BSKY_SOCIAL] {
        let body = serde_json::json!({
            "identifier": identifier,
            "password": password,
        });
        match bluesky_api(
            client,
            host,
            "com.atproto.server.createSession",
            "POST",
            &[],
            Some(body),
            None,
        )
        .await
        {
            Ok(val) => {
                let token = val["accessJwt"]
                    .as_str()
                    .context("missing accessJwt")?
                    .to_string();
                let did = val["did"].as_str().context("missing did")?.to_string();
                return Ok((token, did));
            }
            Err(e) => eprintln!("Auth failed on {}: {}", host, e),
        }
    }
    anyhow::bail!("Authentication failed")
}

// ---------------------------------------------------------------------------
// Block list fetching
// ---------------------------------------------------------------------------

/// Return a `HashSet` of DIDs the authenticated user blocks.
///
/// Paginated through `app.bsky.graph.getBlocks` (100 records / page).
async fn fetch_my_blocks(
    client: &Client,
    pds: &str,
    token: &str,
) -> Result<HashSet<String>> {
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
        let val = bluesky_api(
            client,
            pds,
            "app.bsky.graph.getBlocks",
            "GET",
            &query,
            None,
            Some(token),
        )
        .await?;
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

/// Return every account the authenticated user blocks with DID and optional handle.
///
/// Paginated through `app.bsky.graph.getBlocks` (100 records / page).
async fn fetch_my_blocks_full(
    client: &Client,
    pds: &str,
    token: &str,
) -> Result<Vec<BlockedAccount>> {
    let mut blocked = Vec::new();
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
        let val = bluesky_api(
            client,
            pds,
            "app.bsky.graph.getBlocks",
            "GET",
            &query,
            None,
            Some(token),
        )
        .await?;
        for prof in val["blocks"].as_array().unwrap_or(&vec![]) {
            if let Some(did) = prof["did"].as_str() {
                blocked.push(BlockedAccount {
                    did: did.to_string(),
                    handle: prof["handle"].as_str().map(|s| s.to_string()),
                });
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

/// Return every account blocking *identifier* as a `Vec` of `(did, blocked_date)`.
///
/// Iterates Clearsky pages until a partial page (< 100 items) signals the end.
async fn get_blockers(
    client: &Client,
    identifier: &str,
) -> Result<Vec<(String, String)>> {
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
            format!(
                "{}/api/v1/anon/single-blocklist/{}/{}",
                CLEARSKY_API, identifier, page
            )
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
    }
    pb.finish_and_clear();
    Ok(blockers)
}

// ---------------------------------------------------------------------------
// Profile / handle resolution
// ---------------------------------------------------------------------------

/// Batch-resolve DIDs to handles via `app.bsky.actor.getProfiles`.
///
/// - Reads from the on-disk cache first.
/// - Splits missing entries into batches of 25 (API limit).
/// - Fires batches concurrently, capped at 10 parallel requests via a semaphore.
async fn get_profiles(
    client: &Client,
    cache: &mut Cache,
    dids: &[String],
) -> Result<HashMap<String, String>> {
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

    let semaphore = Arc::new(Semaphore::new(10));
    let mut tasks = Vec::new();
    for batch in batches {
        let client = client.clone();
        let batch_owned: Vec<String> = batch.to_vec();
        let sem = semaphore.clone();
        let task = tokio::spawn(async move {
            let _permit = sem.acquire().await.unwrap();
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

// ---------------------------------------------------------------------------
// List helpers
// ---------------------------------------------------------------------------

/// Look up an existing curation or moderation list by exact name match.
async fn find_list_by_name(
    client: &Client,
    my_did: &str,
    name: &str,
) -> Result<Option<String>> {
    let val = bluesky_api(
        client,
        BSKY_PUBLIC,
        "app.bsky.graph.getLists",
        "GET",
        &[("actor", my_did), ("limit", "100")],
        None,
        None,
    )
    .await?;
    for lst in val["lists"].as_array().unwrap_or(&vec![]) {
        if lst["name"].as_str() == Some(name) {
            if let Some(uri) = lst["uri"].as_str() {
                return Ok(Some(uri.to_string()));
            }
        }
    }
    Ok(None)
}

/// Create a new curation list and return its AT URI.
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
    let res = bluesky_api(
        client,
        pds,
        "com.atproto.repo.createRecord",
        "POST",
        &[],
        Some(body),
        Some(token),
    )
    .await?;
    let uri = res["uri"]
        .as_str()
        .context("createRecord did not return a URI for the list")?;
    Ok(uri.to_string())
}

/// Create a new moderation list (modlist) and return its AT URI.
async fn create_moderation_list(
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
            "purpose": "app.bsky.graph.defs#modlist",
            "name": name,
            "createdAt": iso_now(),
        }
    });
    let res = bluesky_api(
        client,
        pds,
        "com.atproto.repo.createRecord",
        "POST",
        &[],
        Some(body),
        Some(token),
    )
    .await?;
    let uri = res["uri"]
        .as_str()
        .context("createRecord did not return a URI for the list")?;
    Ok(uri.to_string())
}

/// Return every member of a list via `app.bsky.graph.getList`.
///
/// Each member record has shape `{did, handle}`.
async fn fetch_list_members(
    client: &Client,
    list_uri: &str,
) -> Result<Vec<BlockedAccount>> {
    let mut members = Vec::new();
    let mut cursor: Option<String> = None;
    let pb = ProgressBar::new_spinner();
    pb.set_style(
        ProgressStyle::default_spinner()
            .template("{spinner:.green} {msg}")?
            .tick_chars("⠁⠂⠄⡀⢀⠠⠐⠈ "),
    );
    let mut pages = 0;

    loop {
        let mut query = vec![("list", list_uri), ("limit", "100")];
        if let Some(ref c) = cursor {
            query.push(("cursor", c.as_str()));
        }
        let val = bluesky_api(
            client,
            BSKY_PUBLIC,
            "app.bsky.graph.getList",
            "GET",
            &query,
            None,
            None,
        )
        .await?;
        for item in val["items"].as_array().unwrap_or(&vec![]) {
            if let Some(subj) = item["subject"].as_object() {
                if let Some(did) = subj["did"].as_str() {
                    members.push(BlockedAccount {
                        did: did.to_string(),
                        handle: subj["handle"].as_str().map(|s| s.to_string()),
                    });
                }
            }
        }
        pages += 1;
        pb.set_message(format!(
            "Fetching list members (page {}, total {})",
            pages,
            members.len()
        ));
        cursor = val["cursor"].as_str().map(|s| s.to_string());
        if cursor.is_none() {
            break;
        }
    }
    pb.finish_and_clear();
    Ok(members)
}

// ---------------------------------------------------------------------------
// Mutations (block back, lists)
// ---------------------------------------------------------------------------

/// Create a block record for every DID in *dids*, limited to *max_workers* concurrency.
///
/// Returns the number of successfully created blocks.
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
            match bluesky_api(
                &client,
                &pds,
                "com.atproto.repo.createRecord",
                "POST",
                &[],
                Some(body),
                Some(&token),
            )
            .await
            {
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

/// Add DIDs to a list using `applyWrites` in batches of 200.
///
/// Falls back to individual `createRecord` calls if a batch fails.
/// The fallback is capped at 10 concurrent requests.
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
        match bluesky_api(
            client,
            pds,
            "com.atproto.repo.applyWrites",
            "POST",
            &[],
            Some(body),
            Some(token),
        )
        .await
        {
            Ok(_) => {
                total_added += chunk.len();
                pb.inc(chunk.len() as u64);
            }
            Err(e) => {
                eprintln!("Batch add failed: {}, falling back to individual creates", e);
                let sem = Arc::new(Semaphore::new(10));
                let mut tasks = Vec::new();
                for did in chunk {
                    let client = client.clone();
                    let pds = pds.to_string();
                    let token = token.to_string();
                    let my_did = my_did.to_string();
                    let list_uri = list_uri.to_string();
                    let did = did.clone();
                    let sem = sem.clone();
                    let task = tokio::spawn(async move {
                        let _permit = sem.acquire().await.unwrap();
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
                        match bluesky_api(
                            &client,
                            &pds,
                            "com.atproto.repo.createRecord",
                            "POST",
                            &[],
                            Some(fallback),
                            Some(&token),
                        )
                        .await
                        {
                            Ok(_) => true,
                            Err(e) => {
                                eprintln!("Failed to add {} to list: {}", did, e);
                                false
                            }
                        }
                    });
                    tasks.push(task);
                }
                for task in tasks {
                    if task.await? {
                        total_added += 1;
                        pb.inc(1);
                    }
                }
            }
        }
    }
    pb.finish_and_clear();
    Ok(total_added)
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

#[tokio::main]
async fn main() -> Result<()> {
    let args = Args::parse();

    let cache_path = PathBuf::from(CACHE_FILE);
    let mut cache = if args.no_cache {
        Cache::default()
    } else {
        Cache::load(&cache_path)?
    };
    let client = Client::new();

    let output_path = args.output.unwrap_or_else(|| {
        if args.my_blocks {
            PathBuf::from("my-blockings.json")
        } else {
            PathBuf::from("blocks.json")
        }
    });

    // 1. Resolve identity
    let ident = if args.handle.starts_with("did:") {
        args.handle.clone()
    } else {
        resolve_did(&client, &mut cache, &args.handle).await?
    };

    // 2. Resolve PDS
    let pds = get_pds(&client, &mut cache, &ident).await?;
    if args.verbose > 0 {
        eprintln!("PDS: {}", pds);
    }

    // 3. Authenticate
    let (token, my_did) = login(&client, &args.handle, &args.password, &pds).await?;
    if args.verbose > 0 {
        eprintln!("Authenticated as {}", my_did);
    }

    if args.my_blocks {
        // ------------------------------------------------------------------
        // --my-blocks mode
        // ------------------------------------------------------------------
        let my_blocks = fetch_my_blocks_full(&client, &pds, &token).await?;

        let blocked = if my_blocks.is_empty() {
            vec![]
        } else {
            let missing_dids: Vec<String> = my_blocks
                .iter()
                .filter_map(|b| {
                    if b.handle.is_none() {
                        Some(b.did.clone())
                    } else {
                        None
                    }
                })
                .collect();
            let profiles = if missing_dids.is_empty() {
                HashMap::new()
            } else {
                get_profiles(&client, &mut cache, &missing_dids).await?
            };
            my_blocks
                .into_iter()
                .map(|b| BlockedAccount {
                    did: b.did.clone(),
                    handle: b.handle.or_else(|| profiles.get(&b.did).cloned()),
                })
                .collect()
        };

        let output = MyBlocksOutput {
            blocked: blocked.clone(),
        };
        std::fs::write(&output_path, serde_json::to_string_pretty(&output)?)?;
        eprintln!(
            "Wrote {} records to {}",
            output.blocked.len(),
            output_path.display()
        );

        if blocked.is_empty() && args.moderation_list.is_none() {
            if !args.no_cache {
                cache.save(&cache_path)?;
            }
            println!("You are not blocking any accounts.");
            return Ok(());
        }

        // Optional moderation list
        if let Some(list_name) = &args.moderation_list {
            let list_uri = match find_list_by_name(&client, &my_did, list_name).await? {
                Some(uri) => {
                    eprintln!("Found moderation list: {}", uri);
                    uri
                }
                None => {
                    eprintln!("Creating moderation list: {}", list_name);
                    let uri =
                        create_moderation_list(&client, &pds, &token, &my_did, list_name).await?;
                    eprintln!("Created moderation list: {}", uri);
                    uri
                }
            };

            eprintln!("Fetching current list members...");
            let current_members = fetch_list_members(&client, &list_uri).await?;
            let existing_dids: HashSet<String> =
                current_members.into_iter().map(|m| m.did).collect();
            eprintln!("List currently has {} member(s).", existing_dids.len());

            if args.add_to_list {
                let to_add: Vec<String> = blocked
                    .iter()
                    .filter(|b| !existing_dids.contains(&b.did) && b.handle.is_some())
                    .map(|b| b.did.clone())
                    .collect();
                if !to_add.is_empty() {
                    let added_now =
                        add_to_list_batch(&client, &pds, &token, &my_did, &list_uri, &to_add)
                            .await?;
                    eprintln!("Added {} new account(s) to moderation list.", added_now);
                } else {
                    eprintln!("All blocked accounts are already on the moderation list.");
                }
            }

            eprintln!("Fetching final list members...");
            let members = fetch_list_members(&client, &list_uri).await?;
            let listed_output = MyBlocksOutput { blocked: members };
            let listed_path = PathBuf::from("my-blockings-listed.json");
            std::fs::write(&listed_path, serde_json::to_string_pretty(&listed_output)?)?;
            eprintln!(
                "Wrote {} records to {}",
                listed_output.blocked.len(),
                listed_path.display()
            );
        }
    } else {
        // ------------------------------------------------------------------
        // Default mode — who blocks me
        // ------------------------------------------------------------------
        let blockers = get_blockers(&client, &ident).await?;
        let my_blocks = fetch_my_blocks(&client, &pds, &token).await?;

        if blockers.is_empty() {
            println!("No accounts are blocking you.");
            let output = WhoBlocksOutput {
                i_block_them: vec![],
                i_dont_block_them: vec![],
            };
            std::fs::write(&output_path, serde_json::to_string_pretty(&output)?)?;
            if !args.no_cache {
                cache.save(&cache_path)?;
            }
            return Ok(());
        }

        // 5. Resolve handles
        let dids: Vec<String> = blockers.iter().map(|(d, _)| d.clone()).collect();
        let profiles = get_profiles(&client, &mut cache, &dids).await?;

        // 6. Compare
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

        // 7. Optional block back
        if args.block_back && !i_dont_block_them.is_empty() {
            let to_block: Vec<String> = i_dont_block_them
                .iter()
                .filter_map(|r| {
                    if r.handle.is_some() {
                        Some(r.did.clone())
                    } else {
                        None
                    }
                })
                .collect();
            let skipped = i_dont_block_them.len() - to_block.len();
            if skipped > 0 {
                eprintln!("Skipping {} account(s) with unresolved handles.", skipped);
            }
            if !to_block.is_empty() {
                let blocked_now = block_accounts(
                    &client,
                    &pds,
                    &token,
                    &my_did,
                    &to_block,
                    args.block_workers,
                )
                .await?;
                eprintln!("Blocked back {} account(s).", blocked_now);
            }
        }

        // 8. Optional list creation
        if let Some(list_name) = &args.list {
            if !blockers.is_empty() {
                let list_uri = match find_list_by_name(&client, &my_did, list_name).await? {
                    Some(uri) => {
                        eprintln!("Reusing existing list: {}", uri);
                        uri
                    }
                    None => {
                        let uri = create_list(&client, &pds, &token, &my_did, list_name).await?;
                        eprintln!("Created list: {}", uri);
                        uri
                    }
                };
                let to_add: Vec<String> = blockers.iter().map(|(did, _)| did.clone()).collect();
                let added_now =
                    add_to_list_batch(&client, &pds, &token, &my_did, &list_uri, &to_add).await?;
                eprintln!("Added {} account(s) to list.", added_now);
            }
        }

        // 9. Write output
        let output = WhoBlocksOutput {
            i_block_them,
            i_dont_block_them,
        };
        std::fs::write(&output_path, serde_json::to_string_pretty(&output)?)?;
        eprintln!(
            "Wrote {} records to {} ({} mutual, {} one-way)",
            blockers.len(),
            output_path.display(),
            output.i_block_them.len(),
            output.i_dont_block_them.len()
        );
    }

    if !args.no_cache {
        cache.save(&cache_path)?;
    }
    Ok(())
}
