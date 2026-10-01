import SwiftUI

// MARK: - 配色体系（精确复刻网页 CSS HSL 变量）
// 莫兰迪·婴儿蓝（默认主题）
// 对应 src/index.css :root 变量

extension Color {
    /// HSL → Color（H: 0-360, S/L: 0-100）
    init(h: Double, s: Double, l: Double, opacity: Double = 1.0) {
        let s = s / 100.0
        let l = l / 100.0
        let c = (1 - abs(2 * l - 1)) * s
        let x = c * (1 - abs((h / 60.0).truncatingRemainder(dividingBy: 2) - 1))
        let m = l - c / 2
        let rgb: (Double, Double, Double)
        switch h {
        case 0..<60:   rgb = (c, x, 0)
        case 60..<120: rgb = (x, c, 0)
        case 120..<180: rgb = (0, c, x)
        case 180..<240: rgb = (0, x, c)
        case 240..<300: rgb = (x, 0, c)
        default:        rgb = (c, 0, x)
        }
        self.init(
            .sRGB,
            red: rgb.0 + m,
            green: rgb.1 + m,
            blue: rgb.2 + m,
            opacity: opacity
        )
    }

    /// "#rrggbb" / "#rgb" → Color
    init(hex: String) {
        var m = hex.replacingOccurrences(of: "#", with: "")
        if m.count == 3 { m = m.map { "\($0)\($0)" }.joined() }
        var n: UInt64 = 0
        Scanner(string: m).scanHexInt64(&n)
        self.init(
            .sRGB,
            red: Double((n >> 16) & 255) / 255.0,
            green: Double((n >> 8) & 255) / 255.0,
            blue: Double(n & 255) / 255.0
        )
    }
}

// MARK: - 全站界面主题（复刻 useTheme.tsx：blue 婴儿蓝 / gray 雾灰 / green 墨绿 / pink 雾粉）
// 登录后跟随账号（settings.getSiteTheme / updateSiteTheme），游客存本机。
final class SiteThemeManager: ObservableObject {
    static let shared = SiteThemeManager()

    struct ThemeDef {
        let key: String
        let label: String
        let swatch: Color
    }
    static let themes: [ThemeDef] = [
        .init(key: "blue",  label: "婴儿蓝", swatch: Color(h: 205, s: 28, l: 56)),
        .init(key: "gray",  label: "雾灰",   swatch: Color(h: 240, s: 5,  l: 22)),
        .init(key: "green", label: "墨绿",   swatch: Color(h: 150, s: 16, l: 28)),
        .init(key: "pink",  label: "雾粉",   swatch: Color(h: 345, s: 18, l: 52)),
    ]

    @Published private(set) var theme: String

    private init() {
        let v = UserDefaults.standard.string(forKey: "msl-site-theme") ?? "blue"
        theme = Self.themes.contains { $0.key == v } ? v : "blue"
    }

    /// 本地切换 + （登录后）同步到账号
    func apply(_ key: String) {
        guard Self.themes.contains(where: { $0.key == key }) else { return }
        theme = key
        UserDefaults.standard.set(key, forKey: "msl-site-theme")
        Task { @MainActor in
            if AuthManager.shared.isAuthenticated {
                _ = try? await MashanglingAPI.shared.settings.updateSiteTheme(key)
            }
        }
    }

    /// 登录后从账号拉取主题
    @MainActor
    func syncFromServer() async {
        guard AuthManager.shared.isAuthenticated else { return }
        if let r = try? await MashanglingAPI.shared.settings.getSiteTheme(),
           let t = r.siteTheme, Self.themes.contains(where: { $0.key == t }), t != theme {
            theme = t
            UserDefaults.standard.set(t, forKey: "msl-site-theme")
        }
    }
}

