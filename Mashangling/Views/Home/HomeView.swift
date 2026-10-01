import SwiftUI

// MARK: - 首页（逐行复刻网页 Home.tsx + Header.tsx + HomeModules.tsx + Footer.tsx）
struct HomeView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var vm = HomeViewModel()
    @StateObject private var unreadManager = UnreadManager.shared
    @State private var mobileSearch = false
    @State private var searchInput = ""
    @State private var pushSearch = false
    @State private var showAvatarMenu = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 0) {
                    // 移动端搜索条（网页：点搜索图标在顶栏下方展开，border-t px-4 pb-3 pt-2）
                    if mobileSearch {
                        HStack(spacing: 0) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16))
                                .foregroundColor(.appMutedFg)
                                .padding(.leading, 14)
                            TextField("搜索无料码 / 发布人 / 关键词…", text: $searchInput)
                                .font(.system(size: 16)) // iOS：≥16px 聚焦不自动放大
                                .autocapitalization(.none)
                                .padding(.leading, 8)
                                .onSubmit { submitSearch() }
                        }
                        .frame(height: 40)
                        .background(Color.appCard)
                        .overlay(Capsule().stroke(Color.appInput, lineWidth: 0.5))
                        .clipShape(Capsule())
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                        .background(Color.appBackground)
                        .overlay(alignment: .top) {
                            Rectangle().fill(Color.appBorder.opacity(0.6)).frame(height: 0.5)
                        }
                    }

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 16) {
                            // 全站积分播报细条
                            if !vm.ticker.isEmpty {
                                tickerBar
                            }
                            // 小 Tip 轮播条
                            tipBar.padding(.top, -4)
                            // 心选橱窗 / 我的农场
                            entryCards
                            // 模块化主页区域
                            HomeModulesView()
                                .padding(.top, 8)
                            // 信息流
                            FeedView(showPlatformToggle: true)
                                .padding(.top, 8)
                            // 页脚
                            FooterView()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                        .padding(.bottom, 24)
                    }
                    .refreshable { await vm.refresh(authed: authManager.isAuthenticated) }
                }
                .background(Color.appBackground)

                // 头像下拉菜单（网页 DropdownMenu）
                if showAvatarMenu {
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .onTapGesture { showAvatarMenu = false }
                    AvatarMenuPanel(close: { showAvatarMenu = false })
                        .padding(.top, 44)
                        .padding(.trailing, 8)
                        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topTrailing)))
                        .zIndex(1)
                }
            }
            .animation(.easeOut(duration: 0.15), value: showAvatarMenu)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 8) {
                        Text("码上领")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.appForeground)
                        // 裸搜索图标（网页：logo 右边，h-9 w-9 rounded-full 无底色）
                        Button {
                            withAnimation(.easeOut(duration: 0.15)) { mobileSearch.toggle() }
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 20))
                                .foregroundColor(.appMutedFg)
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    // 头像 + 未读角标，点出下拉菜单
                    if let me = authManager.currentUser {
                        Button { showAvatarMenu.toggle() } label: {
                            // 网页：外层 relative 不裁切，角标露出圆圈右上角
                            ZStack(alignment: .topTrailing) {
                                AvatarView(path: me.avatar, name: me.name ?? "U", size: 36)
                                if unreadManager.totalUnread > 0 {
                                    Text(unreadManager.totalUnread > 99 ? "99+" : "\(unreadManager.totalUnread)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.appPrimaryFg)
                                        .padding(.horizontal, 4)
                                        .frame(height: 16)
                                        .background(Color.appPrimary)
                                        .cornerRadius(8)
                                        .overlay(Capsule().stroke(Color.appBackground, lineWidth: 2))
                                        .offset(x: 6, y: -6)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                            NavigationLink(destination: LoginView()) {
                                HStack(spacing: 4) {
                                    Image(systemName: "person").font(.system(size: 14))
                                    Text("登录 / 注册").font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(.appPrimaryFg)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(Color.appPrimary)
                                .cornerRadius(18)
                            }
                            .buttonStyle(.plain)
                        }
                }
            }
            .navigationDestination(isPresented: $pushSearch) {
                SearchView(initialQuery: searchInput)
            }
            .onAppear { vm.onAppear(authed: authManager.isAuthenticated) }
        }
    }

    private func submitSearch() {
        let q = searchInput.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        mobileSearch = false
        pushSearch = true
    }

    // 积分播报（网页 PointsTicker：amber 细条）
    private var tickerBar: some View {
        let cur = vm.ticker[vm.tickerIdx % vm.ticker.count]
        return HStack(spacing: 6) {
            Image(systemName: "megaphone")
                .font(.system(size: 11))
                .foregroundColor(.appAmberIcon)
            Text(String(cur.name.prefix(8)))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.appAmberFg)
                .lineLimit(1)
            Text("通过").font(.system(size: 12)).foregroundColor(.appAmberFg)
            Text(String(cur.label.prefix(20)))
                .font(.system(size: 12))
                .foregroundColor(.appAmberFg)
                .lineLimit(1)
            Text("获得 ").font(.system(size: 12)).foregroundColor(.appAmberFg)
                + Text("+\(cur.delta)").font(.system(size: 12, weight: .bold)).foregroundColor(.appAmberFg)
                + Text(" 积分").font(.system(size: 12)).foregroundColor(.appAmberFg)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Color.appAmberBg.opacity(0.8))
        .cornerRadius(20)
        .overlay(Capsule().stroke(Color.appAmberBrd.opacity(0.7), lineWidth: 0.5))
    }

    // 小 Tip（网页：rounded-full border-emerald-200 bg-emerald-50/80 py-1.5 pl-2 pr-4）
    private var tipBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 12))
                .foregroundColor(.appEmeraldIcon)
                .frame(width: 24, height: 24)
                .background(Color.appEmeraldLight)
                .clipShape(Circle())
            HStack(spacing: 6) {
                Text("小 Tip").font(.system(size: 12, weight: .semibold)).foregroundColor(.appEmeraldFg)
                Text(HomeViewModel.tips[vm.tipIdx])
                    .font(.system(size: 12))
                    .foregroundColor(.appEmeraldFg)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 8).padding(.trailing, 16).padding(.vertical, 6)
        .background(Color.appEmeraldBg)
        .cornerRadius(20)
        .overlay(Capsule().stroke(Color.appEmeraldBrd, lineWidth: 0.5))
    }

    // 心选橱窗 / 我的农场（网页：grid-cols-2 gap-3，rounded-2xl border px-3 py-2.5）
    private var entryCards: some View {
        HStack(spacing: 12) {
            NavigationLink(destination: HeartShowcaseView()) {
                entryCard(icon: "diamond.fill", title: "心选橱窗", badge: nil)
            }
            .buttonStyle(.plain)

            NavigationLink(destination: ProfileView(userId: authManager.currentUser?.id ?? 0)) {
                entryCard(icon: "leaf.fill", title: "我的农场",
                          badge: vm.farmRate.map { String(format: "%.2f%%", ($0.dailyRate ?? 0) * 100) })
            }
            .buttonStyle(.plain)
            .disabled(!authManager.isAuthenticated)
            .opacity(authManager.isAuthenticated ? 1 : 0.6)
        }
    }

    private func entryCard(icon: String, title: String, badge: String?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.appPrimaryFg)
                .frame(width: 32, height: 32)
                .background(Color.appPrimary)
                .cornerRadius(3)
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.appForeground)
                .lineLimit(1)
            Spacer(minLength: 0)
            if let badge = badge {
                Text(badge)
                    .font(.system(size: 10, weight: .semibold))
                    .monospacedDigit()
                    .foregroundColor(.appSecondaryFg)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.appSecondary)
                    .cornerRadius(10)
                    .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Color.appCard)
        .cornerRadius(5)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appBorder, lineWidth: 0.5))
    }
}

