#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "diskcache>=5.6",
#     "tqdm>=4.65",
#     "httpx>=0.27",
# ]
# ///
"""block-and-list.py

Merged utility combining ``who-blocks-me.py`` and ``blocks-to-list.py``.

Two mutually-exclusive modes are available via CLI flags:

1. **Default mode** — discover who blocks you on Bluesky, split by whether you
   block them back. Optionally block back one-way blockers or add them to a
   curation list.

2. ``--my-blocks`` mode — list every account *you* block. Optionally sync them
   to a moderation list and/or a curation list.

Architecture
------------
1. Resolve handle → DID via Clearsky (default mode) or directly.
2. Resolve DID → PDS endpoint (plc.directory or did:web well-known).
3. Authenticate with the PDS (falling back to bsky.social).
4. Fetch data depending on mode (Clearsky blockers or own block list).
5. Resolve handles for unknown DIDs in batches of 25 via
   ``app.bsky.actor.getProfiles``.
6. Write JSON output.
7. Optionally perform mutations (block back, list creation / population).

Concurrency
-----------
- Profile resolution is capped at 10 concurrent batches.
- Block-back creation is capped by ``--block-workers`` (default 10).
- List additions use ``applyWrites`` in batches of 200. If that fails, the
  script falls back to individual ``createRecord`` calls capped at 10
  concurrent.

Caching
-------
A ``diskcache.Cache`` at ``~/.cache/who-blocks-me`` is used by default.
Pass ``--no-cache`` to disable all cache reads and writes.

* Default mode caches DID documents, handle → DID mappings, and DID → handle
  mappings.
* ``--my-blocks`` mode additionally caches the full block list under the key
  ``block-and-list:<did>`` for 1 hour.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import logging
import sys
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import diskcache
import httpx
from tqdm import tqdm
from tqdm.asyncio import tqdm as tqdm_async

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
CLEARSKY = "https://public.api.clearsky.services"
BSKY_PUBLIC = "https://public.api.bsky.app"
BSKY_SOCIAL = "https://bsky.social"
BLOCK_COLLECTION = "app.bsky.graph.block"
LIST_COLLECTION = "app.bsky.graph.list"
LIST_ITEM_COLLECTION = "app.bsky.graph.listitem"
DEFAULT_CACHE_PATH = str(Path.home() / ".cache" / "who-blocks-me")


# ---------------------------------------------------------------------------
# Cache wrapper
# ---------------------------------------------------------------------------
class Cache:
    """Tiny wrapper around diskcache.Cache (or a no-op null cache)."""

    def __init__(self, path: str | None = None) -> None:
        self._cache: diskcache.Cache | None = diskcache.Cache(path) if path else None

    def __contains__(self, key: object) -> bool:
        if self._cache is None:
            return False
        return key in self._cache

    def get(self, key: object, default: Any = None) -> Any:
        if self._cache is None:
            return default
        return self._cache.get(key, default)

    def set(self, key: object, value: Any, expire: int | None = None) -> None:
        if self._cache is None:
            return
        self._cache.set(key, value, expire=expire)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def iso_now() -> str:
    """Return the current UTC timestamp in ISO-8601 / ATProto format."""
    return datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")


# ---------------------------------------------------------------------------
# HTTP helpers
# ---------------------------------------------------------------------------
async def fetch(client: httpx.AsyncClient, url: str, cache: Cache, ttl: int = 3600) -> dict:
    """GET *url* with short-term caching.

    Args:
        client: Shared httpx async client.
        url: Target URL.
        cache: Cache instance (may be a NullCache).
        ttl: Cache expiration in seconds (default 1 h).

    Returns:
        Parsed JSON response as a dict.
    """
    if url in cache:
        return cache.get(url)
    resp = await client.get(url, headers={"Accept": "application/json"})
    resp.raise_for_status()
    data = resp.json()
    cache.set(url, data, expire=ttl)
    return data


async def bluesky_api(
    client: httpx.AsyncClient,
    base: str,
    nsid: str,
    *,
    method: str = "GET",
    params: dict[str, Any] | None = None,
    body: dict[str, Any] | None = None,
    token: str | None = None,
) -> dict[str, Any]:
    """Low-level Bluesky / XRPC helper.

    Automatically injects Accept, User-Agent and Authorization headers.
    Raises ``RuntimeError`` on non-2xx with a truncated body preview.
    """
    url = f"{base}/xrpc/{nsid}"
    headers = {"Accept": "application/json", "User-Agent": "block-and-list/1.0"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if method == "GET":
        resp = await client.get(url, headers=headers, params=params, timeout=60)
    else:
        resp = await client.post(url, headers=headers, params=params, json=body, timeout=60)
    try:
        resp.raise_for_status()
    except httpx.HTTPStatusError as exc:
        detail = exc.response.text[:200]
        raise RuntimeError(f"{nsid} HTTP {exc.response.status_code}: {detail}") from exc
    return resp.json() if resp.text else {}


# ---------------------------------------------------------------------------
# Identity resolution
# ---------------------------------------------------------------------------
async def resolve_did(client: httpx.AsyncClient, handle: str, cache: Cache) -> str:
    """Resolve a Bluesky handle to a DID via Clearsky's anonymous endpoint."""
    data = await fetch(client, f"{CLEARSKY}/api/v1/anon/get-did/{handle}", cache)
    return data["data"]["did_identifier"]


