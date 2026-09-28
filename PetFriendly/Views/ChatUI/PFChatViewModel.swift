//
//  PFChatViewModel.swift
//  PetFriendly
//
//  聊天 ViewModel 基础协议 — PFChatUI 设计模式包
//  所有聊天场景（急诊、社区对话等）遵循此协议
//

import Foundation
import SwiftUI
import Combine

// MARK: - 聊天场景类型
enum PFChatScene: String {
    case emergency = "emergency"     // 宠物急救
    case community = "community"     // 社区对话（后续）
    case service   = "service"       // 服务咨询
}

// MARK: - 聊天 ViewModel 协议
/// 所有聊天 ViewModel 必须遵循此协议
@MainActor
protocol PFChatViewModelProtocol: AnyObject, ObservableObject {
    /// 消息列表
    var messages: [ChatMessage] { get set }
    /// 是否正在加载历史消息
    var isLoadingHistory: Bool { get set }
    /// 是否更多历史可加载
    var hasMoreHistory: Bool { get set }
    /// 发送状态
    var isSending: Bool { get set }
    /// 当前聊天场景
    var scene: PFChatScene { get }

    /// 发送文本消息
    func send(text: String) async
    /// 发送文本消息（可引用/回复某条消息）
    func send(text: String, quoting reply: ChatMessage?) async
    /// 发送图片
    func send(image: UIImage) async
    /// 发送文件
    func send(fileAt url: URL) async
    /// 加载更多历史消息
    func loadHistory() async
    /// 重试失败消息
    func retry(message id: String) async
    /// 删除消息
    func delete(message id: String)
}

// MARK: - 基础 ViewModel 实现（提供通用逻辑）
@MainActor
class PFChatViewModelBase: PFChatViewModelProtocol {
    @Published var messages: [ChatMessage] = [] {
        didSet {
            saveMessagesLocally()
        }
    }
    @Published var isLoadingHistory = false
    @Published var hasMoreHistory = true
    @Published var isSending = false

    let scene: PFChatScene

    /// 已上传图片的 (原图URL, 缩略图URL) 缓存（去重）
    private var uploadedImageURLs: [String: (url: URL, thumbURL: URL?)] = [:]

    /// 流式回复期间临时挂起本地持久化，避免每个 token 都编码+写入 UserDefaults 阻塞主线程导致 UI 卡顿
    private var persistenceSuspended = false

    init(scene: PFChatScene) {
        self.scene = scene
        loadMessagesLocally()
    }

    private func saveMessagesLocally() {
        guard !persistenceSuspended else { return }
        let key = "PFChatHistory_\(scene.rawValue)"
        if let data = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// 挂起本地持久化（流式回复过程中调用，避免频繁写入造成显示延迟）
    func suspendPersistence() {
        persistenceSuspended = true
    }

    /// 恢复本地持久化并立即保存一次（流式回复结束时调用）
    func resumePersistence() {
        persistenceSuspended = false
        saveMessagesLocally()
    }

    private func loadMessagesLocally() {
        let key = "PFChatHistory_\(scene.rawValue)"
        if let data = UserDefaults.standard.data(forKey: key),
           let list = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            self.messages = list
        }
    }

    // MARK: - 发送文本（子类重写）
    func send(text: String) async {
        await send(text: text, quoting: nil)
    }

    /// 发送文本（可带引用，子类重写）
    func send(text: String, quoting reply: ChatMessage?) async {
        fatalError("必须由子类实现 \(#function)")
    }

