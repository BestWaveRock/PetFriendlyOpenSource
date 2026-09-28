//
//  PFChatBubble.swift
//  PetFriendly
//
//  聊天气泡组件 — Telegram iOS 27 风格
//  渲染文本 / 图片 / 文件 / 系统消息，支持状态图标、反应表情、上下文菜单
//

import SwiftUI
import UIKit
import Photos

// MARK: - 聊天气泡主组件

/// Telegram iOS 27 风格聊天气泡，支持文本、图片、文件、系统消息
struct PFChatBubble: View {
    /// 消息数据
    let message: ChatMessage
    /// 气泡圆角样式（独立 / 合并消息）
    let cornerStyle: PFChatBubbleCorners
    /// 长按是否允许唤起上下文菜单
    var allowContextMenu: Bool = true
    /// 添加/切换反应表情的回调
    var onReact: ((String) -> Void)?
    /// 长按回复（引用）消息
    var onReply: (() -> Void)?
    /// 重试发送失败的消息
    var onRetry: (() -> Void)?
    /// 删除消息
    var onDelete: (() -> Void)?

    /// 进入动画标记
    @State private var appeared = false
    @State private var showsFullTimestamp = false
    @State private var timestampResetTask: Task<Void, Never>?
    @State private var previewItem: PFAttachmentItem?

    /// 快捷反应表情列表
    private let quickReactions = ["👍", "❤️", "😂", "😮", "😢"]

    var body: some View {
        if message.content.isSystem {
            systemMessage
        } else {
            bubbleContainer
        }
    }

    // MARK: - 系统消息

    private var systemMessage: some View {
        Group {
            if case .system(let text) = message.content {
                Text(text)
                    .font(PFFonts.caption2)
                    .foregroundColor(PFColors.textTertiary)
                    .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .scaleEffect(appeared ? 1 : 0.8)
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.25), value: appeared)
        .onAppear { appeared = true }
    }

    // MARK: - 气泡容器

    @ViewBuilder
    private var bubbleContainer: some View {
        HStack {
            if message.isOutgoing {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.isOutgoing ? .trailing : .leading, spacing: 2) {
                bubbleContent
                if !message.reactions.isEmpty {
                    reactionsBar
                }
            }

            if !message.isOutgoing {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, alignment: message.isOutgoing ? .trailing : .leading)
        .scaleEffect(appeared ? 1 : 0.8)
        .opacity(appeared ? 1 : 0)
        .animation(PFAnimation.springBouncy, value: appeared)
        .onAppear { appeared = true }
        .contextMenu {
            if allowContextMenu {
                contextMenuItems
            }
        }
        .sheet(item: $previewItem) { item in
            PFAttachmentPreview(url: item.url)
        }
    }

    // MARK: - 气泡内容（含背景形状 + 内边距）

    @ViewBuilder
    private var bubbleContent: some View {
        // 使用 cornerStyle 控制圆角和尾巴
        let bubbleShape = PFChatBubbleShape(
            isOutgoing: message.isOutgoing,
            showTail: cornerStyle.showTail,
            mainRadius: 18,
            auxiliaryRadius: 6
        )

        if isImageMessage, let url = imageURL {
            // 图片消息：不展示气泡背景，图片直接裁切为气泡圆角形状（自适应圆角）
            VStack(alignment: message.isOutgoing ? .trailing : .leading, spacing: 2) {
                ZStack {
                    imageContent(url)
                    // 上传进度蒙版：直接覆盖在图片气泡上，100% 后由 ViewModel 关闭
                    if let progress = message.uploadProgress, progress < 1.0 {
                        uploadMask(progress: progress)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { previewItem = PFAttachmentItem(url: originalImageURL ?? url) }
                .clipShape(bubbleShape)
                timestampRow
                    .padding(.top, 2)
            }
        } else {
            VStack(alignment: message.isOutgoing ? .trailing : .leading, spacing: 0) {
                messageContentArea
                timestampRow
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(bubbleBackground)
            .clipShape(bubbleShape)
        }
    }

    /// 当前消息是否为图片消息
    private var isImageMessage: Bool {
        if case .image = message.content { return true }
        return false
    }

    /// 当前图片消息的 URL（若存在）。优先使用缩略图，未提供时回退原图，以提升列表加载速度。
    private var imageURL: URL? {
        if case .image(let url, let thumbURL) = message.content { return thumbURL ?? url }
        return nil
    }

    // MARK: - 消息内容区域

    @ViewBuilder
    private var messageContentArea: some View {
        switch message.content {
        case .text(let text):
            // 流式输出阶段用纯文本渲染：避免每个 token 都重新解析整段 Markdown 造成的 O(n²) 卡顿。
            // 纯文本完整保留换行与缩进。流式结束（isStreaming == nil/false）后再渲染 Markdown 格式。
            if message.isStreaming == true {
                styledBubbleText(Text(text))
            } else {
                // 渲染 Markdown（**加粗**、列表、标题、行内代码等），同时严格保留 AI 回复中的
                // 换行与缩进：采用「逐行解析 Markdown + 用真实 \n 拼接」的方式。
                // 若整体交给 AttributedString(markdown:) 解析，单行换行会被折叠成空格、连续空白被合并。
                styledBubbleText(Text(renderMarkdown(text)))
            }

        case .image(let url, let thumbURL):
            imageContent(thumbURL ?? url)

        case .file(let name, let url, let size):
            fileContent(name: name, url: url, size: size)

        case .system:
            // System handled separately
            EmptyView()
        }
    }

    // MARK: - 图片内容

    @ViewBuilder
    private func imageContent(_ url: URL) -> some View {
        if url.isFileURL, let local = UIImage(contentsOfFile: url.path) {
            Image(uiImage: local)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxHeight: 200)
                .clipped()
        } else {
            CachedAsyncImage(url: url) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxHeight: 200)
                .clipped()
        } placeholder: {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 150)
                .overlay {
                    ProgressView()
                }
            }
        }
    }

