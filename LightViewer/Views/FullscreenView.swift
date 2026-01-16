//
//  FullscreenView.swift
//  LightViewer
//
//  全屏查看视图 - 纯黑背景 + 点击翻页 + 悬浮 EXIF
//

import SwiftUI

struct FullscreenView: View {
    let image: NSImage
    let metadata: ImageMetadata?
    let imageURL: URL?
    let currentIndex: Int
    let totalCount: Int
    @Binding var showExif: Bool
    var onNavigate: (Int) -> Void
    var onExit: () -> Void
    
    @State private var exifPosition: CGPoint = CGPoint(x: 100, y: 100)
    @State private var showControls: Bool = true
    @State private var showNavigationHint: NavigationHint? = nil
    @State private var hideControlsTask: DispatchWorkItem?
    
    enum NavigationHint {
        case previous, next
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 纯黑背景
                Color.black
                    .ignoresSafeArea()
                
                // 图片 - 自适应全屏
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // 点击区域
                HStack(spacing: 0) {
                    // 左侧 - 上一张
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            navigateTo(-1)
                        }
                        .overlay(
                            navigationIndicator(direction: .previous)
                        )
                    
                    // 右侧 - 下一张
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            navigateTo(1)
                        }
                        .overlay(
                            navigationIndicator(direction: .next)
                        )
                }
                
                // 顶部控制栏
                if showControls {
                    VStack {
                        HStack {
                            // 退出按钮
                            Button(action: onExit) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                            .padding(20)
                            
                            Spacer()
                            
                            // 图片计数
                            Text("\(currentIndex + 1) / \(totalCount)")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Color.black.opacity(0.5)))
                            
                            Spacer()
                            
                            // EXIF 开关
                            Button(action: { showExif.toggle() }) {
                                Image(systemName: showExif ? "info.circle.fill" : "info.circle")
                                    .font(.title)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                            .padding(20)
                        }
                        .background(
                            LinearGradient(
                                colors: [Color.black.opacity(0.6), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 100)
                            .allowsHitTesting(false)
                        )
                        
                        Spacer()
                    }
                    .transition(.opacity)
                }
                
                // 悬浮 EXIF 面板
                if showExif {
                    FloatingExifPanel(
                        metadata: metadata,
                        imageURL: imageURL,
                        position: $exifPosition,
                        containerSize: geometry.size
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .onAppear {
                // 初始化 EXIF 位置到右下角
                exifPosition = CGPoint(
                    x: geometry.size.width - 180,
                    y: geometry.size.height - 250
                )
                scheduleHideControls()
            }
            .onHover { hovering in
                if hovering {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showControls = true
                    }
                    scheduleHideControls()
                }
            }
        }
        .background(Color.black)
    }
    
    // MARK: - 导航指示器
    
    @ViewBuilder
    private func navigationIndicator(direction: NavigationHint) -> some View {
        Group {
            if showNavigationHint == direction {
                Image(systemName: direction == .previous ? "chevron.left.circle.fill" : "chevron.right.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white.opacity(0.7))
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: showNavigationHint)
    }
    
    // MARK: - 导航
    
    private func navigateTo(_ direction: Int) {
        withAnimation(.easeOut(duration: 0.15)) {
            showNavigationHint = direction < 0 ? .previous : .next
        }
        
        onNavigate(direction)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeOut(duration: 0.15)) {
                showNavigationHint = nil
            }
        }
        
        // 显示控制栏
        withAnimation(.easeOut(duration: 0.2)) {
            showControls = true
        }
        scheduleHideControls()
    }
    
    // MARK: - 自动隐藏控制栏
    
    private func scheduleHideControls() {
        hideControlsTask?.cancel()
        
        let task = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.3)) {
                showControls = false
            }
        }
        hideControlsTask = task
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: task)
    }
}

// MARK: - 悬浮 EXIF 面板

struct FloatingExifPanel: View {
    let metadata: ImageMetadata?
    let imageURL: URL?
    @Binding var position: CGPoint
    let containerSize: CGSize
    
    @State private var isDragging = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题栏（可拖动）
            HStack {
                Image(systemName: "camera.fill")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                Text("EXIF 信息")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.9))
                
                Spacer()
                
                Image(systemName: "line.3.horizontal")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.bottom, 4)
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // 内容
            VStack(alignment: .leading, spacing: 8) {
                if let model = metadata?.cameraModel {
                    FloatingInfoRow(label: "相机", value: model)
                }
                
                if let lens = metadata?.lensModel {
                    FloatingInfoRow(label: "镜头", value: lens)
                }
                
                if let focal = metadata?.focalLengthFormatted {
                    FloatingInfoRow(label: "焦距", value: focal)
                }
                
                if let aperture = metadata?.apertureFormatted {
                    FloatingInfoRow(label: "光圈", value: aperture)
                }
                
                if let shutter = metadata?.shutterSpeedFormatted {
                    FloatingInfoRow(label: "快门", value: shutter)
                }
                
                if let iso = metadata?.isoFormatted {
                    FloatingInfoRow(label: "ISO", value: iso)
                }
                
                if let date = metadata?.dateFormatted {
                    FloatingInfoRow(label: "时间", value: date)
                }
            }
        }
        .padding(16)
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.75))
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .opacity(0.3)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
        .position(position)
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    
                    // 限制在容器内
                    let newX = min(max(value.location.x, 150), containerSize.width - 150)
                    let newY = min(max(value.location.y, 100), containerSize.height - 100)
                    
                    position = CGPoint(x: newX, y: newY)
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
        .scaleEffect(isDragging ? 1.02 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isDragging)
    }
}

// MARK: - 悬浮面板信息行

struct FloatingInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 45, alignment: .leading)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(2)
            
            Spacer()
        }
    }
}

#Preview {
    FullscreenView(
        image: NSImage(systemSymbolName: "photo", accessibilityDescription: nil)!,
        metadata: ImageMetadata(
            cameraMake: "Sony",
            cameraModel: "ILCE-7RM5",
            lensModel: "FE 85mm F1.4 GM",
            focalLength: 85,
            aperture: 1.4,
            shutterSpeed: 1.0/500.0,
            iso: 200
        ),
        imageURL: URL(fileURLWithPath: "/test.jpg"),
        currentIndex: 5,
        totalCount: 100,
        showExif: .constant(true),
        onNavigate: { _ in },
        onExit: { }
    )
}
