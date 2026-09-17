# MacPower

![MacPower](docs/readme/icon.png)

中文 | [English](README.en.md)

MacBook 菜单栏电池监视器。不进程序坞，在菜单栏显示电量和充放电状态，点开后是 Liquid Glass 面板：实时能量流向，以及续航或充满时间。

## 能量流向

四种胶囊形态，随充放电状态切换：


|                                                             |                                                         |
| ----------------------------------------------------------- | ------------------------------------------------------- |
| ![电池给电脑](docs/readme/flow-discharging.png) **电池给电脑**        | ![电源给电脑](docs/readme/flow-adapter-hold.png) **电源给电脑**   |
| ![电源和电池给电脑](docs/readme/flow-underpowered.png) **电源和电池给电脑** | ![电源给电池和电脑](docs/readme/flow-charging.png) **电源给电池和电脑** |




## 功能

- 只在菜单栏（`LSUIElement`），没有 Dock 图标
- 六种图标：填充 / 电池内百分比 / 旁注百分比，以及对应的边框版
- 可开关充电标志（闪电），各样式都生效
- 弹层显示充电器、电池、电脑的实时功率；充电时为 Y 形分流
- 电量 / CPU / GPU / 内存圆环，以及续航或充满时间
- 能量流动画：白色高光，渐变/彩色/白色细线与粒子，可关；粒子/细线帧率 15–120 Hz
- 可开关面板箭头；隐藏后贴紧菜单栏
- **拔电：** 预计续航  
**插电：** 预计充满
- 颜色跟能量状态走（充电绿、放电橙、插电维持/功率不够为蓝）
- 可选低电量着色：20% 黄、10% 红
- 多套配色、浅色/深色；11 种语言，设置里即时切换
- 登录时启动
- 可自动检查 GitHub 更新；设置底部显示版本号和 GitHub 标志



## 安装（GitHub Release）

1. 从 [Releases](https://github.com/RyanStarFox/MacPower/releases) 下载 `MacPower-1.2.6.dmg`。
2. 打开镜像，把 **MacPower** 拖进 **应用程序**。
3. 从应用程序里打开，菜单栏会出现电池图标。



## 修复损坏

Release 里的包是 **ad-hoc 签名，没有走 Developer ID 公证**。别人下载后，系统几乎一定会加上隔离属性。如果提示 **App 已损坏** 或无法打开，再按下面做：

1. 按下 **Command（⌘）+ 空格**，在 Spotlight 里搜索 **终端**，打开它。
2. 复制下面整行指令，粘贴到终端里，按下 **Enter / Return**：

```bash
sudo xattr -rd com.apple.quarantine /Applications/MacPower.app
```

3. 终端会要求输入这台 Mac 的登录密码。输入时**屏幕上不会出现圆点或星号**，这是正常现象，不是没有输入成功。输完直接按 Enter。

然后再从「应用程序」打开 MacPower。

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
