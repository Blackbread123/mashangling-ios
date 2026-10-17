import SwiftUI

// MARK: - 补货清单（对应网页 2026-10-17 RestockList.tsx）
// 全部非盲盒橱窗按拼音首字母分组，勾选后一键向发布人表达「想要补货」意向
struct RestockListView: View {
    @EnvironmentObject var authManager: AuthManager

    @State private var scope = "all"              // all / valid / invalid
    @State private var kind: String? = nil        // soldout / quantity / expired（仅 invalid 时显示）
    @State private var keyword = ""
    @State private var data: RestockListResponse? = nil
    @State private var loading = true
    @State private var selected: Set<Int> = []
    @State private var submitting = false

    private let scopeTabs = [("all", "全部"), ("valid", "未失效"), ("invalid", "已失效")]
    private let kindTabs: [(String?, String)] = [(nil, "全部"), ("soldout", "领完即止"), ("quantity", "限量"), ("expired", "限时")]
    private let kindLabel = ["soldout": "领完即止", "expired": "限时到期", "quantity": "限量领完"]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // 标题（h1：图标 + 补货清单，text-xl font-bold）
                    HStack(spacing: 8) {
                        Image(systemName: "list.clipboard.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.appPrimary)
                        Text("补货清单")
                            .font(.system(size: 20, weight: .bold))
                            .tracking(-0.5)
                            .foregroundColor(.appForeground)
                    }
                    Text("勾选想要补货的橱窗（可多选），点「确定」后发布人会在自己主页的「补货申请」里看到。同一轮失效内重复申请只计一次。")
                        .font(.system(size: 14))
                        .foregroundColor(.appMutedFg)
                        .padding(.top, 6)
                    Text("补货清单只是向发布人表达「想要补货」的意向，帮助 TA 了解哪些橱窗被惦记着，并不代表发布人一定会补货——最终以发布人的安排为准。")
                        .font(.system(size: 12))
                        .lineSpacing(5)
                        .foregroundColor(.appMutedFg)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appSecondary.opacity(0.4))
                        .cornerRadius(4)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 1, dash: [6])))
                        .padding(.top, 12)

                    // 搜索框（rounded-full border bg-card）
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16))
                            .foregroundColor(.appMutedFg)
                        TextField("搜索橱窗标题 / 发布人", text: $keyword)
                            .font(.system(size: 14))
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .onSubmit { Task { await load() } }
                            .onChange(of: keyword) { _ in Task { await load() } }
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .background(Color.appCard)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.appBorder, lineWidth: 1))
                    .padding(.top, 12)

                    // 筛选行（网页 sticky：scope 胶囊 + invalid 时的成因细分 + 右侧确定按钮）
                    FlowLayout(spacing: 6) {
                        ForEach(scopeTabs, id: \.0) { tab in
                            Button {
                                scope = tab.0
                                if tab.0 != "invalid" { kind = nil }
                                Task { await load() }
                            } label: {
                                Text(tab.1)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(scope == tab.0 ? .appPrimaryFg : .appSecondaryFg)
                                    .padding(.horizontal, 14).padding(.vertical, 6)
                                    .background(scope == tab.0 ? Color.appPrimary : Color.appSecondary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        if scope == "invalid" {
                            Rectangle().fill(Color.appBorder).frame(width: 1, height: 16).padding(.horizontal, 4)
                            ForEach(kindTabs, id: \.1) { tab in
                                Button {
                                    kind = tab.0
                                    Task { await load() }
                                } label: {
                                    Text(tab.1)
                                        .font(.system(size: 12))
                                        .foregroundColor(kind == tab.0 ? .white : .fixAmber700)
                                        .padding(.horizontal, 12).padding(.vertical, 6)
                                        .background(kind == tab.0 ? Color.fixAmber500 : Color.fixAmber100)
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(kind == tab.0 ? Color.clear : Color.fixAmber200, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.top, 8)

                    // 内容
                    if loading && data == nil {
                        VStack(spacing: 10) {
                            ForEach(0..<6, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.appSecondary)
                                    .frame(height: 64)
                            }
                        }
                        .padding(.top, 8)
                    } else if (data?.sections ?? []).isEmpty {
                        Text("没有符合条件的橱窗")
                            .font(.system(size: 14))
                            .foregroundColor(.appMutedFg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 80)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 1, dash: [6])))
                            .padding(.top, 8)
                    } else {
                        ForEach(data?.sections ?? []) { section in
                            // 分组标题（首字母方块 + 数量）
                            HStack(spacing: 8) {
                                Text(section.initial)
                                    .font(.system(size: 12))
                                    .foregroundColor(.appSecondaryFg)
                                    .frame(width: 24, height: 24)
                                    .background(Color.appSecondary)
                                    .cornerRadius(2)
                                Text("(\(section.items.count))")
                                    .font(.system(size: 14))
                                    .foregroundColor(.appMutedFg)
                            }
                            .padding(.top, 20)

                            VStack(spacing: 8) {
                                ForEach(section.items) { item in
                                    restockRow(item)
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, selected.isEmpty ? 24 : 88) // 底部确定栏避让
            }
            .refreshable { await load() }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("补货清单")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        // 底部确定栏（网页在 sticky 筛选行右侧；App 里筛选行窄，放底部悬浮条）
        .safeAreaInset(edge: .bottom) {
            if !selected.isEmpty {
                HStack(spacing: 12) {
                    Button { selected.removeAll() } label: {
                        Text("清空")
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button { Task { await submit() } } label: {
                        Text(submitting ? "提交中…" : "确定 (\(selected.count))")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.appPrimaryFg)
                            .padding(.horizontal, 16).padding(.vertical, 6)
                            .background(Color.appPrimary)
                            .clipShape(Capsule())
                            .opacity(submitting ? 0.6 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(submitting)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color.appBackground.opacity(0.95))
            }
        }
    }

    // 行：勾选圈 + 封面 48 + 标题/发布人 + 状态胶囊 + 本轮已申请
    private func restockRow(_ item: RestockListItem) -> some View {
        let isOn = selected.contains(item.id)
        let requested = item.requested == true
        return Button {
            guard !requested else { return }
            if isOn { selected.remove(item.id) } else { selected.insert(item.id) }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(isOn ? Color.appPrimary : Color.appMutedFg.opacity(0.4), lineWidth: 1)
                        .frame(width: 20, height: 20)
                    if isOn {
                        Circle().fill(Color.appPrimary).frame(width: 20, height: 20)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.appPrimaryFg)
                    }
                }
                AppImage(path: item.coverImage)
                    .frame(width: 48, height: 48)
                    .cornerRadius(3)
                    .clipped()
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appForeground)
                        .lineLimit(1)
                    Text(item.authorName ?? "")
                        .font(.system(size: 12))
                        .foregroundColor(.appMutedFg)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 4) {
                    if item.invalid == true, let k = item.kind {
                        Text("已失效 · \(kindLabel[k] ?? k)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.fixAmber700)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(Color.fixAmber100)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.fixAmber200, lineWidth: 1))
                    } else {
                        Text("未失效")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.fixEmerald700)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(Color.fixEmerald100)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.fixEmerald300.opacity(0.5), lineWidth: 1))
                    }
                    if requested {
                        Text("本轮已申请")
                            .font(.system(size: 10))
                            .foregroundColor(.appMutedFg)
                    }
                }
            }
            .padding(12)
            .background(Color.appCard)
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(isOn ? Color.appPrimary : Color.appBorder, lineWidth: 1))
            .opacity(requested ? 0.6 : 1)
        }
        .buttonStyle(.plain)
        .disabled(requested)
    }

    private func load() async {
        loading = true
        defer { loading = false }
        data = try? await MashanglingAPI.shared.restock.list(
            scope: scope, kind: scope == "invalid" ? kind : nil,
            keyword: keyword.trimmingCharacters(in: .whitespaces))
    }

    private func submit() async {
        guard !submitting, !selected.isEmpty else { return }
        submitting = true
        defer { submitting = false }
        do {
            let r = try await MashanglingAPI.shared.restock.submit(showcaseIds: Array(selected))
            if r.requested > 0 {
                ToastCenter.shared.success("已为 \(r.requested) 个橱窗提交补货申请，发布人会在主页看到")
            } else {
                ToastCenter.info("所选橱窗本轮都已申请过了")
            }
            selected.removeAll()
            await load()
        } catch {
            ToastCenter.shared.error(error.localizedDescription)
        }
    }
}

