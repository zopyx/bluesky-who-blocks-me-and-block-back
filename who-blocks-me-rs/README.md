# who-blocks-me-rs

Rust implementation of the Bluesky "who blocks me" tool.

## Build

```bash
cargo build --release
```

## Usage

```bash
# Preview only (writes blocks.json)
./target/release/who-blocks-me yourhandle.bsky.social your-app-password

# Block back all one-way blockers
./target/release/who-blocks-me yourhandle.bsky.social your-app-password --block-back

# Custom parallelism (default 4 concurrent block requests)
./target/release/who-blocks-me yourhandle.bsky.social your-app-password --block-back --block-workers 8

# Create a curation list and add all one-way blockers
./target/release/who-blocks-me yourhandle.bsky.social your-app-password --list "People Blocking Me"

# Verbose
./target/release/who-blocks-me yourhandle.bsky.social your-app-password -v
```

## Architecture

See the crate-level documentation in `src/main.rs` for a detailed overview.

High-level flow:

1. Resolve handle → DID via Clearsky.
2. Resolve DID → PDS via `plc.directory` or `did:web`.
3. Authenticate (PDS first, fallback to `bsky.social`).
4. Fetch own blocks and Clearsky blockers (both paginated).
5. Resolve handles in batches of 25 via `app.bsky.actor.getProfiles`.
6. Compare and emit mutual vs. one-way blocks.
7. Optionally block back or add to a list.

## Caching

A local `cache.json` stores handle → DID, DID → handle, and DID document lookups between runs.

## Safety

- `--block-back` creates real block records. Review `blocks.json` first.
- Progress bars show real-time status.
