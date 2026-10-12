import SwiftUI

// MARK: - 盲盒分类上线悬浮提示（逐行复刻网页 MysteryTabTip.tsx）
// 对所有用户显示一次（含游客）；「不再显示」写入 UserDefaults 永久关闭；右上角 X 仅本次关闭。
struct MysteryTabTipCard: View {
    let onGo: () -> Void
    let onNever: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 骰子圆形图标
            ZStack {
                Circle().fill(Color(hex: "#ede9fe"))
                Image(systemName: "dice")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "#7c3aed"))
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 0) {
                Text("盲盒分类上线啦")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appForeground)
                Text("首页新增「盲盒」分类，抽到什么全看概率；每个盲盒的设定概率和全站实际抽中占比都在「概率公示」里公开可查。")
                    .font(.system(size: 12))
                    .lineSpacing(5)
                    .foregroundColor(.appMutedFg)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
                HStack(spacing: 8) {
                    Button(action: onGo) {
                        Text("去看看")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color(hex: "#8b5cf6"))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    Button(action: onNever) {
                        Text("不再显示")
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 10)
            }

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12))
                    .foregroundColor(.appMutedFg)
                    .padding(4)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: 320)
        .background(Color.appCard)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "#c4b5fd"), lineWidth: 1))
        .shadow(color: .black.opacity(0.15), radius: 16, y: 4)
    }
}

// MARK: - 盲盒概率公示页（逐行复刻网页 MysteryStats.tsx，公开页）
struct MysteryStatsView: View {
    // ?id= 直达单个橱窗；「重置」时清空回全量列表
    @State private var showcaseId: Int?

    init(showcaseId: Int? = nil) {
        _showcaseId = State(initialValue: showcaseId)
    }

