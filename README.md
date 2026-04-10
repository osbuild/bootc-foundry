# Derived bootc images for image builder

This repository contains a `Containerfile` for each derived image type used by
image builder. The goal is to customize base bootc images of Fedora, CentOS
Stream, or RHEL for the target environment (clouds, virtualization) by
installing the tools needed for a successful installation or to align with Red
Hat or cloud vendor recommendations.

It mirrors what is defined for package-based OS images in distro definitions:
https://github.com/osbuild/images/tree/main/data/distrodefs, but there is no
parity. The core image content comes from the base container, we just add
additional software and configuration to make the image integrate nicely with
the target environment.

## Supported image formats

_This is a work in progress, not all image formats are available._

* AWS EC2
* Azure
* GCE
* qcow2
* Anaconda installer

## Supported bootable container base images

* `quay.io/fedora/fedora-bootc` versions N and N-1 (`x86_64`, `aarch64`)
* `quay.io/centos-bootc/centos-bootc` versions Stream 9 and 10 (`x86_64`, `aarch64`)
* `registry.redhat.io/rhelXX/rhel-bootc` (9 and 10) (`x86_64`)

## Organization

Each `Containerfile` is prefixed with `f` for Fedora, `stream` for CentOS
Stream, and `rhel` for RHEL containers, and suffixed with one of: `qcow2`,
`ec2`, `azure`, `gce`, or `installer`.

Heredocs are not allowed in `Containerfile`s; files must be copied with `COPY`
either from a common directory for the image type (for example `qcow2`) or from
an OS version or architecture-specific tree (`qcow2-amd64`). Architecture
names follow podman/docker conventions.

Comments explaining *why* are welcome.

## Build pipeline

Images are built in Konflux and published on `quay.io`. Repositories with RHEL
containers are private. Currently available images:

* `quay.io/redhat-services-prod/insights-management-tenant/image-builder-bootc-foundry/rhel-10.1-qcow2:latest`

## License

Apache License 2.0
