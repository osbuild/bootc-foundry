#!/bin/sh

REPO="placeholder.org" FROM_REF="quay.io/centos-bootc/centos-bootc:stream9" DST_REF="centos-bootc:stream9" CONTAINERFILE="el9" CONTAINERFILES_DIR=/opt/containerfiles /opt/schutzbot/build.sh
