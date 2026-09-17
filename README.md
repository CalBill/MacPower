# MacPower

English | [中文](#macpower-中文)

A native menu-bar battery monitor for MacBook. It stays out of the Dock, shows charge and charging state in the menu bar, and opens a Liquid Glass panel with live energy flow plus remaining runtime or time-to-full.

Unofficial. Not affiliated with Apple. Not a charge limiter.

## Features

- Menu bar only (`LSUIElement`): no Dock icon
- Three icon styles: system fill, percent inside the battery, classic percent beside it
- Optional charging bolt / plugged-in plug on all three styles
- Popover with live watts: charger, battery, and Mac, including a Y-split while charging
- **On battery:** estimated remaining runtime  
  **Plugged in:** estimated time to full
- Colors follow energy state (green charging, orange discharging, blue holding / underpowered)
- Optional low-battery yellow / red tint at 20% and 10%
- Appearance palettes, light / dark, English and Simplified Chinese
- Open at login

## Install (GitHub Release)

1. Download `MacPower-1.0.0.dmg` from [Releases](https://github.com/RyanStarFox/MacPower/releases).
2. Open the disk image and drag **MacPower** into **Applications**.
3. Launch it from Applications. Look for the battery in the menu bar.

The Release build is **ad-hoc signed, not Developer ID notarized**. Other people’s Macs will usually quarantine it after download. If macOS says the app is **damaged** or cannot be opened, run:

```bash
sudo xattr -rd com.apple.quarantine /Applications/MacPower.app
```

Then open MacPower again.

A Developer ID + notarized build would skip this step. This project currently only has an Apple Development certificate, which cannot be used to distribute to other Macs (and often *causes* the “damaged” dialog if you ship it). Until a Developer ID is available, the unsigned/ad-hoc DMG plus the `xattr` command is the honest option.

## Requirements

- macOS 26 or later (developed on macOS 27)
- Apple Silicon MacBook with a battery

## Build from source

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project MacPower.xcodeproj -scheme MacPower -configuration Release -destination 'platform=macOS' build
```

To rebuild the GitHub Release disk image:

```bash
./scripts/make_dmg.sh
```

The `.dmg` lands in `dist/`.

## License

MIT. See [LICENSE](LICENSE).

---

# MacPower (中文)

MacBook 菜单栏电池监视器。不进程序坞，在菜单栏显示电量和充放电状态，点开后是 Liquid Glass 面板：实时能量流向，以及续航或充满时间。

非官方应用，与 Apple 无关，也不是充电限制工具。

## 功能

- 只在菜单栏（`LSUIElement`），没有 Dock 图标
- 三种图标：系统风填充、电池内百分比、旁边经典百分比
- 可开关充电闪电 / 插电插头，三种样式都生效
- 弹层显示充电器、电池、电脑的实时功率；充电时为 Y 形分流
- **拔电：** 预计续航  
  **插电：** 预计充满
- 颜色跟能量状态走（充电绿、放电橙、插电维持/功率不够为蓝）
- 可选低电量着色：20% 黄、10% 红
- 多套配色、浅色/深色、简体中文与英文
- 登录时启动

## 安装（GitHub Release）

1. 从 [Releases](https://github.com/RyanStarFox/MacPower/releases) 下载 `MacPower-1.0.0.dmg`。
2. 打开镜像，把 **MacPower** 拖进 **应用程序**。
3. 从应用程序里打开，菜单栏会出现电池图标。

Release 里的包是 **ad-hoc 签名，没有走 Developer ID 公证**。别人下载后，系统几乎一定会加上隔离属性。如果提示 **App 已损坏** 或无法打开，在终端运行：

```bash
sudo xattr -rd com.apple.quarantine /Applications/MacPower.app
```

然后再打开 MacPower。

如果用 Developer ID 签名并公证，这一步可以省掉。目前只有 Apple Development 证书，不能用来给别人分发（用它打包，对方更容易看到「已损坏」）。在有 Developer ID 之前，Release 放未公证/ad-hoc 的 DMG，并写明上面这行 `xattr` 命令。

## 运行要求

- macOS 26 或更高（在 macOS 27 上开发）
- 带电池的 Apple 芯片 MacBook

## 从源码编译

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project MacPower.xcodeproj -scheme MacPower -configuration Release -destination 'platform=macOS' build
```

重新制作 Release 用的磁盘镜像：

```bash
./scripts/make_dmg.sh
```

生成的 `.dmg` 在 `dist/`。

## 许可证

MIT，见 [LICENSE](LICENSE)。
