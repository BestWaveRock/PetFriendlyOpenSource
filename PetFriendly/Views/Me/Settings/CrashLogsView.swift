//
//  CrashLogsView.swift
//  PetFriendly
//
//  崩溃日志查看器 — 可复制全部日志或逐条分享
//

import SwiftUI

struct CrashLogsView: View {
    @State private var logs: [CrashLog] = []
    @State private var showShareSheet = false
    @State private var shareText = ""
    @State private var selectedLog: CrashLog?

    var body: some View {
        List {
            if logs.isEmpty {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.green)
                        Text("crash_log_empty")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("crash_log_empty_desc")
                            .font(.subheadline)
                            .foregroundColor(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            } else {
                Section {
                    Button(action: {
                        shareText = CrashReporter.shared.exportText
                        showShareSheet = true
                    }) {
                        Label("crash_log_export", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) {
                        CrashReporter.shared.clearAll()
                        logs = []
                    } label: {
                        Label("crash_log_clear", systemImage: "trash")
                    }
                }

                Section(String(format: NSLocalizedString("crash_log_section", comment: ""), logs.count)) {
                    ForEach(logs) { log in
                        Button(action: { selectedLog = log }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(log.date)
                                    .font(PFFonts.caption)
                                    .foregroundColor(.secondary)
                                Text(log.summary)
                                    .font(PFFonts.body)
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                                HStack {
                                    Text("v\(log.appVersion)")
                                        .font(PFFonts.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(PFColors.danger.opacity(0.1))
                                        .cornerRadius(4)
                                    Text("iOS \(log.osVersion)")
                                        .font(PFFonts.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .navigationTitle("crash_log_title")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { logs = CrashReporter.shared.allLogs }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [shareText])
        }
        .sheet(item: $selectedLog) { log in
            NavigationStack {
                CrashLogDetailView(log: log)
            }
        }
    }
}

// MARK: - 详情
struct CrashLogDetailView: View {
    let log: CrashLog
    @State private var showShareSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Group {
                    LabeledRow(label: NSLocalizedString("crash_log_time", comment: ""), value: log.date)
                    LabeledRow(label: NSLocalizedString("crash_log_version", comment: ""), value: "v\(log.appVersion)")
                    LabeledRow(label: NSLocalizedString("crash_log_system", comment: ""), value: "iOS \(log.osVersion)")
                    LabeledRow(label: NSLocalizedString("crash_log_device", comment: ""), value: log.deviceModel)
                }

                if let name = log.exceptionName {
                    SectionHeader(NSLocalizedString("crash_log_exception_type", comment: ""))
                    Text(name)
                        .font(.body.monospaced())
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }

                if let reason = log.exceptionReason {
                    SectionHeader(NSLocalizedString("crash_log_reason", comment: ""))
                    Text(reason)
                        .font(.body.monospaced())
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }

                SectionHeader(NSLocalizedString("crash_log_call_stack", comment: ""))
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(log.callStack.enumerated()), id: \.offset) { i, frame in
                        Text("\(i) \(frame)")
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                    }
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            .padding()
        }
        .navigationTitle("crash_log_detail_title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    let text = """
                    Crash Report
                    Date: \(log.date)
                    App: v\(log.appVersion) | iOS: \(log.osVersion)
                    Device: \(log.deviceModel)
                    Exception: \(log.exceptionName ?? "?")
                    Reason: \(log.exceptionReason ?? "?")
                    Stack:
                    \(log.callStack.joined(separator: "\n"))
                    """
                    UIPasteboard.general.string = text
                }) {
                    Image(systemName: "doc.on.doc")
                }
            }
        }
    }
}

private struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.headline)
            .padding(.top, 8)
    }
}

// MARK: - UIKit 分享
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
