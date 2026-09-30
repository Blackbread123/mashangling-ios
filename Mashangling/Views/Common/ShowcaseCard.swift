import SwiftUI

// MARK: - 橱窗卡片（对应网页 ShowcaseCard.tsx，feed 两列网格）
struct ShowcaseCardView: View {
    let item: Showcase
    var rank: Int? = nil            // 热门榜名次（1/2 显示金银皇冠）
    var isOwner: Bool = false       // 是否本人（显示余量角标）
    var onLike: (() -> Void)? = nil

    private var liked: Bool { item.likedByMe ?? false }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 封面 + 角标（网页为 4:3 object-cover）
            // 尺寸由 Color 容器决定（无固有尺寸，比例永远锁定 4:3），图片只在 overlay 里填充裁切
            Color.appSecondary
                .aspectRatio(4.0 / 3.0, contentMode: .fit)
                .overlay(
                    ZStack(alignment: .topTrailing) {
                        AppImage(path: item.coverImage)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()

                        // 右上角平台标签
                        MiniBadge(text: PlatformLabel.of(item.platform),
                                  fg: .white, bg: Color.black.opacity(0.55))
                            .padding(6)

                        // 左上角徽章列
                        VStack(alignment: .leading, spacing: 4) {
                            if let rank = rank, rank <= 2 {
                                Text(rank == 1 ? "👑 NO.1" : "🥈 NO.2")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(rank == 1 ? Color(h: 45, s: 90, l: 45) : Color.gray)
                                    .cornerRadius(6)
                            }
                            if item.pinned == true {
                                MiniBadge(text: "置顶", fg: .appPrimaryFg, bg: .appPrimary)
                            }
                            if let txt = stockBadgeText {
                                MiniBadge(text: txt.text, fg: txt.fg, bg: txt.bg)
                            }
                            if let eb = item.expiresBadgeText {
                                MiniBadge(text: eb,
                                          fg: item.isExpired ? .white : .appAmberFg,
                                          bg: item.isExpired ? .appDestructive : .appAmberBg)
                            }
                            if let pc = item.pointCost, pc > 0 {
                                MiniBadge(text: "\(pc) 积分", fg: .appAmberFg, bg: .appAmberBg)
                            }
                            if let cc = item.codeCount, cc > 0 {
                                MiniBadge(text: "补码×\(cc)", fg: .appEmeraldFg, bg: .appEmeraldBg)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                        .frame(maxHeight: .infinity, alignment: .top)
                    }
                    .clipped()
                )
                .clipped()

            // 信息区
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.appForeground)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // 作者
                HStack(spacing: 5) {
                    AvatarView(path: item.author?.avatar, name: item.author?.name ?? "", size: 16)
                    Text(item.author?.name ?? "")
                        .font(.system(size: 11))
                        .foregroundColor(.appMutedFg)
                        .lineLimit(1)
                    if let t = item.author?.equippedTitle, !t.isEmpty {
                        Text(t).font(.system(size: 10)).foregroundColor(.appAmberFg).lineLimit(1)
                    }
                }

                // 互动行
                HStack(spacing: 12) {
                    Button { onLike?() } label: {
                        HStack(spacing: 3) {
                            Image(systemName: liked ? "heart.fill" : "heart")
                                .font(.system(size: 12))
                                .foregroundColor(liked ? .appRedFg : .appMutedFg)
                            Text("\(item.likeCount ?? 0)")
                                .font(.system(size: 11))
                                .foregroundColor(.appMutedFg)
                        }
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                        Text("\(item.claimCount ?? 0) 人领到")
                            .font(.system(size: 11))
                            .foregroundColor(.appMutedFg)
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(10)
        }
        .background(Color.appCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, lineWidth: 0.5))
        .contentShape(Rectangle())
    }

    /// 库存角标
    private var stockBadgeText: (text: String, fg: Color, bg: Color)? {
        if isOwner, let r = item.remaining, let q = item.quantity {
            return ("剩 \(r)/\(q)", .appSkyBrd, .appSkyBg)
        }
        switch item.stockStatus {
        case "soldout":  return ("领完即止", .appRedFg, .appSecondary)
        case "restock":  return ("可补码", .appEmeraldFg, .appEmeraldBg)
        case "limited":
            if let q = item.quantity { return ("限量 \(q) 份", .appAmberFg, .appAmberBg) }
            return ("限量", .appAmberFg, .appAmberBg)
        default: return nil
        }
    }
}
