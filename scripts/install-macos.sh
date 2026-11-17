#!/bin/bash
# 把京时 1.0.1 的 Apple Silicon 安装包放到当前用户的应用程序目录。
# 阅读后再执行。不要用 sudo，不要通过 curl 管道交给 sh。
# 脚本不会启动应用，不请求通知，不修改登录项、时区或系统安全设置。
# 安装包约 180KB，使用 macOS 自带的 curl、shasum、unzip、ditto、file、plutil、codesign。

set -euo pipefail

EXPECTED_SHA256="b99c7489eed4cc404db217b01045e2f29c9152f836e2e936194b4d7e350f3be0"
EXPECTED_SIZE=180157
BUNDLE_ID="local.beijingclock.jingshi"
APP_VERSION="1.0.1"
APP_BUILD="2"
APP_EXECUTABLE="BeijingClock"
APP_NAME="京时"

# 固定到已经包含这份 zip 的提交。main 合并后也有同一份文件，SHA256 仍是最终校验。
DEFAULT_ZIP_URL="https://raw.githubusercontent.com/rengs/BeijingClock/0df21739a8b26aee90eb99387f6a26bc4a016557/downloads/BeijingClock-1.0.1-arm64.app.zip"

TMP_ROOT=""

die() {
  printf '%s\n' "$1" >&2
  exit "${2:-1}"
}

usage() {
  cat <<'EOF'
用法（在 Apple Silicon Mac 上，不要加 sudo）：

  只校验已经下载的 zip，不安装：
    ./scripts/install-macos.sh --check-zip /路径/BeijingClock-1.0.1-arm64.app.zip

  用已经下载的 zip 安装：
    ./scripts/install-macos.sh --zip /路径/BeijingClock-1.0.1-arm64.app.zip

  从本仓库这个分支里的真实文件下载、校验后安装：
    ./scripts/install-macos.sh

  指定同样位于 rengs/BeijingClock 的 https 地址：
    ./scripts/install-macos.sh --url https://raw.githubusercontent.com/rengs/BeijingClock/<提交>/downloads/BeijingClock-1.0.1-arm64.app.zip

  默认安装到 $HOME/Applications/BeijingClock.app
    ./scripts/install-macos.sh --zip <zip> --dest "$HOME/Applications/BeijingClock.app"

安装完成后脚本不会打开应用。
EOF
}

refuse_root() {
  if [[ "$(id -u)" -eq 0 || -n "${SUDO_USER:-}" ]]; then
    die "请以当前用户运行，不要使用 sudo。应用会安装到该用户主目录下的 Applications。"
  fi
}

require_apple_silicon() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    die "安装只能在 macOS 上进行。当前系统是 $(uname -s)。" 2
  fi
  if [[ "$(uname -m)" != "arm64" ]]; then
    die "预编译包只包含 Apple Silicon arm64（M1、M2、M3、M4 等）。当前架构是 $(uname -m)，安装已停止。Intel 版本未提供，也未验证。" 2
  fi
}

allowed_url() {
  local url=$1
  case "$url" in
    https://raw.githubusercontent.com/rengs/BeijingClock/*/downloads/BeijingClock-1.0.1-arm64.app.zip|\
    https://github.com/rengs/BeijingClock/raw/*/downloads/BeijingClock-1.0.1-arm64.app.zip)
      ;;
    *)
      return 1
      ;;
  esac
  case "$url" in
    *..*|*' '*|*$'\n'*|*'|'*)
      return 1
      ;;
  esac
  return 0
}

