#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "diskcache>=5.6",
#     "tqdm>=4.65",
#     "httpx>=0.27",
# ]
# ///
"""List all Bluesky accounts that you block."""

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

CLEARSKY = "https://public.api.clearsky.services"
BSKY_PUBLIC = "https://public.api.bsky.app"
BSKY_SOCIAL = "https://bsky.social"
BLOCK_COLLECTION = "app.bsky.graph.block"
LIST_COLLECTION = "app.bsky.graph.list"
LIST_ITEM_COLLECTION = "app.bsky.graph.listitem"
CACHE = diskcache.Cache(str(Path.home() / ".cache" / "who-blocks-me"))


async def fetch(client: httpx.AsyncClient, url: str, ttl: int = 3600) -> dict:
    if url in CACHE:
        return CACHE[url]
    resp = await client.get(url, headers={"Accept": "application/json"})
    resp.raise_for_status()
    data = resp.json()
    CACHE.set(url, data, expire=ttl)
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
    url = f"{base}/xrpc/{nsid}"
    headers = {"Accept": "application/json", "User-Agent": "blocks-to-list/1.0"}
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


async def resolve_did(client: httpx.AsyncClient, handle: str) -> str:
    data = await fetch(client, f"{CLEARSKY}/api/v1/anon/get-did/{handle}")
    return data["data"]["did_identifier"]


async def get_pds(client: httpx.AsyncClient, did: str) -> str:
    if did.startswith("did:plc:"):
        doc = await fetch(client, f"https://plc.directory/{did}")
    elif did.startswith("did:web:"):
        domain = did.removeprefix("did:web:")
        doc = await fetch(client, f"https://{domain}/.well-known/did.json")
    else:
        raise RuntimeError(f"Unsupported DID method: {did}")
    for svc in doc.get("service", []):
        ep = svc.get("serviceEndpoint")
        if ep and (svc.get("type") == "AtprotoPersonalDataServer" or svc.get("id", "").endswith("#atproto_pds")):
            return ep.rstrip("/")
    raise RuntimeError("No PDS found in DID document")


async def login(client: httpx.AsyncClient, identifier: str, password: str, pds: str) -> tuple[str, str]:
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


async def fetch_my_blocks(client: httpx.AsyncClient, pds: str, token: str) -> list[dict]:
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


async def find_list_by_name(
    client: httpx.AsyncClient, my_did: str, name: str
) -> str | None:
    data = await bluesky_api(
        client, BSKY_PUBLIC, "app.bsky.graph.getLists",
        params={"actor": my_did, "limit": 100},
    )
    for lst in data.get("lists", []):
        if lst.get("name") == name:
            return lst.get("uri")
    return None


async def create_moderation_list(
    client: httpx.AsyncClient, pds: str, token: str, my_did: str, name: str
) -> str:
    body = {
        "repo": my_did,
        "collection": LIST_COLLECTION,
        "record": {
            "$type": LIST_COLLECTION,
            "purpose": "app.bsky.graph.defs#modlist",
            "name": name,
            "createdAt": datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        },
    }
    data = await bluesky_api(client, pds, "com.atproto.repo.createRecord", method="POST", token=token, body=body)
    uri = data.get("uri")
    if not uri:
        raise RuntimeError("createRecord did not return a URI for the list")
    return uri


async def fetch_list_members(client: httpx.AsyncClient, list_uri: str) -> list[dict]:
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
            members.append({
                "did": subj.get("did"),
                "handle": subj.get("handle"),
            })
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
    semaphore = asyncio.Semaphore(10)
    total_added = 0
    errors: list[str] = []

    # Debug: print first request details
    first_body = {
        "repo": my_did,
        "collection": LIST_ITEM_COLLECTION,
        "record": {
            "$type": LIST_ITEM_COLLECTION,
            "subject": dids[0] if dids else None,
            "list": list_uri,
            "createdAt": datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        },
    }
    print(f"[DEBUG] List URI: {list_uri}", file=sys.stderr)
    print(f"[DEBUG] First request body: {json.dumps(first_body, indent=2)}", file=sys.stderr)

    async def add_one(idx: int, did: str) -> bool:
        nonlocal total_added
        async with semaphore:
            body = {
                "repo": my_did,
                "collection": LIST_ITEM_COLLECTION,
                "record": {
                    "$type": LIST_ITEM_COLLECTION,
                    "subject": did,
                    "list": list_uri,
                    "createdAt": datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
                },
            }
            url = f"{pds}/xrpc/com.atproto.repo.createRecord"
            headers = {
                "Accept": "application/json",
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
            }
            try:
                resp = await client.post(url, headers=headers, json=body, timeout=60)
                resp.raise_for_status()
                if idx == 0:
                    print(f"[DEBUG] First response: {resp.status_code} {resp.text[:500]}", file=sys.stderr)
                total_added += 1
                return True
            except httpx.HTTPStatusError as exc:
                err = f"Failed to add {did}: HTTP {exc.response.status_code} {exc.response.text[:500]}"
                errors.append(err)
                if len(errors) <= 5:
                    print(err, file=sys.stderr)
                return False
            except Exception as exc:
                err = f"Failed to add {did}: {type(exc).__name__} {exc}"
                errors.append(err)
                if len(errors) <= 5:
                    print(err, file=sys.stderr)
                return False

    results = await tqdm_async.gather(
        *[add_one(i, did) for i, did in enumerate(dids)],
        desc="Adding to moderation list",
        unit="account",
        file=sys.stderr,
    )
    if len(errors) > 5:
        print(f"... and {len(errors) - 5} more errors", file=sys.stderr)
    print(f"[DEBUG] Total added: {total_added}, Total errors: {len(errors)}", file=sys.stderr)
    return sum(results)


