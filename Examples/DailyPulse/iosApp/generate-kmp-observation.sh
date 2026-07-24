#!/bin/sh
#
# Use this file as the content of an Xcode Run Script phase placed before
# Compile Sources. No generated group or file needs to be added manually.
set -eu

if [ -z "${JAVA_HOME:-}" ]; then
    export JAVA_HOME="$(/usr/libexec/java_home -v 17)"
fi

cd "$SRCROOT/.."
./gradlew :shared:embedAndSignAppleFrameworkForXcode --no-daemon

GENERATED_DIR="$SRCROOT/iosApp/Generated/KMPObservableBridge"
mkdir -p "$GENERATED_DIR"

KMP_OBSERVABLE_SDKROOT="$SDKROOT" env -u SDKROOT \
    xcrun swift run \
    --package-path "$SRCROOT/../../.." \
    kmp-observable-bridge-generator \
    --framework "$SRCROOT/../shared/build/xcode-frameworks/$CONFIGURATION/$SDK_NAME/shared.framework" \
    --module shared \
    --output "$GENERATED_DIR/KMPObservableBridge.generated.swift" \
    --xcode-project "$PROJECT_FILE_PATH" \
    --target "$TARGET_NAME"
