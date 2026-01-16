//
//  ImageViewer.swift
//  LightViewer
//
//  图片显示视图 - 支持缩放、拖动、点击翻页
//

import SwiftUI

struct ImageViewer: View {
    let image: NSImage
    var onNavigate: ((Int) -> Void)? = nil  // -1 上一张, +1 下一张
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showNavigationHint: NavigationHint? = nil
    
    enum NavigationHint {
        case previous, next
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景
                Color.darkBackground
                
                // 图片
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // 点击区域（左右两侧）
                HStack(spacing: 0) {
                    // 左侧点击区域 - 上一张
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showNavigationHint = .previous
                            onNavigate?(-1)
                            
                            // 隐藏提示
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showNavigationHint = nil
                            }
                        }
                        .overlay(
                            // 左侧悬停提示
                            Group {
                                if showNavigationHint == .previous {
                                    Image(systemName: "chevron.left.circle.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(.white.opacity(0.8))
                                        .transition(.opacity)
                                }
                            }
                        )
                    
                    // 右侧点击区域 - 下一张
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showNavigationHint = .next
                            onNavigate?(1)
                            
                            // 隐藏提示
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showNavigationHint = nil
                            }
                        }
                        .overlay(
                            // 右侧悬停提示
                            Group {
                                if showNavigationHint == .next {
                                    Image(systemName: "chevron.right.circle.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(.white.opacity(0.8))
                                        .transition(.opacity)
                                }
                            }
                        )
                }
                .gesture(
                    // 双击恢复/放大
                    TapGesture(count: 2)
                        .onEnded {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if scale != 1.0 {
                                    scale = 1.0
                                    offset = .zero
                                } else {
                                    scale = 2.0
                                }
                            }
                        }
                )
                .gesture(
                    // 拖动手势
                    DragGesture()
                        .onChanged { value in
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                )
                .gesture(
                    // 缩放手势
                    MagnificationGesture()
                        .onChanged { value in
                            let newScale = lastScale * value
                            scale = min(max(newScale, 0.5), 10.0)
                        }
                        .onEnded { _ in
                            lastScale = scale
                            
                            // 如果缩放太小，恢复到 1.0
                            if scale < 0.8 {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    scale = 1.0
                                    lastScale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                }
                            }
                        }
                )
                
                // 缩放指示器
                if scale != 1.0 {
                    VStack {
                        HStack {
                            Text(String(format: "%.0f%%", scale * 100))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color.black.opacity(0.6)))
                                .padding(12)
                            
                            Spacer()
                        }
                        Spacer()
                    }
                }
            }
        }
        .onChange(of: image) { _, _ in
            // 切换图片时重置缩放和位置
            withAnimation(.easeOut(duration: 0.2)) {
                scale = 1.0
                lastScale = 1.0
                offset = .zero
                lastOffset = .zero
            }
        }
    }
}

#Preview {
    ImageViewer(image: NSImage(systemSymbolName: "photo", accessibilityDescription: nil)!)
        .frame(width: 600, height: 400)
        .preferredColorScheme(.dark)
}
