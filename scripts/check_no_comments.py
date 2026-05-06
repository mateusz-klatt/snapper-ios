"""Scan Swift source files for non-doc comment tokens.

The project treats docstrings as the canonical place for rationale and
guidance — Python files are enforced by the parent monorepo's
``scripts/check_no_comments.py`` and Swift files are enforced here.

Allowed (doc-style):
    ``///`` — single-line documentation comment.
    ``/** ... */`` — block documentation comment.

Forbidden (non-doc):
    ``//`` — single-line comment.
    ``/* ... */`` — block comment (not a doc block).

The scanner walks each file character by character through a small
state machine (code, single-line string, multi-line triple-quoted
string, block comment). It does not aim to parse Swift fully — Swift's
grammar is rich enough that an exact parser would require SourceKit
— but the rule is enforced closely enough to keep the project's
docstring-first style without false positives in practice.

CLI flags:
    ``--strict`` — return exit code 1 when any non-doc comment is found.
    ``--root <path>`` — add a relative root to scan; pass multiple
        times to scan multiple directories. Default: ``Snapper`` and
        ``SnapperTests``.
"""

import sys
from collections.abc import Sequence
from pathlib import Path
from typing import Final

DEFAULT_RELATIVE_ROOTS: Final[tuple[str, ...]] = (
    "Snapper",
    "SnapperTests",
)
SKIP_DIRS: Final[set[str]] = {
    "build",
    "DerivedData",
    "Pods",
    ".swiftpm",
    "node_modules",
    ".git",
    "Generated",
}


def should_skip_path(path: Path) -> bool:
    """Return True when the path is in a skipped directory.

    Args:
        path: Candidate file path.

    Returns:
        True when any part of the path matches a skipped directory name.
    """
    return any(part in SKIP_DIRS for part in path.parts)


def iter_swift_files(
    root: Path,
    relative_roots: Sequence[str] = DEFAULT_RELATIVE_ROOTS,
) -> list[Path]:
    """Collect project Swift files under the configured roots.

    Args:
        root: Project root directory.
        relative_roots: Relative directories (from root) to scan.

    Returns:
        Sorted list of Swift file paths.
    """
    swift_files: list[Path] = []
    for relative_root in relative_roots:
        search_root = root / relative_root
        if not search_root.exists():
            continue
        for swift_file in search_root.rglob("*.swift"):
            if should_skip_path(swift_file):
                continue
            swift_files.append(swift_file)
    return sorted(swift_files)


class _SwiftScanContext:
    """Per-file scan state for ``find_non_doc_comments``.

    Encapsulates the offset cursor, current line number, parser state,
    and accumulated findings so the per-state advance helpers stay
    small. Direct attribute access keeps the helper API trivial; the
    class exists purely to keep cognitive complexity inside helpers
    below the project's S3776 threshold.
    """

    def __init__(self, text: str) -> None:
        self.text = text
        self.length = len(text)
        self.findings: list[tuple[int, str]] = []
        self.state = "code"
        self.block_doc = False
        self.block_open_line = 0
        self.line_no = 1
        self.cursor = 0

    def starts_with(self, token: str) -> bool:
        """Return True when ``token`` matches the slice at the cursor."""
        return self.text[self.cursor : self.cursor + len(token)] == token

    def advance(self, count: int = 1) -> None:
        """Advance the cursor by ``count`` characters."""
        self.cursor += count


def _advance_code(ctx: _SwiftScanContext) -> None:
    """Advance one code character — handles the ``code`` state.

    Dispatches on the next 1-4 characters at the cursor: string openers
    (single or triple quote), block-comment openers (``/*`` and
    ``/**``), line-comment openers (``//`` and ``///``), or any other
    character (advanced by 1). Findings are appended to
    ``ctx.findings`` for every non-doc token.
    """
    if ctx.starts_with('"""'):
        ctx.state = "tstring"
        ctx.advance(3)
        return
    if ctx.text[ctx.cursor] == '"':
        ctx.state = "string"
        ctx.advance(1)
        return
    if ctx.starts_with("/**/"):
        ctx.findings.append((ctx.line_no, "/**/"))
        ctx.advance(4)
        return
    if ctx.starts_with("/**"):
        ctx.state = "block"
        ctx.block_doc = True
        ctx.block_open_line = ctx.line_no
        ctx.advance(3)
        return
    if ctx.starts_with("/*"):
        ctx.state = "block"
        ctx.block_doc = False
        ctx.block_open_line = ctx.line_no
        ctx.advance(2)
        return
    if ctx.starts_with("///"):
        _skip_to_eol(ctx)
        return
    if ctx.starts_with("//"):
        _consume_line_comment(ctx)
        return
    ctx.advance(1)


def _skip_to_eol(ctx: _SwiftScanContext) -> None:
    """Advance past the rest of the current line (no findings)."""
    end = ctx.text.find("\n", ctx.cursor)
    ctx.cursor = end if end != -1 else ctx.length


def _consume_line_comment(ctx: _SwiftScanContext) -> None:
    """Record an offending ``//`` comment and advance past it."""
    end = ctx.text.find("\n", ctx.cursor)
    snippet = ctx.text[ctx.cursor : (end if end != -1 else ctx.length)]
    ctx.findings.append((ctx.line_no, snippet))
    ctx.cursor = end if end != -1 else ctx.length


def _advance_string(ctx: _SwiftScanContext) -> None:
    """Advance through a regular ``"..."`` string literal."""
    char = ctx.text[ctx.cursor]
    if char == "\\" and ctx.cursor + 1 < ctx.length:
        ctx.advance(2)
        return
    if char == '"':
        ctx.state = "code"
    ctx.advance(1)