// MARK: - 头像下拉菜单（复刻网页 Header.tsx DropdownMenuContent，w-44）
struct AvatarMenuPanel: View {
    var close: () -> Void
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var unreadManager = UnreadManager.shared
    @State private var pendingFee = 0
    @State private var approvals = 0

    struct Row: Identifiable {
        let id = UUID()
        let icon: String
        let label: String
        var badge: Int = 0
        var badgeColor: BadgeColor = .primary
        let dest: Dest
    }
    enum BadgeColor { case primary, amber, red }
    enum Dest {
        case profile, editModules, messages, claims, bookmarks, history, comments
        case points, pointRecords, shop, cards, cardPlaza, settings
        case myShipments, shipping, admin, adminTags, logout
    }

    var body: some View {
        let me = authManager.currentUser
        var rows: [Row] = [
            Row(icon: "square.grid.2x2", label: "我的主页", dest: .profile),
            Row(icon: "slider.horizontal.3", label: "编辑主页模块", dest: .editModules),
            Row(icon: "envelope", label: "消息", badge: unreadManager.totalUnread, dest: .messages),
            Row(icon: "checklist", label: "领取申请", dest: .claims),
            Row(icon: "bookmark", label: "我的清单", dest: .bookmarks),
            Row(icon: "clock.arrow.circlepath", label: "浏览记录", dest: .history),
            Row(icon: "text.bubble", label: "我的评论", dest: .comments),
            Row(icon: "trophy", label: "积分与等级", dest: .points),
            Row(icon: "doc.text", label: "积分记录", dest: .pointRecords),
            Row(icon: "bag", label: "积分商城", dest: .shop),
            Row(icon: "paintpalette", label: "个性化", dest: .cards),
            Row(icon: "megaphone", label: "卡片广场", dest: .cardPlaza),
            Row(icon: "gearshape", label: "设置", dest: .settings),
            Row(icon: "cube.box", label: "我的快递", badge: pendingFee, badgeColor: .amber, dest: .myShipments),
            Row(icon: "box.truck", label: "快递后台", badge: approvals, badgeColor: .red, dest: .shipping),
        ]
        if me?.isAdmin == true {
            rows.append(Row(icon: "checkmark.shield", label: "管理后台", dest: .admin))
            rows.append(Row(icon: "tag", label: "标签管理", dest: .adminTags))
        }

        return VStack(spacing: 2) {
            ForEach(rows) { row in
                menuRow(row)
            }
            Divider().padding(.vertical, 4)
            Button {
                close()
                Task { await AuthManager.shared.logout() }
            } label: {
                rowLabel(icon: "rectangle.portrait.and.arrow.right", label: "退出登录", badge: 0, badgeColor: .primary)
            }
            .buttonStyle(.plain)
        }
        .padding(4)
        .frame(width: 176)
        .background(Color.appCard)
        .cornerRadius(2)
        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.appBorder, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        .onAppear {
            Task {
                let b = try? await MashanglingAPI.shared.address.navBadges()
                pendingFee = b?.pendingFeeCount ?? 0
                approvals = b?.approvalCount ?? 0
            }
        }
    }

