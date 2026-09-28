//
//  ChatMessage.swift
//  PetFriendly
//
//  聊天消息核心数据模型 — PFChatUI 设计模式包
//  支持文本/图片/文件/系统消息，发送状态，反应表情
//

import Foundation
import SwiftUI

// MARK: - 发送状态
enum MessageStatus: Codable, Equatable {
    case sending
    case sent
    case delivered
    case read
    case failed(String)

    var iconName: String {
        switch self {
        case .sending:  return "clock"
        case .sent:     return "checkmark"
        case .delivered: return "checkmark.message"
        case .read:     return "checkmark.message.fill"
        case .failed:   return "exclamationmark.circle"
        }
    }

    var tintColor: Color {
        switch self {
        case .read:     return .blue
        case .failed:   return .red
        default:        return .secondary
        }
    }
}

// MARK: - 消息内容类型
enum MessageContent: Codable, Equatable {
    case text(String)
    case image(url: URL, thumbURL: URL?)
    case file(name: String, url: URL, size: Int64)
    case system(String) // 时间分隔线、系统提示等

    var isSystem: Bool {
        if case .system = self { return true }
        return false
    }
}

// MARK: - 核心消息模型
struct ChatMessage: Identifiable, Codable, Equatable {
    let id: String
    let content: MessageContent
    let senderId: String
    let senderName: String
    let senderAvatar: String?
    let timestamp: Date
    let status: MessageStatus
    let isOutgoing: Bool
    let reactions: [String]
    /// 是否正在流式输出中。仅运行时状态，不持久化语义（可选以兼容旧版历史数据）。
    /// 流式阶段气泡用纯文本渲染（避免逐字解析 Markdown 造成 O(n²) 卡顿），结束后才格式化。
    let isStreaming: Bool?
    /// 被引用（回复）的消息 ID（长按回复时设置）
    let quotedMessageId: String?
    /// 被引用消息的简短预览文本（用于气泡顶部引用条）
    let quotedPreview: String?
    /// 图片上传进度（0.0~1.0）；nil 表示非上传中。用于聊天内图片气泡的蒙版进度展示。
    var uploadProgress: Double?

    init(
        id: String = UUID().uuidString,
        content: MessageContent,
        senderId: String = "",
        senderName: String = "",
        senderAvatar: String? = nil,
        timestamp: Date = Date(),
        status: MessageStatus = .sending,
        isOutgoing: Bool = true,
        reactions: [String] = [],
        isStreaming: Bool? = nil,
        quotedMessageId: String? = nil,
        quotedPreview: String? = nil,
        uploadProgress: Double? = nil
    ) {
        self.id = id
        self.content = content
        self.senderId = senderId
        self.senderName = senderName
        self.senderAvatar = senderAvatar
        self.timestamp = timestamp
        self.status = status
        self.isOutgoing = isOutgoing
        self.reactions = reactions
        self.isStreaming = isStreaming
        self.quotedMessageId = quotedMessageId
        self.quotedPreview = quotedPreview
        self.uploadProgress = uploadProgress
    }

    // MARK: - 引用预览文本

    /// 用于引用条展示的简短文本：文本消息取内容，图片/文件取占位文案。
    var previewText: String {
        switch content {
        case .text(let t): return t
        case .image: return "图片"
        case .file(let n, _, _): return n
        case .system(let t): return t
        }
    }

    // MARK: - Convenience 构造

    static func text(_ text: String, isOutgoing: Bool = true, status: MessageStatus = .sent) -> ChatMessage {
        ChatMessage(content: .text(text), status: status, isOutgoing: isOutgoing)
    }

    static func image(_ url: URL, thumbURL: URL? = nil, isOutgoing: Bool = true) -> ChatMessage {
        ChatMessage(content: .image(url: url, thumbURL: thumbURL), isOutgoing: isOutgoing)
    }

    static func file(name: String, url: URL, size: Int64, isOutgoing: Bool = true) -> ChatMessage {
        ChatMessage(content: .file(name: name, url: url, size: size), isOutgoing: isOutgoing)
    }

    static func system(_ text: String) -> ChatMessage {
        ChatMessage(content: .system(text), senderId: "system", isOutgoing: false)
    }

    // MARK: - Preview 数据

    static let previewOutgoing: ChatMessage = .text(
        "带狗狗去过这家店，环境很好，有专门的宠物区！",
        isOutgoing: true,
        status: .read
    )

    static let previewIncoming: ChatMessage = .text(
        "是的，这里有宠物专属休息区，还有免费的饮用水提供 🐾",
        isOutgoing: false,
        status: .read
    )

    static let previewImage: ChatMessage = .image(
        URL(string: "https://picsum.photos/400/300")!,
        thumbURL: nil,
        isOutgoing: true
    )

    static var previewMessages: [ChatMessage] = [
        .system("2024-01-15 14:30"),
        previewIncoming,
        previewOutgoing,
        .text("具体位置在哪里呀？", isOutgoing: true, status: .delivered),
        .text("就在朝阳区建国路88号，地铁大望路站B口出来就是", isOutgoing: false),
        previewImage,
        .system("2024-01-15 15:00"),
        .text("好的，谢谢！下午带毛孩子去看看 🐕", isOutgoing: true, status: .read),
    ]
}
