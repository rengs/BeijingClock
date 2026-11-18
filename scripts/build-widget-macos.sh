#!/bin/bash
# 在 macOS 上用 Xcode 编译京时的 WidgetKit 扩展，并在已有菜单栏 App 时放进 PlugIns。
# 不下载工具，不用 sudo，不安装，不注册小组件，不打开应用，不请求通知。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "需要在装有 macOS SDK 的 Mac 上运行。当前系统不能编译 WidgetKit 扩展。" >&2
  exit 2
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "未找到 xcodebuild。请安装 Xcode，并自行接受许可协议。此脚本不会安装工具。" >&2
  exit 127
fi

ARCH="${ARCH:-arm64}"
DERIVED="$ROOT/build/widget-derived"
echo "编译 BeijingClockWidget.appex（macOS 14+，仅 Widget 扩展，菜单栏最低系统版本仍是 13）…"
xcodebuild \
  -project "$ROOT/WidgetExtension/BeijingClockWidget.xcodeproj" \
  -scheme BeijingClockWidget \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$DERIVED" \
  ARCHS="$ARCH" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO

APPEX="$DERIVED/Build/Products/Release/BeijingClockWidget.appex"
if [[ ! -d "$APPEX" ]]; then
  echo "找不到扩展产物: $APPEX" >&2
  exit 1
fi

if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - \
    --entitlements "$ROOT/WidgetExtension/BeijingClockWidget.entitlements" \
    "$APPEX"
  codesign --verify --strict "$APPEX"
  echo "已对扩展做 ad-hoc 签名，并写入 App Sandbox entitlement。"
  echo "这不能当成系统已经接受或可以放到桌面。WidgetKit 由 pluginkit / chronod 加载，通常还要开发团队签名。没有在这里验证图库或桌面显示。"
else
  echo "未找到 codesign，扩展未签名。未验证能否注册。"
fi

APP="$ROOT/dist/BeijingClock.app"
if [[ -d "$APP" ]]; then
  mkdir -p "$APP/Contents/PlugIns"
  rm -rf "$APP/Contents/PlugIns/BeijingClockWidget.appex"
  cp -R "$APPEX" "$APP/Contents/PlugIns/BeijingClockWidget.appex"
  echo "已放入: $APP/Contents/PlugIns/BeijingClockWidget.appex"
  echo "没有启动应用，没有加入登录项，没有改系统时区。"
else
  echo "尚未看到 dist/BeijingClock.app。扩展已编出，但没有嵌入菜单栏 App。可先运行 scripts/build-macos.sh，再运行本脚本。"
fi

echo "downloads/BeijingClock-1.0.1-arm64.app.zip 不含这个扩展。"
