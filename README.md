# 京时（BeijingClock）

菜单栏里的北京时间时钟。时间固定用 `Asia/Shanghai`，不随系统时区改变。可以保存多个闹钟，钟点一律按北京时间。应用只显示在菜单栏（`LSUIElement`），不占程序坞图标。

这是离线应用：不联网，没有遥测，不修改系统时区，也不把自己加进登录项。

## 现在哪一份能安装

| 位置 | 状态 |
| --- | --- |
| 分支 `cursor/sync-beijingclock-1.0.1-c298` | 有源码、测试、构建脚本和下面的安装包 |
| `main` | 仍是仓库最初的一行说明。合并本分支之前，`main` 上没有安装包，不能用 `main` 的地址下载或安装 |

安装包文件：

`downloads/BeijingClock-1.0.1-arm64.app.zip`

- 大小：180157 字节（约 180 KB）
- SHA256：`b99c7489eed4cc404db217b01045e2f29c9152f836e2e936194b4d7e350f3be0`
- 架构：Apple Silicon arm64（M1、M2、M3、M4 等）
- 版本：1.0.1（构建号 2）
- 签名：ad-hoc，未公证
- 安装这个 zip 不需要 Xcode，也不需要 Homebrew

在本分支合并进 `main` 之前，请使用下面这个已经包含安装包的提交，或本分支上的同一文件。不要把地址里的提交号或分支名换成 `main`。

固定提交 `0df21739a8b26aee90eb99387f6a26bc4a016557`：

```text
https://raw.githubusercontent.com/rengs/BeijingClock/0df21739a8b26aee90eb99387f6a26bc4a016557/downloads/BeijingClock-1.0.1-arm64.app.zip
```

同一文件的分支地址：

```text
https://raw.githubusercontent.com/rengs/BeijingClock/cursor/sync-beijingclock-1.0.1-c298/downloads/BeijingClock-1.0.1-arm64.app.zip
```

页面：

```text
https://github.com/rengs/BeijingClock/blob/0df21739a8b26aee90eb99387f6a26bc4a016557/downloads/BeijingClock-1.0.1-arm64.app.zip
```

仓库说明的分支页面：

```text
https://github.com/rengs/BeijingClock/blob/cursor/sync-beijingclock-1.0.1-c298/README.md
```

没有另发 Release，也没有标签。上面的文件在仓库里，下载前可以用 SHA256 对上。

## 名称

| 用途 | 值 |
| --- | --- |
| 显示名 | 京时 |
| 英文名 / 可执行文件 / App 文件名 | BeijingClock，打包后是 `BeijingClock.app` |
| Bundle ID | `local.beijingclock.jingshi` |
| 版本 | 1.0.1 |
| 构建号 | 2 |

`local.` 开头表示这是本应用自己的本地标识，不是已注册域名，也不冒用 Apple 或其他组织的标识。通知和强制退出里看到的名字是「京时」。

## 能在哪些 Mac 上使用预编译包

当前这份 zip 只包含 arm64。Apple Silicon（M1、M2、M3、M4 以及同架构的后续芯片）可以使用。

Intel 版本没有提供，也没有验证。

`Packaging/Info.plist` 的 `LSMinimumSystemVersion` 和 `Package.swift` 的 deployment target 写的是 macOS 13。这只说明编译时的最低目标。已记录的编译和界面确认发生在 macOS 26.3 的 Apple Silicon Mac 上，没有在 macOS 13 上做运行实测，因此这里不能承诺 macOS 13 已经跑过。

## 已记录的 Mac 验证

下面是此前在一台 Apple Silicon Mac 上留下的结果。同步这份仓库时的环境是 Linux，没有在 Linux 上启动京时，也没有重新编译，Swift 源码相对那次验证没有改动。

| 项目 | 记录 |
| --- | --- |
| 系统 | macOS 26.3，arm64，Apple M2 |
| 工具 | Xcode 26.6，Swift 6.3.3，SDK 26.5 |
| 测试 | XCTest 27 项通过：`BeijingTimeCoreTests` 23 项，`LaunchAcceptanceTests` 4 项 |
| 产物 | 版本 1.0.1，构建号 2；ad-hoc `codesign` 校验通过 |
| 界面 | 用户亲自确认设置窗口和菜单栏都看得到 |
| 未测 | 闹钟声音、通知 |
| 未验证 | Intel；macOS 13 的实际运行 |

