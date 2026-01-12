# MacTools

<p align="center">
  <img src="MacTools/Assets.xcassets/AppIcon.appiconset/icon-128@2x.png" width="128" height="128" alt="MacTools Icon">
</p>

<p align="center">
  <strong>一款简洁实用的 macOS 效率工具集</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS-blue.svg" alt="Platform">
  <img src="https://img.shields.io/badge/Swift-5.9+-orange.svg" alt="Swift">
  <img src="https://img.shields.io/badge/SwiftUI-✓-green.svg" alt="SwiftUI">
</p>

---

## ✨ 功能特性

### 🚀 Dock 切换

模拟 Windows 任务栏行为：**点击 Dock 图标时，如果该应用窗口已聚焦，则自动最小化窗口**。

告别反复点击 Dock 图标却无法最小化的困扰！

### 📐 窗口调整

通过快捷键快速调整任意窗口到预设尺寸：

- 默认快捷键：`⌘ + ⇧ + W`
- 支持自定义快捷键
- 支持自定义预设尺寸列表
- 可视化窗口选择器，支持窗口缩略图预览

### ⚙️ 通用设置

- 🔄 开机自启动
- 🎯 菜单栏常驻图标（左键打开设置，右键退出）
- 👁️ 可选在 Dock 中显示图标
- 🔐 权限状态检测与快速跳转授权

---

## 🔧 系统要求

- macOS 13.0 (Ventura) 或更高版本
- 需要以下系统权限：
  - **辅助功能权限** - 用于监听全局事件和控制窗口
  - **屏幕录制权限** - 用于获取窗口缩略图

---

## 📦 安装

### 方式一：直接下载

从 [Releases](../../releases) 页面下载最新版本的 `.dmg` 或 `.app` 文件。

### 方式二：源码编译

```bash
# 克隆仓库
git clone https://github.com/HT3301601278/MacTools.git

# 打开项目
cd MacTools
open MacTools.xcodeproj

# 在 Xcode 中编译运行（⌘ + R）
```

---

## 🚀 使用指南

### 首次启动

1. 启动应用后，系统会提示授予**辅助功能权限**
2. 前往「通用」设置页面，点击「去授权」授予**屏幕录制权限**
3. 权限授予后，所有功能即可正常使用

### Dock 切换

- 在「Dock」设置页面启用功能
- 点击 Dock 中已聚焦应用的图标，窗口将自动最小化

### 窗口调整

1. 在「窗口」设置页面启用功能
2. 按下快捷键（默认 `⌘ + ⇧ + W`）
3. 在弹出的窗口选择器中点击目标窗口
4. 选择预设尺寸，窗口将自动调整

### 自定义快捷键

1. 进入「窗口」设置页面
2. 点击当前快捷键按钮
3. 按下新的快捷键组合（需包含 ⌘/⌃/⌥ 修饰键）
4. 按 `Esc` 取消录制

### 管理预设尺寸

- 点击 ➕ 新增尺寸
- 悬停尺寸条目显示编辑/删除按钮
- 拖拽调整排序
- 点击 🔄 恢复默认预设

---

## 🏗️ 项目结构

```
MacTools/
├── App/
│   ├── MacToolsApp.swift      # 应用入口
│   └── AppDelegate.swift      # 应用代理，菜单栏图标
├── Core/
│   ├── FeatureManager.swift   # 功能管理协议
│   ├── GlobalEventMonitor.swift
│   ├── KeyCodeUtils.swift
│   ├── PanelCentering.swift
│   └── ScreenCapture.swift
├── Features/
│   ├── DockToggle/            # Dock 切换功能
│   │   ├── DockToggleManager.swift
│   │   └── DockToggleView.swift
│   └── WindowResizer/         # 窗口调整功能
│       ├── WindowResizerManager.swift
│       ├── WindowResizerView.swift
│       ├── WindowPickerPanel.swift
│       ├── SizePickerPanel.swift
│       └── PresetSizeStore.swift
├── Views/
│   └── GeneralSettingsView.swift
├── ContentView.swift
└── Assets.xcassets/
```

---

## 🛠️ 技术栈

- **SwiftUI** - 现代声明式 UI 框架
- **AppKit** - macOS 原生框架
- **Accessibility API** - 窗口控制与事件监听
- **ScreenCaptureKit** - 窗口截图

---

<p align="center">
  Made with ❤️ for macOS
</p>
