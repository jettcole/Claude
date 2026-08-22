import SwiftUI

extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255,
                  green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255,
                  alpha: 1)
    }
}

extension Color {
    /// A colour that resolves itself against the phone's appearance.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

/// Accounting paper, cash-register green and brass.
enum Palette {
    static let bg          = Color(light: 0xE9ECE6, dark: 0x101714)
    static let surface     = Color(light: 0xF7F8F4, dark: 0x182320)
    static let surfaceHigh = Color(light: 0xFDFDFB, dark: 0x1F2C28)
    static let sunk        = Color(light: 0xDFE4DC, dark: 0x0B110F)
    static let ink         = Color(light: 0x16211D, dark: 0xE8EDE8)
    static let ink2        = Color(light: 0x4A5851, dark: 0xA3B2AB)
    static let ink3        = Color(light: 0x7C8A83, dark: 0x74847D)
    static let rule        = Color(light: 0xC9D0C6, dark: 0x2C3A35)
    static let register    = Color(light: 0x1F6B4F, dark: 0x4FBF8E)
    static let registerSoft = Color(light: 0xD7E6DC, dark: 0x1B3A2E)
    static let brass       = Color(light: 0x8A6226, dark: 0xD0A45C)
    static let brassSoft   = Color(light: 0xF0E4C6, dark: 0x35291A)
    static let oxblood     = Color(light: 0x96382B, dark: 0xE0705C)
    static let oxbloodSoft = Color(light: 0xF5DCD7, dark: 0x3A1E19)
    static let greenbar    = Color(light: 0xE2E9DF, dark: 0x14201C)
}

extension Font {
    /// Every figure is monospaced with lining digits, the way a receipt is.
    static func register(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension View {
    /// The small uppercase label used above each group.
    func eyebrow() -> some View {
        self.font(.register(11, weight: .medium))
            .tracking(1.1)
            .textCase(.uppercase)
            .foregroundStyle(Palette.ink3)
    }
}
