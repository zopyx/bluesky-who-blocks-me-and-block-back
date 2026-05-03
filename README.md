# who-blocks-me

Find out who blocks you on Bluesky, split by whether you block them back. Optionally block them all back in parallel.

## Purpose

Bluesky does not provide a native "who blocked me" API. This tool uses the [Clearsky](https://clearsky.app) firehose index to discover accounts blocking you, then checks your own block list to split the results into two groups:

- **Mutual blocks** — accounts blocking you that you also block
- **One-way blocks** — accounts blocking you that you do *not* block back

You can optionally block all one-way blockers with a single command.

## How it works

1. **Clearsky API** (anonymous) — fetches every account blocking the target handle
2. **Bluesky API** (authenticated) — fetches every account *you* block
3. **Comparison** — splits blockers into the two lists above
4. **Optional block-back** — creates block records for all one-way blockers in parallel

## Python implementation

`who-blocks-me.py` — a self-contained script using `uv`.

### Dependencies

```bash
uv pip install diskcache tqdm httpx
```

Or let `uv` handle it automatically via the inline script metadata.

### Usage

```bash
# Preview only (writes blocks.json)
./who-blocks-me.py yourhandle.bsky.social your-app-password

# Preview + block all one-way blockers back
./who-blocks-me.py yourhandle.bsky.social your-app-password --block-back

# Custom parallelism (default 4 concurrent block requests)
./who-blocks-me.py yourhandle.bsky.social your-app-password --block-back --block-workers 8

# Verbose logging
./who-blocks-me.py yourhandle.bsky.social your-app-password -v
```

### Output (`blocks.json`)

```json
{
  "i_block_them": [
    {
      "did": "did:plc:...",
      "handle": "alice.bsky.social",
      "blocked_date": "2026-05-01T16:33:49.790000+00:00"
    }
  ],
  "i_dont_block_them": [
    {
      "did": "did:plc:...",
      "handle": "bob.bsky.social",
      "blocked_date": "2026-04-30T12:53:08.586908+00:00"
    }
  ]
}
```

## Rust implementation

`who-blocks-me-rs/` — a Cargo project using `tokio` and `reqwest`.

### Build

```bash
cd who-blocks-me-rs
cargo build --release
```

### Usage

```bash
# Preview only
./target/release/who-blocks-me yourhandle.bsky.social your-app-password

# Block back all one-way blockers
./target/release/who-blocks-me yourhandle.bsky.social your-app-password --block-back

# Custom parallelism
./target/release/who-blocks-me yourhandle.bsky.social your-app-password --block-back --block-workers 8

# Verbose
./target/release/who-blocks-me yourhandle.bsky.social your-app-password -v
```

### Caching

Both implementations cache resolved handles to avoid redundant API calls. The Python version uses `diskcache` in `~/.cache/who-blocks-me`. The Rust version uses a local `cache.json` file.

## Getting an app password

Do **not** use your main account password. Generate an app password in Bluesky:

**Settings → Privacy & Security → App Passwords**

## Safety notes

- The `--block-back` flag creates real block records on your account. Review `blocks.json` first if unsure.
- Rate limits are respected (0.25s delay between Clearsky pages, 0.1s delay between Bluesky block requests).
- Progress bars show real-time status for all phases.
