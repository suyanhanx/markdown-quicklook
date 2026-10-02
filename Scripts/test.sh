#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swiftc -I Vendor/cmark-gfm/src -I Vendor/cmark-gfm/extensions -I build/cmark/src -I build/cmark/extensions \
  -import-objc-header Shared/MarkdownBridge.h Shared/PreviewSettings.swift Shared/MathMarkup.swift Shared/MarkdownRenderer.swift Tests/main.swift \
  -L build/lib -lcmark-gfm-extensions -lcmark-gfm -o build/renderer-tests-runner
build/renderer-tests-runner

swiftc -parse-as-library Tests/WebRendering.swift -o build/web-rendering-tests
build/web-rendering-tests build/rich-preview.html > build/web-rich-result.json
build/web-rendering-tests build/render-errors.html > build/web-error-result.json
build/web-rendering-tests build/rich-dark.html > build/web-dark-result.json
printf 'WebKit: formulas, diagrams, explicit errors and zero network requests verified.\n'
