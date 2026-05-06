import os
import sys

import pytest

sys.path.insert(0, os.path.dirname(__file__))
from generate_ci import (
    ARCH_TO_DOCKER,
    build_change_rules,
    build_job,
    generate_ci_config,
    parse_copy_sources,
)


@pytest.mark.parametrize(
    "arch, expected_docker",
    [
        pytest.param("x86_64", "amd64", id="x86_64"),
        pytest.param("aarch64", "arm64", id="aarch64"),
    ],
)
def test_arch_to_docker_mapping(arch, expected_docker):
    assert ARCH_TO_DOCKER[arch] == expected_docker


def _setup_layout(root, dirs=None, files=None):
    """Create directories and empty files under root."""
    for d in dirs or []:
        (root / d).mkdir(parents=True, exist_ok=True)
    for f in files or []:
        p = root / f
        p.parent.mkdir(parents=True, exist_ok=True)
        p.touch()


@pytest.mark.parametrize(
    "case",
    [
        pytest.param(
            dict(
                lines=["COPY azure/etc/ /etc/"],
                arch="x86_64",
                layout_dirs=["azure/etc"],
                layout_files=[],
                expected_dirs=["azure/**/*"],
                expected_files=[],
            ),
            id="dir_simple",
        ),
        pytest.param(
            dict(
                lines=["COPY rhel-10-azure /root/Containerfile"],
                arch="x86_64",
                layout_dirs=[],
                layout_files=["rhel-10-azure"],
                expected_dirs=[],
                expected_files=["rhel-10-azure"],
            ),
            id="file_simple",
        ),
        pytest.param(
            dict(
                lines=["COPY config/myfile.conf /etc/myfile.conf"],
                arch="x86_64",
                layout_dirs=[],
                layout_files=["config/myfile.conf"],
                expected_dirs=[],
                expected_files=["config/myfile.conf"],
            ),
            id="file_nested",
        ),
        pytest.param(
            dict(
                lines=["COPY <<EOT /usr/lib/image-builder/bootc/iso.yaml"],
                arch="x86_64",
                layout_dirs=[],
                layout_files=[],
                expected_dirs=[],
                expected_files=[],
            ),
            id="heredoc",
        ),
        pytest.param(
            dict(
                lines=["COPY qcow2-${TARGETARCH}/usr/ /usr/"],
                arch="x86_64",
                layout_dirs=["qcow2-amd64/usr"],
                layout_files=[],
                expected_dirs=["qcow2-amd64/**/*"],
                expected_files=[],
            ),
            id="targetarch_dir",
        ),
        pytest.param(
            dict(
                lines=["COPY qcow2-${TARGETARCH}/usr/ /usr/"],
                arch="aarch64",
                layout_dirs=["qcow2-arm64/usr"],
                layout_files=[],
                expected_dirs=["qcow2-arm64/**/*"],
                expected_files=[],
            ),
            id="targetarch_dir_aarch64",
        ),
        pytest.param(
            dict(
                lines=[
                    "COPY azure/etc/ /etc/",
                    "COPY azure/usr/ /usr/",
                ],
                arch="x86_64",
                layout_dirs=["azure/etc", "azure/usr"],
                layout_files=[],
                expected_dirs=["azure/**/*"],
                expected_files=[],
            ),
            id="dedup",
        ),
        pytest.param(
            dict(
                lines=[
                    "FROM registry.redhat.io/rhel10/rhel-bootc:latest",
                    "ARG TARGETARCH",
                    "RUN dnf -y install cloud-init && dnf clean all",
                    "COPY azure/etc/ /etc/",
                    "COPY azure/usr/ /usr/",
                    "COPY azure-${TARGETARCH}/usr/ /usr/",
                    "COPY <<EOT /usr/lib/image-builder/bootc/iso.yaml",
                    "some: content",
                    "EOT",
                    "RUN systemctl enable waagent",
                    "COPY rhel-10-azure /root/Containerfile",
                ],
                arch="x86_64",
                layout_dirs=["azure/etc", "azure/usr", "azure-amd64/usr"],
                layout_files=["rhel-10-azure"],
                expected_dirs=["azure-amd64/**/*", "azure/**/*"],
                expected_files=["rhel-10-azure"],
            ),
            id="mixed",
        ),
        pytest.param(
            dict(
                lines=["COPY fileA fileB /dest/"],
                arch="x86_64",
                layout_dirs=[],
                layout_files=["fileA", "fileB"],
                expected_dirs=[],
                expected_files=["fileA", "fileB"],
            ),
            id="multi_source_files",
        ),
        pytest.param(
            dict(
                lines=["COPY dirA/ dirB/ /dest/"],
                arch="x86_64",
                layout_dirs=["dirA", "dirB"],
                layout_files=[],
                expected_dirs=["dirA/**/*", "dirB/**/*"],
                expected_files=[],
            ),
            id="multi_source_dirs",
        ),
        pytest.param(
            dict(
                lines=["COPY mydir/ myfile.conf /dest/"],
                arch="x86_64",
                layout_dirs=["mydir"],
                layout_files=["myfile.conf"],
                expected_dirs=["mydir/**/*"],
                expected_files=["myfile.conf"],
            ),
            id="multi_source_mixed",
        ),
        pytest.param(
            dict(
                lines=["COPY common/etc/ ec2-${TARGETARCH}/usr/ /dest/"],
                arch="x86_64",
                layout_dirs=["common/etc", "ec2-amd64/usr"],
                layout_files=[],
                expected_dirs=["common/**/*", "ec2-amd64/**/*"],
                expected_files=[],
            ),
            id="multi_source_with_targetarch",
        ),
    ],
)
def test_parse_copy_sources(tmp_path, case):
    _setup_layout(tmp_path, dirs=case["layout_dirs"], files=case["layout_files"])
    dirs, files = parse_copy_sources(case["lines"], case["arch"], tmp_path)
    assert dirs == case["expected_dirs"]
    assert files == case["expected_files"]


