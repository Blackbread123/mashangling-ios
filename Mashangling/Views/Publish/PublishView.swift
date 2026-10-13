import SwiftUI
import UIKit

// MARK: - 发布 / 编辑橱窗（对应网页 Publish.tsx + TagPicker.tsx）
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
    @State private var newTagCategory = "work"
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
    // 盲盒：开关 + 奖项列表（名称 + 码 + 概率百分数字符串）
    @State private var isMystery = false
    @State private var mysteryItems: [MysteryItemInput] = [MysteryItemInput(), MysteryItemInput()]
    @State private var busy = false
    @State private var publishedId: Int? = nil
    // 发布草稿（网页 2026-10-13：localStorage["publish_draft_v1"] + 800ms 防抖，仅新建模式）
    @State private var draftPending: PublishDraft? = nil
    @State private var draftSaveTask: Task<Void, Never>? = nil

    private var isEdit: Bool { editing != nil }
    private let tagMax = 8

    var body: some View {
        Group {
            if isEdit {
                formContent
                    .navigationTitle("编辑橱窗")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("关闭") { dismiss() }
                                .font(.system(size: 13))
                                .foregroundColor(.appMutedFg)
                        }
                    }
            } else {
                // 主 Tab 形态：与网页一致，套用全局自绘顶栏
                formContent
                    .webHeader()
            }
        }
    }

    private var formContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // 副标题（对应网页 h1 下的说明段）
                Text("分享你的无料码（柔造 / 映糖）或外部无料，让同好领取。发布即表示你确认拥有该制品的分享授权。")
                    .font(.system(size: 14))
                    .foregroundColor(.appMutedFg)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 4)

                // 封面图 *
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("封面图 *")
                    Button { showPicker = true } label: {
                        if let img = cover {
                            coverPreview {
                                Image(uiImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            }
                        } else if let path = existingCover {
                            coverPreview {
                                AppImage(path: path, contentMode: .fill)
                            }
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "photo.badge.plus").font(.system(size: 32))
                                Text("点击上传封面（自动压缩）").font(.system(size: 14))
                            }
                            .foregroundColor(.appMutedFg)
                            .frame(maxWidth: .infinity)
                            .frame(height: 192)
                            .background(Color.appCard)
                            .cornerRadius(4)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appInput, style: StrokeStyle(lineWidth: 1, dash: [6])))
                        }
                    }
                    .buttonStyle(.plain)
                }

                // 标题 *
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("标题 *")
                    AppTextField(text: $title, placeholder: "例如：XX 同人吧唧三件套")
                        .onChange(of: title) { v in if v.count > 120 { title = String(v.prefix(120)) } }
                }

                // 无料来源 *
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("无料来源 *")
                    HStack(spacing: 6) {
                        ForEach([("rouzao", "柔造"), ("yingtang", "映糖"), ("external", "外部无料")], id: \.0) { p in
                            fullPillButton(p.1, selected: platform == p.0) { platform = p.0 }
                        }
                    }
                    if platform == "external" {
                        noteText("外部无料没有平台码，把「无料码」留空即可，其余设置（可见性、数量）与柔造/映糖一致。")
                        // 邮费（包邮 / 不包邮）
                        amberBox {
                            fieldLabel("邮费（包邮 / 不包邮）")
                            HStack(spacing: 6) {
                                smallOptionCard(title: "包邮",
                                                desc: "你承担邮费，领取人发送地址后无需任何操作",
                                                selected: shippingFree) { shippingFree = true }
                                smallOptionCard(title: "不包邮",
                                                desc: "下单后系统通知领取人补邮并上传转账截图，你审批通过后发货",
                                                selected: !shippingFree) { shippingFree = false }
                            }
                            noteText("选择会高亮显示在领取人的「发送地址」按钮旁。不包邮请先在「设置」里填好补邮支付宝账号，下单时会自动发给领取人。")
                        }
                        // 填写地址时限（可选）
                        amberBox {
                            fieldLabel("填写地址时限（可选）")
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
                                        .background(Color.appCard)
                                        .cornerRadius(4)
                                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appInput, style: StrokeStyle(lineWidth: 1, dash: [6])))
                                }
                                .buttonStyle(.plain)
                            }
                            noteText("留空 = 随时开放。设置后，领取人只能在截止时间前一键发送地址，超时后按钮会显示「已超时」并展示该时间；分钟按 10 分钟一档选择。之后修改时限会给特别关注你的人发邮件通知。")
                        }
                    }
                }

                // 盲盒开关：仅平台橱窗（柔造/映糖）
                if platform != "external" {
                    VStack(alignment: .leading, spacing: 6) {
                        fieldLabel("盲盒橱窗")
                        HStack(spacing: 6) {
                            fullPillButton("普通橱窗", selected: !isMystery) { isMystery = false }
                            fullPillButton("盲盒橱窗", selected: isMystery) { isMystery = true }
                        }
                        noteText("盲盒：配置多个无料（编号名称+各自的码）和抽中概率，访客领取后按概率随机获得其中一款的码；领取前只能看到各款名称和概率，看不到码。")
                    }

                    // 盲盒奖项配置
                    if isMystery {
                        mysteryEditor
                    }
                }

                // 无料码：外部无料可留空；盲盒隐藏（码在各奖项里）
                if !isMystery {
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("无料码" + (platform == "external" ? "（外部无料可留空）" : platform == "rouzao" ? "（柔造码）" : "（映糖码）"))
                    AppTextField(text: $rouzaoCode,
                                 placeholder: platform == "external" ? "没有平台码可留空" : platform == "rouzao" ? "粘贴柔造小程序里的分享码" : "粘贴映糖的分享码",
                                 monospace: true)
                        .onChange(of: rouzaoCode) { v in if v.count > 128 { rouzaoCode = String(v.prefix(128)) } }
                    if platform != "external" {
                        noteText("留空则会按「外部无料」发布。")
                    }
                }
                }

                // 分享码可见性：所有平台一致
                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("分享码可见性")
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
                    fieldLabel("数量（留空 = 不限）")
                    AppTextField(text: $quantityText, placeholder: "不限", keyboard: .numberPad)
                        .frame(width: 128)
                        .onChange(of: quantityText) { v in
                            let digits = String(v.filter { $0.isNumber }.prefix(4))
                            if digits != v { quantityText = digits }
                        }
                    if !quantityText.trimmingCharacters(in: .whitespaces).isEmpty {
                        noteText("设置了数量，将锁定为「申请领取」，按审批通过数判定领完，领完后无法再申请。")
                    }
                }

                // 库存状态
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("库存状态")
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
                            HStack(spacing: 6) {
                                smallOptionCard(title: "需审批",
                                                desc: "领取者需上传图片凭证（或文字说明），你批准后码才解锁",
                                                selected: claimMode == "request") { claimMode = "request" }
                                smallOptionCard(title: "无需审批",
                                                desc: "码仍遮挡，访客点「领取」立即解锁，领完即止",
                                                selected: claimMode == "instant") { claimMode = "instant" }
                                smallOptionCard(title: "积分解锁",
                                                desc: "访客支付你设定的积分立即解锁，积分转入你的账户，无需审批",
                                                selected: claimMode == "points") { claimMode = "points" }
                            }
                            if claimMode == "points" {
                                HStack(spacing: 8) {
                                    AppTextField(text: $pointCostText, placeholder: "所需积分", keyboard: .numberPad)
                                        .frame(width: 112)
                                        .onChange(of: pointCostText) { v in
                                            let digits = String(v.filter { $0.isNumber }.prefix(6))
                                            if digits != v { pointCostText = digits }
                                        }
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

                // 限时：仅普通橱窗（柔造/映糖）
                if platform != "external" {
                    VStack(alignment: .leading, spacing: 6) {
                        fieldLabel("限时（可选）")
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
                                    .background(Color.appCard)
                                    .cornerRadius(4)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appInput, style: StrokeStyle(lineWidth: 1, dash: [6])))
                            }
                            .buttonStyle(.plain)
                        }
                        noteText("留空 = 长期有效。设置后橱窗卡片和详情页会显示失效时间，到期后任何人（含礼物领取）都不能再领取，橱窗显示「已失效」。分钟按 10 分钟一档选择。")
                    }
                }

                // 简介
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("简介")
                    TextField("补充说明：制品规格、领取条件（是否需自付邮费）、数量限制等", text: $descriptionText, axis: .vertical)
                        .font(.system(size: 14))
                        .lineLimit(4...8)
                        .padding(10)
                        .background(Color.appInput)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                        .onChange(of: descriptionText) { v in if v.count > 2000 { descriptionText = String(v.prefix(2000)) } }
                }

                // 标签 *（对应网页 TagPicker）
                tagPickerSection

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
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appPrimaryFg)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Color.appPrimary)
                        .clipShape(Capsule())
                        .opacity(busy ? 0.6 : 1)
                }
                .buttonStyle(.plain)
                .disabled(busy)
                .padding(.bottom, 30)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.appBackground)
        .background(
            NavigationLink(destination: ShowcaseDetailView(showcaseId: publishedId ?? 0),
                           isActive: Binding(get: { publishedId != nil }, set: { if !$0 { publishedId = nil } })) { EmptyView() }
                .hidden()
        )
        .sheet(isPresented: $showPicker) { ImagePicker(image: $cover) }
        .onAppear {
            prefill()
            checkDraft()
        }
        // 草稿：内容变化后 800ms 防抖自动保存（仅新建模式）
        .onChange(of: draftFingerprint) { _ in scheduleDraftSave() }
        // 草稿询问弹窗（网页：「继续上次未发布的橱窗？」可恢复或丢弃）
        .confirmationDialog("继续上次未发布的橱窗？", isPresented: Binding(
            get: { draftPending != nil },
            set: { if !$0 { draftPending = nil } }
        ), titleVisibility: .visible) {
            Button("恢复草稿") { restoreDraft() }
            Button("丢弃草稿", role: .destructive) { discardDraft() }
        } message: {
            if let d = draftPending {
                Text("标题：\(d.title.isEmpty ? "（未填写）" : d.title)\n类型：\(d.isMystery ? "盲盒橱窗" : "普通橱窗")\n上次编辑：\(Self.draftTimeText(d.savedAt))")
            }
        }
    }

    // 封面预览（已选/回填）：自然比例，max-h-80，右下「更换图片」
    private func coverPreview<Content: View>(@ViewBuilder _ image: () -> Content) -> some View {
        ZStack(alignment: .bottomTrailing) {
            image()
                .frame(maxWidth: .infinity)
                .frame(maxHeight: 320)
                .clipped()
                .cornerRadius(4)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 1))
            Text("更换图片")
                .font(.system(size: 12))
                .foregroundColor(.white)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color.black.opacity(0.6))
                .clipShape(Capsule())
                .padding(12)
        }
    }

    // MARK: 标签选择（对应网页 TagPicker：已选 primary/10 胶囊 + 搜索 + 结果盒 + 创建行）
    private var tagPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 3) {
                Text("标签 *").font(.system(size: 14, weight: .medium)).foregroundColor(.appForeground)
            }
            if !selectedTags.isEmpty {
                HStack(alignment: .center, spacing: 6) {
                    FlowLayout(spacing: 6) {
                        ForEach(selectedTags) { t in
                            HStack(spacing: 4) {
                                Text(t.name)
                                Button { selectedTags.removeAll { $0.id == t.id } } label: {
                                    Image(systemName: "xmark").font(.system(size: 10))
                                }
                                .buttonStyle(.plain)
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.appPrimary)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Color.appPrimary.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                    Text("\(selectedTags.count)/\(tagMax)")
                        .font(.system(size: 12))
                        .foregroundColor(.appMutedFg)
                }
            }

            AppTextField(text: $tagQuery, placeholder: "搜索已有标签，或输入新标签名…")
                .onChange(of: tagQuery) { _ in Task { await searchTags() } }
                .onSubmit { Task { await searchTags() } }

            if !tagQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    let pickedIds = Set(selectedTags.map { $0.id })
                    let candidates = tagResults.filter { !pickedIds.contains($0.id) }
                    if !candidates.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(candidates) { t in
                                Button {
                                    guard selectedTags.count < tagMax else { return }
                                    selectedTags.append(t)
                                    tagQuery = ""
                                    tagResults = []
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(t.name).foregroundColor(.appSecondaryFg)
                                        Text("·\(TagCategory.label(t.category))")
                                            .foregroundColor(.appMutedFg)
                                    }
                                    .font(.system(size: 12))
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(Color.appSecondary)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    // 新建标签行：分类下拉 + 创建按钮
                    if !tagResults.contains(where: { $0.name == tagQuery.trimmingCharacters(in: .whitespaces) }) {
                        HStack(spacing: 8) {
                            Menu {
                                ForEach(["work", "character", "merch", "other"], id: \.self) { c in
                                    Button(TagCategory.label(c)) { newTagCategory = c }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(TagCategory.label(newTagCategory))
                                    Image(systemName: "chevron.down").font(.system(size: 10))
                                }
                                .font(.system(size: 12))
                                .foregroundColor(.appForeground)
                                .padding(.horizontal, 10)
                                .frame(height: 32)
                                .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.appInput, lineWidth: 1))
                            }
                            Button { Task { await createTag() } } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus").font(.system(size: 12))
                                    Text("创建「\(tagQuery.trimmingCharacters(in: .whitespaces))」")
                                        .font(.system(size: 12, weight: .medium))
                                        .lineLimit(1)
                                }
                                .foregroundColor(.appPrimaryFg)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Color.appPrimary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(busy)
                            Spacer(minLength: 0)
                        }
                        .padding(.top, 8)
                        .overlay(Rectangle().fill(Color.appBorder).frame(height: 1), alignment: .top)
                        .padding(.top, 4)
                    }
                    Text("建议按层级选择：先标「作品」（如游戏/番剧名），再标「角色」，最后标「制品」种类。分类仅作提示，不强制。")
                        .font(.system(size: 11))
                        .lineSpacing(5)
                        .foregroundColor(.appMutedFg)
                        .padding(.top, 8)
                }
                .padding(8)
                .background(Color.appCard)
                .cornerRadius(3)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.appBorder, lineWidth: 1))
            }
        }
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

    // 大选项卡（可见性：图标 + 标题 + 说明，rounded-xl=4 p-3.5）
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
                        .font(.system(size: 12))
                        .lineSpacing(7)
                        .foregroundColor(.appMutedFg)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(selected ? Color.appPrimary.opacity(0.05) : Color.appCard)
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(selected ? Color.appPrimary : Color.appBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // 小选项卡（邮费 / 领取方式：无图标，rounded-lg=3 px-3 py-2，flex-1）
    private func smallOptionCard(title: String, desc: String, selected: Bool,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.appForeground)
                Text(desc)
                    .font(.system(size: 11))
                    .lineSpacing(5)
                    .foregroundColor(.appMutedFg)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(selected ? Color.appPrimary.opacity(0.05) : Color.appCard)
            .cornerRadius(3)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(selected ? Color.appPrimary : Color.appBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // 琥珀色提示框（对应网页 border-amber-200 bg-amber-50/60 rounded-xl=4 p-3）
    private func amberBox<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) { content() }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.fixAmber100.opacity(0.6))
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.fixAmber200, lineWidth: 1))
    }

    // 说明文字（网页 text-[11px] leading-4 text-muted-foreground）
    private func noteText(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 11))
            .lineSpacing(5)
            .foregroundColor(.appMutedFg)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fieldLabel(_ t: String) -> some View {
        Text(t)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.appForeground)
    }

    // MARK: 盲盒奖项编辑器（对应网页 Publish.tsx 盲盒无料项配置）
    /// 网页 2026-10-13：已发布盲盒（编辑模式且 ownerMysteryItems 非空）码和概率锁死，不能增删项，只能改名称
    private var mysteryLocked: Bool {
        guard isEdit, let d = editing else { return false }
        return d.isMystery == true && !(d.ownerMysteryItems?.isEmpty ?? true)
    }

    private var mysteryEditor: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "dice")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#7c3aed"))
                Text("盲盒无料项（名称 + 码 + 概率）")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.appForeground)
            }
            .padding(.bottom, 8)

            // 网页：锁定提示条「码和概率已锁定，可以修改名称和照片」
            if mysteryLocked {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.fixAmber600)
                    Text("码和概率已锁定，可以修改名称和照片")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.fixAmber600)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.fixAmber100.opacity(0.6))
                .cornerRadius(4)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.fixAmber200, lineWidth: 1))
                .padding(.bottom, 8)
            }

            VStack(spacing: 8) {
                ForEach($mysteryItems) { $it in
                    HStack(spacing: 6) {
                        AppTextField(text: $it.name, placeholder: "名称（如 123 吧唧）")
                            .onChange(of: it.name) { v in if v.count > 120 { it.name = String(v.prefix(120)) } }
                        AppTextField(text: $it.code, placeholder: "码", monospace: true)
                            .frame(width: 108)
                            .onChange(of: it.code) { v in if v.count > 128 { it.code = String(v.prefix(128)) } }
                            .disabled(mysteryLocked)
                            .opacity(mysteryLocked ? 0.5 : 1)
                        HStack(spacing: 2) {
                            AppTextField(text: $it.percent, placeholder: "概率", keyboard: .decimalPad)
                                .onChange(of: it.percent) { v in
                                    let f = v.filter { $0.isNumber || $0 == "." }
                                    if f != v { it.percent = f }
                                }
                                .disabled(mysteryLocked)
                                .opacity(mysteryLocked ? 0.5 : 1)
                            Text("%").font(.system(size: 12)).foregroundColor(.appMutedFg)
                        }
                        .frame(width: 92)
                        if !mysteryLocked {
                            Button {
                                if mysteryItems.count > 2 {
                                    mysteryItems.removeAll { $0.id == it.id }
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 14))
                                    .foregroundColor(mysteryItems.count <= 2 ? Color.appMutedFg.opacity(0.3) : .appMutedFg)
                                    .padding(6)
                            }
                            .buttonStyle(.plain)
                            .disabled(mysteryItems.count <= 2)
                        }
                    }
                }
            }

            HStack {
                if !mysteryLocked {
                    Button {
                        mysteryItems.append(MysteryItemInput())
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus").font(.system(size: 11))
                            Text("加一项").font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(Color(hex: "#6d28d9"))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .overlay(Capsule().stroke(Color(hex: "#c4b5fd"), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
                let total = mysteryItems.reduce(0.0) { $0 + (Double($1.percent) ?? 0) }
                let ok = Int((total * 100).rounded()) == 10000
                Text("概率合计：\(fmtTotal(total))% \(ok ? "✓" : "（需 = 100%）")")
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundColor(ok ? .fixEmerald600 : .fixAmber600)
            }
            .padding(.top, 10)

            noteText("提示：各项概率合计必须等于 100% 才能发布。访客看到的是按概率从低到高排列的名称和百分比，码不公开。")
                .padding(.top, 8)
        }
        .padding(12)
        .background(Color(hex: "#f5f3ff").opacity(0.6))
        .cornerRadius(5)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(hex: "#c4b5fd"), lineWidth: 1))
    }

    private func fmtTotal(_ p: Double) -> String {
        let r = (p * 100).rounded() / 100
        if r == r.rounded() { return String(Int(r)) }
        return String(format: "%g", r)
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
        if let dt = DateFmt.parse(d.addressDeadline) {
            addrDeadlineDate = dt
            hasAddrDeadline = true
        }
        if let dt = DateFmt.parse(d.expiresAt) {
            expiresDate = dt
            hasExpires = true
        }
        descriptionText = d.description ?? ""
        existingCover = d.coverImage
        shippingFree = d.shippingFree ?? false
        // 盲盒回填：发布者可见全量 ownerMysteryItems
        isMystery = d.isMystery ?? false
        if d.isMystery == true, let items = d.ownerMysteryItems, !items.isEmpty {
            mysteryItems = items.map { m in
                var it = MysteryItemInput()
                it.name = m.name
                it.code = m.code
                it.percent = (m.percent == m.percent.rounded()) ? String(Int(m.percent)) : String(format: "%g", m.percent)
                return it
            }
        }
        selectedTags = d.tags ?? []
        pinned = d.pinned ?? false
    }

    /// 发布成功后清空表单（对齐网页：离开发布页后再次进入是全新空白表单）
    private func resetForm() {
        title = ""
        platform = "rouzao"
        rouzaoCode = ""
        codeVisibility = "open"
        descriptionText = ""
        cover = nil
        existingCover = nil
        selectedTags = []
        tagQuery = ""
        tagResults = []
        newTagCategory = "work"
        stockStatus = "none"
        claimMode = "request"
        quantityText = ""
        pointCostText = ""
        hasAddrDeadline = false
        addrDeadlineDate = Date().addingTimeInterval(86400)
        hasExpires = false
        expiresDate = Date().addingTimeInterval(7 * 86400)
        shippingFree = false
        pinned = false
        isMystery = false
        mysteryItems = [MysteryItemInput(), MysteryItemInput()]
    }

    // MARK: 发布草稿（网页 2026-10-13 Publish.tsx：localStorage["publish_draft_v1"]，800ms 防抖自动保存；仅新建模式，编辑已有橱窗不启用）
    private static let draftKey = "publish_draft_v1"

    /// 参与草稿保存的字段指纹（变化即触发防抖保存）；图片不入草稿（网页超配额时也只保文字）
    private var draftFingerprint: String {
        var parts = [title, platform, rouzaoCode, codeVisibility, descriptionText,
                     stockStatus, claimMode, quantityText, pointCostText,
                     shippingFree ? "1" : "0", isMystery ? "1" : "0"]
        for it in mysteryItems { parts.append("\(it.name)|\(it.code)|\(it.percent)") }
        return parts.joined(separator: "\n")
    }

    private func scheduleDraftSave() {
        guard !isEdit else { return }
        draftSaveTask?.cancel()
        draftSaveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000)
            if Task.isCancelled { return }
            saveDraft()
        }
    }

    private func currentDraft() -> PublishDraft {
        PublishDraft(
            title: title, platform: platform, rouzaoCode: rouzaoCode,
            codeVisibility: codeVisibility, descriptionText: descriptionText,
            stockStatus: stockStatus, claimMode: claimMode,
            quantityText: quantityText, pointCostText: pointCostText,
            shippingFree: shippingFree, isMystery: isMystery,
            mysteryItems: mysteryItems.map { ["name": $0.name, "code": $0.code, "percent": $0.percent] },
            savedAt: Date().timeIntervalSince1970)
    }

    private func saveDraft() {
        let d = currentDraft()
        // 全空表单不存草稿
        let empty = d.title.trimmingCharacters(in: .whitespaces).isEmpty
            && d.rouzaoCode.trimmingCharacters(in: .whitespaces).isEmpty
            && d.descriptionText.trimmingCharacters(in: .whitespaces).isEmpty
        if empty {
            UserDefaults.standard.removeObject(forKey: Self.draftKey)
            return
        }
        if let data = try? JSONEncoder().encode(d) {
            UserDefaults.standard.set(data, forKey: Self.draftKey)
        }
    }

    private func checkDraft() {
        guard !isEdit, draftPending == nil else { return }
        guard let data = UserDefaults.standard.data(forKey: Self.draftKey),
              let d = try? JSONDecoder().decode(PublishDraft.self, from: data) else { return }
        // 表单已有内容时不打扰（例如恢复后再次触发 onAppear）
        guard title.isEmpty && rouzaoCode.isEmpty && descriptionText.isEmpty else { return }
        draftPending = d
    }

    private func restoreDraft() {
        guard let d = draftPending else { return }
        title = d.title
        platform = d.platform
        rouzaoCode = d.rouzaoCode
        codeVisibility = d.codeVisibility
        descriptionText = d.descriptionText
        stockStatus = d.stockStatus
        claimMode = d.claimMode
        quantityText = d.quantityText
        pointCostText = d.pointCostText
        shippingFree = d.shippingFree
        isMystery = d.isMystery
        let rows = d.mysteryItems.compactMap { m -> MysteryItemInput? in
            var it = MysteryItemInput()
            it.name = m["name"] ?? ""
            it.code = m["code"] ?? ""
            it.percent = m["percent"] ?? ""
            return it
        }
        if !rows.isEmpty { mysteryItems = rows }
        draftPending = nil
        ToastCenter.shared.success("已恢复上次未发布的草稿")
    }

    private func discardDraft() {
        draftPending = nil
        UserDefaults.standard.removeObject(forKey: Self.draftKey)
    }

    private static func clearDraft() {
        UserDefaults.standard.removeObject(forKey: draftKey)
    }

    private static func draftTimeText(_ ts: TimeInterval) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 HH:mm"
        return f.string(from: Date(timeIntervalSince1970: ts))
    }

    private func searchTags() async {
        let q = tagQuery.trimmingCharacters(in: .whitespaces)
        tagResults = (try? await MashanglingAPI.shared.tag.search(q: q, limit: 12)) ?? []
    }

    private func createTag() async {
        let name = tagQuery.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, selectedTags.count < tagMax else { return }
        do {
            let t = try await MashanglingAPI.shared.tag.create(name: name, category: newTagCategory)
            selectedTags.append(t)
            tagQuery = ""
            tagResults = []
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    // 提交逻辑与网页 Publish.tsx submit() 一致
    private func submit() async {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        let codeT = rouzaoCode.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { ToastCenter.shared.error("请填写标题"); return }
        if platform != "external" && !isMystery && codeT.isEmpty {
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
        // 盲盒：校验奖项（至少 2 项、名称/码非空、概率合计 100%）
        var mysteryPayload: [[String: Any]]? = nil
        if isMystery {
            if platform == "external" {
                ToastCenter.shared.error("盲盒仅支持有码的平台橱窗（柔造/映糖）"); return
            }
            if mysteryItems.count < 2 {
                ToastCenter.shared.error("盲盒至少需要 2 个无料项"); return
            }
            var rows: [[String: Any]] = []
            for (i, it) in mysteryItems.enumerated() {
                let name = it.name.trimmingCharacters(in: .whitespaces)
                let code = it.code.trimmingCharacters(in: .whitespaces)
                if name.isEmpty { ToastCenter.shared.error("第 \(i + 1) 项请填写无料名称"); return }
                if code.isEmpty { ToastCenter.shared.error("第 \(i + 1) 项请填写对应的码"); return }
                guard let p = Double(it.percent), p > 0 else {
                    ToastCenter.shared.error("第 \(i + 1) 项概率请填大于 0 的数字"); return
                }
                if p > 100 { ToastCenter.shared.error("第 \(i + 1) 项概率不能超过 100%"); return }
                rows.append(["name": name, "code": code, "percent": p])
            }
            let total = rows.reduce(0.0) { $0 + ($1["percent"] as? Double ?? 0) }
            if Int((total * 100).rounded()) != 10000 {
                ToastCenter.shared.error("概率合计须等于 100%，当前为 \(fmtTotal(total))%，请调整后再发布"); return
            }
            mysteryPayload = rows
        }
        // 码为空按外部无料发布；盲盒保持所选平台（码在各奖项里）
        let plat = isMystery ? platform : (codeT.isEmpty ? "external" : platform)
        if plat == "external" && hasAddrDeadline && addrDeadlineDate.timeIntervalSinceNow < 600 {
            ToastCenter.shared.error("地址时限至少要比现在晚 10 分钟"); return
        }
        if plat != "external" && hasExpires && expiresDate.timeIntervalSinceNow < 600 {
            ToastCenter.shared.error("失效时间至少要比现在晚 10 分钟"); return
        }
        // 限量（任何平台）→ 可见性强制「申请领取」；码为空可见性强制 open（盲盒除外）
        let vis = limited ? "request" : codeVisibility
        let visFinal = (isMystery || !codeT.isEmpty) ? vis : "open"
        let codeFinal = isMystery ? "" : codeT
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
                    id: d.id, title: trimmed, platform: plat, rouzaoCode: codeFinal,
                    codeVisibility: visFinal, description: descriptionText,
                    coverImage: coverData, tagIds: tagIds, stockStatus: stockStatus,
                    quantity: qty, claimMode: claimMode, pointCost: pc,
                    addressDeadline: dl, expiresAt: exp,
                    shippingFree: ship, pinned: pinned,
                    isMystery: isMystery, mysteryItems: mysteryPayload)
                ToastCenter.shared.success("已保存修改")
                dismiss()
            } else {
                let newId = try await MashanglingAPI.shared.showcase.create(
                    title: trimmed, platform: plat, rouzaoCode: codeFinal,
                    codeVisibility: visFinal, description: descriptionText,
                    coverImage: coverData, tagIds: tagIds, stockStatus: stockStatus,
                    quantity: qty, claimMode: claimMode, pointCost: pc,
                    addressDeadline: dl, expiresAt: exp,
                    shippingFree: ship,
                    isMystery: isMystery, mysteryItems: mysteryPayload)
                ToastCenter.shared.success("发布成功！")
                // 网页：发布成功即清除草稿
                Self.clearDraft()
                // 网页行为：发布成功即离开本页，下次进入是全新空白表单；
                // App 发布 Tab 常驻，必须显式清空，否则旧内容残留像「在编辑原橱窗」
                resetForm()
                publishedId = newId
            }
        } catch {
            ToastCenter.shared.error(error.localizedDescription)
        }
    }
}

// MARK: - 盲盒奖项输入行（发布/编辑页本地状态）
struct MysteryItemInput: Identifiable, Equatable {
    let id = UUID()
    var name = ""
    var code = ""
    var percent = ""
}

// MARK: - 发布草稿（网页 publish_draft_v1；图片不入草稿，与网页超配额剔除图片一致）
struct PublishDraft: Codable {
    var title: String
    var platform: String
    var rouzaoCode: String
    var codeVisibility: String
    var descriptionText: String
    var stockStatus: String
    var claimMode: String
    var quantityText: String
    var pointCostText: String
    var shippingFree: Bool
    var isMystery: Bool
    var mysteryItems: [[String: String]]
    var savedAt: TimeInterval
}
