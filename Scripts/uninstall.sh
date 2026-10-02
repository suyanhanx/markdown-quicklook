#!/bin/bash
# Only the independent app is moved to Trash. Settings and backups are retained.
set -euo pipefail
target_app="${INSTALL_DIR:-/Applications}/Markdown Quick Look.app"
[[ -e "$target_app" ]] || { echo '未找到 Markdown Quick Look，无需卸载。'; exit 0; }
identifier=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$target_app/Contents/Info.plist")
[[ "$identifier" == 'local.yan.MarkdownQuickLook' ]] || { echo '拒绝卸载其他应用。' >&2; exit 1; }
pluginkit -e default -i local.yan.MarkdownQuickLook.Preview
pluginkit -r "$target_app/Contents/PlugIns/MarkdownPreview.appex"
mkdir -p "$HOME/.Trash"
trash_dir="$(mktemp -d "$HOME/.Trash/Markdown-Quick-Look.XXXXXX")"
if ! mv "$target_app" "$trash_dir/"; then
  pluginkit -a "$target_app/Contents/PlugIns/MarkdownPreview.appex"
  echo '移动到废纸篓失败，应用已保留。' >&2
  exit 1
fi
qlmanage -r
printf '已移到废纸篓：%s\n设置和升级备份已保留。恢复后请重新运行安装脚本。\n' "$trash_dir"
