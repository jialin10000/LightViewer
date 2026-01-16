//
//  ContentView.swift
//  LightViewer
//
//  主界面：支持单图查看、缩略图网格、全屏和幻灯片模式
//

import SwiftUI
import UniformTypeIdentifiers

enum ViewMode {
    case single      // 单图查看模式
    case thumbnails  // 缩略图网格模式
}

struct ContentView: View {
    @State private var currentImage: NSImage?
    @State private var metadata: ImageMetadata?
    @State private var isDragging = false
    @State private var currentImageURL: URL?
    @State private var folderImages: [URL] = []
    @State private var currentIndex: Int = 0
    @State private var showExif: Bool = true
    @State private var viewMode: ViewMode = .single
    @State private var isFullscreen: Bool = false
    @State private var currentFolderURL: URL?
    @State private var showExifInFullscreen: Bool = true
    
    // 幻灯片状态
    @State private var isSlideshow: Bool = false
    @State private var isSlideshowPlaying: Bool = true
    @State private var slideshowInterval: Double = 3.0
    
    var body: some View {
        ZStack {
            // 背景色
            Color.darkBackground
                .ignoresSafeArea()
            
            if isSlideshow && !folderImages.isEmpty {
                // 幻灯片模式
                SlideshowView(
                    images: folderImages,
                    currentIndex: $currentIndex,
                    isPlaying: $isSlideshowPlaying,
                    interval: $slideshowInterval,
                    onLoadImage: { url in
                        let image = NSImage(contentsOf: url)
                        let meta = ExifParser.parse(from: url)
                        return (image, meta)
                    },
                    onExit: {
                        withAnimation(.easeOut(duration: 0.3)) {
                            isSlideshow = false
                            // 同步当前图片
                            if folderImages.indices.contains(currentIndex) {
                                loadImage(from: folderImages[currentIndex])
                            }
                        }
                        exitSystemFullscreen()
                    }
                )
                .transition(.opacity)
            } else if isFullscreen && currentImage != nil {
                // 全屏模式
                FullscreenView(
                    image: currentImage!,
                    metadata: metadata,
                    imageURL: currentImageURL,
                    currentIndex: currentIndex,
                    totalCount: folderImages.count,
                    showExif: $showExifInFullscreen,
                    onNavigate: { direction in
                        navigateImage(direction: direction)
                    },
                    onExit: {
                        withAnimation(.easeOut(duration: 0.3)) {
                            isFullscreen = false
                        }
                    }
                )
                .transition(.opacity)
            } else if viewMode == .single {
                // 单图查看模式
                singleImageView
            } else {
                // 缩略图模式
                thumbnailsView
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .toolbar((isFullscreen || isSlideshow) ? .hidden : .automatic)
        .toolbar {
            if !isFullscreen && !isSlideshow {
                toolbarContent
            }
        }
        .onAppear {
            setupKeyboardShortcuts()
        }
        .background(KeyboardEventHandler(
            onLeftArrow: { 
                if !isSlideshow {
                    navigateImage(direction: -1)
                }
            },
            onRightArrow: { 
                if !isSlideshow {
                    navigateImage(direction: 1)
                }
            },
            onToggleExif: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isFullscreen {
                        showExifInFullscreen.toggle()
                    } else {
                        showExif.toggle()
                    }
                }
            },
            onToggleThumbnails: {
                if !isFullscreen && !isSlideshow {
                    withAnimation(.easeInOut(duration: 0.3)) { toggleViewMode() }
                }
            },
            onToggleFullscreen: { toggleFullscreen() },
            onOpenFolder: { openFolderDialog() },
            onDelete: { deleteCurrentImage() },
            onEscape: {
                if isSlideshow {
                    withAnimation(.easeOut(duration: 0.3)) {
                        isSlideshow = false
                        if folderImages.indices.contains(currentIndex) {
                            loadImage(from: folderImages[currentIndex])
                        }
                    }
                    exitSystemFullscreen()
                } else if isFullscreen {
                    withAnimation(.easeOut(duration: 0.3)) {
                        isFullscreen = false
                    }
                }
            },
            onToggleSlideshow: {
                startSlideshow()
            },
            onSpace: {
                if isSlideshow {
                    isSlideshowPlaying.toggle()
                } else {
                    startSlideshow()
                }
            }
        ))
    }
    
