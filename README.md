# Derived bootc images for image builder

This repository contains `Containerfile` for each derived image types that
are used by image builder.

## Supported image formats

* AWC EC2
* Azure
* GCE
* qcow2

## Supported bootable containers

* `quay.io/fedora/fedora-bootc` (`x86_64`, `aarch64`)

## Building Containerfiles

Use `make` to build Containerfiles from templates. Go is required in order to
build a small templating command that processes the templates. Python Jinja2
templating module must be installed:

    dnf -y install python3-jinja2

## Building container images

Push the changes into this repository, GitHub Actions will build and publish new
versions of container images. Daily rebuild is scheduled for every morning
(CET).

GitHub Actions use `ghcr.io` as a cache registry to speed up builds do base
images does not need to be pulled from `quay.io` everytime.

## Available images

Fedora (`x86_64`, `aarch64`)

* `quay.io/osbuild/fedora-bootc:43-ec2`
* `quay.io/osbuild/fedora-bootc:43-azure`
* `quay.io/osbuild/fedora-bootc:43-gce`
* `quay.io/osbuild/fedora-bootc:43-qcow2`

## TODO

* Supported OSes: Fedora N, N-1, Stream 9/10, RHEL latest (10.2/9.8 downstream only)
* Use `--from` to have less Containefiles (not too much useful at this point)
* Figure out a good comment for all Containerfile explaining to end users what to do
