//
//  Colors.swift
//  LightViewer
//
//  自定义颜色主题
//

import SwiftUI

extension Color {
    // 背景色
    static let viewerBackground = Color("BackgroundColor")
    static let sidebarBackground = Color("SidebarColor")
    
    // 自定义深色主题颜色
    static let darkBackground = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let darkSidebar = Color(red: 0.14, green: 0.14, blue: 0.15)
    static let darkCard = Color(red: 0.18, green: 0.18, blue: 0.19)
    
    // 强调色
    static let accentGradientStart = Color(red: 0.4, green: 0.6, blue: 1.0)
    static let accentGradientEnd = Color(red: 0.6, green: 0.4, blue: 1.0)
}

// MARK: - 颜色扩展

extension ShapeStyle where Self == Color {
    static var viewerBackground: Color { .darkBackground }
    static var sidebarBackground: Color { .darkSidebar }
}