struct AppTheme {
    // MARK: 浅色模式（莫兰迪·婴儿蓝）
    struct Light {
        static let background      = Color(h: 205, s: 26, l: 96)
        static let foreground      = Color(h: 210, s: 15, l: 27)
        static let card            = Color(h: 0,   s: 0,  l: 100)
        static let cardForeground  = Color(h: 210, s: 15, l: 27)
        static let primary         = Color(h: 205, s: 28, l: 56)
        static let primaryForeground = Color(h: 205, s: 30, l: 97)
        static let secondary       = Color(h: 205, s: 16, l: 92)
        static let secondaryForeground = Color(h: 210, s: 15, l: 31)
        static let muted           = Color(h: 205, s: 16, l: 92)
        static let mutedForeground = Color(h: 210, s: 6,  l: 47)
        static let accent          = Color(h: 205, s: 16, l: 91)
        static let accentForeground = Color(h: 210, s: 18, l: 29)
        static let destructive     = Color(h: 5,   s: 24, l: 48)
        static let destructiveFg   = Color(h: 40,  s: 20, l: 97)
        static let border          = Color(h: 205, s: 12, l: 86)
        static let input           = Color(h: 205, s: 10, l: 82)
        static let ring            = Color(h: 205, s: 22, l: 44)
        // 品牌扩展色
        static let brand50  = Color(h: 205, s: 34, l: 95)
        static let brand100 = Color(h: 205, s: 30, l: 92)
        static let brand200 = Color(h: 205, s: 26, l: 86)
        static let brand300 = Color(h: 205, s: 22, l: 77)
        static let brand400 = Color(h: 205, s: 22, l: 63)
        static let brand500 = Color(h: 205, s: 25, l: 53)
        static let brand600 = Color(h: 205, s: 30, l: 45)
        static let brand700 = Color(h: 205, s: 34, l: 36)
        static let brand900 = Color(h: 205, s: 38, l: 25)
        // 语义色
        static let emeraldBg   = Color(h: 140, s: 11, l: 92, opacity: 0.8)
        static let emeraldBrd  = Color(h: 140, s: 10, l: 84)
        static let emeraldFg   = Color(h: 140, s: 13, l: 46)
        static let emeraldIcon = Color(h: 140, s: 13, l: 46)
        static let emeraldLight = Color(h: 140, s: 11, l: 92)
        static let greenBg     = Color(h: 130, s: 10, l: 92, opacity: 0.6)
        static let greenFg     = Color(h: 130, s: 13, l: 47)
        static let amberBg     = Color(h: 40,  s: 13, l: 92)
        static let amberBrd    = Color(h: 40,  s: 13, l: 86)
        static let amberFg     = Color(h: 40,  s: 15, l: 64)
        static let amberIcon   = Color(h: 40,  s: 15, l: 45)
        static let skyBg       = Color(h: 195, s: 16, l: 92)
        static let skyBrd      = Color(h: 195, s: 15, l: 84)
        static let redFg       = Color(h: 0,   s: 72, l: 51)
    }

    // MARK: 深色模式（对应网页 .dark 变量）
    struct Dark {
        static let background      = Color(h: 240, s: 10,  l: 3.9)
        static let foreground      = Color(h: 0,   s: 0,   l: 98)
        static let card            = Color(h: 240, s: 10,  l: 3.9)
        static let cardForeground  = Color(h: 0,   s: 0,   l: 98)
        static let primary         = Color(h: 0,   s: 0,   l: 98)
        static let primaryForeground = Color(h: 240, s: 5.9, l: 10)
        static let secondary       = Color(h: 240, s: 3.7, l: 15.9)
        static let secondaryForeground = Color(h: 0, s: 0, l: 98)
        static let muted           = Color(h: 240, s: 3.7, l: 15.9)
        static let mutedForeground = Color(h: 240, s: 5,   l: 64.9)
        static let accent          = Color(h: 240, s: 3.7, l: 15.9)
        static let accentForeground = Color(h: 0,  s: 0,   l: 98)
        static let destructive     = Color(h: 0,   s: 62.8, l: 30.6)
        static let destructiveFg   = Color(h: 0,   s: 0,   l: 98)
        static let border          = Color(h: 240, s: 3.7, l: 15.9)
        static let input           = Color(h: 240, s: 3.7, l: 15.9)
        static let ring            = Color(h: 240, s: 4.9, l: 83.9)
        // 深色下语义色微调
        static let emeraldBg   = Color(h: 140, s: 10, l: 21, opacity: 0.4)
        static let emeraldBrd  = Color(h: 140, s: 9,  l: 21)
        static let emeraldFg   = Color(h: 140, s: 10, l: 59)
        static let emeraldIcon = Color(h: 140, s: 10, l: 59)
        static let emeraldLight = Color(h: 140, s: 10, l: 21)
        static let greenBg     = Color(h: 130, s: 20, l: 21, opacity: 0.3)
        static let greenFg     = Color(h: 130, s: 10, l: 59)
        static let amberBg     = Color(h: 40,  s: 15, l: 21)
        static let amberBrd    = Color(h: 40,  s: 13, l: 21)
        static let amberFg     = Color(h: 40,  s: 15, l: 64)
        static let amberIcon   = Color(h: 40,  s: 15, l: 64)
        static let skyBg       = Color(h: 195, s: 16, l: 21)
        static let skyBrd      = Color(h: 195, s: 15, l: 21)
        static let redFg       = Color(h: 0,   s: 62, l: 60)
        // 深色下品牌色（对应浅色 brand50/100/400/600 的深色映射）
        static let brand900    = Color(h: 240, s: 4,  l: 16)
        static let brand700    = Color(h: 240, s: 4,  l: 28)
        static let brand400    = Color(h: 240, s: 3,  l: 58)
        static let brand300    = Color(h: 240, s: 3,  l: 70)
    }

