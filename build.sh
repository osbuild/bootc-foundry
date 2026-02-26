#!/bin/bash
set -ex

# Buildah requires the vfs storage driver when running inside an unprivileged
# container/pod. Use cross-platform build even when aarch64 is not supported by
# GHA, because downstream we can only use RHOS on x86_64.
BUILDAH=${BUILDAH:-buildah --storage-driver=vfs}

# The token can be passed via mounted directory for security reasons. This is
# used downstream (RHOS Tekton).
TOKEN=/workspace/source/token.txt

if test -f "$TOKEN"; then
	cat "$TOKEN" | $BUILDAH login -u "$REPO_USERNAME" --password-stdin "$REPO_URL"
elif test -n "$REPO_USERNAME" && test -n "$REPO_PASSWORD"; then
	$BUILDAH login -u "$REPO_USERNAME" -p "$REPO_PASSWORD"
else
	echo "No token or password provided, push will likely fail"
fi

# Fedora images
for cf in $(find . -name "Containerfile.fedora-[0-9][0-9]-*" -not -name "*.tmpl"); do
    URL=${REPO_URL:-quay.io/osbuild/fedora-bootc}
    TAG=$(basename "$cf" | sed 's/^Containerfile\.fedora-//')
    $BUILDAH rmi "$URL:$TAG" 2>/dev/null || true
    $BUILDAH manifest create "$URL:$TAG"

    for ARCH in x86_64 aarch64; do
        $BUILDAH build --arch=$ARCH \
            --manifest "$URL:$TAG" \
            --build-arg CONTAINERFILE="$cf" \
            -f "$cf" -t "$URL:$TAG-$ARCH" .
        $BUILDAH push "$URL:$TAG-$ARCH"
    done

    $BUILDAH manifest push --all "$URL:$TAG" "docker://$URL:$TAG"
done