async def get_pds(client: httpx.AsyncClient, did: str, cache: Cache) -> str:
    """Resolve a DID to its ATProto PDS endpoint.

    Supports ``did:plc`` (via plc.directory) and ``did:web`` (via
    ``.well-known/did.json``).
    """
    if did.startswith("did:plc:"):
        doc = await fetch(client, f"https://plc.directory/{did}", cache)
    elif did.startswith("did:web:"):
        domain = did.removeprefix("did:web:")
        doc = await fetch(client, f"https://{domain}/.well-known/did.json", cache)
    else:
        raise RuntimeError(f"Unsupported DID method: {did}")
    for svc in doc.get("service", []):
        ep = svc.get("serviceEndpoint")
        if ep and (svc.get("type") == "AtprotoPersonalDataServer" or svc.get("id", "").endswith("#atproto_pds")):
            return ep.rstrip("/")
    raise RuntimeError("No PDS found in DID document")


async def login(client: httpx.AsyncClient, identifier: str, password: str, pds: str) -> tuple[str, str]:
    """Authenticate and return ``(accessJwt, did)``.

    Tries the user's own PDS first, then falls back to ``bsky.social``.
    """
    for host in dict.fromkeys([pds, BSKY_SOCIAL]):
        try:
            data = await bluesky_api(
                client, host, "com.atproto.server.createSession",
                method="POST", body={"identifier": identifier, "password": password},
            )
            return data["accessJwt"], data["did"]
        except RuntimeError as exc:
            logging.warning("Auth failed on %s: %s", host, exc)
    raise RuntimeError("Authentication failed")


# ---------------------------------------------------------------------------
# Data fetching
# ---------------------------------------------------------------------------
async def fetch_my_blocks(client: httpx.AsyncClient, pds: str, token: str) -> list[dict]:
    """Return every blocked account with at least ``did`` and ``handle`` keys.

    Paginated through ``app.bsky.graph.getBlocks`` (100 records / page).
    """
    blocked: list[dict] = []
    cursor: str | None = None
    pbar = tqdm(desc="Fetching my blocks", unit="page", file=sys.stderr)
    while True:
        params: dict[str, Any] = {"limit": 100}
        if cursor:
            params["cursor"] = cursor
        data = await bluesky_api(client, pds, "app.bsky.graph.getBlocks", params=params, token=token)
        for prof in data.get("blocks", []):
            blocked.append({"did": prof["did"], "handle": prof.get("handle")})
        pbar.update(1)
        pbar.set_postfix({"total": len(blocked)})
        cursor = data.get("cursor")
        if not cursor:
            break
    pbar.close()
    return blocked


async def fetch_clearsky_page(client: httpx.AsyncClient, identifier: str, page: int, cache: Cache) -> list[dict]:
    """Fetch a single page of Clearsky's single-blocklist endpoint."""
    url = f"{CLEARSKY}/api/v1/anon/single-blocklist/{identifier}"
    if page > 1:
        url += f"/{page}"
    # Short 5-minute TTL for blocklist data.
    data = await fetch(client, url, cache, ttl=300)
    return data.get("data", {}).get("blocklist") or []


