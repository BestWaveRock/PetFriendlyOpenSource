//
//  VoicePlayerView.swift
//  PetFriendly
//
//  宠物录音播放器 — 重写版：修复 PlayerDelegate 未被 retain 导致回访闪退
//

import SwiftUI
import AVFoundation

struct VoicePlayerView: View {
    let voiceURL: URL
    
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var progress: Double = 0
    @State private var duration: TimeInterval = 0
    @State private var currentTime: TimeInterval = 0
    @State private var playbackTimer: Timer?
    @State private var isLoading = true
    @State private var loadError = false
    
    var body: some View {
        GlassCard(padding: PFSpacing.md) {
            HStack(spacing: PFSpacing.md) {
                Button(action: {
                    if isPlaying { pausePlayback() } else { startPlayback() }
                }) {
                    ZStack {
                        Circle()
                            .fill(PFColors.primary)
                            .frame(width: 40, height: 40)
                        
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .offset(x: isPlaying ? 0 : 1)
                        }
                    }
                }
                .disabled(loadError)
                
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform")
                            .font(.system(size: 14))
                            .foregroundColor(isPlaying ? PFColors.primary : PFColors.textTertiary)
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(PFColors.surfaceSecondary)
                                    .frame(height: 4)
                                Capsule()
                                    .fill(PFGradients.brandHorizontal)
                                    .frame(width: geo.size.width * progress, height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                    
                    HStack {
                        Text(formattedTime(currentTime))
                            .font(PFFonts.caption2)
                            .foregroundColor(PFColors.textTertiary)
                        Spacer()
                        if loadError {
                            Text(LocalizedStringKey("voice_player_load_error"))
                                .font(PFFonts.caption2)
                                .foregroundColor(PFColors.danger)
                        } else {
                            Text(formattedTime(duration))
                                .font(PFFonts.caption2)
                                .foregroundColor(PFColors.textTertiary)
                        }
                    }
                }
            }
        }
        .onAppear { preparePlayer() }
        .onDisappear { cleanup() }
    }
    
    private func preparePlayer() {
        isLoading = true
        loadError = false
        
        Task {
            do {
                let data = try await URLSession.shared.data(from: voiceURL).0
                await MainActor.run {
                    do {
                        let session = AVAudioSession.sharedInstance()
                        try session.setCategory(.playback, mode: .default)
                        try session.setActive(true)
                        
                        audioPlayer = try AVAudioPlayer(data: data)
                        audioPlayer?.prepareToPlay()
                        duration = audioPlayer?.duration ?? 0
                        isLoading = false
                    } catch {
                        print("[VoicePlayer] Prepare error: \(error)")
                        loadError = true
                        isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    print("[VoicePlayer] Download error: \(error)")
                    loadError = true
                    isLoading = false
                }
            }
        }
    }
    
    private func startPlayback() {
        guard let player = audioPlayer else {
            preparePlayer()
            return
        }
        
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("[VoicePlayer] Session error: \(error)")
        }
        
        player.play()
        isPlaying = true
        
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            DispatchQueue.main.async {
                guard let p = self.audioPlayer, p.duration > 0 else { return }
                self.currentTime = p.currentTime
                self.progress = p.currentTime / p.duration
                if !p.isPlaying { self.stopPlayback() }
            }
        }
    }
    
    private func pausePlayback() {
        audioPlayer?.pause()
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    private func stopPlayback() {
        playbackTimer?.invalidate()
        playbackTimer = nil
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        isPlaying = false
        progress = 0
        currentTime = 0
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    
    private func cleanup() {
        playbackTimer?.invalidate()
        playbackTimer = nil
        audioPlayer?.stop()
        audioPlayer = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    
    private func formattedTime(_ time: TimeInterval) -> String {
        let t = max(time, 0)
        let minutes = Int(t) / 60
        let seconds = Int(t) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