    // MARK: - 单图查看视图
    
    private var singleImageView: some View {
        HSplitView {
            // 左侧：图片显示区域
            ZStack {
                Color.darkBackground
                
                if let image = currentImage {
                    ImageViewer(image: image) { direction in
                        navigateImage(direction: direction)
                    }
                } else {
                    // 拖拽提示
                    emptyStateView
                }
                
                // 拖拽高亮效果
                if isDragging {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.accentColor, lineWidth: 3)
                        .background(Color.accentColor.opacity(0.1).cornerRadius(16))
                        .padding(12)
                }
                
                // 图片计数器
                if !folderImages.isEmpty {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("\(currentIndex + 1) / \(folderImages.count)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.black.opacity(0.6)))
                                .padding(16)
                        }
                    }
                }
            }
            .frame(minWidth: 500, minHeight: 400)
            .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
                handleDrop(providers: providers)
            }
            
            // 右侧：EXIF 信息面板
            if showExif {
                ExifPanel(metadata: metadata, imageURL: currentImageURL)
                    .frame(width: 300)
                    .transition(.move(edge: .trailing))
            }
        }
    }
    
    // MARK: - 缩略图视图
    
    private var thumbnailsView: some View {
        VStack(spacing: 0) {
            // 顶部信息栏
            if let folderURL = currentFolderURL {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.accentColor)
                    
                    Text(folderURL.lastPathComponent)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("(\(folderImages.count) 张图片)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // 幻灯片按钮
                    Button(action: { startSlideshow() }) {
                        Label("幻灯片", systemImage: "play.rectangle")
                    }
                    .buttonStyle(.bordered)
                    .disabled(folderImages.isEmpty)
                    
                    Button(action: { openFolderDialog() }) {
                        Label("更换文件夹", systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.darkSidebar)
            }
            
            // 缩略图网格
            if folderImages.isEmpty {
                emptyStateView
            } else {
                ThumbnailGridView(
                    images: folderImages,
                    selectedIndex: $currentIndex,
                    onSelect: { index in
                        currentIndex = index
                        loadImage(from: folderImages[index])
                    },
                    onDoubleClick: { index in
                        currentIndex = index
                        loadImage(from: folderImages[index])
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewMode = .single
                        }
                    }
                )
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
            handleDrop(providers: providers)
        }
    }
    
    // MARK: - 空状态视图
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 72, weight: .thin))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.accentColor, .accentColor.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: 8) {
                Text("拖拽图片或文件夹到这里")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("支持 JPG、HEIC、PNG、RAW 等格式")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Button(action: { openFolderDialog() }) {
                Label("选择文件夹", systemImage: "folder")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            // 快捷键提示
            VStack(spacing: 4) {
                Text("快捷键")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 16) {
                    KeyHint(key: "← →", action: "切换图片")
                    KeyHint(key: "I", action: "显示信息")
                    KeyHint(key: "T", action: "缩略图")
                    KeyHint(key: "F", action: "全屏")
                    KeyHint(key: "P", action: "幻灯片")
                }
            }
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 工具栏
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            Button(action: { openFolderDialog() }) {
                Label("打开文件夹", systemImage: "folder")
            }
            .help("打开文件夹 (⌘O)")
            
            Divider()
            
            Button(action: { navigateImage(direction: -1) }) {
                Label("上一张", systemImage: "chevron.left")
            }
            .disabled(folderImages.isEmpty || currentIndex <= 0)
            .help("上一张 (←)")
            
            Button(action: { navigateImage(direction: 1) }) {
                Label("下一张", systemImage: "chevron.right")
            }
            .disabled(folderImages.isEmpty || currentIndex >= folderImages.count - 1)
            .help("下一张 (→)")
            
            Divider()
            
            // 视图模式切换
            Picker("视图模式", selection: $viewMode) {
                Label("单图", systemImage: "photo").tag(ViewMode.single)
                Label("缩略图", systemImage: "square.grid.2x2").tag(ViewMode.thumbnails)
            }
            .pickerStyle(.segmented)
            .frame(width: 120)
            .help("切换视图模式 (T)")
            
            Divider()
            
            // 幻灯片按钮
            Button(action: { startSlideshow() }) {
                Label("幻灯片", systemImage: "play.rectangle")
            }
            .disabled(folderImages.isEmpty)
            .help("开始幻灯片 (P 或 空格)")
            
            Button(action: { toggleFullscreen() }) {
                Label("全屏", systemImage: "arrow.up.left.and.arrow.down.right")
            }
            .disabled(currentImage == nil)
            .help("全屏查看 (F)")
            
            Button(action: { withAnimation { showExif.toggle() } }) {
                Label("信息", systemImage: showExif ? "info.circle.fill" : "info.circle")
            }
            .help("显示/隐藏信息 (I)")
        }
    }
    
    // MARK: - 拖拽处理
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        // 打印可用的类型标识符（调试用）
        print("📂 拖拽类型: \(provider.registeredTypeIdentifiers)")
        
        // 尝试多种方式获取 URL
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            let handleItem = { (item: NSSecureCoding?, error: Error?) in
                if let error = error {
                    print("❌ 加载 fileURL 失败: \(error)")
                    return
                }
                
                var url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let urlItem = item as? URL {
                    url = urlItem
                } else if let string = item as? String {
                    url = URL(fileURLWithPath: string)
                }
                
                guard let finalURL = url else {
                    print("❌ 无法解析 URL")
                    return
                }
                
                print("📍 原始 URL: \(finalURL.path)")
                
                DispatchQueue.main.async {
                    self.processDroppedURL(finalURL)
                }
            }
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil, completionHandler: handleItem)
        }
        
        return true
    }
    
    // MARK: - 处理拖入的 URL
    
    private func processDroppedURL(_ url: URL) {
        // 解析别名和符号链接，获取真实路径
        let resolvedURL = resolveAlias(url: url)
        print("📍 解析后 URL: \(resolvedURL.path)")
        
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: resolvedURL.path, isDirectory: &isDirectory)
        print("📍 文件存在: \(exists), 是目录: \(isDirectory.boolValue)")
        
        if exists {
            if isDirectory.boolValue {
                loadFolder(from: resolvedURL)
            } else {
                loadImage(from: resolvedURL)
                loadFolderImages(from: resolvedURL)
            }
        } else {
            print("❌ 文件/文件夹不存在: \(resolvedURL.path)")
        }
    }
    
    // MARK: - 解析别名和符号链接
    
    private func resolveAlias(url: URL) -> URL {
        let symlinkResolved = (url.path as NSString).resolvingSymlinksInPath
        let workingURL = URL(fileURLWithPath: symlinkResolved)
        
        do {
            let resourceValues = try workingURL.resourceValues(forKeys: [.isAliasFileKey])
            if resourceValues.isAliasFile == true {
                let options: URL.BookmarkResolutionOptions = [.withoutUI, .withoutMounting]
                let resolved = try URL(resolvingAliasFileAt: workingURL, options: options)
                return resolved
            }
        } catch {
            print("⚠️ 别名解析错误: \(error)")
        }
        
        return workingURL
    }
    
    // MARK: - 打开文件夹对话框
    
    private func openFolderDialog() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "选择包含图片的文件夹"
        panel.prompt = "选择"
        
        if panel.runModal() == .OK, let url = panel.url {
            loadFolder(from: url)
        }
    }
    
    // MARK: - 加载文件夹
    
    private func loadFolder(from url: URL) {
        currentFolderURL = url
        
        let fileManager = FileManager.default
        let imageExtensions = ["jpg", "jpeg", "png", "heic", "heif", "tiff", "tif", "gif", "bmp", "raw", "cr2", "cr3", "nef", "arw", "orf", "rw2", "dng"]
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.contentTypeKey],
                options: [.skipsHiddenFiles]
            )
            
            folderImages = contents.filter { fileURL in
                imageExtensions.contains(fileURL.pathExtension.lowercased())
            }.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            
            if !folderImages.isEmpty {
                currentIndex = 0
                loadImage(from: folderImages[0])
                
                // 如果图片数量较多，默认显示缩略图模式
                if folderImages.count > 10 && viewMode == .single && currentImage == nil {
                    withAnimation {
                        viewMode = .thumbnails
                    }
                }
            }
            
        } catch {
            print("无法读取文件夹: \(error)")
        }
    }
    
    // MARK: - 图片加载
    
    private func loadImage(from url: URL) {
        guard let image = NSImage(contentsOf: url) else {
            print("无法加载图片: \(url.path)")
            return
        }
        
        currentImage = image
        currentImageURL = url
        metadata = ExifParser.parse(from: url)
        
        // 更新当前索引
        if let index = folderImages.firstIndex(of: url) {
            currentIndex = index
        }
    }
    
    // MARK: - 文件夹图片列表
    
    private func loadFolderImages(from url: URL) {
        let folderURL = url.deletingLastPathComponent()
        currentFolderURL = folderURL
        
        let fileManager = FileManager.default
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: [.contentTypeKey],
                options: [.skipsHiddenFiles]
            )
            
            // 过滤图片文件
            let imageExtensions = ["jpg", "jpeg", "png", "heic", "heif", "tiff", "tif", "gif", "bmp", "raw", "cr2", "cr3", "nef", "arw", "orf", "rw2", "dng"]
            
            folderImages = contents.filter { fileURL in
                imageExtensions.contains(fileURL.pathExtension.lowercased())
            }.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            
            // 设置当前索引
            if let index = folderImages.firstIndex(of: url) {
                currentIndex = index
            }
            
        } catch {
            print("无法读取文件夹: \(error)")
        }
    }
    
    // MARK: - 图片导航
    
    private func navigateImage(direction: Int) {
        guard !folderImages.isEmpty else { return }
        
        let newIndex = currentIndex + direction
        
        if newIndex >= 0 && newIndex < folderImages.count {
            currentIndex = newIndex
            loadImage(from: folderImages[currentIndex])
        }
    }
    
    // MARK: - 视图模式切换
    
    private func toggleViewMode() {
        viewMode = viewMode == .single ? .thumbnails : .single
    }
    
    // MARK: - 全屏切换
    
    private func toggleFullscreen() {
        guard currentImage != nil else { return }
        
        withAnimation(.easeOut(duration: 0.3)) {
            isFullscreen.toggle()
        }
        
        // 同时切换系统全屏
        if let window = NSApplication.shared.mainWindow {
            if isFullscreen && !window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
            } else if !isFullscreen && window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
            }
        }
    }
    
    // MARK: - 幻灯片
    
    private func startSlideshow() {
        guard !folderImages.isEmpty else { return }
        
        // 如果没有选中具体图片，从第一张开始
        if currentImage == nil {
            currentIndex = 0
        }
        
        isSlideshowPlaying = true
        
        withAnimation(.easeOut(duration: 0.3)) {
            isSlideshow = true
        }
        
        // 进入系统全屏
        if let window = NSApplication.shared.mainWindow {
            if !window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
            }
        }
    }
    
    private func exitSystemFullscreen() {
        if let window = NSApplication.shared.mainWindow {
            if window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
            }
        }
    }
    
    // MARK: - 删除当前图片
    
    private func deleteCurrentImage() {
        guard let url = currentImageURL, !folderImages.isEmpty else { return }
        
        // 移动到废纸篓
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            
            // 从列表中移除
            folderImages.remove(at: currentIndex)
            
            // 更新索引和加载下一张
            if folderImages.isEmpty {
                currentImage = nil
                currentImageURL = nil
                metadata = nil
            } else {
                if currentIndex >= folderImages.count {
                    currentIndex = folderImages.count - 1
                }
                loadImage(from: folderImages[currentIndex])
            }
        } catch {
            print("删除失败: \(error)")
        }
    }
    
    private func setupKeyboardShortcuts() {
        // 键盘事件在 KeyboardEventHandler 中处理
    }
}

