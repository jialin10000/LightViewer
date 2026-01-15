# LightViewer

轻量级 Mac 看图软件 - 为摄影玩家打造

## 核心特性

- **极快打开** - 点开即看，不转圈
- **清晰 EXIF** - 相机、镜头、拍摄参数一目了然
- **极简 UI** - 左图右信息，干净舒服
- **流畅导航** - 方向键切换，I 键显示/隐藏信息

## 快捷键

| 按键 | 功能 |
|------|------|
| ← → | 切换上/下一张图片 |
| I | 显示/隐藏 EXIF 信息 |
| 双击 | 放大/还原 |

## 支持格式

- JPG, JPEG, PNG, GIF, BMP, TIFF
- HEIC, HEIF (Apple 格式)
- RAW: CR2, CR3 (Canon), NEF (Nikon), ARW (Sony), ORF (Olympus), RW2 (Panasonic), DNG

## 开发进度

### Day 1 ✅
- [x] 拖拽打开图片
- [x] 基本 EXIF 解析
- [x] 左右布局 (图片 + 信息面板)
- [x] 键盘快捷键 (方向键切换、I 键切换面板)

### Day 2 (计划)
- [ ] 文件夹浏览优化
- [ ] 缩略图模式

### Day 3 (计划)
- [ ] 完整 EXIF 分组显示
- [ ] RAW 内嵌 JPG 优先显示

## 如何创建 Xcode 项目

1. 打开 Xcode
2. File → New → Project
3. 选择 **macOS** → **App**
4. 配置：
   - Product Name: `LightViewer`
   - Interface: `SwiftUI`
   - Language: `Swift`
   - 取消勾选 "Include Tests"
5. 选择保存位置（**选择 `/Users/linjia/works/LightViewer` 的上级目录**，让 Xcode 在现有文件夹中创建项目）
6. 删除 Xcode 自动生成的 `ContentView.swift` 和 `LightViewerApp.swift`
7. 将 `LightViewer/` 文件夹中的所有 `.swift` 文件拖入项目

或者更简单的方式：
1. 在 Xcode 中：File → New → Project
2. 选择一个**新位置**创建空项目
3. 把本目录下的 Swift 文件全部拖入项目中替换

## 技术栈

- SwiftUI
- ImageIO (EXIF 解析)
- AppKit (键盘事件)

## 作者

开发者：linjia
