#!/usr/bin/env python3
"""Generate a localization coverage report for all 16 locale files."""

import json
from pathlib import Path

LOCALES_DIR = Path(__file__).resolve().parent.parent / "BlueskyModeration" / "Sources" / "Shared" / "Localizations"

LOCALE_NAMES = {
    "en": "English", "de": "German", "fr": "French", "it": "Italian",
    "ja": "Japanese", "zh": "Chinese", "es": "Spanish", "pt": "Portuguese",
    "ko": "Korean", "ru": "Russian", "ar": "Arabic", "nl": "Dutch",
    "pl": "Polish", "tr": "Turkish", "th": "Thai", "vi": "Vietnamese",
}

def load_flat(path):
    """Load JSON and return flat dict."""
    with open(path, encoding="utf-8") as f:
        return json.load(f)

def is_english_placeholder(val):
    """Heuristic: a string is an untranslated English placeholder if >50% ASCII letters."""
    if not val:
        return False
    letters = [c for c in val if c.isalpha()]
    if not letters:
        return False
    ascii_letters = sum(1 for c in letters if c.isascii())
    return ascii_letters / len(letters) > 0.5

def main():
    locale_paths = sorted(LOCALES_DIR.glob("*.json"))
    if not locale_paths:
        print("No locale files found.")
        return

    locales = {}
    for p in locale_paths:
        code = p.stem
        locales[code] = load_flat(p)

    all_keys = sorted({k for loc in locales.values() for k in loc})
    locale_codes = sorted(locales.keys())
    total = len(all_keys)
    col_w = max(len(c) for c in locale_codes) + 2

    # ── Summary ──
    print("=" * 72)
    print("  Localization Coverage Report")
    print(f"  Locales: {len(locale_codes)}  |  Total keys: {total}")
    print("=" * 72)
    print()

    # ── Per-locale stats ──
    print(f"{'Locale':<12} {'Keys':>6} {'Missing':>8} {'Placehldr':>10} {'Coverage':>9}")
    print("-" * 48)
    for code in locale_codes:
        data = locales[code]
        n = len(data)
        missing = total - n
        placeholders = sum(1 for v in data.values() if is_english_placeholder(v))
        coverage = n / total * 100
        name = LOCALE_NAMES.get(code, code)
        print(f"{name:<12} {n:>6} {missing:>8} {placeholders:>10} {coverage:>7.1f}%")
    print()

    # ── Missing keys per locale ──
    missing_count = sum(1 for code in locale_codes if len(locales[code]) < total)
    if missing_count:
        print(f"Keys missing from at least one locale: {missing_count} locales affected")
        print()
        for code in locale_codes:
            data = locales[code]
            missing_keys = [k for k in all_keys if k not in data]
            if missing_keys:
                name = LOCALE_NAMES.get(code, code)
                print(f"  [{name}] {len(missing_keys)} missing:")
                for k in missing_keys:
                    print(f"    - {k}")
                print()

    # ── English placeholders (untranslated) ──
    placeholder_count = sum(
        1 for code in locale_codes for v in locales[code].values() if is_english_placeholder(v)
    )
    if placeholder_count:
        print(f"Potential English placeholders: {placeholder_count}")
        print()
        for code in locale_codes:
            data = locales[code]
            bad = [(k, v) for k, v in data.items() if is_english_placeholder(v)]
            if bad:
                name = LOCALE_NAMES.get(code, code)
                print(f"  [{name}] {len(bad)} placeholder(s):")
                for k, v in bad:
                    print(f"    - {k}: \"{v}\"")
                print()

    # ── Key coverage matrix ──
    print("Key coverage matrix (●=present  ○=missing  P=placeholder):")
    print()
    header = f"{'Key':<48}" + "".join(f"{c:>{max(len(c)+1, 5)}}" for c in locale_codes)
    print(header)
    print("-" * len(header))
    for k in all_keys:
        row = f"{k:<48}"
        for code in locale_codes:
            data = locales[code]
            if k not in data:
                row += f"{'○':>{max(len(code)+1, 5)}}"
            elif is_english_placeholder(data[k]):
                row += f"{'P':>{max(len(code)+1, 5)}}"
            else:
                row += f"{'●':>{max(len(code)+1, 5)}}"
        print(row)

    print()
    print("=" * 72)
    print(f"  Total keys: {total}  |  Locales: {len(locale_codes)}")

if __name__ == "__main__":
    main()
