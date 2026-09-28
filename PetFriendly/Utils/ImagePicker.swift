import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// 全局统一的上传来源面板。旧调用保持兼容，新入口不再各自实现相机/相册/文件选择。
public struct ImagePicker: View {
    @Binding private var image: UIImage?
    private let fileURL: Binding<URL?>?
    private let preferredSource: UIImagePickerController.SourceType?

    @Environment(\.dismiss) private var dismiss
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var showFiles = false
    @State private var errorMessage: String?
    @State private var didApplyPreferredSource = false
    @State private var isExpanded = false

    public init(image: Binding<UIImage?>) {
        _image = image
        fileURL = nil
        preferredSource = nil
    }

    public init(image: Binding<UIImage?>, sourceType: UIImagePickerController.SourceType) {
        _image = image
        fileURL = nil
        preferredSource = sourceType
    }

    /// 同时支持普通文件的业务（例如聊天附件）可传入 fileURL。
    public init(image: Binding<UIImage?>, fileURL: Binding<URL?>) {
        _image = image
        self.fileURL = fileURL
        preferredSource = nil
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if isExpanded {
                    header
                        .transition(.move(edge: .top).combined(with: .opacity))
                } else {
                    Text("upload_sources_headline")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                VStack(spacing: 12) {
                    sourceButton(title: tr("upload_camera"), subtitle: tr("upload_camera_desc"), icon: "camera.fill", tint: .blue) {
                        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                            errorMessage = tr("upload_camera_unavailable")
                            return
                        }
                        showCamera = true
                    }
                    sourceButton(title: tr("upload_photo_library"), subtitle: tr("upload_photo_library_desc"), icon: "photo.on.rectangle.angled", tint: .purple) {
                        showLibrary = true
                    }
                    sourceButton(title: tr("upload_browse_files"), subtitle: fileURL == nil ? tr("upload_image_file_desc") : tr("upload_attachment_file_desc"), icon: "folder.fill", tint: .orange) {
                        showFiles = true
                    }
                }
                Spacer(minLength: 12)
                Text("upload_privacy_notice")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(20)
            .navigationTitle("upload_picker_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("common_cancel") { dismiss() } } }
        }
        .modifier(ImagePickerSheetStyle(isExpanded: $isExpanded))
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { selected in complete(image: selected) }
                .ignoresSafeArea()
                .background(Color.black.ignoresSafeArea())
                .statusBarHidden(true)
        }
        .sheet(isPresented: $showLibrary) {
            PhotoLibraryPicker { selected in complete(image: selected) }
                // 相册默认以接近 4:3 的非全屏高度展示，仍可由用户上拉展开。
                .presentationDetents([.fraction(0.72), .large])
                .presentationDragIndicator(.visible)
        }
        .fileImporter(
            isPresented: $showFiles,
            allowedContentTypes: fileURL == nil ? [.image] : [.item],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let url = try result.get().first else { return }
                if let data = try? Data(contentsOf: url), let selected = UIImage(data: data) {
                    complete(image: selected)
                } else if let fileURL {
                    fileURL.wrappedValue = url
                    dismiss()
                } else {
                    errorMessage = tr("upload_invalid_image")
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        .alert(tr("upload_file_error_title"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) { Button("common_ok", role: .cancel) {} } message: { Text(errorMessage ?? tr("common_unknown")) }
        .onAppear { applyPreferredSourceOnce() }
    }

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.12)).frame(width: 72, height: 72)
                Image(systemName: "square.and.arrow.up.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(.accentColor)
            }
            Text("upload_sources_headline").font(.headline)
            Text("upload_sources_desc")
                .font(.subheadline).foregroundColor(.secondary)
        }
    }

    private func sourceButton(title: String, subtitle: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13).fill(tint.opacity(0.14)).frame(width: 48, height: 48)
                    Image(systemName: icon).font(.system(size: 21, weight: .semibold)).foregroundColor(tint)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline).foregroundColor(.primary)
                    Text(subtitle).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundColor(.secondary)
            }
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 17))
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(Color.primary.opacity(0.07)))
        }
        .buttonStyle(UploadPressStyle())
    }

    private func complete(image selected: UIImage) {
        image = selected
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        dismiss()
    }

    private func tr(_ key: String) -> String { NSLocalizedString(key, comment: "") }

    private func applyPreferredSourceOnce() {
        guard !didApplyPreferredSource, let preferredSource else { return }
        didApplyPreferredSource = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if preferredSource == .camera, UIImagePickerController.isSourceTypeAvailable(.camera) { showCamera = true }
            else { showLibrary = true }
        }
    }
}

private struct UploadPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

private struct ImagePickerSheetStyle: ViewModifier {
    @Binding var isExpanded: Bool

    func body(content: Content) -> some View {
        ImagePickerDetentView(content: content, isExpanded: $isExpanded)
    }
}

private struct ImagePickerDetentView<Content: View>: View {
    let content: Content
    @Binding var isExpanded: Bool
    @State private var selectedDetent: PresentationDetent = .medium

    var body: some View {
        content
            .presentationDetents([.medium, .large], selection: $selectedDetent)
            .presentationDragIndicator(.visible)
            .onChange(of: selectedDetent) { value in
                withAnimation(PFAnimation.ease) { isExpanded = value == .large }
            }
    }
}

private struct CameraPicker: UIViewControllerRepresentable {
    let completion: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = NativeAspectCameraPickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.modalPresentationStyle = .fullScreen
        picker.view.backgroundColor = .black
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker; init(parent: CameraPicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.completion(image) }; parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}

/// 保留系统相机原生 4:3 取景比例，不放大裁切画面。
/// 取景区之外使用纯黑相机背景铺满安全区，避免全面屏设备出现白色留空。
private final class NativeAspectCameraPickerController: UIImagePickerController {
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard sourceType == .camera else { return }
        view.backgroundColor = .black
        view.superview?.backgroundColor = .black
        cameraViewTransform = .identity
    }
}

private struct PhotoLibraryPicker: UIViewControllerRepresentable {
    let completion: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared()); config.filter = .images; config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config); picker.delegate = context.coordinator; return picker
    }
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoLibraryPicker; init(parent: PhotoLibraryPicker) { self.parent = parent }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { parent.dismiss(); return }
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                DispatchQueue.main.async { if let image = object as? UIImage { self.parent.completion(image) }; self.parent.dismiss() }
            }
        }
    }
}
