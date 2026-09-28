import SwiftUI

struct HeaderImageSettingView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @EnvironmentObject private var uiState: UIState
    @State private var selectedImage: UIImage?
    @State private var uploadError: String?
    @State private var showImagePicker = false
    
    // 裁剪相关状态
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    // 名片比例 约 3.35:1
    private let aspectRatio: CGFloat = 3.35
    private var frameWidth: CGFloat { PFScreen.width - 40 }
    private var frameHeight: CGFloat { frameWidth / aspectRatio }
    
    var body: some View {
        ZStack {
            PFColors.background.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // 预览区
                VStack(spacing: 12) {
                    HStack {
                        Text(NSLocalizedString("theme_preview_title", comment: ""))
                            .font(PFFonts.caption)
                            .foregroundColor(PFColors.textSecondary)
                        Spacer()
                        if selectedImage != nil {
                            Text(NSLocalizedString("drag_zoom_hint", comment: ""))
                                .font(PFFonts.caption)
                                .foregroundColor(PFColors.primary)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    ZStack(alignment: .top) {
                        // 背景占位/图片 (裁剪容器)
                        ZStack {
                            if let uiImage = selectedImage {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .scaleEffect(scale)
                                    .offset(offset)
                                    .gesture(
                                        DragGesture()
                                            .onChanged { value in
                                                offset = CGSize(
                                                    width: lastOffset.width + value.translation.width,
                                                    height: lastOffset.height + value.translation.height
                                                )
                                            }
                                            .onEnded { _ in
                                                lastOffset = offset
                                            }
                                    )
                                    .simultaneousGesture(
                                        MagnificationGesture()
                                            .onChanged { value in
                                                scale = lastScale * value
                                            }
                                            .onEnded { _ in
                                                lastScale = scale
                                            }
                                    )
                            } else if !themeManager.headerBackgroundImageUrl.isEmpty {
                                CachedAsyncImage(url: NetworkManager.fullUrl(themeManager.headerBackgroundImageUrl)) { image in
                                    image.resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    PFPetLoadingInline(size: 18)
                                }
                            } else {
                                PFColors.surfaceSecondary
                            }
                        }
                        .frame(width: frameWidth, height: frameHeight)
                        .clipped() // 强制剪裁到 16:5 容器
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(PFColors.primary.opacity(0.3), lineWidth: 1)
                        )
                        
                        // 1. 蒙层遮罩
                        if selectedImage != nil || !themeManager.headerBackgroundImageUrl.isEmpty {
                            LinearGradient(
                                colors: [.black.opacity(0.4), .black.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .cornerRadius(12)
                        }
                        
                        // 2. 模拟 AvatarCard 的布局内容
                        HStack(spacing: 16) {
                            // 模拟头像
                            Circle()
                                .fill(.white.opacity(0.2))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Circle().stroke(.white.opacity(0.5), lineWidth: 2)
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(NSLocalizedString("your_nickname", comment: ""))
                                    .font(PFFonts.headline)
                                    .foregroundColor(.white)
                                
                                HStack(spacing: 12) {
                                    Label("0", systemImage: "heart.fill")
                                    Label("0", systemImage: "dollarsign.circle")
                                }
                                .font(PFFonts.caption)
                                .foregroundColor(.white.opacity(0.9))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 25)
                    }
                    .frame(width: frameWidth, height: frameHeight)
                }
                .padding(.top, 20)
                
                // 操作区
                VStack(spacing: 16) {
                    if uiState.isUploading || uiState.isUploadFinished {
                         EmptyView()
                    } else {
                        Button(action: {
                            showImagePicker = true
                        }) {
                            Label(selectedImage == nil ? NSLocalizedString("select_image", comment: "") : "重新选择", systemImage: "photo.on.rectangle.angled")
                                .font(PFFonts.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(PFColors.primary)
                                .cornerRadius(25)
                                .pfCardShadow()
                        }
                        
                        if selectedImage != nil {
                            Button(action: processAndUpload) {
                                Text(NSLocalizedString("save_and_upload", comment: ""))
                                    .font(PFFonts.headline)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(PFColors.success)
                            .cornerRadius(25)
                            .pfCardShadow()
                        }
                    }
                    
                    if !uiState.isUploading && !uiState.isUploadFinished && !themeManager.headerBackgroundImageUrl.isEmpty {
                        Button(action: {
                            themeManager.updateHeaderImage("")
                            Haptics.play(.medium)
                        }) {
                            Text(NSLocalizedString("restore_bg", comment: ""))
                                .font(PFFonts.callout)
                                .foregroundColor(PFColors.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 40)
                .animation(.spring(), value: uiState.isUploading)
                
                if let error = uploadError {
                    Text(error)
                        .font(PFFonts.caption)
                        .foregroundColor(PFColors.danger)
                        .padding(.top, 8)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("tips_label", comment: ""))
                        .font(PFFonts.caption)
                        .fontWeight(.bold)
                    Text(NSLocalizedString("tip_drag", comment: ""))
                    Text(NSLocalizedString("tip_pinch", comment: ""))
                    Text(NSLocalizedString("tip_sync", comment: ""))
                }
                .font(PFFonts.caption)
                .foregroundColor(PFColors.textTertiary)
                .padding(.horizontal, 40)
                .padding(.bottom, 100)
            }
        }
        .navigationTitle("namecard_bg_setting")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage)
        }
    }
    
    private func processAndUpload() {
        guard let image = selectedImage else { return }
        let croppedImage = cropImage(image)
        
        // 优化：使用 0.8 质量可以大幅缩小体积且人眼无差别
        guard let data = croppedImage.jpegData(compressionQuality: 0.8) else {
            uploadError = "图片处理失败"
            return
        } 
        uiState.isUploading = true
        uiState.uploadProgress = 0.0
        uiState.isUploadFinished = false
        uploadError = nil
        
        Task {
            do {
                let resp: RespWrapper<String> = try await NetworkManager.shared.upload(
                    path: "/petFriendly/client/upload",
                    fileData: data,
                    mimeType: "image/jpeg",
                    onProgress: { progress in
                        DispatchQueue.main.async {
                            uiState.uploadProgress = progress
                        }
                    }
                )
                
                await MainActor.run {
                    uiState.uploadProgress = 1.0
                    uiState.isUploadFinished = true
                }
                
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                
                await MainActor.run {
                    themeManager.updateHeaderImage(resp.data ?? "")
                    uiState.isUploading = false
                    uiState.isUploadFinished = false
                    Haptics.notify(.success)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    uploadError = "上传失败: \(error.localizedDescription)"
                    uiState.isUploading = false
                    uiState.isUploadFinished = false
                    Haptics.notify(.error)
                }
            }
        }
    }
    
    /// 根据当前 Offset 和 Scale 裁切 UIImage
    private func cropImage(_ image: UIImage) -> UIImage {
        // 计算 UI 呈现时的图片实际尺寸（Aspect Fill 下）
        let imageSize = image.size
        let widthRatio = frameWidth / imageSize.width
        let heightRatio = frameHeight / imageSize.height
        let baseScale = max(widthRatio, heightRatio)
        
        let displayedWidth = imageSize.width * baseScale * scale
        let displayedHeight = imageSize.height * baseScale * scale
        
        // 计算裁切区域相对于原始图片的坐标
        // 1. 先计算图片中心偏移量
        let xOffset = offset.width / (baseScale * scale)
        let yOffset = offset.height / (baseScale * scale)
        
        // 2. 目标矩形在原图中的宽度和高度
        let cropWidth = frameWidth / (baseScale * scale)
        let cropHeight = frameHeight / (baseScale * scale)
        
        // 3. 计算起始点 (原图坐标系)
        let originX = (imageSize.width - cropWidth) / 2.0 - xOffset
        let originY = (imageSize.height - cropHeight) / 2.0 - yOffset
        
        let cropRect = CGRect(x: originX, y: originY, width: cropWidth, height: cropHeight)
        
        UIGraphicsBeginImageContextWithOptions(CGSize(width: frameWidth * 2, height: frameHeight * 2), false, 1.0)
        image.draw(in: CGRect(x: -originX * (frameWidth * 2 / cropWidth),
                              y: -originY * (frameHeight * 2 / cropHeight),
                              width: imageSize.width * (frameWidth * 2 / cropWidth),
                              height: imageSize.height * (frameHeight * 2 / cropHeight)))
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return result ?? image
    }
}
