#!/usr/bin/env python3
"""Write asc's canonical metadata files from marketing/listing/<locale>.json.

Usage: listing_to_metadata.py <version> <out-dir> [locale ...]   (defaults to every listing file)

The listing files are the single source for store copy; this only reshapes them into the layout
`asc metadata push --dir <out-dir> --version <version>` reads: app-info/<locale>.json (name,
subtitle, privacy URL) and version/<version>/<locale>.json (description, keywords, promotional
text, support URL, What's New). Apple's length limits are checked first so nothing half-valid
is ever pushed.
"""

import glob
import json
import os
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
LISTING = os.path.join(ROOT, "listing")
PRIVACY_URL = "https://mako.midgarcorp.cc/privacy/pixiepocket"
LIMITS = {"name": 30, "subtitle": 30, "keywords": 100, "promotionalText": 170, "description": 4000, "whatsNew": 4000}


def problems(locale, listing):
    found = []
    for field, limit in LIMITS.items():
        value = listing.get(field) or ""
        if not value.strip():
            found.append(f"{locale}: {field} is empty")
        elif len(value) > limit:
            found.append(f"{locale}: {field} is {len(value)} chars, max {limit}")
    if ", " in listing.get("keywords", ""):
        found.append(f"{locale}: keywords contain a space after a comma")
    return found


def main(argv):
    if len(argv) < 2:
        raise SystemExit(__doc__)
    version, out = argv[0], argv[1]
    locales = argv[2:] or sorted(os.path.splitext(os.path.basename(p))[0] for p in glob.glob(os.path.join(LISTING, "*.json")))
    listings = {locale: json.load(open(os.path.join(LISTING, f"{locale}.json"))) for locale in locales}
    errors = [problem for locale, listing in listings.items() for problem in problems(locale, listing)]
    if errors:
        raise SystemExit("\n".join(errors))
    os.makedirs(os.path.join(out, "app-info"), exist_ok=True)
    os.makedirs(os.path.join(out, "version", version), exist_ok=True)
    for locale, listing in listings.items():
        app_info = {"name": listing["name"], "subtitle": listing["subtitle"], "privacyPolicyUrl": PRIVACY_URL}
        version_fields = {key: listing[key] for key in ("description", "keywords", "promotionalText", "supportUrl", "whatsNew")}
        with open(os.path.join(out, "app-info", f"{locale}.json"), "w") as fh:
            json.dump(app_info, fh, ensure_ascii=False)
        with open(os.path.join(out, "version", version, f"{locale}.json"), "w") as fh:
            json.dump(version_fields, fh, ensure_ascii=False)
        print(f"{locale}: {listing['name']} | {listing['subtitle']}")


if __name__ == "__main__":
    main(sys.argv[1:])