// MARK: - 补货申请收件箱（发布人视角，对应网页 RestockInboxPage.tsx）
struct RestockInboxView: View {
    @State private var scope = "invalid"          // invalid / valid / all
    @State private var kind: String? = nil
    @State private var items: [RestockReceivedItem]? = nil

    private let scopeTabs = [("invalid", "已失效"), ("valid", "未失效"), ("all", "全部")]
    private let kindTabs: [(String?, String)] = [(nil, "全部"), ("soldout", "领完即止"), ("quantity", "限量"), ("expired", "限时")]
    private let kindLabel = ["soldout": "领完即止", "expired": "限时到期", "quantity": "限量领完"]

    // 网页：一次拉 scope=all，前端本地过滤
    private var filtered: [RestockReceivedItem] {
        (items ?? []).filter { e in
            if scope == "invalid" && e.invalid != true { return false }
            if scope == "valid" && e.invalid == true { return false }
            if scope == "invalid", let k = kind, e.kind != k { return false }
            return true
        }
    }

    private func countFor(_ s: String) -> Int {
        (items ?? []).filter { s == "all" ? true : (s == "invalid" ? $0.invalid == true : $0.invalid != true) }.count
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "list.clipboard.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.appPrimary)
                    Text("补货申请")
                        .font(.system(size: 20, weight: .bold))
                        .tracking(-0.5)
                        .foregroundColor(.appForeground)
                }
                Text("按申请次数排名，补货后橱窗自动移到「未失效」；同一轮失效内同一人只计一次。")
                    .font(.system(size: 14))
                    .foregroundColor(.appMutedFg)
                    .padding(.top, 6)
                Text("补货申请只是访客给你的补货意向，帮你了解哪些橱窗被惦记着，并非承诺一定补货——补不补、什么时候补都由你决定。")
                    .font(.system(size: 12))
                    .lineSpacing(5)
                    .foregroundColor(.appMutedFg)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appSecondary.opacity(0.4))
                    .cornerRadius(4)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 1, dash: [6])))
                    .padding(.top, 12)

                // 筛选（带数量徽标）
                FlowLayout(spacing: 6) {
                    ForEach(scopeTabs, id: \.0) { tab in
                        Button {
                            scope = tab.0
                            if tab.0 != "invalid" { kind = nil }
                        } label: {
                            HStack(spacing: 4) {
                                Text(tab.1)
                                Text("\(countFor(tab.0))").opacity(0.7)
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(scope == tab.0 ? .appPrimaryFg : .appSecondaryFg)
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .background(scope == tab.0 ? Color.appPrimary : Color.appSecondary)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    if scope == "invalid" {
                        Rectangle().fill(Color.appBorder).frame(width: 1, height: 16).padding(.horizontal, 4)
                        ForEach(kindTabs, id: \.1) { tab in
                            Button { kind = tab.0 } label: {
                                Text(tab.1)
                                    .font(.system(size: 12))
                                    .foregroundColor(kind == tab.0 ? .white : .fixAmber700)
                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                    .background(kind == tab.0 ? Color.fixAmber500 : Color.fixAmber100)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(kind == tab.0 ? Color.clear : Color.fixAmber200, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.top, 16)

                if items == nil {
                    VStack(spacing: 10) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.appSecondary)
                                .frame(height: 76)
                        }
                    }
                    .padding(.top, 16)
                } else if (items ?? []).isEmpty {
                    Text("还没有收到补货申请。访客可以在主页「补货清单」里对你的橱窗发起申请。")
                        .font(.system(size: 14))
                        .foregroundColor(.appMutedFg)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 80)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 1, dash: [6])))
                        .padding(.top, 16)
                } else if filtered.isEmpty {
                    Text("该分类下暂时没有补货申请")
                        .font(.system(size: 14))
                        .foregroundColor(.appMutedFg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 80)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 1, dash: [6])))
                        .padding(.top, 16)
                } else {
                    VStack(spacing: 10) {
                        ForEach(filtered) { e in
                            inboxRow(e)
                        }
                    }
                    .padding(.top, 16)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("补货申请")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    // 行：封面 48 + 标题(链) + 申请人 + 状态胶囊 + N人申请 + 去补货
    private func inboxRow(_ e: RestockReceivedItem) -> some View {
        HStack(spacing: 12) {
            AppImage(path: e.coverImage)
                .frame(width: 48, height: 48)
                .cornerRadius(3)
                .clipped()
            VStack(alignment: .leading, spacing: 2) {
                NavigationLink(destination: ShowcaseDetailView(showcaseId: e.showcaseId)) {
                    Text(e.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appPrimary)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                Text((e.requesters ?? []).joined(separator: "、")
                     + ((e.count) > (e.requesters ?? []).count ? " 等" : "") + "希望补货")
                    .font(.system(size: 12))
                    .foregroundColor(.appMutedFg)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if e.invalid == true, let k = e.kind {
                Text("已失效 · \(kindLabel[k] ?? k)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.fixAmber700)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Color.fixAmber100)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.fixAmber200, lineWidth: 1))
            } else {
                Text("未失效")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.fixEmerald700)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Color.fixEmerald100)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.fixEmerald300.opacity(0.5), lineWidth: 1))
            }
            Text("\(e.count) 人申请")
                .font(.system(size: 12, weight: .bold))
                .monospacedDigit()
                .foregroundColor(.appPrimary)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color.appPrimary.opacity(0.1))
                .clipShape(Capsule())
            NavigationLink(destination: ShowcaseDetailView(showcaseId: e.showcaseId)) {
                HStack(spacing: 4) {
                    Image(systemName: "plus").font(.system(size: 12))
                    Text("去补货").font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.appPrimaryFg)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color.appPrimary)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.appCard)
        .cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 1))
    }

    private func load() async {
        items = (try? await MashanglingAPI.shared.restock.received(scope: "all"))?.items ?? []
    }
}