那 27 项测试的名字是：

`BeijingTimeCoreTests`：`testShanghaiOffsetHasNoDaylightSaving`，`testLosAngelesConversionDoesNotUseHostZone`，`testBeijingMidnightIsNextCivilDay`，`testInvalidCivilDatesAreRejected`，`testEmptyTitleBecomesDefault`，`testAddingDaysRollsMonthAndYear`，`testDailyAndOnceNextOccurrenceAroundBeijingMidnight`，`testDocumentedPolicyBounds`，`testCatchUpMissedAndExpiredBoundaries`，`testDuplicateRefreshAndRestartDoNotRingAgain`，`testWakeWithinCatchUpRingsOnce`，`testEditingTimeCanRingNewOccurrenceAndDeleteRemovesIt`，`testReenableOnceDoesNotRepeatHandledOccurrence`，`testUpcomingUsesNextBeijingDateAndHidesHandled`，`testDisabledAlarmIsNotDueOrUpcoming`，`testClockDefaultsOmitBeijingMarkAndUseTwentyFourHourDigits`，`testMenuBarDateFollowsBeijingNotLosAngeles`，`testFollowLocaleTimeUsesShanghaiZone`，`testPopoverClockIsAlwaysBeijingTwentyFourHour`，`testFontSizeClamp`，`testStoreRoundTripEditDeleteAndCorruptFile`，`testAlarmCap`，`testPruneDropsOldHandledRecords`。

`LaunchAcceptanceTests`：`testLauncherWindowOpensOnStartAndReopenEvenWhenStatusItemLooksFine`，`testEmptyMenuBarTitleDoesNotCollapseTheStatusItem`，`testMarketingVersionIs101`，`testStartupSourceDoesNotUseBareNSApplicationMain`。

同步这份仓库时，又在 Linux x86_64 上用 Swift 6.2.1 执行了 `swift test`。上面列出的 27 项再次通过（23 项核心，4 项启动策略和静态检查），宿主时区是 UTC。这次没有编译或启动 Mac 应用，没有做签名校验，也没有测试闹钟声音和通知。它是源码测试的另一次结果，不能代替 macOS 26.3、Xcode 26.6 那次记录。

## 安装这个预编译包

安装不需要 Xcode，不需要 Homebrew，也不要使用 sudo。包大约 180 KB。默认放到当前用户自己的应用程序目录：`$HOME/Applications/BeijingClock.app`。系统级「应用程序」目录不需要写权限。

脚本在 `scripts/install-macos.sh`。它会：

- 只在 macOS 且 `uname -m` 为 `arm64` 时安装，其他架构直接停止
- 接受本地已经下载的 zip，或从本仓库上述真实地址下载到文件后再读
- 核对大小和 SHA256，并检查 zip 成员都在 `BeijingClock.app/` 内，拒绝绝对路径、`..` 和符号链接
- 在 `mktemp` 建立的临时目录里解开，结束时只删除这个临时目录
- 若目的地已有应用，先确认 Bundle ID 是 `local.beijingclock.jingshi`，再把旧的整包改名备份
- 发现这个位置的京时正在运行时，提示先退出，不结束进程
- 安装后做 ad-hoc 签名校验
- 到此停止。不自动打开，不请求通知，不触发闹钟，不修改登录项、时区或系统安全设置，不删除 `~/Library/Application Support/BeijingClock` 里的闹钟数据

请先把脚本和说明读一遍，再执行文件，不要把下载内容管道交给 shell。

最短的做法：

```bash
uname -m
# 这里要看到 arm64

mkdir -p "$HOME/src"
cd "$HOME/src"

curl -fL --proto '=https' --output BeijingClock-1.0.1-arm64.app.zip \
  'https://raw.githubusercontent.com/rengs/BeijingClock/0df21739a8b26aee90eb99387f6a26bc4a016557/downloads/BeijingClock-1.0.1-arm64.app.zip'

curl -fL --proto '=https' --output install-macos.sh \
  'https://raw.githubusercontent.com/rengs/BeijingClock/cursor/sync-beijingclock-1.0.1-c298/scripts/install-macos.sh'

shasum -a 256 BeijingClock-1.0.1-arm64.app.zip
# 必须是 b99c7489eed4cc404db217b01045e2f29c9152f836e2e936194b4d7e350f3be0

# 打开 install-macos.sh 看完，再执行
chmod +x install-macos.sh
./install-macos.sh --check-zip ./BeijingClock-1.0.1-arm64.app.zip
./install-macos.sh --zip ./BeijingClock-1.0.1-arm64.app.zip
```