async def get_blockers(client: httpx.AsyncClient, identifier: str, cache: Cache) -> list[tuple[str, str]]:
    """Return ``[(did, blocked_date), ...]`` for every account blocking *identifier*.

    Iterates Clearsky pages until a partial page (< 100 items) signals the end.
    """
    page = 1
    blockers: list[tuple[str, str]] = []
    pbar = tqdm(desc="Fetching blockers", unit="page", file=sys.stderr)
    while True:
        items = await fetch_clearsky_page(client, identifier, page, cache)
        for it in items:
            blockers.append((it["did"], it["blocked_date"]))
        pbar.update(1)
        pbar.set_postfix({"total": len(blockers)})
        if len(items) < 100:
            break
        page += 1
    pbar.close()
    return blockers


# ---------------------------------------------------------------------------
# Profile / handle resolution
# ---------------------------------------------------------------------------
async def get_profiles(client: httpx.AsyncClient, dids: list[str], cache: Cache) -> dict[str, str]:
    """Batch-resolve DIDs to handles via ``app.bsky.actor.getProfiles``.

    - Reads from cache first.
    - Splits missing entries into batches of 25 (API limit).
    - Limits concurrency to 10 parallel batches.
    """
    profiles: dict[str, str] = {}
    missing: list[str] = []
    for did in dids:
        cached = cache.get(did)
        if isinstance(cached, str):
            profiles[did] = cached
        else:
            missing.append(did)
    if not missing:
        return profiles

    batches = [missing[i : i + 25] for i in range(0, len(missing), 25)]
    semaphore = asyncio.Semaphore(10)

    async def fetch_batch(batch: list[str]) -> dict[str, str]:
        async with semaphore:
            actors = "&".join(f"actors={d}" for d in batch)
            url = f"{BSKY_PUBLIC}/xrpc/app.bsky.actor.getProfiles?{actors}"
            try:
                data = await fetch(client, url, cache, ttl=3600)
            except RuntimeError as exc:
                logging.warning("profile batch failed: %s", exc)
                return {}
            result: dict[str, str] = {}
            for p in data.get("profiles", []):
                result[p["did"]] = p["handle"]
                cache.set(p["did"], p["handle"], expire=3600)
            return result

    results = await tqdm_async.gather(
        *[fetch_batch(b) for b in batches],
        desc="Resolving handles",
        unit="batch",
        file=sys.stderr,
    )
    for r in results:
        profiles.update(r)
    return profiles


# ---------------------------------------------------------------------------
# Mutations
# ---------------------------------------------------------------------------
async def block_accounts(
    client: httpx.AsyncClient, pds: str, token: str, my_did: str, dids: list[str], max_workers: int
) -> int:
    """Create a block record for every DID in *dids*, limited to *max_workers* concurrency.

    Returns the number of successfully created blocks.
    """
    semaphore = asyncio.Semaphore(max_workers)

    async def block_one(did: str) -> bool:
        async with semaphore:
            try:
                await bluesky_api(
                    client, pds, "com.atproto.repo.createRecord",
                    method="POST",
                    token=token,
                    body={
                        "repo": my_did,
                        "collection": BLOCK_COLLECTION,
                        "record": {
                            "$type": BLOCK_COLLECTION,
                            "subject": did,
                            "createdAt": iso_now(),
                        },
                    },
                )
                return True
            except RuntimeError as exc:
                logging.warning("Failed to block %s: %s", did, exc)
                return False

    results = await tqdm_async.gather(
        *[block_one(did) for did in dids],
        desc="Blocking back",
        unit="account",
        file=sys.stderr,
    )
    return sum(results)


async def find_list_by_name(
    client: httpx.AsyncClient, my_did: str, name: str
) -> str | None:
    """Look up an existing list by exact name match via ``app.bsky.graph.getLists``."""
    data = await bluesky_api(
        client, BSKY_PUBLIC, "app.bsky.graph.getLists",
        params={"actor": my_did, "limit": 100},
    )
    for lst in data.get("lists", []):
        if lst.get("name") == name:
            return lst.get("uri")
    return None


async def create_list(
    client: httpx.AsyncClient, pds: str, token: str, my_did: str, name: str
) -> str:
    """Create a new *curation* list and return its AT URI."""
    body = {
        "repo": my_did,
        "collection": LIST_COLLECTION,
        "record": {
            "$type": LIST_COLLECTION,
            "purpose": "app.bsky.graph.defs#curatelist",
            "name": name,
            "createdAt": iso_now(),
        },
    }
    data = await bluesky_api(client, pds, "com.atproto.repo.createRecord", method="POST", token=token, body=body)
    uri = data.get("uri")
    if not uri:
        raise RuntimeError("createRecord did not return a URI for the list")
    return uri