@pytest.mark.parametrize(
    "lines, arch, error_match, layout_dirs, layout_files",
    [
        pytest.param(
            ["COPY --chmod=0755 src /dest"], "x86_64", "COPY with options is not supported", [], [],
            id="options_error",
        ),
        pytest.param(
            ["COPY --from=builder /app /app"], "x86_64", "COPY with options is not supported", [], [],
            id="options_from_error",
        ),
        pytest.param(
            ["COPY ghost/etc/ /etc/"], "x86_64", "COPY source does not exist", [], [],
            id="nonexistent_dir_error",
        ),
        pytest.param(
            ["COPY nonexistent_file.txt /etc/nonexistent_file.txt"], "x86_64", "COPY source does not exist", [], [],
            id="nonexistent_file_error",
        ),
        pytest.param(
            ["COPY existA ghost /dest/"], "x86_64", "COPY source does not exist", [], ["existA"],
            id="multi_source_nonexistent",
        ),
    ],
)
def test_parse_copy_sources_errors(tmp_path, lines, arch, error_match, layout_dirs, layout_files):
    _setup_layout(tmp_path, dirs=layout_dirs, files=layout_files)
    with pytest.raises(ValueError, match=error_match):
        parse_copy_sources(lines, arch, tmp_path)


@pytest.mark.parametrize(
    "case",
    [
        pytest.param(
            dict(
                cntfile_name="stream10-qcow2",
                cntfile_lines=[
                    "COPY qcow2-${TARGETARCH}/usr/ /usr/",
                    "COPY stream10-qcow2 /root/Containerfile",
                ],
                arch="x86_64",
                payload_name=None,
                payload_lines=None,
                layout_dirs=["qcow2-amd64/usr"],
                layout_files=["stream10-qcow2"],
                expected=[
                    "Schutzfile",
                    "qcow2-amd64/**/*",
                    "stream10-qcow2",
                    "test/**/*",
                ],
            ),
            id="simple-containerfile",
        ),
        pytest.param(
            dict(
                cntfile_name="hummingbird-qcow2",
                cntfile_lines=[
                    "COPY qcow2-${TARGETARCH}/usr/ /usr/",
                    "COPY hummingbird-qcow2-${TARGETARCH}/usr/ /usr/",
                    "COPY hummingbird-qcow2 /root/Containerfile",
                ],
                arch="aarch64",
                payload_name=None,
                payload_lines=None,
                layout_dirs=["qcow2-arm64/usr", "hummingbird-qcow2-arm64/usr"],
                layout_files=["hummingbird-qcow2"],
                expected=[
                    "Schutzfile",
                    "hummingbird-qcow2",
                    "hummingbird-qcow2-arm64/**/*",
                    "qcow2-arm64/**/*",
                    "test/**/*",
                ],
            ),
            id="aarch64-multiple-dirs",
        ),
        pytest.param(
            dict(
                cntfile_name="rhel-10-azure",
                cntfile_lines=[
                    "COPY azure/etc/ /etc/",
                    "COPY azure/usr/ /usr/",
                    "COPY azure/var/ /var/",
                    "COPY azure-${TARGETARCH}/usr/ /usr/",
                    "COPY rhel-10-azure /root/Containerfile",
                ],
                arch="x86_64",
                payload_name=None,
                payload_lines=None,
                layout_dirs=["azure/etc", "azure/usr", "azure/var", "azure-amd64/usr"],
                layout_files=["rhel-10-azure"],
                expected=[
                    "Schutzfile",
                    "azure-amd64/**/*",
                    "azure/**/*",
                    "rhel-10-azure",
                    "test/**/*",
                ],
            ),
            id="dedup-common-dirs",
        ),
        pytest.param(
            dict(
                cntfile_name="rhel-10-installer",
                cntfile_lines=[
                    'COPY <<EOT /usr/lib/image-builder/bootc/iso.yaml',
                    'label: "test"',
                    "EOT",
                ],
                arch="x86_64",
                payload_name="rhel-10-qcow2",
                payload_lines=[
                    "COPY qcow2-${TARGETARCH}/usr/ /usr/",
                    "COPY rhel-10-qcow2 /root/Containerfile",
                ],
                layout_dirs=["qcow2-amd64/usr"],
                layout_files=["rhel-10-installer", "rhel-10-qcow2"],
                expected=[
                    "Schutzfile",
                    "qcow2-amd64/**/*",
                    "rhel-10-installer",
                    "rhel-10-qcow2",
                    "test/**/*",
                ],
            ),
            id="installer-with-payload",
        ),
    ],
)
def test_build_change_rules(tmp_path, case):
    _setup_layout(tmp_path, dirs=case["layout_dirs"], files=case["layout_files"])
    rules = build_change_rules(
        cntfile_name=case["cntfile_name"],
        cntfile_lines=case["cntfile_lines"],
        arch=case["arch"],
        payload_cntfile_name=case["payload_name"],
        payload_cntfile_lines=case["payload_lines"],
        repo_root=tmp_path,
    )
    assert rules == case["expected"]


