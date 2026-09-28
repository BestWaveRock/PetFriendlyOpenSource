//
//  VoiceRecorderView.swift
//  PetFriendly
//
//  宠物录音组件 — 重写版：移除 TimelineView，使用显式 Timer 管理
//  修复：停止录音时 TimelineView 访问已释放 recorder 导致的闪退
//

import SwiftUI
import AVFoundation
import Alamofire

// MARK: - 录音状态
enum VoiceRecorderState {
    case idle
    case recording
    case preview
    case uploading
}

// MARK: - 视图模型
@MainActor
final class VoiceRecorderViewModel: ObservableObject {
    @Published var state: VoiceRecorderState = .idle
    @Published var elapsedTime: TimeInterval = 0
    @Published var isPlaying = false
    @Published var playbackProgress: Double = 0
    @Published var showPermissionAlert = false
    @Published var showError = false
    @Published var errorMessage: String?

    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    /// View 层只读访问（用于播放进度显示）
    var currentPlayer: AVAudioPlayer? { audioPlayer }
    var recordingURL: URL?
    private var playerDelegate: AudioPlayerDelegate?
    private var recordingTimer: Timer?
    private var playbackTimer: Timer?

    let maxDuration: TimeInterval = 15

    // MARK: - 录音
    func requestPermissionAndStart() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                guard let self else { return }
                if granted {
                    self.startRecording()
                } else {
                    self.showPermissionAlert = true
                }
            }
        }
    }

    private func startRecording() {
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "pet_voice_\(UUID().uuidString).m4a"
        let fileURL = tempDir.appendingPathComponent(fileName)
        recordingURL = fileURL

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)

            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()

            state = .recording
            elapsedTime = 0
            startRecordingTimer()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func stopRecording() {
        // 防重入：已经在非录制状态则直接返回，避免 timer 回调与手动停止重复触发
        guard state == .recording || audioRecorder != nil else { return }
        // 1. 先停 timer（避免 timer 访问已释放的 recorder）
        stopRecordingTimer()
        // 2. 在 stop() 之前记录当前时长。
        //    不要在任何 stop() 之后访问 currentTime——iOS 上 AVAudioRecorder.stop()
        //    后立即读取 currentTime 存在边缘崩溃风险。
        let rec = audioRecorder
        let finalTime = (rec?.isRecording == true) ? (rec?.currentTime ?? elapsedTime) : elapsedTime
        // 3. 安全停止录音：检查 isRecording 防止音频会话异常时 crash
        if rec?.isRecording == true {
            rec?.stop()
        }
        // 4. 释放 recorder
        audioRecorder = nil
        // 5. 停用音频会话
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        // 6. 最后改状态
        elapsedTime = finalTime
        state = .preview
    }

    func resetRecording() {
        stopPlayback()
        stopRecordingTimer()
        stopPlaybackTimer()
        audioPlayer = nil
        audioRecorder = nil
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordingURL = nil
        elapsedTime = 0
        playbackProgress = 0
        state = .idle
    }

    // MARK: - 播放
    func startPlayback() {
        guard let url = recordingURL else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            audioPlayer = try AVAudioPlayer(contentsOf: url)
            playerDelegate = AudioPlayerDelegate { [weak self] in
                Task { @MainActor in
                    self?.stopPlayback()
                }
            }
            audioPlayer?.delegate = playerDelegate
            audioPlayer?.play()
            isPlaying = true
            playbackProgress = 0
            startPlaybackTimer()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func stopPlayback() {
        stopPlaybackTimer()
        audioPlayer?.stop()
        audioPlayer = nil
        playerDelegate = nil
        isPlaying = false
        playbackProgress = 0
    }

    // MARK: - 定时器

    private func startRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.state == .recording, let rec = self.audioRecorder else { return }
                self.elapsedTime = rec.currentTime
                if rec.currentTime >= self.maxDuration {
                    self.stopRecording()
                }
            }
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    private func startPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.state == .preview, self.isPlaying,
                      let player = self.audioPlayer, player.duration > 0 else { return }
                self.playbackProgress = player.currentTime / player.duration
            }
        }
    }

    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    // MARK: - 清理
    func cleanup() {
        stopRecordingTimer()
        stopPlaybackTimer()
        audioPlayer?.stop()
        audioPlayer = nil
        audioRecorder?.stop()
        audioRecorder = nil
        playerDelegate = nil
    }
}

