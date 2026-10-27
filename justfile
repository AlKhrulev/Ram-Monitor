# `just` lists the available commands.
default:
    @just --list

# Compile and package a standalone native app. No Xcode project needed.
build:
    #!/usr/bin/env bash
    set -euo pipefail
    export TMPDIR=/private/tmp/tmpfs/swift
    mkdir -p "$TMPDIR" build/"RAM Monitor.app"/Contents/MacOS
    swiftc -O -target "$(uname -m)-apple-macosx13.0" \
        -module-cache-path "$TMPDIR/ram-monitor-module-cache" \
        Sources/*.swift -o "build/RAM Monitor.app/Contents/MacOS/RAMMonitor"
    cp Resources/Info.plist "build/RAM Monitor.app/Contents/Info.plist"
    mkdir -p "build/RAM Monitor.app/Contents/Resources"
    cp Resources/AppIcon.icns "build/RAM Monitor.app/Contents/Resources/AppIcon.icns"
    codesign --force --sign - "build/RAM Monitor.app"
    echo 'Built: build/RAM Monitor.app'

# Regenerate the app icon after changing the source PNG.
icon:
    #!/usr/bin/env bash
    set -euo pipefail
    export TMPDIR=/private/tmp/tmpfs/swift
    mkdir -p "$TMPDIR"
    work=$(mktemp -d "$TMPDIR/ram-monitor-icon.XXXXXX")
    trap 'rm -rf "$work"' EXIT
    mkdir "$work/AppIcon.iconset"
    for size in 16 32 128 256 512; do
        sips -z "$size" "$size" "Neon RAM Monitor Icon.png" \
            --out "$work/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
        double=$((size * 2))
        sips -z "$double" "$double" "Neon RAM Monitor Icon.png" \
            --out "$work/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
    done
    iconutil -c icns "$work/AppIcon.iconset" -o Resources/AppIcon.icns

# Build, then open the menu-bar app.
run: build
    open "build/RAM Monitor.app"

# Run a small live check of the OS readings without opening the UI.
check:
    #!/usr/bin/env bash
    set -euo pipefail
    export TMPDIR=/private/tmp/tmpfs/swift
    mkdir -p "$TMPDIR"
    swiftc -O -module-cache-path "$TMPDIR/ram-monitor-module-cache" \
        Sources/MemoryStats.swift Sources/AppMemory.swift Tests/SmokeCheck.swift \
        -o "$TMPDIR/ram-monitor-check"
    "$TMPDIR/ram-monitor-check"
