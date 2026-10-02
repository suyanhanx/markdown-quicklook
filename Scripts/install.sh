#!/bin/bash
set -euo pipefail
script_dir="$(cd "$(dirname "$0")" && pwd)"
source_app="${1:-$script_dir/../build/DerivedData/Build/Products/Release/Markdown Quick Look.app}"
target_dir="${INSTALL_DIR:-/Applications}"
target_app="$target_dir/Markdown Quick Look.app"
backup_root="${BACKUP_DIR:-$HOME/Library/Application Support/Markdown Quick Look/Backups}"
expected_id='local.yan.MarkdownQuickLook'
read_id() { /usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$1/Contents/Info.plist"; }
[[ "$(read_id "$source_app")" == "$expected_id" ]] || { echo '拒绝安装：应用标识不匹配。' >&2; exit 1; }
codesign --verify --deep --strict "$source_app"
if [[ -e "$target_app" ]]; then
  [[ "$(read_id "$target_app")" == "$expected_id" ]] || { echo '拒绝替换其他应用。' >&2; exit 1; }
  source_version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$source_app/Contents/Info.plist")
  target_version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$target_app/Contents/Info.plist")
  [[ "$source_version" =~ ^[0-9]+$ && "$target_version" =~ ^[0-9]+$ ]] || { echo '版本号无效。' >&2; exit 1; }
  (( source_version >= target_version )) || { echo '拒绝降级；恢复旧版本请手动使用备份。' >&2; exit 1; }
fi
mkdir -p "$target_dir" "$backup_root"
staging="$(mktemp -d "$target_dir/.markdown-quicklook-install.XXXXXX")"
backup=''
installed=false
register_app() {
  /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "$target_app"
  pluginkit -a "$target_app/Contents/PlugIns/MarkdownPreview.appex"
  pluginkit -e use -i local.yan.MarkdownQuickLook.Preview
}
rollback() {
  result=$?
  trap - EXIT
  if (( result != 0 )); then
    echo '安装失败，正在恢复原状态。' >&2
    if [[ "$installed" == true ]]; then
      pluginkit -r "$target_app/Contents/PlugIns/MarkdownPreview.appex" || echo '新扩展注销失败。' >&2
      mv "$target_app" "$staging/failed.app"
    fi
    if [[ -n "$backup" && -e "$backup/Markdown Quick Look.app" ]]; then
      mv "$backup/Markdown Quick Look.app" "$target_app"
      register_app || echo '旧应用已恢复，但扩展注册失败；请重新运行安装。' >&2
      qlmanage -r || echo '预览缓存刷新失败，请关闭预览后重试。' >&2
    fi
  fi
  rm -rf "$staging"
  exit "$result"
}
trap rollback EXIT
ditto "$source_app" "$staging/Markdown Quick Look.app"
codesign --verify --deep --strict "$staging/Markdown Quick Look.app"
if [[ -e "$target_app" ]]; then
  backup="$(mktemp -d "$backup_root/$(date +%Y%m%d-%H%M%S).XXXXXX")"
  mv "$target_app" "$backup/"
fi
mv "$staging/Markdown Quick Look.app" "$target_app"
installed=true
register_app
source_extension="$(cd "$source_app/Contents/PlugIns/MarkdownPreview.appex" && pwd)"
registered="$(pluginkit -m -A -D -v -i local.yan.MarkdownQuickLook.Preview)"
if [[ "$source_extension" != "$target_app/Contents/PlugIns/MarkdownPreview.appex" && "$registered" == *"$source_extension"* ]]; then
  pluginkit -r "$source_extension"
fi
qlmanage -r
printf '已安装：%s\n' "$target_app"
[[ -z "$backup" ]] || printf '上一版本备份：%s\n' "$backup"
