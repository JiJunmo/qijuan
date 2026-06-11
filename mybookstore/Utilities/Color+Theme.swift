import SwiftUI

extension Color {
    struct Theme {
        /// 主品牌色：森林系护眼绿
        static let primary = Color(hex: "#4E8975")
        /// 应用底色：极其柔和的灰白
        static let background = Color(hex: "#F5F7F8")
        /// 卡片底色：纯白
        static let cardBackground = Color.white
        /// 主文本色：高对比度黑灰
        static let textPrimary = Color(hex: "#333333")
        /// 副文本色：辅助信息灰
        static let textSecondary = Color(hex: "#888888")
    }
}

// 辅助 Hex 颜色初始化扩展
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