async def create_moderation_list(
    client: httpx.AsyncClient, pds: str, token: str, my_did: str, name: str
) -> str:
    """Create a new *moderation* list (modlist) and return its AT URI."""
    body = {
        "repo": my_did,
        "collection": LIST_COLLECTION,
        "record": {
            "$type": LIST_COLLECTION,
            "purpose": "app.bsky.graph.defs#modlist",
            "name": name,
            "createdAt": iso_now(),
        },
    }
    data = await bluesky_api(client, pds, "com.atproto.repo.createRecord", method="POST", token=token, body=body)
    uri = data.get("uri")
    if not uri:
        raise RuntimeError("createRecord did not return a URI for the moderation list")
    return uri


async def fetch_list_members(client: httpx.AsyncClient, list_uri: str) -> list[dict]:
    """Return every member of a list via ``app.bsky.graph.getList``.

    Each member record has shape ``{"did": ..., "handle": ...}``.
    """
    members: list[dict] = []
    cursor: str | None = None
    pbar = tqdm(desc="Fetching list members", unit="page", file=sys.stderr)
    while True:
        params: dict[str, Any] = {"list": list_uri, "limit": 100}
        if cursor:
            params["cursor"] = cursor
        data = await bluesky_api(client, BSKY_PUBLIC, "app.bsky.graph.getList", params=params)
        for item in data.get("items", []):
            subj = item.get("subject", {})
            members.append({"did": subj.get("did"), "handle": subj.get("handle")})
        pbar.update(1)
        pbar.set_postfix({"total": len(members)})
        cursor = data.get("cursor")
        if not cursor:
            break
    pbar.close()
    return members


async def add_to_list_batch(
    client: httpx.AsyncClient, pds: str, token: str, my_did: str, list_uri: str, dids: list[str]
) -> int:
    """Add DIDs to a list using ``applyWrites`` in batches of 200.

    Falls back to individual ``createRecord`` calls (max 10 concurrent) if a
    batch fails. Returns the number of successfully added accounts.
    """
    BATCH_SIZE = 200
    total_added = 0
    batches = [dids[i : i + BATCH_SIZE] for i in range(0, len(dids), BATCH_SIZE)]
    pbar = tqdm(total=len(dids), desc="Adding to list", unit="account", file=sys.stderr)

    for batch in batches:
        writes = []
        for did in batch:
            writes.append({
                "$type": "com.atproto.repo.applyWrites#create",
                "collection": LIST_ITEM_COLLECTION,
                "value": {
                    "$type": LIST_ITEM_COLLECTION,
                    "subject": did,
                    "list": list_uri,
                    "createdAt": iso_now(),
                },
            })
        body = {"repo": my_did, "writes": writes}
        try:
            await bluesky_api(client, pds, "com.atproto.repo.applyWrites", method="POST", token=token, body=body)
            total_added += len(batch)
            pbar.update(len(batch))
        except RuntimeError as exc:
            logging.warning("Batch add failed: %s", exc)
            # Concurrent fallback for this batch
            semaphore = asyncio.Semaphore(10)

            async def add_one(did: str) -> bool:
                async with semaphore:
                    try:
                        await bluesky_api(
                            client, pds, "com.atproto.repo.createRecord",
                            method="POST",
                            token=token,
                            body={
                                "repo": my_did,
                                "collection": LIST_ITEM_COLLECTION,
                                "record": {
                                    "$type": LIST_ITEM_COLLECTION,
                                    "subject": did,
                                    "list": list_uri,
                                    "createdAt": iso_now(),
                                },
                            },
                        )
                        return True
                    except RuntimeError as exc2:
                        logging.warning("Failed to add %s to list: %s", did, exc2)
                        return False

            results = await asyncio.gather(*[add_one(did) for did in batch])
            added = sum(results)
            total_added += added
            pbar.update(added)

    pbar.close()
    return total_added


