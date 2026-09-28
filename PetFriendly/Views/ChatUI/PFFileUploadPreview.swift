//
//  PFFileUploadPreview.swift
//  PetFriendly
//
//  文件上传预览组件 — Grok 风格的进度卡片
//  显示缩略图/图标、文件名、大小、进度条，支持多种上传状态
//  配合 PFChatViewModel 使用，实际上传逻辑由 ViewModel 管理
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - 文件上传数据模型

/// 文件上传项模型，追踪上传进度和状态
struct PFFileUploadItem: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let url: URL
    let size: Int64
    var state: UploadState = .preparing
    var progress: Double = 0
    
    /// 上传状态枚举
    enum UploadState: Equatable, Hashable {
        case preparing           // 准备中（计算哈希、初始化等）
        case uploading           // 上传中
        case processing          // 服务端处理中
        case completed(URL)      // 上传完成
        case failed(String)      // 上传失败
    }
    
    /// 格式化文件大小（如 "1.2 MB"）
    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    /// 根据文件扩展名匹配对应的 SF Symbol 图标名
    var iconName: String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "gif", "webp", "heic", "heif", "bmp":
            return "photo.fill"
        case "mp4", "mov", "avi", "mkv", "wmv", "flv":
            return "video.fill"
        case "mp3", "wav", "aac", "flac", "ogg", "m4a":
            return "waveform.circle.fill"
        case "pdf":
            return "doc.text.fill"
        case "doc", "docx":
            return "doc.fill"
        case "xls", "xlsx":
            return "table.fill"
        case "ppt", "pptx":
            return "chart.bar.fill"
        case "zip", "rar", "7z", "tar", "gz":
            return "archivebox.fill"
        case "txt", "md", "json", "xml", "csv", "yml", "yaml":
            return "text.page.fill"
        case "swift", "py", "js", "ts", "java", "c", "cpp", "h":
            return "chevron.right.circle.fill"
        default:
            return "doc.fill"
        }
    }
    
    /// 根据文件类型匹配图标颜色
    var iconColor: Color {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "gif", "webp", "heic", "heif", "bmp":
            return .blue
        case "mp4", "mov", "avi", "mkv", "wmv", "flv":
            return .purple
        case "mp3", "wav", "aac", "flac", "ogg", "m4a":
            return .orange
        case "pdf":
            return .red
        case "zip", "rar", "7z", "tar", "gz":
            return .yellow
        case "swift", "py", "js", "ts", "java", "c", "cpp", "h":
            return .indigo
        default:
            return .secondary
        }
    }
    
    /// 当前状态对应的图标名（用于 trailing 区域）
    var stateIconName: String {
        switch state {
        case .preparing:      return "bolt.horizontal.circle"
        case .uploading:      return "arrow.up.circle"
        case .processing:     return "gearbadge.resize"
        case .completed:      return "checkmark.circle.fill"
        case .failed:         return "exclamationmark.circle.fill"
        }
    }
    
    /// 当前状态的颜色
    var stateColor: Color {
        switch state {
        case .preparing:      return .secondary
        case .uploading:      return .blue
        case .processing:     return .orange
        case .completed:      return .green
        case .failed:         return .red
        }
    }
    
    /// 是否处于可取消的活跃状态
    var isCancelable: Bool {
        switch state {
        case .preparing, .uploading: return true
        default: return false
        }
    }
    
    /// 是否可重试
    var isRetryable: Bool {
        if case .failed = state { return true }
        return false
    }

    /// 是否失败
    var isFailed: Bool {
        if case .failed = state { return true }
        return false
    }
    
    /// 是否显示进度条
    var showsProgress: Bool {
        switch state {
        case .uploading: return true
        default: return false
        }
    }
    
    /// 是否显示处理指示器
    var showsProcessing: Bool {
        if state == .processing { return true }
        if state == .preparing { return true }
        return false
    }
    
    /// Equatable 实现
    static func == (lhs: PFFileUploadItem, rhs: PFFileUploadItem) -> Bool {
        lhs.id == rhs.id && lhs.state == rhs.state && lhs.progress == rhs.progress
    }
}

// MARK: - 自定义线性进度条样式

/// 带动画弹簧效果的线性进度条样式
struct PFProgressStyle: ProgressViewStyle {
    let progress: Double
    
    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // 背景轨道
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(width: geo.size.width, height: 4)
                    .clipShape(Capsule())
                
                // 进度填充（带弹簧动画）
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(4, geo.size.width * progress), height: 4)
                    .clipShape(Capsule())
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: progress)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - 文件上传预览卡片

