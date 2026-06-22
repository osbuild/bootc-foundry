#!/usr/bin/env python3
import json
from datetime import datetime, timezone

# Relative to repo root; must be run from the repo top-level directory.
SCHUTZFILE = "Schutzfile"


def bump_rebuild_timestamp():
    with open(SCHUTZFILE, encoding="utf-8") as f:
        data = json.load(f)

    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d%H%M")
    data["common"]["last-forced-rebuild"] = timestamp

    with open(SCHUTZFILE, encoding="utf-8", mode="w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")

    return timestamp


def main():
    timestamp = bump_rebuild_timestamp()
    print(timestamp)


if __name__ == "__main__":
    main()