# ---------------------------------------------------------------------------
# Mode implementations
# ---------------------------------------------------------------------------
async def run_default_mode(
    client: httpx.AsyncClient,
    args: argparse.Namespace,
    cache: Cache,
) -> int:
    """Execute the default "who blocks me" flow."""
    ident = args.handle
    if not ident.startswith("did:"):
        ident = await resolve_did(client, ident, cache)

    pds = await get_pds(client, ident, cache)
    logging.info("PDS: %s", pds)

    token, my_did = await login(client, args.handle, args.password, pds)
    logging.info("Authenticated as %s", my_did)

    blockers = await get_blockers(client, ident, cache)
    my_blocks = await fetch_my_blocks(client, pds, token)
    my_block_dids = {b["did"] for b in my_blocks}

    if not blockers:
        print("No accounts are blocking you.", file=sys.stderr)
        result = {"i_block_them": [], "i_dont_block_them": []}
        Path(args.output).write_text(json.dumps(result, indent=2) + "\n")
        return 0

    dids = list({did for did, _ in blockers})
    profiles = await get_profiles(client, dids, cache)

    i_block_them: list[dict] = []
    i_dont_block_them: list[dict] = []

    for did, blocked_date in blockers:
        record = {
            "did": did,
            "handle": profiles.get(did),
            "blocked_date": blocked_date,
        }
        if did in my_block_dids:
            i_block_them.append(record)
        else:
            i_dont_block_them.append(record)

    if args.block_back and i_dont_block_them:
        to_block = [r["did"] for r in i_dont_block_them if r["handle"]]
        skipped = len(i_dont_block_them) - len(to_block)
        if skipped:
            print(f"Skipping {skipped} account(s) with unresolved handles.", file=sys.stderr)
        blocked_now = await block_accounts(client, pds, token, my_did, to_block, args.block_workers)
        print(f"Blocked back {blocked_now} account(s).", file=sys.stderr)

    if args.list_name and blockers:
        list_uri = await find_list_by_name(client, my_did, args.list_name)
        if list_uri:
            print(f"Reusing existing list: {list_uri}", file=sys.stderr)
        else:
            list_uri = await create_list(client, pds, token, my_did, args.list_name)
            print(f"Created list: {list_uri}", file=sys.stderr)
        to_add = [did for did, _ in blockers]
        added_now = await add_to_list_batch(client, pds, token, my_did, list_uri, to_add)
        print(f"Added {added_now} account(s) to list.", file=sys.stderr)

    result = {
        "i_block_them": i_block_them,
        "i_dont_block_them": i_dont_block_them,
    }
    Path(args.output).write_text(json.dumps(result, indent=2) + "\n")
    print(
        f"Wrote {len(blockers)} records to {args.output} "
        f"({len(i_block_them)} mutual, {len(i_dont_block_them)} one-way)",
        file=sys.stderr,
    )
    return 0


