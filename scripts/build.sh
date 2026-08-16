#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
SWIFTC="$(xcrun -f swiftc)"
DEPLOYMENT_TARGET="13.0"
ATLAS_PATH="$PROJECT_ROOT/Resources/map.png"

if [[ ! -f "$ATLAS_PATH" ]]; then
    echo "Missing Resources/map.png. Run ./scripts/fetch-assets.sh first." >&2
    exit 1
fi

if [[ $# -eq 0 || "$1" == "all" ]]; then
    ARCHITECTURES=(arm64 x86_64)
else
    ARCHITECTURES=("$1")
fi

for ARCHITECTURE in "${ARCHITECTURES[@]}"; do
    case "$ARCHITECTURE" in
        arm64|x86_64) ;;
        *)
            echo "Unsupported architecture: $ARCHITECTURE" >&2
            exit 2
            ;;
    esac

    BUILD_DIRECTORY="$PROJECT_ROOT/.build/$ARCHITECTURE"
    APP_BUNDLE="$PROJECT_ROOT/dist/ClippyPet-$ARCHITECTURE.app"
    APP_CONTENTS="$APP_BUNDLE/Contents"
    EXECUTABLE="$APP_CONTENTS/MacOS/ClippyPet"

    rm -rf "$BUILD_DIRECTORY" "$APP_BUNDLE"
    mkdir -p \
        "$BUILD_DIRECTORY/ModuleCache" \
        "$APP_CONTENTS/MacOS" \
        "$APP_CONTENTS/Resources"

    CLANG_MODULE_CACHE_PATH="$BUILD_DIRECTORY/ModuleCache" "$SWIFTC" \
        -O \
        -whole-module-optimization \
        -module-cache-path "$BUILD_DIRECTORY/ModuleCache" \
        -target "$ARCHITECTURE-apple-macosx$DEPLOYMENT_TARGET" \
        -sdk "$SDK_PATH" \
        -framework AppKit \
        -framework QuartzCore \
        -framework ImageIO \
        "$PROJECT_ROOT"/Sources/ClippyPet/*.swift \
        -o "$EXECUTABLE"

    ditto "$PROJECT_ROOT/Resources/Info.plist" "$APP_CONTENTS/Info.plist"
    ditto "$ATLAS_PATH" "$APP_CONTENTS/Resources/map.png"
    codesign --force --sign - --timestamp=none "$APP_BUNDLE"

    echo "Built $APP_BUNDLE"
done
