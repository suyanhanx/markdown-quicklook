#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="/opt/homebrew/bin:$PATH"
: "${SIGNING_IDENTITY:?Set SIGNING_IDENTITY to an Apple Development certificate name or hash}"
git submodule update --init --recursive
cmake -S Vendor/cmark-gfm -B build/cmark -DCMARK_TESTS=OFF -DCMARK_SHARED=OFF -DCMARK_STATIC=ON -DCMARK_GFM_STATIC=ON -DCMARK_GFM_SHARED=OFF -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0
cmake --build build/cmark -j 8
mkdir -p build/lib
cp build/cmark/src/libcmark-gfm.a build/lib/
cp build/cmark/extensions/libcmark-gfm-extensions.a build/lib/
xcodegen generate
xcodebuild -project MarkdownQuickLook.xcodeproj -scheme MarkdownQuickLook -configuration Release -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES ARCHS="$(uname -m)" build
app='build/DerivedData/Build/Products/Release/Markdown Quick Look.app'
codesign --force --sign "$SIGNING_IDENTITY" --entitlements Extension/Extension.entitlements "$app/Contents/PlugIns/MarkdownPreview.appex"
codesign --force --sign "$SIGNING_IDENTITY" --entitlements App/App.entitlements "$app"
codesign --verify --deep --strict 'build/DerivedData/Build/Products/Release/Markdown Quick Look.app'
