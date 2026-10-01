import SwiftUI

// MARK: - 分享卡片渲染（复刻 lib/share-card.ts 的 720×960 画布布局）
// 顶部品牌条 → 封面快照 → 平台徽标 → 标题/作者/标签 → 贴纸 → 底部品牌条

enum CardPalettes {
    struct Palette {
        let label: String
        let primary: Color
        let bg: Color
        let soft: Color
        let text: Color
        let dot: Color
    }

    static let all: [(key: String, p: Palette)] = [
        ("orange",   Palette(label: "暖阳橙", primary: Color(hex: "#ff7a1a"), bg: Color(hex: "#faf7f2"), soft: Color(hex: "#ffe8d6"), text: Color(hex: "#7a5a2e"), dot: Color(hex: "#b0660a"))),
        ("pink",     Palette(label: "樱花粉", primary: Color(hex: "#ec4899"), bg: Color(hex: "#fdf5f8"), soft: Color(hex: "#fce0ec"), text: Color(hex: "#8a3a5e"), dot: Color(hex: "#b0447c"))),
        ("blue",     Palette(label: "晴空蓝", primary: Color(hex: "#3b82f6"), bg: Color(hex: "#f4f8fd"), soft: Color(hex: "#dbeafe"), text: Color(hex: "#2c4a7c"), dot: Color(hex: "#2f5ea8"))),
        ("green",    Palette(label: "抹茶绿", primary: Color(hex: "#22a06b"), bg: Color(hex: "#f4faf6"), soft: Color(hex: "#d8f0e2"), text: Color(hex: "#2c5c42"), dot: Color(hex: "#1f7a50"))),
        ("purple",   Palette(label: "葡萄紫", primary: Color(hex: "#8b5cf6"), bg: Color(hex: "#f8f6fd"), soft: Color(hex: "#e9e2fb"), text: Color(hex: "#4c3a7c"), dot: Color(hex: "#6d48c8"))),
        ("dark",     Palette(label: "酷黑",   primary: Color(hex: "#26262b"), bg: Color(hex: "#f6f6f7"), soft: Color(hex: "#e2e2e6"), text: Color(hex: "#3a3a40"), dot: Color(hex: "#4a4a52"))),
        ("crimson",  Palette(label: "深红",   primary: Color(hex: "#b91c1c"), bg: Color(hex: "#fbf3f3"), soft: Color(hex: "#f3d7d7"), text: Color(hex: "#7a2626"), dot: Color(hex: "#8f1d1d"))),
        ("wine",     Palette(label: "酒红",   primary: Color(hex: "#9f1239"), bg: Color(hex: "#fbf3f5"), soft: Color(hex: "#f3d3dc"), text: Color(hex: "#6e1a30"), dot: Color(hex: "#7c1530"))),
        ("scarlet",  Palette(label: "绯红",   primary: Color(hex: "#dc2626"), bg: Color(hex: "#fdf4f4"), soft: Color(hex: "#fadcdc"), text: Color(hex: "#8a2828"), dot: Color(hex: "#b01f1f"))),
        ("teal",     Palette(label: "青碧",   primary: Color(hex: "#0d9488"), bg: Color(hex: "#f2faf9"), soft: Color(hex: "#d3eeeb"), text: Color(hex: "#155e55"), dot: Color(hex: "#0f766e"))),
        ("indigo",   Palette(label: "靛蓝",   primary: Color(hex: "#4f46e5"), bg: Color(hex: "#f5f5fd"), soft: Color(hex: "#e0e0fa"), text: Color(hex: "#37308a"), dot: Color(hex: "#4338ca"))),
        ("gold",     Palette(label: "麦金",   primary: Color(hex: "#d97706"), bg: Color(hex: "#fbf7ef"), soft: Color(hex: "#f6e7cd"), text: Color(hex: "#7c4a12"), dot: Color(hex: "#b45309"))),
    ]

    /// 解析任意 palette 值：预设 key 或 #rrggbb 自定义色（复刻 resolvePalette / paletteFromPrimary）
    static func resolve(_ key: String?) -> Palette {
        guard let key = key, !key.isEmpty else { return all[0].p }
        if let hit = all.first(where: { $0.key == key }) { return hit.p }
        if key.hasPrefix("#"), key.count == 7 {
            let primary = Color(hex: key)
            // 简化：主色 + 同色系浅色背景（mix 95% 白 / 82% 白 / 45% 黑 / 20% 黑）
            return Palette(
                label: "自定义",
                primary: primary,
                bg: primary.opacity(0.05).blended(with: .white, ratio: 0.95),
                soft: primary.opacity(0.18).blended(with: .white, ratio: 0.82),
                text: primary.blended(with: .black, ratio: 0.45),
                dot: primary.blended(with: .black, ratio: 0.2)
            )
        }
        return all[0].p
    }
}

private extension Color {
    /// 近似 paletteFromPrimary 的混色（与白色/黑色按比例混合）
    func blended(with other: Color, ratio: Double) -> Color {
        let ui1 = UIColor(self), ui2 = UIColor(other)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        ui1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        ui2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return Color(.sRGB,
                     red: Double(r1 + (r2 - r1) * ratio),
                     green: Double(g1 + (g2 - g1) * ratio),
                     blue: Double(b1 + (b2 - b1) * ratio),
                     opacity: 1)
    }
}

