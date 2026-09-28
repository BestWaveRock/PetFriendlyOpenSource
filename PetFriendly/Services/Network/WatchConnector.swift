import Foundation
import WatchConnectivity

/// iOS 端：登录后将 token 同步到 Watch
final class WatchConnector: NSObject, WCSessionDelegate {
    static let shared = WatchConnector()

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else {
            print("[WatchConnector] 此设备不支持 WatchConnectivity")
            return
        }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// 发送 token 和用户信息到 Watch
    func sendToken(_ token: String, nickname: String? = nil, avatar: String? = nil) {
        guard WCSession.default.isReachable else {
            // Watch 不在可达状态，通过 ApplicationContext 后台同步
            var context: [String: Any] = ["token": token]
            if let n = nickname { context["nickname"] = n }
            if let a = avatar { context["avatar"] = a }
            try? WCSession.default.updateApplicationContext(context)
            print("[WatchConnector] 通过 ApplicationContext 同步 token")
            return
        }

        // Watch 可达，直接发送消息
        var msg: [String: Any] = ["token": token]
        if let n = nickname { msg["nickname"] = n }
        if let a = avatar { msg["avatar"] = a }
        WCSession.default.sendMessage(msg, replyHandler: nil) { error in
            print("[WatchConnector] sendMessage 失败: \(error.localizedDescription)，尝试 ApplicationContext")
            var context: [String: Any] = ["token": token]
            if let n = nickname { context["nickname"] = n }
            if let a = avatar { context["avatar"] = a }
            try? WCSession.default.updateApplicationContext(context)
        }
    }

    /// 响应 Watch 的请求：返回当前 token
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        if message["requestToken"] as? Bool == true {
            let token = NetworkManager.shared.token ?? ""
            replyHandler(["token": token])
        } else {
            replyHandler([:])
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("[WatchConnector] 激活失败: \(error.localizedDescription)")
        } else {
            print("[WatchConnector] 激活成功: \(activationState.rawValue)")
            // 激活后如果有 token，立即同步
            if let token = NetworkManager.shared.token {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.sendToken(token)
                }
            }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        print("[WatchConnector] 会话变为非活跃")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        print("[WatchConnector] 会话已失效，重新激活")
        WCSession.default.activate()
    }
}
