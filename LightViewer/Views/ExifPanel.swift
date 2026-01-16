//
//  ExifPanel.swift
//  LightViewer
//
//  EXIF 信息显示面板 - 优化后的深色主题
//

import SwiftUI

struct ExifPanel: View {
    let metadata: ImageMetadata?
    let imageURL: URL?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 文件信息
                if let url = imageURL {
                    InfoSection(title: "文件", icon: "doc.fill") {
                        InfoRow(label: "文件名", value: url.lastPathComponent)
                        
                        if let size = metadata?.fileSizeFormatted {
                            InfoRow(label: "大小", value: size)
                        }
                        
                        if let resolution = metadata?.resolutionFormatted {
                            InfoRow(label: "分辨率", value: resolution)
                        }
                    }
                }
                
                // 相机信息
                if metadata?.cameraModel != nil || metadata?.cameraMake != nil {
                    InfoSection(title: "相机", icon: "camera.fill") {
                        if let make = metadata?.cameraMake {
                            InfoRow(label: "品牌", value: make)
                        }
                        
                        if let model = metadata?.cameraModel {
                            InfoRow(label: "型号", value: model)
                        }
                    }
                }
                
                // 镜头信息
                if metadata?.lensModel != nil {
                    InfoSection(title: "镜头", icon: "camera.aperture") {
                        if let lens = metadata?.lensModel {
                            InfoRow(label: "型号", value: lens)
                        }
                    }
                }
                
                // 拍摄参数
                if hasShootingParams {
                    InfoSection(title: "拍摄参数", icon: "slider.horizontal.3") {
                        if let focal = metadata?.focalLengthFormatted {
                            InfoRow(label: "焦距", value: focal)
                        }
                        
                        if let aperture = metadata?.apertureFormatted {
                            InfoRow(label: "光圈", value: aperture)
                        }
                        
                        if let shutter = metadata?.shutterSpeedFormatted {
                            InfoRow(label: "快门", value: shutter)
                        }
                        
                        if let iso = metadata?.isoFormatted {
                            InfoRow(label: "ISO", value: iso)
                        }
                        
                        if let bias = metadata?.exposureBiasFormatted {
                            InfoRow(label: "曝光补偿", value: bias)
                        }
                    }
                }
                
                // 时间信息
                if metadata?.dateFormatted != nil {
                    InfoSection(title: "时间", icon: "clock.fill") {
                        if let date = metadata?.dateFormatted {
                            InfoRow(label: "拍摄时间", value: date)
                        }
                    }
                }
                
                // GPS 信息
                if metadata?.hasGPS == true {
                    InfoSection(title: "位置", icon: "location.fill") {
                        if let gps = metadata?.gpsFormatted {
                            InfoRow(label: "GPS", value: gps)
                        }
                        
                        if let altitude = metadata?.altitude {
                            InfoRow(label: "海拔", value: String(format: "%.1f m", altitude))
                        }
                    }
                }
                
                // 无 EXIF 数据提示
                if metadata == nil && imageURL != nil {
                    VStack(spacing: 12) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 32, weight: .thin))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.secondary, .secondary.opacity(0.5)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        
                        Text("无 EXIF 数据")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
                
                Spacer()
            }
            .padding(20)
        }
        .background(Color.darkSidebar)
    }
    
    private var hasShootingParams: Bool {
        return metadata?.focalLength != nil ||
               metadata?.aperture != nil ||
               metadata?.shutterSpeed != nil ||
               metadata?.iso != nil
    }
}

// MARK: - 信息区块

struct InfoSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.accentColor)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(1)
            }
            
            // 内容
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.darkCard)
            .cornerRadius(10)
        }
    }
}

// MARK: - 信息行

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 65, alignment: .leading)
            
            Text(value)
                .font(.callout)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .textSelection(.enabled)
            
            Spacer()
        }
    }
}

#Preview {
    ExifPanel(
        metadata: ImageMetadata(
            cameraMake: "Sony",
            cameraModel: "ILCE-7RM5",
            lensModel: "FE 85mm F1.4 GM",
            focalLength: 85,
            focalLength35mm: 85,
            aperture: 1.4,
            shutterSpeed: 1.0/500.0,
            iso: 200,
            exposureBias: -0.3,
            dateTimeOriginal: Date(),
            latitude: 31.2304,
            longitude: 121.4737,
            altitude: 10,
            imageWidth: 7952,
            imageHeight: 5304,
            fileSize: 45_000_000,
            fileName: "DSC00001.ARW"
        ),
        imageURL: URL(fileURLWithPath: "/test/DSC00001.ARW")
    )
    .frame(width: 300, height: 700)
    .preferredColorScheme(.dark)
}
