import SwiftUI
import UIKit

// MARK: - 盲盒图鉴（逐行复刻网页 2026-10-13 MysteryCollection.tsx）
// 每个盲盒橱窗一张文字卡片（不显示图）；点开 → 全部无料名列表：抽中过的点亮（显示码，可「显示图片」），
// 未抽中的灰暗（无码、不可看图）。集齐可领 200 积分（每橱窗一次）。待领取红点；已集齐/未集齐筛选；旧→新排序。
struct MysteryCollectionView: View {
    @EnvironmentObject var authManager: AuthManager

    private enum FilterKey: String, CaseIterable {
        case all, complete, incomplete
        var label: String {
            switch self {
            case .all: return "全部"
            case .complete: return "已集齐"
            case .incomplete: return "未集齐"
            }
        }
    }

    struct ViewImg: Identifiable {
        let id = UUID()
        let name: String
        let image: String
    }

    @State private var cards: [MysteryCollectionCard] = []
    @State private var rewardPoints = 200
    @State private var loading = true
    @State private var filter: FilterKey = .all
    @State private var openCard: MysteryCollectionCard? = nil
    @State private var viewImg: ViewImg? = nil
    @State private var copiedCode: String? = nil
    @State private var claiming = false
    @State private var openDetailId: Int? = nil

    private let violet = Color(hex: "#8b5cf6")      // violet-500
    private let violetText = Color(hex: "#6d28d9")  // violet-700
    private let violetSoft = Color(hex: "#ede9fe")  // violet-100
    private let violetBorder = Color(hex: "#c4b5fd")// violet-300

    private var filtered: [MysteryCollectionCard] {
        cards.filter { c in
            switch filter {
            case .all: return true
            case .complete: return c.complete == true
            case .incomplete: return c.complete != true
            }
        }
    }