    @State private var q = ""
    @State private var submitted = ""
    @State private var items: [MysteryStatsResponse.MysteryStatsItem] = []
    @State private var loading = true
    @State private var openDetailId: Int? = nil

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // 标题
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "#8b5cf6"))
                    Text("盲盒概率公示")
                        .font(.system(size: 24, weight: .bold))
                        .tracking(-0.6)
                        .foregroundColor(.appForeground)
                }
                Text("每个盲盒橱窗的奖项设定概率与全站实际抽中占比都在这里公开，抽得越多越接近设定值。最低概率款带保底机制（窗口内必中），因此实际占比可能略高于纯随机期望。公示只含无料名，不含码。")
                    .font(.system(size: 14))
                    .lineSpacing(7)
                    .foregroundColor(.appMutedFg)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)

                // 搜索：橱窗标题 / 无料名
                HStack(spacing: 8) {
                    HStack(spacing: 0) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14))
                            .foregroundColor(.appMutedFg)
                            .padding(.leading, 12)
                        TextField("搜索橱窗标题或无料名…", text: $q)
                            .font(.system(size: 14))
                            .autocapitalization(.none)
                            .padding(.leading, 8)
                            .onSubmit { submitted = q; Task { await load() } }
                    }
                    .frame(height: 40)
                    .background(Color.appCard)
                    .overlay(Capsule().stroke(Color.appInput, lineWidth: 0.5))
                    .clipShape(Capsule())

                    Button {
                        submitted = q
                        Task { await load() }
                    } label: {
                        Text("搜索")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .frame(height: 40)
                            .background(Color(hex: "#8b5cf6"))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    if !submitted.isEmpty || showcaseId != nil {
                        Button {
                            q = ""
                            submitted = ""
                            showcaseId = nil
                            Task { await load() }
                        } label: {
                            Text("重置")
                                .font(.system(size: 14))
                                .foregroundColor(.appMutedFg)
                                .padding(.horizontal, 16)
                                .frame(height: 40)
                                .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 20)

                if loading {
                    Text("加载中…")
                        .font(.system(size: 14))
                        .foregroundColor(.appMutedFg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 64)
                } else if items.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "dice")
                            .font(.system(size: 28))
                            .foregroundColor(.appMutedFg.opacity(0.5))
                        Text(!submitted.isEmpty || showcaseId != nil ? "没有匹配的盲盒橱窗" : "还没有盲盒橱窗")
                            .font(.system(size: 14))
                            .foregroundColor(.appMutedFg)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 80)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 1, dash: [6])))
                    .padding(.top, 24)
                } else {
                    VStack(spacing: 16) {
                        ForEach(items) { s in
                            statsCard(s)
                        }
                    }
                    .padding(.top, 24)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: Binding(
            get: { openDetailId != nil },
            set: { if !$0 { openDetailId = nil } }
        )) {
            if let id = openDetailId {
                ShowcaseDetailView(showcaseId: id)
            }
        }
        .task { await load() }
    }

    // 单个橱窗的公示卡：标题 + 共N抽 + 表格（无料名/设定概率/抽中次数/实际占比）
    private func statsCard(_ s: MysteryStatsResponse.MysteryStatsItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Button { openDetailId = s.showcaseId } label: {
                    Text(s.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.appForeground)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
                if s.removed == true {
                    Text("已下架")
                        .font(.system(size: 11))
                        .foregroundColor(.appMutedFg)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Color.appSecondary)
                        .clipShape(Capsule())
                }
                Text("共 \(s.totalDraws ?? 0) 抽")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "#6d28d9"))
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Color(hex: "#ede9fe"))
                    .clipShape(Capsule())
            }

            // 表头
            HStack(spacing: 0) {
                Text("无料名").frame(maxWidth: .infinity, alignment: .leading)
                Text("设定概率").frame(width: 64, alignment: .trailing)
                Text("抽中次数").frame(width: 56, alignment: .trailing)
                Text("实际占比").frame(width: 56, alignment: .trailing)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.appMutedFg)
            .padding(.bottom, 8)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.appBorder).frame(height: 0.5) }
            .padding(.top, 12)

            let entries = s.items ?? []
            let minExpect = entries.map { $0.expect }.min() ?? .infinity
            ForEach(Array(entries.enumerated()), id: \.offset) { idx, it in
                HStack(spacing: 0) {
                    HStack(spacing: 6) {
                        Text(it.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.appForeground)
                            .lineLimit(1)
                        if it.expect == minExpect {
                            Text("隐藏款")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(LinearGradient(colors: [Color(hex: "#f59e0b"), Color(hex: "#ca8a04")], startPoint: .leading, endPoint: .trailing))
                                .clipShape(Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(fmtPct(it.expect))%")
                        .frame(width: 64, alignment: .trailing)
                    Text("\(it.count)")
                        .frame(width: 56, alignment: .trailing)
                    Text(it.actual == nil ? "—" : "\(fmtPct(it.actual!))%")
                        .frame(width: 56, alignment: .trailing)
                }
                .font(.system(size: 12))
                .monospacedDigit()
                .foregroundColor(.appForeground)
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) {
                    if idx < entries.count - 1 {
                        Rectangle().fill(Color.appBorder.opacity(0.5)).frame(height: 0.5)
                    }
                }
            }

            if (s.totalDraws ?? 0) == 0 {
                Text("还没有人抽过这个盲盒，抽中后数据会实时更新。")
                    .font(.system(size: 11))
                    .foregroundColor(.appMutedFg)
                    .padding(.top, 8)
            }
        }
        .padding(16)
        .background(Color.appCard)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appBorder, lineWidth: 0.5))
    }

    private func fmtPct(_ p: Double) -> String {
        let r = (p * 100).rounded() / 100
        if r == r.rounded() { return String(Int(r)) }
        return String(format: "%g", r)
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            let kw = submitted.trimmingCharacters(in: .whitespaces)
            // 网页优先级：showcaseId 直达 > 关键词 > 全量
            let r: MysteryStatsResponse
            if let sid = showcaseId {
                r = try await MashanglingAPI.shared.showcase.mysteryStats(showcaseId: sid)
            } else if !kw.isEmpty {
                r = try await MashanglingAPI.shared.showcase.mysteryStats(q: kw)
            } else {
                r = try await MashanglingAPI.shared.showcase.mysteryStats()
            }
            items = r.items ?? []
        } catch {
            ToastCenter.shared.error(error.localizedDescription)
        }
    }
}
