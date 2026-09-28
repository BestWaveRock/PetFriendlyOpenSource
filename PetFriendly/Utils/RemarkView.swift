import SwiftUI

struct RemarkView: View {
    let remark: String?
    let fontStyle: Font?
    
    /// 多少字开始折叠，可按需调
    private let foldThreshold = 50
    /// max字数
    private let maxThreshold = 120
    
    /// 展开状态
    @State private var isExpanded = false
    
    /// 真正要显示的文本（空字符串兜底）
    private var displayText: String {
        let t = remark?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{200B}", with: "")
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .replacingOccurrences(of: "\u{2028}", with: "")   // 行分隔符
            .replacingOccurrences(of: "\u{2029}", with: "")   // 段分隔符
            ?? NSLocalizedString("no_desc", comment: "")
        return t
    }
    
    /// 是否需要折叠
    private var shouldFold: Bool {
        displayText.count > foldThreshold
    }
    
    var body: some View {
        VStack {
            VStack(alignment: .leading) {
                // 1. 前半段（始终显示）
                if shouldFold {
                    if isExpanded && displayText.count > maxThreshold {
                        // 展开并且字数大于100字时需要下拉框
                        GeometryReader { geo in
                            ScrollView(.vertical, showsIndicators: true) {
                                Text(displayText)
                                    .font(fontStyle ?? .title3)
                                    .frame(maxWidth: geo.size.width, alignment: .leading)
                                    .fixedSize(horizontal: false, vertical: true)  // 允许自动换行
                            }
                            .frame(minHeight: 60, maxHeight: 120)
                        }
                    } else {
                        // 直接展示
                        Text("\(isExpanded ? displayText : prefix)")
                            .font(fontStyle ?? .title3)
                            .frame(minHeight: 60, maxHeight: 120)
                    }
                    
                    Button(isExpanded ? NSLocalizedString("collapse", comment: "") : "展开") {
                        isExpanded.toggle()
                        Haptics.play()
                    }
                    .padding(.leading, 0)
                    .font(fontStyle ?? .title3)   // 让箭头文字同字号
                } else {
                    // 不够长，直接全文
                    Text(String(format: NSLocalizedString("remark_full", comment: ""), displayText))
                        .font(fontStyle ?? .title3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
    
    /// 前半段文本
    private var prefix: String {
        String(displayText.prefix(foldThreshold)) + "..."
    }
}
