"""Validate the local concept manifest and each document's metadata."""

import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parent
STATUSES = {"Exploring", "Proposed", "Validated", "Adopted"}


def local_file(relative):
    if not isinstance(relative, str) or not relative or Path(relative).is_absolute():
        raise ValueError(f"Expected a relative file path: {relative!r}")
    path = (ROOT / relative).resolve()
    if not path.is_relative_to(ROOT) or not path.is_file():
        raise ValueError(f"Missing file or path outside the library: {relative}")
    return path


def validate():
    manifest = json.loads((ROOT / "manifest.json").read_text())
    concepts = manifest.get("concepts")
    if not isinstance(concepts, list) or not concepts:
        raise ValueError("The manifest must contain a nonempty concepts list")
    seen = set()
    for relative in concepts:
        path = local_file(relative)
        if path.suffix != ".md" or path in seen:
            raise ValueError(f"Expected a unique Markdown document: {relative}")
        seen.add(path)
        lines = path.read_text().splitlines()
        if not lines or lines[0] != "---" or "---" not in lines[1:]:
            raise ValueError(f"Missing front matter: {relative}")
        metadata = {}
        for line in lines[1:lines[1:].index("---") + 1]:
            key, separator, value = line.partition(":")
            if not separator or key in metadata:
                raise ValueError(f"Invalid metadata in {relative}: {key}")
            metadata[key] = value.strip()
        for field in ("title", "summary", "category", "status"):
            if not metadata.get(field):
                raise ValueError(f"Missing {field}: {relative}")
        if metadata["status"] not in STATUSES:
            raise ValueError(f"Unknown status: {relative}")
        if "interactive" in metadata:
            interactive = local_file(metadata["interactive"])
            if interactive.suffix != ".html":
                raise ValueError(f"Expected an HTML interactive: {relative}")
    print(f"Validated {len(concepts)} concept documents")


if __name__ == "__main__":
    try:
        validate()
    except (OSError, ValueError, AttributeError) as error:
        print(f"Concept validation failed: {error}", file=sys.stderr)
        sys.exit(1)
