#!/bin/sh
set -eu

if rg -n 'SkieSwift|SkieKotlin|import KMPObservableBridgeSKIE' \
  Sources/KMPObservableBridge \
  Sources/KMPObservableBridgeNative
then
  echo "SKIE-specific API leaked into the core or native integration." >&2
  exit 1
fi

if [ -z "${BASELINE_REF:-}" ]; then
  echo "API_BASELINE_REF is unset; compatibility comparison starts after 1.0."
  exit 0
fi

git rev-parse --verify "$BASELINE_REF^{commit}" >/dev/null
swift package diagnose-api-breaking-changes "$BASELINE_REF"
