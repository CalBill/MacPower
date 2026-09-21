# MacPower

<p align="center">
  <img src="docs/readme/icon.png" width="96" alt="MacPower">
</p>

中文 | [English](README.en.md)

MacBook 菜单栏电池监视器。不进 Dock，点开后是 **Liquid Glass** 监控面板：能量流向、系统圆环、续航或充满时间，外观与动效都可自定义。

## 预览

<table>
  <tr>
    <td align="center" width="33%"><img src="docs/readme/flow-discharging.png" alt="电池给电脑 · 粒子"><br><b>电池 → 电脑</b> · 粒子</td>
    <td align="center" width="33%"><img src="docs/readme/flow-adapter-hold.png" alt="电源给电脑 · 渐变"><br><b>电源 → 电脑</b> · 渐变</td>
    <td align="center" width="33%"><img src="docs/readme/flow-underpowered.png" alt="电源和电池给电脑 · 细线 · 高对比"><br><b>电源 + 电池 → 电脑</b> · 细线 · 高对比</td>
  </tr>
  <tr>
    <td align="center"><img src="docs/readme/flow-charging.png" alt="电源给电池和电脑 · 滑动"><br><b>电源 → 电池 + 电脑</b> · 滑动</td>
    <td align="center"><img src="docs/readme/flow-discharging-smooth.png" alt="电池给电脑 · 柔和 · 细线"><br><b>电池 → 电脑</b> · 柔和 · 细线</td>
    <td align="center"><img src="docs/readme/flow-charging-off.png" alt="电源给电池和电脑 · 无动效"><br><b>电源 → 电池 + 电脑</b> · 无动效</td>
  </tr>
</table>

## 功能

- 菜单栏 Liquid Glass 监控面板（能量流向、电量 / CPU / GPU / 内存圆环、续航或充满时间）
- 高度可自定义：配色预设、图标套装、动效样式、菜单栏电池外观等
- 不进 Dock；可选登录时启动、自动检查更新
- 多语言：简体中文、繁体中文、English、日本語、한국어、Français、Deutsch、Español、Português (Brasil)、Italiano、Русский（设置里可跟随系统或单独切换）

## 安装

1. 从 [Releases](https://github.com/RyanStarFox/MacPower/releases) 下载最新的 `MacPower-*.dmg`，打开后把 **MacPower** 拖进 **应用程序**。
2. **修复损坏**（Release 为 ad-hoc 签名、未公证，下载后系统常会隔离）：

```bash
sudo xattr -rd com.apple.quarantine /Applications/MacPower.app
```

在「终端」中粘贴运行；输入密码时屏幕不会显示圆点，输完直接回车即可。
3. 打开 **系统设置 → 菜单栏**，确保允许 **MacPower** 在菜单栏中显示，然后从「应用程序」启动。

## 运行要求

- macOS 14 或更高（在 macOS 26+ 上使用 Liquid Glass；14/15 为材质回退）
- 带电池的 Apple 芯片 MacBook

## 从源码编译

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project MacPower.xcodeproj -scheme MacPower -configuration Release -destination 'platform=macOS' build
```

重新制作 Release 磁盘镜像：

```bash
./scripts/make_dmg.sh
```

生成的 `.dmg` 在 `dist/`。

## 许可证

本项目采用 MIT License，并附加 Commons Clause。允许免费使用、修改和分发，但不得销售本软件，或通过主要依赖本软件功能的产品或服务获利。详见 [LICENSE](LICENSE)。