// MARK: - 个人主页「补货申请」入口卡（对应网页 RestockInbox.tsx，仅本人可见）
struct RestockInboxEntryCard: View {
    @State private var items: [RestockReceivedItem]? = nil

    private var subtitle: String {
        guard let items = items else { return "加载中…" }
        if items.isEmpty { return "暂无申请；访客可在主页「补货清单」里申请" }
        let invalidCount = items.filter { $0.invalid == true }.count
        let totalPeople = items.reduce(0) { $0 + $1.count }
        return "\(items.count) 个橱窗被求补货\(invalidCount > 0 ? "（\(invalidCount) 个已失效）" : "") · 共 \(totalPeople) 人次"
    }

    var body: some View {
        NavigationLink(destination: RestockInboxView()) {
            HStack(spacing: 12) {
                Image(systemName: "list.clipboard.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.appPrimary)
                    .frame(width: 44, height: 44)
                    .background(Color.appPrimary.opacity(0.1))
                    .cornerRadius(4)
                VStack(alignment: .leading, spacing: 2) {
                    Text("补货申请")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.appForeground)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.appMutedFg)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.appMutedFg)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [Color.appPrimary.opacity(0.08), Color.clear],
                               startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(5)
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .task {
            items = (try? await MashanglingAPI.shared.restock.received(scope: "all"))?.items ?? []
        }
    }
}