    @ViewBuilder
    private func menuRow(_ row: Row) -> some View {
        if row.dest == .editModules {
            Button {
                close()
                NotificationCenter.default.post(name: .mslOpenHomeModulesEditor, object: nil)
            } label: {
                rowLabel(icon: row.icon, label: row.label, badge: row.badge, badgeColor: row.badgeColor)
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(destination: destination(row.dest)) {
                rowLabel(icon: row.icon, label: row.label, badge: row.badge, badgeColor: row.badgeColor)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture().onEnded { close() })
        }
    }

    private func rowLabel(icon: String, label: String, badge: Int, badgeColor: BadgeColor) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.appForeground)
                .frame(width: 16)
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.appForeground)
            Spacer(minLength: 0)
            if badge > 0 {
                Text(badge > 99 ? "99+" : "\(badge)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(badgeColor == .amber ? Color.twAmber500 :
                                badgeColor == .red ? Color.appDestructive : Color.appPrimary)
                    .cornerRadius(10)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func destination(_ d: Dest) -> some View {
        switch d {
        case .profile:      ProfileView(userId: authManager.currentUser?.id ?? 0)
        case .messages:     MessagesView()
        case .claims:       ClaimsView()
        case .bookmarks:    BookmarksView()
        case .history:      BrowseHistoryView()
        case .comments:     MyCommentsView()
        case .points:       PointsView()
        case .pointRecords: PointRecordsView()
        case .shop:         ShopView()
        case .cards:        CardStudioView()
        case .cardPlaza:    CardPlazaView()
        case .settings:     SettingsView()
        case .myShipments:  MyShipmentsView()
        case .shipping:     ShippingView()
        case .admin:        AdminView()
        case .adminTags:    AdminTagsView()
        default:            EmptyView()
        }
    }
}

