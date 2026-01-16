//
//  ContentView.swift
//  LightViewer
//
//  主界面：支持单图查看和缩略图网格模式
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
    
    var body: some View {
        ZStack {
            // 背景色
            Color.darkBackground
                .ignoresSafeArea()
            
            if viewMode == .single {
                // 单图查看模式
                singleImageView
            } else {
                // 缩略图模式
                thumbnailsView
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .toolbar {
            toolbarContent
        }
        .onAppear {
            setupKeyboardShortcuts()
        }
        .background(KeyboardEventHandler(
            onLeftArrow: { navigateImage(direction: -1) },
            onRightArrow: { navigateImage(direction: 1) },
            onToggleExif: { withAnimation(.easeInOut(duration: 0.2)) { showExif.toggle() } },
            onToggleThumbnails: { withAnimation(.easeInOut(duration: 0.3)) { toggleViewMode() } },
            onToggleFullscreen: { toggleFullscreen() },
            onOpenFolder: { openFolderDialog() },
            onDelete: { deleteCurrentImage() }
        ))
    }
    
    // MARK: - 单图查看视图
    
    private var singleImageView: some View {
        HSplitView {
            // 左侧：图片显示区域
            ZStack {
                Color.darkBackground
                
                if let image = currentImage {
                    ImageViewer(image: image)
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
            
            Button(action: { withAnimation { showExif.toggle() } }) {
                Label("信息", systemImage: showExif ? "info.circle.fill" : "info.circle")
            }
            .help("显示/隐藏信息 (I)")
        }
    }
    
    // MARK: - 拖拽处理
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else {
                return
            }
            
            DispatchQueue.main.async {
                var isDirectory: ObjCBool = false
                FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
                
                if isDirectory.boolValue {
                    // 拖入的是文件夹
                    loadFolder(from: url)
                } else {
                    // 拖入的是图片文件
                    loadImage(from: url)
                    loadFolderImages(from: url)
                }
            }
        }
        
        return true
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
        if let window = NSApplication.shared.mainWindow {
            window.toggleFullScreen(nil)
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
    
    func makeNSView(context: Context) -> KeyboardView {
        let view = KeyboardView()
        view.onLeftArrow = onLeftArrow
        view.onRightArrow = onRightArrow
        view.onToggleExif = onToggleExif
        view.onToggleThumbnails = onToggleThumbnails
        view.onToggleFullscreen = onToggleFullscreen
        view.onOpenFolder = onOpenFolder
        view.onDelete = onDelete
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
