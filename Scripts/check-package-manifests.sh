#!/bin/sh
set -eu

manifests="
Package.swift
Package@swift-6.0.swift
Package@swift-6.1.swift
Package@swift-6.2.swift
"

for manifest in $manifests; do
  for product in \
    KMPObservableBridge \
    KMPObservableBridgeSKIE \
    KMPObservableBridgeNative
  do
    rg -q "name: \"$product\"" "$manifest"
  done

  for target in \
    KMPObservableBridgeMacros \
    KMPObservableBridgeTests \
    KMPObservableBridgeMacroTests
  do
    rg -q "name: \"$target\"" "$manifest"
  done
done

rg -q 'exact: "509\.' Package.swift
rg -q 'swiftSyntaxVersion: "600\.' Package@swift-6.0.swift
rg -q 'swiftSyntaxVersion: "601\.' Package@swift-6.1.swift
rg -q 'swiftSyntaxVersion: "602\.' Package@swift-6.2.swift
