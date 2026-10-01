import SwiftUI

// MARK: - 橱窗卡片（逐行复刻网页 ShowcaseCard.tsx）
// 结构：封面（4:3，圆角 12，带边框）+ 下方信息区（无卡片底，直接落在页面背景上）
struct ShowcaseCardView: View {
    let item: Showcase
    var rank: Int? = nil            // 热门榜名次（1 金冠 2 银冠）
    var isOwner: Bool = false       // 本人（显示余量角标 剩x/共y）
    var onLike: (() -> Void)? = nil

    private var liked: Bool { item.likedByMe ?? false }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cover
            infoArea
        }
        .contentShape(Rectangle())
    }

    // MARK: 封面 + 全部角标（位置与配色与网页一致）
    private var cover: some View {
        Color.appSecondary
            .aspectRatio(4.0 / 3.0, contentMode: .fit)
            .overlay(
                ZStack {
                    AppImage(path: item.coverImage)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()

                    // 右上：平台标（白底 85%）
                    VStack {
                        HStack {
                            Spacer()
                            Text(PlatformLabel.of(item.platform))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color.appForeground.opacity(0.8))
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(Color.white.opacity(0.85))
                                .cornerRadius(10)
                        }
                        Spacer()
                    }
                    .padding(8)

                    // 左上：金冠 / 银冠 / 置顶
                    VStack {
                        HStack {
                            if let rank = rank, rank == 1 {
                                rankBadge(text: "NO.1", colors: ["#f9e29c", "#f0c64f", "#d99e2b"], fg: Color(h: 32, s: 26, l: 25))
                            } else if let rank = rank, rank == 2 {
                                rankBadge(text: "NO.2", colors: ["#f8fafc", "#dbe2ea", "#a8b6c6"], fg: Color(h: 215, s: 16, l: 35))
                            } else if item.pinned == true {
                                HStack(spacing: 3) {
                                    Image(systemName: "pin.fill").font(.system(size: 9))
                                    Text("置顶").font(.system(size: 11))
                                }
                                .foregroundColor(.appPrimaryFg)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(Color.appForeground.opacity(0.8))
                                .cornerRadius(10)
                            }
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(8)

                    // 右上（平台标下方）：本人余量 剩/共 或 「补」
                    VStack {
                        HStack {
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Spacer().frame(height: 28) // 平台标(top:8,高~20)+间距8 → 第二行 top:36
                                // 网页里「余量」与「补」同在 right:8 top:36，补在后覆盖余量
                                ZStack(alignment: .topTrailing) {
                                    if isOwner, let r = item.remaining, let q = item.quantity {
                                        Text("\(r)/\(q)")
                                            .font(.system(size: 11, weight: .bold))
                                            .monospacedDigit()
                                            .foregroundColor(r == 0 ? .white : .appForeground)
                                            .padding(.horizontal, 8).padding(.vertical, 2)
                                            .background(r == 0 ? Color(h: 240, s: 4, l: 30).opacity(0.9) : Color.white.opacity(0.9))
                                            .cornerRadius(10)
                                    }
                                    if let cc = item.codeCount, cc > 0 {
                                        Text("补")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.appPrimaryFg)
                                            .padding(.horizontal, 8).padding(.vertical, 2)
                                            .background(Color.appPrimary)
                                            .cornerRadius(10)
                                    }
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(8)

                    // 左下：库存状态 + 限时（限时在库存上方避让）
                    VStack {
                        Spacer()
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                if let eb = item.expiresBadgeText {
                                    HStack(spacing: 3) {
                                        Image(systemName: "timer").font(.system(size: 9))
                                        Text(eb).font(.system(size: 11, weight: .medium))
                                    }
                                    .foregroundColor(item.isExpired ? Color(h: 240, s: 5, l: 96) : .white)
                                    .padding(.horizontal, 8).padding(.vertical, 2)
                                    .background(item.isExpired ? Color(h: 240, s: 4, l: 30).opacity(0.85) : Color(h: 30, s: 17, l: 61).opacity(0.9))
                                    .cornerRadius(10)
                                }
                                stockBadge
                            }
                            Spacer()
                            // 右下：积分解锁
                            if let pc = item.pointCost, pc > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: "dollarsign.circle.fill").font(.system(size: 9))
                                    Text("\(pc)").font(.system(size: 11, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(Color(h: 40, s: 15, l: 64))
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding(8)
                }
                .clipped()
            )
            .cornerRadius(4)   // 盐系主题 rounded-xl = 4px
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder.opacity(0.6), lineWidth: 1))
            .clipped()
    }

    private func rankBadge(text: String, colors: [String], fg: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "crown.fill").font(.system(size: 10))
            Text(text).font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(fg)
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(
            LinearGradient(colors: colors.map { Color(hex: $0) },
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
    }

    @ViewBuilder
    private var stockBadge: some View {
        switch item.stockStatus {
        case "soldout":
            Text("领完即止")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 8).padding(.vertical, 2)
                .background(Color.black.opacity(0.7))
                .cornerRadius(10)
        case "restock":
            Text("可补码")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 8).padding(.vertical, 2)
                .background(Color(h: 140, s: 13, l: 46).opacity(0.9))
                .cornerRadius(10)
        case "limited":
            Text(item.quantity.map { "限量 \($0) 份" } ?? "限量")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 8).padding(.vertical, 2)
                .background(Color(h: 40, s: 15, l: 64))
                .cornerRadius(10)
        default:
            EmptyView()
        }
    }

    // MARK: 信息区（网页：左侧标题/作者/等级头衔/tags，右侧点赞+领到数）
    private var infoArea: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Text(item.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.appForeground)
                    .lineLimit(1)
                    .padding(.top, 10)

                // 作者
                HStack(spacing: 6) {
                    AvatarView(path: item.author?.avatar, name: item.author?.name ?? "", size: 20)
                    Text(item.author?.name ?? "未知用户")
                        .font(.system(size: 12))
                        .foregroundColor(.appMutedFg)
                        .lineLimit(1)
                }
                .padding(.top, 6)

                // 等级 + 头衔
                HStack(spacing: 4) {
                    LevelBadgeView(level: item.author?.level ?? 1)
                    TitleBadgeView(equippedTitle: item.author?.equippedTitle)
                }
                .padding(.top, 4)

                // tags（最多 3 个；网页 flex-wrap，胶囊不压缩）
                if let tags = item.tags, !tags.isEmpty {
                    FlowLayout(spacing: 4) {
                        ForEach(tags.prefix(3)) { t in
                            Text(t.name)
                                .font(.system(size: 11))
                                .foregroundColor(.appSecondaryFg)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(Color.appSecondary)
                                .cornerRadius(10)
                                .fixedSize()
                        }
                    }
                    .padding(.top, 6)
                }
            }

            Spacer(minLength: 0)

            // 右列：点赞 + 领到数
            VStack(alignment: .trailing, spacing: 4) {
                Button { onLike?() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: liked ? "heart.fill" : "heart")
                            .font(.system(size: 13))
                        Text("\(item.likeCount ?? 0)")
                            .font(.system(size: 12, weight: liked ? .semibold : .regular))
                    }
                    .foregroundColor(liked ? .appPrimary : .appMutedFg)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(liked ? Color.appPrimary.opacity(0.1) : Color.clear)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)

                if let cc = item.claimCount, cc > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.rectangle").font(.system(size: 10))
                        Text("\(cc) 人领到").font(.system(size: 11))
                    }
                    .foregroundColor(.appMutedFg)
                    .padding(.horizontal, 8)
                }
            }
        }
        .padding(.horizontal, 2)
    }
}
