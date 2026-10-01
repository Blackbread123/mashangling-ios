import SwiftUI

// MARK: - 农场（复刻 ChickenFarm 组件）
// 第一行母鸡（用户上传的 PNG dataURL）；第二行 鸡蛋×数量；
// 种植区 6 种果树两列排列；果实每天自动长出 1 个，周日 23:00 落地结算。
struct FarmView: View {
    let userId: Int
    /// 嵌入个人主页时使用：去掉独立 ScrollView 与导航标题
    var embedded: Bool = false

    @StateObject private var vm: FarmViewModel

    init(userId: Int, embedded: Bool = false) {
        self.userId = userId
        self.embedded = embedded
        _vm = StateObject(wrappedValue: FarmViewModel(userId: userId))
    }

    var body: some View {
        Group {
            if embedded {
                farmBody
            } else {
                farmBody
                    .background(Color.appBackground)
                    .navigationTitle("农场")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .task { await vm.load() }
    }

    @ViewBuilder
    private var farmBody: some View {
        if let d = vm.overview, d.visible {
            farmContent(d)
        } else if vm.loading {
            LoadingView()
        } else {
            EmptyStateView(icon: "leaf", title: "农场未开放", subtitle: "对方把农场设为私密了")
        }
    }

    @ViewBuilder
    private func farmContent(_ d: FarmOverview) -> some View {
        if embedded {
            farmSections(d)
        } else {
            ScrollView(showsIndicators: false) {
                farmSections(d)
                    .padding(16)
            }
        }
    }

    @ViewBuilder
    private func farmSections(_ d: FarmOverview) -> some View {
        VStack(alignment: .leading, spacing: 16) {
                // 标题行
                HStack(spacing: 6) {
                    Text("农场")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.appForeground)
                    Text("鸡产蛋 · 树结果 · 每天 23:00 结算积分利息")
                        .font(.system(size: 11))
                        .foregroundColor(.appMutedFg)
                    Spacer(minLength: 0)
                    if d.isOwner {
                        Button {
                            Task { await vm.toggleVisibility() }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: vm.farmPublic ? "eye" : "eye.slash")
                                    .font(.system(size: 11))
                                Text(vm.farmPublic ? "对外展示中" : "已私密")
                                    .font(.system(size: 11))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .foregroundColor(.appMutedFg)
                            .overlay(
                                Capsule().stroke(Color.appBorder, lineWidth: 1)
                            )
                        }
                        .disabled(vm.toggling)
                    }
                }

                // 母鸡 + 鸡蛋
                henCard(d)

                // 种植区
                plantSection(d)

                // 操作行（仅本人）
                if d.isOwner {
                    ownerRow(d)
                }
        }
    }

