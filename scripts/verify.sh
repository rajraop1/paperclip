#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUN_LAUNCH_TEST=false
RUN_BUILD=true
for ARGUMENT in "$@"; do
    case "$ARGUMENT" in
        --launch) RUN_LAUNCH_TEST=true ;;
        --skip-build) RUN_BUILD=false ;;
        *)
            echo "Usage: $0 [--launch] [--skip-build]" >&2
            exit 2
            ;;
    esac
done

if [[ "$RUN_BUILD" == true ]]; then
    "$PROJECT_ROOT/scripts/build.sh" all
fi

for ARCHITECTURE in arm64 x86_64; do
    APP_BUNDLE="$PROJECT_ROOT/dist/ClippyPet-$ARCHITECTURE.app"
    EXECUTABLE="$APP_BUNDLE/Contents/MacOS/ClippyPet"

    ACTUAL_ARCHITECTURE="$(lipo -archs "$EXECUTABLE")"
    if [[ "$ACTUAL_ARCHITECTURE" != "$ARCHITECTURE" ]]; then
        echo "Expected $ARCHITECTURE, found $ACTUAL_ARCHITECTURE" >&2
        exit 1
    fi

    if ! vtool -show-build "$EXECUTABLE" | grep -q "minos 13.0"; then
        echo "$ARCHITECTURE binary does not target macOS 13.0" >&2
        exit 1
    fi

    BUNDLE_MINIMUM="$(plutil -extract LSMinimumSystemVersion raw "$APP_BUNDLE/Contents/Info.plist")"
    if [[ "$BUNDLE_MINIMUM" != "13.0" ]]; then
        echo "$ARCHITECTURE bundle has an unexpected minimum system version" >&2
        exit 1
    fi

    codesign --verify --deep --strict "$APP_BUNDLE"
    echo "Verified $ARCHITECTURE architecture, deployment target, and signature"
done

if [[ "$RUN_LAUNCH_TEST" != true ]]; then
    echo "Static verification passed. Run with --launch from a desktop-capable shell for the native GUI smoke test."
    exit 0
fi

HOST_ARCHITECTURE="$(uname -m)"
if [[ "$HOST_ARCHITECTURE" == "x86_64" ]] &&
   [[ "$(sysctl -in sysctl.proc_translated 2>/dev/null)" == "1" ]]; then
    HOST_ARCHITECTURE="arm64"
fi
HOST_APP="$PROJECT_ROOT/dist/ClippyPet-$HOST_ARCHITECTURE.app"
HOST_EXECUTABLE="$HOST_APP/Contents/MacOS/ClippyPet"
if [[ -x "$HOST_EXECUTABLE" ]]; then
    SMOKE_REPORT="$(mktemp -t clippypet-smoke)"
    trap 'rm -f "$SMOKE_REPORT"' EXIT
    open -n -W "$HOST_APP" --args --smoke-test --smoke-output "$SMOKE_REPORT"
    SMOKE_OUTPUT="$(<"$SMOKE_REPORT")"
    if ! plutil -extract stationary raw -o - - <<<"$SMOKE_OUTPUT" | grep -qx 'true'; then
        echo "Smoke test did not confirm a stationary window" >&2
        exit 1
    fi

    FRAME_ADVANCE_COUNT="$(plutil -extract frameAdvanceCount raw -o - - <<<"$SMOKE_OUTPUT")"
    if (( FRAME_ADVANCE_COUNT < 2 )); then
        echo "Smoke test did not confirm frame animation" >&2
        exit 1
    fi

    if ! plutil -extract isOpaque raw -o - - <<<"$SMOKE_OUTPUT" | grep -qx 'false'; then
        echo "Smoke test did not confirm a transparent window" >&2
        exit 1
    fi

    if ! plutil -extract hasShadow raw -o - - <<<"$SMOKE_OUTPUT" | grep -qx 'false'; then
        echo "Smoke test did not confirm a shadow-free window" >&2
        exit 1
    fi

    for BOOLEAN_KEY in isBorderless isMovable isNonactivating; do
        if ! plutil -extract "$BOOLEAN_KEY" raw -o - - <<<"$SMOKE_OUTPUT" | grep -qx 'true'; then
            echo "Smoke test failed window behavior check: $BOOLEAN_KEY" >&2
            exit 1
        fi
    done

    ROUTE_COUNT="$(plutil -extract routeCount raw -o - - <<<"$SMOKE_OUTPUT")"
    if (( ROUTE_COUNT != 290 )); then
        echo "Smoke test did not confirm the original animation routes" >&2
        exit 1
    fi

    PLAYABLE_ANIMATION_COUNT="$(plutil -extract playableAnimationCount raw -o - - <<<"$SMOKE_OUTPUT")"
    if (( PLAYABLE_ANIMATION_COUNT != 45 )); then
        echo "Smoke test did not confirm all 45 playable animations" >&2
        exit 1
    fi

    ANIMATION_COUNT="$(plutil -extract animationCount raw -o - - <<<"$SMOKE_OUTPUT")"
    UNIQUE_NAME_COUNT="$(plutil -extract uniqueAnimationNameCount raw -o - - <<<"$SMOKE_OUTPUT")"
    FRAME_COUNT="$(plutil -extract frameCount raw -o - - <<<"$SMOKE_OUTPUT")"
    ROUTE_ERROR_COUNT="$(plutil -extract routeValidationErrorCount raw -o - - <<<"$SMOKE_OUTPUT")"
    if (( ANIMATION_COUNT != 46 || UNIQUE_NAME_COUNT != 46 || FRAME_COUNT != 1347 || ROUTE_ERROR_COUNT != 0 )); then
        echo "Smoke test did not confirm the expanded animation catalog" >&2
        exit 1
    fi

    AUTOMATIC_DELAY="$(plutil -extract automaticDelaySeconds raw -o - - <<<"$SMOKE_OUTPUT")"
    if [[ "$AUTOMATIC_DELAY" != "2" ]]; then
        echo "Smoke test did not confirm the two-second animation delay" >&2
        exit 1
    fi

    MAXIMUM_DURATION="$(plutil -extract maximumAnimationDurationSeconds raw -o - - <<<"$SMOKE_OUTPUT")"
    if [[ "$MAXIMUM_DURATION" != "20" ]]; then
        echo "Smoke test did not confirm the animation safety duration" >&2
        exit 1
    fi

    MAXIMUM_ADVANCES="$(plutil -extract maximumFrameAdvances raw -o - - <<<"$SMOKE_OUTPUT")"
    if (( MAXIMUM_ADVANCES != 2000 )); then
        echo "Smoke test did not confirm the animation frame safety limit" >&2
        exit 1
    fi

    WINDOW_LEVEL="$(plutil -extract windowLevel raw -o - - <<<"$SMOKE_OUTPUT")"
    if (( WINDOW_LEVEL != 3 )); then
        echo "Smoke test did not confirm the floating window level" >&2
        exit 1
    fi

    echo "Launch smoke test passed: $SMOKE_OUTPUT"
else
    echo "No native binary is available for launch testing on $HOST_ARCHITECTURE" >&2
    exit 1
fi
