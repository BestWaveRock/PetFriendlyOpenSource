import SwiftUI

/// 支付成功全屏页（类微信支付风格）
struct PaymentSuccessView: View {
    let amount: String
    let serviceName: String
    let orderId: String?
    let payTime: String
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // 背景色
            Color(UIColor.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // 成功动画图标
                ZStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.bottom, 20)
                
                Text("pay_success_title")
                    .font(.title2).bold()
                    .padding(.bottom, 6)
                
                Text("pay_success_desc")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 32)
                
                // 金额和订单信息卡片
                VStack(spacing: 0) {
                    // 金额
                    Text("¥\(amount)")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.vertical, 16)
                    
                    Divider().padding(.horizontal, 20)
                    
                    // 服务名称
                    HStack {
                        Text("pay_success_service")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                        Spacer()
                        Text(serviceName)
                            .font(.subheadline).bold()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    
                    Divider().padding(.horizontal, 20)
                    
                    // 订单号
                    if let oid = orderId {
                        HStack {
                            Text("pay_success_order_id")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                            Spacer()
                            Text("\(oid)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        
                        Divider().padding(.horizontal, 20)
                    }
                    
                    // 支付时间
                    HStack {
                        Text("pay_success_time")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                        Spacer()
                        Text(payTime)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                }
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(16)
                .padding(.horizontal, 24)
                
                Spacer()
                
                // 完成按钮
                Button(action: { dismiss() }) {
                    Text("pay_success_done")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .navigationBarHidden(true)
        .interactiveDismissDisabled()
    }
}

// MARK: - Helper: 格式化时间
extension PaymentSuccessView {
    static func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return df.string(from: date)
    }
    
    static func currentTime() -> String {
        return formatDate(Date())
    }
}
