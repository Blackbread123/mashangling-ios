import SwiftUI

// MARK: - 个人数据看板（对应网页 StatsDashboard.tsx，仅本人可见）
struct StatsDashboardView: View {
    @State private var stats: StatsDashboardData? = nil
    @State private var trend: StatsTrend? = nil
    @State private var period = "week"          // week / month / year
    @State private var hidden: Set<String> = []

    private let periods: [(key: String, label: String)] = [
        ("week", "本周"), ("month", "本月"), ("year", "今年"),
    ]

    private struct Metric: Identifiable {
        let key: String
        let label: String
        let icon: String
        let color: Color
        var id: String { key }
    }

    // 与网页 CHART_CONFIG 完全一致的 HSL 配色
    private let metrics: [Metric] = [
        Metric(key: "followers",      label: "粉丝",   icon: "person.badge.plus",      color: Color(h: 262, s: 83, l: 58)),
        Metric(key: "views",          label: "浏览",   icon: "eye",                    color: Color(h: 215, s: 16, l: 47)),
        Metric(key: "likes",          label: "点赞",   icon: "heart.fill",             color: Color(h: 337, s: 80, l: 61)),
        Metric(key: "wants",          label: "想要",   icon: "hand.raised",            color: Color(h: 38,  s: 92, l: 50)),
        Metric(key: "claimed",        label: "领到",   icon: "checkmark.circle.fill",  color: Color(h: 160, s: 84, l: 39)),
        Metric(key: "reposts",        label: "返图",   icon: "photo",                  color: Color(h: 217, s: 91, l: 60)),
        Metric(key: "shares",         label: "分享",   icon: "square.and.arrow.up",    color: Color(h: 190, s: 90, l: 42)),
        Metric(key: "showcasePoints", label: "橱窗积分", icon: "dollarsign.circle.fill", color: Color(h: 45,  s: 95, l: 42)),
    ]

