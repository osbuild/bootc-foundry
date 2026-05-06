#!/usr/bin/env python3
"""Generate .gitlab-ci.yml from test/config.yml and Containerfile COPY directives."""

import re
from pathlib import Path

ARCH_TO_DOCKER = {
    "x86_64": "amd64",
    "aarch64": "arm64",
}

COPY_RE = re.compile(r"^COPY\s+(\S+(?:\s+\S+)+)")


def parse_copy_sources(lines, arch, repo_root):
    """Parse COPY directives and return (sorted_dir_globs, sorted_files).

    Extracts COPY sources from Containerfile lines, substitutes ${TARGETARCH}
    with the Docker arch name, and validates each source against the filesystem
    rooted at repo_root.

    Returns a tuple of two sorted lists:
      - directory globs: '<top_dir>/**/*' patterns for directory sources
      - files: paths for plain file sources

    Raises ValueError for COPY with options or sources that don't exist on disk.
    """
    docker_arch = ARCH_TO_DOCKER[arch]
    dirs = set()
    files = set()
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("COPY <<"):
            continue
        if stripped.startswith("COPY --"):
            raise ValueError(f"COPY with options is not supported: {stripped}")
        m = COPY_RE.match(stripped)
        if not m:
            continue
        tokens = m.group(1).split()
        sources = tokens[:-1]
        for src in sources:
            src_substituted = src.replace("${TARGETARCH}", docker_arch)
            resolved = repo_root / src_substituted
            if resolved.is_dir():
                top_dir = Path(src_substituted).parts[0]
                dirs.add(top_dir)
            elif resolved.is_file():
                files.add(src_substituted)
            else:
                raise ValueError(
                    f"COPY source does not exist: {src} (resolved to {resolved})"
                )
    return sorted(f"{d}/**/*" for d in dirs), sorted(files)
