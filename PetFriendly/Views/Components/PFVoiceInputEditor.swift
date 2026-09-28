import SwiftUI
import AVFoundation
import UIKit

/// 原生多行文字输入 + 微信式按住语音输入。
/// 按下开始录音，上滑进入取消区，松手后取消或提交识别；也可直接键盘输入。
struct PFVoiceInputEditor: View {
    let placeholder: String
    @Binding var text: String
    var height: CGFloat = 140
    var maxLength: Int = 1000

    @FocusState private var isFocused: Bool
    @State private var isPressing = false
    @State private var isRecording = false
    @State private var isCancelling = false
    @State private var isTranscribing = false
    @State private var recorder: AVAudioRecorder?
    @State private var recordingStartedAt: Date?
    @State private var elapsedSeconds = 0
    @State private var timer: Timer?

    private let cancelThreshold: CGFloat = -64
    private let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("voice_note_\(UUID().uuidString).wav")

    var body: some View {
        VStack(spacing: 0) {
            editor
            Divider().padding(.horizontal, PFSpacing.md)
            actionBar
        }
        .background(PFColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: PFRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PFRadius.lg, style: .continuous)
                .stroke(isFocused ? PFColors.primary.opacity(0.55) : Color.primary.opacity(0.07), lineWidth: isFocused ? 1.5 : 1)
        }
        .shadow(color: isFocused ? PFColors.primary.opacity(0.08) : .clear, radius: 10, y: 4)
        .animation(PFAnimation.ease, value: isFocused)
        .animation(PFAnimation.ease, value: isRecording)
        .overlay { recordingOverlay }
        .onDisappear { cancelRecording() }
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(PFFonts.body)
                .foregroundColor(PFColors.textPrimary)
                .tint(PFColors.primary)
                .focused($isFocused)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(height: max(76, height - 52))
                .background(Color.clear)
                .onChange(of: text) { value in
                    if value.count > maxLength { text = String(value.prefix(maxLength)) }
                }

