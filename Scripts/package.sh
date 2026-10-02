#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
app='build/DerivedData/Build/Products/Release/Markdown Quick Look.app'
codesign --verify --deep --strict "$app"
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")
arch="$(uname -m)"
stage="$(mktemp -d "$PWD/build/package.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/Markdown Quick Look.app"
ln -s /Applications "$stage/Applications"
cp Scripts/install.sh "$stage/install.sh"
cp Scripts/uninstall.sh "$stage/Uninstall.command"
cp INSTALL.md "$stage/安装说明.md"
cat > "$stage/Install.command" <<'INSTALL'
#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
/bin/bash ./install.sh "$PWD/Markdown Quick Look.app"
INSTALL
chmod +x "$stage/Install.command" "$stage/Uninstall.command"
mkdir -p build/releases
output="$PWD/build/releases/Markdown-Quick-Look-$version-$arch.dmg"
hdiutil create -ov -format UDZO -volname "Markdown Quick Look $version" -srcfolder "$stage" "$output"
shasum -a 256 "$output" > "$output.sha256"
printf '安装包：%s\n本地开发签名，未公证；仅供本机验证，不宣称可在其他 Mac 无提示运行。\n' "$output"
