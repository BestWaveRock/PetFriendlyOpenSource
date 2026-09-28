//
//  Haptics.swift
//  PetFriendly
//
//  Created by PetFriendly Team on 2025/8/21.
//
/*
 使用示例
 // 1. 默认轻触感
 Haptics.play()

 // 2. 重触感 + 半强度
 Haptics.play(.heavy, intensity: 0.5)

 // 3. 成功提示
 Haptics.notify(.success)
 */


import UIKit

/// 全局统一的触感反馈工具
enum Haptics {

    /// 触发一次触感
    /// - Parameters:
    ///   - style: 触感强度（`.light / .medium / .heavy / .soft / .rigid`）
    ///   - intensity: 0 ~ 1 之间的附加强度，默认 1（系统会自动忽略非法值）
    static func play(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light,
                     intensity: CGFloat = 1.0) {
        // 只在真机上执行；模拟器 / Mac 会无效果，但不会 crash
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred(intensity: intensity)
    }

    /// 如果需要通知类型（成功 / 警告 / 失败），可以再加一组：
    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}