也可以先克隆这个分支，在仓库里核对校验文件后安装：

```bash
git clone --branch cursor/sync-beijingclock-1.0.1-c298 --single-branch \
  https://github.com/rengs/BeijingClock.git
cd BeijingClock
cd downloads
shasum -a 256 -c BeijingClock-1.0.1-arm64.app.zip.sha256
cd ..
./scripts/install-macos.sh --zip downloads/BeijingClock-1.0.1-arm64.app.zip
```

只想让脚本自己下载仓库里的那一份时，在确认脚本内容之后执行 `./scripts/install-macos.sh`。脚本里的地址是提交 `0df21739a8b26aee90eb99387f6a26bc4a016557` 上的 zip，不是 `main`。

校验值已经一致时，也可以不用脚本，自己解开已知的这份 zip：

```bash
uname -m
# arm64

tmp=$(mktemp -d "${TMPDIR:-/tmp}/beijingclock-install.XXXXXX")
ditto -x -k "$HOME/src/BeijingClock-1.0.1-arm64.app.zip" "$tmp"
plutil -extract CFBundleIdentifier raw -o - "$tmp/BeijingClock.app/Contents/Info.plist"
# local.beijingclock.jingshi

mkdir -p "$HOME/Applications"
# 若 $HOME/Applications/BeijingClock.app 已在，先确认它是京时，再整包改名备份
ditto "$tmp/BeijingClock.app" "$HOME/Applications/BeijingClock.app"
rm -rf "$tmp"

# 下面这一行由你决定要不要运行。安装步骤本身不要自动打开。
# open "$HOME/Applications/BeijingClock.app"
```

`mktemp` 打印出来的那个目录，才是可以删的临时目录。

## 第一次打开和门禁

打开后没有程序坞图标。设置窗口会在每次启动时出现，在 Finder 里再次打开已经在运行的京时也会把设置窗口带到前面。菜单栏里是北京时间文字。菜单栏太挤时，系统可能把这一项藏起来；设置窗口不依赖菜单栏有没有空位。

这份应用是 ad-hoc 签名，没有经过 Apple 公证，门禁（Gatekeeper）可能拦截。Apple 对「打开来自未知开发者的 Mac App」的说明是：

1. 先尝试打开该应用。
2. 打开「系统设置 → 隐私与安全性」。若刚被拦截，安全性一节会出现打开这一个应用的操作。
3. 点「打开」或「仍要打开」。这个按钮在尝试打开后的一小时内可用。
4. 按提示输入登录密码，再点「好」或「打开」。

官方说明：