// MARK: - 快捷键提示组件

struct KeyHint: View {
    let key: String
    let action: String
    
    var body: some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.caption2)
                .fontWeight(.semibold)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(4)
            
            Text(action)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 键盘事件处理

struct KeyboardEventHandler: NSViewRepresentable {
    var onLeftArrow: () -> Void
    var onRightArrow: () -> Void
    var onToggleExif: () -> Void
    var onToggleThumbnails: () -> Void
    var onToggleFullscreen: () -> Void
    var onOpenFolder: () -> Void
    var onDelete: () -> Void
    var onEscape: () -> Void
    var onToggleSlideshow: () -> Void
    var onSpace: () -> Void
    
    func makeNSView(context: Context) -> KeyboardView {
        let view = KeyboardView()
        view.onLeftArrow = onLeftArrow
        view.onRightArrow = onRightArrow
        view.onToggleExif = onToggleExif
        view.onToggleThumbnails = onToggleThumbnails
        view.onToggleFullscreen = onToggleFullscreen
        view.onOpenFolder = onOpenFolder
        view.onDelete = onDelete
        view.onEscape = onEscape
        view.onToggleSlideshow = onToggleSlideshow
        view.onSpace = onSpace
        return view
    }
    
    func updateNSView(_ nsView: KeyboardView, context: Context) {
        nsView.onLeftArrow = onLeftArrow
        nsView.onRightArrow = onRightArrow
        nsView.onToggleExif = onToggleExif
        nsView.onToggleThumbnails = onToggleThumbnails
        nsView.onToggleFullscreen = onToggleFullscreen
        nsView.onOpenFolder = onOpenFolder
        nsView.onDelete = onDelete
        nsView.onEscape = onEscape
        nsView.onToggleSlideshow = onToggleSlideshow
        nsView.onSpace = onSpace
    }
}

