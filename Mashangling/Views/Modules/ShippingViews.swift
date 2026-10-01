import SwiftUI
import UIKit

// MARK: - 快递后台（对应网页 Shipping.tsx，发布者寄件管理）
struct ShippingView: View {
    /// 0=寄件看板 1=邮费审批（消息页「去上传凭证 / 审批」直达用）
    var initialTab: Int = 0

    @State private var board: ShippingBoard? = nil
    @State private var approvals: ApprovalsResponse? = nil
    @State private var tab: Int

    init(initialTab: Int = 0) {
        self.initialTab = initialTab
        _tab = State(initialValue: initialTab)
    }
    @State private var loading = true
    @State private var busy = false
    @State private var shipTarget: ShipItem? = nil
    @State private var trackingNo = ""
    @State private var exportItem: ExportFileItem? = nil
    @State private var approvalDetailId: Int? = nil

    struct ExportFileItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tabBtn(0, "寄件看板")
                tabBtn(1, "邮费审批\(approvals?.pendingCount.map { $0 > 0 ? "（\($0)）" : "" } ?? "")")
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
                boardList
            } else {
                approvalList
            }
        }
        .background(Color.appBackground)
        .navigationTitle("快递后台")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button { Task { await exportExcel(kind: "excel") } } label: {
                        Label("导出寄件需求 Excel", systemImage: "square.and.arrow.down")
                    }
                    Button { Task { await exportExcel(kind: "cainiao") } } label: {
                        Label("导出菜鸟批量寄件模板", systemImage: "square.and.arrow.down.on.square")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.appForeground)
                }
            }
        }
        .task { await load() }
        .sheet(item: $shipTarget) { item in
            shipSheet(item)
        }
        .sheet(item: $exportItem) { item in
            ShareSheet(items: [item.url])
        }
        .sheet(isPresented: Binding(get: { approvalDetailId != nil },
                                    set: { if !$0 { approvalDetailId = nil } })) {
            if let aid = approvalDetailId {
                ApprovalDetailSheet(approvalId: aid) { Task { await load() } }
            }
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

    // MARK: 寄件看板
    private var boardList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let b = board {
                    // 汇总
                    SectionCard {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("预估邮费合计 \(b.grandTotal ?? 0) 积分")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.appForeground)
                                Spacer()
                                if let unpaid = b.grandUnpaid, unpaid > 0 {
                                    Text("待付清 \(unpaid)")
                                        .font(.system(size: 11))
                                        .foregroundColor(.appAmberFg)
                                }
                            }
                            if let rule = b.rule, !rule.isEmpty {
                                Text(rule)
                                    .font(.system(size: 10))
                                    .foregroundColor(.appMutedFg)
                            }
                            if let sender = b.senderAddress, !sender.isEmpty {
                                Text("寄件地址：\(sender)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.appMutedFg)
                            } else {
                                Text("还没填寄件地址，去「设置 → 收货地址」里补上")
                                    .font(.system(size: 10))
                                    .foregroundColor(.appAmberFg)
                            }
                            HStack(spacing: 8) {
                                expressBadge("韵达", bound: b.yundaBound == true)
                                expressBadge("中通", bound: b.ztoBound == true)
                                expressBadge("菜鸟", bound: b.cainiaoBound == true)
                            }
                        }
                    }

                    if b.groups.isEmpty {
                        EmptyStateView(icon: "shippingbox", title: "暂无寄件需求", subtitle: "领取人发送地址后会出现在这里")
                    }

                    ForEach(b.groups) { g in
                        groupCard(g)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .refreshable { await load() }
    }

    private func expressBadge(_ name: String, bound: Bool) -> some View {
        Text("\(name)\(bound ? "已绑定" : "未绑定")")
            .font(.system(size: 10))
            .foregroundColor(bound ? .appEmeraldFg : .appMutedFg)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(bound ? Color.appEmeraldBg : Color.appSecondary)
            .clipShape(Capsule())
    }

    private func groupCard(_ g: ShipGroup) -> some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    NavigationLink(destination: ShowcaseDetailView(showcaseId: g.showcaseId)) {
                        Text(g.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(g.removed == true ? .appMutedFg : .appPrimary)
                            .lineLimit(1)
                    }
                    if g.removed == true { MiniBadge(text: "已下架") }
                    Spacer()
                    if let sub = g.subtotal {
                        Text("小计 \(sub)")
                            .font(.system(size: 11))
                            .foregroundColor(.appMutedFg)
                    }
                }

                ForEach(g.items) { item in
                    shipRow(item)
                    if item.id != g.items.last?.id { Divider() }
                }

                if let hidden = g.hiddenCount, hidden > 0 {
                    Button { Task { await unhideAll(g) } } label: {
                        Text("已隐藏 \(hidden) 条 · 点按全部恢复")
                            .font(.system(size: 11))
                            .foregroundColor(.appMutedFg)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func shipRow(_ item: ShipItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(item.nickname)  \(item.phone)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.appForeground)
                Spacer()
                MiniBadge(text: item.stateText,
                          fg: item.stateText == "未下单" ? .appAmberFg : .appEmeraldFg,
                          bg: item.stateText == "未下单" ? .appAmberBg : .appEmeraldBg)
                if item.shippingPaid != true {
                    MiniBadge(text: "邮费未付清", fg: .appRedFg, bg: .appSecondary)
                }
            }
            .contextMenu {
                NavigationLink(destination: UserShipmentsView(userId: item.userId)) {
                    Label("该用户寄件", systemImage: "cube.box")
                }
                Button(role: .destructive) { Task { await deleteShare(item) } } label: {
                    Label("删除记录", systemImage: "trash")
                }
            }
            Text(item.full ?? item.address)
                .font(.system(size: 11))
                .foregroundColor(.appMutedFg)
                .lineLimit(2)
            HStack(spacing: 8) {
                if let fee = item.fee {
                    Text("邮费 \(item.feeLabel ?? "\(fee) 积分")")
                        .font(.system(size: 10))
                        .foregroundColor(.appMutedFg)
                }
                if let no = item.trackingNo, !no.isEmpty {
                    Text("单号 \(no)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.appMutedFg)
                        .lineLimit(1)
                }
                Spacer()
            }
            HStack(spacing: 8) {
                miniAction("填单号") { shipTarget = item; trackingNo = "" }
                if item.shipState == "preorder" || item.shipState == "ordered" {
                    miniAction("取消订单") { Task { await cancelShip(item) } }
                }
                if item.shippingPaid != true {
                    miniAction("邮费已付清") { Task { await markPaid(item) } }
                }
                miniAction("隐藏") { Task { await hide(item, hidden: true) } }
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }

    private func miniAction(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.appPrimary)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .overlay(Capsule().stroke(Color.appPrimary.opacity(0.6), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(busy)
    }

    private func shipSheet(_ item: ShipItem) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("收件人：\(item.nickname) \(item.phone)")
                    .font(.system(size: 13))
                    .foregroundColor(.appForeground)
                AppTextField(text: $trackingNo, placeholder: "快递单号")
                Button { Task { await ship(item) } } label: {
                    Text(busy ? "提交中…" : "确认寄出")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appPrimaryFg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.appPrimary)
                        .clipShape(Capsule())
                }
                .disabled(trackingNo.trimmingCharacters(in: .whitespaces).isEmpty || busy)
                Spacer()
            }
            .padding(20)
            .background(Color.appBackground)
            .navigationTitle("填写快递单号")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(260)])
    }

    // MARK: 邮费审批
    private var approvalList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if (approvals?.groups ?? []).isEmpty {
                    EmptyStateView(icon: "checkmark.shield", title: "暂无邮费审批")
                }
                ForEach(approvals?.groups ?? []) { g in
                    SectionCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(g.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.appForeground)
                            ForEach(g.items ?? []) { a in
                                approvalRow(a)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .refreshable { await load() }
    }

    private func approvalRow(_ a: ApprovalsResponse.ApprovalItem) -> some View {
        HStack(spacing: 8) {
            Button { approvalDetailId = a.id } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(a.claimerName ?? "") · \(a.kind == "proof" ? "补邮凭证" : "免邮申请")")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.appForeground)
                    HStack(spacing: 6) {
                        Text("邮费 \(a.fee ?? 0) 积分 · \(DateFmt.short(a.createdAt))")
                            .font(.system(size: 10))
                            .foregroundColor(.appMutedFg)
                        if a.hasProof == true {
                            Text("有凭证图")
                                .font(.system(size: 9))
                                .foregroundColor(.appPrimary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            Spacer()
            switch a.status {
            case "submitted", "pending":
                HStack(spacing: 6) {
                    Button { Task { await review(a, action: "approve") } } label: {
                        Text("通过").font(.system(size: 11, weight: .medium))
                            .foregroundColor(.appPrimaryFg)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(Color.appPrimary).clipShape(Capsule())
                    }
                    .disabled(busy)
                    Button { Task { await review(a, action: "reject") } } label: {
                        Text("驳回").font(.system(size: 11))
                            .foregroundColor(.appForeground)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .overlay(Capsule().stroke(Color.appBorder, lineWidth: 1))
                    }
                    .disabled(busy)
                }
            default:
                MiniBadge(text: approvalStatusText(a.status), fg: .appMutedFg, bg: .appSecondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func approvalStatusText(_ s: String?) -> String {
        switch s {
        case "approved", "auto_approved": return "已通过"
        case "rejected": return "已驳回"
        case "modify": return "待修改"
        case "cancelled": return "已取消"
        default: return "待处理"
        }
    }

    // MARK: 数据与操作
    private func load() async {
        loading = true
        board = try? await MashanglingAPI.shared.address.shippingBoard()
        approvals = try? await MashanglingAPI.shared.address.approvals()
        loading = false
    }

    private func ship(_ item: ShipItem) async {
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.address.ship(
                shareId: item.id, trackingNo: trackingNo.trimmingCharacters(in: .whitespaces))
            ToastCenter.shared.success("已标记寄出，收件人会收到通知")
            shipTarget = nil
            await load()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func cancelShip(_ item: ShipItem) async {
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.address.cancelShip(shareId: item.id)
            ToastCenter.shared.success("订单已取消")
            await load()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func markPaid(_ item: ShipItem) async {
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.address.markShippingPaid(shareId: item.id)
            ToastCenter.shared.success("已标记邮费付清")
            await load()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func hide(_ item: ShipItem, hidden: Bool) async {
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.address.setShareHidden(shareId: item.id, hidden: hidden)
            await load()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func deleteShare(_ item: ShipItem) async {
        busy = true
        defer { busy = false }
        do {
            let r = try await MashanglingAPI.shared.address.deleteShare(shareId: item.id)
            ToastCenter.shared.success(r.showcaseDeleted == true ? "记录已删除，橱窗一并下架" : "记录已删除")
            await load()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func unhideAll(_ g: ShipGroup) async {
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.address.unhideShowcaseShares(showcaseId: g.showcaseId)
            ToastCenter.shared.success("已恢复全部记录")
            await load()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func review(_ a: ApprovalsResponse.ApprovalItem, action: String) async {
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.address.reviewApproval(approvalId: a.id, action: action)
            ToastCenter.shared.success(action == "approve" ? "已通过" : "已驳回")
            await load()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func exportExcel(kind: String) async {
        ToastCenter.shared.show("正在生成表格…")
        do {
            let r: ExportResult
            if kind == "cainiao" {
                r = try await MashanglingAPI.shared.address.exportCainiao()
            } else {
                r = try await MashanglingAPI.shared.address.exportExcel()
            }
            guard let data = Data(base64Encoded: r.base64) else {
                ToastCenter.shared.error("表格数据解析失败"); return
            }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(r.filename)
            try data.write(to: url)
            exportItem = ExportFileItem(url: url)
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}

// MARK: - 我的快递（对应网页 MyShipments.tsx，领取人视角）
struct MyShipmentsView: View {
    @State private var data: MyShipmentsResponse? = nil
    @State private var loading = true
    @State private var busy = false
    @State private var proofTarget: MyShipmentsResponse.PendingFee? = nil
    @State private var proofImage: UIImage? = nil
    @State private var showPicker = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if loading {
                    LoadingView()
                } else {
                    // 待补邮费
                    if let fees = data?.pendingFees, !fees.isEmpty {
                        SectionCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("待补邮费（\(fees.count)）")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.appForeground)
                                ForEach(fees) { f in
                                    HStack(spacing: 8) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(f.title)
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(.appForeground)
                                                .lineLimit(1)
                                            Text("需补 \(f.fee ?? 0) 积分邮费 · 支付宝：\(f.alipayAccount ?? "见橱窗说明")")
                                                .font(.system(size: 10))
                                                .foregroundColor(.appMutedFg)
                                        }
                                        Spacer()
                                        if f.status == "submitted" {
                                            MiniBadge(text: "凭证已提交", fg: .appAmberFg, bg: .appAmberBg)
                                        } else {
                                            Button {
                                                proofTarget = f
                                                proofImage = nil
                                            } label: {
                                                Text("上传凭证")
                                                    .font(.system(size: 11, weight: .medium))
                                                    .foregroundColor(.appPrimaryFg)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 5)
                                                    .background(Color.appPrimary)
                                                    .clipShape(Capsule())
                                            }
                                            .disabled(busy)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 运单分组
                    if (data?.groups ?? []).isEmpty {
                        EmptyStateView(icon: "cube.box", title: "暂无快递", subtitle: "你领取的外部无料发货后会显示在这里")
                    }
                    ForEach(data?.groups ?? []) { g in
                        SectionCard {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(g.title)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(g.removed == true ? .appMutedFg : .appForeground)
                                        .lineLimit(1)
                                    if g.removed == true { MiniBadge(text: "已下架") }
                                    Spacer()
                                }
                                ForEach(g.items ?? []) { s in
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("单号 \(s.trackingNo)")
                                                .font(.system(size: 12, design: .monospaced))
                                                .foregroundColor(.appForeground)
                                            Spacer()
                                            Button {
                                                UIPasteboard.general.string = s.trackingNo
                                                ToastCenter.shared.success("单号已复制")
                                            } label: {
                                                Image(systemName: "doc.on.doc")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(.appPrimary)
                                            }
                                        }
                                        HStack(spacing: 8) {
                                            Text(s.isYunda == true ? "韵达快递" : "快递")
                                                .font(.system(size: 10))
                                                .foregroundColor(.appMutedFg)
                                            if s.shippingPaid == true {
                                                MiniBadge(text: "邮费已付清", fg: .appEmeraldFg, bg: .appEmeraldBg)
                                            }
                                            if let st = s.approvalStatus, st == "submitted" {
                                                MiniBadge(text: "补邮审核中", fg: .appAmberFg, bg: .appAmberBg)
                                            }
                                            Spacer()
                                            Text(DateFmt.short(s.createdAt))
                                                .font(.system(size: 10))
                                                .foregroundColor(.appMutedFg)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    if s.id != g.items?.last?.id { Divider() }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.appBackground)
        .navigationTitle("我的快递")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            data = try? await MashanglingAPI.shared.address.myShipments()
            loading = false
        }
        .refreshable {
            data = try? await MashanglingAPI.shared.address.myShipments()
        }
        .sheet(item: $proofTarget) { f in
            proofSheet(f)
        }
        .sheet(isPresented: $showPicker) { ImagePicker(image: $proofImage) }
    }

    private func proofSheet(_ f: MyShipmentsResponse.PendingFee) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("「\(f.title)」需补邮费 \(f.fee ?? 0) 积分，请向发布人支付宝转账后上传付款截图。")
                    .font(.system(size: 12))
                    .foregroundColor(.appMutedFg)
                Button { showPicker = true } label: {
                    if let img = proofImage {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: 200)
                            .cornerRadius(10)
                    } else {
                        HStack {
                            Image(systemName: "photo.badge.plus")
                            Text("选择付款截图")
                        }
                        .font(.system(size: 13))
                        .foregroundColor(.appMutedFg)
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 1, dash: [6])))
                    }
                }
                .buttonStyle(.plain)
                Button { Task { await uploadProof(f) } } label: {
                    Text(busy ? "上传中…" : "提交凭证")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appPrimaryFg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.appPrimary)
                        .clipShape(Capsule())
                }
                .disabled(proofImage == nil || busy)
                Spacer()
            }
            .padding(20)
            .background(Color.appBackground)
            .navigationTitle("上传补邮凭证")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }

    private func uploadProof(_ f: MyShipmentsResponse.PendingFee) async {
        guard let img = proofImage, let dataURL = ImageCodec.coverDataURL(from: img) else {
            ToastCenter.shared.error("图片处理失败"); return
        }
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.address.uploadProof(approvalId: f.approvalId, image: dataURL)
            ToastCenter.shared.success("凭证已提交，等待发布人审核")
            proofTarget = nil
            data = try? await MashanglingAPI.shared.address.myShipments()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}
