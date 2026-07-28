#!/bin/sh
set -eu

if rg -n 'SkieSwift|SkieKotlin|import KMPObservableBridgeSKIE' \
  Sources/KMPObservableBridge \
  Sources/KMPObservableBridgeNative
then
  echo "SKIE-specific API leaked into the core or native integration." >&2
  exit 1
fi

BASELINE_REF="${BASELINE_REF:-1.1.0}"

git rev-parse --verify "$BASELINE_REF^{commit}" >/dev/null
swift package diagnose-api-breaking-changes "$BASELINE_REF"