extension Notification.Name {
    static let mslOpenHomeModulesEditor = Notification.Name("mslOpenHomeModulesEditor")
    static let mslSwitchTab = Notification.Name("mslSwitchTab")
}

// MARK: - 页脚（复刻网页 Footer.tsx）
struct FooterView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("码上领 · 无料橱窗")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.appForeground)
            HStack(spacing: 6) {
                Image(systemName: "message")
                    .font(.system(size: 12))
                Text("制作者 / 问题反馈：QQ 3495379352")
                    .font(.system(size: 12))
            }
            .foregroundColor(.appMutedFg)
            Text("站内橱窗内容由用户发布，领取无料通常需自付制作与邮费，请以分享者说明为准。")
                .font(.system(size: 11))
                .foregroundColor(.appMutedFg.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.appBorder.opacity(0.7)).frame(height: 0.5)
        }
        .padding(.top, 64)
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

// MARK: - 主页模块（逐行复刻网页 HomeModules.tsx）
// 结构：数据看板（可选）→ 记录类模块（消息/领取申请/快递后台，各显最新两条）→
//       入口类模块（两列小卡片）→ 卡片广场横幅；编辑通过头像菜单「编辑主页模块」打开。
struct HomeModulesView: View {
    @EnvironmentObject var authManager: AuthManager

    struct ModuleMeta: Identifiable {
        let key: String
        let label: String
        let icon: String
        let kind: Kind
        var adminOnly: Bool = false
        var id: String { key }
        enum Kind { case dashboard, records, entry, cardPlaza }
    }

    // 顺序与网页 MODULES 一致
    private let modules: [ModuleMeta] = [
        ModuleMeta(key: "dashboard", label: "数据看板", icon: "chart.bar", kind: .dashboard),
        ModuleMeta(key: "messages", label: "消息", icon: "envelope", kind: .records),
        ModuleMeta(key: "claims", label: "领取申请", icon: "checklist", kind: .records),
        ModuleMeta(key: "shipping", label: "快递后台", icon: "box.truck", kind: .records),
        ModuleMeta(key: "myShipments", label: "我的快递", icon: "cube.box", kind: .entry),
        ModuleMeta(key: "profile", label: "我的主页", icon: "square.grid.2x2", kind: .entry),
        ModuleMeta(key: "bookmarks", label: "我的清单", icon: "bookmark", kind: .entry),
        ModuleMeta(key: "history", label: "浏览记录", icon: "clock.arrow.circlepath", kind: .entry),
        ModuleMeta(key: "comments", label: "我的评论", icon: "text.bubble", kind: .entry),
        ModuleMeta(key: "points", label: "积分与等级", icon: "trophy", kind: .entry),
        ModuleMeta(key: "cards", label: "个性化", icon: "paintpalette", kind: .entry),
        ModuleMeta(key: "cardPlaza", label: "卡片广场", icon: "megaphone", kind: .cardPlaza),
        ModuleMeta(key: "settings", label: "设置", icon: "gearshape", kind: .entry),
        ModuleMeta(key: "adminReports", label: "举报处理", icon: "checkmark.shield", kind: .entry, adminOnly: true),
        ModuleMeta(key: "adminTags", label: "标签管理", icon: "tag", kind: .entry, adminOnly: true),
    ]

    @State private var selected: [String] = ["cardPlaza"]
    @State private var editing = false
    @State private var draft: Set<String> = []

    // 角标
    @State private var unreadCount = 0
    @State private var approvalCount = 0
    @State private var pendingFeeCount = 0

    // 最新两条记录
    @State private var latestMessages: [MessageRow] = []
    @State private var latestClaims: [ClaimRow] = []
    @State private var latestShipments: [(item: ShipItem, title: String)] = []

