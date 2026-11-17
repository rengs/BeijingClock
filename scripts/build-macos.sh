#!/bin/bash
# 在 macOS 上编译并组装 BeijingClock.app。
# 不下载工具链，不安装，不加入登录项，不修改系统设置，不做 Developer ID 公证。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "需要在 macOS 上运行。当前系统没有 macOS SDK，不能编译 AppKit 应用。" >&2
  exit 2
fi

if ! command -v swift >/dev/null 2>&1; then
  echo "未找到 swift。请安装 Xcode 15 或更高版本的命令行工具。此脚本不会下载任何文件。" >&2
  exit 127
fi

ARCH="${ARCH:-arm64}"
if [[ "$ARCH" != "arm64" ]]; then
  echo "警告: 本仓库只针对 Apple Silicon (arm64) 准备。Intel / 其他架构未在此环境验证，不保证能编译或运行。" >&2
fi

export MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-13.0}"

echo "编译 BeijingClock ($ARCH, macOS ${MACOSX_DEPLOYMENT_TARGET}+)…"
swift build -c release --arch "$ARCH" --product BeijingClock

BIN_DIR="$(swift build -c release --arch "$ARCH" --product BeijingClock --show-bin-path)"
BIN="$BIN_DIR/BeijingClock"
if [[ ! -f "$BIN" ]]; then
  echo "找不到编译产物: $BIN" >&2
  exit 1
fi

APP="$ROOT/dist/BeijingClock.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/BeijingClock"
cp "$ROOT/Packaging/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
chmod 755 "$APP/Contents/MacOS/BeijingClock"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - "$APP"
  echo "已做 ad-hoc 签名（未公证）。Gatekeeper 仍可能拦截，请勿关闭系统安全。"
else
  echo "未找到 codesign，已跳过签名。"
fi

echo "已生成: $APP"
echo "显示名：京时。版本：1.0.1。包名 / 文件名：BeijingClock.app"
echo "Bundle ID：local.beijingclock.jingshi（local 本地标识，不是已注册域名）"
echo "未复制到「应用程序」，未设置开机启动。"
