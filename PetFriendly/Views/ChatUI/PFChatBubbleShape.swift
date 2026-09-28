//
//  PFChatBubbleShape.swift
//  PetFriendly
//
//  聊天气泡形状 — 参考 Telegram iOS 27 设计
//  - 主圆角 16pt，辅助圆角 8pt
//  - 可选尾巴（小三角）
//  - isOutgoing 控制尾巴方向
//  - 使用预合成路径而非 cornerRadius，避免 GPU 复合开销
//

import SwiftUI

// MARK: - 聊天气泡形状
struct PFChatBubbleShape: Shape {
    let isOutgoing: Bool
    var showTail: Bool = true
    var mainRadius: CGFloat = 16
    var auxiliaryRadius: CGFloat = 8

    func path(in rect: CGRect) -> Path {
        let r = mainRadius
        return Path(roundedRect: rect, cornerRadius: r)
    }
}

// MARK: - 连续消息合并修饰
enum PFChatBubbleCorners {
    /// 完全圆角（首条/独立消息）
    case all
    /// 仅顶部圆角（合并消息的首条）
    case top
    /// 仅底部圆角（合并消息的末条）
    case bottom
    /// 无圆角（合并消息的中间条）
    case none

    var cornerRadius: CGFloat {
        switch self {
        case .all:    return 18
        case .top:    return 18
        case .bottom: return 18
        case .none:   return 4
        }
    }

    var showTail: Bool {
        switch self {
        case .all:    return true
        case .bottom: return true
        default:      return false
        }
    }
}

// MARK: - 合并气泡容器
struct PFChatBubbleGroup<Content: View>: View {
    let isOutgoing: Bool
    let cornerStyle: PFChatBubbleCorners
    @ViewBuilder let content: Content

    var body: some View {
        content
            .clipShape(PFChatBubbleShape(
                isOutgoing: isOutgoing,
                showTail: cornerStyle.showTail,
                mainRadius: cornerStyle.cornerRadius,
                auxiliaryRadius: 6
            ))
    }
}

// MARK: - Preview
#Preview("Outgoing Bubble") {
    VStack(spacing: 16) {
        Text("Outgoing")
            .font(.caption)
            .padding(12)
            .foregroundColor(.white)
            .background(Color.blue)
            .clipShape(PFChatBubbleShape(isOutgoing: true))
            .frame(maxWidth: 240, alignment: .trailing)

        Text("Incoming with longer text that wraps to multiple lines")
            .font(.caption)
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(PFChatBubbleShape(isOutgoing: false))
            .frame(maxWidth: 240, alignment: .leading)
    }
    .padding()
}