validate_member_name() {
  local name=$1
  local trimmed part rest
  [[ -n "$name" ]] || die "zip 含有空成员名"
  case "$name" in
    *$'\n'*|*'\'*|*'|'*)
      die "zip 成员名不安全"
      ;;
    /*|./*)
      die "zip 含有绝对路径或意外前缀"
      ;;
  esac
  trimmed=${name%/}
  case "$trimmed" in
    BeijingClock.app|BeijingClock.app/*)
      ;;
    *)
      die "zip 成员不在 BeijingClock.app 内"
      ;;
  esac
  rest=${trimmed#BeijingClock.app}
  rest=${rest#/}
  if [[ -n "$rest" ]]; then
    local old_ifs=$IFS
    IFS=/
    for part in $rest; do
      case "$part" in
        ''|.|..)
          IFS=$old_ifs
          die "zip 成员含有路径穿越"
          ;;
      esac
    done
    IFS=$old_ifs
  fi
}

validate_zip_members() {
  local zip=$1
  local line name names_n info_n saw_plist=0 saw_bin=0 saw_pkg=0
  names_n=0
  while IFS= read -r name || [[ -n "$name" ]]; do
    names_n=$((names_n + 1))
    validate_member_name "$name"
    case "$name" in
      BeijingClock.app/Contents/Info.plist) saw_plist=1 ;;
      BeijingClock.app/Contents/MacOS/BeijingClock) saw_bin=1 ;;
      BeijingClock.app/Contents/PkgInfo) saw_pkg=1 ;;
    esac
  done < <(unzip -Z1 -- "$zip")

  # 成员名以 unzip -Z1 为准。这里只确认类型：拒绝符号链接，并要求条数一致。
  info_n=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      Archive:*|"Zip file size:"*|*' files, '*uncompressed*)
        continue
        ;;
    esac
    case "$line" in
      l*)
        die "zip 含有符号链接，已停止"
        ;;
      d*|[-]*)
        info_n=$((info_n + 1))
        ;;
      *)
        die "无法识别 zip 目录中的一行，已停止"
        ;;
    esac
  done < <(unzip -Z -- "$zip")

  [[ "$names_n" -gt 0 && "$names_n" == "$info_n" ]] || die "zip 目录不一致，已停止"
  [[ "$saw_plist" -eq 1 && "$saw_bin" -eq 1 && "$saw_pkg" -eq 1 ]] || die "zip 缺少应用必需文件，已停止"
}

verify_zip_file() {
  local zip=$1
  local size actual
  [[ -f "$zip" && ! -L "$zip" ]] || die "找不到 zip，或该路径是符号链接"
  size=$(wc -c < "$zip" | tr -d '[:space:]')
  [[ "$size" == "$EXPECTED_SIZE" ]] || die "zip 大小不是 ${EXPECTED_SIZE} 字节，已停止"
  actual=$(shasum -a 256 -- "$zip" | awk '{print $1}' | tr '[:upper:]' '[:lower:]')
  [[ "$actual" == "$EXPECTED_SHA256" ]] || die "SHA256 不一致，已停止。期望 ${EXPECTED_SHA256}"
  validate_zip_members "$zip"
}

plist_get() {
  local key=$1 file=$2
  /usr/bin/plutil -extract "$key" raw -o - -- "$file"
}

assert_our_plist() {
  local plist=$1 require_release=$2
  local bundle_id executable version build name
  [[ -f "$plist" && ! -L "$plist" ]] || die "找不到 Info.plist"
  bundle_id=$(plist_get CFBundleIdentifier "$plist")
  executable=$(plist_get CFBundleExecutable "$plist")
  [[ "$bundle_id" == "$BUNDLE_ID" ]] || die "Bundle ID 不是 ${BUNDLE_ID}，已停止"
  [[ "$executable" == "$APP_EXECUTABLE" ]] || die "可执行文件名不是 ${APP_EXECUTABLE}，已停止"
  if [[ "$require_release" -eq 1 ]]; then
    version=$(plist_get CFBundleShortVersionString "$plist")
    build=$(plist_get CFBundleVersion "$plist")
    name=$(plist_get CFBundleName "$plist")
    [[ "$version" == "$APP_VERSION" && "$build" == "$APP_BUILD" ]] || die "安装包不是 ${APP_VERSION}（${APP_BUILD}），已停止"
    [[ "$name" == "$APP_NAME" ]] || die "应用名称不是京时，已停止"
  fi
}

assert_arm64_binary() {
  local bin=$1
  local info
  [[ -f "$bin" && ! -L "$bin" ]] || die "找不到可执行文件"
  info=$(/usr/bin/file -b -- "$bin")
  case "$info" in
    *Mach-O*arm64*)
      ;;
    *)
      die "可执行文件不是 arm64 Mach-O，已停止"
      ;;
  esac
  case "$info" in
    *x86_64*|*i386*)
      die "可执行文件不是仅 arm64，已停止"
      ;;
  esac
}

assert_tree_contained() {
  local root=$1
  local real_root path real_path base
  [[ -d "$root/BeijingClock.app" && ! -L "$root/BeijingClock.app" ]] || die "解压结果没有 BeijingClock.app"
  base=$(cd -P -- "$root" && pwd)
  for path in "$root"/* "$root"/.[!.]* "$root"/..?*; do
    [[ -e "$path" || -L "$path" ]] || continue
    case "$(basename -- "$path")" in
      BeijingClock.app) ;;
      *) die "解压出现意外的顶层内容，已停止" ;;
    esac
  done
  real_root=$(cd -P -- "$root" && pwd)
  while IFS= read -r -d '' path; do
    if [[ -L "$path" ]]; then
      die "解压结果含有符号链接，已停止"
    fi
    if [[ -d "$path" ]]; then
      real_path=$(cd -P -- "$path" && pwd)
    else
      real_path=$(cd -P -- "$(dirname -- "$path")" && pwd)/$(basename -- "$path")
    fi
    case "$real_path" in
      "$real_root"|"$real_root"/*) ;;
      *) die "解压路径越出临时目录，已停止" ;;
    esac
  done < <(find -P "$root" -print0)
  [[ "$base" == "$real_root" ]] || die "临时目录路径不一致，已停止"
}

executable_path_for_pid() {
  local pid=$1 line cmd
  if [[ -x /usr/sbin/lsof ]]; then
    while IFS= read -r line; do
      case "$line" in
        n/*)
          printf '%s\n' "${line#n}"
          return 0
          ;;
      esac
    done < <(/usr/sbin/lsof -a -p "$pid" -d txt -Fn 2>/dev/null || true)
  fi
  cmd=$(ps -ww -p "$pid" -o command= 2>/dev/null || true)
  case "$cmd" in
    /*)
      printf '%s\n' "${cmd%% *}"
      return 0
      ;;
  esac
  return 1
}

same_bundle_is_running() {
  local dest=$1 pid path unknown=0 same=0
  [[ -x /usr/bin/pgrep ]] || return 1
  while read -r pid; do
    [[ -n "$pid" ]] || continue
    if path=$(executable_path_for_pid "$pid"); then
      case "$path" in
        "$dest"/*)
          same=1
          ;;
      esac
    else
      unknown=1
    fi
  done < <(/usr/bin/pgrep -x BeijingClock || true)
  if [[ "$same" -eq 1 ]]; then
    return 0
  fi
  if [[ "$unknown" -eq 1 && -d "$dest" ]]; then
    return 0
  fi
  return 1
}

resolve_dest() {
  local dest=$1 parent base physical
  [[ -n "$dest" ]] || dest="${HOME}/Applications/BeijingClock.app"
  case "$dest" in
    "$HOME"/*) ;;
    *)
      die "目的地必须在当前用户主目录内。默认是 ${HOME}/Applications/BeijingClock.app"
      ;;
  esac
  case "$dest" in
    *"/../"*|*"/"..|*"/./"*|*"/".)
      die "目的地路径不明确，已停止"
      ;;
  esac
  base=$(basename -- "$dest")
  [[ "$base" == "BeijingClock.app" ]] || die "目的地文件名必须是 BeijingClock.app"
  if [[ -L "$dest" ]]; then
    die "目的地是符号链接，已拒绝覆盖"
  fi
  if [[ -e "$dest" && ! -d "$dest" ]]; then
    die "目的地已存在，但不是应用包，已拒绝覆盖"
  fi
  parent=$(dirname -- "$dest")
  mkdir -p -- "$parent"
  physical=$(cd -P -- "$parent" && pwd)
  case "$physical" in
    "$HOME"|"$HOME"/*) ;;
    *)
      die "目的地解析后不在当前用户主目录内，已停止"
      ;;
  esac
  if [[ -e "$dest" ]]; then
    assert_our_plist "$dest/Contents/Info.plist" 0
  fi
  printf '%s/%s\n' "$physical" "$base"
}

remove_our_tmp() {
  local dir=${TMP_ROOT:-} base parent tmpdir
  [[ -n "$dir" ]] || return 0
  base=$(basename -- "$dir")
  parent=$(dirname -- "$dir")
  case "$base" in
    beijingclock-install.*) ;;
    *)
      printf '%s\n' "临时目录名称不符合预期，未删除。" >&2
      return 0
      ;;
  esac
  tmpdir=${TMPDIR:-/tmp}
  tmpdir=${tmpdir%/}
  case "$parent" in
    "$tmpdir"|/tmp|/private/tmp|/var/folders/*) ;;
    *)
      printf '%s\n' "临时目录不在预期位置，未删除。" >&2
      return 0
      ;;
  esac
  if [[ -d "$dir" && ! -L "$dir" ]]; then
    rm -rf -- "$dir"
  fi
  TMP_ROOT=""
}

cleanup() {
  local status=$?
  remove_our_tmp || true
  exit "$status"
}

make_temp() {
  local tmpdir=${TMPDIR:-/tmp}
  TMP_ROOT=$(mktemp -d "${tmpdir%/}/beijingclock-install.XXXXXX")
  trap cleanup EXIT
}

download_zip() {
  local url=$1 dest=$2
  allowed_url "$url" || die "只接受 rengs/BeijingClock 仓库里这份 zip 的 https 地址。"
  /usr/bin/curl \
    --fail \
    --location \
    --silent \
    --show-error \
    --proto '=https' \
    --tlsv1.2 \
    --retry 2 \
    --retry-delay 1 \
    --max-filesize 1000000 \
    --output "$dest" \
    "$url"
}

install_bundle() {
  local src=$1 dest=$2
  local backup="" had_old=0
  if [[ -e "$dest" ]]; then
    had_old=1
    backup="${dest}.bak.$(date +%Y%m%d%H%M%S).$$"
    [[ -e "$backup" ]] && die "备份路径已经存在，已停止"
    mv -- "$dest" "$backup"
  fi
  if ! /usr/bin/ditto "$src" "$dest"; then
    if [[ "$had_old" -eq 1 ]]; then
      rm -rf -- "$dest"
      mv -- "$backup" "$dest"
    fi
    die "复制应用失败。若原来有京时，已放回原处。"
  fi
  if ! /usr/bin/codesign --verify --strict "$dest"; then
    rm -rf -- "$dest"
    if [[ "$had_old" -eq 1 ]]; then
      mv -- "$backup" "$dest"
    fi
    die "复制后的 ad-hoc 签名校验没有通过。若原来有京时，已放回原处。系统安全设置没有改动。"
  fi
  if [[ -n "$backup" ]]; then
    printf '原来的京时已保留为备份：%s\n' "$backup"
  fi
}

main() {
  local zip_path="" zip_url="" dest="" check_only=0
  refuse_root
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --zip)
        [[ $# -ge 2 ]] || die "缺少 --zip 后面的路径"
        zip_path=$2
        shift 2
        ;;
      --url)
        [[ $# -ge 2 ]] || die "缺少 --url 后面的地址"
        zip_url=$2
        shift 2
        ;;
      --dest)
        [[ $# -ge 2 ]] || die "缺少 --dest 后面的路径"
        dest=$2
        shift 2
        ;;
      --check-zip)
        [[ $# -ge 2 ]] || die "缺少 --check-zip 后面的路径"
        zip_path=$2
        check_only=1
        shift 2
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        die "无法识别的参数：$1。可先运行 --help。"
        ;;
    esac
  done

  if [[ -n "$zip_path" && -n "$zip_url" ]]; then
    die "请只选择本地 zip 或下载地址其中一种。"
  fi

  if [[ "$check_only" -eq 1 ]]; then
    verify_zip_file "$zip_path"
    printf '校验通过：大小 %s 字节，SHA256 %s。没有安装。\n' "$EXPECTED_SIZE" "$EXPECTED_SHA256"
    exit 0
  fi

  require_apple_silicon
  command -v unzip >/dev/null 2>&1 || die "需要 macOS 自带的 unzip 来检查 zip 成员。"
  [[ -x /usr/bin/ditto && -x /usr/bin/curl && -x /usr/bin/plutil && -x /usr/bin/file && -x /usr/bin/codesign ]] || die "需要 macOS 自带的 ditto、curl、plutil、file 和 codesign。"

  dest=$(resolve_dest "$dest")
  if same_bundle_is_running "$dest"; then
    die "这个位置的京时正在运行，或无法确认正在运行的 BeijingClock 是否就是它。请先从弹出层或设置窗口退出，然后重新运行安装。脚本不会结束进程。"
  fi

  make_temp
  local staged="$TMP_ROOT/BeijingClock-1.0.1-arm64.app.zip"
  if [[ -n "$zip_path" ]]; then
    cp -p -- "$zip_path" "$staged"
  else
    if [[ -z "$zip_url" ]]; then
      zip_url=$DEFAULT_ZIP_URL
    fi
    download_zip "$zip_url" "$staged"
  fi
  verify_zip_file "$staged"

  local extract="$TMP_ROOT/extract"
  mkdir -p -- "$extract"
  /usr/bin/ditto -x -k -- "$staged" "$extract"
  assert_tree_contained "$extract"
  assert_our_plist "$extract/BeijingClock.app/Contents/Info.plist" 1
  assert_arm64_binary "$extract/BeijingClock.app/Contents/MacOS/BeijingClock"

  install_bundle "$extract/BeijingClock.app" "$dest"
  assert_our_plist "$dest/Contents/Info.plist" 1

  cat <<EOF
已安装到：${dest}
没有启动应用，没有请求通知，没有修改登录项、时区或系统安全设置。
闹钟数据仍在原来的位置，脚本没有读取或删除：\$HOME/Library/Application Support/BeijingClock

要打开时，请你自己执行：
  open "${dest}"

这个包是 ad-hoc 签名，没有公证。若门禁拦截，先按上面的命令尝试打开，然后在一小时内打开「系统设置 → 隐私与安全性」，点「仍要打开」，再按提示点「打开」并输入登录密码。
说明：
  https://support.apple.com/zh-cn/guide/mac-help/mh40616/mac
  https://support.apple.com/zh-cn/102445
EOF
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
