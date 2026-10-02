#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source_app='build/DerivedData/Build/Products/Release/Markdown Quick Look.app'
target_app='/Applications/Markdown Quick Look.app'
codesign --verify --deep --strict "$source_app"
if [[ -e "$target_app" ]]; then
  existing_id=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$target_app/Contents/Info.plist")
  [[ "$existing_id" == 'local.yan.MarkdownQuickLook' ]] || { echo '拒绝替换其他应用。' >&2; exit 1; }
  backup="build/install-backups/$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$backup"
  mv "$target_app" "$backup/"
fi
ditto "$source_app" "$target_app"
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "$target_app"
pluginkit -a "$target_app/Contents/PlugIns/MarkdownPreview.appex"
pluginkit -e use -i local.yan.MarkdownQuickLook.Preview
build_extension="$PWD/$source_app/Contents/PlugIns/MarkdownPreview.appex"
registered="$(pluginkit -m -A -D -v -i local.yan.MarkdownQuickLook.Preview)"
if [[ "$registered" == *"$build_extension"* ]]; then
  pluginkit -r "$build_extension"
fi
qlmanage -r
printf 'Installed: %s\n' "$target_app"
