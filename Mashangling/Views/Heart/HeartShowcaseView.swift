import SwiftUI

// MARK: - 心选橱窗（对应网页 HeartShowcase.tsx：积分看涨/买空瓜分奖池）
struct HeartShowcaseView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var q = ""
    @State private var submitted = ""
    @State private var results: [HeartSearchResult] = []
    @State private var searching = false
    @State private var selected: HeartSearchResult? = nil
    @State private var amount = ""
    @State private var info: HeartInfo? = nil
    @State private var mine: [HeartSupportRow] = []
    @State private var weeklyTop: [HeartWeeklyTopUser] = []
    @State private var rising: [HeartRising] = []
    @State private var recent: [HeartRecentSupport] = []
    @State private var showLogin = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                // 说明
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "diamond")
                            .font(.system(size: 24))
                            .foregroundColor(.appBrand500)
                        Text("心选橱窗")
                            .font(.system(size: 24, weight: .bold))
                            .tracking(-0.6)
                            .foregroundColor(.appForeground)
                    }
                    Text("用积分支持你看好的橱窗，或买空你看淡的橱窗：押对方向即可按投入权重瓜分奖池积分。")
                        .font(.system(size: 11))
                        .foregroundColor(.appMutedFg)
                }

                // 最近支持横幅
                if !recent.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(recent) { s in
                            NavigationLink(destination: ShowcaseDetailView(showcaseId: s.showcaseId)) {
                                HStack(spacing: 6) {
                                    Image(systemName: s.direction == "short" ? "arrow.down.right" : "heart.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(s.direction == "short" ? .blue : .appPrimary)
                                    Group {
                                        Text(s.userName ?? "").bold()
                                            + Text(s.isBot == true ? " [官方]" : "")
                                            + Text(s.direction == "short" ? " 买空了「" : " 支持了「")
                                            + Text(s.title ?? "")
                                            + Text("」")
                                    }
                                    .font(.system(size: 11))
                                    .foregroundColor(.appForeground.opacity(0.9))
                                    .lineLimit(1)
                                    Spacer()
                                    Text(DateFmt.time(s.createdAt))
                                        .font(.system(size: 10))
                                        .foregroundColor(.appMutedFg)
                                }
                                .padding(.horizontal, 10).padding(.vertical, 7)
                                .background(Color.appPrimary.opacity(0.06))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // 搜索
                HStack(spacing: 8) {
                    AppTextField(text: $q, placeholder: "搜索橱窗名 / 发布人，或输入编码（如 M000123）")
                        .onSubmit { doSearch() }
                    Button { doSearch() } label: {
                        Image(systemName: searching ? "ellipsis" : "magnifyingglass")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.appPrimaryFg)
                            .frame(width: 40, height: 40)
                            .background(Color.appPrimary)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                // 搜索结果
                if !submitted.isEmpty {
                    if searching {
                        LoadingView()
                    } else if results.isEmpty {
                        Text("没有找到匹配的橱窗")
                            .font(.system(size: 13))
                            .foregroundColor(.appMutedFg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 36)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 1, dash: [6])))
                    } else {
                        VStack(spacing: 8) {
                            ForEach(results) { r in
                                searchRow(r)
                            }
                        }
                    }
                }

                // 近期上升橱窗
                if !rising.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.up.right").foregroundColor(.appEmeraldFg)
                            Text("近期上升橱窗").font(.system(size: 15, weight: .semibold)).foregroundColor(.appForeground)
                        }
                        Text("最近一天热度排名上升最多的橱窗，支持它们或许更容易分到奖池")
                            .font(.system(size: 10)).foregroundColor(.appMutedFg)
                        ForEach(rising) { r in
                            Button { select(r.asSearchResult) } label: {
                                HStack(spacing: 10) {
                                    AppImage(path: r.coverImage)
                                        .frame(width: 44, height: 44)
                                        .cornerRadius(8)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(r.title).font(.system(size: 13, weight: .medium)).foregroundColor(.appForeground).lineLimit(1)
                                        Text("\(r.authorName ?? "") · \(r.shortCode ?? "—")").font(.system(size: 10)).foregroundColor(.appMutedFg)
                                    }
                                    Spacer()
                                    Text("升 \(r.rise) 名")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.appEmeraldFg)
                                        .padding(.horizontal, 7).padding(.vertical, 3)
                                        .background(Color.appEmeraldBg)
                                        .cornerRadius(10)
                                }
                                .padding(10)
                                .background(Color.appCard)
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected?.id == r.id ? Color.appPrimary : Color.appBorder, lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                        }
                        // 推荐里选中的支持面板
                        if let sel = selected, rising.contains(where: { $0.id == sel.id }) {
                            supportPanel(for: sel.id)
                        }
                    }
                    .padding(.top, 4)
                }

                // 买股王周榜
                weeklyTopSection

                // 我支持的橱窗
                if authManager.isAuthenticated {
                    mySupportsSection
                }

                // 结算规则
                rulesSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Color.appBackground)
        .navigationTitle("心选橱窗")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showLogin) { LoginView() }
        .onAppear { Task { await load() } }
    }

    // MARK: 搜索结果行 + 内联支持面板
    private func searchRow(_ r: HeartSearchResult) -> some View {
        VStack(spacing: 0) {
            Button { select(r) } label: {
                HStack(spacing: 10) {
                    AppImage(path: r.coverImage)
                        .frame(width: 44, height: 44)
                        .cornerRadius(8)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.title).font(.system(size: 13, weight: .medium)).foregroundColor(.appForeground).lineLimit(1)
                        Text("\(r.authorName ?? "")\(r.todayRank != nil ? " · 今日第 \(r.todayRank!) 名" : "")")
                            .font(.system(size: 10)).foregroundColor(.appMutedFg)
                    }
                    Spacer()
                    Text(r.shortCode ?? "—")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.appMutedFg)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color.appSecondary)
                        .cornerRadius(10)
                }
                .padding(10)
                .background(Color.appCard)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected?.id == r.id ? Color.appPrimary : Color.appBorder, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            if selected?.id == r.id {
                supportPanel(for: r.id)
            }
        }
    }

    // MARK: 支持面板（K 线 + 投入）
    private func supportPanel(for showcaseId: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MarketChartView(showcaseId: showcaseId)
            HStack(spacing: 8) {
                AppTextField(text: $amount, placeholder: "投入的积分", keyboard: .numberPad)
                    .frame(width: 100)
                    .onChange(of: amount) { v in
                        let digits = v.filter { $0.isNumber }
                        if digits != v { amount = digits }
                    }
                Button { doSupport(showcaseId, direction: "long") } label: {
                    Label("支持看涨", systemImage: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(Color.appPrimary)
                        .cornerRadius(18)
                }
                .buttonStyle(.plain)
                .disabled(amount.isEmpty || info?.inWindow == false)
                Button { doSupport(showcaseId, direction: "short") } label: {
                    Label("买空看跌", systemImage: "arrow.down.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .overlay(Capsule().stroke(Color.blue, lineWidth: 0.8))
                }
                .buttonStyle(.plain)
                .disabled(amount.isEmpty || info?.inWindow == false)
                NavigationLink(destination: ShowcaseDetailView(showcaseId: showcaseId)) {
                    Text("看橱窗")
                        .font(.system(size: 12))
                        .foregroundColor(.appForeground)
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.8))
                }
                .buttonStyle(.plain)
            }
            if info?.inWindow == false {
                Text("现在不在支持时段（每天 9:00 - 22:00 可支持）")
                    .font(.system(size: 10))
                    .foregroundColor(.appAmberFg)
            }
        }
        .padding(12)
        .background(Color.appPrimary.opacity(0.04))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appPrimary.opacity(0.3), lineWidth: 0.5))
    }

    // MARK: 买股王周榜
    private var weeklyTopSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "trophy").foregroundColor(.appAmberIcon)
                Text("买股王 · 本周榜").font(.system(size: 15, weight: .semibold)).foregroundColor(.appForeground)
            }
            Text("近 7 天心选投入分红收益前 5 名；每周日定榜，第一名获「买股王」头衔 + 100 积分")
                .font(.system(size: 10)).foregroundColor(.appMutedFg)
            if weeklyTop.isEmpty {
                Text("本周还没有分红记录，虚位以待")
                    .font(.system(size: 13))
                    .foregroundColor(.appMutedFg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 26)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 1, dash: [6])))
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(weeklyTop.enumerated()), id: \.element.id) { i, r in
                        NavigationLink(destination: ProfileView(userId: r.userId)) {
                            HStack(spacing: 10) {
                                Text("\(i + 1)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(i == 0 ? .white : i == 1 ? .gray : i == 2 ? .appAmberFg : .appMutedFg)
                                    .frame(width: 26, height: 26)
                                    .background(i == 0 ? Color.appAmberIcon : Color.appSecondary)
                                    .clipShape(Circle())
                                Text(i == 0 ? "📈 \(r.name ?? "")" : (r.name ?? ""))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.appForeground)
                                    .lineLimit(1)
                                Spacer()
                                Text("+\(r.profit)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.appEmeraldFg)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 9)
                            .background(Color.appCard)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appBorder, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: 我支持的橱窗
    private var mySupportsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("我支持的橱窗").font(.system(size: 15, weight: .semibold)).foregroundColor(.appForeground)
            if mine.isEmpty {
                Text("还没有支持过橱窗")
                    .font(.system(size: 13))
                    .foregroundColor(.appMutedFg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 26)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 1, dash: [6])))
            } else {
                ForEach(mine) { m in
                    MySupportRowView(item: m)
                }
            }
        }
    }

    // MARK: 结算规则
    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("结算规则").font(.system(size: 14, weight: .semibold)).foregroundColor(.appForeground)
            VStack(alignment: .leading, spacing: 6) {
                ruleText("支持时间：每天 9:00 - 22:00（北京时间），次日 8:00 结算")
                ruleText("你投入的积分会先扣除并进入当日奖池（奖池数额不公开）")
                ruleText("两种玩法：支持看涨——排名明显上升即押对；买空看跌——排名持平或下降即押对。押错方向，投入不返还")
                ruleText("结算时对比橱窗热度排名（今早 8:00 vs 昨早 8:00），变动需达到最小波幅才算涨跌：max(2, 在架橱窗数 × 3%) 名（取整），波幅内算持平（买空赢）")
                ruleText("昨日 8:00 后才上架的新橱窗不参与涨跌判定，押它的注视为未中、不返还")
                ruleText("所有押对方向的人按投入权重瓜分当日奖池的 90%（看涨与买空共用同一奖池）；若当天没有人押对，90% 结转计入下一次奖池")
                ruleText("奖池的 2% 按在架橱窗数量加权分给全站橱窗发布者，作为创作激励")
                ruleText("奖池的 2% 平分给当天被支持且排名上升橱窗的发布人；若没有橱窗上升，这 2% 结转计入下一次奖池")
                ruleText("剩余 6% 作为平台运营分成，均分给管理员")
                ruleText("取整余数等未分完的剩余，自动累积至下一次结算的奖池")
                ruleText("「买股王」周榜按近 7 天参与投入获得的分红收益排名，每周日定榜，第一名获「买股王」头衔 + 100 积分")
                ruleText("结算结果会通过站内信和邮件通知，并记入积分明细")
                ruleText("活动初期官方会投入 10 个机器人账户一起参与，与你按完全相同规则分红；机器人不上买股王周榜")
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("💡 小贴士：可以「对冲」")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.appAmberFg)
                Text("你可以同时支持、买空多个橱窗分散风险——只有押对方向的那部分投入参与瓜分奖池，押错的积分不会返还。对冲能提高「押中」的概率，但每次投错的成本也是真实扣除的，请量力而行。")
                    .font(.system(size: 11))
                    .foregroundColor(.appAmberFg.opacity(0.85))
                    .lineSpacing(3)
            }
            .padding(10)
            .background(Color.appAmberBg)
            .cornerRadius(8)
        }
        .padding(14)
        .background(Color.appCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, lineWidth: 0.5))
    }

    private func ruleText(_ t: String) -> some View {
        Text("· \(t)")
            .font(.system(size: 11))
            .foregroundColor(.appMutedFg)
            .lineSpacing(3)
    }

    // MARK: 逻辑
    private func select(_ r: HeartSearchResult) {
        selected = selected?.id == r.id ? nil : r
    }

    private func doSearch() {
        let v = q.trimmingCharacters(in: .whitespaces)
        guard !v.isEmpty else { return }
        selected = nil
        submitted = v
        searching = true
        Task {
            do {
                results = try await MashanglingAPI.shared.heart.search(q: v)
            } catch {
                results = []
                ToastCenter.error(error.localizedDescription)
            }
            searching = false
        }
    }

    private func doSupport(_ showcaseId: Int, direction: String) {
        guard authManager.isAuthenticated else { showLogin = true; return }
        guard let n = Int(amount), n >= 1 else { ToastCenter.error("请输入至少 1 积分"); return }
        Task {
            do {
                _ = try await MashanglingAPI.shared.heart.support(showcaseId: showcaseId, amount: n, direction: direction)
                ToastCenter.success(direction == "short" ? "买空成功，已投入今日奖池" : "支持成功，已投入今日奖池")
                amount = ""
                mine = (try? await MashanglingAPI.shared.heart.mine()) ?? []
            } catch { ToastCenter.error(error.localizedDescription) }
        }
    }

    private func load() async {
        info = try? await MashanglingAPI.shared.heart.info()
        weeklyTop = (try? await MashanglingAPI.shared.heart.weeklyTop()) ?? []
        rising = (try? await MashanglingAPI.shared.heart.rising()) ?? []
        recent = (try? await MashanglingAPI.shared.heart.recentSupports()) ?? []
        if authManager.isAuthenticated {
            mine = (try? await MashanglingAPI.shared.heart.mine()) ?? []
        }
    }
}

