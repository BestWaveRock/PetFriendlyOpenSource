//
//  File.swift
//  PetFriendly
//
//  Created by PetFriendly Team on 2025/9/23.
//


import UIKit
import SwiftUI

/// 任何地方都能直接 showErrorAlert(_:)
//func showErrorAlert(_ error: Error) {
//    let msg = error.localizedDescription
//    guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
//          let root = scene.windows.first?.rootViewController else { return }
//    
//    let alert = UIAlertController(title: NSLocalizedString("alert_hint", comment: ""),
//                                message: msg,
//                                preferredStyle: .alert)
//    alert.addAction(.init(title: NSLocalizedString("map_got_it", comment: ""), style: .default))
//    root.present(alert, animated: true)
//}
func showErrorAlert(_ error: Error) {
    let msg = error.localizedDescription

    // 系统级 500 错误（http 5xx / 业务 5xx）统一走 AirPods 风格错误提示弹窗，不弹原生 alert
    if let biz = error as? BizError {
        switch biz {
        case .http(let code, _), .biz(let code, _):
            if code >= 500 {
                DispatchQueue.main.async {
                    UIState.shared.showToast(msg, style: .error, icon: "exclamationmark.triangle.fill")
                }
                return
            }
        }
    }
    
    // 保证后续 UI 操作在主线程
    DispatchQueue.main.async {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        
        let alert = UIAlertController(title: NSLocalizedString("alert_hint", comment: ""),
                                    message: msg,
                                    preferredStyle: .alert)
        if msg.contains("需要登录") {
            alert.addAction(.init(title: NSLocalizedString("map_goto_login", comment: ""), style: .default, handler: { _ in
                let loginVC = UIHostingController(rootView: LoginPage())
                loginVC.modalPresentationStyle = .pageSheet
                root.present(loginVC, animated: true)
            }))
        } else {
            alert.addAction(.init(title: NSLocalizedString("copy_log", comment: ""), style: .default, handler: { _ in
                UIPasteboard.general.string = msg
                // 可选：震动 + 浮层提示
                Haptics.play(.light)
                let toast = UIAlertController(title: nil, message: NSLocalizedString("copied_clipboard", comment: ""), preferredStyle: .actionSheet)
                root.present(toast, animated: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    toast.dismiss(animated: true)
                }
            }))
        }
        alert.addAction(.init(title: NSLocalizedString("map_got_it", comment: ""), style: .default))
        root.present(alert, animated: true)
    }
}

// MARK: - Success HUD
struct SuccessHUDView: View {
    let message: String
    @State private var showCheckmark = false
    
    var body: some View {
        ZStack {
            // Full screen clear background to block interactions optionally
            Color.clear.ignoresSafeArea()
            
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 4)
                        .frame(width: 70, height: 70)
                    
                    // Animated Checkmark
                    Path { path in
                        path.move(to: CGPoint(x: 20, y: 36))
                        path.addLine(to: CGPoint(x: 32, y: 48))
                        path.addLine(to: CGPoint(x: 52, y: 24))
                    }
                    .trim(from: 0, to: showCheckmark ? 1 : 0)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                    .frame(width: 70, height: 70)
                }
                
                Text(message)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 32)
            .background(Color.black.opacity(0.75))
            .background(.ultraThinMaterial)
            .environment(\.colorScheme, .dark)
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0).delay(0.1)) {
                    showCheckmark = true
                }
            }
        }
    }
}

/// Global helper to show the large success HUD
func showSuccessHUD(message: String = NSLocalizedString("alert_done", comment: "")) {
    DispatchQueue.main.async {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }),
              let root = window.rootViewController else { return }
        
        // Find top most presented controller
        var topController = root
        while let presented = topController.presentedViewController {
            topController = presented
        }
        
        let hudView = SuccessHUDView(message: message)
        let hostingController = UIHostingController(rootView: hudView)
        hostingController.view.backgroundColor = .clear
        hostingController.modalPresentationStyle = .overFullScreen
        hostingController.modalTransitionStyle = .crossDissolve
        
        topController.present(hostingController, animated: true) {
            Haptics.notify(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                hostingController.dismiss(animated: true)
            }
        }
    }
}

func showErrorHUD(message: String) {
    showErrorAlert(NSError(domain: "App", code: -1, userInfo: [NSLocalizedDescriptionKey: message]))
}

// MARK: - Circular Upload Progress
struct CircularUploadProgressView: View {
    var progress: Double
    var isFinished: Bool
    
    var body: some View {
        VStack(spacing: 20) {
                ZStack {
                    // 圆形背景
                    Circle()
                        .stroke(lineWidth: 8)
                        .opacity(0.3)
                        .foregroundColor(Color.white)
                        .frame(width: 80, height: 80)
                    
                    // 进度条
                    Circle()
                        .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                        .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                        .foregroundColor(PFColors.primary)
                        .rotationEffect(Angle(degrees: -90))
                        .animation(.linear, value: progress)
                        .frame(width: 80, height: 80)
                    
                    if isFinished {
                        Image(systemName: "checkmark")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.white)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                Text(isFinished ? NSLocalizedString("upload_done", comment: "") : NSLocalizedString("uploading", comment: ""))
                    .font(PFFonts.headline)
                    .foregroundColor(.white)
            }
            .padding(30)
            .background(Color(.systemGray6).opacity(0.2))
            .cornerRadius(20)
            .liquidGlass(cornerRadius: 20)
        .transition(.opacity)
    }
}