def _advance_tstring(ctx: _SwiftScanContext) -> None:
    """Advance through a multi-line triple-quoted string literal."""
    if ctx.text[ctx.cursor] == "\\" and ctx.cursor + 1 < ctx.length:
        ctx.advance(2)
        return
    if ctx.starts_with('"""'):
        ctx.state = "code"
        ctx.advance(3)
        return
    ctx.advance(1)


def _advance_block(ctx: _SwiftScanContext) -> None:
    """Advance through a ``/* ... */`` block comment.

    Records an offending finding when the closing ``*/`` is reached
    and the block was opened with ``/*`` (not the doc form ``/**``).
    """
    if ctx.starts_with("*/"):
        if not ctx.block_doc:
            ctx.findings.append((ctx.block_open_line, "/* ... */ block comment"))
        ctx.state = "code"
        ctx.block_doc = False
        ctx.advance(2)
        return
    ctx.advance(1)


def find_non_doc_comments(filepath: Path) -> list[tuple[int, str]]:
    """Return offending comment tokens found in a Swift source file.

    Args:
        filepath: Path to the Swift file.

    Returns:
        A list of (line_number, comment_text) tuples for offending lines.
    """
    try:
        text = filepath.read_text(encoding="utf-8")
    except OSError:
        return []

    ctx = _SwiftScanContext(text)
    advance_handlers = {
        "code": _advance_code,
        "string": _advance_string,
        "tstring": _advance_tstring,
        "block": _advance_block,
    }

    while ctx.cursor < ctx.length:
        if ctx.text[ctx.cursor] == "\n":
            ctx.line_no += 1
            ctx.advance(1)
            continue
        advance_handlers[ctx.state](ctx)

    if ctx.state == "block" and not ctx.block_doc:
        ctx.findings.append((ctx.block_open_line, "/* ... unterminated block comment"))

    return ctx.findings


def scan_swift_files(
    root: Path,
    relative_roots: Sequence[str] = DEFAULT_RELATIVE_ROOTS,
) -> dict[Path, list[tuple[int, str]]]:
    """Scan project Swift files for non-doc comment tokens.

    Args:
        root: Project root directory.
        relative_roots: Relative directories (from root) to scan.

    Returns:
        Mapping of file paths to comment findings.
    """
    results: dict[Path, list[tuple[int, str]]] = {}
    for swift_file in iter_swift_files(root, relative_roots):
        findings = find_non_doc_comments(swift_file)
        if findings:
            results[swift_file] = findings
    return results


def print_results(
    results: dict[Path, list[tuple[int, str]]],
    root: Path,
) -> int:
    """Print scan results and return total count of findings.

    Args:
        results: Dictionary mapping file paths to their findings.
        root: Root directory for computing relative paths.

    Returns:
        Total count of comment findings.
    """
    if not results:
        print("  No Swift comments found")
        return 0
    total = 0
    for filepath, findings in sorted(results.items()):
        rel_path = filepath.relative_to(root)
        print(f"\n  {rel_path}")
        for line_num, comment_text in findings:
            display_comment = comment_text[:80] + "..." if len(comment_text) > 80 else comment_text
            print(f"     L{line_num}: {display_comment}")
            total += 1
    return total


def run_scan(
    root: Path,
    strict_mode: bool = False,
    relative_roots: Sequence[str] = DEFAULT_RELATIVE_ROOTS,
) -> int:
    """Run the no-comment scan and return exit code.

    Args:
        root: Root directory of the project to scan.
        strict_mode: If True, return exit code 1 when comments are found.
        relative_roots: Relative directories (from root) to scan.

    Returns:
        Exit code (0 for success, 1 for failure in strict mode with findings).
    """
    print("=" * 70)
    print("Swift Comment Scanner")
    print("=" * 70)
    print(f"\nScanning: {root}")
    mode_label = "STRICT (will fail on findings)" if strict_mode else "Report only"
    print(f"Mode: {mode_label}")
    print(f"Relative roots: {', '.join(relative_roots)}")
    results = scan_swift_files(root, relative_roots)
    print("\n" + "-" * 70)
    print("SWIFT FILES (.swift)")
    print("-" * 70)
    total = print_results(results, root)
    print("\n" + "=" * 70)
    print("SUMMARY")
    print("=" * 70)
    print(f"\n  Swift non-doc comments: {total}")
    if total > 0:
        print(
            "\nFound non-doc comments. Move rationale and guidance into doc "
            "comments (`///` for line, `/** ... */` for block) or remove them."
        )
        if strict_mode:
            print("\nSTRICT MODE: Failing due to comments found.")
            return 1
    else:
        print("\nNo Swift non-doc comments found. Clean docstring-first codebase!")
    return 0


def parse_arguments(argv: Sequence[str]) -> tuple[bool, list[str]]:
    """Parse CLI arguments into a strict flag and override-root list.

    Args:
        argv: Argument vector (without the program name).

    Returns:
        Tuple of (strict_mode, list of override roots — empty when none given).
    """
    strict_mode = False
    overrides: list[str] = []
    iterator = iter(argv)
    for arg in iterator:
        if arg == "--strict":
            strict_mode = True
            continue
        if arg == "--root":
            try:
                overrides.append(next(iterator))
            except StopIteration:
                break
            continue
        if arg.startswith("--root="):
            overrides.append(arg.split("=", 1)[1])
    return strict_mode, overrides


def main() -> int:
    """Entry point for check_no_comments script.

    Returns:
        Exit code from the scan operation.
    """
    strict_mode, overrides = parse_arguments(sys.argv[1:])
    script_dir = Path(__file__).parent
    root = script_dir.parent
    relative_roots = tuple(overrides) if overrides else DEFAULT_RELATIVE_ROOTS
    return run_scan(root, strict_mode, relative_roots)


if __name__ == "__main__":
    raise SystemExit(main())