// MARK: - HeartRising → HeartSearchResult 转换
extension HeartRising {
    var asSearchResult: HeartSearchResult {
        HeartSearchResult(id: id, title: title, coverImage: coverImage, shortCode: shortCode, authorName: authorName, todayRank: nil)
    }
}

// MARK: - 模拟大盘 K 线图（对应网页 MarketChart，Canvas 绘制）
struct MarketChartView: View {
    let showcaseId: Int
    @State private var pts: [MarketPoint] = []
    @State private var loading = true

    var body: some View {
        if loading {
            ProgressView().frame(maxWidth: .infinity, minHeight: 100).tint(.appPrimary)
                .onAppear { Task { await load() } }
        } else if pts.count < 2 {
            Text("暂无足够排名数据（排名快照从功能上线后开始累积）")
                .font(.system(size: 10))
                .foregroundColor(.appMutedFg)
        } else {
            chart
        }
    }

    private var chart: some View {
        let latest = pts.last!
        let prev = pts[pts.count - 2]
        let delta = latest.rank - prev.rank
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: latest.flat ? "minus" : (latest.rank < prev.rank ? "arrow.up.right" : "arrow.down.right"))
                        .font(.system(size: 10))
                        .foregroundColor(latest.flat ? .appMutedFg : (latest.rank < prev.rank ? .appEmeraldFg : .appRedFg))
                    Text("最新第 ").font(.system(size: 10)).foregroundColor(.appMutedFg)
                        + Text("\(latest.rank)").font(.system(size: 10, weight: .bold)).foregroundColor(.appMutedFg)
                        + Text(" 名").font(.system(size: 10)).foregroundColor(.appMutedFg)
                    if !latest.flat {
                        Text("（\(latest.rank < prev.rank ? "↑\(-delta)" : "↓\(delta)")）")
                            .font(.system(size: 10))
                            .foregroundColor(latest.rank < prev.rank ? .appEmeraldFg : .appRedFg)
                    } else {
                        Text("（持平）").font(.system(size: 10)).foregroundColor(.appMutedFg)
                    }
                }
                Spacer()
                HStack(spacing: 8) {
                    Circle().fill(Color.appEmeraldFg).frame(width: 6, height: 6)
                    Text("升").font(.system(size: 9)).foregroundColor(.appMutedFg)
                    Circle().fill(Color.appRedFg).frame(width: 6, height: 6)
                    Text("降").font(.system(size: 9)).foregroundColor(.appMutedFg)
                }
            }

            CandlestickCanvas(pts: pts)
                .frame(height: 110)

            HStack {
                Text(dayLabel(pts.first!.day))
                Spacer()
                Text(dayLabel(pts.last!.day))
            }
            .font(.system(size: 9))
            .foregroundColor(.appMutedFg)

            Text("模拟大盘 · 按热度排名走势生成（名次小=K线高）")
                .font(.system(size: 9))
                .foregroundColor(.appMutedFg.opacity(0.7))
        }
    }

    private func dayLabel(_ day: String) -> String {
        // day 格式 yyyymmdd → mm/dd
        guard day.count >= 8 else { return day }
        let m = day.dropFirst(4).prefix(2)
        let d = day.dropFirst(6).prefix(2)
        return "\(m)/\(d)"
    }

    private func load() async {
        let r = try? await MashanglingAPI.shared.heart.market(showcaseId: showcaseId)
        pts = r?.points ?? []
        loading = false
    }
}

