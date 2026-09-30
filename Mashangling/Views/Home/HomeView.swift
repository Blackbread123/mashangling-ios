import SwiftUI

// MARK: - 首页（对应网页 Home.tsx）
struct HomeView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var vm = HomeViewModel()
    @State private var showSearch = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    // 全站积分播报细条
                    if !vm.ticker.isEmpty {
                        tickerBar
                    }

                    // 小 Tip 轮播条
                    tipBar

                    // 心选橱窗 / 我的农场 入口
                    HStack(spacing: 10) {
                        NavigationLink(destination: HeartShowcaseView()) {
                            entryCard(icon: "diamond.fill", title: "心选橱窗", badge: nil)
                        }
                        .buttonStyle(.plain)

                        NavigationLink(destination: FarmView(userId: authManager.currentUser?.id ?? 0)) {
                            entryCard(icon: "leaf.fill", title: "我的农场",
                                      badge: vm.farmRate.map { String(format: "%.2f%%", ($0.dailyRate ?? 0) * 100) })
                        }
                        .buttonStyle(.plain)
                        .disabled(!authManager.isAuthenticated)
                        .opacity(authManager.isAuthenticated ? 1 : 0.6)
                    }

                    // 模块化主页区域
                    HomeModulesView()

                    // 信息流
                    FeedView(showPlatformToggle: true)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
            .background(Color.appBackground)
            .navigationTitle("码上领")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 14) {
                        Button { showSearch = true } label: {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.appForeground)
                        }
                        // 网页 Header 右上角头像（点进个人主页）
                        if let me = authManager.currentUser {
                            NavigationLink(destination: ProfileView(userId: me.id)) {
                                AvatarView(path: me.avatar, name: me.name ?? "", size: 28)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .sheet(isPresented: $showSearch) { SearchView() }
            .onAppear { vm.onAppear(authed: authManager.isAuthenticated) }
            .refreshable { await vm.refresh(authed: authManager.isAuthenticated) }
        }
    }

    // 积分播报
    private var tickerBar: some View {
        let cur = vm.ticker[vm.tickerIdx % vm.ticker.count]
        return HStack(spacing: 6) {
            Image(systemName: "megaphone")
                .font(.system(size: 11))
                .foregroundColor(.appAmberIcon)
            Text(cur.name.prefix(8).description)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.appAmberFg)
                .lineLimit(1)
            Text("通过").font(.system(size: 11)).foregroundColor(.appAmberFg)
            Text(cur.label.prefix(20).description)
                .font(.system(size: 11))
                .foregroundColor(.appAmberFg)
                .lineLimit(1)
            Text("获得 ").font(.system(size: 11)).foregroundColor(.appAmberFg)
                + Text("+\(cur.delta)").font(.system(size: 11, weight: .bold)).foregroundColor(.appAmberFg)
                + Text(" 积分").font(.system(size: 11)).foregroundColor(.appAmberFg)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Color.appAmberBg)
        .cornerRadius(18)
        .overlay(Capsule().stroke(Color.appAmberBrd, lineWidth: 0.5))
    }

    // 小 Tip
    private var tipBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 11))
                .foregroundColor(.appEmeraldIcon)
                .frame(width: 24, height: 24)
                .background(Color.appEmeraldLight)
                .clipShape(Circle())
            HStack(spacing: 4) {
                Text("小 Tip").font(.system(size: 11, weight: .semibold)).foregroundColor(.appEmeraldFg)
                Text(HomeViewModel.tips[vm.tipIdx])
                    .font(.system(size: 11))
                    .foregroundColor(.appEmeraldFg)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 6).padding(.trailing, 14).padding(.vertical, 6)
        .background(Color.appEmeraldBg)
        .cornerRadius(18)
        .overlay(Capsule().stroke(Color.appEmeraldBrd, lineWidth: 0.5))
    }

    private func entryCard(icon: String, title: String, badge: String?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(.appPrimaryFg)
                .frame(width: 32, height: 32)
                .background(Color.appPrimary)
                .cornerRadius(8)
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.appForeground)
                .lineLimit(1)
            Spacer(minLength: 0)
            if let badge = badge {
                Text(badge)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.appSecondaryFg)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.appSecondary)
                    .cornerRadius(8)
                    .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Color.appCard)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appBorder, lineWidth: 0.5))
    }
}