    var body: some View {
        let isAdmin = authManager.currentUser?.isAdmin == true
        let visible = modules.filter { !$0.adminOnly || isAdmin }
        let ordered = visible.filter { selected.contains($0.key) }
        let recordModules = ordered.filter { $0.kind == .records }
        let entryModules = ordered.filter { $0.kind == .entry }

        VStack(alignment: .leading, spacing: 0) {
            // 数据看板模块
            if authManager.isAuthenticated && selected.contains("dashboard") {
                StatsDashboardView()
            }

            // 记录类模块：单列，gap-4
            if !recordModules.isEmpty {
                VStack(spacing: 16) {
                    ForEach(recordModules) { m in
                        recordCard(m)
                    }
                }
                .padding(.top, 24)
            }

            // 入口类模块：两列，gap-3
            if !entryModules.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(entryModules) { m in
                        NavigationLink(destination: destination(for: m.key)) {
                            entryCell(m)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 24)
            }

            // 卡片广场横幅
            if selected.contains("cardPlaza") {
                NavigationLink(destination: CardPlazaView()) {
                    HStack(spacing: 12) {
                        Image(systemName: "megaphone")
                            .font(.system(size: 20))
                            .foregroundColor(.appPrimary)
                            .frame(width: 44, height: 44)
                            .background(Color.appPrimary.opacity(0.1))
                            .cornerRadius(4)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("卡片广场")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.appForeground)
                            Text("看看大家设计的个性化分享卡片，喜欢就点赞评论，蹲一张同款")
                                .font(.system(size: 12))
                                .foregroundColor(.appMutedFg)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16))
                            .foregroundColor(.appMutedFg)
                    }
                    .padding(16)
                    .background(
                        LinearGradient(colors: [Color.appPrimary.opacity(0.08), Color.appPrimary.opacity(0.04), Color.clear],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .background(Color.appCard)
                    .cornerRadius(5)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appBorder, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .padding(.top, 24)
            }
        }
        .onAppear {
            loadSelection()
        }
        .onReceive(NotificationCenter.default.publisher(for: .mslOpenHomeModulesEditor)) { _ in
            draft = Set(selected)
            editing = true
        }
        .sheet(isPresented: $editing) { editorSheet(visible: visible) }
    }

    // MARK: 记录类模块卡（网页：rounded-2xl border bg-card p-4）
    private func recordCard(_ m: ModuleMeta) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 头部：图标 + 标题 + 红色角标 + 查看全部
            HStack(spacing: 6) {
                Image(systemName: m.icon)
                    .font(.system(size: 14))
                    .foregroundColor(.appPrimary)
                Text(m.label)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.appForeground)
                let badge = badgeOf(m.key)
                if badge > 0 {
                    Text(badge > 99 ? "99+" : "\(badge)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.appDestructive)
                        .cornerRadius(10)
                }
                Spacer(minLength: 0)
                NavigationLink(destination: destination(for: m.key)) {
                    HStack(spacing: 2) {
                        Text("查看全部")
                            .font(.system(size: 12))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.appMutedFg)
                }
                .buttonStyle(.plain)
            }