    // MARK: 浅色主题调色板（对应 index.css 的 [data-theme] 变量）
    struct Palette {
        let background, foreground, card, cardForeground: Color
        let primary, primaryForeground: Color
        let secondary, secondaryForeground, muted, mutedForeground: Color
        let accent, accentForeground, border, input, ring: Color
        let brand50, brand100, brand400, brand500, brand600: Color
    }

    static func palette(_ theme: String) -> Palette {
        switch theme {
        case "gray":
            return Palette(
                background: Color(h: 240, s: 4, l: 96), foreground: Color(h: 240, s: 5, l: 16),
                card: Color(h: 0, s: 0, l: 100), cardForeground: Color(h: 240, s: 5, l: 16),
                primary: Color(h: 240, s: 5, l: 22), primaryForeground: Color(h: 0, s: 0, l: 98),
                secondary: Color(h: 240, s: 5, l: 92), secondaryForeground: Color(h: 240, s: 5, l: 24),
                muted: Color(h: 240, s: 5, l: 92), mutedForeground: Color(h: 240, s: 3, l: 44),
                accent: Color(h: 240, s: 5, l: 91), accentForeground: Color(h: 240, s: 5, l: 20),
                border: Color(h: 240, s: 4, l: 87), input: Color(h: 240, s: 4, l: 83), ring: Color(h: 240, s: 5, l: 28),
                brand50: Color(h: 240, s: 5, l: 95), brand100: Color(h: 240, s: 5, l: 92),
                brand400: Color(h: 240, s: 3, l: 58), brand500: Color(h: 240, s: 3, l: 46), brand600: Color(h: 240, s: 4, l: 34)
            )
        case "green":
            return Palette(
                background: Color(h: 140, s: 9, l: 95), foreground: Color(h: 150, s: 12, l: 18),
                card: Color(h: 0, s: 0, l: 100), cardForeground: Color(h: 150, s: 12, l: 18),
                primary: Color(h: 150, s: 16, l: 28), primaryForeground: Color(h: 140, s: 15, l: 96),
                secondary: Color(h: 135, s: 8, l: 91), secondaryForeground: Color(h: 150, s: 10, l: 24),
                muted: Color(h: 135, s: 8, l: 91), mutedForeground: Color(h: 120, s: 4, l: 42),
                accent: Color(h: 135, s: 9, l: 89), accentForeground: Color(h: 150, s: 10, l: 22),
                border: Color(h: 130, s: 5, l: 84), input: Color(h: 130, s: 4, l: 80), ring: Color(h: 150, s: 14, l: 30),
                brand50: Color(h: 140, s: 10, l: 94), brand100: Color(h: 140, s: 10, l: 90),
                brand400: Color(h: 145, s: 8, l: 54), brand500: Color(h: 150, s: 10, l: 43), brand600: Color(h: 150, s: 13, l: 34)
            )
        case "pink":
            return Palette(
                background: Color(h: 345, s: 16, l: 96), foreground: Color(h: 345, s: 10, l: 26),
                card: Color(h: 0, s: 0, l: 100), cardForeground: Color(h: 345, s: 10, l: 26),
                primary: Color(h: 345, s: 18, l: 52), primaryForeground: Color(h: 345, s: 20, l: 97),
                secondary: Color(h: 340, s: 12, l: 92), secondaryForeground: Color(h: 345, s: 10, l: 30),
                muted: Color(h: 340, s: 12, l: 92), mutedForeground: Color(h: 340, s: 5, l: 46),
                accent: Color(h: 340, s: 12, l: 91), accentForeground: Color(h: 345, s: 12, l: 28),
                border: Color(h: 340, s: 8, l: 87), input: Color(h: 340, s: 7, l: 83), ring: Color(h: 345, s: 14, l: 40),
                brand50: Color(h: 345, s: 24, l: 95), brand100: Color(h: 345, s: 22, l: 92),
                brand400: Color(h: 345, s: 14, l: 63), brand500: Color(h: 345, s: 16, l: 53), brand600: Color(h: 345, s: 20, l: 45)
            )
        default: // blue 婴儿蓝（默认）
            return Palette(
                background: Light.background, foreground: Light.foreground,
                card: Light.card, cardForeground: Light.cardForeground,
                primary: Light.primary, primaryForeground: Light.primaryForeground,
                secondary: Light.secondary, secondaryForeground: Light.secondaryForeground,
                muted: Light.muted, mutedForeground: Light.mutedForeground,
                accent: Light.accent, accentForeground: Light.accentForeground,
                border: Light.border, input: Light.input, ring: Light.ring,
                brand50: Light.brand50, brand100: Light.brand100,
                brand400: Light.brand400, brand500: Light.brand500, brand600: Light.brand600
            )
        }
    }
}

