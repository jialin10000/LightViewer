//
//  LightViewerApp.swift
//  LightViewer
//
//  应用入口
//

import SwiftUI

@main
struct LightViewerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)  // 默认深色模式
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1200, height: 800)
        .commands {
            // 文件菜单
            CommandGroup(after: .newItem) {
                Button("打开文件夹...") {
                    NotificationCenter.default.post(name: .openFolder, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            
            // 视图菜单
            CommandMenu("视图") {
                Button("单图模式") {
                    NotificationCenter.default.post(name: .setSingleMode, object: nil)
                }
                .keyboardShortcut("1", modifiers: .command)
                
                Button("缩略图模式") {
                    NotificationCenter.default.post(name: .setThumbnailMode, object: nil)
                }
                .keyboardShortcut("2", modifiers: .command)
                
                Divider()
                
                Button("显示/隐藏信息面板") {
                    NotificationCenter.default.post(name: .toggleExif, object: nil)
                }
                .keyboardShortcut("i", modifiers: .command)
                
                Divider()
                
                Button("进入全屏") {
                    NotificationCenter.default.post(name: .toggleFullscreen, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .control])
            }
        }
    }
}

// MARK: - 通知名称

extension Notification.Name {
    static let openFolder = Notification.Name("openFolder")
    static let toggleExif = Notification.Name("toggleExif")
    static let toggleFullscreen = Notification.Name("toggleFullscreen")
    static let setSingleMode = Notification.Name("setSingleMode")
    static let setThumbnailMode = Notification.Name("setThumbnailMode")
}
