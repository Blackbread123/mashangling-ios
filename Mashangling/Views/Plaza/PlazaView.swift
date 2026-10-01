import SwiftUI

// MARK: - 广场 Tab（逐行复刻网页 Plaza.tsx + TasksPanel.tsx + Leaderboard.tsx）
// 今日标签趋势 + 标签筛选 + 任务面板(琥珀色) + 无料达人/上升最快榜 + 橱窗信息流（隐藏排序栏）
struct PlazaView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var trending: [Tag] = []
    @State private var trendingLoaded = false
    @State private var includeTags: [Tag] = []
    @State private var excludeTags: [Tag] = []
    @State private var pickerOpen = false
    @State private var pickerMode = 0   // 0 包含 1 屏蔽
    @State private var pickerQ = ""
    @State private var tagResults: [Tag] = []
    @State private var checkin: CheckinStatus? = nil
    @State private var tasks: TaskProgress? = nil
    @State private var tasksExpanded = UserDefaults.standard.bool(forKey: "msl-tasks-expanded")
    @State private var claimingKey: String? = nil
    @State private var boardTab = 0     // 0 无料达人 1 上升最快
    @State private var boardPeriod = "week" // week / month
    @State private var rising: [PointsLeaderboardUser] = []
    @State private var board: [PointsLeaderboardUser] = []
    @State private var boardLoaded = false
    @State private var busy = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    trendingSection.padding(.top, 8)
                    filterSection.padding(.top, 24)
                    // 任务面板（仅登录且有数据）+ 达人榜（网页 mt-8）
                    if authManager.isAuthenticated, tasks != nil {
                        tasksCard.padding(.top, 32)
                        leaderboardSection.padding(.top, 24)
                    } else {
                        leaderboardSection.padding(.top, 32)
                    }
                    FeedView(includeTagIds: includeTags.map { $0.id },
                             excludeTagIds: excludeTags.map { $0.id },
                             hideSortBar: true)
                        .id("\(includeTags.map { $0.id })-\(excludeTags.map { $0.id })")
                        .padding(.top, 24)
                    FooterView()
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
            .background(Color.appBackground)
            .webHeader()
            .task { await load() }
            .refreshable { await load() }
        }
    }

    // MARK: 今日标签趋势（网页：flame 20 主色 + 20px 粗标题；胶囊带名次/数量）
    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "flame")
                    .font(.system(size: 20))
                    .foregroundColor(.appPrimary)
                Text("今日标签趋势")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.appForeground)
            }
            if !trendingLoaded {
                HStack(spacing: 8) {
                    ForEach([96, 112, 80], id: \.self) { w in
                        Capsule().fill(Color.appSecondary).frame(width: CGFloat(w), height: 36)
                    }
                }
            } else if trending.isEmpty {
                Text("今天还没有新发布的橱窗，第一个发布的标签会出现在这里")
                    .font(.system(size: 14))
                    .foregroundColor(.appMutedFg)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(Array(trending.enumerated()), id: \.element.id) { i, t in
                        let included = isIncluded(t)
                        Button { toggleInclude(t) } label: {
                            HStack(spacing: 6) {
                                Text("\(i + 1)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(included ? Color.appPrimaryFg.opacity(0.8) : (i == 0 ? .appPrimary : .appMutedFg))
                                Text(t.name)
                                    .font(.system(size: 14))
                                Text("\(t.todayCount ?? 0) 个新橱窗")
                                    .font(.system(size: 11))
                                    .foregroundColor(included ? Color.appPrimaryFg.opacity(0.7) : .appMutedFg)
                            }
                            .foregroundColor(included ? .appPrimaryFg : .appForeground)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(included ? Color.appPrimary : Color.appCard)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(included ? Color.appPrimary : Color.appBorder, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: 标签筛选（网页：rounded-2xl border bg-card p-4 卡片）
    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16))
                    .foregroundColor(.appPrimary)
                Text("筛选")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appForeground)
                if !includeTags.isEmpty || !excludeTags.isEmpty {
                    Spacer(minLength: 0)
                    Button {
                        includeTags = []
                        excludeTags = []
                    } label: {
                        Text("清空筛选")
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                    }
                    .buttonStyle(.plain)
                }
            }

            // 已选条件 + 添加/屏蔽按钮
            FlowLayout(spacing: 6) {
                if includeTags.isEmpty && excludeTags.isEmpty {
                    Text("未设置筛选，下方显示全部橱窗；点趋势标签或「添加标签」开始筛选")
                        .font(.system(size: 12))
                        .foregroundColor(.appMutedFg)
                }
                ForEach(includeTags) { t in
                    filterChip(t, excluded: false)
                }
                ForEach(excludeTags) { t in
                    filterChip(t, excluded: true)
                }
                // 添加标签（虚线主色）
                Button {
                    if pickerMode == 0 { pickerOpen.toggle() } else { pickerMode = 0; pickerOpen = true }
                    pickerQ = ""
                    tagResults = []
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 12))
                        Text("添加标签").font(.system(size: 12))
                    }
                    .foregroundColor(.appPrimary)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .overlay(Capsule().stroke(Color.appPrimary.opacity(0.6), style: StrokeStyle(lineWidth: 0.5, dash: [4])))
                }
                .buttonStyle(.plain)
                // 屏蔽标签（虚线灰色）
                Button {
                    if pickerMode == 1 { pickerOpen.toggle() } else { pickerMode = 1; pickerOpen = true }
                    pickerQ = ""
                    tagResults = []
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 12))
                        Text("屏蔽标签").font(.system(size: 12))
                    }
                    .foregroundColor(.appMutedFg)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .overlay(Capsule().stroke(Color.appMutedFg.opacity(0.5), style: StrokeStyle(lineWidth: 0.5, dash: [4])))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 12)

            // 标签选择器（点开才显示）
            if pickerOpen {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 0) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14))
                            .foregroundColor(.appMutedFg)
                            .padding(.leading, 12)
                        TextField(pickerMode == 0 ? "搜索要包含的标签…" : "搜索要屏蔽的标签…", text: $pickerQ)
                            .font(.system(size: 14))
                            .autocapitalization(.none)
                            .padding(.leading, 6)
                            .onChange(of: pickerQ) { _ in Task { await searchTags() } }
                    }
                    .frame(height: 36)
                    .background(Color.appCard)
                    .overlay(Capsule().stroke(Color.appInput, lineWidth: 0.5))
                    .clipShape(Capsule())

                    ScrollView(showsIndicators: false) {
                        FlowLayout(spacing: 6) {
                            ForEach(tagResults.filter { t in !includeTags.contains(where: { $0.id == t.id }) && !excludeTags.contains(where: { $0.id == t.id }) }) { t in
                                Button {
                                    if pickerMode == 0 { toggleInclude(t) } else { toggleExclude(t) }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(t.name).font(.system(size: 12))
                                        Text(categoryLabel(t.category))
                                            .font(.system(size: 10))
                                            .opacity(0.6)
                                    }
                                    .foregroundColor(.appSecondaryFg)
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(Color.appSecondary)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                            if tagResults.isEmpty {
                                Text("没有可\(pickerMode == 0 ? "包含" : "屏蔽")的标签了")
                                    .font(.system(size: 12))
                                    .foregroundColor(.appMutedFg)
                                    .padding(.vertical, 12)
                            }
                        }
                    }
                    .frame(maxHeight: 176)
                }
                .padding(12)
                .background(Color.appBackground)
                .cornerRadius(4)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 0.5))
                .padding(.top, 12)
            }

            Text("包含标签取交集（同时含有全部所选标签）；屏蔽标签取排除（含任一被屏蔽标签的橱窗不显示）。")
                .font(.system(size: 11))
                .foregroundColor(.appMutedFg)
                .padding(.top, 10)
        }
        .padding(16)
        .background(Color.appCard)
        .cornerRadius(5)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appBorder, lineWidth: 0.5))
    }

    private func categoryLabel(_ c: String?) -> String {
        switch c {
        case "work": return "作品"
        case "character": return "角色"
        case "merch": return "制品"
        case "other": return "其他"
        default: return c ?? ""
        }
    }

    // 已选条件 chip：包含=主色实心+X；屏蔽=虚线删除线+X
    private func filterChip(_ t: Tag, excluded: Bool) -> some View {
        Button {
            if excluded { excludeTags.removeAll { $0.id == t.id } }
            else { includeTags.removeAll { $0.id == t.id } }
        } label: {
            HStack(spacing: 4) {
                if excluded {
                    Text(t.name)
                        .font(.system(size: 12))
                        .strikethrough()
                        .foregroundColor(.appMutedFg)
                    Image(systemName: "xmark").font(.system(size: 11))
                        .foregroundColor(.appMutedFg)
                } else {
                    Text(t.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.appPrimaryFg)
                    Image(systemName: "xmark").font(.system(size: 11))
                        .foregroundColor(.appPrimaryFg)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(excluded ? Color.clear : Color.appPrimary)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(excluded ? Color.appMutedFg.opacity(0.5) : Color.clear,
                                      style: StrokeStyle(lineWidth: 0.5, dash: excluded ? [4] : [])))
        }
        .buttonStyle(.plain)
    }

    // MARK: 任务面板（逐行复刻 TasksPanel.tsx：琥珀色高亮卡）
    private var tasksCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 头部：礼物图标圆 + 标题 + 提示 + 展开/折叠胶囊
            HStack(spacing: 8) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.twAmber700)
                    .frame(width: 28, height: 28)
                    .background(Color.twAmber200.opacity(0.8))
                    .clipShape(Circle())
                Text("任务")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.twAmber900)
                Text("完成任务领积分 · 仅自己可见")
                    .font(.system(size: 12))
                    .foregroundColor(.twAmber600)
                Spacer(minLength: 0)
                Button {
                    tasksExpanded.toggle()
                    UserDefaults.standard.set(tasksExpanded, forKey: "msl-tasks-expanded")
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: tasksExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12))
                        Text(tasksExpanded ? "折叠" : "展开")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.twAmber800)
                    .padding(.horizontal, 12).padding(.vertical, 4)
                    .background(Color.white.opacity(0.7))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.twAmber300, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 12)

            // 签到条（网页：rounded-xl border-amber-300 渐变 amber-100→amber-50 px-4 py-3）
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.twAmber400)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    if checkin?.checkedToday == true {
                        Text("已连续签到 \(checkin?.streak ?? 0) 天")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.twAmber900)
                    } else {
                        Text((checkin?.streak ?? 0) > 0 ? "已连续签到 \(checkin?.streak ?? 0) 天，今天还没签" : "每日签到")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.twAmber900)
                    }
                    Text("连续签到 10 天 +100 · 100 天 +1000 · 200 天 +2000 · 此后每满 100 天 +2000")
                        .font(.system(size: 11))
                        .foregroundColor(.twAmber700.opacity(0.8))
                }
                Spacer(minLength: 0)
                if checkin?.checkedToday == true {
                    Text("今日已签")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.twEmerald700)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.twEmerald100)
                        .clipShape(Capsule())
                } else {
                    Button { Task { await doCheckin() } } label: {
                        Text("签到")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16).padding(.vertical, 6)
                            .background(Color.twAmber500)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(busy)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(LinearGradient(colors: [Color.twAmber100, Color.twAmber50], startPoint: .leading, endPoint: .trailing))
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.twAmber300, lineWidth: 0.5))
            .padding(.bottom, 16)

            // 每日 / 每周任务（移动端单列堆叠）
            if let t = tasks {
                taskGroup("每日任务", items: visibleTasks(t.daily ?? []))
                taskGroup("每周任务", items: visibleTasks(t.weekly ?? []))
                    .padding(.top, 16)
            }
        }
        .padding(16)
        .background(Color.appCard)
        .cornerRadius(5)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appBorder, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }

    // 折叠逻辑与网页一致：完成且已领取的收起；全完成奖励条未领取前保留
    private func visibleTasks(_ list: [TaskItem]) -> [TaskItem] {
        if tasksExpanded { return list }
        return list.filter { $0.key.hasSuffix("_all") ? !$0.claimed : !($0.done && $0.claimed) }
    }

    // 网页 TASK_META 文案逐条一致
    private func taskMeta(_ key: String) -> (label: String, hint: String?) {
        switch key {
        case "daily_login": return ("登录网站", "已登录即完成")
        case "daily_browse5": return ("浏览 5 个橱窗", nil)
        case "daily_feedback5": return ("给出 5 次反馈", "点赞 / 返图 / 领到了 / 我想要 都算")
        case "daily_cardbrowse3": return ("浏览 3 次卡片广场的卡片", nil)
        case "daily_cardfeedback1": return ("给出 1 次卡片反馈", "卡片点赞 / 想要 / 收藏 / 评论 都算")
        case "weekly_publish1": return ("发布 1 个橱窗", nil)
        case "weekly_cardcomment1": return ("评论 1 次卡片", nil)
        case "weekly_share1": return ("分享 1 次橱窗", "点橱窗「分享」，发给好友或复制链接都算")
        case "daily_all": return ("完成全部每日任务", nil)
        case "weekly_all": return ("完成全部每周任务", nil)
        default: return (key, nil)
        }
    }

    private func taskGroup(_ title: String, items: [TaskItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.twAmber700)
                .textCase(.uppercase)
                .tracking(0.5)
            ForEach(items) { item in
                taskRow(item)
            }
        }
    }

    // 单条任务（网页 TaskRow：图标 + 文案 + 进度 + 领取按钮 + 进度条）
    private func taskRow(_ item: TaskItem) -> some View {
        let meta = taskMeta(item.key)
        let isBonus = item.key.hasSuffix("_all")
        let pct = item.goal > 0 ? min(1.0, Double(item.progress) / Double(item.goal)) : 0
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: item.claimed ? "checkmark.circle" : "circle")
                    .font(.system(size: 15))
                    .foregroundColor(item.claimed ? .twEmerald500 : (item.done ? .twAmber500 : .twAmber300))
                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(meta.label)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.twAmber900)
                        Text("+\(item.reward)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.twAmber600)
                    }
                    if let hint = meta.hint {
                        Text(hint)
                            .font(.system(size: 11))
                            .foregroundColor(.twAmber700.opacity(0.7))
                    }
                }
                Spacer(minLength: 0)
                Text("\(item.progress)/\(item.goal)")
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundColor(.twAmber700)
                if item.claimed {
                    Text("已领取")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.twEmerald700)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Color.twEmerald100)
                        .clipShape(Capsule())
                } else if item.done {
                    Button { Task { await claimTask(item.key) } } label: {
                        Text("领取")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10).padding(.vertical, 2)
                            .background(Color.twAmber500)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(claimingKey != nil)
                }
            }
            // 进度条 h-1.5
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.twAmber100).frame(height: 6)
                    Capsule()
                        .fill(item.claimed ? Color.twEmerald400 : (item.done ? Color.twAmber500 : Color.twAmber300))
                        .frame(width: geo.size.width * pct, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(isBonus ? Color.twAmber100.opacity(0.8) : Color.white.opacity(0.6))
        .cornerRadius(3)
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(isBonus ? Color.twAmber300 : Color.twAmber200.opacity(0.7), lineWidth: 0.5))
    }

    // MARK: 无料达人榜 / 上升最快（逐行复刻 Leaderboard.tsx）
    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 顶部切换：主胶囊组（无料达人/上升最快）+ 周期组（周榜/月榜）+ 右侧说明
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        boardTabBtn(0, "无料达人")
                        boardTabBtn(1, "上升最快")
                    }
                    .padding(2)
                    .background(Color.appCard)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))

                    if boardTab == 0 {
                        HStack(spacing: 2) {
                            periodBtn("week", "周榜")
                            periodBtn("month", "月榜")
                        }
                        .padding(2)
                        .background(Color.appCard)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                    }
                    Spacer(minLength: 0)
                }
                Text(boardTab == 1 ? "按本周较上周的积分涨幅排名" : "按农场可用积分排名（总积分-已消耗）· 每周日 23:59 定榜，第一名 +100 分")
                    .font(.system(size: 11))
                    .foregroundColor(.appMutedFg)
            }

            // 榜单容器（rounded-2xl border bg-card，行间分隔线）
            VStack(spacing: 0) {
                if boardTab == 0 {
                    if board.isEmpty && boardLoaded {
                        Text("本期还没有人上榜，去发布橱窗攒积分吧～")
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                    } else {
                        ForEach(Array(board.enumerated()), id: \.element.id) { i, u in
                            boardRow(u, index: i)
                        }
                    }
                } else {
                    if rising.isEmpty && boardLoaded {
                        Text("本周还没有新的积分变化")
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                    } else {
                        ForEach(Array(rising.enumerated()), id: \.element.id) { i, u in
                            risingRow(u, index: i)
                        }
                    }
                }
            }
            .background(Color.appCard)
            .cornerRadius(5)
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appBorder, lineWidth: 0.5))
            .clipped()
        }
    }

    private func boardTabBtn(_ idx: Int, _ label: String) -> some View {
        Button {
            boardTab = idx
            Task { await loadBoard() }
        } label: {
            Text(label)
                .font(.system(size: 12, weight: boardTab == idx ? .medium : .regular))
                .foregroundColor(boardTab == idx ? .appPrimaryFg : .appMutedFg)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(boardTab == idx ? Color.appPrimary : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func periodBtn(_ key: String, _ label: String) -> some View {
        Button {
            boardPeriod = key
            Task { await loadBoard() }
        } label: {
            Text(label)
                .font(.system(size: 11, weight: boardPeriod == key ? .medium : .regular))
                .foregroundColor(boardPeriod == key ? .appSecondaryFg : .appMutedFg)
                .padding(.horizontal, 10).padding(.vertical, 2)
                .background(boardPeriod == key ? Color.appSecondary : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // 达人榜行：第一名皇冠+母鸡，2/3 名特殊色，头像+昵称+等级+头衔+积分
    private func boardRow(_ u: PointsLeaderboardUser, index i: Int) -> some View {
        NavigationLink(destination: ProfileView(userId: u.userId)) {
            HStack(spacing: 10) {
                if i == 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.twAmber500)
                        AsyncImage(url: URL(string: "https://mashangling.kimi.site/hen.png")) { img in
                            img.resizable().interpolation(.none).scaledToFit()
                        } placeholder: { Color.clear }
                        .frame(width: 18, height: 18)
                    }
                    .frame(width: 28)
                } else {
                    Text("\(i + 1)")
                        .font(.system(size: 12, weight: .bold))
                        .monospacedDigit()
                        .foregroundColor(i == 1 ? Color.twSlate400 : (i == 2 ? Color.twAmber700.opacity(0.7) : Color.appMutedFg))
                        .frame(width: 28)
                }
                AvatarView(path: u.avatar, name: u.name ?? "", size: 28)
                HStack(spacing: 4) {
                    Text(u.name ?? "未知用户")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.appForeground)
                        .lineLimit(1)
                    if let lv = u.level { LevelBadgeView(level: lv) }
                    TitleBadgeView(equippedTitle: u.equippedTitle, plain: true)
                }
                Spacer(minLength: 0)
                (Text("\(u.points ?? 0)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.appPrimary)
                 + Text(" 分")
                    .font(.system(size: 10))
                    .foregroundColor(.appMutedFg))
                    .monospacedDigit()
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .overlay(alignment: .bottom) {
                if i < board.count - 1 {
                    Rectangle().fill(Color.appBorder.opacity(0.6)).frame(height: 0.5)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // 上升最快行：🔥⚡🚀/🌱 + 上周→本周 + 涨幅胶囊
    private func risingRow(_ u: PointsLeaderboardUser, index i: Int) -> some View {
        let marks = ["🔥", "⚡", "🚀"]
        let mark = (u.rise ?? 0) > 0 ? marks[min(2, i)] : "🌱"
        return NavigationLink(destination: ProfileView(userId: u.userId)) {
            HStack(spacing: 10) {
                Text(mark)
                    .font(.system(size: 14))
                    .frame(width: 24)
                AvatarView(path: u.avatar, name: u.name ?? "", size: 28)
                HStack(spacing: 4) {
                    Text(u.name ?? "未知用户")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.appForeground)
                        .lineLimit(1)
                    TitleBadgeView(equippedTitle: u.equippedTitle, plain: true)
                }
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    Text("上周 \(u.lastWeekPoints ?? 0) → 本周 \(u.weekPoints ?? 0)")
                        .font(.system(size: 11))
                        .foregroundColor(.appMutedFg)
                    Text((u.rise ?? 0) > 0 ? "+\(u.rise ?? 0)" : "\(u.rise ?? 0)")
                        .font(.system(size: 11, weight: .bold))
                        .monospacedDigit()
                        .foregroundColor((u.rise ?? 0) > 0 ? Color(h: 140, s: 16, l: 42) : .appMutedFg)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background((u.rise ?? 0) > 0 ? Color.twEmerald500.opacity(0.1) : Color.appSecondary)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .overlay(alignment: .bottom) {
                if i < rising.count - 1 {
                    Rectangle().fill(Color.appBorder.opacity(0.6)).frame(height: 0.5)
                }
            }
        }
        .buttonStyle(.plain)
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
        tagResults = (try? await MashanglingAPI.shared.tag.search(q: pickerQ, limit: 20)) ?? []
    }

    private func load() async {
        trending = (try? await MashanglingAPI.shared.tag.trendingToday()) ?? []
        trendingLoaded = true
        await loadBoard()
        guard authManager.isAuthenticated else { return }
        checkin = try? await MashanglingAPI.shared.task.checkinStatus()
        tasks = try? await MashanglingAPI.shared.task.mine()
    }

    private func loadBoard() async {
        if boardTab == 0 {
            board = (try? await MashanglingAPI.shared.points.leaderboard(period: boardPeriod)) ?? []
        } else {
            rising = (try? await MashanglingAPI.shared.points.rising(limit: 5)) ?? []
        }
        boardLoaded = true
    }

    private func doCheckin() async {
        busy = true
        defer { busy = false }
        do {
            let r = try await MashanglingAPI.shared.task.checkin()
            if r.already == true {
                ToastCenter.shared.success("今天已经签到过了")
            } else if (r.reward ?? 0) > 0 {
                ToastCenter.shared.success("连续签到 \(r.streak ?? 0) 天，奖励 +\(r.reward ?? 0) 积分！")
            } else {
                ToastCenter.shared.success("签到成功，已连续 \(r.streak ?? 0) 天")
            }
            checkin = try? await MashanglingAPI.shared.task.checkinStatus()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func claimTask(_ key: String) async {
        claimingKey = key
        defer { claimingKey = nil }
        do {
            let r = try await MashanglingAPI.shared.task.claim(taskKey: key)
            ToastCenter.shared.success(r.already == true ? "该奖励已领取过" : "领取成功，+\(r.reward ?? 0) 积分")
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
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 0.5))
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
