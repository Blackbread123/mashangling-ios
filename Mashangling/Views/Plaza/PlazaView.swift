import SwiftUI

// MARK: - 广场 Tab（对应网页 PlazaPage.tsx：橱窗广场）
// 今日标签趋势 + 标签筛选 + 任务中心 + 无料达人榜 + 橱窗信息流
struct PlazaView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var trending: [Tag] = []
    @State private var includeTags: [Tag] = []
    @State private var excludeTags: [Tag] = []
    @State private var filterMode = 0   // 0 添加(包含) 1 屏蔽
    @State private var tagQuery = ""
    @State private var tagResults: [Tag] = []
    @State private var checkin: CheckinStatus? = nil
    @State private var tasks: TaskProgress? = nil
    @State private var tasksOpen = false
    @State private var boardTab = 0     // 0 上升最快 1 周榜 2 月榜
    @State private var rising: [PointsLeaderboardUser] = []
    @State private var board: [PointsLeaderboardUser] = []
    @State private var busy = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    trendingSection
                    filterSection
                    if authManager.isAuthenticated {
                        tasksCard
                        boardCard
                    }
                    FeedView(includeTagIds: includeTags.map { $0.id },
                             excludeTagIds: excludeTags.map { $0.id })
                        .id("\(includeTags.map { $0.id })-\(excludeTags.map { $0.id })")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color.appBackground)
            .navigationTitle("广场")
            .navigationBarTitleDisplayMode(.inline)
            .task { await load() }
            .refreshable { await load() }
        }
    }

    // MARK: 今日标签趋势
    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "flame")
                    .font(.system(size: 12))
                    .foregroundColor(.appAmberIcon)
                Text("今日标签趋势")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appForeground)
            }
            if trending.isEmpty {
                Text("今天还没有新橱窗打标签")
                    .font(.system(size: 11))
                    .foregroundColor(.appMutedFg)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(trending) { t in
                        Button { toggleInclude(t) } label: {
                            HStack(spacing: 4) {
                                Text("# \(t.name)")
                                    .font(.system(size: 11, weight: .medium))
                                Text("\(t.todayCount ?? 0) 个新橱窗")
                                    .font(.system(size: 9))
                                    .foregroundColor(.appMutedFg)
                            }
                            .foregroundColor(isIncluded(t) ? .appPrimaryFg : .appForeground)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(isIncluded(t) ? Color.appPrimary : Color.appCard)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: 标签筛选
    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 12))
                    .foregroundColor(.appPrimary)
                Text("筛选")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appForeground)
                if includeTags.isEmpty && excludeTags.isEmpty {
                    Text("未设置筛选，下方显示全部橱窗")
                        .font(.system(size: 10))
                        .foregroundColor(.appMutedFg)
                }
                Spacer()
            }

            if !includeTags.isEmpty || !excludeTags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(includeTags) { t in
                        filterChip(t, excluded: false)
                    }
                    ForEach(excludeTags) { t in
                        filterChip(t, excluded: true)
                    }
                }
            }

            HStack(spacing: 8) {
                PillButton(title: "添加标签", selected: filterMode == 0) { filterMode = 0 }
                PillButton(title: "屏蔽标签", selected: filterMode == 1) { filterMode = 1 }
                Spacer()
            }
            AppTextField(text: $tagQuery,
                         placeholder: filterMode == 0 ? "搜索要包含的标签…" : "搜索要屏蔽的标签…")
                .onChange(of: tagQuery) { _ in Task { await searchTags() } }
                .onSubmit { Task { await searchTags() } }
            if !tagResults.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(tagResults) { t in
                        Button {
                            if filterMode == 0 { toggleInclude(t) } else { toggleExclude(t) }
                            tagQuery = ""
                            tagResults = []
                        } label: {
                            Text("# \(t.name)")
                                .font(.system(size: 11))
                                .foregroundColor(.appForeground)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.appSecondary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Text("包含标签取交集；屏蔽标签取排除（含任一被屏蔽标签的橱窗不显示）")
                .font(.system(size: 9))
                .foregroundColor(.appMutedFg)
        }
    }

    private func filterChip(_ t: Tag, excluded: Bool) -> some View {
        HStack(spacing: 4) {
            Text(excluded ? "🚫 # \(t.name)" : "# \(t.name)")
            Button {
                if excluded { excludeTags.removeAll { $0.id == t.id } }
                else { includeTags.removeAll { $0.id == t.id } }
            } label: {
                Image(systemName: "xmark").font(.system(size: 8))
            }
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundColor(excluded ? .appDestructive : .appPrimaryFg)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(excluded ? Color.appDestructive.opacity(0.12) : Color.appPrimary)
        .clipShape(Capsule())
    }

    // MARK: 任务中心
    private var tasksCard: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("任务")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.appForeground)
                    Text("完成任务领积分 · 仅自己可见")
                        .font(.system(size: 10))
                        .foregroundColor(.appMutedFg)
                    Spacer()
                    Button(tasksOpen ? "收起" : "展开") { tasksOpen.toggle() }
                        .font(.system(size: 12))
                        .foregroundColor(.appPrimary)
                }

                // 签到行
                HStack {
                    Text("已连续签到 \(checkin?.streak ?? 0) 天")
                        .font(.system(size: 12))
                        .foregroundColor(.appForeground)
                    Spacer()
                    Button { Task { await doCheckin() } } label: {
                        Text(checkin?.checkedToday == true ? "今日已签" : "签到")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(checkin?.checkedToday == true ? .appMutedFg : .appPrimaryFg)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(checkin?.checkedToday == true ? Color.appSecondary : Color.appPrimary)
                            .clipShape(Capsule())
                    }
                    .disabled(checkin?.checkedToday == true || busy)
                }

                if tasksOpen, let t = tasks {
                    taskGroup("每日任务", items: t.daily ?? [])
                    taskGroup("每周任务", items: t.weekly ?? [])
                }
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
                    Text(item.label)
                        .font(.system(size: 12))
                        .foregroundColor(.appForeground)
                    Text("\(item.progress)/\(item.goal) · +\(item.reward)")
                        .font(.system(size: 10))
                        .foregroundColor(.appMutedFg)
                    Spacer()
                    if item.claimed {
                        MiniBadge(text: "已领取", fg: .appMutedFg, bg: .appSecondary)
                    } else if item.done {
                        Button { Task { await claimTask(item.key) } } label: {
                            Text("领取")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.appPrimaryFg)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.appPrimary)
                                .clipShape(Capsule())
                        }
                        .disabled(busy)
                    }
                }
            }
        }
    }

    // MARK: 无料达人榜
    private var boardCard: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("无料达人")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.appForeground)
                    Spacer()
                    HStack(spacing: 6) {
                        PillButton(title: "上升最快", selected: boardTab == 0) {
                            boardTab = 0
                            Task { await loadBoard() }
                        }
                        PillButton(title: "周榜", selected: boardTab == 1) {
                            boardTab = 1
                            Task { await loadBoard() }
                        }
                        PillButton(title: "月榜", selected: boardTab == 2) {
                            boardTab = 2
                            Task { await loadBoard() }
                        }
                    }
                }
                Text("按农场可用积分排名 · 每周日 23:59 定榜，第一名 +100 分")
                    .font(.system(size: 9))
                    .foregroundColor(.appMutedFg)
                let list = boardTab == 0 ? rising : board
                ForEach(Array(list.prefix(10).enumerated()), id: \.element.id) { i, u in
                    NavigationLink(destination: ProfileView(userId: u.userId)) {
                        HStack(spacing: 10) {
                            Text("\(i + 1)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(i == 0 ? .appAmberFg : .appMutedFg)
                                .frame(width: 22)
                            AvatarView(path: u.avatar, name: u.name ?? "", size: 28)
                            Text(u.name ?? "")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.appForeground)
                                .lineLimit(1)
                            if let lv = u.level { LevelBadgeView(level: lv) }
                            TitleBadgeView(equippedTitle: u.equippedTitle, plain: true)
                            Spacer()
                            Text("\(u.points ?? u.weekPoints ?? 0)分")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.appPrimary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                if list.isEmpty {
                    Text("暂无上榜数据")
                        .font(.system(size: 11))
                        .foregroundColor(.appMutedFg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
            }
        }
    }

    // MARK: 逻辑
    private func isIncluded(_ t: Tag) -> Bool { includeTags.contains { $0.id == t.id } }

    private func toggleInclude(_ t: Tag) {
        if isIncluded(t) { includeTags.removeAll { $0.id == t.id } }
        else {
            includeTags.append(t)
            excludeTags.removeAll { $0.id == t.id }
        }
    }

    private func toggleExclude(_ t: Tag) {
        if excludeTags.contains(where: { $0.id == t.id }) { excludeTags.removeAll { $0.id == t.id } }
        else {
            excludeTags.append(t)
            includeTags.removeAll { $0.id == t.id }
        }
    }

    private func searchTags() async {
        let q = tagQuery.trimmingCharacters(in: .whitespaces)
        tagResults = (try? await MashanglingAPI.shared.tag.search(q: q, limit: 10)) ?? []
    }

    private func load() async {
        trending = (try? await MashanglingAPI.shared.tag.trendingToday()) ?? []
        guard authManager.isAuthenticated else { return }
        checkin = try? await MashanglingAPI.shared.task.checkinStatus()
        tasks = try? await MashanglingAPI.shared.task.mine()
        await loadBoard()
    }

    private func loadBoard() async {
        switch boardTab {
        case 0:
            rising = (try? await MashanglingAPI.shared.points.rising(limit: 10)) ?? []
        case 1:
            board = (try? await MashanglingAPI.shared.points.leaderboard(period: "week")) ?? []
        default:
            board = (try? await MashanglingAPI.shared.points.leaderboard(period: "month")) ?? []
        }
    }

    private func doCheckin() async {
        busy = true
        defer { busy = false }
        do {
            let r = try await MashanglingAPI.shared.task.checkin()
            ToastCenter.shared.success(r.already == true ? "今天已经签到过了" : "签到成功 +\(r.reward ?? 0) 积分")
            checkin = try? await MashanglingAPI.shared.task.checkinStatus()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func claimTask(_ key: String) async {
        busy = true
        defer { busy = false }
        do {
            let r = try await MashanglingAPI.shared.task.claim(taskKey: key)
            ToastCenter.shared.success(r.already == true ? "已领取过" : "领取成功 +\(r.reward ?? 0) 积分")
            tasks = try? await MashanglingAPI.shared.task.mine()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}

// MARK: - 卡片广场（卡片作品信息流）
struct CardPlazaView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var vm = CardPlazaViewModel()
    @State private var openPostId: Int? = nil
    @State private var showLogin = false
    @State private var showLeaderboard = false

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                // 标题 + 榜单入口
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("卡片广场")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.appForeground)
                        Text("大家设计的分享卡片主题，喜欢就导入或求分享")
                            .font(.system(size: 11))
                            .foregroundColor(.appMutedFg)
                    }
                    Spacer()
                    Button { showLeaderboard = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trophy")
                                .font(.system(size: 11))
                            Text("热度榜")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.appAmberFg)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.appAmberBg)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                // 排序栏
                HStack(spacing: 6) {
                    PillButton(title: "热门", selected: vm.sort == "hot") {
                        vm.sort = "hot"
                        Task { await vm.reload() }
                    }
                    PillButton(title: "最新", selected: vm.sort == "new") {
                        vm.sort = "new"
                        Task { await vm.reload() }
                    }
                    if vm.sort == "hot" {
                        ForEach(FeedViewModel.windows, id: \.key) { w in
                            PillButton(title: w.label, selected: vm.window == w.key) {
                                vm.window = w.key
                                Task { await vm.reload() }
                            }
                        }
                    }
                    Spacer()
                }

                if vm.loading && vm.items.isEmpty {
                    LoadingView()
                } else if vm.items.isEmpty {
                    Text("广场还没有卡片，去「个性化」发布第一套吧")
                        .font(.system(size: 13))
                        .foregroundColor(.appMutedFg)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 50)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 1, dash: [6])))
                } else {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(vm.items) { p in
                            Button { openPostId = p.id } label: {
                                cardCell(p)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if vm.cursor > 0 {
                        Button {
                            Task { await vm.loadMore() }
                        } label: {
                            Text(vm.loadingMore ? "加载中…" : "加载更多")
                                .font(.system(size: 13))
                                .foregroundColor(.appForeground)
                                .padding(.horizontal, 22)
                                .padding(.vertical, 7)
                                .background(Color.appCard)
                                .cornerRadius(18)
                                .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                        .disabled(vm.loadingMore)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Color.appBackground)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { vm.onAppear() }
        .refreshable { await vm.reload() }
        .sheet(isPresented: Binding(get: { openPostId != nil }, set: { if !$0 { openPostId = nil } })) {
            if let pid = openPostId {
                CardDetailSheet(postId: pid) { }
            }
        }
        .sheet(isPresented: $showLogin) { LoginView() }
        .sheet(isPresented: $showLeaderboard) { CardLeaderboardSheet() }
    }

    private func cardCell(_ p: CardPostItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .topLeading) {
                CardThemeThumbnailView(config: p.config)
                    .cornerRadius(10)
                Text("SHOW ONLY")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.55))
                    .clipShape(Capsule())
                    .padding(6)
            }
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appBorder, lineWidth: 0.5))
            Text(p.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.appForeground)
                .lineLimit(1)
            Text("\(p.author?.name ?? "匿名") · ❤ \(p.likeCount ?? 0) · 👁 \(p.viewCount ?? 0)")
                .font(.system(size: 9))
                .foregroundColor(.appMutedFg)
                .lineLimit(1)
        }
    }
}

