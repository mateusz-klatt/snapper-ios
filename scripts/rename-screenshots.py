"""Extract attachments from an xcresult bundle and lay them out per country.

Usage:
    python3 rename-screenshots.py <xcresult-path> <output-dir>

The XCUITest harness names attachments
``locale-<country>__<screen-tag>_<uuid>.png`` (e.g. ``locale-ae__03-home_0_…``).
This script:

1. Calls ``xcrun xcresulttool export attachments`` to dump every PNG to a
   temp directory along with a ``manifest.json``.
2. Parses the manifest, derives ``<country>`` and ``<screen>`` from each
   attachment's ``suggestedHumanReadableName``, drops the numeric prefix
   (``03-home`` -> ``home``), and copies the PNG to
   ``<output-dir>/<country>/<screen>.png``.
3. Overwrites only attachment paths present in the current result bundle.
   Other capture modes may share the same country directory, so the
   extractor never removes the directory wholesale.
"""
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path


ATTACHMENT_RE = re.compile(
    r"^locale-(?P<country>[A-Za-z0-9-]+)__"
    r"(?P<screen>[A-Za-z0-9-]+)"
    r"(?:_\d+)?"
    r"(?:_[A-F0-9-]{36})?"
    r"\.png$"
)

SCREEN_PREFIX_RE = re.compile(r"^\d+-")


def export_attachments(xcresult: Path, scratch: Path) -> Path:
    scratch.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            "xcrun",
            "xcresulttool",
            "export",
            "attachments",
            "--path",
            str(xcresult),
            "--output-path",
            str(scratch),
        ],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.STDOUT,
    )
    return scratch / "manifest.json"


def parse_manifest(manifest_path: Path) -> list[dict]:
    with manifest_path.open() as fp:
        data = json.load(fp)
    entries: list[dict] = []
    for run in data:
        for att in run.get("attachments", []):
            entries.append(att)
    return entries


def derive_target(name: str) -> tuple[str, str] | None:
    """Return ``(country, screen)`` for a recognised attachment name."""
    match = ATTACHMENT_RE.match(name)
    if not match:
        return None
    country = match.group("country")
    screen = SCREEN_PREFIX_RE.sub("", match.group("screen"))
    return country, screen


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: rename-screenshots.py <xcresult-path> <output-dir>", file=sys.stderr)
        return 2

    xcresult = Path(sys.argv[1]).resolve()
    out_root = Path(sys.argv[2]).resolve()

    if not xcresult.is_dir():
        print(f"error: xcresult not found at {xcresult}", file=sys.stderr)
        return 1

    scratch = xcresult.parent / "xcresult-attachments"
    if scratch.exists():
        shutil.rmtree(scratch)

    manifest_path = export_attachments(xcresult, scratch)
    entries = parse_manifest(manifest_path)
    if not entries:
        print("warning: no attachments in xcresult manifest", file=sys.stderr)

    countries_seen: set[str] = set()
    placed = 0
    skipped: list[str] = []

    out_root.mkdir(parents=True, exist_ok=True)
    for entry in entries:
        exported_name = entry["exportedFileName"]
        suggested = entry.get("suggestedHumanReadableName", exported_name)
        target = derive_target(suggested)
        if not target:
            skipped.append(suggested)
            continue
        country, screen = target
        countries_seen.add(country)
        country_dir = out_root / country
        country_dir.mkdir(parents=True, exist_ok=True)
        src = scratch / exported_name
        dest = country_dir / f"{screen}.png"
        shutil.copy(src, dest)
        placed += 1

    print(f"  placed {placed} PNGs across {len(countries_seen)} countries: {sorted(countries_seen)}")
    if skipped:
        print(f"  skipped {len(skipped)} non-locale attachments")

    shutil.rmtree(scratch)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