struct CandlestickCanvas: View {
    let pts: [MarketPoint]

    var body: some View {
        Canvas { ctx, size in
            let allVals = pts.flatMap { [$0.high, $0.low, $0.open, $0.close] }
            guard let minV = allVals.min(), let maxV = allVals.max() else { return }
            let span = max(1, maxV - minV)
            let padL: CGFloat = 28, padR: CGFloat = 8, padT: CGFloat = 10, padB: CGFloat = 16
            let innerW = size.width - padL - padR
            let innerH = size.height - padT - padB
            let step = innerW / CGFloat(max(1, pts.count - 1))
            let x: (Int) -> CGFloat = { padL + CGFloat($0) * step }
            let y: (Int) -> CGFloat = { v in padT + (CGFloat(v - minV) / CGFloat(span)) * innerH }
            let candleW = max(4, min(10, step * 0.5))

            // 网格
            for f in [0.25, 0.5, 0.75] {
                var p = Path()
                p.move(to: CGPoint(x: padL, y: padT + innerH * f))
                p.addLine(to: CGPoint(x: size.width - padR, y: padT + innerH * f))
                ctx.stroke(p, with: .color(.appBorder), style: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
            }
            // 刻度
            ctx.draw(Text("\(minV)").font(.system(size: 8)).foregroundColor(.appMutedFg),
                     at: CGPoint(x: padL - 12, y: padT + 3), anchor: .trailing)
            ctx.draw(Text("\(maxV)").font(.system(size: 8)).foregroundColor(.appMutedFg),
                     at: CGPoint(x: padL - 12, y: padT + innerH), anchor: .trailing)

            for (i, p) in pts.enumerated() {
                let col: Color = p.up ? Color(h: 160, s: 84, l: 39) : (p.flat ? Color(h: 215, s: 16, l: 65) : Color(h: 0, s: 84, l: 60))
                // 影线
                var line = Path()
                line.move(to: CGPoint(x: x(i), y: y(p.high)))
                line.addLine(to: CGPoint(x: x(i), y: y(p.low)))
                ctx.stroke(line, with: .color(col), lineWidth: 1)
                // 实体
                let top = y(min(p.open, p.close))
                let bot = y(max(p.open, p.close))
                let rect = CGRect(x: x(i) - candleW / 2, y: top, width: candleW, height: max(2, bot - top))
                let rrect = Path(roundedRect: rect, cornerRadius: 1)
                ctx.fill(rrect, with: .color(p.up ? col : .white))
                ctx.stroke(rrect, with: .color(col), lineWidth: 1)
                if p.isToday {
                    ctx.draw(Text("今").font(.system(size: 7)).foregroundColor(col),
                             at: CGPoint(x: x(i), y: y(p.high) - 5), anchor: .center)
                }
            }
        }
    }
}

// MARK: - 我支持的橱窗行（可展开 K 线）
struct MySupportRowView: View {
    let item: HeartSupportRow
    @State private var open = false