    private var pendingCount: Int { cards.filter { $0.pending == true }.count }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // 标题（网页：BookOpen violet-500 + text-2xl font-bold tracking-tight）
                HStack(spacing: 8) {
                    Image(systemName: "book")
                        .font(.system(size: 20))
                        .foregroundColor(violet)
                    Text("盲盒图鉴")
                        .font(.system(size: 24, weight: .bold))
                        .tracking(-0.6)
                        .foregroundColor(.appForeground)
                }
                // 副标题（含待领取提示）
                (Text("每个盲盒橱窗的全部无料在这里集卡：抽中即点亮并可查看码与照片；集齐一个橱窗可领 \(rewardPoints) 积分（每橱窗一次）。")
                    .font(.system(size: 12))
                    .foregroundColor(.appMutedFg)
                 + Text(pendingCount > 0 ? " 你有 \(pendingCount) 个橱窗的奖励待领取！" : "")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.fixAmber600))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)

                // 筛选（网页：rounded-full px-3.5 py-1.5 text-xs，选中 bg-violet-500）
                HStack(spacing: 6) {
                    ForEach(FilterKey.allCases, id: \.self) { f in
                        Button { filter = f } label: {
                            Text(f.label)
                                .font(.system(size: 12, weight: filter == f ? .medium : .regular))
                                .foregroundColor(filter == f ? .white : .appForeground)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(filter == f ? violet : Color.appSecondary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 16)

                // 卡片列表
                VStack(spacing: 12) {
                    if loading {
                        LoadingView().frame(maxWidth: .infinity).padding(.top, 40)
                    } else if filtered.isEmpty {
                        Text(cards.isEmpty ? "还没有盲盒橱窗" : "该筛选下暂无橱窗")
                            .font(.system(size: 14))
                            .foregroundColor(.appMutedFg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                    } else {
                        ForEach(filtered) { c in cardRow(c) }
                    }
                }
                .padding(.top, 16)
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: Binding(
            get: { openDetailId != nil },
            set: { if !$0 { openDetailId = nil } }
        )) {
            if let id = openDetailId {
                ShowcaseDetailView(showcaseId: id)
            }
        }
        .task { await load() }
        .refreshable { await load() }
        // 橱窗图鉴明细弹层（网页 Dialog max-h-85vh）
        .sheet(item: $openCard) { c in collectionSheet(c) }
        // 单张图片查看
        .sheet(item: $viewImg) { v in
            NavigationStack {
                ScrollView(showsIndicators: false) {
                    AppImage(path: v.image, contentMode: .fit)
                        .cornerRadius(8)
                        .padding(16)
                }
                .background(Color.appBackground)
                .navigationTitle(v.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("关闭") { viewImg = nil }
                    }
                }
            }
        }
    }

    // MARK: 橱窗卡片（网页：dice 图标 + 标题徽标 + 进度副标题 + 已集齐胶囊 + 待领红点 + chevron）
    private func cardRow(_ c: MysteryCollectionCard) -> some View {
        Button { openCard = c } label: {
            HStack(spacing: 12) {
                Image(systemName: "dice")
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "#a78bfa"))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(c.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.appForeground)
                            .lineLimit(1)
                        if c.mine == true {
                            Text("你的橱窗")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(violetText)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(violetSoft)
                                .cornerRadius(4)
                        }
                        if c.removed == true {
                            Text("已下架")
                                .font(.system(size: 10))
                                .foregroundColor(.appMutedFg)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.appSecondary)
                                .cornerRadius(4)
                        }
                    }
                    Text(subtitle(c))
                        .font(.system(size: 12))
                        .foregroundColor(.appMutedFg)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if c.complete == true && c.mine != true {
                    Text("已集齐")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(violetText)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(violetSoft)
                        .clipShape(Capsule())
                }
                if c.pending == true {
                    Circle()
                        .fill(Color.fixAmber500)
                        .frame(width: 10, height: 10)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.appMutedFg.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.appCard)
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder.opacity(0.6), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private func subtitle(_ c: MysteryCollectionCard) -> String {
        var s: String
        if c.mine == true {
            s = "共 \(c.totalItems) 款 · 全部默认解锁"
        } else if authManager.isAuthenticated {
            s = "已点亮 \(c.ownedCount)/\(c.totalItems)"
        } else {
            s = "共 \(c.totalItems) 款"
        }
        if c.mine != true && c.complete == true && c.claimed != true { s += " · 可领奖励" }
        if c.claimed == true { s += " · 奖励已领" }
        return s
    }

    // MARK: 明细弹层（网页 Dialog：mine 提示条 / 领奖按钮 / 无料条目 / 前往橱窗）
    private func collectionSheet(_ c: MysteryCollectionCard) -> some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(c.mine == true
                         ? "共 \(c.totalItems) 款 · 你的橱窗默认全部解锁"
                         : "已点亮 \(c.ownedCount)/\(c.totalItems)"
                           + (c.removed == true ? (c.mine == true ? " · 已下架" : " · 已下架（仍可集卡领奖）") : ""))
                        .font(.system(size: 12))
                        .foregroundColor(.appMutedFg)

                    // 自己的橱窗：提示无奖励
                    if c.mine == true {
                        Text("这是你发布的橱窗，图鉴全部默认解锁，不参与集齐积分奖励")
                            .font(.system(size: 12))
                            .foregroundColor(violetText)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(Color(hex: "#f5f3ff"))
                            .cornerRadius(4)
                    }

                    // 领取奖励（网页：amber-500 圆角大按钮）
                    if c.mine != true && c.complete == true && c.claimed != true {
                        Button { Task { await claimReward(c) } } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "gift").font(.system(size: 14))
                                Text(claiming ? "领取中…" : "领取奖励 +\(rewardPoints) 积分")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.fixAmber500)
                            .cornerRadius(4)
                            .opacity(claiming ? 0.6 : 1)
                        }
                        .buttonStyle(.plain)
                        .disabled(claiming)
                    }
                    if c.claimed == true {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.fixEmerald600)
                            Text("集齐奖励已领取")
                                .font(.system(size: 12))
                                .foregroundColor(.appMutedFg)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.appSecondary)
                        .cornerRadius(4)
                    }

                    // 无料条目
                    VStack(spacing: 8) {
                        ForEach(c.items ?? [], id: \.itemId) { it in itemRow(it) }
                    }

                    // 前往橱窗
                    Button {
                        openCard = nil
                        openDetailId = c.showcaseId
                    } label: {
                        Text(c.mine == true ? "前往橱窗 →" : "前往橱窗抽取 →")
                            .font(.system(size: 14))
                            .foregroundColor(.appMutedFg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .cornerRadius(4)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder.opacity(0.6), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .background(Color.appBackground)
            .navigationTitle(c.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { openCard = nil }
                }
            }
        }
    }

    // MARK: 无料条目（网页：点亮=violet 边框底 + 码 + 复制 + 显示图片；未点亮=灰显 grayscale）
    private func itemRow(_ it: MysteryCollectionItem) -> some View {
        let owned = it.owned == true
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(owned ? violet : Color.appSecondary)
                        .frame(width: 20, height: 20)
                    Image(systemName: owned ? "checkmark" : "lock.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(owned ? .white : .appMutedFg)
                }
                Text(owned ? it.name : "？？？")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.appForeground)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("\(fmtPercent(it.percent))%")
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundColor(.appMutedFg)
            }
            if owned {
                HStack(spacing: 8) {
                    Text(it.code ?? "")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.appForeground)
                        .lineLimit(1)
                        .padding(.horizontal, 8).padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appCard)
                        .cornerRadius(6)
                    Button {
                        if let code = it.code {
                            UIPasteboard.general.string = code
                            copiedCode = code
                            ToastCenter.shared.success("码已复制")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                if copiedCode == code { copiedCode = nil }
                            }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: copiedCode == it.code ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 10))
                            Text(copiedCode == it.code ? "已复制" : "复制")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(copiedCode == it.code ? .fixEmerald600 : .appForeground)
                        .padding(.horizontal, 8).padding(.vertical, 6)
                        .background(Color.appSecondary)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    Button {
                        if let img = it.image {
                            viewImg = ViewImg(name: it.name, image: img)
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "eye").font(.system(size: 10))
                            Text("显示图片").font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 6)
                        .background(violet)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)
            } else {
                Text("未抽中：点亮后可查看码与照片")
                    .font(.system(size: 11))
                    .foregroundColor(.appMutedFg)
                    .padding(.top, 6)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(owned ? violetSoft.opacity(0.6) : Color.appSecondary.opacity(0.4))
        .cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(owned ? violetBorder : Color.appBorder.opacity(0.5), lineWidth: 0.5))
        .opacity(owned ? 1 : 0.6)
        .grayscale(owned ? 0 : 1)
    }

    private func fmtPercent(_ p: Double) -> String {
        if p == p.rounded() { return String(Int(p)) }
        return String(format: "%g", p)
    }

    private func load() async {
        loading = true
        if let r = try? await MashanglingAPI.shared.claim.collection() {
            cards = r.items ?? []
            rewardPoints = r.rewardPoints ?? 200
        }
        loading = false
    }

    private func claimReward(_ c: MysteryCollectionCard) async {
        guard authManager.isAuthenticated else { return }
        claiming = true
        defer { claiming = false }
        do {
            let pts = try await MashanglingAPI.shared.claim.claimCollectionReward(showcaseId: c.showcaseId)
            ToastCenter.shared.success("集齐奖励到账：+\(pts) 积分")
            await load()
            // 弹层里的卡片状态同步
            if let updated = cards.first(where: { $0.showcaseId == c.showcaseId }) {
                openCard = updated
            }
        } catch {
            ToastCenter.shared.error(error.localizedDescription)
        }
    }
}
