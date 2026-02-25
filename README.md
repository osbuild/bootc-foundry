# Derived bootc images for image builder

This repository contains `Containerfile`s with necessary changes for base
containers in order to build various image types like cloud or installer.

## Building Containerfiles

Use `make` to build Containerfiles from templates.

## Building container images

Use `./build.sh` to build and push container images.

## TODO

* Supported OSes: Fedora N, N-1, Stream 9/10, RHEL latest (10.2/9.8)
* Use `--from` to have less Containefiles (not too much useful at this point)
* Figure out a good comment for all Containerfile explaining to end users what to do
* Write GHA action with caching support for container storage
* Use GHA matrix to distribute the build across many nodes
