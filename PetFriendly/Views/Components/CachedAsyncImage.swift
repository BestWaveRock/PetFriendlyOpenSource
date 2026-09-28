//
//  CachedAsyncImage.swift
//  PetFriendly
//
//  Created by PetFriendly Team on 2026/03/22.
//

import SwiftUI

/// 自定义异步图片组件 (带内存缓存)
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    private let url: URL?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder
    
    @State private var phase: AsyncImagePhase = .empty
    @State private var activeTask: URLSessionDataTask? = nil
    // 单调递增的加载序号，用于忽略旧任务的结果，避免 view 快速重建时的竞态崩溃
    @State private var loadID: Int = 0
    
    init(url: URL?,
         @ViewBuilder content: @escaping (Image) -> Content,
         @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            switch phase {
            case .empty:
                placeholder()
                    .onAppear {
                        loadImage()
                    }
            case .success(let image):
                content(image)
            case .failure(_):
                placeholder() // 失败时退回 placeholder
            @unknown default:
                placeholder()
            }
        }
        .onChange(of: url) { _ in
            loadImage()
        }
        .onDisappear {
            activeTask?.cancel()
            activeTask = nil
        }
    }
    
    private func loadImage() {
        guard let url = url else {
            phase = .empty
            return
        }
        
        // 1. 检查内存缓存
        if let cachedImage = ImageCacheManager.shared.get(forKey: url.absoluteString) {
            phase = .success(Image(uiImage: cachedImage))
            return
        }
        
        // 2. 网络加载 - 每次加载递增序号，并取消上一次未完成的任务
        activeTask?.cancel()
        loadID += 1
        let myID = loadID

        // 在后台线程解码，结果回到主线程后需校验序号，避免旧任务覆盖新状态。
        // loadImage 由 body 的 onAppear/onChange 调用（主线程），@State 读写安全。
        // URLSession 回调在任意线程执行：解码在后台完成，更新 @State 时用 Task { @MainActor }
        // 保证在主线程，并通过 myID 校验忽略过期结果，规避 iOS 27 并发更新 @State 的崩溃。
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            // 解码工作在后台线程完成，避免阻塞主线程
            let result: Result<UIImage, Error>
            if let data = data, error == nil {
                result = Self.decodeImage(data: data)
            } else {
                result = .failure(error ?? NSError(domain: "ImageError", code: -1))
            }

            // 回到主线程更新状态；仅当序号仍匹配时写入，防止竞态覆盖
            Task { @MainActor in
                guard myID == loadID else { return }
                switch result {
                case .success(let ui):
                    ImageCacheManager.shared.set(ui, forKey: url.absoluteString)
                    phase = .success(Image(uiImage: ui))
                case .failure(let err):
                    phase = .failure(err)
                }
            }
        }
        task.resume()
        activeTask = task
    }
    
    /// 在任意线程解码图片（UIImage 解码是线程安全的）
    private static func decodeImage(data: Data) -> Result<UIImage, Error> {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 800
        ]
        if let source = CGImageSourceCreateWithData(data as CFData, nil),
           let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
            return .success(UIImage(cgImage: cgImage))
        }
        if let ui = UIImage(data: data) {
            return .success(ui)
        }
        return .failure(NSError(domain: "ImageError", code: -1))
    }
}
