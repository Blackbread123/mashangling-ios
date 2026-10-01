import SwiftUI
import UIKit

// MARK: - 发布 / 编辑橱窗（对应网页 Publish.tsx）
struct PublishView: View {
    /// 传入则为编辑模式
    var editing: ShowcaseDetailData? = nil

    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var platform = "rouzao"
    @State private var rouzaoCode = ""
    @State private var codeVisibility = "open"
    @State private var descriptionText = ""
    @State private var cover: UIImage? = nil
    @State private var existingCover: String? = nil
    @State private var showPicker = false
    @State private var selectedTags: [Tag] = []
    @State private var tagQuery = ""
    @State private var tagResults: [Tag] = []
    @State private var stockStatus = "none"
    @State private var claimMode = "request"
    @State private var quantityText = ""
    @State private var pointCostText = ""
    @State private var hasAddrDeadline = false
    @State private var addrDeadlineDate = Date().addingTimeInterval(86400)
    @State private var hasExpires = false
    @State private var expiresDate = Date().addingTimeInterval(7 * 86400)
    @State private var shippingFree = false
    @State private var pinned = false
    @State private var busy = false
    @State private var publishedId: Int? = nil

    private var isEdit: Bool { editing != nil }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                // 封面图 *
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("封面图", required: true)
                    Button { showPicker = true } label: {
                        if let img = cover {
                            Image(uiImage: img)
                                .resizable()
                                .aspectRatio(1, contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .cornerRadius(12)
                        } else if let path = existingCover {
                            AppImage(path: path)
                                .aspectRatio(1, contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .cornerRadius(12)
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "photo.badge.plus").font(.system(size: 30))
                                Text("选择封面（正方形最佳）").font(.system(size: 13))
                            }
                            .foregroundColor(.appMutedFg)
                            .frame(maxWidth: .infinity, minHeight: 180)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 1, dash: [6])))
                        }
                    }
                    .buttonStyle(.plain)
                }

                // 标题 *
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("标题", required: true)
                    AppTextField(text: $title, placeholder: "例如：XX 同人吧唧三件套")
                }

                // 无料来源 *
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("无料来源", required: true)
                    HStack(spacing: 6) {
                        ForEach([("rouzao", "柔造"), ("yingtang", "映糖"), ("external", "外部无料")], id: \.0) { p in
                            fullPillButton(p.1, selected: platform == p.0) { platform = p.0 }
                        }
                    }
                    if platform == "external" {
                        noteText("外部无料没有平台码，把「无料码」留空即可，其余设置（可见性、数量）与柔造/映糖一致。")
                        // 邮费（包邮 / 不包邮）
                        amberBox {
                            fieldLabel("邮费（包邮 / 不包邮）", required: false)
                            HStack(spacing: 6) {
                                optionCard(icon: "checkmark.seal", title: "包邮",
                                           desc: "你承担邮费，领取人发送地址后无需任何操作",
                                           selected: shippingFree) { shippingFree = true }
                                optionCard(icon: "yensign.circle", title: "不包邮",
                                           desc: "下单后系统通知领取人补邮并上传转账截图，你审批通过后发货",
                                           selected: !shippingFree) { shippingFree = false }
                            }
                            noteText("选择会高亮显示在领取人的「发送地址」按钮旁。不包邮请先在「设置」里填好补邮支付宝账号，下单时会自动发给领取人。")
                        }
                        // 填写地址时限（可选）
                        amberBox {
                            fieldLabel("填写地址时限（可选）", required: false)
                            if hasAddrDeadline {
                                HStack(spacing: 8) {
                                    DatePicker("", selection: $addrDeadlineDate, in: Date()...,
                                               displayedComponents: [.date, .hourAndMinute])
                                        .labelsHidden()
                                    Button("清除（随时开放）") { hasAddrDeadline = false }
                                        .font(.system(size: 12))
                                        .foregroundColor(.appMutedFg)
                                }
                            } else {
                                Button {
                                    addrDeadlineDate = Date().addingTimeInterval(86400)
                                    hasAddrDeadline = true
                                } label: {
                                    Text("选择截止时间（留空 = 随时开放）")
                                        .font(.system(size: 13))
                                        .foregroundColor(.appMutedFg)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 9)
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 1, dash: [6])))
                                }
                                .buttonStyle(.plain)
                            }
                            noteText("留空 = 随时开放。设置后，领取人只能在截止时间前一键发送地址，超时后按钮会显示「已超时」并展示该时间；分钟按 10 分钟一档选择。之后修改时限会给特别关注你的人发邮件通知。")
                        }
                    }
                }

                // 无料码
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("无料码" + (platform == "external" ? "（外部无料可留空）" : platform == "rouzao" ? "（柔造码）" : "（映糖码）"), required: false)
                    AppTextField(text: $rouzaoCode,
                                 placeholder: platform == "external" ? "没有平台码可留空" : platform == "rouzao" ? "粘贴柔造小程序里的分享码" : "粘贴映糖的分享码",
                                 monospace: true)
                    if platform != "external" {
                        noteText("留空则会按「外部无料」发布。")
                    }
                }

                // 分享码可见性（所有平台一致）
                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("分享码可见性", required: false)
                    optionCard(icon: "eye", title: "直接可见",
                               desc: "任何人打开橱窗即可看到并复制分享码",
                               selected: codeVisibility == "open") { codeVisibility = "open" }
                    optionCard(icon: "lock", title: "申请领取",
                               desc: "访客点击「申请领取」，你在个人页批准后码才解锁",
                               selected: codeVisibility == "request") { codeVisibility = "request" }
                    optionCard(icon: "checkmark.seal", title: "凭证解锁",
                               desc: "申请者需上传凭证（照片或文字，至少一项）供你审核",
                               selected: codeVisibility == "credential") { codeVisibility = "credential" }
                    if codeVisibility != "open" {
                        noteText("审核入口在个人页「领取申请」，批准后申请者会收到站内信通知。码留空时此设置不生效。")
                    }
                }

                // 数量（留空 = 不限）
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("数量（留空 = 不限）", required: false)
                    AppTextField(text: $quantityText, placeholder: "不限", keyboard: .numberPad)
                        .frame(width: 128)
                    if !quantityText.trimmingCharacters(in: .whitespaces).isEmpty {
                        noteText("设置了数量，将锁定为「申请领取」，按审批通过数判定领完，领完后无法再申请。")
                    }
                }

                // 库存状态
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("库存状态", required: false)
                    HStack(spacing: 6) {
                        ForEach([("none", "不标记"), ("soldout", "领完即止"), ("restock", "可补码"), ("limited", "限量")], id: \.0) { s in
                            fullPillButton(s.1, selected: stockStatus == s.0) { stockStatus = s.0 }
                        }
                    }
                    if stockStatus == "limited" {
                        amberBox {
                            HStack(spacing: 8) {
                                AppTextField(text: $quantityText, placeholder: "数量", keyboard: .numberPad)
                                    .frame(width: 112)
                                Text("份 · 达到数量即「已领完」")
                                    .font(.system(size: 12))
                                    .foregroundColor(.appMutedFg)
                                Spacer(minLength: 0)
                            }
                            VStack(spacing: 6) {
                                optionCard(icon: "lock", title: "需审批",
                                           desc: "领取者需上传图片凭证（或文字说明），你批准后码才解锁",
                                           selected: claimMode == "request") { claimMode = "request" }
                                optionCard(icon: "bolt", title: "无需审批",
                                           desc: "码仍遮挡，访客点「领取」立即解锁，领完即止",
                                           selected: claimMode == "instant") { claimMode = "instant" }
                                optionCard(icon: "centsign.circle", title: "积分解锁",
                                           desc: "访客支付你设定的积分立即解锁，积分转入你的账户，无需审批",
                                           selected: claimMode == "points") { claimMode = "points" }
                            }
                            if claimMode == "points" {
                                HStack(spacing: 8) {
                                    AppTextField(text: $pointCostText, placeholder: "所需积分", keyboard: .numberPad)
                                        .frame(width: 112)
                                    Text("积分 · 解锁后转入你的账户")
                                        .font(.system(size: 12))
                                        .foregroundColor(.appMutedFg)
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                    }
                    noteText("标记会显示在橱窗卡片封面上：「领完即止」= 领完不再补；「可补码」= 领完可联系补新码；「限量」= 设数量，领完即止；「不标记」则不显示。")
                }

                // 限时（仅柔造/映糖）
                if platform != "external" {
                    VStack(alignment: .leading, spacing: 6) {
                        fieldLabel("限时（可选）", required: false)
                        if hasExpires {
                            HStack(spacing: 8) {
                                DatePicker("", selection: $expiresDate, in: Date()...,
                                           displayedComponents: [.date, .hourAndMinute])
                                    .labelsHidden()
                                Button("清除（长期有效）") { hasExpires = false }
                                    .font(.system(size: 12))
                                    .foregroundColor(.appMutedFg)
                            }
                        } else {
                            Button {
                                expiresDate = Date().addingTimeInterval(7 * 86400)
                                hasExpires = true
                            } label: {
                                Text("选择失效时间（留空 = 长期有效）")
                                    .font(.system(size: 13))
                                    .foregroundColor(.appMutedFg)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 1, dash: [6])))
                            }
                            .buttonStyle(.plain)
                        }
                        noteText("留空 = 长期有效。设置后橱窗卡片和详情页会显示失效时间，到期后任何人（含礼物领取）都不能再领取，橱窗显示「已失效」。分钟按 10 分钟一档选择。")
                    }
                }

                // 简介
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("简介", required: false)
                    TextField("补充说明：制品规格、领取条件（是否需自付邮费）、数量限制等", text: $descriptionText, axis: .vertical)
                        .font(.system(size: 14))
                        .lineLimit(4...8)
                        .padding(10)
                        .background(Color.appInput)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // 标签 *
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("标签", required: true)
                    if !selectedTags.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(selectedTags) { t in
                                HStack(spacing: 4) {
                                    Text("# \(t.name)")
                                    Button { selectedTags.removeAll { $0.id == t.id } } label: {
                                        Image(systemName: "xmark").font(.system(size: 9))
                                    }
                                }
                                .font(.system(size: 11))
                                .foregroundColor(.appPrimaryFg)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.appPrimary)
                                .clipShape(Capsule())
                            }
                        }
                    }
                    AppTextField(text: $tagQuery, placeholder: "搜索标签，或输入新标签名")
                        .onChange(of: tagQuery) { _ in Task { await searchTags() } }
                        .onSubmit { Task { await searchTags() } }
                    if !tagResults.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(tagResults) { t in
                                Button {
                                    if !selectedTags.contains(where: { $0.id == t.id }) {
                                        selectedTags.append(t)
                                    }
                                    tagQuery = ""
                                    tagResults = []
                                } label: {
                                    Text("# \(t.name) · \(TagCategory.label(t.category))")
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
                    // 新建标签
                    if !tagQuery.trimmingCharacters(in: .whitespaces).isEmpty,
                       !tagResults.contains(where: { $0.name == tagQuery.trimmingCharacters(in: .whitespaces) }) {
                        HStack(spacing: 8) {
                            Text("新建标签：")
                                .font(.system(size: 11))
                                .foregroundColor(.appMutedFg)
                            ForEach(["work", "character", "merch", "other"], id: \.self) { c in
                                Button { Task { await createTag(category: c) } } label: {
                                    Text(TagCategory.label(c))
                                        .font(.system(size: 11))
                                        .foregroundColor(.appPrimary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .overlay(Capsule().stroke(Color.appPrimary, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // 置顶（仅编辑模式，对应网页 pinned 开关）
                if isEdit {
                    Button { pinned.toggle() } label: {
                        HStack(spacing: 8) {
                            Image(systemName: pinned ? "pin.fill" : "pin.slash")
                                .font(.system(size: 16))
                                .foregroundColor(pinned ? .appPrimary : .appMutedFg)
                            Text(pinned ? "已在个人页置顶" : "在个人页置顶")
                                .font(.system(size: 14))
                                .foregroundColor(.appMutedFg)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Button { Task { await submit() } } label: {
                    Text(busy ? "提交中…" : (isEdit ? "保存修改" : "发布橱窗"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.appPrimaryFg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.appPrimary)
                        .clipShape(Capsule())
                }
                .disabled(busy)
                .padding(.bottom, 30)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .background(Color.appBackground)
        .background(
            NavigationLink(destination: ShowcaseDetailView(showcaseId: publishedId ?? 0),
                           isActive: Binding(get: { publishedId != nil }, set: { if !$0 { publishedId = nil } })) { EmptyView() }
                .hidden()
        )
        .navigationTitle(isEdit ? "编辑橱窗" : "发布橱窗")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isEdit {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                        .font(.system(size: 13))
                        .foregroundColor(.appMutedFg)
                }
            }
        }
        .overlay(ToastOverlay())
        .sheet(isPresented: $showPicker) { ImagePicker(image: $cover) }
        .onAppear { prefill() }
    }

    // 全宽胶囊选项（对应网页 flex-1 rounded-full 按钮）
    private func fullPillButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: selected ? .medium : .regular))
                .foregroundColor(selected ? .appPrimaryFg : .appSecondaryFg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selected ? Color.appPrimary : Color.appSecondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // 大选项卡（对应网页带图标+说明的 rounded-xl 选项）
    private func optionCard(icon: String, title: String, desc: String, selected: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(selected ? .appPrimary : .appMutedFg)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appForeground)
                    Text(desc)
                        .font(.system(size: 11))
                        .lineSpacing(4)
                        .foregroundColor(.appMutedFg)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(selected ? Color.appPrimary.opacity(0.05) : Color.appCard)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? Color.appPrimary : Color.appBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // 琥珀色提示框（对应网页 border-amber-200 bg-amber-50/60 rounded-xl）
    private func amberBox<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) { content() }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.fixAmber100.opacity(0.6))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.fixAmber300, lineWidth: 1))
    }

    // 说明文字（网页 text-[11px] leading-4 text-muted-foreground）
    private func noteText(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 11))
            .lineSpacing(4)
            .foregroundColor(.appMutedFg)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fieldLabel(_ t: String, required: Bool) -> some View {
        HStack(spacing: 3) {
            Text(t).font(.system(size: 14, weight: .medium)).foregroundColor(.appForeground)
            if required { Text("*").foregroundColor(.appDestructive).font(.system(size: 13)) }
        }
    }

    private func prefill() {
        guard let d = editing else { return }
        title = d.title
        platform = d.platform ?? "rouzao"
        rouzaoCode = d.rouzaoCode ?? ""
        codeVisibility = d.codeVisibility ?? "open"
        stockStatus = d.stockStatus ?? "none"
        // 网页回填规则：有数量但未选「限量」则自动勾上
        if d.quantity != nil && stockStatus != "limited" { stockStatus = "limited" }
        quantityText = d.quantity.map { "\($0)" } ?? ""
        claimMode = d.claimMode ?? "request"
        pointCostText = (d.claimMode == "points" ? d.pointCost.map { "\($0)" } : nil) ?? ""
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoBasic = ISO8601DateFormatter()
        if let s = d.addressDeadline, let dt = iso.date(from: s) ?? isoBasic.date(from: s) {
            addrDeadlineDate = dt
            hasAddrDeadline = true
        }
        if let s = d.expiresAt, let dt = iso.date(from: s) ?? isoBasic.date(from: s) {
            expiresDate = dt
            hasExpires = true
        }
        descriptionText = d.description ?? ""
        existingCover = d.coverImage
        shippingFree = d.shippingFree ?? false
        selectedTags = d.tags ?? []
        pinned = d.pinned ?? false
    }

    private func searchTags() async {
        let q = tagQuery.trimmingCharacters(in: .whitespaces)
        tagResults = (try? await MashanglingAPI.shared.tag.search(q: q, limit: 12)) ?? []
    }

    private func createTag(category: String) async {
        let name = tagQuery.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        do {
            let t = try await MashanglingAPI.shared.tag.create(name: name, category: category)
            if !selectedTags.contains(where: { $0.id == t.id }) { selectedTags.append(t) }
            tagQuery = ""
            tagResults = []
            ToastCenter.shared.success("标签已创建（待管理员审核后全站可见）")
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    // 提交逻辑与网页 Publish.tsx submit() 一致
    private func submit() async {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        let codeT = rouzaoCode.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { ToastCenter.shared.error("请填写标题"); return }
        if platform != "external" && codeT.isEmpty {
            ToastCenter.shared.error("请填写无料码；没有码的话请选择「外部无料」"); return
        }
        guard cover != nil || existingCover != nil else { ToastCenter.shared.error("请上传封面图"); return }
        guard !selectedTags.isEmpty else { ToastCenter.shared.error("至少选择 1 个标签"); return }
        // 选了「限量」必须填数量；没选则数量清空
        let limited = stockStatus == "limited"
        if limited && quantityText.trimmingCharacters(in: .whitespaces).isEmpty {
            ToastCenter.shared.error("选了「限量」请填写数量"); return
        }
        if limited && claimMode == "points" && (Int(pointCostText) ?? 0) < 1 {
            ToastCenter.shared.error("选了「积分解锁」请填写所需积分（正整数）"); return
        }
        var qty: Int? = nil
        if limited {
            guard let q = Int(quantityText), q >= 1 else {
                ToastCenter.shared.error("数量请填正整数"); return
            }
            qty = q
        }
        // 码为空按外部无料发布
        let plat = codeT.isEmpty ? "external" : platform
        if plat == "external" && hasAddrDeadline && addrDeadlineDate.timeIntervalSinceNow < 600 {
            ToastCenter.shared.error("地址时限至少要比现在晚 10 分钟"); return
        }
        if plat != "external" && hasExpires && expiresDate.timeIntervalSinceNow < 600 {
            ToastCenter.shared.error("失效时间至少要比现在晚 10 分钟"); return
        }
        // 限量（任何平台）→ 可见性强制「申请领取」；码为空可见性强制 open
        let vis = limited ? "request" : codeVisibility
        let visFinal = codeT.isEmpty ? "open" : vis
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let dl: String? = (plat == "external" && hasAddrDeadline) ? iso.string(from: addrDeadlineDate) : nil
        let exp: String? = (plat != "external" && hasExpires) ? iso.string(from: expiresDate) : nil
        let pc: Int? = claimMode == "points" ? Int(pointCostText) : nil
        let ship = plat == "external" ? shippingFree : false

        busy = true
        defer { busy = false }
        do {
            var coverData = existingCover ?? ""
            if let img = cover {
                guard let dataURL = ImageCodec.coverDataURL(from: img) else {
                    ToastCenter.shared.error("封面图片处理失败"); return
                }
                coverData = dataURL
            }
            let tagIds = selectedTags.map { $0.id }
            if let d = editing {
                _ = try await MashanglingAPI.shared.showcase.update(
                    id: d.id, title: trimmed, platform: plat, rouzaoCode: codeT,
                    codeVisibility: visFinal, description: descriptionText,
                    coverImage: coverData, tagIds: tagIds, stockStatus: stockStatus,
                    quantity: qty, claimMode: claimMode, pointCost: pc,
                    addressDeadline: dl, expiresAt: exp,
                    shippingFree: ship, pinned: pinned)
                ToastCenter.shared.success("已保存修改")
                dismiss()
            } else {
                let newId = try await MashanglingAPI.shared.showcase.create(
                    title: trimmed, platform: plat, rouzaoCode: codeT,
                    codeVisibility: visFinal, description: descriptionText,
                    coverImage: coverData, tagIds: tagIds, stockStatus: stockStatus,
                    quantity: qty, claimMode: claimMode, pointCost: pc,
                    addressDeadline: dl, expiresAt: exp,
                    shippingFree: ship)
                ToastCenter.shared.success("发布成功！")
                publishedId = newId
            }
        } catch {
            ToastCenter.shared.error(error.localizedDescription)
        }
    }
}
