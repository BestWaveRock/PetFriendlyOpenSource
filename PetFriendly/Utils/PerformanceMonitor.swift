import Foundation
import QuartzCore
import SwiftUI

/// 性能监控工具 (支持 120Hz ProMotion)
final class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()
    
    @Published var fps: Int = 0
    @Published var samples: [FPSSample] = []
    
    struct FPSSample: Codable {
        let timestamp: Date
        let fps: Int
        let scene: String
    }
    
    private var displayLink: CADisplayLink?
    private var lastTimestamp: TimeInterval = 0
    private var frameCount: Int = 0
    
    // 最大存储 30 分钟的数据 (每秒 1 个样本)
    private let maxBufferCount = 1600
    
    private init() {}
    
    func start() {
        guard displayLink == nil else { return }
        
        displayLink = CADisplayLink(target: self, selector: #selector(handleDisplayLink(_:)))
        
        let maxFPS = Float(UIScreen.main.maximumFramesPerSecond)
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: maxFPS, preferred: maxFPS)
        
        displayLink?.add(to: .main, forMode: .common)
    }
    
    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        lastTimestamp = 0
        frameCount = 0
    }
    
    func clearHistory() {
        samples.removeAll()
    }
    
    func getAverageFPS(lastMinutes: Int = 5) -> Double {
        let startTime = Date().addingTimeInterval(-Double(lastMinutes * 60))
        let filteredSamples = samples.filter { $0.timestamp >= startTime }
        guard !filteredSamples.isEmpty else { return 0 }
        let sum = filteredSamples.reduce(0) { $0 + $1.fps }
        return Double(sum) / Double(filteredSamples.count)
    }
    
    func exportLog() -> String? {
        guard !samples.isEmpty else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        var log = "=== PetFriendly FPS Monitor Log ===\n"
        log += "Export Time: \(formatter.string(from: Date()))\n"
        log += "Available Samples: \(samples.count)\n"
        log += "Average FPS (Overall): \(String(format: "%.2f", getAverageFPS()))\n"
        log += "-----------------------------------\n"
        
        for sample in samples {
            log += "[\(formatter.string(from: sample.timestamp))] \(sample.scene): \(sample.fps) FPS\n"
        }
        
        return log
    }
    
    @objc private func handleDisplayLink(_ link: CADisplayLink) {
        if lastTimestamp == 0 {
            lastTimestamp = link.timestamp
            return
        }
        
        frameCount += 1
        let delta = link.timestamp - lastTimestamp
        
        if delta >= 1.0 { // 每秒更新一次
            let currentFPS = Int(round(Double(frameCount) / delta))
            DispatchQueue.main.async {
                self.fps = currentFPS
                
                // 记录样本
                let scene = UIState.shared.currentSceneName
                let sample = FPSSample(timestamp: Date(), fps: currentFPS, scene: scene)
                self.samples.append(sample)
                
                // 维持缓冲区大小
                if self.samples.count > self.maxBufferCount {
                    self.samples.removeFirst()
                }
            }
            frameCount = 0
            lastTimestamp = link.timestamp
        }
    }
}

/// 性能悬浮窗
struct PerformanceOverlayView: View {
    @ObservedObject var monitor = PerformanceMonitor.shared
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(monitor.fps >= 110 ? Color.green : (monitor.fps >= 55 ? Color.yellow : Color.red))
                .frame(width: 8, height: 8)
                .shadow(color: .black.opacity(0.3), radius: 2)
            
            Text("\(monitor.fps) FPS")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.6))
                .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
        )
        .onTapGesture {
            // 点击可触发刷新，或者长按导出
        }
    }
}