// MARK: - 语义化颜色提供者（自动适配深色模式）
extension Color {
    static var appBackground: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(AppTheme.Dark.background)
                : UIColor(AppTheme.palette(SiteThemeManager.shared.theme).background)
        })
    }
    static var appForeground: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(AppTheme.Dark.foreground)
                : UIColor(AppTheme.palette(SiteThemeManager.shared.theme).foreground)
        })
    }
    static var appCard: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(AppTheme.Dark.card)
                : UIColor(AppTheme.palette(SiteThemeManager.shared.theme).card)
        })
    }
    static var appPrimary: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(AppTheme.Dark.primary)
                : UIColor(AppTheme.palette(SiteThemeManager.shared.theme).primary)
        })
    }
    static var appPrimaryFg: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(AppTheme.Dark.primaryForeground)
                : UIColor(AppTheme.palette(SiteThemeManager.shared.theme).primaryForeground)
        })
    }
    static var appSecondary: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(AppTheme.Dark.secondary)
                : UIColor(AppTheme.palette(SiteThemeManager.shared.theme).secondary)
        })
    }
    static var appSecondaryFg: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(AppTheme.Dark.secondaryForeground)
                : UIColor(AppTheme.palette(SiteThemeManager.shared.theme).secondaryForeground)
        })
    }
    static var appMuted: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(AppTheme.Dark.muted)
                : UIColor(AppTheme.palette(SiteThemeManager.shared.theme).muted)
        })
    }
    static var appMutedFg: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(AppTheme.Dark.mutedForeground)
                : UIColor(AppTheme.palette(SiteThemeManager.shared.theme).mutedForeground)
        })
    }
    static var appAccent: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(AppTheme.Dark.accent)
                : UIColor(AppTheme.palette(SiteThemeManager.shared.theme).accent)
        })
    }
    static var appDestructive: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(AppTheme.Dark.destructive)
                : UIColor(AppTheme.Light.destructive)
        })
    }
    static var appBorder: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(AppTheme.Dark.border)
                : UIColor(AppTheme.palette(SiteThemeManager.shared.theme).border)
        })
    }
    static var appInput: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(AppTheme.Dark.input)
                : UIColor(AppTheme.palette(SiteThemeManager.shared.theme).input)
        })
    }
    static var appRing: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(AppTheme.Dark.ring)
                : UIColor(AppTheme.palette(SiteThemeManager.shared.theme).ring)
        })
    }
    // 语义色
    static var appEmeraldBg: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(AppTheme.Dark.emeraldBg)
                : UIColor(AppTheme.Light.emeraldBg)
        })
    }
    static var appEmeraldBrd: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(AppTheme.Dark.emeraldBrd)
                : UIColor(AppTheme.Light.emeraldBrd)
        })
    }
    static var appEmeraldFg: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(AppTheme.Dark.emeraldFg)
                : UIColor(AppTheme.Light.emeraldFg)
        })
    }
    static var appEmeraldIcon: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(AppTheme.Dark.emeraldIcon)
                : UIColor(AppTheme.Light.emeraldIcon)
        })
    }
    static var appEmeraldLight: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(AppTheme.Dark.emeraldLight)
                : UIColor(AppTheme.Light.emeraldLight)
        })
    }
    /// 翠绿主色（对应网页莫兰迪映射 emerald-600 = hsl(140 13% 46%)，用于描边/徽标）
    static var appEmerald: Color { Color(h: 140, s: 13, l: 46) }
    /// 琥珀主色（对应网页莫兰迪映射 amber-500 = hsl(40 15% 64%)，用于描边/徽标）
    static var appAmber: Color { Color(h: 40, s: 15, l: 64) }
    static var appGreenBg: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(AppTheme.Dark.greenBg)
                : UIColor(AppTheme.Light.greenBg)
        })
    }
    static var appGreenFg: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(AppTheme.Dark.greenFg)
                : UIColor(AppTheme.Light.greenFg)
        })
    }
    static var appAmberBg: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(AppTheme.Dark.amberBg)
                : UIColor(AppTheme.Light.amberBg)
        })
    }
    static var appAmberBrd: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(AppTheme.Dark.amberBrd)
                : UIColor(AppTheme.Light.amberBrd)
        })
    }
    static var appAmberFg: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(AppTheme.Dark.amberFg)
                : UIColor(AppTheme.Light.amberFg)
        })
    }
    static var appAmberIcon: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(AppTheme.Dark.amberIcon)
                : UIColor(AppTheme.Light.amberIcon)
        })
    }
    static var appSkyBg: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(AppTheme.Dark.skyBg)
                : UIColor(AppTheme.Light.skyBg)
        })
    }
    static var appSkyBrd: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(AppTheme.Dark.skyBrd)
                : UIColor(AppTheme.Light.skyBrd)
        })
    }
    static var appRedFg: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(AppTheme.Dark.redFg)
                : UIColor(AppTheme.Light.redFg)
        })
    }

    static var appBrand50: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(AppTheme.Dark.brand900)
                : UIColor(AppTheme.palette(SiteThemeManager.shared.theme).brand50)
        })
    }
    static var appBrand100: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(AppTheme.Dark.brand700)
                : UIColor(AppTheme.palette(SiteThemeManager.shared.theme).brand100)
        })
    }
    static var appBrand200: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(AppTheme.Dark.brand700)
                : UIColor(AppTheme.Light.brand200)
        })
    }
    static var appBrand300: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(AppTheme.Dark.brand400)
                : UIColor(AppTheme.Light.brand300)
        })
    }
    static var appBrand400: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(AppTheme.Dark.brand400)
                : UIColor(AppTheme.palette(SiteThemeManager.shared.theme).brand400)
        })
    }
    static var appBrand500: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(AppTheme.Dark.brand400)
                : UIColor(AppTheme.palette(SiteThemeManager.shared.theme).brand500)
        })
    }
    static var appBrand600: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(AppTheme.Dark.brand300)
                : UIColor(AppTheme.palette(SiteThemeManager.shared.theme).brand600)
        })
    }
}