// MARK: - 分享卡片画布（设计尺寸 720×960，外部用缩放适配）
struct ShareCardCanvas: View {
    let title: String
    let cover: UIImage?          // nil = 纯色底 + 站名
    let platformLabel: String
    let authorName: String
    let tags: [String]
    let theme: CardConfig?       // nil = 默认橙色无贴纸

    static let designW: CGFloat = 720
    static let designH: CGFloat = 960

    private var palette: CardPalettes.Palette { CardPalettes.resolve(theme?.palette) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // 背景
            if theme?.gradient == true {
                LinearGradient(colors: [palette.bg, palette.soft], startPoint: .topLeading, endPoint: .bottomTrailing)
            } else {
                palette.bg
            }

            VStack(alignment: .leading, spacing: 0) {
                // 顶部品牌色条
                palette.primary.frame(height: 10)

                // 封面快照
                ZStack {
                    if let cover = cover {
                        GeometryReader { geo in
                            Image(uiImage: cover)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geo.size.width, height: 520)
                                .clipped()
                        }
                    } else {
                        palette.soft
                        Text("码上领")
                            .font(.system(size: 90, weight: .bold))
                            .foregroundColor(palette.primary)
                    }
                    // 封面底部渐变过渡到信息区
                    VStack {
                        Spacer()
                        LinearGradient(colors: [palette.bg.opacity(0), palette.bg],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(height: 90)
                    }
                }
                .frame(height: 520)

                // 信息区
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 16) {
                        Text(platformLabel)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 22)
                            .frame(height: 44)
                            .background(palette.primary)
                            .cornerRadius(22)
                        Text("无料分享 · 快来领取")
                            .font(.system(size: 22))
                            .foregroundColor(palette.dot)
                            .padding(.bottom, 4)
                    }
                    .padding(.top, 28)

                    Text(title)
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                        .lineLimit(2)
                        .lineSpacing(10)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 32)

                    Text("来自 \(authorName) 的橱窗")
                        .font(.system(size: 26))
                        .foregroundColor(Color(hex: "#6b6b6b"))
                        .padding(.top, 18)

                    if !tags.isEmpty {
                        HStack(spacing: 12) {
                            ForEach(Array(tags.prefix(5).enumerated()), id: \.offset) { _, tag in
                                Text(tag)
                                    .font(.system(size: 22))
                                    .foregroundColor(palette.text)
                                    .padding(.horizontal, 16)
                                    .frame(height: 38)
                                    .background(palette.soft)
                                    .cornerRadius(19)
                            }
                        }
                        .padding(.top, 10)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 44)
            }

            // 贴纸（最多 2 个；网页 drawImage/预览热区均以左上角为原点：left=x·W, top=y·H）
            if let stickers = theme?.stickers {
                ZStack(alignment: .topLeading) {
                    ForEach(Array(stickers.prefix(2))) { st in
                        if let data = SiteConfig.dataFromDataURL(st.url), let ui = UIImage(data: data) {
                            Image(uiImage: ui)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: Self.designW * st.scale)
                                .offset(x: Self.designW * st.x, y: Self.designH * st.y)
                        }
                    }
                }
                .frame(width: Self.designW, height: Self.designH)
            }

            // 底部品牌条
            VStack {
                Spacer()
                ZStack(alignment: .leading) {
                    palette.primary
                        .frame(height: theme != nil ? 56 : 92)
                    HStack(alignment: .lastTextBaseline, spacing: 12) {
                        Text("码上领")
                            .font(.system(size: theme != nil ? 24 : 34, weight: .bold))
                        Text("mashangling.kimi.site")
                            .font(.system(size: theme != nil ? 16 : 22))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 44)
                    .padding(.bottom, theme != nil ? 12 : 26)
                }
            }
        }
        .frame(width: Self.designW, height: Self.designH)
    }

    /// 按目标宽度缩放后的视图
    func scaled(to width: CGFloat) -> some View {
        let scale = width / Self.designW
        return self
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: width, height: width * Self.designH / Self.designW)
            .clipped()
    }
}

// MARK: - 卡片主题缩略图（复刻 CardThemeThumbnail：用示例数据渲染）
struct CardThemeThumbnailView: View {
    let config: CardConfig

    var body: some View {
        GeometryReader { geo in
            ShareCardCanvas(
                title: "示例橱窗标题",
                cover: nil,
                platformLabel: "外部无料",
                authorName: "创作者",
                tags: ["纸制品", "同人"],
                theme: config
            )
            .scaleEffect(geo.size.width / ShareCardCanvas.designW, anchor: .topLeading)
            .frame(width: geo.size.width, height: geo.size.width * ShareCardCanvas.designH / ShareCardCanvas.designW)
            .clipped()
        }
        .aspectRatio(ShareCardCanvas.designW / ShareCardCanvas.designH, contentMode: .fit)
    }
}

// MARK: - 封面图加载（分享图片生成前预取）
enum CoverLoader {
    /// dataURL 本地解码；远程路径走网络（带缓存）；失败返回 nil
    static func load(_ path: String?) async -> UIImage? {
        guard let path = path, !path.isEmpty else { return nil }
        if SiteConfig.isDataURL(path), let data = SiteConfig.dataFromDataURL(path) {
            return UIImage(data: data)
        }
        guard let url = SiteConfig.absoluteURL(path) else { return nil }
        if let cached = await CacheManager.shared.loadImage(key: url.absoluteString) { return cached }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let img = UIImage(data: data) else { return nil }
        await CacheManager.shared.cacheImage(img, key: url.absoluteString)
        return img
    }
}
