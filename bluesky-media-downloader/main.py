import argparse
import asyncio
import io
import sys
from pathlib import Path

import httpx
from atproto import Client
from PIL import Image
from tqdm import tqdm


CDN_IMAGE = "https://cdn.bsky.app/img/feed_fullsize/plain/{did}/{cid}@jpeg"
CDN_THUMB = "https://cdn.bsky.app/img/feed_thumbnail/plain/{did}/{cid}@jpeg"


def get_actor_did(client: Client, handle: str) -> str:
    resp = client.resolve_handle(handle)
    return resp.did


def iter_all_records(client: Client, did: str, collection: str):
    cursor = None
    while True:
        params = {"repo": did, "collection": collection, "limit": 100}
        if cursor:
            params["cursor"] = cursor
        response = client.com.atproto.repo.list_records(params)
        for record in response.records:
            yield record
        cursor = getattr(response, "cursor", None)
        if not cursor:
            break


def extract_cid(blob) -> str | None:
    if blob is None:
        return None
    ref = getattr(blob, "ref", None)
    if ref is None:
        return None
    return getattr(ref, "link", None)


def collect_all_media(did: str, records) -> list[tuple[str, str]]:
    entries: list[tuple[str, str]] = []

    for rec in records:
        value = rec.value
        created_at = str(getattr(value, "created_at", ""))[:10] or "unknown"
        embed = getattr(value, "embed", None)
        if embed is None:
            continue

        py_type = getattr(embed, "py_type", "")

        if py_type == "app.bsky.embed.images":
            for img in getattr(embed, "images", []) or []:
                blob = getattr(img, "image", None)
                cid = extract_cid(blob)
                if cid:
                    url = CDN_IMAGE.format(did=did, cid=cid)
                    entries.append((url, created_at))

        elif py_type == "app.bsky.embed.video":
            thumb = getattr(embed, "thumbnail", None) or getattr(getattr(embed, "video", None), "thumbnail", None)
            if thumb:
                thumb_cid = extract_cid(thumb)
                if thumb_cid:
                    entries.append((CDN_THUMB.format(did=did, cid=thumb_cid), created_at))

        elif py_type == "app.bsky.embed.external":
            external = getattr(embed, "external", None)
            if external:
                thumb = getattr(external, "thumb", None)
                cid = extract_cid(thumb)
                if cid:
                    url = CDN_THUMB.format(did=did, cid=cid)
                    entries.append((url, created_at))

        elif py_type == "app.bsky.embed.recordWithMedia":
            media = getattr(embed, "media", None)
            if media:
                media_type = getattr(media, "py_type", "")
                if media_type == "app.bsky.embed.images":
                    for img in getattr(media, "images", []) or []:
                        blob = getattr(img, "image", None)
                        cid = extract_cid(blob)
                        if cid:
                            entries.append((CDN_IMAGE.format(did=did, cid=cid), created_at))
                elif media_type == "app.bsky.embed.video":
                    thumb = getattr(media, "thumbnail", None) or getattr(getattr(media, "video", None), "thumbnail", None)
                    if thumb:
                        thumb_cid = extract_cid(thumb)
                        if thumb_cid:
                            entries.append((CDN_THUMB.format(did=did, cid=thumb_cid), created_at))

    return entries


def to_png(raw: bytes) -> bytes:
    buf = io.BytesIO(raw)
    img = Image.open(buf)
    img.load()
    out = io.BytesIO()
    img.save(out, format="PNG")
    return out.getvalue()


async def download_one(
    sem: asyncio.Semaphore,
    http: httpx.AsyncClient,
    url: str,
    date_str: str,
    index: int,
    output_dir: Path,
) -> tuple[int, int]:
    fname = f"image_{index:04d}.png"
    fpath = output_dir / fname

    if fpath.exists() and fpath.stat().st_size > 0:
        return 0, 1

    async with sem:
        try:
            resp = await http.get(url, headers={"User-Agent": "bluesky-media-downloader/0.1"})
            resp.raise_for_status()
        except Exception as e:
            return 0, 0

        if fpath.exists() and fpath.stat().st_size > 0:
            return 0, 1

        try:
            png_data = to_png(resp.content)
        except Exception:
            png_data = resp.content

        output_dir.mkdir(parents=True, exist_ok=True)
        fpath.write_bytes(png_data)
        return 1, 0


async def download_all(entries: list[tuple[str, str]], output_dir: Path) -> tuple[int, int]:
    output_dir.mkdir(parents=True, exist_ok=True)
    sem = asyncio.Semaphore(10)
    downloaded = 0
    skipped = 0

    pbar = tqdm(total=len(entries), unit="img", desc="Downloading")

    async with httpx.AsyncClient(timeout=120.0, follow_redirects=True) as http:
        tasks = [
            download_one(sem, http, url, date_str, idx, output_dir)
            for idx, (url, date_str) in enumerate(entries, 1)
        ]
        for coro in asyncio.as_completed(tasks):
            d, s = await coro
            downloaded += d
            skipped += s
            pbar.update(1)
            pbar.set_postfix_str(f"ok={d} skip={s}")

    pbar.close()
    return downloaded, skipped


def main():
    parser = argparse.ArgumentParser(
        description="Download all media from a Bluesky user's posts"
    )
    parser.add_argument("handle", help="Bluesky handle (e.g., @user.bsky.social)")
    parser.add_argument(
        "--output", "-o", default=None,
        help="Output directory (default: ./<handle>/)",
    )
    args = parser.parse_args()

    handle = args.handle.lstrip("@")
    output_dir = Path(args.output or handle)

    client = Client()

    print(f"Resolving handle: @{handle}")
    try:
        did = get_actor_did(client, handle)
        print(f"  DID: {did}")
    except Exception as e:
        print(f"Error: Could not resolve handle — {e}", file=sys.stderr)
        sys.exit(1)

    print("Fetching all posts...")
    all_records = []
    try:
        for record in iter_all_records(client, did, "app.bsky.feed.post"):
            all_records.append(record)
        print(f"  Found {len(all_records)} posts")
    except Exception as e:
        print(f"Error fetching posts: {e}", file=sys.stderr)
        sys.exit(1)

    if not all_records:
        print("No posts found.")
        return

    print("Scanning for media...")
    entries = collect_all_media(did, all_records)
    print(f"  Found {len(entries)} media entries")

    if not entries:
        print("No media found.")
        return

    print(f"Downloading to: {output_dir.resolve()}")
    downloaded, skipped = asyncio.run(download_all(entries, output_dir))
    print(f"Done: {downloaded} downloaded, {skipped} already existed")


if __name__ == "__main__":
    main()