    var body: some View {
        Group {
            if let d = stats {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    chips(d)
                    chart
                    topGrid(d)
                }
                .padding(16)
                .background(Color.appCard)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appBorder, lineWidth: 0.5))
            }
        }
        .task { await loadAll() }
        .onChange(of: period) { _ in Task { await loadTrend() } }
    }

    // MARK: 标题行（图标 + 标题 + 仅自己可见 + 周期切换）
    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 15))
                .foregroundColor(.appPrimary)
            Text("数据看板")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.appForeground)
            Text("仅自己可见")
                .font(.system(size: 10))
                .foregroundColor(.appMutedFg)
            Spacer(minLength: 0)
            HStack(spacing: 2) {
                ForEach(periods, id: \.key) { p in
                    Button {
                        period = p.key
                    } label: {
                        Text(p.label)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(period == p.key ? .appPrimaryFg : .appMutedFg)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(period == p.key ? Color.appPrimary : Color.clear)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
        }
    }

    // MARK: 指标图例（点按显示/隐藏对应折线）
    private func chips(_ d: StatsDashboardData) -> some View {
        FlowLayout(spacing: 6) {
            ForEach(metrics) { m in
                let c = counts(of: m.key, d)
                let off = hidden.contains(m.key)
                Button {
                    toggleMetric(m.key)
                } label: {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(off ? Color.clear : m.color)
                            .frame(width: 7, height: 7)
                            .overlay(Circle().stroke(m.color, lineWidth: 1.2))
                        Image(systemName: m.icon).font(.system(size: 9))
                        Text(m.label).font(.system(size: 11, weight: .medium))
                        Text("\(c.value(for: period))")
                            .font(.system(size: 11, weight: .bold))
                        Text("/ 累计 \(c.total)")
                            .font(.system(size: 10))
                            .foregroundColor(.appMutedFg)
                    }
                    .foregroundColor(off ? .appMutedFg.opacity(0.6) : .appForeground)
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(off ? Color.clear : Color.appSecondary.opacity(0.4))
                    .cornerRadius(14)
                    .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: 趋势折线图
    private var chart: some View {
        let visible = metrics.filter { !hidden.contains($0.key) }
        return Group {
            if visible.isEmpty {
                Text("所有统计量都已隐藏，点上方图例恢复显示")
                    .font(.system(size: 12))
                    .foregroundColor(.appMutedFg)
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
            } else {
                MultiLineChartView(
                    labels: trend?.labels ?? [],
                    series: visible.map { ($0.label, $0.color, seriesValues($0.key)) }
                )
                .frame(height: 200)
            }
        }
    }

    // MARK: 各指标橱窗前三
    private func topGrid(_ d: StatsDashboardData) -> some View {
        let withTop = metrics.filter { $0.key != "followers" }
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(withTop) { m in
                let items = topItems(of: m.key, d)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: m.icon).font(.system(size: 9))
                        Text(m.key == "showcasePoints"
                             ? "橱窗积分最多的橱窗"
                             : "\(periods.first { $0.key == period }?.label ?? "本周")\(m.label)最多的橱窗")
                            .font(.system(size: 11, weight: .medium))
                        if m.key == "views" {
                            Text("（登录用户）").font(.system(size: 9))
                        }
                    }
                    .foregroundColor(.appMutedFg)

                    if items.isEmpty {
                        Text("这个周期还没有\(m.label)记录")
                            .font(.system(size: 11))
                            .foregroundColor(.appMutedFg.opacity(0.7))
                    } else {
                        ForEach(Array(items.prefix(3).enumerated()), id: \.element.id) { i, t in
                            NavigationLink(destination: ShowcaseDetailView(showcaseId: t.showcaseId)) {
                                HStack(spacing: 8) {
                                    Text("\(i + 1)")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(rankStyle(i).fg)
                                        .frame(width: 18, height: 18)
                                        .background(rankStyle(i).bg)
                                        .cornerRadius(9)
                                    Text(t.title)
                                        .font(.system(size: 12))
                                        .foregroundColor(.appForeground)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                    Text("\(t.count)")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.appMutedFg)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appBorder, lineWidth: 0.5))
            }
        }
    }

    private func rankStyle(_ i: Int) -> (fg: Color, bg: Color) {
        switch i {
        case 0: return (Color(h: 38, s: 92, l: 40), Color(h: 45, s: 95, l: 51).opacity(0.15))
        case 1: return (Color(h: 215, s: 16, l: 47), Color(h: 215, s: 16, l: 47).opacity(0.15))
        default: return (Color(h: 25, s: 90, l: 50), Color(h: 25, s: 95, l: 53).opacity(0.15))
        }
    }

    // MARK: 数据访问
    private func counts(of key: String, _ d: StatsDashboardData) -> StatsDashboardData.StatsPeriodCounts {
        switch key {
        case "followers": return d.followers
        case "views": return d.views.counts
        case "likes": return d.likes.counts
        case "wants": return d.wants.counts
        case "claimed": return d.claimed.counts
        case "reposts": return d.reposts.counts
        case "shares": return d.shares.counts
        default: return d.showcasePoints
        }
    }

    private func topItems(of key: String, _ d: StatsDashboardData) -> [StatsDashboardData.StatsTopItem] {
        switch key {
        case "views": return d.views.top.items(for: period)
        case "likes": return d.likes.top.items(for: period)
        case "wants": return d.wants.top.items(for: period)
        case "claimed": return d.claimed.top.items(for: period)
        case "reposts": return d.reposts.top.items(for: period)
        case "shares": return d.shares.top.items(for: period)
        default: return d.showcasePointTop ?? []
        }
    }

    private func seriesValues(_ key: String) -> [Int] {
        let s = trend?.series
        switch key {
        case "followers": return s?.followers ?? []
        case "views": return s?.views ?? []
        case "likes": return s?.likes ?? []
        case "wants": return s?.wants ?? []
        case "claimed": return s?.claimed ?? []
        case "reposts": return s?.reposts ?? []
        case "shares": return s?.shares ?? []
        default: return s?.showcasePoints ?? []
        }
    }

    private func toggleMetric(_ key: String) {
        if hidden.contains(key) {
            hidden.remove(key)
        } else if hidden.count < metrics.count - 1 {
            hidden.insert(key)
        }
    }

    private func loadAll() async {
        stats = try? await MashanglingAPI.shared.stats.dashboard()
        await loadTrend()
    }

    private func loadTrend() async {
        trend = try? await MashanglingAPI.shared.stats.trend(period: period)
    }
}

// MARK: - 卡片广场数据（对应网页 CardStatsPanel，仅本人可见；浏览量只统计累计）
struct CardStatsPanelView: View {
    @State private var stats: StatsDashboardData? = nil
    @State private var trend: StatsTrend? = nil
    @State private var period = "week"
    @State private var hidden: Set<String> = []
    @State private var openedPostId: IdentifiedInt? = nil

    private let periods: [(key: String, label: String)] = [
        ("week", "本周"), ("month", "本月"), ("year", "今年"),
    ]

    private struct CMetric: Identifiable {
        let key: String       // dashboard.cards 的 key
        let trendKey: String? // trend.series 的 key（浏览无日数据）
        let label: String
        let color: Color
        var id: String { key }
    }

    private let metrics: [CMetric] = [
        CMetric(key: "views",     trendKey: nil,             label: "浏览", color: Color(h: 215, s: 16, l: 47)),
        CMetric(key: "likes",     trendKey: "cardLikes",     label: "点赞", color: Color(h: 337, s: 80, l: 61)),
        CMetric(key: "wants",     trendKey: "cardWants",     label: "想要", color: Color(h: 38,  s: 92, l: 50)),
        CMetric(key: "comments",  trendKey: "cardComments",  label: "评论", color: Color(h: 217, s: 91, l: 60)),
        CMetric(key: "shares",    trendKey: "cardShares",    label: "转发", color: Color(h: 190, s: 90, l: 42)),
        CMetric(key: "favorites", trendKey: "cardFavorites", label: "收藏", color: Color(h: 45,  s: 95, l: 42)),
    ]

    var body: some View {
        Group {
            if let d = stats, hasAny(d) {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    chips(d)
                    barChart
                    topGrid(d)
                }
                .padding(16)
                .background(Color.appCard)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appBorder, lineWidth: 0.5))
            }
        }
        .task { await loadAll() }
        .onChange(of: period) { _ in Task { await loadTrend() } }
        .sheet(item: $openedPostId) { pid in
            CardDetailSheet(postId: pid.value) { openedPostId = nil }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "megaphone.fill")
                .font(.system(size: 14))
                .foregroundColor(.appPrimary)
            Text("卡片广场数据")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.appForeground)
            Text("仅自己可见 · 浏览量只统计累计")
                .font(.system(size: 10))
                .foregroundColor(.appMutedFg)
                .lineLimit(1)
            Spacer(minLength: 0)
            HStack(spacing: 2) {
                ForEach(periods, id: \.key) { p in
                    Button {
                        period = p.key
                    } label: {
                        Text(p.label)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(period == p.key ? .appPrimaryFg : .appMutedFg)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(period == p.key ? Color.appPrimary : Color.clear)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
        }
    }

    private func chips(_ d: StatsDashboardData) -> some View {
        FlowLayout(spacing: 6) {
            ForEach(metrics) { m in
                let c = cardCounts(of: m.key, d)
                let off = hidden.contains(m.key)
                Button {
                    if hidden.contains(m.key) { hidden.remove(m.key) }
                    else if hidden.count < metrics.count - 1 { hidden.insert(m.key) }
                } label: {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(off ? Color.clear : m.color)
                            .frame(width: 7, height: 7)
                            .overlay(Circle().stroke(m.color, lineWidth: 1.2))
                        Text(m.label).font(.system(size: 11, weight: .medium))
                        if m.trendKey != nil {
                            Text("\(c.value(for: period))")
                                .font(.system(size: 11, weight: .bold))
                        }
                        Text(m.trendKey == nil ? "累计 \(c.total)" : "/ 累计 \(c.total)")
                            .font(.system(size: 10))
                            .foregroundColor(.appMutedFg)
                    }
                    .foregroundColor(off ? .appMutedFg.opacity(0.6) : .appForeground)
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(off ? Color.clear : Color.appSecondary.opacity(0.4))
                    .cornerRadius(14)
                    .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: 柱状图（每天一组细柱，对应网页 BarChart）
    private var barChart: some View {
        let visible = metrics.filter { $0.trendKey != nil && !hidden.contains($0.key) }
        return Group {
            if visible.isEmpty {
                Text("所有统计量都已隐藏，点上方图例恢复显示")
                    .font(.system(size: 12))
                    .foregroundColor(.appMutedFg)
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
            } else {
                MultiBarChartView(
                    labels: trend?.labels ?? [],
                    series: visible.map { ($0.label, $0.color, trendValues($0.trendKey!)) }
                )
                .frame(height: 180)
            }
        }
    }

    private func topGrid(_ d: StatsDashboardData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(metrics) { m in
                topCard(for: m, d)
            }
        }
    }

    @ViewBuilder
    private func topCard(for m: CMetric, _ d: StatsDashboardData) -> some View {
        let items = cardTopItems(of: m.key, d)
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(periods.first { $0.key == period }?.label ?? "本周")\(m.label)最多的卡片")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.appMutedFg)
                ForEach(Array(items.prefix(2).enumerated()), id: \.element.id) { i, t in
                    Button { openedPostId = IdentifiedInt(t.postId) } label: {
                        HStack(spacing: 8) {
                            Text("\(i + 1)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Color(h: 38, s: 92, l: 40))
                                .frame(width: 18, height: 18)
                                .background(Color(h: 45, s: 95, l: 51).opacity(0.15))
                                .cornerRadius(9)
                            Text(t.title)
                                .font(.system(size: 12))
                                .foregroundColor(.appForeground)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text("\(t.count)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.appMutedFg)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appBorder, lineWidth: 0.5))
        }
    }

    // MARK: 数据访问
    private func hasAny(_ d: StatsDashboardData) -> Bool {
        [d.cards.views, d.cards.likes, d.cards.wants, d.cards.comments, d.cards.shares, d.cards.favorites]
            .contains { $0.counts.total > 0 }
    }

    private func cardCounts(of key: String, _ d: StatsDashboardData) -> StatsDashboardData.StatsPeriodCounts {
        switch key {
        case "views": return d.cards.views.counts
        case "likes": return d.cards.likes.counts
        case "wants": return d.cards.wants.counts
        case "comments": return d.cards.comments.counts
        case "shares": return d.cards.shares.counts
        default: return d.cards.favorites.counts
        }
    }

    private func cardTopItems(of key: String, _ d: StatsDashboardData) -> [StatsDashboardData.StatsCardTopItem] {
        switch key {
        case "views": return d.cards.views.top.items(for: period)
        case "likes": return d.cards.likes.top.items(for: period)
        case "wants": return d.cards.wants.top.items(for: period)
        case "comments": return d.cards.comments.top.items(for: period)
        case "shares": return d.cards.shares.top.items(for: period)
        default: return d.cards.favorites.top.items(for: period)
        }
    }

    private func trendValues(_ key: String) -> [Int] {
        let s = trend?.series
        switch key {
        case "cardLikes": return s?.cardLikes ?? []
        case "cardWants": return s?.cardWants ?? []
        case "cardComments": return s?.cardComments ?? []
        case "cardShares": return s?.cardShares ?? []
        default: return s?.cardFavorites ?? []
        }
    }

    private func loadAll() async {
        stats = try? await MashanglingAPI.shared.stats.dashboard()
        await loadTrend()
    }

    private func loadTrend() async {
        trend = try? await MashanglingAPI.shared.stats.trend(period: period)
    }
}

// MARK: - 可 Identifiable 的 Int（sheet(item:) 用）
struct IdentifiedInt: Identifiable {
    let value: Int
    var id: Int { value }
    init(_ value: Int) { self.value = value }
}

// MARK: - 分组柱状图（对应网页 recharts BarChart，每天一组细柱）
struct MultiBarChartView: View {
    let labels: [String]
    let series: [(String, Color, [Int])]

    var body: some View {
        Canvas { ctx, size in
            let count = labels.count
            guard count > 0, !series.isEmpty else { return }
            let padL: CGFloat = 30, padR: CGFloat = 6, padT: CGFloat = 8, padB: CGFloat = 18
            let innerW = size.width - padL - padR
            let innerH = size.height - padT - padB
            let maxV = max(1, series.flatMap { $0.2 }.max() ?? 1)

            // 网格 + Y 轴刻度
            for f in [0.0, 0.5, 1.0] {
                let y = padT + innerH * (1 - f)
                var p = Path()
                p.move(to: CGPoint(x: padL, y: y))
                p.addLine(to: CGPoint(x: size.width - padR, y: y))
                ctx.stroke(p, with: .color(.appBorder.opacity(0.6)),
                           style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                let v = Int((Double(maxV) * f).rounded())
                ctx.draw(Text("\(v)").font(.system(size: 9)).foregroundColor(.appMutedFg),
                         at: CGPoint(x: padL - 14, y: y))
            }

            let groupW = innerW / CGFloat(count)
            let barW = min(5, (groupW - 4) / CGFloat(series.count))
            for i in 0..<count {
                let groupX = padL + groupW * CGFloat(i) + (groupW - barW * CGFloat(series.count)) / 2
                for (j, s) in series.enumerated() {
                    guard i < s.2.count else { continue }
                    let v = s.2[i]
                    guard v > 0 else { continue }
                    let h = innerH * CGFloat(v) / CGFloat(maxV)
                    let rect = CGRect(x: groupX + barW * CGFloat(j),
                                      y: padT + innerH - h,
                                      width: barW - 1, height: h)
                    ctx.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(s.1))
                }
                // X 轴刻度（本月只标首尾，其余全标）
                let showAll = count <= 10
                if showAll || i == 0 || i == count - 1 {
                    ctx.draw(Text(labels[i]).font(.system(size: 9)).foregroundColor(.appMutedFg),
                             at: CGPoint(x: padL + groupW * CGFloat(i) + groupW / 2, y: size.height - 8))
                }
            }
        }
    }
}