- [打开来自未知开发者的 Mac App](https://support.apple.com/zh-cn/guide/mac-help/mh40616/mac)
- [在 Mac 上安全地打开 App](https://support.apple.com/zh-cn/102445)

Apple 写明：覆盖安全设置去打开未经审核的应用，是 Mac 遭恶意软件入侵的常见方式；更稳妥的来源是 Mac App Store 或你信任的开发者。京时不是 App Store 应用。只有在你确认文件的 SHA256 就是上面这一串、并且接受这个风险时，才使用上面的系统设置路径。批准之后，macOS 会把这一份应用记为例外，以后可以正常双击打开。

## 菜单栏

普通菜单栏应用不能保证排在系统时钟右边，也不能自动读取全部系统时钟偏好。京时提供对应选项，位置以 macOS 允许为准。

`NSStatusBar.statusItem(withLength:)` 没有“插到系统时钟右侧”的公开参数。系统时钟属于控制中心。本应用不使用私有 API，不注入其他进程，不替换系统时钟，不用辅助功能改菜单栏，也不写入菜单位置或系统偏好。启动时用公开的 `isVisible = true` 请求显示。1.0.1 不设置 `autosaveName`，避免系统恢复隐藏状态后图标一直不出现。

若系统允许，可以按住 Command 拖动「京时」的菜单栏文字。能否放到系统时钟右边、以及和系统时钟是否像素一致，都不保证。

默认外观接近常见系统时钟：

- 使用系统菜单栏字体和字号，不自定颜色
- 默认显示星期，不显示日期和秒
- 小时制默认「跟随语言区域」，只用公开的 `Locale` / `DateFormatter`
- 文字可以跟随系统语言，也可以改成简体中文
- 默认不在状态栏写「北京」。弹出层始终标明「北京时间」，并用 24 小时制显示到秒
- 需要区分两个时钟时，可打开「状态栏末尾显示北京」
- 自定字号限制在 10–14，并再按菜单栏高度缩小
- 「闪烁分隔符」只是近似，不能与系统时钟同步，默认关闭

点菜单栏文字，弹出层显示大号北京时间和即将到来的闹钟，并可打开设置。

## 闹钟

每个闹钟有标题、北京时间的时和分、开关，以及「每天」或「仅一次」。仅一次另外保存北京公历年月日。编辑器里的日期和钟点标着北京时间，即使用户的系统时区不是上海。

应用运行中大约每秒检查一次，睡眠唤醒后再查一次。补响界限来自 `AlarmPolicy.standard`：

| 迟到 | 行为 |
| --- | --- |
| 0 到 3 分钟（含） | 响铃。应用内窗口加系统提示音，提示音最长 60 秒，可停止 |
| 超过 3 分钟、不满 12 小时 | 不循环响铃。应用内提示一次，并在已经授权通知时发一条通知 |
| 12 小时及以上 | 静默标记为已处理，避免睡了很多天之后一次弹出一串 |

同一次发生（闹钟编号 + 北京日期 + 时分）记入本地文件后，刷新或重启都不会再处理。单次闹钟在响铃、错过或过期后关闭；只重新打开开关、不改时间，也不会再响。每天的闹钟保持开启，过了北京零点后下一次算到新的一天。修改时分或日期会变成新的一次发生。

通知是可选的，只有在设置里由你请求并允许之后才会发。通知本身不播放声音，避免和应用窗口里的提示音叠在一起。拒绝通知时，仍然使用应用内窗口和提示音。闹钟声音和通知没有在已记录的 Mac 验证里实测。

京时必须保持运行，而且 Mac 处于唤醒状态，才会刷新时间和响铃。退出之后不会响。它不能在睡眠中把电脑叫醒。醒来后按上面的迟到表处理已经错过的发生。它不会把自己加进登录项，也不修改系统时区或睡眠设置。

数据写在 `~/Library/Application Support/BeijingClock/state.json`。保存使用原子写入。文件损坏或版本不符时，会把原文件改名为 `state.bad-….json` 并从空白状态开始。已处理记录保留 14 天。最多 100 个闹钟。安装和卸载之外的操作都不会删除这个目录。

## 从源码构建

源码构建需要你自己的 Mac 和 Xcode。请在 Xcode 要求时自行接受许可协议。`scripts/build-macos.sh` 和 `scripts/run-tests.sh` 不会下载工具链，不会用 sudo 安装工具，不会把应用拷进应用程序目录，也不会加入登录项。

`Package.swift` 的工具版本是 Swift 5.9。产出这份 1.0.1 安装包时实际使用的是 Xcode 26.6 / Swift 6.3.3。脚本在找不到 `swift` 时会提示安装 Xcode，然后停止。

```bash
chmod +x scripts/build-macos.sh scripts/run-tests.sh
./scripts/run-tests.sh
./scripts/build-macos.sh
```

成功后得到 `dist/BeijingClock.app`（这个目录不进入 git）。脚本在有 `codesign` 时做 ad-hoc 签名。这不是 Developer ID，也没有公证。默认架构是 arm64。Intel 没有在已记录的环境里验证。

启动后如果要确认委托和状态项有没有创建，可以在 Mac 上查看统一日志。日志只有生命周期标记，没有路径或闹钟标题：

```bash
log show --predicate 'subsystem == "local.beijingclock.jingshi"' --last 5m
```

## 卸载

1. 从弹出层或设置窗口里选择「退出」。
2. 在 Finder 里只把这一份 `BeijingClock.app` 放进废纸篓。默认路径是 `~/Applications/BeijingClock.app`。若安装时用 `--dest` 改过位置，就移那一个包。不要动其他应用。
3. 可选：若要同时去掉闹钟和显示设置，只把 `~/Library/Application Support/BeijingClock` 这一个文件夹放进废纸篓。
4. 若曾经允许通知，可在「系统设置 → 通知」里去掉「京时」。

安装时没有添加登录项，也不需要改时区或睡眠。卸载时不要对主目录或资源库使用带通配符的删除。

## 桌面小组件

这是 macOS 14 及以上的 WidgetKit 扩展，放在桌面或通知中心，不是一扇浮动窗口。菜单栏应用的最低系统版本仍是 macOS 13。macOS 13 上看不到这个小组件。

`downloads/BeijingClock-1.0.1-arm64.app.zip` 是不含小组件的菜单栏包，大小 180157 字节，SHA256 仍是 `b99c7489eed4cc404db217b01045e2f29c9152f836e2e936194b4d7e350f3be0`。不要把那份 zip 当成已经带有双环。

界面是一个系统圆角卡片里的一个圆盘。外圈和内圈共用圆心，不是并排或上下两只钟。外圈固定 `Asia/Shanghai`，00 在正上方，顺时针，一圈 24 小时。北京早 8 点在 120 度，用方块刻度和「早8」标出，不单靠颜色。内圈默认 `America/Los_Angeles`。同一条半径是同一个绝对时刻：示例里北京 08:00 的半径上，冬令时内圈是前一日 16:00，夏令时是前一日 17:00。环表示此刻所在的一个北京公历日，不是以现在为中心滚动的 24 小时。夏令时切换日上，内圈偏移会变，缺失或重复的钟点按那个瞬间的真实读数画，不把一个时差套到整天。

样式靠近 macOS 的时钟小组件，但不是那只世界时钟。参考的是 Apple 公开说明，不是像素临摹：

- [在 Mac 上的时钟中查看时间](https://support.apple.com/guide/clock-mac/check-the-time-apdw7dec11e7/mac)：系统有 City 和 World Clock 小组件，编辑方式是 Control-click 后选 Edit “Clock”。世界时钟是多个城市的表盘，京时不采用这个排列。
- [在 Mac 上添加和自定义小组件](https://support.apple.com/guide/mac-help/add-and-customize-widgets-mchl52be5da5/mac)：桌面小组件由系统加圆角卡片；小组件风格可以是自动、单色或全彩。
- [Preparing widgets for additional contexts and appearances](https://developer.apple.com/documentation/widgetkit/preparing-widgets-for-additional-contexts-and-appearances)：`fullColor`、`accented`、`vibrant`。文字和时间使用系统字体与 primary / secondary / tertiary，数字在 macOS 15 及以上标成可着色。
- [Displaying the right widget background](https://developer.apple.com/documentation/widgetkit/displaying-the-right-widget-background)：背景放在 `containerBackground(_:for: .widget)` 里，让系统在需要时拿掉。这里用的是系统 `.background`，不自绘一块灰板。

和系统世界时钟的真实差别：京时只有一个圆盘、两圈 24 小时，名称是「京时双环」，没有 Apple 标志，也没有把多个城市并排。圆角和单色/全彩由系统处理。这台环境没有对照官方截图像素验收。

时区记在系统的小组件实例配置里。应用不另存一份，不用 App Group，不改系统时区，也不因此响铃或请求通知。时间线大约每 15 分钟一条，向前约 6 小时，并在这窗口里的夏令时切换点加一条。系统可以再推迟刷新。

设计预览只画一个小组件，示例时刻是 2024-01-15 北京 08:00。它是代码绘制的，不是系统截图，也不能代替 Mac 验收：

`docs/widget-design-preview.png`

在自己的 Mac 上编译扩展：

```bash
chmod +x scripts/build-macos.sh scripts/build-widget-macos.sh
./scripts/build-macos.sh
./scripts/build-widget-macos.sh
```

第一条先做出还没有扩展的菜单栏 App，并给那个宿主做一次 ad-hoc 签名。第二条编译扩展、复制进 `Contents/PlugIns`，然后才由内向外重新签名：先签 `BeijingClockWidget.appex`（带 App Sandbox entitlement），再签宿主。签名用的是 `codesign --sign -`，不用 `--deep` 代替逐层签名，也不使用开发者证书。复制完成之后，脚本要求扩展和宿主的 `--verify --strict`，以及宿主的 `--verify --deep --strict` 都成功；任一失败则脚本以非 0 结束。

这个顺序来自一次真实构建：在 `bb06264158b1729877fe9cf657cd64ba00b9c500` 上，脚本当时先签宿主再嵌入扩展，脚本退出码是 0，但整包 `codesign --verify` 退出码是 1。扩展自己的 ad-hoc 校验可以通过。按先扩展、后宿主补签之后，`--strict` 和 `--deep --strict` 都是 0。Apple 的 [TN2206](https://developer.apple.com/library/archive/technotes/tn2206/_index.html) 要求嵌套代码由内向外签。`codesign` 手册把 `--deep` 当作不推荐的签名方式，因为同一组选项会被套到所有嵌套代码上；它可以用来复查，不能代替逐层签名。

签名分两件事，不要混在一起：

- 本机 ad-hoc 只让同一台 Mac 上的 `codesign --verify` 能认出这个包。它不是 Developer ID，也没有公证。
- 对外分发、让门禁（Gatekeeper）接受从网络下载的应用，Apple 要求 Developer ID 签名并公证。说明见 [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)。`spctl` 拒绝 ad-hoc 包，符合「未公证、也不是 Developer ID」这个事实。不能由此推断只有公证才能做开发时的小组件图库试验，也没有人在这台机器上打开过图库，所以不能保证图库或桌面可用。

在 iMac（arm64，macOS 27.0 / 26A428，Xcode 27.2 / 27B52，Swift 6.4.2，SDK 27.2）上，对 `bb06264` 的源码测得 XCTest 36 项全部通过。宿主是 1.0.1、构建号 2、最低系统版本 13；扩展是 1.0.1、构建号 2、最低系统版本 14，并且带有 App Sandbox。那次没有做界面、图库或桌面验收。此提交改了视图和打包脚本，那次结果不覆盖新的提交，需要按新的 SHA 重新编译。本仓库的 Linux 环境没有 macOS SDK，没有编译扩展，也没有看见图库。

添加和修改：

1. 用带 `PlugIns/BeijingClockWidget.appex` 的应用，先打开一次京时。
2. 在桌面空白处或通知中心打开小组件图库，找「京时双环」。建议中号、大号或超大号。
3. 编辑这个小组件，改「内圈时区」。非法或空的标识会回到洛杉矶。
4. 刷新交给系统。退出京时不会按秒重画小组件。

若图库没有这一项，先看扩展是否真的在 App 包里，以及 `codesign --verify --strict` 是否通过。未验证：图库出现、桌面放置、深色外观的实际像素、以及 ad-hoc 签名能否被 pluginkit 接受。

## 源码

- `Sources/BeijingTimeCore/`：时区、菜单栏格式、闹钟、调度、JSON 存储，以及双环的纯时间计算。不依赖 AppKit，测试覆盖这里。
- `Sources/BeijingClock/`：macOS 菜单栏、弹出层、设置、闹钟窗口和可选通知。
- `Sources/BeijingClockWidget/`：macOS 14 的 WidgetKit 扩展视图和时间线。Swift Package 不产出这个扩展。
- `WidgetExtension/`：扩展的 Xcode 工程、`Info.plist` 和 App Sandbox entitlement。
- `Packaging/Info.plist`：`LSUIElement`、显示名「京时」、Bundle ID、版本 1.0.1、构建号 2，最低系统版本 13.0。
- `scripts/build-macos.sh`：只在 macOS 上编译并组装菜单栏 App。
- `scripts/build-widget-macos.sh`：只在 macOS 上编译 Widget 扩展。
- `scripts/run-tests.sh`：运行 Swift 测试，不下载编译器。
- `scripts/install-macos.sh`：校验并安装本仓库的 arm64 zip。
- `Tests/BeijingTimeCoreTests/`：原有时间与闹钟测试，加上双环、夏令时和小组件时间线预算。
- `downloads/`：版本化的预编译 zip 和 SHA256。仓库里不提交解开的 `.app`。这份 zip 没有小组件。
- `docs/widget-design-preview.png`：单个小组件的同心环设计预览，不是系统截图。
