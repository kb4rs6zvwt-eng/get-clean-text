#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/ModuleCache"
mkdir -p .build
swiftc -module-cache-path "$CLANG_MODULE_CACHE_PATH" \
    Sources/PlainText/ClipboardCleaner.swift Sources/PlainText/Shortcut.swift \
    Tests/main.swift -o .build/PlainTextTests
.build/PlainTextTests