@MainActor
class CardPlazaViewModel: ObservableObject {
    @Published var sort = "hot"
    @Published var window = "week"
    @Published var items: [CardPostItem] = []
    @Published var cursor = 0
    @Published var loading = false
    @Published var loadingMore = false
    private var appeared = false

    func onAppear() {
        guard !appeared else { return }
        appeared = true
        Task { await reload() }
    }

    func reload() async {
        loading = true
        do {
            let r = try await MashanglingAPI.shared.cardPlaza.feed(sort: sort, window: window, cursor: 0, limit: 24)
            items = r.items
            cursor = r.nextCursor ?? -1
        } catch {
            ToastCenter.shared.error(error.localizedDescription)
        }
        loading = false
    }

    func loadMore() async {
        guard cursor > 0, !loadingMore else { return }
        loadingMore = true
        do {
            let r = try await MashanglingAPI.shared.cardPlaza.feed(sort: sort, window: window, cursor: cursor, limit: 24)
            items.append(contentsOf: r.items)
            cursor = r.nextCursor ?? -1
        } catch {}
        loadingMore = false
    }
}

// MARK: - 卡片详情弹窗（对应网页 CardPostDialog）
struct CardDetailSheet: View {
    let postId: Int
    var onClose: () -> Void

    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var post: CardPostItem? = nil
    @State private var comments: [CardCommentRow] = []
    @State private var commentInput = ""
    @State private var liked = false
    @State private var favorited = false
    @State private var wanted = false
    @State private var showLogin = false
    @State private var showFriends = false
    @State private var showReport = false
    @State private var busy = false