class KeyboardView: NSView {
    var onLeftArrow: (() -> Void)?
    var onRightArrow: (() -> Void)?
    var onToggleExif: (() -> Void)?
    var onToggleThumbnails: (() -> Void)?
    var onToggleFullscreen: (() -> Void)?
    var onOpenFolder: (() -> Void)?
    var onDelete: (() -> Void)?
    var onEscape: (() -> Void)?
    var onToggleSlideshow: (() -> Void)?
    var onSpace: (() -> Void)?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        // 检查 Command 键
        let commandPressed = event.modifierFlags.contains(.command)
        
        switch event.keyCode {
        case 123: // 左箭头
            onLeftArrow?()
        case 124: // 右箭头
            onRightArrow?()
        case 34: // I 键
            onToggleExif?()
        case 17: // T 键
            onToggleThumbnails?()
        case 3: // F 键
            onToggleFullscreen?()
        case 31: // O 键
            if commandPressed {
                onOpenFolder?()
            }
        case 51: // Delete 键
            onDelete?()
        case 2: // D 键
            onDelete?()
        case 53: // Escape 键
            onEscape?()
        case 35: // P 键
            onToggleSlideshow?()
        case 49: // 空格键
            onSpace?()
        default:
            super.keyDown(with: event)
        }
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }
}

#Preview {
    ContentView()
}
