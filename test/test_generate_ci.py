import os
import sys

import pytest

sys.path.insert(0, os.path.dirname(__file__))
from generate_ci import ARCH_TO_DOCKER, parse_copy_sources


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