    // MARK: - 发送图片（通用上传 + 单条消息生命周期）
    func send(image: UIImage) async {
        let imageId = "\(image.hashValue)"
        if let existing = uploadedImageURLs[imageId] {
            // 已上传过，复用 URL（仍作为一条新消息发送）
            await send(imageURL: existing.url, messageId: nil, thumbURL: existing.thumbURL)
            return
        }

        // 仅创建一条本地占位消息（修复「上传图片生成两条记录」的问题）
        let localMsg = ChatMessage(
            content: .image(url: URL(string: "placeholder://\(imageId)")!, thumbURL: nil),
            status: .sending,
            uploadProgress: 0
        )
        messages.append(localMsg)

        do {
            let result = try await uploadImage(image) { [weak self] progress in
                // 进度直接刷新该气泡的蒙版，不使用全局上传弹窗
                self?.updateMessage(id: localMsg.id) { msg in
                    msg.uploadProgress = progress
                }
            }
            uploadedImageURLs[imageId] = (url: result.url, thumbURL: result.thumbURL)

            // 上传完成：先标记 100%，随后由调用方关闭蒙版
            updateMessage(id: localMsg.id) { msg in
                msg = ChatMessage(
                    id: localMsg.id,
                    content: .image(url: result.url, thumbURL: result.thumbURL),
                    status: .sending,
                    isOutgoing: true,
                    uploadProgress: 1.0
                )
            }

            await send(imageURL: result.url, messageId: localMsg.id, thumbURL: result.thumbURL)

            // 展示 100% 后关闭蒙版
            try? await Task.sleep(nanoseconds: 400_000_000)
            updateMessage(id: localMsg.id) { msg in
                msg.uploadProgress = nil
            }
        } catch {
            updateMessage(id: localMsg.id) { msg in
                msg = ChatMessage(
                    id: localMsg.id,
                    content: .image(url: URL(string: "placeholder://\(imageId)")!, thumbURL: nil),
                    status: .failed(error.localizedDescription),
                    isOutgoing: true
                )
            }
        }
    }

    /// 发送已上传的图片 URL（子类重写）。messageId 非空时表示更新已有的占位消息，
    /// 避免重复记录；为空时由子类新建一条消息。thumbURL 为缩略图，用于列表快速展示。
    func send(imageURL: URL, messageId: String?, thumbURL: URL? = nil) async {
        fatalError("必须由子类实现 \(#function)")
    }

    // MARK: - 发送文件
    func send(fileAt url: URL) async {
        fatalError("必须由子类实现 \(#function)")
    }

    // MARK: - 加载历史（子类重写）
    func loadHistory() async {
        fatalError("必须由子类实现 \(#function)")
    }

    // MARK: - 重试
    func retry(message id: String) {
        guard let idx = messages.firstIndex(where: { $0.id == id }),
              case .failed = messages[idx].status else { return }
        let msg = messages[idx]
        messages[idx] = ChatMessage(
            id: msg.id,
            content: msg.content,
            senderId: msg.senderId,
            senderName: msg.senderName,
            senderAvatar: msg.senderAvatar,
            timestamp: msg.timestamp,
            status: .sending,
            isOutgoing: msg.isOutgoing
        )
        Task {
            switch msg.content {
            case .text(let text):
                await send(text: text)
            case .image(let url, let thumbURL):
                if url.absoluteString.hasPrefix("placeholder://") {
                    // 需要重新上传，但这里简化处理
                    break
                }
                await send(imageURL: url, messageId: msg.id, thumbURL: thumbURL)
            case .file(let name, let url, let size):
                await send(fileAt: url)
            case .system:
                break
            }
        }
    }

    // MARK: - 删除消息
    func delete(message id: String) {
        messages.removeAll { $0.id == id }
    }

    // MARK: - 添加消息（子类调用）
    func appendMessage(_ msg: ChatMessage) {
        messages.append(msg)
    }

    func updateMessage(id: String, transform: (inout ChatMessage) -> Void) {
        guard let idx = messages.firstIndex(where: { $0.id == id }) else { return }
        var msg = messages[idx]
        transform(&msg)
        messages[idx] = msg
    }

    // MARK: - 图片上传（复用 NetworkManager，抑制全局上传弹窗，并取回缩略图 URL）
    private func uploadImage(_ image: UIImage, onProgress: ((Double) -> Void)? = nil) async throws -> (url: URL, thumbURL: URL?) {
        return try await NetworkManager.shared.uploadChatImage(
            image,
            onProgress: onProgress
        )
    }
}
