#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swiftc -I Vendor/cmark-gfm/src -I Vendor/cmark-gfm/extensions -I build/cmark/src -I build/cmark/extensions \
  -import-objc-header Shared/MarkdownBridge.h Shared/PreviewSettings.swift Shared/MarkdownRenderer.swift Tests/main.swift \
  -L build/lib -lcmark-gfm-extensions -lcmark-gfm -o build/renderer-tests-runner
build/renderer-tests-runner