// MARK: - 固定盐系色（对应网页莫兰迪 tailwind 映射，不随主题/深色模式变化）
// 与 index.css 的 zinc/orange/sky/emerald/amber/red 覆盖值逐条一致
extension Color {
    static let fixZinc50  = Color(hex: "#fafafa")
    static let fixZinc200 = Color(hex: "#e4e4e7")
    static let fixZinc500 = Color(hex: "#71717a")
    static let fixZinc600 = Color(hex: "#52525b")
    static let fixOrange100 = Color(h: 30, s: 16, l: 93)
    static let fixOrange700 = Color(h: 26, s: 25, l: 41)
    static let fixSky600    = Color(h: 195, s: 22, l: 46)
    static let fixSky50     = Color(h: 195, s: 16, l: 92)
    static let fixSky800    = Color(h: 195, s: 28, l: 28)
    static let fixSky900    = Color(h: 195, s: 30, l: 20)
    static let fixEmerald100 = Color(h: 140, s: 11, l: 92)
    static let fixEmerald300 = Color(h: 140, s: 10, l: 84)
    static let fixEmerald700 = Color(h: 140, s: 15, l: 37)
    static let fixAmber100 = Color(h: 40, s: 14, l: 93)
    static let fixAmber200 = Color(h: 40, s: 14, l: 93)
    static let fixAmber300 = Color(h: 40, s: 13, l: 86)
    static let fixAmber700 = Color(h: 36, s: 22, l: 43)
    static let fixRed500   = Color(h: 6, s: 17, l: 62)
    // 盐系覆盖补全（与 index.css 逐条一致）
    static let fixAmber500   = Color(h: 40, s: 15, l: 64)
    static let fixAmber600   = Color(h: 38, s: 19, l: 53)
    static let fixAmber900   = Color(h: 32, s: 26, l: 25)
    static let fixEmerald600 = Color(h: 140, s: 13, l: 46)
    static let fixOrange600  = Color(h: 28, s: 22, l: 50)
    static let fixGreen100   = Color(h: 130, s: 10, l: 92)
    static let fixGreen200   = Color(h: 130, s: 10, l: 92)
    static let fixGreen300   = Color(h: 130, s: 9, l: 84)
    static let fixGreen600   = Color(h: 130, s: 13, l: 47)
    static let fixYellow100  = Color(h: 48, s: 16, l: 93)
    static let fixYellow600  = Color(h: 46, s: 22, l: 53)
    static let fixViolet100  = Color(h: 270, s: 10, l: 95)
    static let fixViolet600  = Color(h: 270, s: 12, l: 47)
    static let fixSky300     = Color(h: 195, s: 15, l: 84)
    static let fixSky700     = Color(h: 195, s: 26, l: 37)
    static let fixViolet200  = Color(h: 270, s: 10, l: 89)
    static let fixViolet300  = Color(h: 270, s: 9,  l: 81)
    static let fixViolet700  = Color(h: 270, s: 13, l: 38)
    static let fixAmber800   = Color(h: 34,  s: 24, l: 34)
    static let fixEmerald200 = Color(h: 140, s: 11, l: 92)
    static let fixAmber200Line = Color(h: 40, s: 14, l: 93)
    static let fixBlue100    = Color(h: 200, s: 16, l: 92)
    static let fixBlue700    = Color(h: 200, s: 26, l: 39)
    static let fixBlue800    = Color(h: 200, s: 28, l: 30)
    static let fixRed100     = Color(h: 6,   s: 16, l: 92)
    static let fixRed600     = Color(h: 5,   s: 22, l: 51)

