#!/usr/bin/env python3
"""Generate .gitlab-ci.yml from test/config.yml and Containerfile COPY directives."""

import re
import sys
import yaml
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


def build_change_rules(cntfile_name, cntfile_lines, arch, payload_cntfile_name, payload_cntfile_lines, repo_root):
    """Build the list of paths for CI change detection rules."""
    sources = {cntfile_name, "test/**/*", "Schutzfile"}
    if payload_cntfile_name:
        sources.add(payload_cntfile_name)

    all_lines = list(cntfile_lines)
    if payload_cntfile_lines:
        all_lines.extend(payload_cntfile_lines)

    copy_dirs, copy_files = parse_copy_sources(all_lines, arch, repo_root)
    sources.update(copy_dirs)
    sources.update(copy_files)

    rules = sorted(sources)
    return rules


def build_job(cntfile_name, image_type, arch, runner_name, distro_id, change_rules, payload_cntfile_name, subscription_needed):
    """Build a single CI job dictionary."""
    if "{arch}" in runner_name:
        runner = runner_name.format(arch=arch)
    else:
        runner = f"{runner_name}-{arch}"
    script = [f"CONTAINER_REF=$(test/get-container.sh {cntfile_name})"]

    if payload_cntfile_name:
        script.append(f"PAYLOAD_REF=$(test/get-container.sh {payload_cntfile_name})")

    build_cmd = f'test/build.sh "$CONTAINER_REF" {image_type} {arch} {distro_id}'
    if payload_cntfile_name:
        build_cmd += ' "$PAYLOAD_REF"'
    script.append(build_cmd)

    script.append("test/boot.sh")

    extends = ".terraform"
    if runner_name.startswith("rhos-01/"):
        extends = ".terraform/openstack"

    variables = {
        "RUNNER": runner,
    }

    if subscription_needed:
        variables["SUBSCRIPTION_NEEDED"] = True

    return {
        "stage": "test",
        "extends": extends,
        "variables": variables,
        "rules": [{"changes": change_rules}],
        "script": script,
    }


def generate_ci_config(config, cntfile_cache, repo_root):
    """Generate the full CI config dictionary from test config and Containerfile contents.

    cntfile_cache: dict mapping containerfile names to their lines
    (used instead of reading files, so tests can provide synthetic content).
    """
    ci = {
        "stages": ["init", "test", "finish"],
        "init": {
            "stage": "init",
            "interruptible": True,
            "tags": ["shell"],
            "script": [
                "schutzbot/update_github_status.sh start",
            ]
        },
        "finish": {
            "stage": "finish",
            "tags": ["shell"],
            "script": [
                "schutzbot/update_github_status.sh finish",
            ]
        },
        "fail": {
            "stage": "finish",
            "tags": ["shell"],
            "script": [
                "schutzbot/update_github_status.sh fail",
                "exit 1",
            ],
            "when": "on_failure"
        },
        ".base": {
            "interruptible": True,
            "variables": {
                "PYTHONUNBUFFERED": "1",
            },
            "before_script": [
                "cat schutzbot/team_ssh_keys.txt | tee -a ~/.ssh/authorized_keys > /dev/null",
                "test/setup.sh",
            ],
            "after_script": [
                "schutzbot/unregister.sh || true",
            ],
        },
        ".terraform": {
            "extends": ".base",
            "tags": ["terraform"],
        },
        ".terraform/openstack": {
            "extends": ".base",
            "tags": ["terraform/openstack"],
        },
    }

    for distro_id, distro_info in config["images"].items():
        distro_runner = distro_info["runner"]
        for entry in distro_info["containerfiles"]:
            cf_name = entry["containerfile"]
            image_type = entry["image-type"]
            payload_cf_name = entry.get("payload-containerfile")
            runner = entry.get("runner", distro_runner)

            cf_lines = cntfile_cache[cf_name]
            payload_cf_lines = None
            if payload_cf_name:
                payload_cf_lines = cntfile_cache[payload_cf_name]

            for arch in entry["arches"]:
                change_rules = build_change_rules(
                    cntfile_name=cf_name,
                    cntfile_lines=cf_lines,
                    arch=arch,
                    payload_cntfile_name=payload_cf_name,
                    payload_cntfile_lines=payload_cf_lines,
                    repo_root=repo_root,
                )
                job = build_job(
                    cntfile_name=cf_name,
                    image_type=image_type,
                    arch=arch,
                    runner_name=runner,
                    distro_id=distro_id,
                    change_rules=change_rules,
                    payload_cntfile_name=payload_cf_name,
                    subscription_needed=distro_info.get("subscription-needed", False),
                )
                job_name = f"{cf_name}-{arch}"
                ci[job_name] = job

    return ci


def main():
    repo_root = Path(__file__).resolve().parent.parent

    config_path = repo_root / "test" / "config.yml"
    with open(config_path) as f:
        config = yaml.safe_load(f)

    containerfile_cache = {}
    for distro_info in config["images"].values():
        for entry in distro_info["containerfiles"]:
            cf_name = entry["containerfile"]
            if cf_name not in containerfile_cache:
                containerfile_cache[cf_name] = (repo_root / cf_name).read_text().splitlines()
            payload = entry.get("payload-containerfile")
            if payload and payload not in containerfile_cache:
                containerfile_cache[payload] = (repo_root / payload).read_text().splitlines()

    ci = generate_ci_config(config, containerfile_cache, repo_root)

    class IndentedListDumper(yaml.Dumper):
        def increase_indent(self, flow=False, indentless=False):
            return super().increase_indent(flow, False)

    output = yaml.dump(ci, default_flow_style=False, sort_keys=False, Dumper=IndentedListDumper, indent=2)
    output = re.sub(r"\n(?=\S)", "\n\n", output)
    sys.stdout.write(output)


if __name__ == "__main__":
    main()
