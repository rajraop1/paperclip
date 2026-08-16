#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ATLAS_PATH="$PROJECT_ROOT/Resources/map.png"
UPSTREAM_COMMIT="748f199f0187f6f94ce395cdd55081f513476156"
ATLAS_URL="https://raw.githubusercontent.com/pithings/clippy/$UPSTREAM_COMMIT/src/agents/clippy/map.png"
EXPECTED_SHA256="880b63ac4d3fa84c78eceb02674c9eaedae032b2d85887539a7f6d107e5801e9"

verify_atlas() {
    local path="$1"
    local actual_sha256
    actual_sha256="$(LC_ALL=C shasum -a 256 "$path" | awk '{print $1}')"
    [[ "$actual_sha256" == "$EXPECTED_SHA256" ]]
}

if [[ -f "$ATLAS_PATH" ]]; then
    if verify_atlas "$ATLAS_PATH"; then
        echo "Clippy sprite atlas is already present and verified."
        exit 0
    fi

    echo "Resources/map.png exists but its checksum is unexpected; it was not changed." >&2
    exit 1
fi

TEMP_ATLAS="$(mktemp -t clippypet-map)"
trap 'rm -f "$TEMP_ATLAS"' EXIT

curl --fail --location --silent --show-error "$ATLAS_URL" --output "$TEMP_ATLAS"

if ! verify_atlas "$TEMP_ATLAS"; then
    echo "Downloaded atlas failed checksum verification." >&2
    exit 1
fi

mkdir -p "$PROJECT_ROOT/Resources"
mv "$TEMP_ATLAS" "$ATLAS_PATH"
trap - EXIT
echo "Downloaded and verified Resources/map.png."