async def get_profiles(client: httpx.AsyncClient, dids: list[str]) -> dict[str, str]:
    profiles: dict[str, str] = {}
    missing: list[str] = []
    for did in dids:
        cached = CACHE.get(did)
        if isinstance(cached, str):
            profiles[did] = cached
        else:
            missing.append(did)
    if not missing:
        return profiles

    batches = [missing[i : i + 25] for i in range(0, len(missing), 25)]

    async def fetch_batch(batch: list[str]) -> dict[str, str]:
        actors = "&".join(f"actors={d}" for d in batch)
        url = f"{BSKY_PUBLIC}/xrpc/app.bsky.actor.getProfiles?{actors}"
        try:
            data = await fetch(client, url, ttl=3600)
        except RuntimeError as exc:
            logging.warning("profile batch failed: %s", exc)
            return {}
        result: dict[str, str] = {}
        for p in data.get("profiles", []):
            result[p["did"]] = p["handle"]
            CACHE.set(p["did"], p["handle"], expire=3600)
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


async def main() -> int:
    parser = argparse.ArgumentParser(description="List all Bluesky accounts that you block.")
    parser.add_argument("handle", help="Your Bluesky handle or DID")
    parser.add_argument("password", help="Your Bluesky app password")
    parser.add_argument("-v", "--verbose", action="count", default=0)
    parser.add_argument("-o", "--output", default="my-blockings.json", help="output JSON file")
    parser.add_argument("--no-cache", action="store_true", help="ignore cached block list and fetch fresh data")
    parser.add_argument("--moderation-list", metavar="NAME", help="create/find a moderation list and list its members")
    parser.add_argument("--add-to-list", action="store_true", help="add blocked accounts to the moderation list in batches of 100")
    args = parser.parse_args()

    level = logging.DEBUG if args.verbose >= 2 else logging.INFO if args.verbose else logging.WARNING
    logging.basicConfig(level=level, format="%(message)s")

    async with httpx.AsyncClient() as client:
        ident = args.handle
        if not ident.startswith("did:"):
            ident = await resolve_did(client, ident)

        cache_key = f"blocks-to-list:{ident}"
        cached_hit = False
        if not args.no_cache and cache_key in CACHE:
            cached = CACHE.get(cache_key)
            if isinstance(cached, dict) and "blocked" in cached:
                print("Using cached block list.", file=sys.stderr)
                Path(args.output).write_text(json.dumps(cached, indent=2) + "\n")
                print(f"Wrote {len(cached['blocked'])} records to {args.output}", file=sys.stderr)
                cached_hit = True
                if not args.moderation_list:
                    return 0

        pds = await get_pds(client, ident)
        logging.info("PDS: %s", pds)

        token, my_did = await login(client, args.handle, args.password, pds)
        logging.info("Authenticated as %s", my_did)

        if cached_hit:
            blocked = cached["blocked"]
            print(f"Skipping fetch, using {len(blocked)} cached records for moderation list.", file=sys.stderr)
        else:
            my_blocks = await fetch_my_blocks(client, pds, token)

            if not my_blocks:
                print("You are not blocking any accounts.", file=sys.stderr)
                result = {"blocked": []}
                CACHE.set(cache_key, result, expire=3600)
                Path(args.output).write_text(json.dumps(result, indent=2) + "\n")
                if not args.moderation_list:
                    return 0
                blocked = []
            else:
                dids = [b["did"] for b in my_blocks if not b.get("handle")]
                profiles = await get_profiles(client, dids)

                blocked = []
                for record in my_blocks:
                    did = record["did"]
                    blocked.append({
                        "did": did,
                        "handle": record.get("handle") or profiles.get(did),
                    })

                result = {"blocked": blocked}
                CACHE.set(cache_key, result, expire=3600)
                Path(args.output).write_text(json.dumps(result, indent=2) + "\n")
                print(f"Wrote {len(blocked)} records to {args.output}", file=sys.stderr)

        if args.moderation_list:
            logging.debug("moderation_list arg: %s", args.moderation_list)
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
                to_add = [r["did"] for r in blocked if r["did"] not in existing_dids]
                if to_add:
                    logging.debug("Adding %d new accounts to moderation list in batches of 100", len(to_add))
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

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(asyncio.run(main()))
    except RuntimeError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        raise SystemExit(1)
    except KeyboardInterrupt:
        print("\nAborted.", file=sys.stderr)
        raise SystemExit(130)
