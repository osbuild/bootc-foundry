# Derived bootc images for image builder

This repository contains `Containerfile` for each derived image types that
are used by image builder.

## Supported image formats

* AWC EC2
* Azure
* GCE
* qcow2

## Supported bootable container base images

* `quay.io/fedora/fedora-bootc` versions N and N-1 (`x86_64`, `aarch64`)
* `quay.io/centos-bootc/centos-bootc` versions Stream 9 and 10 (`x86_64`, `aarch64`)

## Building Containerfiles

All Containerfiles in this repo have `FROM` verb set to `.` which will fail to
build without `--from` argument for podman or buildah. Additionally,
`CONTAINERFILE` variable must be provided:

    buildah build \
        --from quay.io/fedora/fedora-bootc:43 \
        --build-arg CONTAINERFILE="Containerfile.xxx" \
        -f "Containerfile.xxx" \
        -t my-image .

All required files are kept in [`resources/`](resources/) directory.

The Containerfile itself, alongside with all required resource files, is
embedded within in `/root` directory.

## Publishing container images

Images are available as multi-arch image manifests with the following URIs:

[Fedora](https://quay.io/repository/osbuild/fedora-bootc) (`x86_64`, `aarch64`)

* `quay.io/osbuild/fedora-bootc:43-ec2`
* `quay.io/osbuild/fedora-bootc:43-azure`
* `quay.io/osbuild/fedora-bootc:43-gce`
* `quay.io/osbuild/fedora-bootc:43-qcow2`

[CentOS 9 Stream](https://quay.io/repository/osbuild/centos-bootc) (`x86_64`, `aarch64`)

* `quay.io/osbuild/centos-bootc:stream9-ec2`
* `quay.io/osbuild/centos-bootc:stream9-azure`
* `quay.io/osbuild/centos-bootc:stream9-gce`
* `quay.io/osbuild/centos-bootc:stream9-qcow2`

[CentOS 10 Stream](https://quay.io/repository/osbuild/centos-bootc) (`x86_64`, `aarch64`)

* `quay.io/osbuild/centos-bootc:stream10-ec2`
* `quay.io/osbuild/centos-bootc:stream10-azure`
* `quay.io/osbuild/centos-bootc:stream10-gce`
* `quay.io/osbuild/centos-bootc:stream10-qcow2`

Derived images are automatically rebuilt after every push. Daily rebuild is
scheduled for every morning (CET).

## CICD

Building, manifest creation, and pushing are handled by a GitHub Action. Because
the configuration matrix is large, it is generated using the `gen-cicd.py`
script from [`config.yaml`](config.yaml).

No cross-arch build is currently done since only x86_64 and aarch64 are
supported and these are all available on GitHub.

GitHub Actions use `ghcr.io` as a cache registry to speed up builds do base
images does not need to be pulled from `quay.io` everytime.

## Using derived images

```
image-builder-cli manifest --bootc-ref quay.io/osbuild/fedora-bootc:43-ec2 --bootc-default-fs ext4 ami
image-builder-cli manifest --bootc-ref quay.io/osbuild/fedora-bootc:43-azure --bootc-default-fs ext4 vhd
image-builder-cli manifest --bootc-ref quay.io/osbuild/fedora-bootc:43-gce --bootc-default-fs ext4 gce
image-builder-cli manifest --bootc-ref quay.io/osbuild/fedora-bootc:43-qcow2 --bootc-default-fs ext4 qcow2
```

## LICENSE

Apache License 2.0

## TODO

* Document RHEL builds
* Add AWS credentials and client to login.sh
* Looks like /root/resources directory is missing (so symlinks are incorrect)
