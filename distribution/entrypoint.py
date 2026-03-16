#!/usr/bin/python3

import argparse
import os
import subprocess
import sys

# hardcoded build matrix for now
BUILD_MATRIX = {
    "centos-9": {
        "from": "quay.io/centos-bootc/centos-bootc:stream9",
        "dst": "centos-bootc:stream9",
        "containerfile": "el9",
    },
    "centos-10": {
        "from": "quay.io/centos-bootc/centos-bootc:stream10",
        "dst": "centos-bootc:stream10",
        "containerfile": "el10",
    },
    "rhel-9.7": {
        "from": "registry.redhat.io/rhel9/rhel-bootc:9.7",
        "from_creds": os.getenv("RH_CREDS"),
        "dst": "rhel-bootc:9.7",
        "containerfile": "el9",
    },
    "rhel-10.1": {
        "from": "registry.redhat.io/rhel10/rhel-bootc:10.1",
        "from_creds": os.getenv("RH_CREDS"),
        "dst": "rhel-bootc:10.1",
        "containerfile": "el10",
    },
}


def run_one(build, repo):
    env = os.environ.copy()
    env["FROM_REF"] = build["from"]
    env["DST_REF"] = f"{repo}/{build['dst']}"
    env["CONTAINERFILE"] = build["containerfile"]
    if build.get("from_creds"):
        env["FROM_CREDS"] = build["from_creds"]

    print(f"""
Running /schutzbot/build.sh with:
    FROM_REF: {env['FROM_REF']}
    DST_REF: {env['DST_REF']}
    CONTAINERFILE: {env['CONTAINERFILE']}
    FROM_CREDS present: {'yes' if 'FROM_CREDS' in env else 'no'}""")

    subprocess.run([
        "/schutzbot/build.sh",
    ], env=env, shell=True, stderr=subprocess.STDOUT, check=True)


def main():
    parser = argparse.ArgumentParser(
        prog="bootc-foundry container entrypoint",
        description="Build bootc containers inside container",
    )
    parser.add_argument(
        "--repo",
        dest="repo",
        type=str,
        required=True,
        help="repository to push derived containers to",
    )
    parser.add_argument(
        "--distro",
        help="only build specified distros",
        required=False,
        type=str,
        default=[],
        action="append",
    )
    args = parser.parse_args(sys.argv[1:])

    for distro, build in BUILD_MATRIX.items():
        if args.distro and distro not in args.distro:
            continue
        run_one(build, args.repo)

    return 0


if __name__ == "__main__":
    sys.exit(main())
