import SwiftUI
import Charts

// MARK: - 领取申请（发布者审批，对应网页 Claims.tsx）
struct ClaimsView: View {
    /// 详情页胶囊直达：0=领取申请 1=我想要 2=补货提醒
    var initialTab: Int = 0

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
        .task { tab = initialTab; await load() }
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
                    .cornerRadius(4)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 0.5))
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
    @State private var my: PointsMy? = nil
    @State private var busy = false

    /// TITLES 固定顺序（对应 contracts/levels.ts 的 Object.entries 顺序）
    private let titleOrder = ["eggking", "buyking", "weeklyking", "seveneggs"]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text("积分与等级")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.appForeground)
                Text("发布橱窗 +10 · 被返图 +5 · 被领到了 +3 · 被点赞 +2 · 发布返图 +1（「没有了」「我想要」不计分）")
                    .font(.system(size: 14))
                    .foregroundColor(.appMutedFg)
                    .padding(.top, 6)

                levelCard
                    .padding(.top, 24)
                titlesCard
                    .padding(.top, 24)
                levelsTableCard
                    .padding(.top, 24)
            }
            .padding(.horizontal, 16)
            .padding(.top, 32)
            .padding(.bottom, 32)
        }
        .background(Color.appBackground)
        .navigationTitle("积分与等级")
        .navigationBarTitleDisplayMode(.inline)
        .task { my = try? await MashanglingAPI.shared.points.my() }
        .refreshable { my = try? await MashanglingAPI.shared.points.my() }
    }

    // 我的等级卡
    private var levelCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let m = my {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.appPrimary.opacity(0.1))
                        Image(systemName: "oval")
                            .font(.system(size: 24))
                            .foregroundColor(.appPrimary)
                    }
                    .frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("Lv.\(m.level)")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundColor(.appForeground)
                            Text(m.band)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.appPrimary)
                        }
                        Text("总积分 \(m.points) · 本周 \(m.weekPoints ?? 0) · 本月 \(m.monthPoints ?? 0)")
                            .font(.system(size: 14))
                            .foregroundColor(.appMutedFg)
                            .padding(.top, 6)
                    }
                }
                if m.maxLevel == true {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                        Text("已达满级 30 级，传说鸡舍主！")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.fixAmber600)
                    .padding(.top, 16)
                } else {
                    let pct: Double = m.need > 0 ? min(1.0, Double(m.into) / Double(m.need)) : 1.0
                    Capsule()
                        .fill(Color.appSecondary)
                        .frame(height: 10)
                        .overlay(alignment: .leading) {
                            GeometryReader { g in
                                Capsule()
                                    .fill(Color.appPrimary)
                                    .frame(width: g.size.width * pct)
                            }
                        }
                        .padding(.top, 16)
                    Text("距 Lv.\(m.level + 1) 还需 \(m.need - m.into) 分（本级 \(m.into)/\(m.need)）")
                        .font(.system(size: 12))
                        .foregroundColor(.appMutedFg)
                        .padding(.top, 6)
                }
            } else {
                Text("加载中…")
                    .font(.system(size: 14))
                    .foregroundColor(.appMutedFg)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCard)
        .cornerRadius(5)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appBorder, lineWidth: 1))
    }

    // 头衔卡
    private var titlesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 18))
                    .foregroundColor(.appPrimary)
                Text("头衔")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.appForeground)
            }
            Text("无料达人周榜按农场可用积分（总积分-已消耗）排名，每周日 23:59 定榜，第一名获得「周榜冠军」头衔和 100 积分奖励；头衔佩戴后全站可见。")
                .font(.system(size: 12))
                .foregroundColor(.appMutedFg)
                .padding(.top, 4)
            VStack(spacing: 10) {
                ForEach(titleOrder, id: \.self) { key in
                    let meta = Levels.titles[key] ?? (key, "🏅", "")
                    let owned = my?.titles?.first(where: { $0.key == key })
                    titleRow(meta: meta, owned: owned, key: key)
                }
            }
            .padding(.top, 16)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCard)
        .cornerRadius(5)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appBorder, lineWidth: 1))
    }

    private func titleRow(meta: (label: String, icon: String, desc: String), owned: PointsMy.TitleItem?, key: String) -> some View {
        HStack(spacing: 12) {
            Text(meta.icon)
                .font(.system(size: 24))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(meta.label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.appForeground)
                    if owned?.equipped == true {
                        Text("佩戴中")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.fixAmber700)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.fixAmber100)
                            .clipShape(Capsule())
                    }
                }
                Text(meta.desc)
                    .font(.system(size: 12))
                    .foregroundColor(.appMutedFg)
                if let o = owned {
                    Text("获得于 \(DateFmt.zhDate(o.earnedAt))")
                        .font(.system(size: 11))
                        .foregroundColor(.appMutedFg)
                }
            }
            Spacer()
            if let o = owned {
                Button { Task { await equip(key: key, currentlyEquipped: o.equipped) } } label: {
                    Text(o.equipped ? "取下" : "佩戴")
                        .font(.system(size: 13, weight: o.equipped ? .regular : .medium))
                        .foregroundColor(o.equipped ? .appForeground : .appPrimaryFg)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(o.equipped ? Color.clear : Color.appPrimary)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(o.equipped ? Color.appBorder : Color.clear, lineWidth: 1))
                }
                .disabled(busy)
            } else {
                Text("未获得")
                    .font(.system(size: 12))
                    .foregroundColor(.appMutedFg)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 1))
    }

    // 等级一览（30 级）
    private var levelsTableCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("等级一览（30 级）")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.appForeground)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(levelRows(), id: \.0) { row in
                    let current = my?.level == row.0
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 6) {
                            Text("Lv.\(row.0)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.appForeground)
                            if current {
                                Text("当前")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.appPrimary)
                            }
                        }
                        Text(row.1)
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                        Text("累计 \(row.2.formatted(.number.grouping(.automatic))) 分")
                            .font(.system(size: 11))
                            .monospacedDigit()
                            .foregroundColor(.appMutedFg)
                            .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(current ? Color.appPrimary.opacity(0.05) : Color.clear)
                    .cornerRadius(4)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(current ? Color.appPrimary : Color.appBorder, lineWidth: 1))
                    .overlay(current ? RoundedRectangle(cornerRadius: 5).stroke(Color.appPrimary.opacity(0.3), lineWidth: 1).padding(-1) : nil)
                }
            }
            .padding(.top, 16)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCard)
        .cornerRadius(5)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appBorder, lineWidth: 1))
    }

    /// LEVEL_TABLE：从 1 级升到每一级所需的累计积分
    private func levelRows() -> [(Int, String, Int)] {
        (1...Levels.maxLevel).map { lv in
            var cum = 0
            for n in 1..<lv { cum += Levels.needForLevel(n) }
            return (lv, Levels.band(of: lv), cum)
        }
    }

    private func equip(key: String, currentlyEquipped: Bool) async {
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.points.equipTitle(currentlyEquipped ? nil : key)
            ToastCenter.shared.success(currentlyEquipped ? "已取下头衔" : "已佩戴头衔")
            my = try? await MashanglingAPI.shared.points.my()
            await AuthManager.shared.checkAuth()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}

