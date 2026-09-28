import SwiftUI

/// 新版本弹窗（更新 + 彩蛋合一）
/// 用 fullScreenCover 承载，避免 .alert 点击后立即关闭无法等待异步接口的问题。
/// 领取彩蛋时显示加载动画，接口响应完毕后（成功）才关闭弹窗。
struct AppUpdateDialogView: View {
    @ObservedObject var appUpdater: AppUpdater
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // 半透明遮罩
            Color.black.opacity(0.45).ignoresSafeArea()

            VStack(spacing: 18) {
                // 顶部图标
                Image(systemName: appUpdater.easterEggAvailable ? "gift.fill" : "arrow.down.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(appUpdater.easterEggAvailable ? .yellow : PFColors.primary)

                // 标题
                Text(appUpdater.easterEggAvailable ? "easter_egg_dialog_title" : "update_available_title")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(PFColors.textPrimary)

                // 文案
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(format: NSLocalizedString("update_prompt", comment: ""), appUpdater.latestVersion))
                        .font(.system(size: 14))
                        .foregroundColor(PFColors.textSecondary)
                    if appUpdater.easterEggAvailable {
                        // "X 分钟前发布" 彩蛋提示，不透露 60 分钟时效
                        Text(appUpdater.easterEggPublishText)
                            .font(.system(size: 13))
                            .foregroundColor(.orange)
                        Text("easter_egg_dialog_msg")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

                // 按钮区
                VStack(spacing: 10) {
                    if appUpdater.easterEggAvailable {
                        // 领取彩蛋（带加载动画）
                        Button(action: { appUpdater.claimEasterEgg() }) {
                            HStack(spacing: 8) {
                                if appUpdater.isClaiming {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "gift.fill")
                                }
                                Text(appUpdater.isClaiming ? "loading" : "easter_egg_claim_btn")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(RoundedRectangle(cornerRadius: 14).fill(PFGradients.brand))
                        }
                        .disabled(appUpdater.isClaiming)
                    }

                    // 立即更新
                    Button(action: {
                        appUpdater.updateNow()
                        dismiss()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("download_now").font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(RoundedRectangle(cornerRadius: 14).fill(PFColors.primary))
                    }

                    // 忽略此版本
                    Button(action: {
                        appUpdater.ignoreVersion()
                        dismiss()
                    }) {
                        Text("ignore_update_btn")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(PFColors.danger)
                            .padding(.vertical, 6)
                    }

                    // 稍后
                    Button(action: {
                        appUpdater.dismissLater()
                        dismiss()
                    }) {
                        Text("later_btn")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(PFColors.textSecondary)
                            .padding(.vertical, 6)
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(PFColors.surface)
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
            )
            .padding(.horizontal, 36)
        }
        .interactiveDismissDisabled(appUpdater.isClaiming)
    }
}