// MARK: - 首页 ViewModel
@MainActor
class HomeViewModel: ObservableObject {
    static let tips = [
        "快递后台里长按某条寄件记录，可以删除它，或跳到「该用户寄件」专属页。",
        "不用韵达也能批量寄：快递后台点「导出菜鸟批量寄件」，去菜鸟发货平台上传表格一键下单。",
        "寄出后别忘了在对应记录点「已外部寄件」填单号，收件人会立刻收到通知。",
        "橱窗被领完不用下架，点「补码」就能继续发，橱窗卡片上会出现「补」徽标。",
        "在「设置」里填好默认寄件地址，快递后台会自动帮你预估每一笔邮费。",
        "限量橱窗领完后会自动显示「领完即止」，不用手动改库存。",
        "快递后台的记录太多？点「隐藏」收起已处理的，橱窗标题栏可以一键恢复。",
        "多逛逛感兴趣的橱窗，「猜你喜欢」会根据你的浏览记录越推越准。",
        "点「我想要」后记得在私信里和发布人确认邮费与发货时间。",
        "在快递后台点某条记录的状态筛选，可以只看未下单 / 已下单 / 已外部寄件。",
        "想要获取积分？来心选橱窗瓜分奖池吧：支持你看好的橱窗，它明天热度上升就能按投入权重分红。",
        "「心选橱窗」里每天都能给看好的橱窗投积分，次日上午 8 点结算，投中上涨的橱窗就能分走奖池大头。",
        "没有积分支持橱窗？每天签到、发橱窗、给别人的作品点赞返图都能攒，满 500 次浏览还能再换 1 积分。",
        "看好某个橱窗又怕押错？可以同时支持多个分散风险，只有押中上涨的那部分才会参与瓜分奖池。",
        "橱窗详情页点右上角「…」可以把橱窗作为礼物送给好友，对方免审批直接领取（限量名额照扣）。",
        "给橱窗设个「限时」，到期后自动停止领取，主页卡片和详情页都会显示失效时间。",
        "默认是婴儿蓝配色，想换风格？「个性化」页里可以切换雾灰、墨绿、雾粉主题，选择跟随账号，换设备也生效。",
    ]

    @Published var ticker: [PointsTickerRow] = []
    @Published var tickerIdx = 0
    @Published var tipIdx = Int.random(in: 0..<17)
    @Published var farmRate: FarmRate? = nil

    private var tipTimer: Timer?
    private var tickerTimer: Timer?

    func onAppear(authed: Bool) {
        tipIdx = Int.random(in: 0..<Self.tips.count)
        tipTimer?.invalidate()
        tipTimer = Timer.scheduledTimer(withTimeInterval: 6, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.tipIdx = (self.tipIdx + 1) % Self.tips.count
            }
        }
        Task { await refresh(authed: authed) }
    }

    func refresh(authed: Bool) async {
        do {
            let rows = try await MashanglingAPI.shared.points.ticker()
            ticker = rows
            if rows.count >= 2 {
                tickerTimer?.invalidate()
                tickerTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { [weak self] _ in
                    Task { @MainActor in self?.stepTicker() }
                }
            }
        } catch {}
        if authed {
            farmRate = try? await MashanglingAPI.shared.farm.myRate()
        }
    }

    private func stepTicker() {
        guard tickerIdx < ticker.count - 1 else { return }
        tickerIdx += 1
        tickerTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.stepTicker() }
        }
    }
}