@pytest.mark.parametrize(
    "case",
    [
        pytest.param(
            dict(
                cf_name="rhel-10-ec2",
                image_type="ami",
                arch="x86_64",
                runner="aws/rhel-10.1-ga",
                distro_id="rhel-10",
                change_rules=["rhel-10-ec2", "ec2-amd64/**/*", "test/**/*", "Schutzfile"],
                payload_name=None,
                subscription_needed=False,
                expected={
                    "stage": "test",
                    "extends": ".terraform",
                    "variables": {
                        "RUNNER": "aws/rhel-10.1-ga-x86_64",
                    },
                    "rules": [{"changes": ["rhel-10-ec2", "ec2-amd64/**/*", "test/**/*", "Schutzfile"]}],
                    "script": [
                        "CONTAINER_REF=$(test/get-container.sh rhel-10-ec2)",
                        'test/build.sh "$CONTAINER_REF" ami x86_64 rhel-10',
                        "test/boot.sh",
                    ],
                },
            ),
            id="simple-ec2",
        ),
        pytest.param(
            dict(
                cf_name="rhel-10-qcow2",
                image_type="qcow2",
                arch="x86_64",
                runner="rhos-01/rhel-10.1-ga",
                distro_id="rhel-10",
                change_rules=["rhel-10-qcow2", "qcow2-amd64/**/*", "test/**/*", "Schutzfile"],
                payload_name=None,
                subscription_needed=False,
                expected={
                    "stage": "test",
                    "extends": ".terraform/openstack",
                    "variables": {
                        "RUNNER": "rhos-01/rhel-10.1-ga-x86_64",
                    },
                    "rules": [{"changes": ["rhel-10-qcow2", "qcow2-amd64/**/*", "test/**/*", "Schutzfile"]}],
                    "script": [
                        "CONTAINER_REF=$(test/get-container.sh rhel-10-qcow2)",
                        'test/build.sh "$CONTAINER_REF" qcow2 x86_64 rhel-10',
                        "test/boot.sh",
                    ],
                },
            ),
            id="simple-qcow2",
        ),
        pytest.param(
            dict(
                cf_name="rhel-10-installer",
                image_type="bootc-generic-iso",
                arch="x86_64",
                runner="rhos-01/rhel-10.1-ga-{arch}-large",
                distro_id="rhel-10",
                change_rules=["rhel-10-installer", "rhel-10-qcow2", "qcow2-amd64/**/*", "test/**/*", "Schutzfile"],
                payload_name="rhel-10-qcow2",
                subscription_needed=True,
                expected={
                    "stage": "test",
                    "extends": ".terraform/openstack",
                    "variables": {
                        "RUNNER": "rhos-01/rhel-10.1-ga-x86_64-large",
                        "SUBSCRIPTION_NEEDED": True,
                    },
                    "rules": [{"changes": ["rhel-10-installer", "rhel-10-qcow2", "qcow2-amd64/**/*", "test/**/*", "Schutzfile"]}],
                    "script": [
                        "CONTAINER_REF=$(test/get-container.sh rhel-10-installer)",
                        "PAYLOAD_REF=$(test/get-container.sh rhel-10-qcow2)",
                        'test/build.sh "$CONTAINER_REF" bootc-generic-iso x86_64 rhel-10 "$PAYLOAD_REF"',
                        "test/boot.sh",
                    ],
                },
            ),
            id="installer-with-payload",
        ),
    ],
)
def test_build_job(case):
    job = build_job(
        cntfile_name=case["cf_name"],
        image_type=case["image_type"],
        arch=case["arch"],
        runner_name=case["runner"],
        distro_id=case["distro_id"],
        change_rules=case["change_rules"],
        payload_cntfile_name=case["payload_name"],
        subscription_needed=case["subscription_needed"],
    )
    assert job == case["expected"]