/// 单文件上传预览卡片，展示文件信息与上传进度
struct PFFileUploadPreview: View {
    @Binding var item: PFFileUploadItem
    var onCancel: (() -> Void)?
    var onRetry: (() -> Void)?
    
    // 用于完成动画的弹簧效果
    @State private var bounceScale: CGFloat = 1.0
    // 用于失败抖动的偏移量
    @State private var shakeOffset: CGFloat = 0.0
    
    var body: some View {
        HStack(spacing: 8) {
            // ── Leading: 文件类型图标 (40x40) ──
            fileIcon
            
            // ── Center: 文件名 + 大小 ──
            fileInfo
            
            // ── Trailing: 取消/重试/状态按钮 ──
            trailingButton
        }
        .padding(12)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(cardBorder)
        .scaleEffect(bounceScale)
        .offset(x: shakeOffset, y: 0)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .animation(.easeInOut(duration: 0.3), value: item.state)
        .onChange(of: item.state) { newState in
            handleStateTransition(to: newState)
        }
        // 底部进度条
        .overlay(alignment: .bottom) {
            progressIndicator
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
    }
    
    // MARK: - 子视图
    
    /// 文件类型图标（40x40 圆角矩形）
    private var fileIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(item.iconColor.opacity(0.15))
                .frame(width: 40, height: 40)
            
            Image(systemName: item.iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(item.iconColor)
            
            // 完成状态时的绿色对号覆盖
            if case .completed = item.state {
                Circle()
                    .fill(Color.green)
                    .frame(width: 18, height: 18)
                    .offset(x: 12, y: 12)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(x: 12, y: 12)
            }
        }
    }
    
    /// 文件信息（名称 + 大小）
    private var fileInfo: some View {
        VStack(alignment: .leading, spacing: 3) {
            // 文件名
            Text(item.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // 文件大小
            Text(item.sizeFormatted)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            // 失败时的错误信息
            if case .failed(let message) = item.state {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }
        }
    }
    
    /// 右侧操作按钮区域
    private var trailingButton: some View {
        Group {
            if item.isCancelable, let onCancel {
                // 可取消时显示取消按钮
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            } else if item.isRetryable, let onRetry {
                // 可重试时显示重试按钮
                Button(action: onRetry) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            } else if case .preparing = item.state {
                // 准备中显示沙漏
                Image(systemName: "hourglass")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            } else if item.showsProcessing {
                // 处理中显示旋转指示器
                ProgressView()
                    .tint(.orange)
            } else if case .completed = item.state {
                // 完成状态显示绿色对号
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
            } else {
                // 默认显示状态图标
                Image(systemName: item.stateIconName)
                    .font(.title3)
                    .foregroundStyle(item.stateColor)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.8)))
        .animation(.easeInOut(duration: 0.3), value: item.state)
    }
    
    /// 进度指示器（上传中 / 处理中）
    private var progressIndicator: some View {
        Group {
            if item.showsProgress {
                ProgressView(value: item.progress)
                    .progressViewStyle(PFProgressStyle(progress: item.progress))
            } else if item.showsProcessing {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(item.stateColor)
                    
                    Text(processingText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                // 无进度显示时占位空视图
                Color.clear.frame(height: 0)
            }
        }
    }
    
    /// 处理中状态对应的文本提示
    private var processingText: String {
        if item.state == .processing {
            return NSLocalizedString("upload_processing", comment: "")
        }
        return NSLocalizedString("upload_preparing", comment: "")
    }
    
    /// 卡片背景色
    private var cardBackground: some View {
        Color(.secondarySystemBackground)
    }
    
    /// 卡片边框（失败时红色高亮）
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(
                item.isFailed ? Color.red.opacity(0.5) : Color.clear,
                lineWidth: 1.5
            )
    }
    
    // MARK: - 状态转换处理
    
    /// 处理状态切换动画
    private func handleStateTransition(to state: PFFileUploadItem.UploadState) {
        switch state {
        case .completed:
            // 完成时触发 bounce 缩放动画
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                bounceScale = 1.05
            }
            // 反弹回原位
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    bounceScale = 1.0
                }
            }
            
        case .failed:
            // 失败时触发 shake 抖动动画
            shakePattern()
            
        default:
            // 其他状态无特殊动画
            bounceScale = 1.0
            shakeOffset = 0.0
        }
    }
    
    /// 抖动动画序列
    private func shakePattern() {
        let sequence: [CGFloat] = [-4, 4, -3, 3, -2, 2, 0]
        let duration: Double = 0.08
        
        for (i, offset) in sequence.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * duration) {
                withAnimation(.easeInOut(duration: duration)) {
                    shakeOffset = offset
                }
            }
        }
    }
}

