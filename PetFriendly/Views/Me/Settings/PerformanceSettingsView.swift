import SwiftUI

struct PerformanceSettingsView: View {
    @EnvironmentObject var uiState: UIState
    @ObservedObject var monitor = PerformanceMonitor.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var isExporting = false
    @State private var showExportSheet = false
    @State private var exportText: String?
    
    var body: some View {
        ZStack {
            PFColors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: PFSpacing.xl) {
                    // 开关部分
                    VStack(alignment: .leading, spacing: 0) {
                        Text(NSLocalizedString("perf_monitor", comment: ""))
                            .font(PFFonts.callout)
                            .foregroundColor(PFColors.textSecondary)
                            .padding(.horizontal, PFSpacing.xl)
                            .padding(.bottom, PFSpacing.sm)
                        
                        VStack(spacing: 0) {
                            Toggle(isOn: $uiState.showPerformanceFPS) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.orange.opacity(0.1))
                                            .frame(width: 28, height: 28)
                                        Image(systemName: "gauge.medium")
                                            .font(.system(size: 14))
                                            .foregroundColor(.orange)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(NSLocalizedString("settings_performance_fps_toggle", comment: ""))
                                            .font(PFFonts.body)
                                            .foregroundColor(PFColors.textPrimary)
                                        Text(NSLocalizedString("settings_performance_fps_desc", comment: ""))
                                            .font(.system(size: 11))
                                            .foregroundColor(PFColors.textTertiary)
                                    }
                                }
                            }
                            .padding(PFSpacing.lg)
                            .onChange(of: uiState.showPerformanceFPS) { newValue in
                                if newValue {
                                    monitor.start()
                                } else {
                                    monitor.stop()
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: PFRadius.md)
                                .fill(PFColors.surface)
                        )
                        .padding(.horizontal, PFSpacing.lg)
                        .pfCardShadow()
                    }
                    
                    // 统计部分
                    if uiState.showPerformanceFPS {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(NSLocalizedString("fps_stats", comment: ""))
                                .font(PFFonts.callout)
                                .foregroundColor(PFColors.textSecondary)
                                .padding(.horizontal, PFSpacing.xl)
                                .padding(.bottom, PFSpacing.sm)
                            
                            VStack(spacing: 16) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(NSLocalizedString("cur_fps", comment: ""))
                                            .font(PFFonts.caption)
                                            .foregroundColor(PFColors.textSecondary)
                                        Text("\(monitor.fps)")
                                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                                            .foregroundColor(monitor.fps >= 55 ? PFColors.success : PFColors.danger)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        Text(NSLocalizedString("avg_fps", comment: ""))
                                            .font(PFFonts.caption)
                                            .foregroundColor(PFColors.textSecondary)
                                        Text(String(format: "%.1f", monitor.getAverageFPS()))
                                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                                            .foregroundColor(PFColors.primary)
                                    }
                                }
                                
                                Divider()
                                
                                Button(action: exportLog) {
                                    HStack {
                                        Image(systemName: "doc.text.below.ecg.fill")
                                        Text(NSLocalizedString("settings_performance_export_log", comment: ""))
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(PFColors.primary)
                                    .cornerRadius(12)
                                }
                                
                                Button(action: { monitor.clearHistory() }) {
                                    Text(NSLocalizedString("settings_performance_reset", comment: ""))
                                        .font(PFFonts.caption)
                                        .foregroundColor(PFColors.textTertiary)
                                }
                            }
                            .padding(PFSpacing.lg)
                            .background(
                                RoundedRectangle(cornerRadius: PFRadius.md)
                                    .fill(PFColors.surface)
                            )
                            .padding(.horizontal, PFSpacing.lg)
                            .pfCardShadow()
                        }
                    }
                    
                    // 提示语
                    Text(NSLocalizedString("settings_performance_tips", comment: ""))
                        .font(PFFonts.caption)
                        .foregroundColor(PFColors.textTertiary)
                        .padding(.horizontal, 40)
                        .multilineTextAlignment(.center)
                    
                    Spacer()
                }
                .padding(.vertical, PFSpacing.lg)
            }
        }
        .navigationTitle("settings_performance_test")
        .trackScene("PerformanceSettings")
        .sheet(isPresented: $showExportSheet) {
            if let text = exportText {
                ShareSheet(items: [text])
            }
        }
    }
    
    private func exportLog() {
        Haptics.play()
        if let log = monitor.exportLog() {
            exportText = log
            showExportSheet = true
        } else {
            uiState.showToast("暂无统计数据")
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
