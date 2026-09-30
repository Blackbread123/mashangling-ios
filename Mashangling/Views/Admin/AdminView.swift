import SwiftUI

// MARK: - 管理后台（复刻 Admin.tsx）

private func formatCompact(_ n: Int) -> String {
    if n < 1000 { return "\(n)" }
    let (suffix, div): (String, Double) = n >= 1_000_000 ? ("m", 1e6) : ("k", 1e3)
    var s = String(format: "%.2f", Double(n) / div)
    while s.hasSuffix("0") { s.removeLast() }
    if s.hasSuffix(".") { s.removeLast() }
    return s + suffix
}

struct AdminView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var reports: [ReportRow]?
    @State private var stats: AdminStats?
    @State private var heartPool: HeartPoolAdmin?
    @State private var growthPeriod = "week"
    @State private var growth: AdminGrowthTrend?
    @State private var growthHidden: Set<String> = []
    @State private var recentUsers: [AdminUser] = []
    @State private var searchId = ""
    @State private var queriedUser: AdminUser?
    @State private var queryError: String?
    @State private var opinionOpen: Int?
    @State private var opinion = ""
    @State private var busy = false

    private var isAdmin: Bool { authManager.currentUser?.role == "admin" }
    private var isSuper: Bool { authManager.currentUser?.superAdmin == true }

    private static let growthMetrics: [(key: String, label: String, color: Color)] = [
        ("newUsers", "新注册", Color(h: 262, s: 83, l: 58)),
        ("newShowcases", "新发橱窗", Color(h: 337, s: 80, l: 61)),
        ("heartPool", "心选奖池", Color(h: 38, s: 92, l: 50)),
        ("pageViews", "页面浏览", Color(h: 205, s: 60, l: 52)),
    ]

    private static let typeLabel: [String: String] = [
        "showcase": "橱窗", "cardPost": "卡片", "repost": "返图",
        "cardComment": "卡片评论", "dm": "私信", "tag": "标签",
    ]
    private static let banTypes: Set<String> = ["repost", "cardComment", "dm"]

    var body: some View {
        Group {
            if !isAdmin {
                Text("需要管理员权限")
                    .font(.system(size: 13)).foregroundStyle(Color.appMutedFg)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                content
            }
        }
        .navigationTitle("管理后台")
        .background(Color.appBackground)
        .task { await load() }
        .refreshable { await load() }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    HStack(spacing: 8) {
                        Text("管理后台").font(.system(size: 22, weight: .bold))
                        if isSuper {
                            Text("主管理员")
                                .font(.system(size: 11, weight: .medium)).foregroundStyle(Color.appPrimaryFg)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(Color.appPrimary).clipShape(Capsule())
                        }
                    }
                    Spacer()
                    NavigationLink("标签管理 →") { AdminTagsView() }
                        .font(.system(size: 14)).foregroundStyle(Color.appMutedFg)
                }

                // 站点统计
                statGrid.padding(.top, 20)
                growthCard.padding(.top, 16)

                if isSuper {
                    if !recentUsers.isEmpty {
                        recentUsersCard.padding(.top, 16)
                    }
                    roleCard.padding(.top, 16)
                }

                // 举报列表
                if let reports {
                    if reports.isEmpty {
                        Text(isSuper ? "暂无举报" : "暂无分派给你的举报")
                            .font(.system(size: 13)).foregroundStyle(Color.appMutedFg)
                            .frame(maxWidth: .infinity).padding(.vertical, 56)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 1, dash: [6])))
                            .padding(.top, 24)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(reports) { r in
                                reportCard(r)
                            }
                        }
                        .padding(.top, 24)
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: 统计卡片

    private var statGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard("注册人数", value: stats?.totalUsers,
                     sub: stats.map { "今日 +\($0.todayUsers ?? 0)" })
            statCard("在架橱窗", value: stats?.totalShowcases,
                     sub: stats.map { "今日 +\($0.todayShowcases ?? 0)（不含已删除）" })
            statCard("总浏览量", value: stats?.totalPageViews,
                     sub: stats.map { "今日 +\($0.todayPageViews ?? 0)（网页打开次数）" })
            statCard("心选奖池（今日）", value: heartPool?.total,
                     sub: heartPool.map { "今日投入 \($0.todaySupport ?? 0) · 上期结转 \($0.carryIn ?? 0)" },
                     action: AnyView(
                Button(busy ? "结算中…" : "手动结算") { Task { await settleHeart() } }
                    .font(.system(size: 11)).foregroundStyle(Color.appMutedFg)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .overlay(Capsule().stroke(Color.appBorder, lineWidth: 1))
                    .disabled(busy)
            ))
        }
    }

    private func statCard(_ label: String, value: Int?, sub: String?, action: AnyView? = nil) -> some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label).font(.system(size: 12)).foregroundStyle(Color.appMutedFg)
                Text(value.map { formatCompact($0) } ?? "—")
                    .font(.system(size: 24, weight: .bold)).monospacedDigit()
                if let sub {
                    Text(sub).font(.system(size: 11)).foregroundStyle(Color.appGreenFg)
                        .lineLimit(2).minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let action { action }
        }
        .padding(16).background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, lineWidth: 1))
    }

    // MARK: 增长趋势

    private var growthCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("全站增长趋势").font(.system(size: 14, weight: .medium))
                Spacer()
                HStack(spacing: 0) {
                    ForEach([("week", "本周"), ("month", "本月"), ("year", "今年")], id: \.0) { p in
                        Button {
                            growthPeriod = p.0
                            Task { await loadGrowth() }
                        } label: {
                            Text(p.1)
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 12).padding(.vertical, 5)
                                .background(growthPeriod == p.0 ? Color.appPrimary : Color.clear)
                                .foregroundStyle(growthPeriod == p.0 ? Color.appPrimaryFg : Color.appMutedFg)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2)
                .overlay(Capsule().stroke(Color.appBorder, lineWidth: 1))
            }
            // 图例
            FlowLayout(spacing: 6) {
                ForEach(AdminView.growthMetrics, id: \.key) { m in
                    let off = growthHidden.contains(m.key)
                    Button {
                        if off { growthHidden.remove(m.key) } else {
                            if growthHidden.count < AdminView.growthMetrics.count - 1 { growthHidden.insert(m.key) }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(off ? Color.clear : m.color)
                                .frame(width: 8, height: 8)
                                .overlay(Circle().stroke(m.color, lineWidth: 1.5))
                            Text(m.label)
                                .strikethrough(off)
                                .foregroundStyle(off ? Color.appMutedFg.opacity(0.6) : Color.appForeground)
                        }
                        .font(.system(size: 11))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(off ? Color.clear : Color.appSecondary.opacity(0.3))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.appBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            if let g = growth, let labels = g.labels, !labels.isEmpty {
                let visible = AdminView.growthMetrics.filter { !growthHidden.contains($0.key) }
                if visible.isEmpty {
                    Text("所有统计量都已隐藏，点上方图例恢复显示")
                        .font(.system(size: 13)).foregroundStyle(Color.appMutedFg)
                        .frame(maxWidth: .infinity).frame(height: 176)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 1, dash: [6])))
                } else {
                    MultiLineChartView(
                        labels: labels,
                        series: visible.map { m in
                            (m.key, m.color, valuesOf(m.key, g, count: labels.count))
                        }
                    )
                    .frame(height: 200)
                }
            } else {
                LoadingView().frame(height: 176)
            }
        }
        .padding(16).background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, lineWidth: 1))
    }

    private func valuesOf(_ key: String, _ g: AdminGrowthTrend, count: Int) -> [Int] {
        let src: [Int]?
        switch key {
        case "newUsers": src = g.newUsers
        case "newShowcases": src = g.newShowcases
        case "heartPool": src = g.heartPool
        default: src = g.pageViews
        }
        return (0..<count).map { (src?.indices.contains($0) == true) ? src![$0] : 0 }
    }

    // MARK: 最近注册 / 权限管理

    private var recentUsersCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("最近注册").font(.system(size: 14, weight: .medium))
                Text("仅主管理员可见").font(.system(size: 11)).foregroundStyle(Color.appMutedFg)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            Divider()
            ForEach(recentUsers) { u in
                HStack(spacing: 6) {
                    Text(u.name ?? "未命名").font(.system(size: 14, weight: .medium)).lineLimit(1)
                    if u.superAdmin == true {
                        Text("主管理员").font(.system(size: 10, weight: .medium)).foregroundStyle(Color.appPrimary)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.appPrimary.opacity(0.1)).clipShape(Capsule())
                    } else if u.role == "admin" {
                        Text("管理员").font(.system(size: 10, weight: .medium)).foregroundStyle(Color.appGreenFg)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.appGreenBg).clipShape(Capsule())
                    }
                    Text(u.email ?? "").font(.system(size: 12)).foregroundStyle(Color.appMutedFg).lineLimit(1)
                    Spacer()
                    Text(DateFmt.short(u.createdAt)).font(.system(size: 11)).foregroundStyle(Color.appMutedFg)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                if u.id != recentUsers.last?.id { Divider() }
            }
        }
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, lineWidth: 1))
    }

    private var roleCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("权限管理").font(.system(size: 14, weight: .medium))
                Text("输入用户 ID 搜索，可授予/收回管理员权限（用户 ID 见其个人主页链接）")
                    .font(.system(size: 11)).foregroundStyle(Color.appMutedFg)
                    .lineLimit(2).minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    TextField("输入用户 ID，如 12", text: $searchId)
                        .keyboardType(.numberPad)
                        .font(.system(size: 14))
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(Color.appInput)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .onChange(of: searchId) { v in
                            let digits = v.filter(\.isNumber)
                            if digits != v { searchId = digits }
                        }
                        .onSubmit { Task { await searchUser() } }
                    Button("搜索") { Task { await searchUser() } }
                        .font(.system(size: 12)).foregroundStyle(Color.appPrimaryFg)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color.appPrimary).clipShape(Capsule())
                        .disabled(Int(searchId) == nil || Int(searchId) == 0 || busy)
                }
                if let err = queryError {
                    Text(err).font(.system(size: 12)).foregroundStyle(Color.appDestructive)
                }
                if let u = queriedUser {
                    HStack(spacing: 6) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("\(u.name ?? "未命名") #\(u.id)")
                                    .font(.system(size: 14, weight: .medium)).lineLimit(1)
                                if u.superAdmin == true {
                                    Text("主管理员").font(.system(size: 10, weight: .medium)).foregroundStyle(Color.appPrimary)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Color.appPrimary.opacity(0.1)).clipShape(Capsule())
                                } else if u.role == "admin" {
                                    Text("管理员").font(.system(size: 10, weight: .medium)).foregroundStyle(Color.appGreenFg)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Color.appGreenBg).clipShape(Capsule())
                                }
                            }
                            Text(u.email ?? "").font(.system(size: 12)).foregroundStyle(Color.appMutedFg).lineLimit(1)
                        }
                        Spacer()
                        if u.superAdmin != true && u.id != authManager.currentUser?.id {
                            Button(u.role == "admin" ? "收回权限" : "设为管理员") {
                                Task { await setRole(u) }
                            }
                            .font(.system(size: 12))
                            .foregroundStyle(u.role == "admin" ? Color.appForeground : Color.appPrimaryFg)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(u.role == "admin" ? Color.clear : Color.appPrimary)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(u.role == "admin" ? Color.appBorder : Color.clear, lineWidth: 1))
                            .disabled(busy)
                        }
                    }
                    .padding(10).background(Color.appSecondary.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder.opacity(0.6), lineWidth: 1))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, lineWidth: 1))
    }

    // MARK: 举报卡片

    private func reportCard(_ r: ReportRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("\(AdminView.typeLabel[r.targetType] ?? r.targetType) #\(r.targetId)")
                    .font(.system(size: 14, weight: .medium))
                if let author = r.targetAuthorName {
                    Text("作者:\(author)").font(.system(size: 12)).foregroundStyle(Color.appMutedFg)
                }
                if r.targetType == "showcase" {
                    NavigationLink("查看 →") { ShowcaseDetailView(showcaseId: r.targetId) }
                        .font(.system(size: 12)).foregroundStyle(Color.appPrimary)
                }
                statusChip(r.status)
                Spacer()
                Text(DateFmt.full(r.createdAt)).font(.system(size: 12)).foregroundStyle(Color.appMutedFg)
            }
            .lineLimit(1).minimumScaleFactor(0.7)
            Text(r.reason).font(.system(size: 14)).foregroundStyle(Color.appForeground.opacity(0.9))
            if let excerpt = r.targetExcerpt, !excerpt.isEmpty {
                Text("被举报内容:\(excerpt)")
                    .font(.system(size: 12)).foregroundStyle(Color.appMutedFg)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appSecondary.opacity(0.6)).clipShape(RoundedRectangle(cornerRadius: 8))
            }
            if let op = r.opinion, !op.isEmpty {
                Text("处理意见\(r.opinionByName != nil ? "（\(r.opinionByName!)）" : ""):\(op)")
                    .font(.system(size: 12)).foregroundStyle(Color(h: 217, s: 70, l: 40))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(h: 217, s: 90, l: 96)).clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // 普通管理员：填写意见提交终审
            if !isSuper && r.status == "pending" {
                if opinionOpen == r.id {
                    VStack(spacing: 8) {
                        TextField("请填写处理意见理由（是否属实、建议如何处理）…", text: $opinion, axis: .vertical)
                            .font(.system(size: 14)).lineLimit(3...5)
                            .padding(10).background(Color.appInput)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .onChange(of: opinion) { v in if v.count > 500 { opinion = String(v.prefix(500)) } }
                        HStack(spacing: 8) {
                            Button("提交给主管理员终审") { Task { await escalate(r) } }
                                .font(.system(size: 12)).foregroundStyle(Color.appPrimaryFg)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(Color.appPrimary).clipShape(Capsule())
                                .disabled(opinion.trimmingCharacters(in: .whitespaces).count < 2 || busy)
                            Button("取消") { opinionOpen = nil; opinion = "" }
                                .font(.system(size: 12)).foregroundStyle(Color.appForeground)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .overlay(Capsule().stroke(Color.appBorder, lineWidth: 1))
                        }
                    }
                } else {
                    Button("填写意见并提交终审") { opinionOpen = r.id }
                        .font(.system(size: 12)).foregroundStyle(Color.appPrimaryFg)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Color.appPrimary).clipShape(Capsule())
                }
            }

            // 主管理员：直接决定
            if isSuper && (r.status == "pending" || r.status == "escalated") {
                HStack(spacing: 8) {
                    Button(AdminView.banTypes.contains(r.targetType) ? "成立：删除并封号" : "成立：下架处理") {
                        Task { await decide(r, action: "removeTarget") }
                    }
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color.appDestructive).clipShape(Capsule())
                    .disabled(busy)
                    Button("不成立：驳回") { Task { await decide(r, action: "dismiss") } }
                        .font(.system(size: 12)).foregroundStyle(Color.appForeground)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .overlay(Capsule().stroke(Color.appBorder, lineWidth: 1))
                        .disabled(busy)
                }
            }
        }
        .padding(16).background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, lineWidth: 1))
    }

    private func statusChip(_ status: String) -> some View {
        let (label, fg, bg): (String, Color, Color) = {
            switch status {
            case "pending": return ("待处理", Color.appAmberFg, Color.appAmberBg)
            case "escalated": return ("待主管理员终审", Color(h: 217, s: 91, l: 50), Color(h: 217, s: 91, l: 94))
            case "resolved": return ("已处理", Color.appGreenFg, Color.appGreenBg)
            default: return ("已驳回", Color.appMutedFg, Color.appSecondary)
            }
        }()
        return Text(label).font(.system(size: 11)).foregroundStyle(fg)
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(bg).clipShape(Capsule())
    }

    // MARK: 数据

    private func load() async {
        async let rp = try? MashanglingAPI.shared.report.list()
        async let st = try? MashanglingAPI.shared.admin.stats()
        async let hp = try? MashanglingAPI.shared.heart.poolAdmin()
        reports = await rp; stats = await st; heartPool = await hp
        await loadGrowth()
        if isSuper {
            recentUsers = (try? await MashanglingAPI.shared.admin.recentUsers()) ?? []
        }
    }

    private func loadGrowth() async {
        growth = try? await MashanglingAPI.shared.admin.growthTrend(period: growthPeriod)
    }

    private func settleHeart() async {
        busy = true; defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.admin.settleHeart()
            ToastCenter.shared.success("已触发结算（昨天/前天未结的都补上了）")
            heartPool = try? await MashanglingAPI.shared.heart.poolAdmin()
            stats = try? await MashanglingAPI.shared.admin.stats()
        } catch { ToastCenter.shared.error("结算失败：\(error.localizedDescription)") }
    }

    private func searchUser() async {
        guard let id = Int(searchId), id > 0 else { return }
        busy = true; defer { busy = false }
        queryError = nil
        do {
            queriedUser = try await MashanglingAPI.shared.admin.searchUserById(userId: id)
            if queriedUser == nil { queryError = "未找到该用户" }
        } catch {
            queriedUser = nil
            queryError = error.localizedDescription
        }
    }

    private func setRole(_ u: AdminUser) async {
        let grant = u.role != "admin"
        busy = true; defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.admin.setRole(userId: u.id, admin: grant)
            ToastCenter.shared.success(grant ? "已授予管理员权限" : "已收回管理员权限")
            await searchUser()
            recentUsers = (try? await MashanglingAPI.shared.admin.recentUsers()) ?? []
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func escalate(_ r: ReportRow) async {
        busy = true; defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.report.escalate(id: r.id, opinion: opinion.trimmingCharacters(in: .whitespaces))
            ToastCenter.shared.success("意见已提交，等待主管理员终审")
            opinionOpen = nil; opinion = ""
            reports = try? await MashanglingAPI.shared.report.list()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func decide(_ r: ReportRow, action: String) async {
        busy = true; defer { busy = false }
        do {
            let res = try await MashanglingAPI.shared.report.decide(id: r.id, action: action)
            ToastCenter.shared.success(res.banned == true ? "已处理：内容删除并封号" : "已处理")
            reports = try? await MashanglingAPI.shared.report.list()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}

// MARK: - 标签管理（复刻 AdminTags.tsx）

private struct AdminTagEditing: Identifiable {
    let id: Int
    var name: String
    var category: String
}

struct AdminTagsView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var list: [AdminTagRow]?
    @State private var q = ""
    @State private var cat = "all"
    @State private var showRemoved = false
    @State private var editing: AdminTagEditing?
    @State private var busy = false

    private var isAdmin: Bool { authManager.currentUser?.role == "admin" }

    private var filtered: [AdminTagRow] {
        (list ?? []).filter { t in
            if !showRemoved && t.status == "removed" { return false }
            if cat != "all" && t.category != cat { return false }
            let kw = q.trimmingCharacters(in: .whitespaces).lowercased()
            if !kw.isEmpty && !t.name.lowercased().contains(kw) { return false }
            return true
        }
    }

    var body: some View {
        Group {
            if !isAdmin {
                Text("需要管理员权限")
                    .font(.system(size: 13)).foregroundStyle(Color.appMutedFg)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                content
            }
        }
        .navigationTitle("标签管理")
        .background(Color.appBackground)
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $editing) { e in
            AdminTagEditSheet(editing: $editing) { name, category in
                Task { await doUpdate(e.id, name: name, category: category) }
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    HStack(spacing: 8) {
                        Text("标签管理").font(.system(size: 22, weight: .bold))
                        Text("共 \(list?.count ?? 0) 个").font(.system(size: 14)).foregroundStyle(Color.appMutedFg)
                    }
                    Spacer()
                    NavigationLink("← 返回举报处理") { AdminView() }
                        .font(.system(size: 14)).foregroundStyle(Color.appMutedFg)
                }

                // 筛选栏
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").font(.system(size: 14)).foregroundStyle(Color.appMutedFg)
                    TextField("搜索标签名…", text: $q)
                        .font(.system(size: 14))
                }
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(Color.appInput)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.top, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach([("all", "全部分类"), ("work", "作品"), ("character", "角色"), ("merch", "制品"), ("other", "其他")], id: \.0) { c in
                            Button { cat = c.0 } label: {
                                Text(c.1)
                                    .font(.system(size: 12))
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(cat == c.0 ? Color.appPrimary : Color.appSecondary)
                                    .foregroundStyle(cat == c.0 ? Color.appPrimaryFg : Color.appSecondaryFg)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        Button { showRemoved.toggle() } label: {
                            HStack(spacing: 4) {
                                Image(systemName: showRemoved ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 12))
                                Text("显示已禁用").font(.system(size: 12))
                            }
                            .foregroundStyle(Color.appMutedFg)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 12)

                // 列表
                VStack(spacing: 0) {
                    ForEach(filtered) { t in
                        tagRow(t)
                        if t.id != filtered.last?.id { Divider() }
                    }
                    if filtered.isEmpty {
                        Text("没有符合条件的标签")
                            .font(.system(size: 13)).foregroundStyle(Color.appMutedFg)
                            .frame(maxWidth: .infinity).padding(.vertical, 48)
                    }
                }
                .background(Color.appCard)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, lineWidth: 1))
                .padding(.top, 16)
            }
            .padding(16)
        }
    }

    private func tagRow(_ t: AdminTagRow) -> some View {
        HStack(spacing: 8) {
            NavigationLink { TagDetailView(tagId: t.id) } label: {
                Text("# \(t.name)").font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.appForeground).lineLimit(1)
            }
            Text(TagCategory.label(t.category)).font(.system(size: 12)).foregroundStyle(Color.appMutedFg)
            Text("\(t.showcaseCount ?? 0) 橱窗").font(.system(size: 12)).foregroundStyle(Color.appMutedFg)
            Spacer()
            Text(t.status == "active" ? "正常" : "已禁用")
                .font(.system(size: 11))
                .foregroundStyle(t.status == "active" ? Color.appGreenFg : Color.appDestructive)
                .padding(.horizontal, 8).padding(.vertical, 2)
                .background(t.status == "active" ? Color.appGreenBg : Color.appDestructive.opacity(0.12))
                .clipShape(Capsule())
            Button { editing = AdminTagEditing(id: t.id, name: t.name, category: t.category) } label: {
                Label("编辑", systemImage: "pencil").font(.system(size: 12)).foregroundStyle(Color.appMutedFg)
            }
            if t.status == "active" {
                Button { Task { await doSetStatus(t, status: "removed") } } label: {
                    Label("禁用", systemImage: "nosign").font(.system(size: 12)).foregroundStyle(Color.appMutedFg)
                }
            } else {
                Button { Task { await doSetStatus(t, status: "active") } } label: {
                    Label("恢复", systemImage: "arrow.counterclockwise").font(.system(size: 12)).foregroundStyle(Color.appGreenFg)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .opacity(t.status == "removed" ? 0.5 : 1)
    }

    private func load() async {
        list = try? await MashanglingAPI.shared.tagAdmin.list()
    }

    private func doUpdate(_ id: Int, name: String, category: String) async {
        busy = true; defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.tagAdmin.update(id: id, name: name, category: category)
            ToastCenter.shared.success("标签已更新")
            editing = nil
            await load()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func doSetStatus(_ t: AdminTagRow, status: String) async {
        busy = true; defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.tagAdmin.setStatus(id: t.id, status: status)
            ToastCenter.shared.success(status == "removed" ? "标签已禁用" : "标签已恢复")
            await load()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}

// MARK: - 标签编辑弹窗

private struct AdminTagEditSheet: View {
    @Binding var editing: AdminTagEditing?
    let onSave: (String, String) -> Void
    @State private var name: String = ""
    @State private var category: String = "other"

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("标签名").font(.system(size: 12)).foregroundStyle(Color.appMutedFg)
                    TextField("标签名", text: $name)
                        .font(.system(size: 14))
                        .padding(.horizontal, 10).padding(.vertical, 9)
                        .background(Color.appInput)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .onChange(of: name) { v in if v.count > 32 { name = String(v.prefix(32)) } }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("分类").font(.system(size: 12)).foregroundStyle(Color.appMutedFg)
                    HStack(spacing: 8) {
                        ForEach(["work", "character", "merch", "other"], id: \.self) { c in
                            Button { category = c } label: {
                                Text(TagCategory.label(c))
                                    .font(.system(size: 13))
                                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                                    .background(category == c ? Color.appPrimary : Color.appSecondary)
                                    .foregroundStyle(category == c ? Color.appPrimaryFg : Color.appSecondaryFg)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Button {
                    onSave(name.trimmingCharacters(in: .whitespaces), category)
                } label: {
                    Text("保存").font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.appPrimaryFg)
                        .frame(maxWidth: .infinity).padding(.vertical, 11)
                        .background(Color.appPrimary).clipShape(Capsule())
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                Spacer()
            }
            .padding(20)
            .navigationTitle("编辑标签")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                name = editing?.name ?? ""
                category = editing?.category ?? "other"
            }
        }
        .presentationDetents([.medium])
    }
}