// MARK: - 文件拖拽区域

/// 支持拖拽文件的投放区域
struct PFFileDropZone: View {
    @Binding var isTargeted: Bool
    let onDropFile: (URL) -> Void
    
    var body: some View {
        ZStack {
            // 背景
            RoundedRectangle(cornerRadius: 12)
                .fill(isTargeted ? Color.blue.opacity(0.08) : Color.gray.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isTargeted ? Color.blue : Color.gray.opacity(0.3),
                            style: StrokeStyle(
                                lineWidth: isTargeted ? 2 : 1.5,
                                dash: [8, 6]
                            )
                        )
                )
                .animation(.easeInOut(duration: 0.2), value: isTargeted)
            
            // 内容
            VStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(isTargeted ? .blue : .secondary)
                    .animation(.easeInOut(duration: 0.2), value: isTargeted)
                
                Text(NSLocalizedString("drag_file_here", comment: ""))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isTargeted ? .primary : .secondary)
                
                Text(NSLocalizedString("support_formats", comment: ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 140)
        .onDrop(
            of: [UTType.image.identifier, UTType.text.identifier, UTType.pdf.identifier, UTType.movie.identifier, UTType.video.identifier, UTType.audio.identifier, UTType.item.identifier],
            isTargeted: $isTargeted
        ) { providers in
            for provider in providers {
                provider.loadItem(forTypeIdentifier: UTType.item.identifier, completionHandler: { (item, error) in
                    if let fileURL = item as? URL {
                        // 将系统文件拷贝到应用沙盒临时目录
                        Task { @MainActor in
                            do {
                                let tempDir = FileManager.default.temporaryDirectory
                                let tempURL = tempDir.appendingPathComponent(fileURL.lastPathComponent)
                                try FileManager.default.copyItem(at: fileURL, to: tempURL)
                                onDropFile(tempURL)
                            } catch {
                                onDropFile(fileURL)
                            }
                        }
                    }
                })
            }
            return true
        }
    }
}

// MARK: - 预览

struct PFFileUploadPreview_PreviewWrapper: View {
    @State var preparing = PFFileUploadItem(
        name: "宠物合照.jpg",
        url: URL(fileURLWithPath: "/tmp/宠物合照.jpg"),
        size: 2_456_789
    )
    
    @State var uploading = PFFileUploadItem(
        name: "疫苗接种记录.pdf",
        url: URL(fileURLWithPath: "/tmp/疫苗接种记录.pdf"),
        size: 1_048_576,
        state: .uploading,
        progress: 0.45
    )
    
    @State var processing = PFFileUploadItem(
        name: "日常vlog.mov",
        url: URL(fileURLWithPath: "/tmp/日常vlog.mov"),
        size: 52_428_800,
        state: .processing
    )
    
    @State var completed = PFFileUploadItem(
        name: "体检报告.pdf",
        url: URL(fileURLWithPath: "/tmp/体检报告.pdf"),
        size: 314_572,
        state: .completed(URL(fileURLWithPath: "/tmp/体检报告.pdf"))
    )
    
    @State var failed = PFFileUploadItem(
        name: "训练视频.mp4",
        url: URL(fileURLWithPath: "/tmp/训练视频.mp4"),
        size: 104_857_600,
        state: .failed("网络超时")
    )
    
    @State var isDropTargeted = false
    
    var body: some View {
        NavigationStack {
            ListView {
                VStack(spacing: 12) {
                    // 上传状态卡片
                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("upload_preview", comment: ""))
                            .font(.headline)
                        
                        PFFileUploadPreview(item: $preparing)
                        PFFileUploadPreview(item: $uploading)
                        PFFileUploadPreview(item: $processing)
                        PFFileUploadPreview(item: $completed)
                        PFFileUploadPreview(item: $failed, onRetry: {
                            failed = PFFileUploadItem(
                                name: "训练视频.mp4",
                                url: URL(fileURLWithPath: "/tmp/训练视频.mp4"),
                                size: 104_857_600,
                                state: .preparing
                            )
                        })
                    }
                    
                    // 拖拽区域
                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("drop_zone", comment: ""))
                            .font(.headline)
                        
                        PFFileDropZone(isTargeted: $isDropTargeted) { url in
                            print("Dropped file: \(url)")
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("file_upload_preview")
        }
    }
}

#Preview {
    PFFileUploadPreview_PreviewWrapper()
}

/// Preview 使用的简单列表容器（避免使用 ScrollView 影响预览渲染）
private struct ListView<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
    }
}
