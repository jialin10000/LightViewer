//
//  ThumbnailGridView.swift
//  LightViewer
//
//  缩略图网格视图
//

import SwiftUI

struct ThumbnailGridView: View {
    let images: [URL]
    @Binding var selectedIndex: Int
    var onSelect: (Int) -> Void
    var onDoubleClick: (Int) -> Void
    
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 12)
    ]
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, url in
                        ThumbnailCell(
                            url: url,
                            isSelected: index == selectedIndex,
                            onTap: {
                                onSelect(index)
                            },
                            onDoubleTap: {
                                onDoubleClick(index)
                            }
                        )
                        .id(index)
                    }
                }
                .padding(16)
            }
            .background(Color.darkBackground)
            .onChange(of: selectedIndex) { _, newIndex in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }
}

// MARK: - 单个缩略图单元格

struct ThumbnailCell: View {
    let url: URL
    let isSelected: Bool
    var onTap: () -> Void
    var onDoubleTap: () -> Void
    
    @State private var thumbnail: NSImage?
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 6) {
            // 缩略图
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.3))
                
                if let image = thumbnail {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 150, height: 120)
                        .clipped()
                        .cornerRadius(6)
                } else if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "photo")
                        .font(.title)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 150, height: 120)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
            )
            .shadow(color: isSelected ? Color.accentColor.opacity(0.5) : Color.black.opacity(0.2), radius: isSelected ? 8 : 4)
            
            // 文件名
            Text(url.lastPathComponent)
                .font(.caption2)
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 150)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onDoubleTap()
        }
        .onTapGesture(count: 1) {
            onTap()
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        DispatchQueue.global(qos: .userInitiated).async {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
                kCGImageSourceThumbnailMaxPixelSize: 300,
                kCGImageSourceCreateThumbnailWithTransform: true
            ]
            
            guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
                DispatchQueue.main.async {
                    isLoading = false
                }
                return
            }
            
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            
            DispatchQueue.main.async {
                thumbnail = nsImage
                isLoading = false
            }
        }
    }
}

#Preview {
    ThumbnailGridView(
        images: [],
        selectedIndex: .constant(0),
        onSelect: { _ in },
        onDoubleClick: { _ in }
    )
    .frame(width: 600, height: 400)
}
