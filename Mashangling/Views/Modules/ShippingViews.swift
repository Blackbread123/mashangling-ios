import SwiftUI
import UIKit
import Combine

// MARK: - 快递模块（逐行复刻网页 Shipping.tsx / ShippingApprovals.tsx / ShippingApprovalDetail.tsx / MyShipments.tsx）

private let cainiaoHomeURL = URL(string: "https://www.cainiao.com/")!
private let cainiaoFahuoURL = URL(string: "https://fahuo.cainiao.com")!
private let ztoSingleURL = URL(string: "https://www.zto.com/send/single")!

/// 寄件状态筛选（对应网页 STATUS_FILTERS）
enum ShipStatusKey: String, CaseIterable, Identifiable {
    case all, pending, preorder, ordered, external, cancelled
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: return "全部"
        case .pending: return "未下单"
        case .preorder: return "预下单"
        case .ordered: return "已下单"
        case .external: return "已外部寄件"
        case .cancelled: return "已取消"
        }
    }
}

/// 对应网页 statusKeyOf
func shipStatusKeyOf(shipState: String?, trackingNo: String?, yundaOrderId: String?, ztoOrderId: String?) -> ShipStatusKey {
    if shipState == "cancelled" { return .cancelled }
    if shipState == "external" { return .external }
    if shipState == "preorder" { return .preorder }
    if shipState == "ordered" || (trackingNo?.isEmpty == false) || (yundaOrderId?.isEmpty == false) || (ztoOrderId?.isEmpty == false) { return .ordered }
    return .pending
}

/// 状态徽标（网页：rounded-full px-2.5 py-1 text-[11px] font-semibold ring-1）
func shipBadgeView(_ text: String, bg: Color, fg: Color, ring: Color? = nil, mono: Bool = false, semibold: Bool = true) -> some View {
    Text(text)
        .font(.system(size: 11, weight: semibold ? .semibold : .regular, design: mono ? .monospaced : .default))
        .foregroundColor(fg)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(bg)
        .overlay(Capsule().stroke(ring ?? Color.clear, lineWidth: ring == nil ? 0 : 0.5))
        .clipShape(Capsule())
}

/// 物流状态小徽标（网页：px-2 py-0.5 text-[10px]，无 ring）
func shipStatusBadge(_ status: String) -> some View {
    let bg: Color
    let fg: Color
    if status == "已签收" { bg = .fixEmerald100; fg = .fixEmerald700 }
    else if status == "未查询到相关单号" { bg = .fixOrange100; fg = .fixOrange700 }
    else { bg = .fixSky50; fg = .fixSky700 }
    return Text(status)
        .font(.system(size: 10))
        .foregroundColor(fg)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(bg)
        .clipShape(Capsule())
}

// MARK: - 快递后台（网页 Shipping.tsx，发布者寄件管理）
struct ShippingView: View {
    struct ShipTarget: Identifiable {
        let id: Int            // shareId
        let full: String
        let fee: Int?
        let feeLabel: String
        let showcaseTitle: String
        let shippingFree: Bool
    }
    struct ExtTarget: Identifiable {
        let id: Int
        let full: String
        let shippingFree: Bool
    }
    struct ExportFileItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    @State private var board: ShippingBoard? = nil
    @State private var yunda: ExpressStatus? = nil
    @State private var zto: ExpressStatus? = nil
    @State private var cainiao: ExpressStatus? = nil
    @State private var loading = true
    @State private var busy = false

    @State private var editing: [Int: String] = [:]       // shareId -> 草稿（存在即编辑中）
    @State private var senderDraft: String? = nil

    @State private var confirmShip: ShipTarget? = nil
    @State private var itemName = "周边无料"
    @State private var weight = "1"
    @State private var testMode = false

    @State private var statusFilter: ShipStatusKey = .all
    @State private var collapsed: [Int: Bool] = ShippingView.loadCollapsed()

    @State private var extTarget: ExtTarget? = nil
    @State private var extFee = ""
    @State private var extTracking = ""
    @State private var extProof: UIImage? = nil
    @State private var showExtPicker = false

    @State private var tokenDraft = ""
    @State private var showBind = false
    @State private var ztoTokenDraft = ""
    @State private var showZtoBind = false
    @State private var cnCookieDraft = ""
    @State private var showCnBind = false

    @State private var deleteTarget: ShipItem? = nil
    @State private var userShipRoute: Int? = nil
    @State private var exportItem: ExportFileItem? = nil
    // 多选导出 + 长按橱窗标题删除（2026-10-10）
    @State private var selectMode = false
    @State private var selected: Set<Int> = []
    @State private var showcaseDeleteTarget: (showcaseId: Int, title: String, count: Int)? = nil

    private static func loadCollapsed() -> [Int: Bool] {
        guard let data = UserDefaults.standard.data(forKey: "msl-shipping-collapsed"),
              let raw = try? JSONDecoder().decode([String: Bool].self, from: data) else { return [:] }
        var out: [Int: Bool] = [:]
        for (k, v) in raw { if let i = Int(k) { out[i] = v } }
        return out
    }

    private func toggleCollapsed(_ id: Int) {
        collapsed[id] = !(collapsed[id] ?? false)
        var raw: [String: Bool] = [:]
        for (k, v) in collapsed { raw[String(k)] = v }
        if let data = try? JSONEncoder().encode(raw) {
            UserDefaults.standard.set(data, forKey: "msl-shipping-collapsed")
        }
    }

    // MARK: 派生数据
    private var filteredGroups: [ShipGroup] {
        guard let d = board else { return [] }
        return d.groups.map { g in
            guard statusFilter != .all else { return g }
            return ShipGroup(showcaseId: g.showcaseId, title: g.title, shippingFree: g.shippingFree,
                             removed: g.removed,
                             items: g.items.filter { shipStatusKeyOf(shipState: $0.shipState, trackingNo: $0.trackingNo, yundaOrderId: $0.yundaOrderId, ztoOrderId: $0.ztoOrderId) == statusFilter },
                             hiddenCount: g.hiddenCount, subtotal: g.subtotal, unpaidSubtotal: g.unpaidSubtotal)
        }.filter { !$0.items.isEmpty || ($0.hiddenCount ?? 0) > 0 }
    }