    // MARK: - 母鸡卡片
    @ViewBuilder
    private func henCard(_ d: FarmOverview) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .bottom, spacing: 4) {
                if let hens = d.hens, !hens.isEmpty {
                    ForEach(Array(hens.prefix(7).enumerated()), id: \.offset) { _, src in
                        AppImage(path: src, contentMode: .fit)
                            .frame(maxWidth: 56)
                            .frame(height: 48)
                            .clipped()
                    }
                } else {
                    Text("🐣")
                        .font(.system(size: 40))
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 6) {
                Text("🧺")
                    .font(.system(size: 18))
                AppImage(path: "/farm/egg.png", contentMode: .fit)
                    .frame(width: 28, height: 28)
                Text("× \(d.eggCount)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.appForeground)
                Text("（上限 \(d.eggCap) = 母鸡数 × 5）")
                    .font(.system(size: 10))
                    .foregroundColor(.appMutedFg)
                if d.eggCount == 0 {
                    Text("还没有鸡蛋")
                        .font(.system(size: 11))
                        .foregroundColor(.appMutedFg)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.appSecondary.opacity(0.3))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.appBorder, style: StrokeStyle(lineWidth: 1, dash: [5]))
        )
        .cornerRadius(12)
    }

    // MARK: - 种植区
    @ViewBuilder
    private func plantSection(_ d: FarmOverview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 13))
                    .foregroundColor(Color.appGreenFg)
                Text("种植区")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.appForeground)
                Text("果实每天自动长出 1 个，周日 23:00 落地结算")
                    .font(.system(size: 10))
                    .foregroundColor(.appMutedFg)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(d.trees ?? []) { t in
                    if t.owned {
                        ownedTreeCell(t)
                    } else {
                        lockedTreeCell(t, isOwner: d.isOwner)
                    }
                }
            }
        }
    }

    private func ownedTreeCell(_ t: FarmOverview.FarmTree) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                AppImage(path: "/farm/tree_\(t.key).png", contentMode: .fit)
                    .frame(width: 40, height: 40)
                Text(t.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.appForeground)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            HStack {
                Text("本周已结 \(t.fruitCount) 果")
                    .font(.system(size: 9))
                    .foregroundColor(.appMutedFg)
                Spacer(minLength: 0)
                HStack(spacing: 2) {
                    AppImage(path: "/farm/fruit_\(t.key).png", contentMode: .fit)
                        .frame(width: 20, height: 20)
                    Text("×\(t.fruitCount)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.appForeground)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.appGreenBg)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(h: 130, s: 25, l: 80), lineWidth: 1)
        )
        .cornerRadius(10)
    }

    private func lockedTreeCell(_ t: FarmOverview.FarmTree, isOwner: Bool) -> some View {
        HStack(spacing: 8) {
            AppImage(path: "/farm/tree_\(t.key).png", contentMode: .fit)
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(t.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.appForeground)
                    .lineLimit(1)
                Text(t.cost == 0 ? "免费领取" : "\(t.cost.formatted()) 积分")
                    .font(.system(size: 9))
                    .foregroundColor(.appMutedFg)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if isOwner && t.purchasable {
                Button {
                    Task { await vm.buyTree(idx: t.idx) }
                } label: {
                    Text(t.cost == 0 ? "领取" : "购买")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(t.canAfford ? Color.appPrimary : Color.clear)
                        .foregroundColor(t.canAfford ? Color.appPrimaryFg : Color.appPrimary)
                        .overlay(
                            Capsule().stroke(Color.appPrimary, lineWidth: t.canAfford ? 0 : 1)
                        )
                        .clipShape(Capsule())
                }
                .disabled(vm.buyingTree)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .opacity(0.7)
        .background(Color.appSecondary.opacity(0.2))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.appBorder, style: StrokeStyle(lineWidth: 1, dash: [5]))
        )
        .cornerRadius(10)
    }

    // MARK: - 操作行
    @ViewBuilder
    private func ownerRow(_ d: FarmOverview) -> some View {
        HStack(spacing: 12) {
            Button {
                Task { await vm.buyEgg() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "oval.fill")
                        .font(.system(size: 12))
                    Text(d.eggCount >= d.eggCap ? "鸡蛋已满（\(d.eggCap)）" : "买鸡蛋")
                        .font(.system(size: 13, weight: .medium))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.appPrimary)
                .foregroundColor(.appPrimaryFg)
                .cornerRadius(16)
            }
            .disabled(vm.buyingEgg || d.eggCount >= d.eggCap)
            .opacity(d.eggCount >= d.eggCap ? 0.6 : 1)

            if let rate = d.dailyRate {
                HStack(spacing: 4) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 10))
                        .foregroundColor(Color.appGreenFg)
                    Text(String(format: "当前日利率 %.2f%%", rate * 100))
                        .font(.system(size: 11))
                        .foregroundColor(.appMutedFg)
                }
            }

            Text("可用积分 \((d.available ?? 0).formatted())")
                .font(.system(size: 11))
                .foregroundColor(.appMutedFg)

            Spacer(minLength: 0)
        }
    }
}

// MARK: - ViewModel
@MainActor
final class FarmViewModel: ObservableObject {
    let userId: Int

    @Published var overview: FarmOverview? = nil
    @Published var loading = true
    @Published var buyingEgg = false
    @Published var buyingTree = false
    @Published var toggling = false
    /// farm.overview 不返回 farmPublic，本地跟踪开关状态（默认私密文案，与网页一致）
    @Published var farmPublic = false

    init(userId: Int) {
        self.userId = userId
    }

    func load() async {
        loading = true
        defer { loading = false }
        do {
            overview = try await MashanglingAPI.shared.farm.overview(userId: userId)
        } catch {
            // 静默失败，展示空态
        }
    }

    func buyEgg() async {
        guard !buyingEgg else { return }
        buyingEgg = true
        defer { buyingEgg = false }
        do {
            let r = try await MashanglingAPI.shared.points.buyEgg()
            ToastCenter.shared.success("🥚 第 \(r.eggCount) 颗蛋入手！")
            await load()
        } catch {
            ToastCenter.shared.error(error.localizedDescription)
        }
    }

    func buyTree(idx: Int) async {
        guard !buyingTree else { return }
        buyingTree = true
        defer { buyingTree = false }
        do {
            let r = try await MashanglingAPI.shared.farm.buyTree(treeIdx: idx)
            ToastCenter.shared.success("🌳 \(r.name) 种下了！")
            await load()
        } catch {
            ToastCenter.shared.error(error.localizedDescription)
        }
    }

    func toggleVisibility() async {
        guard !toggling else { return }
        toggling = true
        defer { toggling = false }
        do {
            let pub = try await MashanglingAPI.shared.points.toggleFarm()
            farmPublic = pub
            ToastCenter.shared.success(pub ? "农场已对外开放" : "农场已设为私密")
            await load()
        } catch {
            ToastCenter.shared.error(error.localizedDescription)
        }
    }
}
