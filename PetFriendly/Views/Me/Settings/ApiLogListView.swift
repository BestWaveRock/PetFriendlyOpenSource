import SwiftUI

// MARK: - API 调试日志查看器
struct ApiLogListView: View {
    @State private var logs: [ApiLogEntry] = []
    @State private var selectedLog: ApiLogEntry?
    @State private var showDetail = false
    
    var body: some View {
        ZStack {
            PFColors.background.ignoresSafeArea()
            
            if logs.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "antenna.radiowaves.left.and.right.slash")
                        .font(.system(size: 50))
                        .foregroundColor(PFColors.textTertiary)
                    Text("api_log_empty")
                        .font(PFFonts.body)
                        .foregroundColor(PFColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            } else {
                List {
                    ForEach(logs) { entry in
                        Button(action: {
                            selectedLog = entry
                            showDetail = true
                        }) {
                            ApiLogRow(entry: entry)
                        }
                        .listRowBackground(PFColors.surface)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    logs = ApiLogger.shared.allLogs
                }
            }
        }
        .navigationTitle("API 请求日志")
        .navigationBarTitleDisplayMode(.inline)
        .pfToyBackground()
        .onAppear {
            logs = ApiLogger.shared.allLogs
        }
        .sheet(item: $selectedLog) { entry in
            ApiLogDetailView(entry: entry)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("btn_clear") {
                    ApiLogger.shared.clear()
                    logs = []
                }
                .foregroundColor(.red)
            }
        }
    }
}

struct ApiLogRow: View {
    let entry: ApiLogEntry
    
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 第一行：时间 + 接口标题
            HStack {
                Text(timeFormatter.string(from: entry.timestamp))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(PFColors.textSecondary)
                    .frame(width: 56, alignment: .leading)
                
                Text(apiTitle(from: entry.url))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(PFColors.textPrimary)
                    .lineLimit(1)
                
                Spacer()
                
                Text(entry.responseCode.map { "\($0)" } ?? "---")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(statusColor)
                
                Text(String(format: "%.0fms", entry.duration))
                    .font(.caption2)
                    .foregroundColor(PFColors.textSecondary)
                    .frame(width: 44, alignment: .trailing)
            }
            
            // 第二行：URL + Method
            HStack(spacing: 6) {
                Text(entry.method)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(methodColor)
                
                Text(entry.url)
                    .font(.system(size: 9))
                    .foregroundColor(PFColors.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            if let err = entry.error {
                Text("❌ \(err)")
                    .font(.caption2)
                    .foregroundColor(.red)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var methodColor: Color {
        switch entry.method {
        case "GET": return .green
        case "POST": return .blue
        case "PUT": return .orange
        case "DELETE": return .red
        default: return .gray
        }
    }
    
    private var statusColor: Color {
        guard let code = entry.responseCode else { return .gray }
        switch code {
        case 200...299: return .green
        case 400...499: return .orange
        case 500...599: return .red
        default: return .gray
        }
    }
}

struct ApiLogDetailView: View {
    let entry: ApiLogEntry
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // URL & Method
                    GroupBox(label: Label("api_log_request", systemImage: "arrow.up")) {
                        VStack(alignment: .leading, spacing: 8) {
                            labelRow(NSLocalizedString("api_log_time", comment: ""), entry.timestamp.formatted(date: .omitted, time: .standard))
                            labelRow("接口", apiTitle(from: entry.url))
                            labelRow("方法", entry.method)
                            labelRow("URL", entry.url)
                            labelRow("耗时", String(format: "%.0f ms", entry.duration))
                            if let code = entry.responseCode {
                                labelRow("状态码", "\(code)")
                            }
                        }
                        .font(.caption)
                    }
                    
                    // Headers
                    GroupBox(label: Label("api_log_headers", systemImage: "list.bullet")) {
                        Text(entry.headers.map { "\($0.key): \($0.value)" }.joined(separator: "\n"))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(PFColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Parameters
                    GroupBox(label: Label("api_log_params", systemImage: "doc.text")) {
                        Text(entry.parameters)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(PFColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Response
                    if let body = entry.responseBody {
                        GroupBox(label: Label("api_log_response", systemImage: "arrow.down")) {
                            ScrollView(.horizontal, showsIndicators: true) {
                                Text(body)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(PFColors.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 400)
                        }
                    }
                    
                    if let err = entry.error {
                        GroupBox(label: Label("api_log_error", systemImage: "exclamationmark.triangle")) {
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding()
            }
            .background(PFColors.background.ignoresSafeArea())
            .navigationTitle("请求详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button(action: copyAll) {
                            Image(systemName: "doc.on.doc")
                        }
                        Button("btn_close") { dismiss() }
                    }
                }
            }
        }
    }
    
    private func copyAll() {
        var text = "=== API Log ===\n"
        text += "Title: \(apiTitle(from: entry.url))\n"
        text += "App: v\(AppVersion.version) (\(AppVersion.gitHash))\n"
        text += "Time: \(entry.timestamp.formatted(date: .numeric, time: .standard))\n"
        text += "URL: \(entry.url)\n"
        text += "Method: \(entry.method)\n"
        text += "Duration: \(String(format: "%.0f", entry.duration))ms\n"
        if let code = entry.responseCode {
            text += "Status: \(code)\n"
        }
        text += "\n--- Headers ---\n"
        text += entry.headers.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
        text += "\n\n--- Parameters ---\n"
        text += entry.parameters
        if let body = entry.responseBody {
            text += "\n\n--- Response ---\n"
            text += body
        }
        if let err = entry.error {
            text += "\n\n--- Error ---\n"
            text += err
        }
        UIPasteboard.general.string = text
        UIState.shared.showToast("已复制")
    }
    
    private func labelRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .foregroundColor(PFColors.textSecondary)
                .frame(width: 50, alignment: .trailing)
            Text(value)
                .foregroundColor(PFColors.textPrimary)
                .lineLimit(nil)
        }
    }
}