    private var statusCounts: [ShipStatusKey: Int] {
        var acc: [ShipStatusKey: Int] = [.all: 0, .pending: 0, .preorder: 0, .ordered: 0, .external: 0, .cancelled: 0]
        guard let d = board else { return acc }
        for g in d.groups {
            for a in g.items {
                acc[shipStatusKeyOf(shipState: a.shipState, trackingNo: a.trackingNo, yundaOrderId: a.yundaOrderId, ztoOrderId: a.ztoOrderId), default: 0] += 1
                acc[.all, default: 0] += 1
            }
        }
        return acc
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // h1：Truck 图标 + 快递后台 + 右侧邮费审批胶囊
                HStack(alignment: .top, spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: "box.truck")
                            .font(.system(size: 20))
                            .foregroundColor(.appPrimary)
                        Text("快递后台")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.appForeground)
                    }
                    Spacer()
                    NavigationLink(destination: ShippingApprovalsView()) {
                        HStack(spacing: 6) {
                            Text("邮费审批")
                                .font(.system(size: 12, weight: .medium))
                            if let n = board?.pendingApprovalCount, n > 0 {
                                Text("\(n)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(minWidth: 16, minHeight: 16)
                                    .background(Color.appDestructive)
                                    .clipShape(Capsule())
                            }
                        }
                        .foregroundColor(.appPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.appPrimary.opacity(0.05))
                        .overlay(Capsule().stroke(Color.appPrimary.opacity(0.4), lineWidth: 0.5))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Text("按橱窗集中管理收到的收货地址。绑定韵达账号后点「寄快递」会自动下单并回传单号，收件人自动收到通知；寄错可点「取消寄件」（未揽收前可取消）。包邮/不包邮在发布橱窗时设置。")
                    .font(.system(size: 14))
                    .foregroundColor(.appMutedFg)
                    .padding(.top, 6)

                ztoCard.padding(.top, 20)
                yundaCard.padding(.top, 20)
                cainiaoCard.padding(.top, 16)
                senderCard.padding(.top, 20)
                cainiaoGuideCard.padding(.top, 16)

                if loading {
                    VStack(spacing: 12) {
                        ForEach(0..<2, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.appSecondary)
                                .frame(height: 112)
                        }
                    }
                    .padding(.top, 24)
                } else if board == nil || board!.groups.isEmpty {
                    VStack(spacing: 0) {
                        Image(systemName: "shippingbox")
                            .font(.system(size: 32))
                            .foregroundColor(.appMutedFg)
                        Text("还没有收到任何地址。领取人在你的外部无料橱窗点「发送地址」后会出现在这里。")
                            .font(.system(size: 14))
                            .foregroundColor(.appMutedFg)
                            .multilineTextAlignment(.center)
                            .padding(.top, 12)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 64)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 0.5, dash: [4, 3])))
                    .padding(.top, 24)
                } else {
                    filterRow.padding(.top, 24)

                    if filteredGroups.isEmpty {
                        Text("该状态下暂无地址")
                            .font(.system(size: 14))
                            .foregroundColor(.appMutedFg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 0.5, dash: [4, 3])))
                            .padding(.top, 16)
                    }

                    ForEach(filteredGroups) { g in
                        groupCard(g).padding(.top, 16)
                    }

                    summaryCard.padding(.top, 24)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground)
        .navigationTitle("快递后台")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .navigationDestination(isPresented: Binding(get: { userShipRoute != nil }, set: { if !$0 { userShipRoute = nil } })) {
            if let uid = userShipRoute { UserShipmentsView(userId: uid) }
        }
        .navigationDestination(isPresented: $showSettings) {
            SettingsView()
        }
        .alert("取消寄件", isPresented: Binding(get: { cancelConfirm != nil }, set: { if !$0 { cancelConfirm = nil; cancelTarget = nil } })) {
            Button("取消", role: .cancel) {}
            Button("确定", role: .destructive) {
                if let sid = cancelTarget { Task { await cancelShip(sid) } }
            }
        } message: {
            Text(cancelConfirm ?? "")
        }
        .alert("解绑快递账号", isPresented: Binding(get: { unbindConfirm != nil }, set: { if !$0 { unbindConfirm = nil; unbindAction = nil } })) {
            Button("取消", role: .cancel) {}
            Button("解绑", role: .destructive) {
                if let k = unbindAction { Task { await unbind(k) } }
            }
        } message: {
            Text(unbindConfirm ?? "")
        }
        .sheet(item: $confirmShip, onDismiss: { testMode = false }) { t in shipConfirmSheet(t) }
        .sheet(item: $extTarget, onDismiss: { extTracking = ""; extFee = ""; extProof = nil }) { t in externalSheet(t) }
        .sheet(item: $exportItem) { item in ShareSheet(items: [item.url]) }
        .sheet(isPresented: $showExtPicker) { ImagePicker(image: $extProof) }
        .alert("删除寄件记录", isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } })) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let t = deleteTarget { Task { await deleteShare(t) } }
            }
        } message: {
            Text("彻底删除这条寄件记录？与「隐藏」不同，删除后不可恢复。若该橱窗已没有其他寄件记录，橱窗也会一并删除。")
        }
        // 长按橱窗标题 → 彻底删除该橱窗所有寄件记录（2026-10-10，照网页确认弹窗）
        .alert("删除该橱窗所有寄件记录？", isPresented: Binding(get: { showcaseDeleteTarget != nil }, set: { if !$0 { showcaseDeleteTarget = nil } })) {
            Button("取消", role: .cancel) {}
            Button("确认删除", role: .destructive) {
                if let t = showcaseDeleteTarget { Task { await deleteShowcaseShares(t) } }
            }
        } message: {
            if let t = showcaseDeleteTarget {
                Text("「\(t.title)」共 \(t.count) 条寄件记录将被彻底删除。不论是否已下单或取消寄件，该橱窗下所有地址记录和补邮审批都会被直接删除，不可恢复。橱窗本身保留，不影响用户正常领取。")
            }
        }
        // 多选模式底部工具条（网页：fixed bottom-16 rounded-2xl 已选N条 + 导出菜鸟模板 + 取消）
        .overlay(alignment: .bottom) {
            if selectMode {
                HStack(spacing: 12) {
                    Text("已选 \(selected.count) 条")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.appForeground)
                    Spacer()
                    Button { Task { await exportSelected() } } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 12))
                            Text("导出菜鸟模板")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.appPrimaryFg)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.appPrimary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(selected.isEmpty || busy)
                    .opacity(selected.isEmpty ? 0.5 : 1)
                    Button { selectMode = false; selected = [] } label: {
                        Text("取消")
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(Color.appCard)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appPrimary.opacity(0.3), lineWidth: 1))
                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
    }

    // MARK: 状态筛选行
    private var filterRow: some View {
        FlowLayout(spacing: 6, vSpacing: 6) {
            ForEach(ShipStatusKey.allCases) { f in
                Button { statusFilter = f } label: {
                    HStack(spacing: 4) {
                        Text(f.label)
                        if (statusCounts[f] ?? 0) > 0 {
                            Text("\(statusCounts[f] ?? 0)").opacity(0.7)
                        }
                    }
                    .font(.system(size: 12, weight: statusFilter == f ? .medium : .regular))
                    .foregroundColor(statusFilter == f ? Color.appPrimaryFg : Color.appSecondaryFg)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(statusFilter == f ? Color.appPrimary : Color.appSecondary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Text("长按（或右键）某条记录：删除 / 查看该用户寄件")
                .font(.system(size: 11))
                .foregroundColor(.appMutedFg)
        }
    }

    // MARK: 中通卡（暂不可用）
    private var ztoCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            FlowLayout(spacing: 8, vSpacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "link")
                        .font(.system(size: 13))
                        .foregroundColor(.appMutedFg)
                    Text("中通自动下单")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appMutedFg)
                }
                Text("暂不可用")
                    .font(.system(size: 11))
                    .foregroundColor(.appMutedFg)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.appSecondary)
                    .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                    .clipShape(Capsule())
                if zto?.bound == true && zto?.valid == true {
                    Text("已绑定 \(zto?.loginName ?? "")")
                        .font(.system(size: 11))
                        .foregroundColor(.fixEmerald700)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.fixEmerald100)
                        .clipShape(Capsule())
                }
                if zto?.bound == true && zto?.valid != true {
                    Text("登录已失效，请重新绑定")
                        .font(.system(size: 11))
                        .foregroundColor(.fixAmber700)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.fixAmber100)
                        .clipShape(Capsule())
                }
                Spacer(minLength: 0)
                if zto?.bound == true {
                    Button {
                        unbindConfirm = "解绑后寄件将不能选择中通自动下单，确定解绑？"
                        unbindAction = .zto
                    } label: {
                        Text("解绑")
                            .font(.system(size: 11))
                            .foregroundColor(.appMutedFg)
                    }
                    .buttonStyle(.plain)
                }
                Button { showZtoBind.toggle() } label: {
                    Text(zto?.bound == true ? "重新绑定" : (showZtoBind ? "收起" : "去绑定"))
                        .font(.system(size: 11))
                        .foregroundColor(.appPrimary)
                }
                .buttonStyle(.plain)
            }
            Text("中通直连下单暂时不稳定，正在修复中，绑定入口保留。当前请用「韵达自动下单」或「导出菜鸟批量寄件」。")
                .font(.system(size: 12))
                .foregroundColor(.appMutedFg)
                .padding(.top, 8)
            if showZtoBind {
                VStack(alignment: .leading, spacing: 8) {
                    stepList([
                        .init(parts: [("浏览器打开并登录 ", false), ("中通快递官网", true), ("", false)], link: ztoSingleURL),
                        .init(parts: [("按 F12 打开开发者工具 → Network（网络）→ 刷新页面，点任意一条 zto.com 请求", false)], link: nil),
                        .init(parts: [("在请求头（Headers）里找到 ", false), ("x-token", true), ("，复制它的值（eyJ 开头的一长串）", false)], link: nil),
                        .init(parts: [("粘贴到下面并保存。token 会加密保存在本站，只用于给你自己的寄件下单；在中通重新登录后旧 token 自动失效", false)], link: nil),
                    ])
                    tokenEditor($ztoTokenDraft, placeholder: "粘贴 x-token 的值（eyJ 开头的一长串）")
                    bindButton(disabled: ztoTokenDraft.count < 10) { await bindExpress(.zto) }
                }
                .padding(.top, 12)
            }
        }
        .padding(16)
        .background(Color.appCard)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 0.5))
        .cornerRadius(4)
        .opacity(0.6)
    }

    // MARK: 韵达卡（可直接寄件）
    private var yundaCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            FlowLayout(spacing: 8, vSpacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "link")
                        .font(.system(size: 13))
                        .foregroundColor(.appPrimary)
                    Text("韵达自动下单")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appForeground)
                }
                Text("可直接寄件")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.fixEmerald700)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.fixEmerald100)
                    .overlay(Capsule().stroke(Color.fixEmerald300, lineWidth: 0.5))
                    .clipShape(Capsule())
                if yunda?.bound == true && yunda?.valid == true {
                    Text("已绑定 \(yunda?.loginName ?? "")")
                        .font(.system(size: 11))
                        .foregroundColor(.fixEmerald700)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.fixEmerald100)
                        .clipShape(Capsule())
                }
                if yunda?.bound == true && yunda?.valid != true {
                    Text("登录已失效，请重新绑定")
                        .font(.system(size: 11))
                        .foregroundColor(.fixAmber700)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.fixAmber100)
                        .clipShape(Capsule())
                }
                Spacer(minLength: 0)
                if yunda?.bound == true {
                    Button {
                        unbindConfirm = "解绑后「寄快递」将回到手动复制地址模式，确定解绑？"
                        unbindAction = .yunda
                    } label: {
                        Text("解绑")
                            .font(.system(size: 11))
                            .foregroundColor(.appMutedFg)
                    }
                    .buttonStyle(.plain)
                }
                Button { showBind.toggle() } label: {
                    Text(yunda?.bound == true ? "重新绑定" : (showBind ? "收起" : "去绑定"))
                        .font(.system(size: 11))
                        .foregroundColor(.appPrimary)
                }
                .buttonStyle(.plain)
            }
            if yunda?.bound != true && !showBind {
                Text("绑定你自己的韵达会员账号后，点「寄快递」系统会用这条地址自动下单、自动回传运单号，不用再去菜鸟手动填。")
                    .font(.system(size: 12))
                    .foregroundColor(.appMutedFg)
                    .padding(.top, 8)
            }
            if board != nil && (board?.alipayAccount?.isEmpty ?? true) {
                (Text("你还没设置补邮支付宝账号——不包邮的橱窗下单后需要它通知领取人补邮。")
                    .font(.system(size: 11))
                    .foregroundColor(.fixAmber800)
                + Text("去设置")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.fixAmber800)
                    .underline())
                    .lineSpacing(3)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.fixAmber100)
                    .cornerRadius(3)
                    .padding(.top, 8)
                    .onTapGesture { showSettings = true }
            }
            if showBind {
                VStack(alignment: .leading, spacing: 8) {
                    stepList([
                        .init(parts: [("手机/电脑浏览器打开并登录 ", false), ("韵达会员中心", true), ("（membernew.yundasys.com:15443）", false)], link: nil),
                        .init(parts: [("登录成功后，在浏览器开发者工具的 Cookie 里复制 ", false), ("token", true), (" 的值（eyJ 开头的一长串）", false)], link: nil),
                        .init(parts: [("粘贴到下面并保存。token 会加密保存在本站，只用于给你自己的寄件下单；在韵达重新登录后旧 token 自动失效", false)], link: nil),
                    ])
                    tokenEditor($tokenDraft, placeholder: "粘贴 token（eyJ 开头的一长串）")
                    bindButton(disabled: tokenDraft.count < 20) { await bindExpress(.yunda) }
                }
                .padding(.top, 12)
            }
        }
        .padding(16)
        .background(Color.appCard)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 0.5))
        .cornerRadius(4)
    }

    // MARK: 菜鸟卡（暂不可用）
    private var cainiaoCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            FlowLayout(spacing: 8, vSpacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "box.truck")
                        .font(.system(size: 13))
                        .foregroundColor(.appMutedFg)
                    Text("菜鸟裹裹商家版")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appMutedFg)
                }
                Text("暂不可用")
                    .font(.system(size: 11))
                    .foregroundColor(.appMutedFg)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.appSecondary)
                    .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                    .clipShape(Capsule())
                if cainiao?.bound == true && cainiao?.valid == true {
                    Text("已绑定 \(cainiao?.nick ?? "")")
                        .font(.system(size: 11))
                        .foregroundColor(.fixEmerald700)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.fixEmerald100)
                        .clipShape(Capsule())
                }
                if cainiao?.bound == true && cainiao?.valid != true {
                    Text("登录已失效，请重新绑定")
                        .font(.system(size: 11))
                        .foregroundColor(.fixAmber700)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.fixAmber100)
                        .clipShape(Capsule())
                }
                Spacer(minLength: 0)
                if cainiao?.bound == true {
                    Button {
                        unbindConfirm = "解绑后寄件将不能选择菜鸟商家版自动下单，确定解绑？"
                        unbindAction = .cainiao
                    } label: {
                        Text("解绑")
                            .font(.system(size: 11))
                            .foregroundColor(.appMutedFg)
                    }
                    .buttonStyle(.plain)
                }
                Button { showCnBind.toggle() } label: {
                    Text(cainiao?.bound == true ? "重新绑定" : (showCnBind ? "收起" : "去绑定"))
                        .font(.system(size: 11))
                        .foregroundColor(.appPrimary)
                }
                .buttonStyle(.plain)
            }
            Text("菜鸟接口自动下单暂时不稳定，正在修复中，绑定入口保留。现在推荐「导出菜鸟批量寄件」→ 菜鸟官网批量上传 → 寄出后回本站点「已外部寄件」。")
                .font(.system(size: 12))
                .foregroundColor(.appMutedFg)
                .padding(.top, 8)
            if showCnBind {
                VStack(alignment: .leading, spacing: 8) {
                    stepList([
                        .init(parts: [("电脑浏览器打开并登录 ", false), ("菜鸟发货平台", true), ("（淘宝账号登录）", false)], link: URL(string: "https://fahuo.cainiao.com/web/order/ggSend.htm?tab=tb_order")),
                        .init(parts: [("按 F12 打开开发者工具 → Network（网络）→ 刷新页面，点任意一条 fahuo.cainiao.com 请求", false)], link: nil),
                        .init(parts: [("在请求头（Headers）里找到 ", false), ("Cookie", true), ("，整段复制粘贴到下面", false)], link: nil),
                        .init(parts: [("Cookie 会加密保存在本站，只用于给你自己的寄件下单；退出菜鸟登录后自动失效", false)], link: nil),
                    ])
                    tokenEditor($cnCookieDraft, placeholder: "粘贴 Cookie（很长的一串，形如 cookie2=…; t=…; _tb_token_=…）")
                    bindButton(disabled: cnCookieDraft.count < 30) { await bindExpress(.cainiao) }
                }
                .padding(.top, 12)
            }
        }
        .padding(16)
        .background(Color.appCard)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 0.5))
        .cornerRadius(4)
        .opacity(0.6)
    }

    // MARK: 我的寄件地址卡
    private var senderCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            FlowLayout(spacing: 8, vSpacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.system(size: 13))
                        .foregroundColor(.appPrimary)
                    Text("我的寄件地址")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appForeground)
                }
                Text("用于预估邮费（同城/省内更便宜）")
                    .font(.system(size: 11))
                    .foregroundColor(.appMutedFg)
            }
            if senderDraft == nil, let d = board {
                HStack(spacing: 8) {
                    Text(d.senderAddress?.isEmpty == false ? d.senderAddress! : "还没填，填上后预估邮费更准（默认同城 6 元档）")
                        .font(.system(size: 14))
                        .foregroundColor(.appForeground.opacity(0.8))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Button { senderDraft = d.senderAddress ?? "" } label: {
                        Text(d.senderAddress?.isEmpty == false ? "修改" : "填写")
                            .font(.system(size: 12))
                            .foregroundColor(.appForeground)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)
            } else {
                HStack(spacing: 8) {
                    AppTextField(text: Binding(get: { senderDraft ?? "" }, set: { senderDraft = $0 }),
                                 placeholder: "例如：浙江省杭州市西湖区…")
                    Button { Task { await saveSender() } } label: {
                        Text("保存")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.appPrimaryFg)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.appPrimary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(busy)
                    Button { senderDraft = nil } label: {
                        Text("取消")
                            .font(.system(size: 12))
                            .foregroundColor(.appForeground)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
        .background(Color.appCard)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 0.5))
        .cornerRadius(4)
    }

    // MARK: 菜鸟批量寄件指引卡
    private var cainiaoGuideCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("不使用韵达？这样寄更省事")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.fixSky900)
            VStack(alignment: .leading, spacing: 6) {
                guideStep(1, parts: [("在下方点「", false), ("导出菜鸟批量寄件", true), ("」（不要点「预下单」），下载表格", false)])
                HStack(alignment: .top, spacing: 0) {
                    Text("2. ")
                        .font(.system(size: 13))
                        .foregroundColor(.fixSky800)
                    (Text("登录 ").font(.system(size: 13)).foregroundColor(.fixSky800)
                     + Text("菜鸟发货平台").font(.system(size: 13, weight: .medium)).foregroundColor(.fixSky800).underline()
                     + Text(" → 批量寄件 → 上传表格，一键下单").font(.system(size: 13)).foregroundColor(.fixSky800))
                        .lineSpacing(7)
                        .onTapGesture { UIApplication.shared.open(cainiaoFahuoURL) }
                }
                guideStep(3, parts: [("寄出后回到本站，对应记录点「", false), ("已外部寄件", true), ("」：填写单号、可选上传邮费凭证；不包邮的填一下收取的邮费", false)])
            }
            .padding(.top, 8)
            .padding(.leading, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.fixSky50.opacity(0.7))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.fixSky50, lineWidth: 0.5))
        .cornerRadius(4)
    }

    private func guideStep(_ n: Int, parts: [(String, Bool)]) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text("\(n). ")
                .font(.system(size: 13))
                .foregroundColor(.fixSky800)
            parts.reduce(Text("")) { acc, p in
                acc + Text(p.0).font(.system(size: 13, weight: p.1 ? .semibold : .regular)).foregroundColor(.fixSky800)
            }
            .lineSpacing(7)
        }
    }

    // MARK: 橱窗分组卡
    private func groupCard(_ g: ShipGroup) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题行
            FlowLayout(spacing: 12, vSpacing: 4) {
                if g.removed == true {
                    Text(g.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.appMutedFg)
                        .lineLimit(1)
                        // 长按橱窗标题（500ms）：彻底删除该橱窗所有寄件记录（网页同款）
                        .onLongPressGesture(minimumDuration: 0.5) {
                            showcaseDeleteTarget = (g.showcaseId, g.title, g.items.count)
                        }
                } else {
                    NavigationLink(destination: ShowcaseDetailView(showcaseId: g.showcaseId)) {
                        Text(g.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.appForeground)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                        showcaseDeleteTarget = (g.showcaseId, g.title, g.items.count)
                    })
                }
                if g.removed == true {
                    Text("已删除")
                        .font(.system(size: 11))
                        .foregroundColor(.appMutedFg)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.appSecondary)
                        .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                        .clipShape(Capsule())
                }
                Text("\(g.items.count) 条地址")
                    .font(.system(size: 11))
                    .foregroundColor(.appMutedFg)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.appSecondary)
                    .clipShape(Capsule())
                if g.shippingFree == true {
                    Text("包邮")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.fixEmerald700)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.fixEmerald100)
                        .overlay(Capsule().stroke(Color.fixEmerald300, lineWidth: 0.5))
                        .clipShape(Capsule())
                }
                if g.shippingFree == false {
                    Text("不包邮")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.fixAmber700)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.fixAmber100)
                        .overlay(Capsule().stroke(Color.fixAmber300, lineWidth: 0.5))
                        .clipShape(Capsule())
                }
                Button { Task { await exportExcel(showcaseId: g.showcaseId) } } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 10))
                        Text("导出")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.appMutedFg)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .disabled(busy)
                // 多选导出（2026-10-10：进入后每条记录前出现圆形勾选框，底部弹工具条）
                Button {
                    selectMode.toggle()
                    if !selectMode { selected = [] }
                } label: {
                    Text(selectMode ? "退出多选" : "多选导出")
                        .font(.system(size: 11))
                        .foregroundColor(selectMode ? .appPrimaryFg : .appMutedFg)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(selectMode ? Color.appPrimary : Color.clear)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(selectMode ? Color.clear : Color.appBorder, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                if (g.hiddenCount ?? 0) > 0 {
                    Button { Task { await unhideShowcase(g) } } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "eye")
                                .font(.system(size: 10))
                            Text("已隐藏 \(g.hiddenCount ?? 0) 条 · 全部恢复")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.fixAmber700)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.fixAmber100)
                        .overlay(Capsule().stroke(Color.fixAmber300, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .disabled(busy)
                }
                HStack(spacing: 4) {
                    Spacer(minLength: 0)
                    Text("橱窗邮费预估 ")
                        .font(.system(size: 12))
                        .foregroundColor(.appMutedFg)
                    + Text("¥\(g.subtotal ?? 0)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.appForeground)
                    + Text((g.unpaidSubtotal ?? 0) > 0 ? "  " : "")
                        .font(.system(size: 12))
                    + Text((g.unpaidSubtotal ?? 0) > 0 ? "待付 ¥\(g.unpaidSubtotal ?? 0)" : "")
                        .font(.system(size: 12))
                        .foregroundColor(.fixAmber600)
                    Button { toggleCollapsed(g.showcaseId) } label: {
                        Image(systemName: (collapsed[g.showcaseId] ?? false) ? "chevron.down" : "chevron.up")
                            .font(.system(size: 13))
                            .foregroundColor(.appMutedFg)
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if !(collapsed[g.showcaseId] ?? false) {
                Rectangle().fill(Color.appBorder.opacity(0.6)).frame(height: 0.5)
                VStack(spacing: 0) {
                    ForEach(g.items) { a in
                        shipRow(a, group: g)
                        if a.id != g.items.last?.id {
                            Rectangle().fill(Color.appBorder.opacity(0.5)).frame(height: 0.5)
                        }
                    }
                }
            }
        }
        .background(Color.appCard)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appBorder, lineWidth: 0.5))
        .cornerRadius(5)
    }

    // MARK: 单条寄件记录
    private func shipRow(_ a: ShipItem, group g: ShipGroup) -> some View {
        let isEditing = editing[a.id] != nil
        return VStack(alignment: .leading, spacing: 0) {
            // 地址行 + 复制/隐藏（多选模式下前面带圆形勾选框，点勾选框或地址文字都能选中）
            HStack(alignment: .top, spacing: 8) {
                if selectMode {
                    Button { toggleSelect(a.id) } label: {
                        Image(systemName: selected.contains(a.id) ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18))
                            .foregroundColor(selected.contains(a.id) ? .appPrimary : .appMutedFg)
                    }
                    .buttonStyle(.plain)
                }
                Text(a.full ?? a.address)
                    .font(.system(size: 12))
                    .foregroundColor(.appForeground.opacity(0.9))
                    .lineSpacing(8)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { if selectMode { toggleSelect(a.id) } }
                Button {
                    UIPasteboard.general.string = a.full ?? a.address
                    ToastCenter.shared.success("地址已复制")
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundColor(.appMutedFg)
                        .padding(4)
                }
                .buttonStyle(.plain)
                Button { Task { await setHidden(a, hidden: true) } } label: {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 12))
                        .foregroundColor(.appMutedFg)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .disabled(busy)
            }

            // 单号 / 状态行
            FlowLayout(spacing: 8, vSpacing: 6) {
                if a.shipState == "cancelled" {
                    shipBadgeView("已取消", bg: .appBrand100, fg: .appBrand600, ring: .appBrand200)
                }
                if a.shipState == "external" {
                    shipBadgeView("已外部寄件", bg: .fixViolet100, fg: .fixViolet700, ring: .fixViolet300)
                }
                if a.shipState == "external", let no = a.trackingNo, !no.isEmpty {
                    shipBadgeView("外部寄件单号 \(no)", bg: .fixViolet100, fg: .fixViolet700, ring: .fixViolet200, mono: true, semibold: false)
                }
                if a.shipState == "preorder" {
                    if a.preorderApproved == true {
                        HStack(spacing: 4) {
                            Text("已补邮·等待自动下单")
                                .font(.system(size: 11, weight: .semibold))
                            if let t = a.autoShipAt {
                                Text("\(monthDay(of: t)) 9:00")
                                    .font(.system(size: 11))
                                    .opacity(0.8)
                            }
                        }
                        .foregroundColor(.fixEmerald700)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.fixEmerald100)
                        .overlay(Capsule().stroke(Color.fixEmerald300, lineWidth: 0.5))
                        .clipShape(Capsule())
                    } else {
                        HStack(spacing: 4) {
                            Text("预下单·待审批")
                                .font(.system(size: 11, weight: .semibold))
                            if let ms = a.preorderRemainMs {
                                Text("剩约 \(Int(ceil(Double(ms) / 3600000.0)))h")
                                    .font(.system(size: 11))
                                    .opacity(0.8)
                            }
                        }
                        .foregroundColor(.fixSky700)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.fixSky50)
                        .overlay(Capsule().stroke(Color.fixSky300, lineWidth: 0.5))
                        .clipShape(Capsule())
                    }
                }
                if (a.trackingNo?.isEmpty ?? true) && (a.yundaOrderId?.isEmpty ?? true) && (a.ztoOrderId?.isEmpty ?? true)
                    && a.shipState != "cancelled" && a.shipState != "external" && a.shipState != "preorder" {
                    shipBadgeView("未下单", bg: .appSecondary, fg: .appMutedFg, semibold: false)
                }
                if let no = a.trackingNo, !no.isEmpty, (a.yundaOrderId?.isEmpty ?? true), (a.ztoOrderId?.isEmpty ?? true), a.shipState != "external" {
                    shipBadgeView("\(a.cainiaoCpName?.isEmpty == false ? a.cainiaoCpName! : "韵达") \(no)", bg: .appSecondary, fg: .appForeground, mono: true, semibold: false)
                }
                if let no = a.trackingNo, !no.isEmpty, (a.ztoOrderId?.isEmpty == false) {
                    shipBadgeView("中通 \(no)", bg: .appSecondary, fg: .appForeground, mono: true, semibold: false)
                }
                if let st = a.shipStatus, !st.isEmpty {
                    shipStatusBadge(st)
                }
                if let code = a.pickupCode, !code.isEmpty {
                    HStack(spacing: 4) {
                        Text("取货码 ")
                            .font(.system(size: 11, weight: .semibold))
                        + Text(code)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        Button {
                            UIPasteboard.general.string = code
                            ToastCenter.shared.success("取货码已复制")
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 10))
                                .foregroundColor(.fixViolet700)
                        }
                        .buttonStyle(.plain)
                    }
                    .foregroundColor(.fixViolet700)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.fixViolet100)
                    .overlay(Capsule().stroke(Color.fixViolet300, lineWidth: 0.5))
                    .clipShape(Capsule())
                }
                if let at = a.pickupAt, !at.isEmpty {
                    shipBadgeView("预约 \(monthDayString(at)) 取件", bg: .fixSky50, fg: .fixSky700, ring: .fixSky50, semibold: false)
                }
                if (a.trackingNo?.isEmpty ?? true) && ((a.yundaOrderId?.isEmpty == false) || (a.ztoOrderId?.isEmpty == false)) && a.shipState == "ordered" {
                    HStack(spacing: 4) {
                        Text("已下单·待揽收")
                            .font(.system(size: 11, design: .monospaced))
                        Button { Task { await load() } } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10))
                                .foregroundColor(.fixSky700)
                        }
                        .buttonStyle(.plain)
                    }
                    .foregroundColor(.fixSky700)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.fixSky50)
                    .clipShape(Capsule())
                }

                if a.shippingPaid == true {
                    shipBadgeView("已付款", bg: .fixEmerald100, fg: .fixEmerald700)
                } else {
                    shipBadgeView("待付款", bg: .fixAmber100, fg: .fixAmber700, ring: .fixAmber300)
                        .font(.system(size: 11, weight: .bold))
                    if let fr = a.freightActual, !fr.isEmpty {
                        Text("实际邮费 ")
                            .font(.system(size: 11))
                            .foregroundColor(.appMutedFg)
                        + Text("¥\(fr)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.appForeground)
                    } else if let fee = a.fee {
                        Text("预估邮费 ¥\(fee)")
                            .font(.system(size: 11))
                            .foregroundColor(.appMutedFg)
                        + Text("（\(a.feeLabel ?? "")）")
                            .font(.system(size: 11))
                            .foregroundColor(.fixAmber600)
                    }
                    Button { Task { await markPaid(a) } } label: {
                        Text("邮费已收齐")
                            .font(.system(size: 11))
                            .foregroundColor(.fixEmerald700)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .overlay(Capsule().stroke(Color.fixEmerald300, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .disabled(busy)
                }

                // 右侧动作（网页 ml-auto）
                rowActions(a, group: g, isEditing: isEditing)
            }
            .padding(.top, 8)

            // 单号填写（编辑态）
            if isEditing {
                HStack(spacing: 8) {
                    TextField("粘贴韵达快递单号", text: Binding(get: { editing[a.id] ?? "" }, set: { editing[a.id] = $0 }))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.appForeground)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.appInput, lineWidth: 0.5))
                    Button { Task { await saveTracking(a) } } label: {
                        Text("保存单号")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.appPrimaryFg)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.appPrimary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled((editing[a.id] ?? "").trimmingCharacters(in: .whitespaces).count < 4 || busy)
                    Button { editing.removeValue(forKey: a.id) } label: {
                        Text("取消")
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                userShipRoute = a.userId
            } label: {
                Label("查看该用户寄件（\(a.nickname.isEmpty ? "用户 #\(a.userId)" : a.nickname)）", systemImage: "person")
            }
            Button(role: .destructive) {
                deleteTarget = a
            } label: {
                Label("删除这条记录（不可恢复）", systemImage: "trash")
            }
        }
    }

    // MARK: 行内右侧动作分支（对应网页 944-1051 行）
    @ViewBuilder
    private func rowActions(_ a: ShipItem, group g: ShipGroup, isEditing: Bool) -> some View {
        if a.shipState == "preorder" {
            Button {
                cancelConfirm = a.preorderApproved == true
                    ? "取消这次预下单？对方已补邮\(a.fee != nil ? " ¥\(a.fee!)" : "")（未真实下单，不会通知快递员），取消后请私信协商退回补邮。"
                    : "取消这次预下单？从未真实下单，不会通知快递员，收件人会收到通知。"
                cancelTarget = a.id
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 10))
                    Text("取消预下单")
                        .font(.system(size: 11))
                }
                .foregroundColor(.appDestructive)
            }
            .buttonStyle(.plain)
            .disabled(busy)
        } else if let no = a.trackingNo, !no.isEmpty, (a.yundaOrderId?.isEmpty ?? true), (a.ztoOrderId?.isEmpty ?? true), !isEditing {
            Button { editing[a.id] = a.trackingNo ?? "" } label: {
                Text("改单号")
                    .font(.system(size: 11))
                    .foregroundColor(.appMutedFg)
            }
            .buttonStyle(.plain)
            Button {
                cancelConfirm = "取消这次寄件？单号会清空、回到待寄状态，收件人会收到通知。"
                cancelTarget = a.id
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 10))
                    Text("取消寄件")
                        .font(.system(size: 11))
                }
                .foregroundColor(.appDestructive)
            }
            .buttonStyle(.plain)
            .disabled(busy)
        } else if (a.yundaOrderId?.isEmpty == false) || (a.ztoOrderId?.isEmpty == false) {
            Button {
                let channelName = (a.ztoOrderId?.isEmpty == false) ? "中通" : "韵达"
                cancelConfirm = "取消这次寄件？会同时取消\(channelName)订单（已被揽收则取消失败），收件人会收到通知。"
                cancelTarget = a.id
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 10))
                    Text("取消寄件")
                        .font(.system(size: 11))
                }
                .foregroundColor(.appDestructive)
            }
            .buttonStyle(.plain)
            .disabled(busy)
        } else if a.shipState == "external" {
            Button {
                extTarget = ExtTarget(id: a.id, full: a.full ?? a.address, shippingFree: g.shippingFree == true)
            } label: {
                Text((a.trackingNo?.isEmpty == false) ? "改单号" : "补单号")
                    .font(.system(size: 11))
                    .foregroundColor(.appMutedFg)
            }
            .buttonStyle(.plain)
            Button {
                cancelConfirm = "撤销「已外部寄件」标记，回到未下单状态？"
                cancelTarget = a.id
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 10))
                    Text("撤销标记")
                        .font(.system(size: 11))
                }
                .foregroundColor(.appMutedFg)
            }
            .buttonStyle(.plain)
            .disabled(busy)
        } else {
            Button {
                itemName = String("\(g.title)无料".prefix(30))
                weight = "1"
                testMode = false
                confirmShip = ShipTarget(id: a.id, full: a.full ?? a.address, fee: a.fee,
                                         feeLabel: a.feeLabel ?? "", showcaseTitle: g.title,
                                         shippingFree: g.shippingFree == true)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "box.truck")
                        .font(.system(size: 12))
                    Text(g.shippingFree == true ? "寄快递" : "预下单")
                        .font(.system(size: 12))
                }
                .foregroundColor(.appPrimaryFg)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.appPrimary)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            Button {
                extTarget = ExtTarget(id: a.id, full: a.full ?? a.address, shippingFree: g.shippingFree == true)
            } label: {
                Text("已外部寄件")
                    .font(.system(size: 11))
                    .foregroundColor(.appMutedFg)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            Button {
                cancelConfirm = a.shippingPaid == true
                    ? "取消这条寄件？对方已补邮\(a.fee != nil ? " ¥\(a.fee!)" : "")，取消后请私信协商退回。记录会标记为已取消，收件人会收到通知。"
                    : "取消这条寄件？记录会标记为已取消，收件人会收到通知。"
                cancelTarget = a.id
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 10))
                    Text("取消寄件")
                        .font(.system(size: 11))
                }
                .foregroundColor(.appDestructive)
            }
            .buttonStyle(.plain)
            .disabled(busy)
        }
    }

    // MARK: 全部汇总卡
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            FlowLayout(spacing: 16, vSpacing: 4) {
                Text("全部橱窗邮费汇总")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appForeground)
                Text("预估合计 ")
                    .font(.system(size: 14))
                    .foregroundColor(.appForeground)
                + Text("¥\(board?.grandTotal ?? 0)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.appForeground)
                if (board?.grandUnpaid ?? 0) > 0 {
                    Text("待收齐 ")
                        .font(.system(size: 14))
                        .foregroundColor(.fixAmber700)
                    + Text("¥\(board?.grandUnpaid ?? 0)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.fixAmber700)
                }
                Spacer(minLength: 0)
                Button { Task { await exportCainiaoAll() } } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 12))
                        Text("导出菜鸟批量寄件")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.appPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.appCard)
                    .overlay(Capsule().stroke(Color.appPrimary.opacity(0.4), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .disabled(busy)
                Button { Task { await exportExcel(showcaseId: 0) } } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 12))
                        Text("导出\(statusFilter == .all ? "全部" : statusFilter.label) Excel")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.appMutedFg)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.appCard)
                    .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .disabled(busy)
            }
            if let rule = board?.rule, !rule.isEmpty {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 10))
                        .foregroundColor(.appMutedFg)
                        .padding(.top, 2)
                    Text(rule)
                        .font(.system(size: 11))
                        .foregroundColor(.appMutedFg)
                        .lineSpacing(3)
                }
                .padding(.top, 6)
            }
        }
        .padding(16)
        .background(Color.appPrimary.opacity(0.05))
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appPrimary.opacity(0.3), lineWidth: 0.5))
        .cornerRadius(5)
    }

    // MARK: 弹窗与动作所需状态（声明位置不影响布局）
    @State private var cancelConfirm: String? = nil
    @State private var cancelTarget: Int? = nil
    @State private var unbindConfirm: String? = nil
    @State private var unbindAction: ExpressKind? = nil
    @State private var showSettings = false

    enum ExpressKind { case yunda, zto, cainiao }

    // MARK: 寄快递确认弹窗（网页 confirmShip Dialog）
    private func shipConfirmSheet(_ t: ShipTarget) -> some View {
        let yundaOK = yunda?.bound == true && yunda?.valid == true
        return NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    // 收件地址盒
                    VStack(alignment: .leading, spacing: 4) {
                        Text("收件地址")
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                        Text(t.full)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.appForeground)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appSecondary.opacity(0.4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 0.5))
                    .cornerRadius(4)

                    if yundaOK {
                        // 渠道三按钮
                        HStack(spacing: 8) {
                            channelButton("中通（暂不可用）", enabled: false, selected: false) {}
                            channelButton("韵达自动下单", enabled: true, selected: true) {}
                            channelButton("菜鸟（暂不可用）", enabled: false, selected: false) {}
                        }
                        // 模拟下单
                        Button { testMode.toggle() } label: {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: testMode ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 14))
                                    .foregroundColor(testMode ? .appPrimary : .appMutedFg)
                                Text("模拟下单（测试用：不真实调用快递平台，不产生真实订单，取消无影响）")
                                    .font(.system(size: 12))
                                    .foregroundColor(.appMutedFg)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .buttonStyle(.plain)
                        if testMode {
                            Text("当前为模拟模式：系统生成模拟单号与取货码，审批超时自动取消不会通知快递平台，可放心测试")
                                .font(.system(size: 12))
                                .foregroundColor(.fixSky800)
                                .lineSpacing(8)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.fixSky50)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.fixSky300.opacity(0.6), lineWidth: 0.5))
                                .cornerRadius(4)
                        }
                        // 物品名称 / 重量
                        VStack(alignment: .leading, spacing: 8) {
                            Text("物品名称")
                                .font(.system(size: 12))
                                .foregroundColor(.appMutedFg)
                            AppTextField(text: $itemName, placeholder: "")
                                .onChange(of: itemName) { if $0.count > 30 { itemName = String($0.prefix(30)) } }
                            Text("重量")
                                .font(.system(size: 12))
                                .foregroundColor(.appMutedFg)
                                .padding(.top, 4)
                            HStack(spacing: 8) {
                                ForEach(["1", "2", "3"], id: \.self) { w in
                                    Button { weight = w } label: {
                                        Text("\(w) kg")
                                            .font(.system(size: 12, weight: weight == w ? .semibold : .regular))
                                            .foregroundColor(weight == w ? Color.appPrimary : Color.appMutedFg)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 7)
                                            .background(weight == w ? Color.appPrimary.opacity(0.1) : Color.clear)
                                            .overlay(Capsule().stroke(weight == w ? Color.appPrimary : Color.appBorder, lineWidth: 0.5))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        if let fee = t.fee {
                            (Text("预估邮费 ")
                                .font(.system(size: 14))
                                .foregroundColor(.appForeground)
                             + Text("¥\(fee)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.appForeground)
                             + Text("（\(t.feeLabel)，以韵达实际为准）")
                                .font(.system(size: 12))
                                .foregroundColor(.fixAmber600))
                        }
                        Text(!t.shippingFree
                             ? "不包邮橱窗：创建预下单（不真实下单，不打扰快递员），系统会通过站内信+邮件通知领取人向你的补邮支付宝账号转账并上传凭证；你在「邮费审批」页审批（24 小时内），审批通过后系统自动真实下单，超时未通过预下单自动取消。"
                             : "确认后系统会立即用你的韵达账号真实下单，快递员会上门取件。建议在韵达会员中心开通「先寄后付」，邮费月结更省心；运单号生成后自动显示在这里。")
                            .font(.system(size: 12))
                            .foregroundColor(.fixAmber800)
                            .lineSpacing(8)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.fixAmber100)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.fixAmber300.opacity(0.6), lineWidth: 0.5))
                            .cornerRadius(4)
                        HStack(spacing: 8) {
                            Button { Task { await confirmAutoShip(t) } } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "box.truck")
                                        .font(.system(size: 14))
                                    Text(t.shippingFree ? "确认下单" : "确认预下单")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(.appPrimaryFg)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.appPrimary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(itemName.trimmingCharacters(in: .whitespaces).isEmpty || busy)
                            Button { confirmShip = nil } label: {
                                Text("取消")
                                    .font(.system(size: 14))
                                    .foregroundColor(.appForeground)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        if let fee = t.fee {
                            (Text("预估邮费 ")
                                .font(.system(size: 14))
                                .foregroundColor(.appForeground)
                             + Text("¥\(fee)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.appForeground)
                             + Text("（\(t.feeLabel)）")
                                .font(.system(size: 12))
                                .foregroundColor(.fixAmber600))
                        }
                        Text("建议先在菜鸟裹裹商家版开通「先寄后付」，邮费月结更省心；下单时选择「韵达」。")
                            .font(.system(size: 12))
                            .foregroundColor(.fixAmber800)
                            .lineSpacing(8)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.fixAmber100)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.fixAmber300.opacity(0.6), lineWidth: 0.5))
                            .cornerRadius(4)
                        Text(yunda?.bound == true
                             ? "韵达登录已失效，请先在上方重新绑定；或先手动去菜鸟寄件。"
                             : "确认后会打开菜鸟寄件页并复制好这条地址，粘贴下单、拿到单号后回来填写即可。绑定韵达账号后可自动下单。")
                            .font(.system(size: 11))
                            .foregroundColor(.appMutedFg)
                            .lineSpacing(3)
                        HStack(spacing: 8) {
                            Button { startShip(t) } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.on.clipboard")
                                        .font(.system(size: 14))
                                    Text("去寄件（复制地址）")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(.appPrimaryFg)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.appPrimary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            Button { confirmShip = nil } label: {
                                Text("取消")
                                    .font(.system(size: 14))
                                    .foregroundColor(.appForeground)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
            .background(Color.appBackground)
            .navigationTitle(!t.shippingFree ? "预下单（不真实下单）" : (yundaOK ? "自动下单（韵达）" : "寄快递（手动复制地址）"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private func channelButton(_ title: String, enabled: Bool, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: selected ? .semibold : .regular))
                .foregroundColor(!enabled ? Color.appMutedFg.opacity(0.6) : (selected ? Color.appPrimary : Color.appMutedFg))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selected ? Color.appPrimary.opacity(0.1) : Color.clear)
                .overlay(Capsule().stroke(selected ? Color.appPrimary : Color.appBorder, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    // MARK: 外部寄件弹窗（网页 extTarget Dialog）
    private func externalSheet(_ t: ExtTarget) -> some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("收件地址")
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                        Text(t.full)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.appForeground)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appSecondary.opacity(0.4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 0.5))
                    .cornerRadius(4)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("外部寄件单号（可留空）")
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                        TextField("填写其他快递的单号，不一定是韵达", text: $extTracking)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.appForeground)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.appInput, lineWidth: 0.5))
                    }

                    if !t.shippingFree {
                        VStack(alignment: .leading, spacing: 4) {
                            (Text("收取邮费（元）")
                                .font(.system(size: 12))
                                .foregroundColor(.appMutedFg)
                             + Text("*")
                                .font(.system(size: 12))
                                .foregroundColor(.appDestructive))
                            AppTextField(text: $extFee, placeholder: "向领取人收取的邮费")
                                .keyboardTypeIfPossible(.numberPad)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("运费凭证照片（可选，会随站内信发给领取人）")
                                .font(.system(size: 12))
                                .foregroundColor(.appMutedFg)
                            if let img = extProof {
                                HStack(spacing: 12) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.appBorder, lineWidth: 0.5))
                                    Button { showExtPicker = true } label: {
                                        Text("换一张")
                                            .font(.system(size: 12))
                                            .foregroundColor(.appForeground)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                                    }
                                    .buttonStyle(.plain)
                                }
                            } else {
                                Button { showExtPicker = true } label: {
                                    Text("上传照片")
                                        .font(.system(size: 12))
                                        .foregroundColor(.appForeground)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Text("不包邮橱窗：确认后按韵达下单相同流程，站内信+邮件通知领取人补邮金额和补邮账号，进入凭证审批；若已有进行中的审批，这里填的邮费不会重复生成。")
                            .font(.system(size: 11))
                            .foregroundColor(.appMutedFg)
                            .lineSpacing(3)
                    } else {
                        Text("该橱窗为包邮：确认后自动审批通过，不发邮件打扰领取人。")
                            .font(.system(size: 11))
                            .foregroundColor(.appMutedFg)
                            .lineSpacing(3)
                    }
                    Text("填写单号会通过站内信和邮件通知收件人（写明是外部寄件单号，不保证是韵达）。")
                        .font(.system(size: 11))
                        .foregroundColor(.appMutedFg)
                        .lineSpacing(3)

                    HStack(spacing: 8) {
                        Button { Task { await confirmExternal(t) } } label: {
                            Text("确认已寄出")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.appPrimaryFg)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.appPrimary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(busy || (!t.shippingFree && extFee.trimmingCharacters(in: .whitespaces).isEmpty))
                        Button {
                            extTarget = nil
                            extTracking = ""; extFee = ""; extProof = nil
                        } label: {
                            Text("取消")
                                .font(.system(size: 14))
                                .foregroundColor(.appForeground)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .background(Color.appBackground)
            .navigationTitle("已外部寄件")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: 步骤说明（网页 ol list-decimal）
    struct StepLine {
        let parts: [(String, Bool)]   // (文本, 是否强调)
        let link: URL?
    }

    private func stepList(_ steps: [StepLine]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                HStack(alignment: .top, spacing: 0) {
                    Text("\(idx + 1). ")
                        .font(.system(size: 11))
                        .foregroundColor(.appMutedFg)
                    let txt = step.parts.reduce(Text("")) { acc, p in
                        acc + Text(p.0)
                            .font(.system(size: 11, weight: p.1 ? .medium : .regular, design: p.1 ? .monospaced : .default))
                            .foregroundColor(p.1 ? (step.link != nil ? Color.appPrimary : Color.appForeground) : Color.appMutedFg)
                    }
                    if let link = step.link {
                        txt.underline(step.link != nil, color: .appPrimary)
                            .lineSpacing(9)
                            .onTapGesture { UIApplication.shared.open(link) }
                    } else {
                        txt.lineSpacing(9)
                    }
                }
                .padding(.leading, 4)
            }
        }
    }

    // MARK: token 输入框（网页 Textarea h-20 font-mono text-xs）
    private func tokenEditor(_ text: Binding<String>, placeholder: String) -> some View {
        ZStack(alignment: .topLeading) {
            if text.wrappedValue.isEmpty {
                Text(placeholder)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.appMutedFg.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
            }
            TextEditor(text: text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.appForeground)
                .frame(height: 80)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
        }
        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.appInput, lineWidth: 0.5))
    }

    // MARK: 验证并绑定按钮
    private func bindButton(disabled: Bool, action: @escaping () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            Text(busy ? "绑定中…" : "验证并绑定")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.appPrimaryFg)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.appPrimary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(disabled || busy)
    }

    // MARK: 数据加载
    private func load() async {
        loading = true
        async let b = try? MashanglingAPI.shared.address.shippingBoard()
        async let y = try? MashanglingAPI.shared.address.yundaStatus()
        async let z = try? MashanglingAPI.shared.address.ztoStatus()
        async let c = try? MashanglingAPI.shared.address.cainiaoStatus()
        board = await b
        yunda = await y
        zto = await z
        cainiao = await c
        loading = false
    }

    // MARK: 绑定 / 解绑
    private func bindExpress(_ kind: ExpressKind) async {
        busy = true
        defer { busy = false }
        do {
            switch kind {
            case .yunda:
                let r = try await MashanglingAPI.shared.address.bindYunda(token: tokenDraft)
                ToastCenter.shared.success("韵达账号绑定成功（\(r.loginName ?? "")），之后点「寄快递」会自动下单")
                tokenDraft = ""; showBind = false
            case .zto:
                let r = try await MashanglingAPI.shared.address.bindZto(token: ztoTokenDraft)
                ToastCenter.shared.success("中通账号绑定成功（\(r.loginName ?? "")），寄件时可选择中通自动下单")
                ztoTokenDraft = ""; showZtoBind = false
            case .cainiao:
                let r = try await MashanglingAPI.shared.address.bindCainiao(cookie: cnCookieDraft)
                ToastCenter.shared.success("菜鸟商家版绑定成功（\(r.nick ?? "")），寄件时可选择自动最低价下单")
                cnCookieDraft = ""; showCnBind = false
            }
            await load()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func unbind(_ kind: ExpressKind) async {
        busy = true
        defer { busy = false }
        do {
            switch kind {
            case .yunda:
                _ = try await MashanglingAPI.shared.address.unbindYunda()
                ToastCenter.shared.success("已解绑韵达账号")
            case .zto:
                _ = try await MashanglingAPI.shared.address.unbindZto()
                ToastCenter.shared.success("已解绑中通账号")
            case .cainiao:
                _ = try await MashanglingAPI.shared.address.unbindCainiao()
                ToastCenter.shared.success("已解绑菜鸟商家版")
            }
            await load()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    // MARK: 寄件地址保存
    private func saveSender() async {
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.address.saveSender(senderDraft ?? "")
            ToastCenter.shared.success("寄件地址已保存，预估邮费已更新")
            senderDraft = nil
            await load()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    // MARK: 去寄件（复制地址 + 打开菜鸟）
    private func startShip(_ t: ShipTarget) {
        UIPasteboard.general.string = t.full
        ToastCenter.shared.success("地址已复制，去菜鸟粘贴下单（选韵达），回来填单号")
        UIApplication.shared.open(cainiaoHomeURL)
        confirmShip = nil
        if editing[t.id] == nil { editing[t.id] = "" }
    }

    // MARK: 自动下单 / 预下单
    private func confirmAutoShip(_ t: ShipTarget) async {
        busy = true
        defer { busy = false }
        do {
            if !t.shippingFree {
                _ = try await MashanglingAPI.shared.address.preorderShip(
                    shareId: t.id, channel: "yunda",
                    itemName: itemName.trimmingCharacters(in: .whitespaces),
                    weight: weight, testMode: testMode)
                ToastCenter.shared.success("预下单成功（未真实下单）！已通知领取人补邮，审批通过后系统自动下单")
            } else {
                let r = try await MashanglingAPI.shared.address.autoShip(
                    shareId: t.id,
                    itemName: itemName.trimmingCharacters(in: .whitespaces),
                    weight: weight, testMode: testMode)
                if r.testMode == true {
                    ToastCenter.shared.success("模拟下单成功（韵达·测试，未真实下单）")
                } else if let mailNo = r.mailNo, !mailNo.isEmpty {
                    ToastCenter.shared.success("下单成功，韵达运单号：\(mailNo)")
                } else if r.needProof == true {
                    ToastCenter.shared.success("下单成功（预约两天后取件）！已通知领取人补邮并上传凭证，请在「邮费审批」里审批")
                } else {
                    ToastCenter.shared.success("下单成功！快递员揽收后生成运单号，稍后刷新即可看到")
                }
            }
            testMode = false
            confirmShip = nil
            await load()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    // MARK: 外部寄件确认
    private func confirmExternal(_ t: ExtTarget) async {
        busy = true
        defer { busy = false }
        do {
            var proofURL: String? = nil
            if let img = extProof { proofURL = ImageCodec.coverDataURL(from: img) }
            let feeVal: Int? = t.shippingFree ? nil : max(0, Int(extFee.trimmingCharacters(in: .whitespaces)) ?? 0)
            _ = try await MashanglingAPI.shared.address.markExternalShipped(
                shareId: t.id, trackingNo: extTracking.trimmingCharacters(in: .whitespaces),
                fee: feeVal, feeProof: proofURL)
            ToastCenter.shared.success("已标记为外部寄件，收件人会收到通知")
            extTarget = nil
            extTracking = ""; extFee = ""; extProof = nil
            await load()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    // MARK: 保存单号（手动）
    private func saveTracking(_ a: ShipItem) async {
        let no = (editing[a.id] ?? "").trimmingCharacters(in: .whitespaces)
        guard no.count >= 4 else { return }
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.address.ship(shareId: a.id, trackingNo: no)
            ToastCenter.shared.success("快递单号已保存：\(no)，收件人会收到通知")
            editing.removeValue(forKey: a.id)
            await load()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    // MARK: 取消寄件
    private func cancelShip(_ shareId: Int) async {
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.address.cancelShip(shareId: shareId)
            ToastCenter.shared.success("已取消寄件，回到待寄状态")
            await load()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    // MARK: 邮费已收齐
    private func markPaid(_ a: ShipItem) async {
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.address.markShippingPaid(shareId: a.id)
            ToastCenter.shared.success("已标记为已付款")
            await load()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    // MARK: 隐藏 / 恢复
    private func setHidden(_ a: ShipItem, hidden: Bool) async {
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.address.setShareHidden(shareId: a.id, hidden: hidden)
            ToastCenter.shared.success(hidden ? "已隐藏该条记录（橱窗标题栏可恢复）" : "已恢复显示")
            await load()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func unhideShowcase(_ g: ShipGroup) async {
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.address.unhideShowcaseShares(showcaseId: g.showcaseId)
            ToastCenter.shared.success("已恢复该橱窗下所有隐藏的记录")
            await load()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    // MARK: 删除记录
    private func deleteShare(_ a: ShipItem) async {
        busy = true
        defer { busy = false }
        do {
            let r = try await MashanglingAPI.shared.address.deleteShare(shareId: a.id)
            ToastCenter.shared.success(r.showcaseDeleted == true
                                       ? "记录已删除，该橱窗已无寄件记录，橱窗也一并删除"
                                       : "记录已彻底删除")
            await load()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    // MARK: 导出
    private func exportExcel(showcaseId: Int) async {
        do {
            let r = try await MashanglingAPI.shared.address.exportExcel(showcaseId: showcaseId, status: statusFilter.rawValue)
            guard let data = Data(base64Encoded: r.base64) else {
                ToastCenter.shared.error("表格数据解析失败"); return
            }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(r.filename)
            try data.write(to: url)
            exportItem = ExportFileItem(url: url)
            ToastCenter.shared.success("已导出 \(r.count ?? 0) 条寄件需求")
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func exportCainiaoAll() async {
        do {
            let r = try await MashanglingAPI.shared.address.exportCainiao(showcaseId: 0, userId: 0, status: "todo")
            guard let data = Data(base64Encoded: r.base64) else {
                ToastCenter.shared.error("表格数据解析失败"); return
            }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(r.filename)
            try data.write(to: url)
            exportItem = ExportFileItem(url: url)
            ToastCenter.shared.success("已导出 \(r.count ?? 0) 条菜鸟批量寄件模板，去菜鸟发货平台上传即可")
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    // MARK: 多选导出 / 橱窗记录删除（2026-10-10）

    private func toggleSelect(_ id: Int) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    /// 多选导出菜鸟模板（导出后保持选择，由用户手动退出，照网页行为）
    private func exportSelected() async {
        guard !selected.isEmpty else { ToastCenter.shared.error("请先勾选要导出的记录"); return }
        busy = true
        defer { busy = false }
        do {
            let r = try await MashanglingAPI.shared.address.exportCainiao(shareIds: Array(selected))
            guard let data = Data(base64Encoded: r.base64) else {
                ToastCenter.shared.error("表格数据解析失败"); return
            }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(r.filename)
            try data.write(to: url)
            exportItem = ExportFileItem(url: url)
            ToastCenter.shared.success("已导出 \(r.count ?? 0) 条菜鸟批量寄件模板，去菜鸟发货平台上传即可")
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    /// 彻底删除该橱窗下所有寄件记录（不删橱窗本身），成功后刷新列表
    private func deleteShowcaseShares(_ t: (showcaseId: Int, title: String, count: Int)) async {
        busy = true
        defer { busy = false }
        do {
            let n = try await MashanglingAPI.shared.address.deleteShowcaseShares(showcaseId: t.showcaseId)
            ToastCenter.shared.success("已删除该橱窗下 \(n) 条寄件记录")
            showcaseDeleteTarget = nil
            await load()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    // MARK: 时间工具
    private func monthDay(of ms: Int) -> String {
        let d = Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日"
        return f.string(from: d)
    }

    private func monthDayString(_ iso: String) -> String {
        guard let d = DateFmt.parse(iso) else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日"
        return f.string(from: d)
    }
}

// MARK: - 键盘类型小工具
private extension View {
    @ViewBuilder
    func keyboardTypeIfPossible(_ type: UIKeyboardType) -> some View {
        self.keyboardType(type)
    }
}

// MARK: - 审批状态徽标（网页 ShippingApprovals.tsx STATUS / ShippingApprovalDetail.tsx STATUS）
private func approvalBadgeColors(_ status: String?) -> (bg: Color, fg: Color, ring: Color) {
    switch status {
    case "auto_approved", "approved": return (.fixEmerald100, .fixEmerald700, .fixEmerald300)
    case "pending", "modify":         return (.fixSky50, .fixSky700, .fixSky300)
    case "submitted":                 return (.fixAmber100, .fixAmber700, .fixAmber300)
    case "rejected":                  return (.appBrand100, .appBrand600, .appBrand300)
    default:                          return (.appSecondary, .appMutedFg, .appBorder)
    }
}

private func approvalListLabel(_ status: String?) -> String {
    switch status {
    case "auto_approved": return "包邮 · 自动通过"
    case "pending":       return "待对方上传凭证"
    case "submitted":     return "待你审批"
    case "approved":      return "已通过"
    case "rejected":      return "未通过 · 已取消寄件"
    case "modify":        return "已退回 · 待重新上传"
    default:              return "已取消"
    }
}

private func approvalDetailLabel(_ status: String?) -> String {
    switch status {
    case "auto_approved": return "包邮 · 自动通过"
    case "pending":       return "待上传凭证"
    case "submitted":     return "待审批"
    case "approved":      return "已通过"
    case "rejected":      return "未通过 · 已取消寄件"
    case "modify":        return "需修改 · 请重新上传"
    default:              return "已取消"
    }
}

// MARK: - 邮费审批（网页 ShippingApprovals.tsx）
struct ShippingApprovalsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var data: ApprovalsResponse? = nil
    @State private var loading = true

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Button { dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12))
                        Text("返回快递后台")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.appMutedFg)
                }
                .buttonStyle(.plain)

                HStack(spacing: 8) {
                    Image(systemName: "list.clipboard")
                        .font(.system(size: 20))
                        .foregroundColor(.appPrimary)
                    Text("邮费审批")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.appForeground)
                    if let n = data?.pendingCount, n > 0 {
                        Text("\(n) 条待审批")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.appDestructive)
                            .clipShape(Capsule())
                    }
                }
                .padding(.top, 12)
                Text("包邮橱窗的地址会自动生成「包邮·自动通过」记录（不打扰，仅留档）；不包邮橱窗下单后，领取人上传的补邮转账截图会出现在这里，请在 24 小时内审批，超时自动取消寄件。")
                    .font(.system(size: 14))
                    .foregroundColor(.appMutedFg)
                    .padding(.top, 6)

                if loading {
                    VStack(spacing: 12) {
                        ForEach(0..<2, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.appSecondary)
                                .frame(height: 112)
                        }
                    }
                    .padding(.top, 24)
                } else if (data?.groups ?? []).isEmpty {
                    VStack(spacing: 0) {
                        Image(systemName: "shippingbox")
                            .font(.system(size: 32))
                            .foregroundColor(.appMutedFg)
                        Text("还没有任何邮费审批记录。")
                            .font(.system(size: 14))
                            .foregroundColor(.appMutedFg)
                            .padding(.top, 12)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 64)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 0.5, dash: [4, 3])))
                    .padding(.top, 24)
                } else {
                    ForEach(data?.groups ?? []) { g in
                        groupSection(g).padding(.top, 24)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground)
        .navigationTitle("邮费审批")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func groupSection(_ g: ApprovalsResponse.ApprovalGroup) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                NavigationLink(destination: ShowcaseDetailView(showcaseId: g.showcaseId)) {
                    Text(g.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.appForeground)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                Text("\((g.items ?? []).count) 条")
                    .font(.system(size: 11))
                    .foregroundColor(.appMutedFg)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.appSecondary)
                    .clipShape(Capsule())
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            Rectangle().fill(Color.appBorder.opacity(0.6)).frame(height: 0.5)
            VStack(spacing: 0) {
                ForEach(g.items ?? []) { a in
                    approvalRow(a)
                    if a.id != g.items?.last?.id {
                        Rectangle().fill(Color.appBorder.opacity(0.5)).frame(height: 0.5)
                    }
                }
            }
        }
        .background(Color.appCard)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appBorder, lineWidth: 0.5))
        .cornerRadius(5)
    }

    private func approvalRow(_ a: ApprovalsResponse.ApprovalItem) -> some View {
        NavigationLink(destination: ApprovalDetailView(approvalId: a.id)) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    FlowLayout(spacing: 8, vSpacing: 4) {
                        Text(a.claimerName ?? "")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.appForeground)
                        let c = approvalBadgeColors(a.status)
                        Text(approvalListLabel(a.status))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(c.fg)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(c.bg)
                            .overlay(Capsule().stroke(c.ring, lineWidth: 0.5))
                            .clipShape(Capsule())
                        if a.kind == "free" {
                            Text("包邮免审")
                                .font(.system(size: 11))
                                .foregroundColor(.appMutedFg)
                        } else if let fee = a.fee {
                            Text("预估 ¥\(fee)")
                                .font(.system(size: 11))
                                .foregroundColor(.appMutedFg)
                        }
                        if a.hasProof == true {
                            HStack(spacing: 2) {
                                Image(systemName: "checkmark.seal")
                                    .font(.system(size: 10))
                                Text("有凭证")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.fixEmerald600)
                        }
                    }
                    Text(DateFmt.zhFull(a.createdAt) + (a.submittedAt.map { " · 凭证提交于 \(DateFmt.zhFull($0))" } ?? ""))
                        .font(.system(size: 11))
                        .foregroundColor(.appMutedFg)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundColor(.appMutedFg)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        loading = true
        data = try? await MashanglingAPI.shared.address.approvals()
        loading = false
    }
}

// MARK: - 审批详情（网页 ShippingApprovalDetail.tsx）
struct ApprovalDetailView: View {
    let approvalId: Int

    @Environment(\.dismiss) private var dismiss
    @State private var detail: ApprovalDetail? = nil
    @State private var loading = true
    @State private var proof: UIImage? = nil
    @State private var showPicker = false
    @State private var modifyMode = false
    @State private var reason = ""
    @State private var preview = false
    @State private var busy = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Button { dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12))
                        Text(detail?.isOwner == true ? "返回邮费审批" : "返回消息")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.appMutedFg)
                }
                .buttonStyle(.plain)

                if loading {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.appSecondary)
                        .frame(height: 256)
                        .padding(.top, 16)
                } else if let d = detail {
                    HStack(spacing: 8) {
                        Text("补邮凭证")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.appForeground)
                        let c = approvalBadgeColors(d.status)
                        Text(approvalDetailLabel(d.status))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(c.fg)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 2)
                            .background(c.bg)
                            .overlay(Capsule().stroke(c.ring, lineWidth: 0.5))
                            .clipShape(Capsule())
                    }
                    .padding(.top, 12)
                    Text("「\(d.showcaseTitle ?? "")」 · \(d.isOwner == true ? "领取人：\(d.claimerName ?? "")" : "你是领取人")")
                        .font(.system(size: 14))
                        .foregroundColor(.appMutedFg)
                        .padding(.top, 4)

                    // 费用与账号卡
                    VStack(alignment: .leading, spacing: 12) {
                        if let fee = d.fee {
                            (Text("预估邮费 ")
                                .font(.system(size: 14))
                                .foregroundColor(.appForeground)
                             + Text("¥\(fee)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.appForeground)
                             + Text("（菜鸟商家价，以实际为准）")
                                .font(.system(size: 12))
                                .foregroundColor(.appMutedFg))
                        }
                        if let acc = d.alipayAccount, !acc.isEmpty {
                            HStack(spacing: 8) {
                                (Text("补邮支付宝账号：")
                                    .font(.system(size: 14))
                                    .foregroundColor(.appForeground)
                                 + Text(acc)
                                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.appForeground))
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Button {
                                    UIPasteboard.general.string = acc
                                    ToastCenter.shared.success("账号已复制")
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 12))
                                        .foregroundColor(.appMutedFg)
                                        .padding(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        if let addr = d.addressFull, !addr.isEmpty {
                            Text("收件：\(addr)")
                                .font(.system(size: 12))
                                .foregroundColor(.appMutedFg)
                                .lineSpacing(8)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let ms = d.remainMs {
                            Text("审批剩余约 \(ms / 3600000) 小时，超时自动取消寄件")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.fixAmber600)
                        }
                        if let r = d.reason, !r.isEmpty {
                            Text("发布者要求修改：\(r)")
                                .font(.system(size: 12))
                                .foregroundColor(.fixAmber800)
                                .lineSpacing(8)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.fixAmber100)
                                .cornerRadius(3)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appCard)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appBorder, lineWidth: 0.5))
                    .cornerRadius(5)
                    .padding(.top, 16)

                    // 凭证图
                    if let img = d.proofImage, !img.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("转账截图（点开看大图）")
                                .font(.system(size: 12))
                                .foregroundColor(.appMutedFg)
                            Button { preview = true } label: {
                                AppImage(path: img)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: .infinity, maxHeight: 256)
                                    .cornerRadius(4)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 16)
                    }

                    // 领取人：上传凭证
                    if d.isOwner != true && (d.status == "pending" || d.status == "modify") {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("上传凭证")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.appForeground)
                            Text(d.alipayAccount?.isEmpty == false
                                 ? "请先用支付宝向上面的补邮账号转账，然后在这里上传支付宝转账截图（含金额和订单号）。"
                                 : "发布者暂未填写补邮账号，请先私信联系对方获取补邮方式，转账后在这里上传支付宝转账截图。")
                                .font(.system(size: 12))
                                .foregroundColor(.appMutedFg)
                                .lineSpacing(8)
                                .padding(.top, 4)
                            HStack(spacing: 12) {
                                if let img = proof {
                                    Image(uiImage: img)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.appBorder, lineWidth: 0.5))
                                    Button { showPicker = true } label: {
                                        Text("换一张")
                                            .font(.system(size: 12))
                                            .foregroundColor(.appMutedFg)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    Button { showPicker = true } label: {
                                        Image(systemName: "photo.badge.plus")
                                            .font(.system(size: 20))
                                            .foregroundColor(.appMutedFg)
                                            .frame(width: 80, height: 80)
                                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 0.5, dash: [4, 3])))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.top, 12)
                            Button { Task { await uploadProof(d) } } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.seal")
                                        .font(.system(size: 14))
                                    Text(busy ? "提交中…" : "提交凭证")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(.appPrimaryFg)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.appPrimary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(proof == nil || busy)
                            .padding(.top, 12)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appPrimary.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appPrimary.opacity(0.3), lineWidth: 0.5))
                        .cornerRadius(5)
                        .padding(.top, 16)
                    }

                    // 发布人：审批
                    if d.isOwner == true && d.status == "submitted" {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("审批这条补邮")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.appForeground)
                            Text("请先在支付宝确认收到转账再点「同意」。不同意会直接取消这次寄件；需修改会退回给对方重新上传。")
                                .font(.system(size: 12))
                                .foregroundColor(.appMutedFg)
                                .lineSpacing(8)
                                .padding(.top, 4)
                            if modifyMode {
                                TextEditor(text: $reason)
                                    .font(.system(size: 14))
                                    .foregroundColor(.appForeground)
                                    .frame(height: 80)
                                    .padding(4)
                                    .scrollContentBackground(.hidden)
                                    .background(Color.appCard)
                                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.appInput, lineWidth: 0.5))
                                    .padding(.top, 12)
                                HStack(spacing: 8) {
                                    Button { Task { await review(d, action: "modify") } } label: {
                                        Text(busy ? "提交中…" : "提交退回")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.appPrimaryFg)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(Color.appPrimary)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(reason.trimmingCharacters(in: .whitespaces).isEmpty || busy)
                                    Button { modifyMode = false } label: {
                                        Text("返回")
                                            .font(.system(size: 14))
                                            .foregroundColor(.appForeground)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.top, 12)
                            } else {
                                HStack(spacing: 8) {
                                    Button { Task { await review(d, action: "approve") } } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "checkmark.circle")
                                                .font(.system(size: 14))
                                            Text("同意")
                                                .font(.system(size: 14, weight: .medium))
                                        }
                                        .foregroundColor(.appPrimaryFg)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Color.appPrimary)
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(busy)
                                    Button { modifyMode = true } label: {
                                        Text("需修改")
                                            .font(.system(size: 14))
                                            .foregroundColor(.appForeground)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(busy)
                                    Button { showRejectConfirm = true } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "xmark.circle")
                                                .font(.system(size: 14))
                                            Text("不同意")
                                                .font(.system(size: 14))
                                        }
                                        .foregroundColor(.appDestructive)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(busy)
                                }
                                .padding(.top, 12)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appPrimary.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appPrimary.opacity(0.3), lineWidth: 0.5))
                        .cornerRadius(5)
                        .padding(.top, 16)
                    }
                } else {
                    Text("审批记录不存在")
                        .font(.system(size: 14))
                        .foregroundColor(.appMutedFg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 64)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground)
        .navigationTitle("补邮凭证")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(isPresented: $showPicker) { ImagePicker(image: $proof) }
        .fullScreenCover(isPresented: $preview) {
            if let img = detail?.proofImage { ImageViewerCover(path: img) }
        }
        .alert("不同意补邮", isPresented: $showRejectConfirm) {
            Button("取消", role: .cancel) {}
            Button("不同意", role: .destructive) {
                if let d = detail { Task { await review(d, action: "reject") } }
            }
        } message: {
            Text("不同意会直接取消这次寄件（韵达订单一并取消），确定？")
        }
    }

    @State private var showRejectConfirm = false

    private func load() async {
        loading = true
        detail = try? await MashanglingAPI.shared.address.approvalDetail(id: approvalId)
        loading = false
    }

    private func uploadProof(_ d: ApprovalDetail) async {
        guard let img = proof, let dataURL = ImageCodec.coverDataURL(from: img) else {
            ToastCenter.shared.error("图片处理失败"); return
        }
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.address.uploadProof(approvalId: d.id, image: dataURL)
            ToastCenter.shared.success("凭证已提交，发布者会在 24 小时内审批")
            proof = nil
            await load()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func review(_ d: ApprovalDetail, action: String) async {
        busy = true
        defer { busy = false }
        do {
            let r = try await MashanglingAPI.shared.address.reviewApproval(
                approvalId: d.id, action: action,
                reason: reason.trimmingCharacters(in: .whitespaces))
            ToastCenter.shared.success(
                r.status == "approved" ? "已通过，该地址标记为已付款"
                : r.status == "rejected" ? "未通过，寄件已取消"
                : "已退回，等待对方重新上传")
            modifyMode = false
            reason = ""
            await load()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}

// MARK: - 我的快递（网页 MyShipments.tsx，领取人视角）
struct MyShipmentsView: View {
    @State private var data: MyShipmentsResponse? = nil
    @State private var loading = true
    @State private var feeOpen = true
    @State private var now = Date()
    // 发货处理进度（2026-10-10：折叠区块，展开才调接口）
    @State private var queueOpen = false
    @State private var queue: ShipQueueResponse? = nil
    @State private var queueLoading = false
    @State private var queuePushId: Int? = nil

    private var groups: [MyShipmentsResponse.MyShipGroup] { data?.groups ?? [] }
    private var pendingFees: [MyShipmentsResponse.PendingFee] { data?.pendingFees ?? [] }
    private var total: Int { groups.reduce(0) { $0 + ($1.items?.count ?? 0) } }
    private var activeFeeCount: Int { pendingFees.filter { $0.status != "cancelled" && $0.status != "approved" }.count }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "box.truck")
                        .font(.system(size: 20))
                        .foregroundColor(.appPrimary)
                    Text("我的快递")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.appForeground)
                }
                Text("你领取的无料里，发布者已发货并回传单号的包裹都集中在这里。不包邮的会同时显示补邮审批结果；点单号可复制，去菜鸟粘贴即可查物流。")
                    .font(.system(size: 14))
                    .foregroundColor(.appMutedFg)
                    .padding(.top, 8)

                shipQueueSection.padding(.top, 24)

                if !loading && !pendingFees.isEmpty {
                    feeSection.padding(.top, 24)
                }

                if loading {
                    VStack(spacing: 12) {
                        ForEach(0..<2, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.appSecondary)
                                .frame(height: 112)
                        }
                    }
                    .padding(.top, 24)
                } else if groups.isEmpty {
                    VStack(spacing: 0) {
                        Image(systemName: "shippingbox")
                            .font(.system(size: 32))
                            .foregroundColor(.appMutedFg)
                        Text("还没有已发货的包裹。发布者发货并填写单号后会出现在这里。")
                            .font(.system(size: 14))
                            .foregroundColor(.appMutedFg)
                            .multilineTextAlignment(.center)
                            .padding(.top, 12)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 64)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 0.5, dash: [4, 3])))
                    .padding(.top, 24)
                } else {
                    Text("共 \(groups.count) 个橱窗 · \(total) 件包裹")
                        .font(.system(size: 12))
                        .foregroundColor(.appMutedFg)
                        .padding(.top, 20)
                    ForEach(groups) { g in
                        shipGroupCard(g).padding(.top, 12)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground)
        .navigationTitle("我的快递")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { now = $0 }
        .navigationDestination(isPresented: Binding(get: { queuePushId != nil }, set: { if !$0 { queuePushId = nil } })) {
            ShowcaseDetailView(showcaseId: queuePushId ?? 0)
        }
    }

    // MARK: 发货处理进度（2026-10-10 网页 ShipQueueSection：折叠区块，点开才查接口）
    private var shipQueueSection: some View {
        VStack(spacing: 0) {
            Button {
                queueOpen.toggle()
                if queueOpen && queue == nil { Task { await loadQueue() } }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "list.number")
                        .font(.system(size: 14)).foregroundColor(.appPrimary)
                    Text("发货处理进度")
                        .font(.system(size: 14, weight: .semibold)).foregroundColor(.appForeground)
                    Text("已发送地址的橱窗在发布者后台的排队位置")
                        .font(.system(size: 12)).foregroundColor(.appMutedFg)
                        .lineLimit(1)
                        .layoutPriority(-1)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12)).foregroundColor(.appMutedFg)
                        .rotationEffect(.degrees(queueOpen ? 180 : 0))
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            if queueOpen {
                Rectangle().fill(Color.appBorder.opacity(0.6)).frame(height: 0.5)
                queueContent
            }
        }
        .background(Color.appCard)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appBorder, lineWidth: 0.5))
    }

    @ViewBuilder
    private var queueContent: some View {
        let items = queue?.items ?? []
        if queueLoading && queue == nil {
            HStack(spacing: 6) {
                ProgressView().scaleEffect(0.7)
                Text("正在查询排队位置…")
                    .font(.system(size: 12)).foregroundColor(.appMutedFg)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 32)
        } else if items.isEmpty {
            Text("你还没有发送过收货地址。")
                .font(.system(size: 14)).foregroundColor(.appMutedFg)
                .frame(maxWidth: .infinity).padding(.vertical, 32)
        } else {
            let queued = items.filter { $0.position != nil }
            VStack(spacing: 0) {
                if !queued.isEmpty {
                    Text("\(queued.count) 个橱窗在排队中，按发送时间从先到后处理")
                        .font(.system(size: 11)).foregroundColor(.appMutedFg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                    Rectangle().fill(Color.appBorder.opacity(0.5)).frame(height: 0.5)
                }
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, i in
                    queueRow(i)
                    if idx < items.count - 1 {
                        Rectangle().fill(Color.appBorder.opacity(0.5)).frame(height: 0.5)
                    }
                }
            }
        }
    }

    private func queueRow(_ i: ShipQueueResponse.ShipQueueItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                if i.removed == true {
                    Text(i.title ?? "")
                        .font(.system(size: 14, weight: .medium)).foregroundColor(.appMutedFg)
                        .lineLimit(1)
                } else {
                    Button { queuePushId = i.showcaseId } label: {
                        Text(i.title ?? "")
                            .font(.system(size: 14, weight: .medium)).foregroundColor(.appForeground)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 8)
                queueBadge(i)
            }
            Text(queueSubtitle(i) + sentDay(i.sentAt))
                .font(.system(size: 11)).foregroundColor(.appMutedFg)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    @ViewBuilder
    private func queueBadge(_ i: ShipQueueResponse.ShipQueueItem) -> some View {
        if let pos = i.position {
            // 排队中：琥珀实色「第 X 位 / 共 Y 位未发货」
            Text("第 \(pos) 位 / 共 \(i.totalPending ?? 0) 位未发货")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color.twAmber500).clipShape(Capsule())
        } else {
            let s = queueStateStyle(i.shipState ?? "")
            Text(s.0)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(s.1)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(s.2).clipShape(Capsule())
                .overlay(Capsule().stroke(s.1.opacity(0.4), lineWidth: 0.5))
        }
    }

    private func queueStateStyle(_ s: String) -> (String, Color, Color) {
        switch s {
        case "preorder":  return ("预下单", .twSky700, .twSky100)
        case "ordered":   return ("已下单", .twEmerald700, .twEmerald100)
        case "external":  return ("外部寄件", .twViolet700, .twViolet100)
        case "cancelled": return ("已取消", .appPrimary, .appPrimary.opacity(0.1))
        default:          return ("未下单", .twAmber700, .twAmber100)
        }
    }

    private func queueSubtitle(_ i: ShipQueueResponse.ShipQueueItem) -> String {
        if let pos = i.position {
            return "发布者后台共 \(i.totalPending ?? 0) 个地址未发货，你的地址排在第 \(pos) 位"
        }
        switch i.shipState ?? "" {
        case "ordered", "external": return "已发货处理，请到上方包裹列表查看单号"
        case "preorder": return "已预下单，等待自动下单"
        case "cancelled": return "该次寄件已取消"
        default: return ""
        }
    }

    private func sentDay(_ s: String?) -> String {
        guard let s, let t = DateFmt.parse(s) else { return "" }
        let c = Calendar.current.dateComponents([.month, .day], from: t)
        return " · 地址发送于 \(c.month ?? 0)月\(c.day ?? 0)日"
    }

    private func loadQueue() async {
        queueLoading = true
        defer { queueLoading = false }
        queue = try? await MashanglingAPI.shared.address.myShipQueue()
    }

    // MARK: 需补邮折叠卡
    private var feeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation { feeOpen.toggle() } } label: {
                HStack(spacing: 8) {
                    Image(systemName: "wallet.pass")
                        .font(.system(size: 14))
                        .foregroundColor(.fixAmber600)
                    Text("需补邮")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.appForeground)
                    Text("补邮通过后显示已补邮；超时或取消的保留显示")
                        .font(.system(size: 12))
                        .foregroundColor(.appMutedFg)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if activeFeeCount > 0 {
                        Text("\(activeFeeCount)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 2)
                            .background(Color.fixAmber500)
                            .clipShape(Capsule())
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13))
                        .foregroundColor(.appMutedFg)
                        .rotationEffect(.degrees(feeOpen ? 180 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if feeOpen {
                Rectangle().fill(Color.fixAmber300).frame(height: 0.5)
                VStack(spacing: 0) {
                    ForEach(pendingFees) { f in
                        feeRow(f)
                        if f.approvalId != pendingFees.last?.approvalId {
                            Rectangle().fill(Color.fixAmber300.opacity(0.7)).frame(height: 0.5)
                        }
                    }
                }
            }
        }
        .background(Color.fixAmber100.opacity(0.6))
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.fixAmber300, lineWidth: 0.5))
        .cornerRadius(5)
    }

    @ViewBuilder
    private func feeRow(_ f: MyShipmentsResponse.PendingFee) -> some View {
        if f.status == "cancelled" {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(f.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appMutedFg)
                        .strikethrough(true, color: .appMutedFg.opacity(0.4))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text("已取消下单\(f.fee != nil ? " ¥\(f.fee!)" : "")")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.appMutedFg)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.appSecondary)
                        .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                        .clipShape(Capsule())
                }
                Text("超过 24 小时未补邮或由寄件人手动取消，本次下单已取消（预下单未真实下单，不会打扰快递员）")
                    .font(.system(size: 11))
                    .foregroundColor(.appMutedFg)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .opacity(0.7)
        } else if f.status == "approved" {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    titleLink(f)
                    if let t = f.autoShipAt {
                        countdownBadge(deadlineMs: t)
                    }
                    Text("已补邮·等待自动下单\(f.fee != nil ? " ¥\(f.fee!)" : "")")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.fixEmerald700)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.fixEmerald100)
                        .overlay(Capsule().stroke(Color.fixEmerald300, lineWidth: 0.5))
                        .clipShape(Capsule())
                }
                Text("补邮已通过，" + (f.autoShipAt != nil
                     ? "将于 \(monthDay(of: f.autoShipAt!)) 早上 9:00 自动下单，单号生成后会通知你"
                     : "即将自动下单，单号生成后会通知你"))
                    .font(.system(size: 11))
                    .foregroundColor(.appMutedFg)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    titleLink(f)
                    if let t = f.deadlineAt {
                        countdownBadge(deadlineMs: t)
                    }
                    Text("\(f.status == "modify" ? "需重新上传" : "待补邮")\(f.fee != nil ? " ¥\(f.fee!)" : "")")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.fixAmber700)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.fixAmber100)
                        .overlay(Capsule().stroke(Color.fixAmber300, lineWidth: 0.5))
                        .clipShape(Capsule())
                }
                if f.deadlineAt != nil {
                    Text("24 小时内未补邮或未通过审批，预下单自动取消")
                        .font(.system(size: 11))
                        .foregroundColor(.appMutedFg)
                        .padding(.top, 4)
                }
                if f.status == "modify", let r = f.reason, !r.isEmpty {
                    Text("发布者要求修改：\(r)")
                        .font(.system(size: 11))
                        .foregroundColor(.appBrand600)
                        .padding(.top, 6)
                }
                FlowLayout(spacing: 8, vSpacing: 6) {
                    if let acc = f.alipayAccount, !acc.isEmpty {
                        Text("支付宝：\(acc)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.appMutedFg)
                        Button {
                            UIPasteboard.general.string = acc
                            ToastCenter.shared.success("补邮账号已复制")
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 10))
                                .foregroundColor(.appMutedFg)
                                .padding(4)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("发布者未填补邮账号，请私信联系")
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                    }
                    Spacer(minLength: 0)
                    NavigationLink(destination: ApprovalDetailView(approvalId: f.approvalId)) {
                        Text("去补邮")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.appPrimaryFg)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.appPrimary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    @ViewBuilder
    private func titleLink(_ f: MyShipmentsResponse.PendingFee) -> some View {
        if f.removed == true {
            Text(f.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.appMutedFg)
                .lineLimit(1)
        } else {
            NavigationLink(destination: ShowcaseDetailView(showcaseId: f.showcaseId)) {
                Text(f.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.appForeground)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
        }
    }

    /// 倒计时徽标（网页 CountdownBadge：<=0 或 <1h 用 brand 色）
    private func countdownBadge(deadlineMs: Int) -> some View {
        let ms = Int(deadlineMs) - Int(now.timeIntervalSince1970 * 1000)
        let urgent = ms > 0 && ms < 3_600_000
        let danger = ms <= 0 || urgent
        return HStack(spacing: 2) {
            Image(systemName: "timer")
                .font(.system(size: 10))
            Text(remainText(ms))
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(danger ? Color.appBrand600 : Color.appMutedFg)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(danger ? Color.appBrand100 : Color.appSecondary)
        .overlay(Capsule().stroke(danger ? Color.appBrand200 : Color.appBorder, lineWidth: 0.5))
        .clipShape(Capsule())
    }

    private func remainText(_ ms: Int) -> String {
        if ms <= 0 { return "已超时，即将自动取消" }
        let m = Int(ceil(Double(ms) / 60000.0))
        if m < 60 { return "剩 \(m) 分钟" }
        let h = m / 60
        let mm = m % 60
        return mm > 0 ? "剩 \(h) 小时 \(mm) 分" : "剩 \(h) 小时"
    }

    // MARK: 运单分组卡
    private func shipGroupCard(_ g: MyShipmentsResponse.MyShipGroup) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            FlowLayout(spacing: 12, vSpacing: 4) {
                if g.removed == true {
                    Text(g.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.appMutedFg)
                        .lineLimit(1)
                } else {
                    NavigationLink(destination: ShowcaseDetailView(showcaseId: g.showcaseId)) {
                        Text(g.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.appForeground)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                }
                if g.removed == true {
                    Text("已删除")
                        .font(.system(size: 11))
                        .foregroundColor(.appMutedFg)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.appSecondary)
                        .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                        .clipShape(Capsule())
                }
                Spacer(minLength: 0)
                Text("\((g.items ?? []).count) 件")
                    .font(.system(size: 12))
                    .foregroundColor(.appMutedFg)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            Rectangle().fill(Color.appBorder.opacity(0.6)).frame(height: 0.5)
            VStack(spacing: 0) {
                ForEach(g.items ?? []) { a in
                    shipmentRow(a)
                    if a.id != g.items?.last?.id {
                        Rectangle().fill(Color.appBorder.opacity(0.5)).frame(height: 0.5)
                    }
                }
            }
        }
        .background(Color.appCard)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appBorder, lineWidth: 0.5))
        .cornerRadius(5)
    }

    private func shipmentRow(_ a: MyShipmentsResponse.MyShipment) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(a.trackingNo)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(.appForeground)
                    .lineLimit(1)
                Button {
                    UIPasteboard.general.string = a.trackingNo
                    ToastCenter.shared.success("单号已复制，去菜鸟粘贴即可查物流")
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundColor(.appMutedFg)
                        .padding(4)
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
                Button { UIApplication.shared.open(cainiaoHomeURL) } label: {
                    Text("查物流")
                        .font(.system(size: 11))
                        .foregroundColor(.appMutedFg)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
            FlowLayout(spacing: 8, vSpacing: 6) {
                stateBadge(shipState: a.shipState ?? "", isYunda: a.isYunda == true)
                if a.approvalStatus == "approved" {
                    HStack(spacing: 2) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 10))
                        Text("补邮已通过\(a.approvalFee != nil ? " ¥\(a.approvalFee!)" : "")")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.fixEmerald700)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.fixEmerald100)
                    .clipShape(Capsule())
                }
                if a.approvalStatus == "auto_approved" {
                    Text("包邮")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.fixEmerald700)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.fixEmerald100)
                        .overlay(Capsule().stroke(Color.fixEmerald200, lineWidth: 0.5))
                        .clipShape(Capsule())
                }
                if a.shipState == "external" {
                    Text("外部寄件，不一定是韵达")
                        .font(.system(size: 11))
                        .foregroundColor(.appMutedFg)
                }
                Spacer(minLength: 0)
                Text(DateFmt.short(a.createdAt))
                    .font(.system(size: 11))
                    .foregroundColor(.appMutedFg)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    /// 网页 StateBadge 四态
    @ViewBuilder
    private func stateBadge(shipState: String, isYunda: Bool) -> some View {
        if shipState == "cancelled" {
            shipBadgeView("已取消", bg: .appBrand100, fg: .appBrand600, ring: .appBrand200)
        } else if shipState == "external" {
            shipBadgeView("外部寄件", bg: .fixViolet100, fg: .fixViolet700, ring: .fixViolet300)
        } else if isYunda {
            shipBadgeView("韵达快递", bg: .fixSky50, fg: .fixSky700, ring: .fixSky50)
        } else {
            shipBadgeView("已发货", bg: .appSecondary, fg: .appMutedFg)
        }
    }

    private func monthDay(of ms: Int) -> String {
        let d = Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M 月 d 日"
        return f.string(from: d)
    }

    private func load() async {
        loading = true
        data = try? await MashanglingAPI.shared.address.myShipments()
        loading = false
    }
}
