import SwiftUI

// MARK: - 领取申请（发布者审批，对应网页 Claims.tsx）
struct ClaimsView: View {
    @State private var rows: [ClaimRow] = []
    @State private var requests: [RequestReceivedRow] = []
    @State private var soldouts: [SoldoutReceivedRow] = []
    @State private var tab = 0
    @State private var loading = true
    @State private var busy = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tabBtn(0, "领取申请 \(rows.filter { $0.status == "pending" }.count)")
                tabBtn(1, "我想要 \(requests.count)")
                tabBtn(2, "补货提醒 \(soldouts.count)")
            }
            .padding(3)
            .background(Color.appSecondary)
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.top, 10)

            Group {
                if loading {
                    LoadingView()
                    Spacer()
                } else if tab == 0 {
                    claimsList
                } else if tab == 1 {
                    requestList
                } else {
                    soldoutList
                }
            }
        }
        .background(Color.appBackground)
        .navigationTitle("领取与申请")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .overlay(ToastOverlay())
    }

    private func tabBtn(_ idx: Int, _ title: String) -> some View {
        Button { tab = idx } label: {
            Text(title)
                .font(.system(size: 12, weight: tab == idx ? .semibold : .regular))
                .foregroundColor(tab == idx ? .appForeground : .appMutedFg)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(tab == idx ? Color.appCard : Color.clear)
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    private var claimsList: some View {
        Group {
            if rows.isEmpty {
                EmptyStateView(icon: "checkmark.rectangle", title: "暂无领取申请")
                Spacer()
            } else {
                List(rows) { r in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            NavigationLink(destination: ShowcaseDetailView(showcaseId: r.showcaseId ?? 0)) {
                                Text(r.showcaseTitle ?? "")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.appPrimary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text(DateFmt.short(r.createdAt))
                                .font(.system(size: 10))
                                .foregroundColor(.appMutedFg)
                        }
                        HStack(spacing: 6) {
                            Text("申请人：\(r.applicantName ?? "")")
                                .font(.system(size: 12))
                                .foregroundColor(.appForeground)
                            if let note = r.note, !note.isEmpty {
                                Text("备注：\(note)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.appMutedFg)
                                    .lineLimit(1)
                            }
                        }
                        if let img = r.credentialImage, !img.isEmpty {
                            AppImage(path: img)
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 200, maxHeight: 160)
                                .cornerRadius(8)
                        }
                        if r.status == "pending" {
                            HStack(spacing: 10) {
                                Button { Task { await resolve(r, action: "approve") } } label: {
                                    Text("通过")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.appPrimaryFg)
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 7)
                                        .background(Color.appPrimary)
                                        .clipShape(Capsule())
                                }
                                .disabled(busy)
                                Button { Task { await resolve(r, action: "reject") } } label: {
                                    Text("拒绝")
                                        .font(.system(size: 12))
                                        .foregroundColor(.appForeground)
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 7)
                                        .overlay(Capsule().stroke(Color.appBorder, lineWidth: 1))
                                }
                                .disabled(busy)
                            }
                        } else {
                            MiniBadge(
                                text: r.status == "approved" ? "已通过" : "已拒绝",
                                fg: r.status == "approved" ? .appEmeraldFg : .appMutedFg,
                                bg: r.status == "approved" ? .appEmeraldBg : .appSecondary
                            )
                        }
                    }
                    .padding(12)
                    .background(Color.appCard)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, lineWidth: 0.5))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                }
                .listStyle(.plain)
                .refreshable { await load() }
            }
        }
    }

    private var requestList: some View {
        Group {
            if requests.isEmpty {
                EmptyStateView(icon: "hand.raised", title: "暂无人点「我想要」")
                Spacer()
            } else {
                List(requests) { r in
                    HStack(spacing: 8) {
                        Text(r.requesterName ?? "")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.appForeground)
                        Text("想要")
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                        NavigationLink(destination: ShowcaseDetailView(showcaseId: r.showcaseId ?? 0)) {
                            Text(r.showcaseTitle ?? "")
                                .font(.system(size: 12))
                                .foregroundColor(.appPrimary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(DateFmt.short(r.createdAt))
                            .font(.system(size: 10))
                            .foregroundColor(.appMutedFg)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var soldoutList: some View {
        Group {
            if soldouts.isEmpty {
                EmptyStateView(icon: "bell", title: "暂无补货提醒")
                Spacer()
            } else {
                List(soldouts) { r in
                    HStack(spacing: 8) {
                        Text(r.markerName ?? "")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.appForeground)
                        Text("反馈没有了")
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                        NavigationLink(destination: ShowcaseDetailView(showcaseId: r.showcaseId ?? 0)) {
                            Text(r.showcaseTitle ?? "")
                                .font(.system(size: 12))
                                .foregroundColor(.appPrimary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(DateFmt.short(r.createdAt))
                            .font(.system(size: 10))
                            .foregroundColor(.appMutedFg)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func load() async {
        loading = true
        rows = (try? await MashanglingAPI.shared.claim.received()) ?? []
        requests = (try? await MashanglingAPI.shared.request.received()) ?? []
        soldouts = (try? await MashanglingAPI.shared.soldout.received()) ?? []
        loading = false
    }

    private func resolve(_ r: ClaimRow, action: String) async {
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.claim.resolve(id: r.id, action: action)
            ToastCenter.shared.success(action == "approve" ? "已通过，对方现在可以看到无料码" : "已拒绝")
            await load()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}

// MARK: - 我的清单（对应网页 Bookmarks.tsx）
struct BookmarksView: View {
    @State private var data: BookmarkListResponse? = nil
    @State private var loading = true

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if loading {
                    LoadingView()
                } else {
                    // 收藏的橱窗
                    VStack(alignment: .leading, spacing: 8) {
                        Text("收藏的橱窗（\(data?.items?.count ?? 0)）")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.appForeground)
                        if (data?.items ?? []).isEmpty {
                            emptyNote("清单是空的，看到喜欢的橱窗点「清单」收藏")
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                                ForEach(data?.items ?? []) { b in
                                    NavigationLink(destination: ShowcaseDetailView(showcaseId: b.id)) {
                                        ShowcaseCardView(item: b.asShowcase)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    // 收藏的卡片
                    VStack(alignment: .leading, spacing: 8) {
                        Text("收藏的卡片（\(data?.cards?.count ?? 0)）")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.appForeground)
                        if (data?.cards ?? []).isEmpty {
                            emptyNote("还没有收藏卡片")
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                                ForEach(data?.cards ?? []) { c in
                                    VStack(alignment: .leading, spacing: 4) {
                                        CardThemeThumbnailView(config: c.config)
                                            .cornerRadius(10)
                                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appBorder, lineWidth: 0.5))
                                            .opacity(c.removed == true ? 0.4 : 1)
                                        Text(c.removed == true ? "（已撤下）\(c.title)" : c.title)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(.appForeground)
                                            .lineLimit(1)
                                        Text(c.authorName ?? "")
                                            .font(.system(size: 9))
                                            .foregroundColor(.appMutedFg)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Color.appBackground)
        .navigationTitle("我的清单")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            data = try? await MashanglingAPI.shared.bookmark.list()
            loading = false
        }
        .refreshable {
            data = try? await MashanglingAPI.shared.bookmark.list()
        }
    }

    private func emptyNote(_ t: String) -> some View {
        Text(t)
            .font(.system(size: 12))
            .foregroundColor(.appMutedFg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 26)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 1, dash: [6])))
    }
}

// MARK: - 浏览记录（对应网页 History.tsx）
struct BrowseHistoryView: View {
    @State private var tab = 0
    @State private var showcases: [BrowseHistoryRow] = []
    @State private var cards: [CardBrowseHistoryItem] = []
    @State private var loading = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tabBtn(0, "橱窗")
                tabBtn(1, "卡片")
            }
            .padding(3)
            .background(Color.appSecondary)
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.top, 10)

            if loading {
                LoadingView()
                Spacer()
            } else if tab == 0 {
                List(showcases) { r in
                    NavigationLink(destination: ShowcaseDetailView(showcaseId: r.showcaseId)) {
                        HStack(spacing: 10) {
                            AppImage(path: r.coverImage)
                                .frame(width: 48, height: 48)
                                .cornerRadius(8)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.title ?? "").font(.system(size: 13, weight: .medium)).foregroundColor(.appForeground).lineLimit(1)
                                Text("\(r.authorName ?? "") · \(DateFmt.short(r.lastAt))")
                                    .font(.system(size: 10))
                                    .foregroundColor(.appMutedFg)
                            }
                            Spacer()
                        }
                    }
                }
                .listStyle(.plain)
            } else {
                List(cards) { r in
                    HStack(spacing: 10) {
                        if let cfg = r.config {
                            CardThemeThumbnailView(config: cfg)
                                .frame(width: 36, height: 48)
                                .cornerRadius(6)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.removed == true ? "（已撤下）\(r.title ?? "")" : (r.title ?? ""))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.appForeground)
                                .lineLimit(1)
                            Text("\(r.authorName ?? "") · \(DateFmt.short(r.lastAt))")
                                .font(.system(size: 10))
                                .foregroundColor(.appMutedFg)
                        }
                        Spacer()
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(Color.appBackground)
        .navigationTitle("浏览记录")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            async let s = try? MashanglingAPI.shared.showcase.browseHistory()
            async let c = try? MashanglingAPI.shared.cardPlaza.browseHistory()
            // showcase.browseHistory 返回 feed item 列表，取摘要字段
            let sv = await s ?? []
            showcases = sv.map {
                BrowseHistoryRow(showcaseId: $0.id, lastAt: nil, title: $0.title,
                                 coverImage: $0.coverImage, authorName: $0.author?.name, authorId: $0.author?.id)
            }
            cards = await c ?? []
            loading = false
        }
    }

    private func tabBtn(_ idx: Int, _ title: String) -> some View {
        Button { tab = idx } label: {
            Text(title)
                .font(.system(size: 13, weight: tab == idx ? .semibold : .regular))
                .foregroundColor(tab == idx ? .appForeground : .appMutedFg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(tab == idx ? Color.appCard : Color.clear)
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 我的评论（对应网页 MyComments.tsx）
struct MyCommentsView: View {
    @State private var items: [MyCommentsResponse.MyCommentRow] = []
    @State private var loading = true

    var body: some View {
        Group {
            if loading {
                LoadingView()
            } else if items.isEmpty {
                EmptyStateView(icon: "text.bubble", title: "还没有评论过卡片")
            } else {
                List(items) { c in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(c.content)
                            .font(.system(size: 13))
                            .foregroundColor(.appForeground)
                        HStack {
                            Text("评论了「\(c.postTitle ?? "")」")
                                .font(.system(size: 11))
                                .foregroundColor(.appMutedFg)
                                .lineLimit(1)
                            if c.postStatus == "removed" {
                                MiniBadge(text: "已撤下", fg: .appMutedFg, bg: .appSecondary)
                            }
                            Spacer()
                            Text(DateFmt.short(c.createdAt))
                                .font(.system(size: 10))
                                .foregroundColor(.appMutedFg)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
        }
        .background(Color.appBackground)
        .navigationTitle("我的评论")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            items = (try? await MashanglingAPI.shared.cardPlaza.myComments().items) ?? []
            loading = false
        }
    }
}

// MARK: - 积分与等级（对应网页 Points.tsx）
struct PointsView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var my: PointsMy? = nil
    @State private var records: [PointLogRow] = []
    @State private var leaderboard: [PointsLeaderboardUser] = []
    @State private var period = "week"
    @State private var checkin: CheckinStatus? = nil
    @State private var tasks: TaskProgress? = nil
    @State private var tab = 0
    @State private var busy = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                // 总览卡
                if let p = my {
                    overviewCard(p)
                } else {
                    LoadingView()
                }

                // 签到
                checkinCard

                // 任务
                if let t = tasks {
                    tasksCard(t)
                }

                // 头衔
                if let titles = my?.titles, !titles.isEmpty {
                    titlesCard(titles)
                }

                // 榜单 / 流水
                HStack(spacing: 0) {
                    tabBtn(0, "达人榜")
                    tabBtn(1, "积分流水")
                }
                .padding(3)
                .background(Color.appSecondary)
                .cornerRadius(12)

                if tab == 0 {
                    leaderboardSection
                } else {
                    recordsSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Color.appBackground)
        .navigationTitle("积分与等级")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: ShopView()) {
                    HStack(spacing: 4) {
                        Image(systemName: "bag")
                            .font(.system(size: 12))
                        Text("商店")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.appPrimary)
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .overlay(ToastOverlay())
    }

    private func overviewCard(_ p: PointsMy) -> some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(p.points)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.appForeground)
                        Text("总积分 · 可用 \(p.available)")
                            .font(.system(size: 11))
                            .foregroundColor(.appMutedFg)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Lv.\(p.level) \(p.band)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.appPrimary)
                        Text("本周 +\(p.weekPoints ?? 0) · 本月 +\(p.monthPoints ?? 0)")
                            .font(.system(size: 10))
                            .foregroundColor(.appMutedFg)
                    }
                }
                ProgressView(value: p.need > 0 ? Double(p.into) / Double(p.need) : 1)
                    .tint(.appPrimary)
                Text(p.maxLevel == true ? "已满级" : "距 Lv.\(p.level + 1) 还需 \(p.need - p.into) 积分")
                    .font(.system(size: 10))
                    .foregroundColor(.appMutedFg)
            }
        }
    }

    private var checkinCard: some View {
        SectionCard {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("每日签到")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.appForeground)
                    Text("已连续签到 \(checkin?.streak ?? 0) 天")
                        .font(.system(size: 11))
                        .foregroundColor(.appMutedFg)
                }
                Spacer()
                Button { Task { await doCheckin() } } label: {
                    Text(checkin?.checkedToday == true ? "今日已签" : "签到")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(checkin?.checkedToday == true ? .appMutedFg : .appPrimaryFg)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 9)
                        .background(checkin?.checkedToday == true ? Color.appSecondary : Color.appPrimary)
                        .clipShape(Capsule())
                }
                .disabled(checkin?.checkedToday == true || busy)
            }
        }
    }

    private func tasksCard(_ t: TaskProgress) -> some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("任务中心")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appForeground)
                taskGroup("每日任务", items: t.daily ?? [])
                taskGroup("每周任务", items: t.weekly ?? [])
            }
        }
    }

    private func taskGroup(_ title: String, items: [TaskItem]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.appMutedFg)
            ForEach(items) { item in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.label)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.appForeground)
                        Text("进度 \(item.progress)/\(item.goal) · 奖励 +\(item.reward)")
                            .font(.system(size: 10))
                            .foregroundColor(.appMutedFg)
                    }
                    Spacer()
                    if item.claimed {
                        MiniBadge(text: "已领取", fg: .appMutedFg, bg: .appSecondary)
                    } else if item.done {
                        Button { Task { await claimTask(item.key) } } label: {
                            Text("领取")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.appPrimaryFg)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(Color.appPrimary)
                                .clipShape(Capsule())
                        }
                        .disabled(busy)
                    } else {
                        MiniBadge(text: "进行中", fg: .appAmberFg, bg: .appAmberBg)
                    }
                }
            }
        }
    }

    private func titlesCard(_ titles: [PointsMy.TitleItem]) -> some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("我的头衔")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appForeground)
                ForEach(titles) { t in
                    let meta = Levels.titles[t.key] ?? (t.key, "🏅", "")
                    HStack(spacing: 8) {
                        Text("\(meta.icon) \(meta.label)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.appForeground)
                        Text(meta.desc)
                            .font(.system(size: 10))
                            .foregroundColor(.appMutedFg)
                            .lineLimit(1)
                        Spacer()
                        Button { Task { await equip(t) } } label: {
                            Text(t.equipped ? "卸下" : "佩戴")
                                .font(.system(size: 11))
                                .foregroundColor(t.equipped ? .appMutedFg : .appPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .overlay(Capsule().stroke(t.equipped ? Color.appBorder : Color.appPrimary, lineWidth: 1))
                        }
                        .disabled(busy)
                    }
                }
            }
        }
    }

    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                PillButton(title: "周榜", selected: period == "week") {
                    period = "week"; Task { await loadBoard() }
                }
                PillButton(title: "月榜", selected: period == "month") {
                    period = "month"; Task { await loadBoard() }
                }
                Spacer()
                Text("每周日 23:59 定榜，第一获「鸡蛋王」头衔")
                    .font(.system(size: 9))
                    .foregroundColor(.appMutedFg)
            }
            ForEach(Array(leaderboard.enumerated()), id: \.element.id) { i, u in
                NavigationLink(destination: ProfileView(userId: u.userId)) {
                    HStack(spacing: 10) {
                        Text("\(i + 1)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(i == 0 ? .appAmberFg : .appMutedFg)
                            .frame(width: 24)
                        AvatarView(path: u.avatar, name: u.name ?? "", size: 32)
                        Text(u.name ?? "").font(.system(size: 13, weight: .medium)).foregroundColor(.appForeground)
                        TitleBadgeView(equippedTitle: u.equippedTitle, plain: true)
                        Spacer()
                        Text("\(period == "week" ? (u.weekPoints ?? 0) : (u.points ?? 0)) 分")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.appPrimary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
            if leaderboard.isEmpty {
                Text("暂无上榜数据")
                    .font(.system(size: 12))
                    .foregroundColor(.appMutedFg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            }
        }
    }

    private var recordsSection: some View {
        VStack(spacing: 0) {
            ForEach(records) { r in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.label)
                            .font(.system(size: 12))
                            .foregroundColor(.appForeground)
                        Text(DateFmt.full(r.createdAt))
                            .font(.system(size: 10))
                            .foregroundColor(.appMutedFg)
                    }
                    Spacer()
                    Text(r.delta >= 0 ? "+\(r.delta)" : "\(r.delta)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(r.delta >= 0 ? .appEmeraldFg : .appDestructive)
                }
                .padding(.vertical, 8)
                if r.id != records.last?.id { Divider() }
            }
            if records.isEmpty {
                Text("暂无流水")
                    .font(.system(size: 12))
                    .foregroundColor(.appMutedFg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            }
        }
        .padding(.horizontal, 12)
        .background(Color.appCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, lineWidth: 0.5))
    }

    private func tabBtn(_ idx: Int, _ title: String) -> some View {
        Button { tab = idx } label: {
            Text(title)
                .font(.system(size: 13, weight: tab == idx ? .semibold : .regular))
                .foregroundColor(tab == idx ? .appForeground : .appMutedFg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(tab == idx ? Color.appCard : Color.clear)
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        my = try? await MashanglingAPI.shared.points.my()
        records = (try? await MashanglingAPI.shared.points.records()) ?? []
        checkin = try? await MashanglingAPI.shared.task.checkinStatus()
        tasks = try? await MashanglingAPI.shared.task.mine()
        await loadBoard()
    }

    private func loadBoard() async {
        leaderboard = (try? await MashanglingAPI.shared.points.leaderboard(period: period)) ?? []
    }

    private func doCheckin() async {
        busy = true
        defer { busy = false }
        do {
            let r = try await MashanglingAPI.shared.task.checkin()
            if r.already == true {
                ToastCenter.shared.show("今天已经签到过了")
            } else {
                ToastCenter.shared.success("签到成功 +\(r.reward ?? 0) 积分（连续 \(r.streak ?? 0) 天）")
            }
            checkin = try? await MashanglingAPI.shared.task.checkinStatus()
            my = try? await MashanglingAPI.shared.points.my()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func claimTask(_ key: String) async {
        busy = true
        defer { busy = false }
        do {
            let r = try await MashanglingAPI.shared.task.claim(taskKey: key)
            ToastCenter.shared.success(r.already == true ? "已领取过" : "领取成功 +\(r.reward ?? 0) 积分")
            tasks = try? await MashanglingAPI.shared.task.mine()
            my = try? await MashanglingAPI.shared.points.my()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func equip(_ t: PointsMy.TitleItem) async {
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.points.equipTitle(t.equipped ? nil : t.key)
            ToastCenter.shared.success(t.equipped ? "已卸下头衔" : "已佩戴头衔")
            my = try? await MashanglingAPI.shared.points.my()
            await AuthManager.shared.checkAuth()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}
