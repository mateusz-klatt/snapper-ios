"""Merge attachments from multiple xcresult bundles into the screenshots tree.

Usage:
    python3 merge-screenshot-xcresults.py <output-dir> <xcresult-1> [<xcresult-2> ...]

Each xcresult typically contains ``locale-<country>__<screen>_<uuid>.png``
attachments. This script:

1. Exports all attachments from each xcresult.
2. Groups by (country, screen) and picks the freshest source.
3. Places into ``<output-dir>/<country>/<screen>.png``.

Unlike ``rename-screenshots.py``, this script never wipes a country
directory mid-run, so partial repeat runs don't regress prior complete
captures.
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


def export_one(xcresult: Path, scratch_root: Path, idx: int) -> Path:
    scratch = scratch_root / f"src-{idx}"
    if scratch.exists():
        shutil.rmtree(scratch)
    scratch.mkdir(parents=True)
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
    return scratch


def parse(manifest: Path):
    with manifest.open() as fp:
        data = json.load(fp)
    for run in data:
        for att in run.get("attachments", []):
            yield att


def derive_target(name: str):
    match = ATTACHMENT_RE.match(name)
    if not match:
        return None
    country = match.group("country")
    screen = SCREEN_PREFIX_RE.sub("", match.group("screen"))
    return country, screen


def main() -> int:
    if len(sys.argv) < 3:
        print("usage: merge-screenshot-xcresults.py <output-dir> <xcresult-1> [<xcresult-2> ...]", file=sys.stderr)
        return 2

    out_root = Path(sys.argv[1]).resolve()
    xcresults = [Path(p).resolve() for p in sys.argv[2:]]

    for x in xcresults:
        if not x.is_dir():
            print(f"error: not a directory: {x}", file=sys.stderr)
            return 1

    scratch_root = out_root.parent / ".xcresult-scratch"
    if scratch_root.exists():
        shutil.rmtree(scratch_root)
    scratch_root.mkdir(parents=True)

    out_root.mkdir(parents=True, exist_ok=True)

    placements: dict[tuple[str, str], Path] = {}
    skipped: list[str] = []

    for idx, xc in enumerate(xcresults):
        print(f"==> Exporting {xc.name} ({idx + 1}/{len(xcresults)})")
        scratch = export_one(xc, scratch_root, idx)
        manifest = scratch / "manifest.json"
        if not manifest.exists():
            print(f"  warning: no manifest for {xc}", file=sys.stderr)
            continue
        for entry in parse(manifest):
            exported = entry["exportedFileName"]
            suggested = entry.get("suggestedHumanReadableName", exported)
            target = derive_target(suggested)
            if not target:
                skipped.append(suggested)
                continue
            country, screen = target
            src = scratch / exported
            # Later xcresults override earlier (assume later = freshest run).
            # But if a later run only has partial data, this preserves any
            # screen that the earlier had. We do not clear by country.
            placements[(country, screen)] = src

    print()
    countries: dict[str, list[str]] = {}
    for (country, screen), src in placements.items():
        dest_dir = out_root / country
        dest_dir.mkdir(parents=True, exist_ok=True)
        dest = dest_dir / f"{screen}.png"
        shutil.copy(src, dest)
        countries.setdefault(country, []).append(screen)

    print(f"placed {sum(len(v) for v in countries.values())} PNGs across {len(countries)} countries")
    for country in sorted(countries):
        screens = sorted(countries[country])
        print(f"  {country}: {len(screens)} screens ({', '.join(screens)})")

    if skipped:
        print(f"\nskipped {len(skipped)} non-locale attachments")

    shutil.rmtree(scratch_root)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