// MARK: - 积分记录（对应网页 PointRecords.tsx）
struct PointRecordsView: View {
    private let filters: [(key: String, label: String)] = [
        ("all", "全部"), ("interact", "互动收入"), ("publish", "发布"), ("task", "任务/签到"),
        ("browse", "浏览兑换"), ("heart", "心选橱窗"), ("farm", "农场储蓄"), ("spend", "支出"),
    ]

    @State private var kind = "all"
    @State private var showChart = false
    @State private var records: [PointLogRow]? = nil
    @State private var my: PointsMy? = nil

    private struct ChartPoint: Identifiable {
        let id = UUID()
        let time: String
        let balance: Int
        let delta: Int
        let label: String
    }

    private var filtered: [PointLogRow] {
        (records ?? []).filter { kind == "all" || $0.kind == kind }
    }

    private func sumFor(_ key: String) -> Int {
        (records ?? []).filter { key == "all" || $0.kind == key }.reduce(0) { $0 + $1.delta }
    }

    /// 「全部」= 从当前余额倒推真实余额轨迹；分类 = 从 0 起净累计
    private var chartData: [ChartPoint] {
        let all = records ?? []
        let isAll = kind == "all"
        let cur = my?.points ?? 0
        var balAfter = [Int](repeating: 0, count: all.count)
        var acc = 0
        for i in 0..<all.count {
            balAfter[i] = cur - acc
            acc += all[i].delta
        }
        var points: [ChartPoint] = []
        var catBal = 0
        if all.count > 0 {
            for i in stride(from: all.count - 1, through: 0, by: -1) {
                let r = all[i]
                if !(kind == "all" || r.kind == kind) { continue }
                catBal += r.delta
                points.append(ChartPoint(time: Self.mdhm(r.createdAt), balance: isAll ? balAfter[i] : catBal, delta: r.delta, label: r.label))
            }
        }
        return points
    }

    private static func mdhm(_ s: String?) -> String {
        guard let d = DateFmt.parse(s) else { return "" }
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f.string(from: d)
    }

