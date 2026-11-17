#!/bin/bash
# 运行与 AppKit 无关的时间与闹钟测试。不下载 Swift 工具链。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v swift >/dev/null 2>&1; then
  echo "未找到 swift，测试未运行。需要 Swift 5.9 或更高版本。此脚本不会下载编译器。" >&2
  exit 127
fi

swift test "$@"