// MARK: - 播放器代理
private final class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    let onFinish: () -> Void
    init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) { onFinish() }
}

// MARK: - 视图
struct VoiceRecorderView: View {
    let petId: String
    let onSaved: (String) -> Void
    @Environment(\.dismiss) var dismiss
    @StateObject private var vm = VoiceRecorderViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                PFColors.background.ignoresSafeArea()

                VStack(spacing: PFSpacing.xxxl) {
                    Spacer()

                    // 录音图标
                    ZStack {
                        Circle()
                            .fill(vm.state == .recording ? PFColors.danger.opacity(0.15) : PFColors.primary.opacity(0.1))
                            .frame(width: 180, height: 180)
                        Circle()
                            .stroke(vm.state == .recording ? PFColors.danger.opacity(0.3) : PFColors.primary.opacity(0.2), lineWidth: 2)
                            .frame(width: 160, height: 160)
                            .scaleEffect(vm.state == .recording ? 1.1 : 1.0)
                            .animation(vm.state == .recording ? Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default, value: vm.state)
                        Image(systemName: vm.state == .recording ? "waveform" : (vm.state == .preview ? "waveform.badge.mic" : "mic.fill"))
                            .font(.system(size: 60))
                            .foregroundColor(vm.state == .recording ? PFColors.danger : PFColors.primary)
                    }

                    // 时间显示（安全：纯 @Published 值，不访问 recorder）
                    Text(formattedTime(vm.elapsedTime))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(vm.state == .recording ? PFColors.danger : PFColors.textPrimary)
                        .monospacedDigit()

                    // 状态提示
                    Text(stateHint)
                        .font(PFFonts.body)
                        .foregroundColor(PFColors.textSecondary)

                    Spacer()

                    // 主按钮
                    Button(action: {
                        switch vm.state {
                        case .idle:
                            vm.requestPermissionAndStart()
                        case .recording:
                            vm.stopRecording()
                        case .preview:
                            vm.resetRecording()
                        case .uploading:
                            break
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(vm.state == .recording ? PFColors.danger : PFColors.primary)
                                .frame(width: 72, height: 72)
                                .shadow(color: (vm.state == .recording ? PFColors.danger : PFColors.primary).opacity(0.4), radius: 12, x: 0, y: 6)
                            if vm.state == .recording {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(.white)
                                    .frame(width: 24, height: 24)
                            } else if vm.state == .preview {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.title2.bold())
                                    .foregroundColor(.white)
                            } else {
                                Image(systemName: "mic.fill")
                                    .font(.title.bold())
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .disabled(vm.state == .uploading)

                    // 预览操作
                    if vm.state == .preview {
                        HStack(spacing: PFSpacing.xxl) {
                            Button(action: {
                                vm.isPlaying ? vm.stopPlayback() : vm.startPlayback()
                            }) {
                                VStack(spacing: PFSpacing.sm) {
                                    ZStack {
                                        Circle()
                                            .fill(PFColors.primary.opacity(0.1))
                                            .frame(width: 56, height: 56)
                                        Image(systemName: vm.isPlaying ? "stop.fill" : "play.fill")
                                            .font(.title2)
                                            .foregroundColor(PFColors.primary)
                                    }
                                    Text(LocalizedStringKey(vm.isPlaying ? "voice_recorder_stop" : "voice_recorder_preview"))
                                        .font(PFFonts.caption)
                                        .foregroundColor(PFColors.textSecondary)
                                }
                            }

                            Button(action: { uploadRecording() }) {
                                VStack(spacing: PFSpacing.sm) {
                                    ZStack {
                                        Circle()
                                            .fill(PFGradients.brand)
                                            .frame(width: 56, height: 56)
                                            .shadow(color: PFColors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                                        Image(systemName: "checkmark")
                                            .font(.title2.bold())
                                            .foregroundColor(.white)
                                    }
                                    Text(LocalizedStringKey("voice_recorder_confirm"))
                                        .font(PFFonts.caption)
                                        .foregroundColor(PFColors.textSecondary)
                                }
                            }
                        }
                        .padding(.top, PFSpacing.lg)
                    }

                    // 播放进度
                    if vm.state == .preview && vm.isPlaying {
                        VStack(spacing: PFSpacing.xs) {
                            ProgressView(value: min(max(vm.playbackProgress, 0), 1))
                                .tint(PFColors.primary)
                            HStack {
                                Text(formattedTime(vm.playbackProgress * (vm.currentPlayer?.duration ?? 0)))
                                    .font(PFFonts.caption2)
                                    .foregroundColor(PFColors.textTertiary)
                                Spacer()
                                Text(formattedTime(vm.currentPlayer?.duration ?? 0))
                                    .font(PFFonts.caption2)
                                    .foregroundColor(PFColors.textTertiary)
                            }
                        }
                        .padding(.horizontal, PFSpacing.xxl)
                    }

                    Spacer()
                }
                .padding(.horizontal, PFSpacing.xl)

                // 上传覆盖层
                if vm.state == .uploading {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        VStack(spacing: PFSpacing.lg) {
                            PFPetLoadingView(size: 48)
                            Text(LocalizedStringKey("voice_recorder_uploading"))
                                .font(PFFonts.body)
                                .foregroundColor(.white)
                        }
                        .padding(PFSpacing.xxl)
                        .background(.ultraThinMaterial)
                        .cornerRadius(PFRadius.lg)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("voice_recorder_title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(LocalizedStringKey("alert_cancel")) {
                        vm.cleanup()
                        dismiss()
                    }
                    .disabled(vm.state == .uploading)
                }
            }
            .alert(LocalizedStringKey("common_error"), isPresented: $vm.showError) {
                Button(LocalizedStringKey("common_confirm")) { }
            } message: {
                Text(vm.errorMessage ?? "")
            }
            .alert(LocalizedStringKey("voice_recorder_mic_permission_title"), isPresented: $vm.showPermissionAlert) {
                Button(LocalizedStringKey("common_settings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button(LocalizedStringKey("alert_cancel"), role: .cancel) { }
            } message: {
                Text(LocalizedStringKey("voice_recorder_mic_permission_msg"))
            }
            .interactiveDismissDisabled(vm.state == .recording || vm.state == .uploading)
            .onDisappear {
                vm.cleanup()
            }
        }
    }

    // MARK: - 辅助

    private var stateHint: String {
        switch vm.state {
        case .idle: return NSLocalizedString("voice_recorder_hint_idle", comment: "")
        case .recording: return NSLocalizedString("voice_recorder_hint_recording", comment: "")
        case .preview: return NSLocalizedString("voice_recorder_hint_preview", comment: "")
        case .uploading: return NSLocalizedString("voice_recorder_hint_uploading", comment: "")
        }
    }

    private func formattedTime(_ time: TimeInterval) -> String {
        let t = max(time, 0)
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - 上传

    private func uploadRecording() {
        guard let url = vm.recordingURL, let audioData = try? Data(contentsOf: url) else {
            vm.errorMessage = NSLocalizedString("voice_recorder_error_file", comment: "")
            vm.showError = true
            return
        }

        vm.state = .uploading

        Task {
            do {
                let resp: UploadResponse = try await NetworkManager.shared.upload(
                    fileData: audioData,
                    mimeType: "audio/mp4",
                    onProgress: nil,
                    suppressGlobalUI: true
                )

                guard let urlString = resp.data else {
                    await MainActor.run {
                        vm.errorMessage = NSLocalizedString("voice_recorder_error_upload", comment: "")
                        vm.showError = true
                        vm.state = .preview
                    }
                    return
                }

                let params: [String: Any] = ["petId": petId, "voiceUrl": urlString]
                struct Empty: Decodable {}
                _ = try await NetworkManager.shared.request(
                    "/petFriendly/client/updatePet",
                    method: .post,
                    parameters: params,
                    encoding: JSONEncoding.default,
                    needToken: true
                ) as Empty?

                await MainActor.run {
                    onSaved(urlString)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    vm.errorMessage = error.localizedDescription
                    vm.showError = true
                    vm.state = .preview
                }
            }
        }
    }
}
