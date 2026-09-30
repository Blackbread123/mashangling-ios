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
    @State private var codeVisibility = "claim"
    @State private var descriptionText = ""
    @State private var cover: UIImage? = nil
    @State private var existingCover: String? = nil
    @State private var showPicker = false
    @State private var selectedTags: [Tag] = []
    @State private var tagQuery = ""
    @State private var tagResults: [Tag] = []
    @State private var newTagCategory = "other"
    @State private var stockStatus = "normal"
    @State private var claimMode = "request"
    @State private var quantityText = ""
    @State private var pointCostText = ""
    @State private var addressDeadline = ""
    @State private var expiresAt = ""
    @State private var shippingFree = false
    @State private var busy = false
    @State private var errorText: String? = nil

    private var isEdit: Bool { editing != nil }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                // 封面
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

                // 标题
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("标题", required: true)
                    AppTextField(text: $title, placeholder: "无料名称，如「xx 同人明信片一套」")
                }

                // 平台
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("平台", required: true)
                    HStack(spacing: 8) {
                        ForEach([("rouzao", "柔造"), ("yingtang", "映糖"), ("external", "外部无料")], id: \.0) { p in
                            PillButton(title: p.1, selected: platform == p.0) { platform = p.0 }
                        }
                        Spacer()
                    }
                    if platform == "external" {
                        Text("外部无料需要领取人提供收货地址，由你寄快递")
                            .font(.system(size: 10))
                            .foregroundColor(.appMutedFg)
                    }
                }

                // 无料码
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("无料码 / 兑换码", required: false)
                    AppTextField(text: $rouzaoCode, placeholder: "平台兑换码，多个可用逗号分隔；也可领取后补码")
                    HStack(spacing: 8) {
                        Text("可见性").font(.system(size: 12)).foregroundColor(.appMutedFg)
                        PillButton(title: "领取后可见", selected: codeVisibility == "claim") { codeVisibility = "claim" }
                        PillButton(title: "公开", selected: codeVisibility == "public") { codeVisibility = "public" }
                        Spacer()
                    }
                }

                // 描述
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("描述", required: false)
                    TextField("补充说明：领取条件、邮费、发货时间等…", text: $descriptionText, axis: .vertical)
                        .font(.system(size: 14))
                        .lineLimit(3...8)
                        .padding(10)
                        .background(Color.appInput)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // 标签
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("标签", required: false)
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

                // 库存
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("库存状态", required: true)
                    HStack(spacing: 8) {
                        ForEach([("normal", "常态"), ("limited", "限量"), ("restock", "可补码"), ("soldout", "领完即止")], id: \.0) { s in
                            PillButton(title: s.1, selected: stockStatus == s.0) { stockStatus = s.0 }
                        }
                        Spacer()
                    }
                    if stockStatus == "limited" {
                        AppTextField(text: $quantityText, placeholder: "限量份数，如 20", keyboard: .numberPad)
                    }
                }

                // 领取方式
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("领取方式", required: true)
                    HStack(spacing: 8) {
                        ForEach([("request", "申请审批"), ("instant", "即领"), ("points", "积分解锁")], id: \.0) { m in
                            PillButton(title: m.1, selected: claimMode == m.0) { claimMode = m.0 }
                        }
                        Spacer()
                    }
                    if claimMode == "points" {
                        AppTextField(text: $pointCostText, placeholder: "所需积分，如 50", keyboard: .numberPad)
                    }
                }

                // 进阶选项
                VStack(alignment: .leading, spacing: 10) {
                    fieldLabel("进阶选项", required: false)
                    if platform == "external" {
                        AppTextField(text: $addressDeadline, placeholder: "地址截止（如 2026-10-01 23:59，可选）")
                        Toggle("包邮（不收入领取人邮费）", isOn: $shippingFree)
                            .font(.system(size: 13))
                            .foregroundColor(.appForeground)
                    }
                    AppTextField(text: $expiresAt, placeholder: "限时领取截止（如 2026-10-01 23:59，可选）")
                }

                if let err = errorText {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundColor(.appDestructive)
                }

                Button { Task { await submit() } } label: {
                    Text(busy ? "提交中…" : (isEdit ? "保存修改" : "发布橱窗"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.appPrimaryFg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.appPrimary)
                        .cornerRadius(12)
                }
                .disabled(busy)
                .padding(.bottom, 30)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .background(Color.appBackground)
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

    private func fieldLabel(_ t: String, required: Bool) -> some View {
        HStack(spacing: 3) {
            Text(t).font(.system(size: 13, weight: .semibold)).foregroundColor(.appForeground)
            if required { Text("*").foregroundColor(.appDestructive) }
        }
    }

    private func prefill() {
        guard let d = editing else { return }
        title = d.title
        platform = d.platform ?? "rouzao"
        rouzaoCode = d.rouzaoCode ?? ""
        codeVisibility = d.codeVisibility ?? "claim"
        descriptionText = d.description ?? ""
        existingCover = d.coverImage
        selectedTags = d.tags ?? []
        stockStatus = d.stockStatus ?? "normal"
        claimMode = d.claimMode ?? "request"
        quantityText = d.quantity.map { "\($0)" } ?? ""
        pointCostText = d.pointCost.map { "\($0)" } ?? ""
        addressDeadline = d.addressDeadline ?? ""
        expiresAt = d.expiresAt ?? ""
        shippingFree = d.shippingFree ?? false
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

    private func submit() async {
        errorText = nil
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { errorText = "请填写标题"; return }
        guard cover != nil || existingCover != nil else { errorText = "请选择封面图"; return }
        if stockStatus == "limited", Int(quantityText) == nil { errorText = "请填写限量份数"; return }
        if claimMode == "points", Int(pointCostText) == nil { errorText = "请填写所需积分"; return }

        busy = true
        defer { busy = false }
        do {
            var coverData = existingCover ?? ""
            if let img = cover {
                guard let dataURL = ImageCodec.coverDataURL(from: img) else {
                    errorText = "封面图片处理失败"; return
                }
                coverData = dataURL
            }
            let tagIds = selectedTags.map { $0.id }
            let qty = stockStatus == "limited" ? Int(quantityText) : nil
            let pc = claimMode == "points" ? Int(pointCostText) : nil
            let dl = addressDeadline.trimmingCharacters(in: .whitespaces)
            let exp = expiresAt.trimmingCharacters(in: .whitespaces)

            if let d = editing {
                _ = try await MashanglingAPI.shared.showcase.update(
                    id: d.id, title: trimmed, platform: platform, rouzaoCode: rouzaoCode,
                    codeVisibility: codeVisibility, description: descriptionText,
                    coverImage: coverData, tagIds: tagIds, stockStatus: stockStatus,
                    quantity: qty, claimMode: claimMode, pointCost: pc,
                    addressDeadline: dl.isEmpty ? nil : dl,
                    expiresAt: exp.isEmpty ? nil : exp,
                    shippingFree: shippingFree, pinned: d.pinned ?? false)
                ToastCenter.shared.success("已保存修改")
                dismiss()
            } else {
                let newId = try await MashanglingAPI.shared.showcase.create(
                    title: trimmed, platform: platform, rouzaoCode: rouzaoCode,
                    codeVisibility: codeVisibility, description: descriptionText,
                    coverImage: coverData, tagIds: tagIds, stockStatus: stockStatus,
                    quantity: qty, claimMode: claimMode, pointCost: pc,
                    addressDeadline: dl.isEmpty ? nil : dl,
                    expiresAt: exp.isEmpty ? nil : exp,
                    shippingFree: shippingFree)
                ToastCenter.shared.success("发布成功")
                // 重置表单，便于连续发布
                title = ""; rouzaoCode = ""; descriptionText = ""
                cover = nil; existingCover = nil; selectedTags = []
                quantityText = ""; pointCostText = ""; addressDeadline = ""; expiresAt = ""
                _ = newId
            }
        } catch {
            errorText = error.localizedDescription
        }
    }
}