    // Tailwind 原始调色板（HomeModules 状态胶囊等直接用 tailwind 色，不走盐系覆盖）
    static let twAmber100   = Color(hex: "#fef3c7")
    static let twAmber500   = Color(hex: "#f59e0b")
    static let twAmber700   = Color(hex: "#b45309")
    static let twEmerald100 = Color(hex: "#d1fae5")
    static let twEmerald700 = Color(hex: "#047857")
    static let twSky100     = Color(hex: "#e0f2fe")
    static let twSky700     = Color(hex: "#0369a1")
    static let twViolet100  = Color(hex: "#ede9fe")
    static let twViolet700  = Color(hex: "#6d28d9")
    static let twRed500     = Color(hex: "#ef4444")
    static let twAmber50    = Color(hex: "#fffbeb")
    static let twAmber200   = Color(hex: "#fde68a")
    static let twAmber300   = Color(hex: "#fcd34d")
    static let twAmber400   = Color(hex: "#fbbf24")
    static let twAmber600   = Color(hex: "#d97706")
    static let twAmber800   = Color(hex: "#92400e")
    static let twAmber900   = Color(hex: "#78350f")
    static let twEmerald400 = Color(hex: "#34d399")
    static let twEmerald500 = Color(hex: "#10b981")
    static let twSlate400   = Color(hex: "#94a3b8")
    static let twOrange600  = Color(hex: "#ea580c")
    static let twEmerald600 = Color(hex: "#059669")
    static let twSky500     = Color(hex: "#0ea5e9")
    static let twSky300     = Color(hex: "#7dd3fc")
    static let twSlate200   = Color(hex: "#e2e8f0")
    static let twSlate600   = Color(hex: "#475569")
    static let twOrange200  = Color(hex: "#fed7aa")
    static let twOrange700  = Color(hex: "#c2410c")
}