// MARK: - 主页模块（对应网页 HomeModules.tsx，简化：入口卡片横排）
struct HomeModulesView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var selected: [String] = ["cardPlaza"]
    @State private var editing = false

    struct ModuleMeta: Identifiable {
        let key: String
        let label: String
        let icon: String
        var adminOnly: Bool = false
        var id: String { key }
    }

    private let modules: [ModuleMeta] = [
        ModuleMeta(key: "messages", label: "消息", icon: "envelope"),
        ModuleMeta(key: "claims", label: "领取申请", icon: "checkmark.rectangle"),
        ModuleMeta(key: "shipping", label: "快递后台", icon: "shippingbox"),
        ModuleMeta(key: "myShipments", label: "我的快递", icon: "cube.box"),
        ModuleMeta(key: "bookmarks", label: "我的清单", icon: "bookmark"),
        ModuleMeta(key: "history", label: "浏览记录", icon: "clock.arrow.circlepath"),
        ModuleMeta(key: "comments", label: "我的评论", icon: "text.bubble"),
        ModuleMeta(key: "points", label: "积分与等级", icon: "trophy"),
        ModuleMeta(key: "cards", label: "个性化", icon: "paintpalette"),
        ModuleMeta(key: "cardPlaza", label: "卡片广场", icon: "megaphone"),
        ModuleMeta(key: "settings", label: "设置", icon: "gearshape"),
        ModuleMeta(key: "adminReports", label: "举报处理", icon: "shield", adminOnly: true),
        ModuleMeta(key: "adminTags", label: "标签管理", icon: "tag", adminOnly: true),
    ]

    var body: some View {
        let isAdmin = authManager.currentUser?.isAdmin == true
        let visible = modules.filter { !$0.adminOnly || isAdmin }
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("快捷入口")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.appMutedFg)
                Spacer()
                Button(editing ? "完成" : "编辑") {
                    if editing { saveSelection() }
                    editing.toggle()
                }
                .font(.system(size: 12))
                .foregroundColor(.appPrimary)
            }

            if editing {
                // 编辑模式：全部模块多选
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(visible) { m in
                        Button {
                            if selected.contains(m.key) {
                                selected.removeAll { $0 == m.key }
                            } else {
                                selected.append(m.key)
                            }
                        } label: {
                            moduleCell(m, checked: selected.contains(m.key))
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                // 展示模式：已选模块
                let chosen = visible.filter { selected.contains($0.key) }
                if chosen.isEmpty {
                    Text("点右上角「编辑」添加主页模块")
                        .font(.system(size: 12))
                        .foregroundColor(.appMutedFg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(chosen) { m in
                            NavigationLink(destination: destination(for: m.key)) {
                                moduleCell(m, checked: false)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .onAppear { loadSelection() }
    }

    private func moduleCell(_ m: ModuleMeta, checked: Bool) -> some View {
        VStack(spacing: 5) {
            Image(systemName: m.icon)
                .font(.system(size: 16))
                .foregroundColor(checked ? .appPrimaryFg : .appPrimary)
                .frame(width: 36, height: 36)
                .background(checked ? Color.appPrimary : Color.appSecondary)
                .cornerRadius(10)
            Text(m.label)
                .font(.system(size: 10))
                .foregroundColor(.appForeground)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.appCard)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(checked ? Color.appPrimary : Color.appBorder, lineWidth: 0.5))
    }

    @ViewBuilder
    private func destination(for key: String) -> some View {
        switch key {
        case "messages":     AnyView(MessagesView())
        case "claims":       AnyView(ClaimsView())
        case "shipping":     AnyView(ShippingView())
        case "myShipments":  AnyView(MyShipmentsView())
        case "bookmarks":    AnyView(BookmarksView())
        case "history":      AnyView(BrowseHistoryView())
        case "comments":     AnyView(MyCommentsView())
        case "points":       AnyView(PointsView())
        case "cards":        AnyView(CardStudioView())
        case "cardPlaza":    AnyView(CardPlazaView())
        case "settings":     AnyView(SettingsView())
        case "adminReports": AnyView(AdminView())
        case "adminTags":    AnyView(AdminTagsView())
        default:             AnyView(EmptyView())
        }
    }

    private func loadSelection() {
        // 本地缓存
        if let raw = UserDefaults.standard.string(forKey: "msl-home-modules"),
           let arr = try? JSONDecoder().decode([String].self, from: Data(raw.utf8)) {
            selected = arr
        }
        // 服务端覆盖（跨设备）
        Task {
            if let d = try? await MashanglingAPI.shared.settings.getHomeModules(),
               let json = d.homeModules,
               let arr = try? JSONDecoder().decode([String].self, from: Data(json.utf8)) {
                selected = arr
            }
        }
    }

    private func saveSelection() {
        guard let data = try? JSONEncoder().encode(selected),
              let json = String(data: data, encoding: .utf8) else { return }
        UserDefaults.standard.set(json, forKey: "msl-home-modules")
        Task {
            _ = try? await MashanglingAPI.shared.settings.updateHomeModules(json)
        }
    }
}
