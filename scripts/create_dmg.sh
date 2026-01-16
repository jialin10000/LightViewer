#!/bin/bash

# LightViewer DMG 打包脚本
# 使用方法：先在 Xcode 中 Archive 并导出 .app，然后运行此脚本

APP_NAME="LightViewer"
DMG_NAME="LightViewer-Installer"
VERSION="1.0.0"

# 检查 .app 文件
if [ ! -d "$1" ]; then
    echo "❌ 请提供 .app 文件路径"
    echo "用法: ./create_dmg.sh /path/to/LightViewer.app"
    exit 1
fi

APP_PATH="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/../dist"
TEMP_DIR="$SCRIPT_DIR/../temp_dmg"

# 创建输出目录
mkdir -p "$OUTPUT_DIR"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

echo "📦 创建 DMG 安装包..."
echo "   App: $APP_PATH"

# 复制 .app 到临时目录
cp -R "$APP_PATH" "$TEMP_DIR/"

# 创建 Applications 快捷方式
ln -s /Applications "$TEMP_DIR/Applications"

# 创建 DMG
DMG_PATH="$OUTPUT_DIR/${DMG_NAME}-${VERSION}.dmg"
rm -f "$DMG_PATH"

hdiutil create -volname "$APP_NAME" \
    -srcfolder "$TEMP_DIR" \
    -ov -format UDZO \
    "$DMG_PATH"

# 清理
rm -rf "$TEMP_DIR"

echo ""
echo "✅ DMG 创建成功！"
echo "📍 位置: $DMG_PATH"
echo ""
echo "安装方法："
echo "1. 双击 DMG 文件打开"
echo "2. 将 LightViewer 拖到 Applications 文件夹"
echo "3. 完成！"