async def run_my_blocks_mode(
    client: httpx.AsyncClient,
    args: argparse.Namespace,
    cache: Cache,
) -> int:
    """Execute the ``--my-blocks`` flow."""
    ident = args.handle
    if not ident.startswith("did:"):
        ident = await resolve_did(client, ident, cache)

    cache_key = f"block-and-list:{ident}"
    cached_hit = False
    blocked: list[dict] = []

    if cache_key in cache:
        cached = cache.get(cache_key)
        if isinstance(cached, dict) and "blocked" in cached:
            print("Using cached block list.", file=sys.stderr)
            blocked = cached["blocked"]
            Path(args.output).write_text(json.dumps(cached, indent=2) + "\n")
            print(f"Wrote {len(blocked)} records to {args.output}", file=sys.stderr)
            cached_hit = True
            if not args.moderation_list and not args.list_name:
                return 0

    pds = await get_pds(client, ident, cache)
    logging.info("PDS: %s", pds)

    token, my_did = await login(client, args.handle, args.password, pds)
    logging.info("Authenticated as %s", my_did)

    if cached_hit:
        print(
            f"Skipping fetch, using {len(blocked)} cached records for list operations.",
            file=sys.stderr,
        )
    else:
        my_blocks = await fetch_my_blocks(client, pds, token)

        if not my_blocks:
            print("You are not blocking any accounts.", file=sys.stderr)
            result = {"blocked": []}
            cache.set(cache_key, result, expire=3600)
            Path(args.output).write_text(json.dumps(result, indent=2) + "\n")
            blocked = []
        else:
            dids = [b["did"] for b in my_blocks if not b.get("handle")]
            profiles = await get_profiles(client, dids, cache)

            blocked = []
            for record in my_blocks:
                did = record["did"]
                blocked.append({
                    "did": did,
                    "handle": record.get("handle") or profiles.get(did),
                })

            result = {"blocked": blocked}
            cache.set(cache_key, result, expire=3600)
            Path(args.output).write_text(json.dumps(result, indent=2) + "\n")
            print(f"Wrote {len(blocked)} records to {args.output}", file=sys.stderr)

    # Moderation list
    if args.moderation_list:
        list_uri = await find_list_by_name(client, my_did, args.moderation_list)
        if list_uri:
            print(f"Found moderation list: {list_uri}", file=sys.stderr)
        else:
            print(f"Creating moderation list: {args.moderation_list}", file=sys.stderr)
            list_uri = await create_moderation_list(client, pds, token, my_did, args.moderation_list)
            print(f"Created moderation list: {list_uri}", file=sys.stderr)

        print("Fetching current list members...", file=sys.stderr)
        current_members = await fetch_list_members(client, list_uri)
        existing_dids = {m["did"] for m in current_members if m.get("did")}
        print(f"List currently has {len(existing_dids)} member(s).", file=sys.stderr)

        if args.add_to_list:
            to_add = [r["did"] for r in blocked if r["did"] not in existing_dids and r.get("handle")]
            if to_add:
                added_now = await add_to_list_batch(client, pds, token, my_did, list_uri, to_add)
                print(f"Added {added_now} new account(s) to moderation list.", file=sys.stderr)
            else:
                print("All blocked accounts are already on the moderation list.", file=sys.stderr)

        print("Fetching final list members...", file=sys.stderr)
        members = await fetch_list_members(client, list_uri)
        listed_result = {"blocked": members}
        listed_output = "my-blockings-listed.json"
        Path(listed_output).write_text(json.dumps(listed_result, indent=2) + "\n")
        print(f"Wrote {len(members)} records to {listed_output}", file=sys.stderr)

    # Curation list
    if args.list_name:
        list_uri = await find_list_by_name(client, my_did, args.list_name)
        if list_uri:
            print(f"Reusing existing curation list: {list_uri}", file=sys.stderr)
        else:
            list_uri = await create_list(client, pds, token, my_did, args.list_name)
            print(f"Created curation list: {list_uri}", file=sys.stderr)

        print("Fetching current list members...", file=sys.stderr)
        current_members = await fetch_list_members(client, list_uri)
        existing_dids = {m["did"] for m in current_members if m.get("did")}

        to_add = [r["did"] for r in blocked if r["did"] not in existing_dids and r.get("handle")]
        if to_add:
            added_now = await add_to_list_batch(client, pds, token, my_did, list_uri, to_add)
            print(f"Added {added_now} account(s) to curation list.", file=sys.stderr)
        else:
            print("All blocked accounts are already on the curation list.", file=sys.stderr)

    return 0


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
async def main() -> int:
    parser = argparse.ArgumentParser(
        description="Discover who blocks you on Bluesky (default) or list accounts you block (--my-blocks). "
                    "Optionally block back, sync to moderation lists, or curation lists.",
    )
    parser.add_argument("handle", help="Your Bluesky handle or DID")
    parser.add_argument("password", help="Your Bluesky app password")
    parser.add_argument("-v", "--verbose", action="count", default=0)
    parser.add_argument("-o", "--output", default=None, help="output JSON file (default: blocks.json or my-blockings.json)")
    parser.add_argument("--my-blocks", action="store_true", help="list accounts YOU block instead of who blocks you")
    parser.add_argument("--no-cache", action="store_true", help="disable diskcache reads/writes entirely")
    parser.add_argument("--block-back", action="store_true", help="[default mode] block all one-way blockers in parallel")
    parser.add_argument("--block-workers", type=int, default=10, help="max concurrent block requests (default: 10)")
    parser.add_argument("--list", dest="list_name", metavar="NAME", help="create/reuse a curation list and add accounts")
    parser.add_argument("--moderation-list", metavar="NAME", help="[--my-blocks mode] create/reuse a moderation list")
    parser.add_argument("--add-to-list", action="store_true", help="actually populate the moderation list (default is read-only)")
    args = parser.parse_args()

    if args.output is None:
        args.output = "my-blockings.json" if args.my_blocks else "blocks.json"

    level = logging.DEBUG if args.verbose >= 2 else logging.INFO if args.verbose else logging.WARNING
    logging.basicConfig(level=level, format="%(message)s")

    cache = Cache(DEFAULT_CACHE_PATH) if not args.no_cache else Cache()

    async with httpx.AsyncClient() as client:
        if args.my_blocks:
            return await run_my_blocks_mode(client, args, cache)
        return await run_default_mode(client, args, cache)


if __name__ == "__main__":
    try:
        raise SystemExit(asyncio.run(main()))
    except RuntimeError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        raise SystemExit(1)
    except KeyboardInterrupt:
        print("\nAborted.", file=sys.stderr)
        raise SystemExit(130)