    var body: some View {
        NavigationStack {
            Group {
                if let p = post {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 12) {
                            CardThemeThumbnailView(config: p.config)
                                .frame(maxWidth: 260)
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, lineWidth: 0.5))
                                .frame(maxWidth: .infinity)

                            Text(p.title)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.appForeground)

                            HStack(spacing: 8) {
                                NavigationLink(destination: ProfileView(userId: p.author?.id ?? 0)) {
                                    HStack(spacing: 6) {
                                        AvatarView(path: p.author?.avatar, name: p.author?.name ?? "", size: 24)
                                        Text(p.author?.name ?? "匿名")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.appForeground)
                                        if let lv = p.author?.level {
                                            LevelBadgeView(level: lv)
                                        }
                                        TitleBadgeView(equippedTitle: p.author?.equippedTitle)
                                    }
                                }
                                .buttonStyle(.plain)
                                Spacer()
                                Text("👁 \(p.viewCount ?? 0)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.appMutedFg)
                            }

                            // 操作行
                            HStack(spacing: 8) {
                                opButton(icon: liked ? "heart.fill" : "heart", label: "\(p.likeCount ?? 0)", tint: liked ? .appRedFg : .appMutedFg) {
                                    Task { await toggleLike() }
                                }
                                opButton(icon: "hand.raised", label: wanted ? "已想要" : "想要", tint: wanted ? .appAmberFg : .appMutedFg) {
                                    Task { await want() }
                                }
                                opButton(icon: favorited ? "star.fill" : "star", label: "收藏", tint: favorited ? .appPrimary : .appMutedFg) {
                                    Task { await toggleFavorite() }
                                }
                                opButton(icon: "square.and.arrow.up", label: "转发", tint: .appMutedFg) {
                                    guard authManager.isAuthenticated else { showLogin = true; return }
                                    showFriends = true
                                }
                                opButton(icon: "flag", label: "举报", tint: .appMutedFg) {
                                    guard authManager.isAuthenticated else { showLogin = true; return }
                                    showReport = true
                                }
                            }

                            if p.isMine == true {
                                Button(role: .destructive) { Task { await removePost() } } label: {
                                    Text("从广场撤下")
                                        .font(.system(size: 12))
                                        .foregroundColor(.appDestructive)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 9)
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appDestructive.opacity(0.5), lineWidth: 1))
                                }
                            }

                            // 评论区
                            VStack(alignment: .leading, spacing: 8) {
                                Text("评论（\(p.commentCount ?? comments.count)）")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.appForeground)
                                HStack(spacing: 8) {
                                    AppTextField(text: $commentInput, placeholder: "说点什么…")
                                    Button { Task { await sendComment() } } label: {
                                        Image(systemName: "paperplane.fill")
                                            .font(.system(size: 13))
                                            .foregroundColor(.appPrimaryFg)
                                            .frame(width: 38, height: 38)
                                            .background(Color.appPrimary)
                                            .clipShape(Circle())
                                    }
                                    .disabled(commentInput.trimmingCharacters(in: .whitespaces).isEmpty || busy)
                                }
                                ForEach(comments) { c in
                                    HStack(alignment: .top, spacing: 8) {
                                        AvatarView(path: c.avatar, name: c.name ?? "", size: 26)
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 6) {
                                                Text(c.name ?? "").font(.system(size: 11, weight: .medium))
                                                Text(DateFmt.short(c.createdAt)).font(.system(size: 10)).foregroundColor(.appMutedFg)
                                                Spacer()
                                                if c.userId == authManager.currentUser?.id {
                                                    Button { Task { await deleteComment(c.id) } } label: {
                                                        Image(systemName: "trash").font(.system(size: 10)).foregroundColor(.appMutedFg)
                                                    }
                                                }
                                            }
                                            Text(c.content).font(.system(size: 12))
                                        }
                                        .foregroundColor(.appForeground)
                                    }
                                    .padding(10)
                                    .background(Color.appSecondary.opacity(0.3))
                                    .cornerRadius(10)
                                }
                            }
                        }
                        .padding(16)
                    }
                } else {
                    LoadingView()
                }
            }
            .background(Color.appBackground)
            .navigationTitle("卡片详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss(); onClose() }
                        .font(.system(size: 13))
                        .foregroundColor(.appMutedFg)
                }
            }
        }
        .presentationDetents([.large])
        .sheet(isPresented: $showLogin) { LoginView() }
        .sheet(isPresented: $showReport) { ReportSheet(targetType: "cardPost", targetId: postId) }
        .sheet(isPresented: $showFriends) { CardShareFriendSheet(postId: postId) }
        .task { await load() }
    }

    private func opButton(icon: String, label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 15))
                Text(label).font(.system(size: 9))
            }
            .foregroundColor(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.appCard)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appBorder, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        if let p = try? await MashanglingAPI.shared.cardPlaza.byId(id: postId) {
            post = p
            liked = p.likedByMe ?? false
            favorited = p.favoritedByMe ?? false
            wanted = p.wantedByMe ?? false
        }
        comments = (try? await MashanglingAPI.shared.cardPlaza.comments(postId: postId)) ?? []
    }

    private func toggleLike() async {
        guard authManager.isAuthenticated else { showLogin = true; return }
        do {
            let now = try await MashanglingAPI.shared.cardPlaza.toggleLike(postId: postId)
            liked = now
            if var p = post {
                p.likeCount = (p.likeCount ?? 0) + (now ? 1 : -1)
                p.likedByMe = now
                post = p
            }
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func want() async {
        guard authManager.isAuthenticated else { showLogin = true; return }
        do {
            let already = try await MashanglingAPI.shared.cardPlaza.want(postId: postId)
            wanted = true
            ToastCenter.shared.success(already ? "之前已标记过「想要」" : "已告诉作者「想要」")
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func toggleFavorite() async {
        guard authManager.isAuthenticated else { showLogin = true; return }
        do {
            let now = try await MashanglingAPI.shared.cardPlaza.toggleFavorite(postId: postId)
            favorited = now
            ToastCenter.shared.success(now ? "已收藏到清单" : "已取消收藏")
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func sendComment() async {
        guard authManager.isAuthenticated else { showLogin = true; return }
        let text = commentInput.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.cardPlaza.comment(postId: postId, content: text)
            commentInput = ""
            comments = (try? await MashanglingAPI.shared.cardPlaza.comments(postId: postId)) ?? comments
            if var p = post { p.commentCount = (p.commentCount ?? 0) + 1; post = p }
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func deleteComment(_ id: Int) async {
        do {
            _ = try await MashanglingAPI.shared.cardPlaza.deleteComment(commentId: id)
            comments.removeAll { $0.id == id }
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func removePost() async {
        do {
            _ = try await MashanglingAPI.shared.cardPlaza.remove(postId: postId)
            ToastCenter.shared.success("已从广场撤下")
            dismiss()
            onClose()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}

// MARK: - 转发给互关好友
struct CardShareFriendSheet: View {
    let postId: Int

    @Environment(\.dismiss) private var dismiss
    @State private var friends: [FollowUser] = []
    @State private var loading = true
    @State private var busy = false

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    LoadingView()
                } else if friends.isEmpty {
                    Text("还没有互关好友")
                        .font(.system(size: 13))
                        .foregroundColor(.appMutedFg)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(friends) { f in
                        HStack(spacing: 10) {
                            AvatarView(path: f.avatar, name: f.name ?? "", size: 34)
                            Text(f.name ?? "").font(.system(size: 14, weight: .medium))
                            Spacer()
                            Button { Task { await send(to: f.userId) } } label: {
                                Text("转发")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.appPrimaryFg)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.appPrimary)
                                    .clipShape(Capsule())
                            }
                            .disabled(busy)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color.appBackground)
            .navigationTitle("转发给好友")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                        .font(.system(size: 13))
                        .foregroundColor(.appMutedFg)
                }
            }
        }
        .presentationDetents([.medium])
        .task {
            friends = (try? await MashanglingAPI.shared.follow.mutuals()) ?? []
            loading = false
        }
    }

    private func send(to userId: Int) async {
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.cardPlaza.shareToFriend(postId: postId, toUserId: userId)
            ToastCenter.shared.success("已转发，对方会在私信里收到")
            dismiss()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}

// MARK: - 卡片作者热度榜
struct CardLeaderboardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var window = "week"
    @State private var items: [CardLeaderboardResponse.CardLeaderboardUser] = []
    @State private var loading = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack(spacing: 6) {
                    ForEach([("week", "本周"), ("month", "本月"), ("all", "总榜")], id: \.0) { w in
                        PillButton(title: w.1, selected: window == w.0) {
                            window = w.0
                            Task { await load() }
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)

                if loading {
                    LoadingView()
                } else if items.isEmpty {
                    Text("暂无上榜作者")
                        .font(.system(size: 13))
                        .foregroundColor(.appMutedFg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else {
                    List(Array(items.enumerated()), id: \.element.id) { i, u in
                        NavigationLink(destination: ProfileView(userId: u.userId)) {
                            HStack(spacing: 10) {
                                Text("\(u.rank)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(u.rank <= 3 ? .appAmberFg : .appMutedFg)
                                    .frame(width: 24)
                                AvatarView(path: u.avatar, name: u.name ?? "", size: 32)
                                Text(u.name ?? "").font(.system(size: 13, weight: .medium))
                                Spacer()
                                Text("热度 \(u.heat)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.appMutedFg)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .padding(.top, 12)
            .background(Color.appBackground)
            .navigationTitle("卡片作者热度榜")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                        .font(.system(size: 13))
                        .foregroundColor(.appMutedFg)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .task { await load() }
    }

    private func load() async {
        loading = true
        items = (try? await MashanglingAPI.shared.cardPlaza.leaderboard(window: window).items) ?? []
        loading = false
    }
}