            // 记录列表：mt-3 space-y-2
            VStack(spacing: 8) {
                switch m.key {
                case "messages": messagesRows
                case "claims": claimsRows
                case "shipping": shippingRows
                default: EmptyView()
                }
            }
            .padding(.top, 12)
        }
        .padding(16)
        .background(Color.appCard)
        .cornerRadius(5)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appBorder, lineWidth: 0.5))
    }

    // 消息最新两条（网页：未读圆点 + 标题 + 时间；来自 xxx）
    @ViewBuilder
    private var messagesRows: some View {
        if latestMessages.isEmpty {
            Text("暂无消息")
                .font(.system(size: 12))
                .foregroundColor(.appMutedFg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        } else {
            ForEach(latestMessages) { msg in
                NavigationLink(destination: MessagesView()) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            if !msg.read {
                                Circle().fill(Color.appPrimary).frame(width: 6, height: 6)
                            }
                            Text(msg.title)
                                .font(.system(size: 12, weight: msg.read ? .regular : .semibold))
                                .foregroundColor(.appForeground)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text(DateFmt.short(msg.createdAt))
                                .font(.system(size: 10))
                                .foregroundColor(.appMutedFg)
                        }
                        if let from = msg.fromUserName, !from.isEmpty {
                            Text("来自 \(from)")
                                .font(.system(size: 11))
                                .foregroundColor(.appMutedFg)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder.opacity(0.6), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // 领取申请最新两条（网页：名字 申请「标题」+ 状态胶囊；时间）
    @ViewBuilder
    private var claimsRows: some View {
        if latestClaims.isEmpty {
            Text("暂无领取申请")
                .font(.system(size: 12))
                .foregroundColor(.appMutedFg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        } else {
            ForEach(latestClaims) { c in
                NavigationLink(destination: ClaimsView()) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            (Text(c.applicantName ?? "用户").font(.system(size: 12, weight: .medium)) +
                             Text(" 申请「\(c.showcaseTitle ?? "")」").font(.system(size: 12)))
                                .foregroundColor(.appForeground)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            claimPill(c.status ?? "")
                        }
                        Text(DateFmt.short(c.createdAt))
                            .font(.system(size: 11))
                            .foregroundColor(.appMutedFg)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder.opacity(0.6), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func claimPill(_ status: String) -> some View {
        let text = status == "pending" ? "待审核" : status == "approved" ? "已通过" : "已拒绝"
        let bg = status == "pending" ? Color.twAmber100 : status == "approved" ? Color.twEmerald100 : Color.appSecondary
        let fg = status == "pending" ? Color.twAmber700 : status == "approved" ? Color.twEmerald700 : Color.appMutedFg
        return Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(fg)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(bg)
            .cornerRadius(10)
    }

    // 快递后台最新两条（网页：昵称 + 状态胶囊；橱窗标题 · 时间）
    @ViewBuilder
    private var shippingRows: some View {
        if latestShipments.isEmpty {
            Text("暂无寄件记录")
                .font(.system(size: 12))
                .foregroundColor(.appMutedFg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        } else {
            ForEach(latestShipments, id: \.item.id) { pair in
                NavigationLink(destination: ShippingView()) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(pair.item.nickname.isEmpty ? "收件人" : pair.item.nickname)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.appForeground)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            shipPill(pair.item)
                        }
                        Text("\(pair.title) · \(DateFmt.short(pair.item.createdAt))")
                            .font(.system(size: 11))
                            .foregroundColor(.appMutedFg)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder.opacity(0.6), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // 网页 shipStatusOf 的配色逐条一致
    private func shipPill(_ a: ShipItem) -> some View {
        let text = a.stateText
        var bg = Color.appSecondary, fg = Color.appMutedFg
        if a.shipState == "cancelled" { bg = .appBrand100; fg = .appBrand600 }
        else if a.shipState == "external" { bg = .twViolet100; fg = .twViolet700 }
        else if a.shipState == "preorder" { bg = .twSky100; fg = .twSky700 }
        else if text == "已下单" { bg = .twEmerald100; fg = .twEmerald700 }
        return Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(fg)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(bg)
            .cornerRadius(10)
    }

    // MARK: 入口类模块（网页：rounded-2xl border bg-card px-4 py-3，图标 32 圆角 12 主色 10% 底）
    private func entryCell(_ m: ModuleMeta) -> some View {
        HStack(spacing: 10) {
            Image(systemName: m.icon)
                .font(.system(size: 16))
                .foregroundColor(.appPrimary)
                .frame(width: 32, height: 32)
                .background(Color.appPrimary.opacity(0.1))
                .cornerRadius(4)
            Text(m.label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.appForeground)
                .lineLimit(1)
            Spacer(minLength: 0)
            let badge = badgeOf(m.key)
            if badge > 0 {
                Text(badge > 99 ? "99+" : "\(badge)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.twAmber500)
                    .cornerRadius(10)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.appMutedFg)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color.appCard)
        .cornerRadius(5)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appBorder, lineWidth: 0.5))
    }

    // MARK: 编辑备选栏（网页 Dialog：两列多选 + 保存）
    private func editorSheet(visible: [ModuleMeta]) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("勾选要显示在主页的模块，可多选，保存后生效（仅自己可见）。")
                        .font(.system(size: 12))
                        .foregroundColor(.appMutedFg)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        ForEach(visible) { m in
                            let on = draft.contains(m.key)
                            Button {
                                if on { draft.remove(m.key) } else { draft.insert(m.key) }
                            } label: {
                                HStack(spacing: 8) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 2)
                                            .stroke(on ? Color.appPrimary : Color.appBorder, lineWidth: 1)
                                            .frame(width: 16, height: 16)
                                        if on {
                                            RoundedRectangle(cornerRadius: 2).fill(Color.appPrimary).frame(width: 16, height: 16)
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(.appPrimaryFg)
                                        }
                                    }
                                    Image(systemName: m.icon)
                                        .font(.system(size: 14))
                                        .foregroundColor(on ? .appForeground : .appMutedFg)
                                    Text(m.label)
                                        .font(.system(size: 14, weight: on ? .medium : .regular))
                                        .foregroundColor(on ? .appForeground : .appMutedFg)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 10)
                                .background(on ? Color.appPrimary.opacity(0.05) : Color.clear)
                                .cornerRadius(4)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(on ? Color.appPrimary : Color.appBorder, lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    HStack {
                        Text("「消息 / 领取申请 / 快递后台」会显示最新两条记录，其余为跳转入口")
                            .font(.system(size: 11))
                            .foregroundColor(.appMutedFg)
                        Spacer(minLength: 0)
                        Button("保存") { save() }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.appPrimaryFg)
                            .padding(.horizontal, 16).padding(.vertical, 7)
                            .background(Color.appPrimary)
                            .cornerRadius(18)
                    }
                    .padding(.top, 4)
                }
                .padding(16)
            }
            .background(Color.appBackground)
            .navigationTitle("编辑主页模块")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { editing = false } label: {
                        Image(systemName: "xmark").foregroundColor(.appMutedFg)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func badgeOf(_ key: String) -> Int {
        switch key {
        case "messages": return unreadCount
        case "shipping": return approvalCount
        case "myShipments": return pendingFeeCount
        default: return 0
        }
    }

    @ViewBuilder
    private func destination(for key: String) -> some View {
        switch key {
        case "messages":     AnyView(MessagesView())
        case "claims":       AnyView(ClaimsView())
        case "shipping":     AnyView(ShippingView())
        case "myShipments":  AnyView(MyShipmentsView())
        case "profile":      AnyView(ProfileView(userId: authManager.currentUser?.id ?? 0))
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
        if let raw = UserDefaults.standard.string(forKey: "msl-home-modules"),
           let arr = try? JSONDecoder().decode([String].self, from: Data(raw.utf8)) {
            selected = arr
        }
        Task {
            if let d = try? await MashanglingAPI.shared.settings.getHomeModules(),
               let json = d.homeModules,
               let arr = try? JSONDecoder().decode([String].self, from: Data(json.utf8)) {
                selected = arr
            }
            await loadBadgesAndRecords()
        }
    }

    private func loadBadgesAndRecords() async {
        let sel = Set(selected)
        let needBadges = sel.contains("messages") || sel.contains("shipping") || sel.contains("myShipments")
        if needBadges {
            unreadCount = (try? await MashanglingAPI.shared.message.unreadCount()) ?? 0
            let b = try? await MashanglingAPI.shared.address.navBadges()
            approvalCount = b?.approvalCount ?? 0
            pendingFeeCount = b?.pendingFeeCount ?? 0
        }
        if sel.contains("messages") {
            latestMessages = Array(((try? await MashanglingAPI.shared.message.list(type: "all")) ?? []).prefix(2))
        }
        if sel.contains("claims") {
            latestClaims = Array(((try? await MashanglingAPI.shared.claim.received()) ?? []).prefix(2))
        }
        if sel.contains("shipping") {
            if let board = try? await MashanglingAPI.shared.address.shippingBoard() {
                latestShipments = Array(board.groups
                    .flatMap { g in g.items.map { (item: $0, title: g.title) } }
                    .sorted { (DateFmt.parse($0.item.createdAt) ?? .distantPast) > (DateFmt.parse($1.item.createdAt) ?? .distantPast) }
                    .prefix(2))
            }
        }
    }

    private func save() {
        let next = modules.map { $0.key }.filter { draft.contains($0) }
        selected = next
        guard let data = try? JSONEncoder().encode(next),
              let json = String(data: data, encoding: .utf8) else { return }
        UserDefaults.standard.set(json, forKey: "msl-home-modules")
        Task {
            _ = try? await MashanglingAPI.shared.settings.updateHomeModules(json)
            await loadBadgesAndRecords()
        }
        editing = false
    }
}
