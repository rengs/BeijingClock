#!/bin/bash
# 在 macOS 上用 Xcode 编译京时的 WidgetKit 扩展，复制进菜单栏 App 之后再由内向外做 ad-hoc 签名。
# 不下载工具，不用 sudo，不使用开发者证书，不安装，不注册小组件，不打开应用。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CODESIGN="${CODESIGN:-/usr/bin/codesign}"

die() {
  printf '%s\n' "$1" >&2
  exit "${2:-1}"
}

# 全部复制完成后再签名。先签 appex，再签宿主。不用 --deep 代替逐层签名。
sign_inside_out() {
  local app="$1"
  local appex="$app/Contents/PlugIns/BeijingClockWidget.appex"
  [[ -d "$app" ]] || die "找不到宿主应用: $app"
  [[ -d "$appex" ]] || die "宿主里没有扩展: $appex"
  [[ -x "$CODESIGN" ]] || die "未找到 codesign，不能完成 ad-hoc 签名。"

  "$CODESIGN" --force --sign - \
    --entitlements "$ROOT/WidgetExtension/BeijingClockWidget.entitlements" \
    "$appex"
  "$CODESIGN" --force --sign - "$app"

  echo "校验扩展（strict）…"
  "$CODESIGN" --verify --strict --verbose=2 "$appex"
  echo "校验宿主（strict）…"
  "$CODESIGN" --verify --strict --verbose=2 "$app"
  echo "再按嵌套内容校验宿主（deep strict）…"
  "$CODESIGN" --verify --deep --strict --verbose=2 "$app"
}

main() {
  cd "$ROOT"
  if [[ "$(uname -s)" != "Darwin" ]]; then
    die "需要在装有 macOS SDK 的 Mac 上运行。当前系统不能编译 WidgetKit 扩展。" 2
  fi
  if ! command -v xcodebuild >/dev/null 2>&1; then
    die "未找到 xcodebuild。请安装 Xcode，并自行接受许可协议。此脚本不会安装工具。" 127
  fi

  local arch="${ARCH:-arm64}"
  local derived="$ROOT/build/widget-derived"
  echo "编译 BeijingClockWidget.appex（macOS 14+）。菜单栏应用的最低系统版本仍是 13。"
  xcodebuild \
    -project "$ROOT/WidgetExtension/BeijingClockWidget.xcodeproj" \
    -scheme BeijingClockWidget \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$derived" \
    ARCHS="$arch" \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO

  local built="$derived/Build/Products/Release/BeijingClockWidget.appex"
  [[ -d "$built" ]] || die "找不到扩展产物: $built"

  local app="$ROOT/dist/BeijingClock.app"
  if [[ ! -d "$app" ]]; then
    die "还没有 dist/BeijingClock.app。请先运行 scripts/build-macos.sh，再运行本脚本。扩展已编出，但没有嵌入，因此这次不签名、不以成功结束。"
  fi

  mkdir -p "$app/Contents/PlugIns"
  rm -rf "$app/Contents/PlugIns/BeijingClockWidget.appex"
  cp -R "$built" "$app/Contents/PlugIns/BeijingClockWidget.appex"

  # 菜单栏脚本会先签一个还没有 PlugIns 的宿主。嵌入之后必须重签，否则 codesign --verify 会失败。
  sign_inside_out "$app"

  echo "已放入并完成 ad-hoc 签名: $app"
  echo "签名标识是 ad-hoc（-），没有使用开发者证书，也没有公证。"
  echo "没有启动应用，没有加入登录项，没有改系统时区。"
  echo "downloads/BeijingClock-1.0.1-arm64.app.zip 不含这个扩展。"
  echo "codesign --verify 通过不等于小组件已经出现在图库或桌面上。这里没有做那一项检查。"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