SINGLE_DISTRO_CONFIG = {
    "images": {
        "test-distro": {
            "runner": "aws/test-distro",
            "containerfiles": [
                {
                    "containerfile": "stream10-qcow2",
                    "image-type": "qcow2",
                    "arches": ["x86_64", "aarch64"],
                },
            ],
        },
    },
}
SINGLE_DISTRO_CF_CACHE = {
    "stream10-qcow2": [
        "COPY qcow2-${TARGETARCH}/usr/ /usr/",
        "COPY stream10-qcow2 /root/Containerfile",
    ],
}


def _setup_single_distro_layout(root):
    _setup_layout(root, dirs=["qcow2-amd64/usr", "qcow2-arm64/usr"], files=["stream10-qcow2"])


def test_generate_ci_config_top_level_keys(tmp_path):
    _setup_single_distro_layout(tmp_path)
    ci = generate_ci_config(SINGLE_DISTRO_CONFIG, SINGLE_DISTRO_CF_CACHE, tmp_path)
    assert ci["stages"] == ["init", "test", "finish"]
    assert ".base" in ci
    assert ci[".base"]["before_script"] == [
        "cat schutzbot/team_ssh_keys.txt | tee -a ~/.ssh/authorized_keys > /dev/null",
        "test/setup.sh",
    ]
    assert ci[".base"]["after_script"] == [
        "schutzbot/unregister.sh || true",
    ]
    assert ".terraform" in ci
    assert ci[".terraform"]["extends"] == ".base"
    assert ci[".terraform"]["tags"] == ["terraform"]
    assert ".terraform/openstack" in ci
    assert ci[".terraform/openstack"]["extends"] == ".base"
    assert ci[".terraform/openstack"]["tags"] == ["terraform/openstack"]


def test_generate_ci_config_generates_job_per_arch(tmp_path):
    _setup_single_distro_layout(tmp_path)
    ci = generate_ci_config(SINGLE_DISTRO_CONFIG, SINGLE_DISTRO_CF_CACHE, tmp_path)
    assert "stream10-qcow2-x86_64" in ci
    assert "stream10-qcow2-aarch64" in ci


RUNNER_OVERRIDE_CONFIG = {
    "images": {
        "test-distro": {
            "runner": "aws/default-runner",
            "containerfiles": [
                {
                    "containerfile": "stream10-qcow2",
                    "image-type": "qcow2",
                    "arches": ["x86_64"],
                },
                {
                    "containerfile": "stream10-installer",
                    "image-type": "bootc-generic-iso",
                    "payload-containerfile": "stream10-qcow2",
                    "runner": "aws/nested-virt",
                    "arches": ["x86_64"],
                },
            ],
        },
    },
}
RUNNER_OVERRIDE_CF_CACHE = {
    "stream10-qcow2": [
        "COPY qcow2-${TARGETARCH}/usr/ /usr/",
        "COPY stream10-qcow2 /root/Containerfile",
    ],
    "stream10-installer": [
        'COPY <<EOT /usr/lib/image-builder/bootc/iso.yaml',
        'label: "test"',
        "EOT",
    ],
}


def test_generate_ci_config_per_containerfile_runner(tmp_path):
    _setup_single_distro_layout(tmp_path)
    ci = generate_ci_config(RUNNER_OVERRIDE_CONFIG, RUNNER_OVERRIDE_CF_CACHE, tmp_path)
    assert ci["stream10-qcow2-x86_64"]["variables"]["RUNNER"] == "aws/default-runner-x86_64"
    assert ci["stream10-installer-x86_64"]["variables"]["RUNNER"] == "aws/nested-virt-x86_64"
