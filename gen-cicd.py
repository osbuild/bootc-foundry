#!/usr/bin/env python3
"""
Generate GitHub Actions matrix JSON from config.yaml.

Reads config with root key "images" (list of OS/image configs), each with
from_image, from_tag, to_image, to_tag_prefix, arches, types. Writes
build-matrix.json and manifest-matrix.json for use in workflows via fromJSON().

Usage:
  python gen-cicd.py [--config CONFIG] [--out-dir DIR]
"""

import argparse
import json
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("PyYAML required: pip install pyyaml", file=sys.stderr)
    sys.exit(1)


def load_config(path: Path) -> dict:
    with open(path) as f:
        return yaml.safe_load(f)


def build_matrices(config: dict) -> tuple[list, list]:
    build_include = []
    manifest_include = []

    for img in config["images"]:
        img_id = img["id"]
        from_image = img["from_image"]
        from_tag = str(img["from_tag"])
        to_image = img["to_image"]
        to_tag_prefix = str(img["to_tag_prefix"])
        arches = img["arches"]
        types = img["types"]

        for t in types:
            containerfile = f"{img_id}-{t}"
            to_tag = f"{to_tag_prefix}-{t}"
            for arch in arches:
                build_include.append({
                    "containerfile": containerfile,
                    "to_tag": to_tag,
                    "arch": arch,
                    "to_image": to_image,
                    "from_image": from_image,
                    "from_tag": from_tag,
                })

        arches_str = " ".join(arches)
        for t in types:
            tag = f"{to_tag_prefix}-{t}"
            manifest_include.append({
                "image": to_image,
                "arches": arches_str,
                "tag": tag,
            })

    return build_include, manifest_include


def main() -> None:
    root = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description="Generate workflow matrices from config.yaml")
    parser.add_argument(
        "--config",
        type=Path,
        default=root / "config.yaml",
        help="Path to config YAML",
    )
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=root / ".github" / "matrices",
        help="Directory to write matrix JSON files",
    )
    args = parser.parse_args()

    config = load_config(args.config)
    if "images" not in config:
        print("Config must have root key 'images' (list).", file=sys.stderr)
        sys.exit(1)

    build_include, manifest_include = build_matrices(config)

    args.out_dir.mkdir(parents=True, exist_ok=True)

    build_path = args.out_dir / "build-matrix.json"
    manifest_path = args.out_dir / "manifest-matrix.json"

    with open(build_path, "w") as f:
        json.dump({"include": build_include}, f, indent=2)

    with open(manifest_path, "w") as f:
        json.dump({"include": manifest_include}, f, indent=2)

    print(f"Wrote {build_path} ({len(build_include)} entries)")
    print(f"Wrote {manifest_path} ({len(manifest_include)} entries)")


if __name__ == "__main__":
    main()
