# Derived bootc images for image builder

This repository contains `Containerfile` for each derived image types that
are used by image builder.

## Supported image formats

* AWC EC2
* Azure
* GCE
* qcow2

## Supported bootable containers

* `quay.io/fedora/fedora-bootc` (x86_64, aarch64)

## Building Containerfiles

Use `make` to build Containerfiles from templates. Go is required in order to
build a small templating command that processes the templates.

## Building container images

Push the changes into this repository, GitHub Actions will build and publish new
versions of container images. Daily rebuild is scheduled for every morning
(CET).

* Fedora 43: [![Fedora](https://quay.io/repository/osbuild/fedora-bootc/status "Fedora")](https://quay.io/repository/osbuild/fedora-bootc)

## TODO

* Supported OSes: Fedora N, N-1, Stream 9/10, RHEL latest (10.2/9.8 downstream only)
* Use `--from` to have less Containefiles (not too much useful at this point)
* Figure out a good comment for all Containerfile explaining to end users what to do