    private var kindLabel: String {
        filters.first(where: { $0.key == kind })?.label ?? ""
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 22))
                        .foregroundColor(.appPrimary)
                    Text("积分记录")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.appForeground)
                }
                Text("展示最近 200 条积分增减（含来源），仅自己可见。")
                    .font(.system(size: 12))
                    .foregroundColor(.appMutedFg)
                    .padding(.top, 4)

                // 分类胶囊 + 图表切换
                FlowLayout(spacing: 6) {
                    ForEach(filters, id: \.key) { f in
                        Button { kind = f.key } label: {
                            HStack(spacing: 4) {
                                Text(f.label)
                                if (records?.count ?? 0) > 0 {
                                    let s = sumFor(f.key)
                                    Text(s >= 0 ? "+\(s)" : "\(s)")
                                        .monospacedDigit()
                                        .foregroundColor(kind == f.key ? Color.appPrimaryFg.opacity(0.8) : .appMutedFg)
                                }
                            }
                            .font(.system(size: 12, weight: kind == f.key ? .medium : .regular))
                            .foregroundColor(kind == f.key ? .appPrimaryFg : .appSecondaryFg)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(kind == f.key ? Color.appPrimary : Color.appSecondary)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    Button { showChart.toggle() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chart.xyaxis.line")
                                .font(.system(size: 12))
                            Text(showChart ? "查看列表" : "切换图表")
                        }
                        .font(.system(size: 12, weight: showChart ? .medium : .regular))
                        .foregroundColor(showChart ? .appPrimaryFg : .appSecondaryFg)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(showChart ? Color.appPrimary : Color.appSecondary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 12)

                if showChart {
                    chartCard
                        .padding(.top, 16)
                }

                if records == nil {
                    VStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.appSecondary)
                                .frame(height: 56)
                        }
                    }
                    .padding(.top, 16)
                } else if showChart {
                    EmptyView()
                } else if filtered.isEmpty {
                    Text("该分类下还没有积分记录")
                        .font(.system(size: 14))
                        .foregroundColor(.appMutedFg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 64)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 1, dash: [6])))
                        .padding(.top, 16)
                } else {
                    VStack(spacing: 6) {
                        ForEach(filtered) { r in
                            recordRow(r)
                        }
                    }
                    .padding(.top, 16)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground)
        .navigationTitle("积分记录")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            async let rec = try? MashanglingAPI.shared.points.records()
            async let m = try? MashanglingAPI.shared.points.my()
            records = await rec ?? []
            my = await m
        }
        .refreshable {
            async let rec = try? MashanglingAPI.shared.points.records()
            async let m = try? MashanglingAPI.shared.points.my()
            records = await rec ?? []
            my = await m
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(kind == "all"
                 ? "积分余额曲线（全部；展示最近 \(filtered.count) 条记录）"
                 : "分类净积分曲线（\(kindLabel)，从 0 起累计；展示最近 \(filtered.count) 条记录）")
                .font(.system(size: 12))
                .foregroundColor(.appMutedFg)
                .padding(.bottom, 8)
            if filtered.count < 2 {
                Text("该分类下记录不足，无法生成曲线")
                    .font(.system(size: 12))
                    .foregroundColor(.appMutedFg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                Chart(chartData) { p in
                    LineMark(
                        x: .value("时间", p.time),
                        y: .value("积分", p.balance)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color(h: 337, s: 80, l: 61))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(.system(size: 10))
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                            .foregroundStyle(Color.appBorder)
                        AxisValueLabel()
                            .font(.system(size: 10))
                    }
                }
                .frame(height: 208)
            }
        }
        .padding(16)
        .background(Color.appCard)
        .cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 1))
    }

    @ViewBuilder
    private func recordRow(_ r: PointLogRow) -> some View {
        let earn = r.delta > 0
        let content = HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(earn ? Color.fixEmerald600.opacity(0.1) : Color.fixRed500.opacity(0.1))
                Image(systemName: earn ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 14))
                    .foregroundColor(earn ? .fixEmerald600 : .fixRed500)
            }
            .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(r.label)
                    .font(.system(size: 14))
                    .foregroundColor(.appForeground)
                    .lineLimit(1)
                Text(DateFmt.zhFull(r.createdAt))
                    .font(.system(size: 11))
                    .foregroundColor(.appMutedFg)
            }
            Spacer()
            Text(earn ? "+\(r.delta)" : "\(r.delta)")
                .font(.system(size: 14, weight: .bold))
                .monospacedDigit()
                .foregroundColor(earn ? .fixEmerald600 : .fixRed500)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.appCard)
        .cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 1))

        if let sid = r.showcaseId {
            NavigationLink(destination: ShowcaseDetailView(showcaseId: sid)) {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }
}