            if text.isEmpty && !isFocused {
                Text(LocalizedStringKey(placeholder))
                    .font(PFFonts.body)
                    .foregroundColor(PFColors.textTertiary)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 16)
                    .allowsHitTesting(false)
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: PFSpacing.sm) {
            Image(systemName: isTranscribing ? "waveform" : "text.alignleft")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isTranscribing ? PFColors.primary : PFColors.textTertiary)

            Text(isTranscribing ? "voice_input_transcribing" : "voice_input_text_or_hold")
                .font(PFFonts.caption)
                .foregroundColor(PFColors.textSecondary)

            Spacer()

            Text("\(text.count)/\(maxLength)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(PFColors.textTertiary)

            holdToTalkButton
        }
        .padding(.leading, PFSpacing.md)
        .padding(.trailing, 8)
        .frame(height: 52)
    }

    private var holdToTalkButton: some View {
        HStack(spacing: 6) {
            Image(systemName: "mic.fill")
            Text("voice_input_hold")
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundColor(isPressing ? .white : PFColors.primary)
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(isPressing ? PFColors.primary : PFColors.primary.opacity(0.11), in: Capsule())
        .scaleEffect(isPressing ? 0.97 : 1)
        .contentShape(Capsule())
        .accessibilityLabel(Text("voice_input_hold_accessibility"))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard !isTranscribing else { return }
                    if !isPressing {
                        isPressing = true
                        isFocused = false
                        dismissKeyboard()
                        requestAndBeginRecording()
                    }
                    if isRecording {
                        let cancelling = value.translation.height < cancelThreshold
                        if cancelling != isCancelling {
                            isCancelling = cancelling
                            Haptics.play()
                        }
                    }
                }
                .onEnded { _ in
                    guard isPressing else { return }
                    isPressing = false
                    if isRecording {
                        isCancelling ? cancelRecording() : stopAndTranscribe()
                    }
                    isCancelling = false
                }
        )
        .disabled(isTranscribing)
        .opacity(isTranscribing ? 0.55 : 1)
    }

    @ViewBuilder private var recordingOverlay: some View {
        if isRecording {
            VStack(spacing: PFSpacing.md) {
                ZStack {
                    Circle()
                        .fill(isCancelling ? PFColors.danger.opacity(0.15) : PFColors.primary.opacity(0.14))
                        .frame(width: 72, height: 72)
                        .scaleEffect(isRecording ? 1.08 : 0.9)
                    Image(systemName: isCancelling ? "xmark" : "waveform")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(isCancelling ? PFColors.danger : PFColors.primary)
                }
                Text(isCancelling ? "voice_input_release_cancel" : "voice_input_release_recognize")
                    .font(PFFonts.headline)
                    .foregroundColor(isCancelling ? PFColors.danger : PFColors.textPrimary)
                Text(isCancelling ? "voice_input_cancel_hint" : "voice_input_slide_cancel")
                    .font(PFFonts.caption)
                    .foregroundColor(PFColors.textSecondary)
                Text(durationText)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(PFColors.textTertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: PFRadius.lg, style: .continuous))
            .transition(.scale(scale: 0.96).combined(with: .opacity))
            .allowsHitTesting(false)
        }
    }

    private var durationText: String {
        String(format: "00:%02d", min(elapsedSeconds, 59))
    }

    private func requestAndBeginRecording() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                guard granted else {
                    isPressing = false
                    UIState.shared.showToast(NSLocalizedString("voice_permission_denied", comment: ""), style: .warning)
                    return
                }
                guard isPressing else { return }
                beginRecording()
            }
        }
    }

    private func beginRecording() {
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        do {
            try? FileManager.default.removeItem(at: fileURL)
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
            recorder.record()
            self.recorder = recorder
            recordingStartedAt = Date()
            elapsedSeconds = 0
            isRecording = true
            Haptics.play()
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                elapsedSeconds = Int(Date().timeIntervalSince(recordingStartedAt ?? Date()))
            }
        } catch {
            isPressing = false
            UIState.shared.showToast(NSLocalizedString("voice_start_error", comment: "").replacingOccurrences(of: "%@", with: error.localizedDescription), style: .error)
        }
    }

    private func stopAndTranscribe() {
        let url = stopRecorder(deleteFile: false)
        guard let url else { return }
        isTranscribing = true
        Task {
            defer { try? FileManager.default.removeItem(at: url) }
            do {
                let data = try Data(contentsOf: url)
                let result = try await NetworkManager.shared.speechToText(audioBase64: data.base64EncodedString(), format: "wav")
                let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
                await MainActor.run {
                    isTranscribing = false
                    guard !trimmed.isEmpty else { return }
                    text = text.isEmpty ? trimmed : text + "\n" + trimmed
                    Haptics.notify(.success)
                }
            } catch {
                await MainActor.run {
                    isTranscribing = false
                    UIState.shared.showToast(NSLocalizedString("voice_input_failed", comment: ""), style: .warning)
                }
            }
        }
    }

    private func cancelRecording() {
        _ = stopRecorder(deleteFile: true)
        isPressing = false
        isCancelling = false
    }

    @discardableResult
    private func stopRecorder(deleteFile: Bool) -> URL? {
        recorder?.stop()
        recorder = nil
        timer?.invalidate()
        timer = nil
        isRecording = false
        recordingStartedAt = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        let exists = FileManager.default.fileExists(atPath: fileURL.path)
        if deleteFile, exists { try? FileManager.default.removeItem(at: fileURL) }
        return exists && !deleteFile ? fileURL : nil
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// 服务表单统一的当前账号手机号快捷填充入口。
struct PFCurrentPhoneButton: View {
    @Binding var phone: String
    private var accountPhone: String { AccountStore.shared.petOwner?.phoneInformation ?? "" }

    var body: some View {
        if !accountPhone.isEmpty {
            Button {
                phone = accountPhone
                Haptics.play()
            } label: {
                Label(String(format: NSLocalizedString("booking_use_current_phone_format", comment: ""), accountPhone), systemImage: phone == accountPhone ? "checkmark.circle.fill" : "person.crop.circle")
                    .font(PFFonts.caption)
                    .foregroundColor(PFColors.primary)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(PFColors.primary.opacity(0.09), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}