    /// 上传进度蒙版：覆盖在图片气泡上，展示环形进度与百分比，100% 后由 ViewModel 置空关闭
    private func uploadMask(progress: Double) -> some View {
        ZStack {
            Color.black.opacity(0.45)

            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
                        .stroke(Color.white, lineWidth: 4)
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "icloud.and.arrow.up")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
                .frame(width: 44, height: 44)

                Text("\(Int(min(max(progress, 0), 1) * 100))%")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
    }

    // MARK: - 文件内容

    private func fileContent(name: String, url: URL, size: Int64) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.fill")
                .font(.title2)
                .foregroundColor(textColor.opacity(0.6))

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(PFFonts.body)
                    .foregroundColor(textColor)
                    .lineLimit(2)

                Text(formatFileSize(size))
                    .font(PFFonts.caption)
                    .foregroundColor(textColor.opacity(0.6))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { previewItem = PFAttachmentItem(url: url) }
    }

    // MARK: - 时间戳

    private var timestampRow: some View {
        HStack(spacing: 4) {
            if message.isOutgoing {
                FlexibleSpace()
            }

            Text(formatTimestamp(message.timestamp))
                .font(PFFonts.caption2)
                .foregroundColor(textColor.opacity(0.6))
                .lineLimit(1)
                .onTapGesture { toggleTimestamp() }

            if message.isOutgoing {
                statusIcon
                    .foregroundColor(textColor.opacity(0.7))
            }

            if !message.isOutgoing {
                FlexibleSpace()
            }
        }
        .padding(.top, 4)
    }

    // MARK: - 状态图标

    @ViewBuilder
    private var statusIcon: some View {
        Group {
            switch message.status {
            case .sending:
                // 旋转加载 indicator
                Image(systemName: "circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .modifier(RotatingSpinner())

            case .sent:
                Image(systemName: MessageStatus.sent.iconName)
                    .font(.caption)
                    .foregroundColor(MessageStatus.sent.tintColor)

            case .delivered:
                Image(systemName: MessageStatus.delivered.iconName)
                    .font(.caption)
                    .foregroundColor(MessageStatus.delivered.tintColor)

            case .read:
                Image(systemName: MessageStatus.read.iconName)
                    .font(.caption)
                    .foregroundColor(MessageStatus.read.tintColor)

            case .failed:
                Image(systemName: MessageStatus.failed("").iconName)
                    .font(.caption)
                    .foregroundColor(MessageStatus.failed("").tintColor)
                    .onTapGesture { onRetry?() }
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: message.status)
    }

    // MARK: - 反应表情栏

    private var reactionsBar: some View {
        HStack(spacing: 4) {
            ForEach(message.reactions.prefix(6), id: \.self) { emoji in
                Text(emoji)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Capsule())
            }
            if message.reactions.count > 6 {
                Text("+\(message.reactions.count - 6)")
                    .font(PFFonts.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.leading, message.isOutgoing ? 24 : 4)
        .padding(.trailing, message.isOutgoing ? 4 : 24)
    }

    // MARK: - 上下文菜单

    private var contextMenuItems: some View {
        Group {
            // 回复（引用）消息
            Button {
                onReply?()
            } label: {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
            }

            // 复制文本（仅文本消息）
            if case .text(let text) = message.content {
                Button {
                    UIPasteboard.general.string = text
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }

            // 重试（仅失败消息）
            if case .failed = message.status {
                Button(role: nil) {
                    onRetry?()
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
            }

            Divider()

            // 反应表情选择器
            ForEach(quickReactions, id: \.self) { emoji in
                Button {
                    onReact?(emoji)
                } label: {
                    Text(emoji)
                }
            }

            Divider()

            // 删除
            Button(role: .destructive) {
                onDelete?()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - 辅助属性

    private var bubbleBackground: Color {
        message.isOutgoing ? outgoingBubbleColor : incomingBubbleColor
    }

    /// 发送方气泡颜色：iMessage 蓝色
    private var outgoingBubbleColor: Color {
        Color(red: 0.0, green: 0.48, blue: 1.0)
    }

    /// 接收方气泡颜色：系统灰色背景
    private var incomingBubbleColor: Color {
        Color(.systemGray6)
    }

    private var textColor: Color {
        message.isOutgoing ? .white : .primary
    }

}

// MARK: - 文件大小格式化

extension PFChatBubble {
    /// 气泡文本统一字号/字距/行距/颜色与自适应高度样式。
    @ViewBuilder
    private func styledBubbleText(_ content: Text) -> some View {
        content
            .font(.system(size: 16))
            .tracking(0.3)
            .lineSpacing(5)
            .foregroundColor(textColor)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// 将文本按行解析 Markdown 后拼接，既渲染 **加粗**/列表/标题等行内样式，
    /// 又用真实的换行符保留 AI 回复里的段落与缩进，避免整体 Markdown 解析把单行换行折叠成空格。
    private func renderMarkdown(_ raw: String) -> AttributedString {
        var result = AttributedString()
        let lines = raw.components(separatedBy: "\n")
        for (index, line) in lines.enumerated() {
            if index > 0 {
                result.append(AttributedString("\n"))
            }
            if line.isEmpty { continue }
            if let attr = try? AttributedString(markdown: line) {
                result.append(attr)
            } else {
                result.append(AttributedString(line))
            }
        }
        return result
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let fmt = ByteCountFormatter()
        fmt.countStyle = .file
        return fmt.string(fromByteCount: bytes)
    }

    private func formatTimestamp(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = showsFullTimestamp ? "yyyy-MM-dd HH:mm:ss" : "HH:mm"
        return fmt.string(from: date)
    }

    private var originalImageURL: URL? {
        if case .image(let url, _) = message.content { return url }
        return nil
    }

    private func toggleTimestamp() {
        timestampResetTask?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) { showsFullTimestamp.toggle() }
        guard showsFullTimestamp else { return }
        timestampResetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) { showsFullTimestamp = false }
        }
    }
}

private struct PFAttachmentPreview: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var saveMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if let image = localImage {
                    ZoomableImage(image: Image(uiImage: image))
                } else if isImage {
                    CachedAsyncImage(url: url) { image in ZoomableImage(image: image) } placeholder: { ProgressView() }
                } else {
                    VStack(spacing: 18) {
                        Image(systemName: "doc.fill").font(.system(size: 64)).foregroundStyle(.secondary)
                        Text(url.lastPathComponent).font(.headline)
                        ShareLink(item: url) { Label("common_download", systemImage: "square.and.arrow.down") }
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("common_close") { dismiss() } }
                ToolbarItemGroup(placement: .primaryAction) {
                    if isImage { Button { Task { await saveImageToPhotos() } } label: { Image(systemName: "photo.badge.arrow.down") } }
                    ShareLink(item: url) { Image(systemName: "folder.badge.plus") }
                }
            }
        }
        .alert(saveMessage ?? "", isPresented: Binding(get: { saveMessage != nil }, set: { if !$0 { saveMessage = nil } })) { Button("common_ok") {} }
    }

    private var localImage: UIImage? { url.isFileURL ? UIImage(contentsOfFile: url.path) : nil }
    private var isImage: Bool { ["jpg", "jpeg", "png", "gif", "heic", "webp"].contains(url.pathExtension.lowercased()) }

    private func saveImageToPhotos() async {
        do {
            let data = url.isFileURL ? try Data(contentsOf: url) : try await URLSession.shared.data(from: url).0
            guard let image = UIImage(data: data) else { throw URLError(.cannotDecodeContentData) }
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            saveMessage = NSLocalizedString("chat_image_saved_to_photos", comment: "")
        } catch { saveMessage = error.localizedDescription }
    }
}

private struct PFAttachmentItem: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

private struct ZoomableImage: View {
    let image: Image
    @State private var scale: CGFloat = 1
    var body: some View {
        image.resizable().scaledToFit().scaleEffect(scale)
            .gesture(MagnificationGesture().onChanged { scale = max(1, min($0, 5)) }.onEnded { scale = max(1, min($0, 5)) })
            .onTapGesture(count: 2) { withAnimation { scale = scale > 1 ? 1 : 2 } }
    }
}


// MARK: - 旋转动画修饰符

/// 为 sending 状态的 spinner 提供持续旋转动画
struct RotatingSpinner: ViewModifier {
    @State private var rotation: Angle = .degrees(0)

    func body(content: Content) -> some View {
        content
            .onAppear {
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    rotation = .degrees(360)
                }
            }
            .rotationEffect(rotation)
    }
}

// MARK: - 弹性空白

/// 自适应空白占位（比 Spacer() 更轻量）
struct FlexibleSpace: View {
    var body: some View {
        Spacer(minLength: 0)
    }
}

// MARK: - Preview

#Preview("Chat Bubbles") {
    ScrollView {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(ChatMessage.previewMessages) { msg in
                PFChatBubble(
                    message: msg,
                    cornerStyle: .all
                )
            }
        }
        .padding()
        .background(PFColors.background)
    }
}
