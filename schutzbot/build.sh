#!/usr/bin/env bash
#
# Builds and creates multi-arch manifest; optionally pushes. Required variables:
#
# FROM_REF - base ref (e.g. quay.io/fedora/fedora-bootc:43)
# DST_REF - destination ref image without image type suffix (e.g. quay.io/osbuild/fedora-bootc:43)
# CONTAINERFILE - containerfile suffix without type (e.g. fedora → Containerfile.fedora-xxx)
#
# Optional variables:
#
# ARCHES - space-separated list of architectures to cross-build
# TYPES - space-separated list of image types to build
# FROM_CREDS - colon-separated username:password for source registry (empty for public registries)
# DST_CREDS - colon-separated username:password for destination registry (empty for no push)
# CACHE_REF - sidecar cache registry
# CACHE_CREDS - colon-separated username:password for cache registry (required if CACHE_REF is set)

set -euo pipefail

. "$(dirname "$0")/gitlab-utils.sh"

CONTAINERFILES_DIR=${CONTAINERFILES_DIR:-containerfiles}

if [ -n "${FROM_CREDS:-}" ] && [[ "${FROM_CREDS}" == *:* ]]; then
    FROM_USER="${FROM_CREDS%%:*}"
    FROM_PASS="${FROM_CREDS#*:}"
    section_start login_from_registry "Logging in to $FROM_REF"
    TO_REGISTRY=$(echo "$FROM_REF" | cut -d/ -f1)
    echo "$FROM_PASS" | buildah login -u "$FROM_USER" --password-stdin "$TO_REGISTRY"
    section_end login_from_registry
fi

if [ -n "${DST_CREDS:-}" ] && [[ "${DST_CREDS}" == *:* ]]; then
    DST_USER="${DST_CREDS%%:*}"
    DST_PASS="${DST_CREDS#*:}"
    section_start login_dst_registry "Logging in to $DST_REF"
    TO_REGISTRY=$(echo "$DST_REF" | cut -d/ -f1)
    echo "$DST_PASS" | buildah login -u "$DST_USER" --password-stdin "$TO_REGISTRY"
    section_end login_dst_registry
fi

if [ -n "${CACHE_REF:-}" ] && [ -n "${CACHE_CREDS:-}" ] && [[ "${CACHE_CREDS}" == *:* ]]; then
    CACHE_USER="${CACHE_CREDS%%:*}"
    CACHE_PASS="${CACHE_CREDS#*:}"
    section_start login_cache_ref "Logging in to $CACHE_REF (cache will be used)"
    CACHE_REGISTRY=$(echo "$CACHE_REF" | cut -d/ -f1)
    echo "$CACHE_PASS" | buildah login -u "$CACHE_USER" --password-stdin "$CACHE_REGISTRY"
    section_end login_cache_ref

    section_start pull_cache "Pulling from cache ref ${CACHE_REF}"
    echo "Using cache $CACHE_REF"
    buildah pull "$CACHE_REF" || true
    buildah pull "$FROM_REF"
    section_end pull_cache

    section_start push_to_cache "Pushing to cache ref ${CACHE_REF}"
    buildah push "$FROM_REF" "$CACHE_REF" || true
    section_end push_to_cache
fi

NOPUSH=
if [ -z "${DST_REF:-}" ]; then
    DST_REF="local"
    NOPUSH=1
fi

ARCHES=${ARCHES:-x86_64}
TYPES=${TYPES:-qcow2}
DST_REF=${DST_REF:-local}

for ARCH in $ARCHES; do
    for TYPE in $TYPES; do
        section_start prepare_containerfile "Preparing Containerfile with FROM ${FROM_REF}"
        cp -fv "$CONTAINERFILES_DIR/Containerfile.comment" "/tmp/Containerfile"
        set -x
        # shellcheck disable=SC2129
        echo "FROM ${FROM_REF}" >> "/tmp/Containerfile"
        echo "ARG BUILD_DATE=$(date +%Y-%m-%d)" >> "/tmp/Containerfile"
        tail -n +2 "$CONTAINERFILES_DIR/Containerfile.${CONTAINERFILE}-${TYPE}" >> "/tmp/Containerfile"
        set +x
        cat "/tmp/Containerfile"
        section_end prepare_containerfile

        section_start "build_${ARCH}_${TYPE}" "Building $FROM_REF arch $ARCH type $TYPE"
        buildah build --layers --arch="$ARCH" \
            --build-arg CONTAINERFILE="Containerfile" \
            --from "${FROM_REF}" \
            --storage-driver=vfs \
            --userns=host \
            --isolation=chroot \
            -f "/tmp/Containerfile" \
            -t "$DST_REF-$ARCH-$TYPE" .
        section_end "build_${ARCH}_${TYPE}"
    done
done

for TYPE in $TYPES; do
    for ARCH in $ARCHES; do
        section_start "push_${ARCH}_${TYPE}" "Pushing $DST_REF-$ARCH-$TYPE to registry"
        if [ -n "${DST_CREDS:-}" ] && [ -z "${NOPUSH:-}" ]; then
            echo "Pushing $DST_REF-$ARCH-$TYPE to registry"
            buildah push "$DST_REF-$ARCH-$TYPE"
        else
            echo "Push skipped: DST_CREDS missing or NOPUSH set"
        fi
        section_end "push_${ARCH}_${TYPE}"
    done
done

section_start create_manifest "Creating manifest for $DST_REF"
buildah manifest create --storage-driver=vfs "$DST_REF"
section_end create_manifest

for TYPE in $TYPES; do
    section_start "add_to_manifest_${TYPE}" "Adding $TYPE to $DST_REF manifest"
    for ARCH in $ARCHES; do
        buildah manifest add --storage-driver=vfs "$DST_REF" "$DST_REF-$ARCH-$TYPE"
    done
    section_end "add_to_manifest_${TYPE}"

    if [ -n "${DST_CREDS:-}" ] && [ -z "${NOPUSH:-}" ]; then
        section_start "push_manifest_${TYPE}" "Pushing manifest $DST_REF to registry"
        buildah manifest push --storage-driver=vfs --all "$DST_REF" "docker://$DST_REF"
        section_end "push_manifest_${TYPE}"
    else
        echo "Push skipped: DST_CREDS missing or NOPUSH set"
    fi
done
