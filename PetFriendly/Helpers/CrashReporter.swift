import UIKit
import Foundation
import MetricKit
import Darwin

struct CrashLog: Codable, Identifiable {
    let id: String
    let date: String
    let appVersion: String
    let osVersion: String
    let deviceModel: String
    let exceptionName: String?
    let exceptionReason: String?
    let callStack: [String]
    let threadInfo: String?

    var summary: String { exceptionReason ?? exceptionName ?? NSLocalizedString("crash_signal_unknown", comment: "") }
}

private var pendingSignalFD: Int32 = -1

/// Uses only async-signal-safe POSIX functions. Rich diagnostics are created on the next launch.
private func petFriendlySignalHandler(_ signalNumber: Int32) {
    guard pendingSignalFD >= 0 else { return }
    var marker: [UInt8] = [UInt8(ascii: "S"), UInt8(ascii: "I"), UInt8(ascii: "G"), UInt8(ascii: ":"), UInt8(ascii: "0"), UInt8(ascii: "\n")]
    switch signalNumber {
    case SIGABRT: marker[4] = UInt8(ascii: "A")
    case SIGTRAP: marker[4] = UInt8(ascii: "T")
    case SIGSEGV: marker[4] = UInt8(ascii: "S")
    case SIGBUS: marker[4] = UInt8(ascii: "B")
    case SIGILL: marker[4] = UInt8(ascii: "I")
    case SIGFPE: marker[4] = UInt8(ascii: "F")
    default: marker[4] = UInt8(ascii: "?")
    }
    _ = lseek(pendingSignalFD, 0, SEEK_SET)
    _ = ftruncate(pendingSignalFD, 0)
    marker.withUnsafeBytes { bytes in _ = Darwin.write(pendingSignalFD, bytes.baseAddress, bytes.count) }
    _ = fsync(pendingSignalFD)
    Darwin.signal(signalNumber, SIG_DFL)
    _ = kill(getpid(), signalNumber)
}

@objc final class CrashReporter: NSObject, MXMetricManagerSubscriber {
    static let shared = CrashReporter()
    private let fileManager = FileManager.default
    private lazy var logDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("CrashLogs", isDirectory: true)
    private lazy var pendingURL = fileManager.urls(for: .libraryDirectory, in: .userDomainMask)[0].appendingPathComponent("petfriendly.pending-signal")

    private override init() {}

    func install() {
        try? fileManager.createDirectory(at: logDir, withIntermediateDirectories: true)
        recoverPendingSignal()
        pendingSignalFD = Darwin.open(pendingURL.path, O_WRONLY | O_CREAT, S_IRUSR | S_IWUSR)
        for value in [SIGABRT, SIGTRAP, SIGSEGV, SIGBUS, SIGILL, SIGFPE] { Darwin.signal(value, petFriendlySignalHandler) }
        NSSetUncaughtExceptionHandler { exception in
            CrashReporter.shared.save(name: exception.name.rawValue, reason: exception.reason, stack: exception.callStackSymbols)
        }
        MXMetricManager.shared.add(self)
    }

    deinit {
        MXMetricManager.shared.remove(self)
        if pendingSignalFD >= 0 { Darwin.close(pendingSignalFD) }
    }

    private func recoverPendingSignal() {
        guard let marker = try? String(contentsOf: pendingURL, encoding: .utf8), !marker.isEmpty else { return }
        try? fileManager.removeItem(at: pendingURL)
        let code = marker.split(separator: ":").last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "?"
        let names = ["A": "SIGABRT", "T": "SIGTRAP", "S": "SIGSEGV", "B": "SIGBUS", "I": "SIGILL", "F": "SIGFPE"]
        save(name: names[code] ?? "Signal", reason: NSLocalizedString("crash_recovered_signal", comment: ""), stack: [])
    }

    static func record(error: Error, file: String = #file, line: Int = #line) {
        let value = error as NSError
        shared.save(name: "HandledException", reason: "\(value.domain)(\(value.code)): \(value.localizedDescription) [\(file):\(line)]", stack: Thread.callStackSymbols)
    }

    static func record(reason: String, file: String = #file, line: Int = #line) {
        shared.save(name: "HandledException", reason: "\(reason) [\(file):\(line)]", stack: Thread.callStackSymbols)
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            guard let diagnostics = payload.crashDiagnostics else { continue }
            for diagnostic in diagnostics {
                let json = String(data: diagnostic.callStackTree.jsonRepresentation(), encoding: .utf8) ?? ""
                save(name: "MetricKit MXCrashDiagnostic", reason: diagnostic.terminationReason, stack: [json])
            }
        }
    }

    private func save(name: String, reason: String?, stack: [String]) {
        let now = Date()
        let id = ISO8601DateFormatter().string(from: now).replacingOccurrences(of: ":", with: "-") + "-\(UUID().uuidString.prefix(8))"
        let log = CrashLog(id: id, date: ISO8601DateFormatter().string(from: now),
                           appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?",
                           osVersion: UIDevice.current.systemVersion, deviceModel: Self.deviceModelIdentifier(),
                           exceptionName: name, exceptionReason: reason, callStack: Array(stack.prefix(30)),
                           threadInfo: Thread.current.description)
        if let data = try? JSONEncoder().encode(log) { try? data.write(to: logDir.appendingPathComponent("crash_\(id).json"), options: .atomic) }
        cleanupOldLogs(keep: 20)
    }

    var allLogs: [CrashLog] {
        ((try? fileManager.contentsOfDirectory(at: logDir, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "json" }
            .compactMap { try? JSONDecoder().decode(CrashLog.self, from: Data(contentsOf: $0)) }
            .sorted { $0.date > $1.date }
    }
    var logCount: Int { allLogs.count }
    func clearAll() { for url in (try? fileManager.contentsOfDirectory(at: logDir, includingPropertiesForKeys: nil)) ?? [] where url.pathExtension == "json" { try? fileManager.removeItem(at: url) } }
    var exportText: String {
        allLogs.map { "--- \($0.date) ---\n\($0.exceptionName ?? "?"): \($0.exceptionReason ?? "?")\n\($0.callStack.joined(separator: "\n"))" }.joined(separator: "\n\n")
    }

    private func cleanupOldLogs(keep: Int) {
        let files = ((try? fileManager.contentsOfDirectory(at: logDir, includingPropertiesForKeys: [.creationDateKey])) ?? []).filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent > $1.lastPathComponent }
        for url in files.dropFirst(keep) { try? fileManager.removeItem(at: url) }
    }

    private static func deviceModelIdentifier() -> String {
        var info = utsname(); uname(&info)
        return withUnsafePointer(to: &info.machine) { $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) } }
    }
}
