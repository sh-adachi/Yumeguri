#!/bin/bash
set -euo pipefail

if [[ $# -ne 1 || -z "$1" ]]; then
    echo "Usage: bash Scripts/deploy_iphone.sh <iPhone UDID>" >&2
    echo "Find the connected iPhone UDID with: xcrun xctrace list devices" >&2
    exit 2
fi

yumeguri_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
yumeguri_device="$1"
yumeguri_build="$yumeguri_root/.build/device"

xcodebuild \
    -project "$yumeguri_root/Yumeguri.xcodeproj" \
    -scheme Yumeguri \
    -configuration Debug \
    -destination "id=$yumeguri_device" \
    -derivedDataPath "$yumeguri_build" \
    -allowProvisioningUpdates \
    -allowProvisioningDeviceRegistration \
    build

xcrun devicectl device install app \
    --device "$yumeguri_device" \
    "$yumeguri_build/Build/Products/Debug-iphoneos/Yumeguri.app"

xcrun devicectl device process launch \
    --device "$yumeguri_device" \
    dev.adachi.yumeguri
