//
//  SlideshowView.swift
//  LightViewer
//
//  幻灯片播放视图
//

import SwiftUI

struct SlideshowView: View {
    let images: [URL]
    @Binding var currentIndex: Int
    @Binding var isPlaying: Bool
    @Binding var interval: Double
    var onLoadImage: (URL) -> (NSImage?, ImageMetadata?)
    var onExit: () -> Void
    
    @State private var currentImage: NSImage?
    @State private var metadata: ImageMetadata?
    @State private var showControls: Bool = true
    @State private var showSettings: Bool = false
    @State private var showExif: Bool = false
    @State private var exifPosition: CGPoint = CGPoint(x: 100, y: 100)
    @State private var timer: Timer?
    @State private var progress: Double = 0
    @State private var hideControlsTask: DispatchWorkItem?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 纯黑背景
                Color.black
                    .ignoresSafeArea()
                
                // 图片
                if let image = currentImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                        .id(currentIndex) // 强制刷新动画
                }
                
                // 点击区域
                HStack(spacing: 0) {
                    // 左侧 - 上一张
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            previousImage()
                        }
                    
                    // 中间 - 暂停/播放
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .frame(width: geometry.size.width * 0.3)
                        .onTapGesture {
                            togglePlayPause()
                        }
                    
                    // 右侧 - 下一张
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            nextImage()
                        }
                }
                
                // 控制栏
                if showControls {
                    VStack {
                        // 顶部栏
                        topBar
                        
                        Spacer()
                        
                        // 底部控制栏
                        bottomBar(geometry: geometry)
                    }
                    .transition(.opacity)
                }
                
                // 播放/暂停指示器
                if !isPlaying && !showControls {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                // 悬浮 EXIF 面板
                if showExif {
                    FloatingExifPanel(
                        metadata: metadata,
                        imageURL: images.indices.contains(currentIndex) ? images[currentIndex] : nil,
                        position: $exifPosition,
                        containerSize: geometry.size
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
                
                // 设置面板
                if showSettings {
                    settingsPanel
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .onAppear {
                // 初始化 EXIF 位置
                exifPosition = CGPoint(
                    x: geometry.size.width - 180,
                    y: geometry.size.height - 250
                )
                
                // 加载当前图片
                loadCurrentImage()
                
                // 如果是播放状态，启动定时器
                if isPlaying {
                    startTimer()
                }
                
                scheduleHideControls()
            }
            .onDisappear {
                stopTimer()
            }
            .onChange(of: isPlaying) { _, playing in
                if playing {
                    startTimer()
                } else {
                    stopTimer()
                }
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
    
    // MARK: - 顶部栏
    
    private var topBar: some View {
        HStack {
            // 退出按钮
            Button(action: {
                stopTimer()
                onExit()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
            .padding(20)
            
            Spacer()
            
            // 图片计数
            Text("\(currentIndex + 1) / \(images.count)")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.black.opacity(0.5)))
            
            Spacer()
            
            // EXIF 开关
            Button(action: { 
                withAnimation(.easeOut(duration: 0.2)) {
                    showExif.toggle()
                }
            }) {
                Image(systemName: showExif ? "info.circle.fill" : "info.circle")
                    .font(.title)
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
            
            // 设置按钮
            Button(action: { 
                withAnimation(.easeOut(duration: 0.2)) {
                    showSettings.toggle()
                }
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.title)
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
            .padding(20)
        }
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.7), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
            .allowsHitTesting(false)
        )
    }
    
    // MARK: - 底部控制栏
    
    private func bottomBar(geometry: GeometryProxy) -> some View {
        VStack(spacing: 12) {
            // 进度条
            GeometryReader { progressGeometry in
                ZStack(alignment: .leading) {
                    // 背景
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 4)
                    
                    // 进度
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white)
                        .frame(width: progressGeometry.size.width * progress, height: 4)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 40)
            
            // 控制按钮
            HStack(spacing: 40) {
                // 上一张
                Button(action: previousImage) {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.9))
                }
                .buttonStyle(.plain)
                
                // 播放/暂停
                Button(action: togglePlayPause) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                
                // 下一张
                Button(action: nextImage) {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.9))
                }
                .buttonStyle(.plain)
            }
            
            // 间隔时间显示
            Text("间隔: \(String(format: "%.0f", interval)) 秒")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.vertical, 20)
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 150)
            .allowsHitTesting(false)
        )
    }
    
    // MARK: - 设置面板
    
    private var settingsPanel: some View {
        VStack(spacing: 20) {
            Text("幻灯片设置")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                Text("切换间隔")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                
                HStack(spacing: 20) {
                    // 减少间隔
                    Button(action: { 
                        if interval > 1 {
                            interval -= 1
                            if isPlaying {
                                restartTimer()
                            }
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    
                    // 当前间隔
                    Text("\(String(format: "%.0f", interval)) 秒")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 100)
                    
                    // 增加间隔
                    Button(action: { 
                        if interval < 30 {
                            interval += 1
                            if isPlaying {
                                restartTimer()
                            }
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                
                // 快捷选择
                HStack(spacing: 12) {
                    ForEach([2, 3, 5, 10], id: \.self) { seconds in
                        Button(action: {
                            interval = Double(seconds)
                            if isPlaying {
                                restartTimer()
                            }
                        }) {
                            Text("\(seconds)s")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(interval == Double(seconds) ? .black : .white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(interval == Double(seconds) ? Color.white : Color.white.opacity(0.2))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Button(action: {
                withAnimation(.easeOut(duration: 0.2)) {
                    showSettings = false
                }
            }) {
                Text("完成")
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.white))
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
        }
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.85))
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .opacity(0.3)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    // MARK: - Timer 控制
    
    private func startTimer() {
        stopTimer()
        progress = 0
        
        // 进度更新定时器（每 0.05 秒更新一次）
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            withAnimation(.linear(duration: 0.05)) {
                progress += 0.05 / interval
            }
            
            if progress >= 1 {
                progress = 0
                nextImage()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func restartTimer() {
        if isPlaying {
            startTimer()
        }
    }
    
    // MARK: - 导航
    
    private func nextImage() {
        guard !images.isEmpty else { return }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            if currentIndex < images.count - 1 {
                currentIndex += 1
            } else {
                currentIndex = 0 // 循环播放
            }
        }
        
        loadCurrentImage()
        progress = 0
    }
    
    private func previousImage() {
        guard !images.isEmpty else { return }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            if currentIndex > 0 {
                currentIndex -= 1
            } else {
                currentIndex = images.count - 1 // 循环到最后
            }
        }
        
        loadCurrentImage()
        progress = 0
    }
    
    private func togglePlayPause() {
        isPlaying.toggle()
        
        withAnimation(.easeOut(duration: 0.2)) {
            showControls = true
        }
        scheduleHideControls()
    }
    
    private func loadCurrentImage() {
        guard images.indices.contains(currentIndex) else { return }
        
        let (image, meta) = onLoadImage(images[currentIndex])
        currentImage = image
        metadata = meta
    }
    
    // MARK: - 自动隐藏控制栏
    
    private func scheduleHideControls() {
        hideControlsTask?.cancel()
        
        let task = DispatchWorkItem {
            if isPlaying && !showSettings {
                withAnimation(.easeOut(duration: 0.3)) {
                    showControls = false
                }
            }
        }
        hideControlsTask = task
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: task)
    }
}

#Preview {
    SlideshowView(
        images: [],
        currentIndex: .constant(0),
        isPlaying: .constant(true),
        interval: .constant(3),
        onLoadImage: { _ in (nil, nil) },
        onExit: { }
    )
}