    private var dayText: String {
        let d = item.dayKey
        guard d.count >= 8 else { return d }
        return "\(d.prefix(4))-\(d.dropFirst(4).prefix(2))-\(d.dropFirst(6).prefix(2))"
    }

    var body: some View {
        VStack(spacing: 6) {
            Button { open.toggle() } label: {
                HStack(spacing: 10) {
                    AppImage(path: item.coverImage)
                        .frame(width: 40, height: 40)
                        .cornerRadius(8)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title ?? "")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.appForeground)
                            .lineLimit(1)
                        Text("\(dayText) \(item.direction == "short" ? "买空" : "支持") \(item.amount) 积分")
                            .font(.system(size: 10))
                            .foregroundColor(.appMutedFg)
                    }
                    Spacer()
                    if item.direction == "short" {
                        MiniBadge(text: "看跌", fg: .blue, bg: .blue.opacity(0.1))
                    }
                    MiniBadge(
                        text: !item.settled ? "待结算" : ((item.payout ?? 0) > 0 ? "分红 +\(item.payout ?? 0)" : "无分红"),
                        fg: !item.settled ? .appAmberFg : ((item.payout ?? 0) > 0 ? .appEmeraldFg : .appMutedFg),
                        bg: !item.settled ? .appAmberBg : ((item.payout ?? 0) > 0 ? .appEmeraldBg : .appSecondary)
                    )
                }
                .padding(10)
                .background(Color.appCard)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appBorder, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            if open {
                VStack(alignment: .leading, spacing: 8) {
                    MarketChartView(showcaseId: item.showcaseId)
                    NavigationLink(destination: ShowcaseDetailView(showcaseId: item.showcaseId)) {
                        Text("查看橱窗")
                            .font(.system(size: 12))
                            .foregroundColor(.appForeground)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(Color.appCard)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appBorder, lineWidth: 0.5))
            }
        }
    }
}
