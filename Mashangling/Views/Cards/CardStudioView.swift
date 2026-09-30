import SwiftUI
import UIKit

// MARK: - 个性化（对应网页 Cards.tsx：卡片主题 + 自定义母鸡 + 对外展示开关）
struct CardStudioView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var mine: CardMineResponse? = nil
    @State private var hens: CardHensResponse? = nil
    @State private var cardsPublic = true
    @State private var tab = 0
    @State private var loading = true
    @State private var busy = false
    @State private var showEditor = false
    @State private var editingTheme: CardThemeItem? = nil
    @State private var importCode = ""
    @State private var showHenPicker = false
    @State private var henImage: UIImage? = nil
    @State private var publishTarget: CardThemeItem? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tabBtn(0, "我的卡片 \(mine?.count ?? 0)/\(mine?.maxThemes ?? 0)")
                tabBtn(1, "我的母鸡 \(hens?.count ?? 0)/\(hens?.maxHens ?? 0)")
            }
            .padding(3)
            .background(Color.appSecondary)
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.top, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if loading {
                        LoadingView()
                    } else if tab == 0 {
                        themesTab
                    } else {
                        hensTab
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(Color.appBackground)
        .navigationTitle("个性化")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .overlay(ToastOverlay())
        .sheet(isPresented: $showEditor) {
            CardThemeEditorSheet(editing: editingTheme) { Task { await load() } }
        }
        .sheet(isPresented: $showHenPicker) { ImagePicker(image: $henImage) }
        .sheet(item: $publishTarget) { t in
            PublishCardSheet(theme: t) { Task { await load() } }
        }
        .onChange(of: henImage) { img in
            if img != nil { Task { await uploadHen() } }
        }
    }

    private func tabBtn(_ idx: Int, _ title: String) -> some View {
        Button { tab = idx } label: {
            Text(title)
                .font(.system(size: 13, weight: tab == idx ? .semibold : .regular))
                .foregroundColor(tab == idx ? .appForeground : .appMutedFg)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(tab == idx ? Color.appCard : Color.clear)
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    // MARK: 卡片主题
    private var themesTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 操作行
            HStack(spacing: 8) {
                Button {
                    editingTheme = nil
                    showEditor = true
                } label: {
                    Label("新建卡片", systemImage: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.appPrimaryFg)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.appPrimary)
                        .clipShape(Capsule())
                }
                .disabled(busy)
                Spacer()
                Button { Task { await togglePublic() } } label: {
                    HStack(spacing: 4) {
                        Image(systemName: cardsPublic ? "eye" : "eye.slash")
                            .font(.system(size: 11))
                        Text(cardsPublic ? "卡片对外展示中" : "卡片已私密")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.appMutedFg)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .overlay(Capsule().stroke(Color.appBorder, lineWidth: 1))
                }
                .disabled(busy)
            }

            // 导入
            HStack(spacing: 8) {
                AppTextField(text: $importCode, placeholder: "输入卡片码导入别人的设计")
                Button { Task { await importTheme() } } label: {
                    Text("导入")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.appPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .overlay(Capsule().stroke(Color.appPrimary, lineWidth: 1))
                }
                .disabled(importCode.trimmingCharacters(in: .whitespaces).isEmpty || busy)
            }

            if let m = mine {
                if let next = m.nextCost {
                    Text("当前 \(m.count)/\(m.maxThemes) 套 · 解锁下一套需 \(next) 积分 · 可用积分 \(m.availablePoints)")
                        .font(.system(size: 10))
                        .foregroundColor(.appMutedFg)
                }
                if m.themes.isEmpty {
                    Text("还没有卡片主题，点「新建卡片」设计你的第一套分享卡片")
                        .font(.system(size: 12))
                        .foregroundColor(.appMutedFg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 1, dash: [6])))
                }
                ForEach(m.themes) { t in
                    themeRow(t, isDefault: m.defaultThemeId == t.id)
                }
            }
        }
    }

    private func themeRow(_ t: CardThemeItem, isDefault: Bool) -> some View {
        SectionCard {
            HStack(alignment: .top, spacing: 12) {
                CardThemeThumbnailView(config: t.config)
                    .frame(width: 88)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 0.5))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(t.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.appForeground)
                            .lineLimit(1)
                        if isDefault {
                            MiniBadge(text: "默认", fg: .appPrimaryFg, bg: .appPrimary)
                        }
                        if t.source == "imported" {
                            MiniBadge(text: "导入", fg: .appMutedFg, bg: .appSecondary)
                        }
                    }
                    Text("卡片码 \(t.code)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.appMutedFg)
                    HStack(spacing: 6) {
                        miniBtn("编辑") { editingTheme = t; showEditor = true }
                        miniBtn(isDefault ? "取消默认" : "设为默认") { Task { await setDefault(isDefault ? nil : t.id) } }
                        miniBtn("发到广场") { publishTarget = t }
                        miniBtn("复制码") {
                            UIPasteboard.general.string = t.code
                            ToastCenter.shared.success("卡片码已复制")
                        }
                    }
                    Spacer(minLength: 0)
                }
                Spacer()
            }
        }
        .contextMenu {
            Button(role: .destructive) { Task { await removeTheme(t) } } label: {
                Label("删除这套卡片", systemImage: "trash")
            }
        }
    }

    private func miniBtn(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.appPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .overlay(Capsule().stroke(Color.appPrimary.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(busy)
    }

    // MARK: 母鸡
    private var hensTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("自定义农场母鸡形象（PNG，透明底最佳）")
                    .font(.system(size: 11))
                    .foregroundColor(.appMutedFg)
                Spacer()
                Button { showHenPicker = true } label: {
                    Label("上传", systemImage: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.appPrimaryFg)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.appPrimary)
                        .clipShape(Capsule())
                }
                .disabled(busy)
            }
            if let h = hens {
                if let next = h.nextCost {
                    Text("当前 \(h.count)/\(h.maxHens) 只 · 解锁下一只需 \(next) 积分 · 可用积分 \(h.availablePoints)")
                        .font(.system(size: 10))
                        .foregroundColor(.appMutedFg)
                }
                if h.hens.isEmpty {
                    Text("还没有自定义母鸡，上传后农场和分享卡片里都会出现")
                        .font(.system(size: 12))
                        .foregroundColor(.appMutedFg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 1, dash: [6])))
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(h.hens) { hen in
                            AppImage(path: hen.image, contentMode: .fit)
                                .frame(height: 72)
                                .frame(maxWidth: .infinity)
                                .background(Color.appSecondary.opacity(0.3))
                                .cornerRadius(10)
                                .contextMenu {
                                    Button(role: .destructive) { Task { await removeHen(hen) } } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
        }
    }

    // MARK: 数据
    private func load() async {
        loading = true
        mine = try? await MashanglingAPI.shared.card.mine()
        hens = try? await MashanglingAPI.shared.card.hens()
        loading = false
    }

    private func togglePublic() async {
        busy = true
        defer { busy = false }
        do {
            let pub = try await MashanglingAPI.shared.card.togglePublic()
            cardsPublic = pub
            ToastCenter.shared.success(pub ? "卡片已对外展示" : "卡片已设为私密")
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func importTheme() async {
        busy = true
        defer { busy = false }
        do {
            let r = try await MashanglingAPI.shared.card.importByCode(code: importCode.trimmingCharacters(in: .whitespaces))
            ToastCenter.shared.success(r.cost > 0 ? "已导入「\(r.name)」（消耗 \(r.cost) 积分）" : "已导入「\(r.name)」")
            importCode = ""
            await load()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func setDefault(_ id: Int?) async {
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.card.setDefault(themeId: id)
            ToastCenter.shared.success(id == nil ? "已取消默认卡片" : "已设为默认分享卡片")
            await load()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func removeTheme(_ t: CardThemeItem) async {
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.card.remove(id: t.id)
            ToastCenter.shared.success("已删除")
            await load()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func uploadHen() async {
        guard let img = henImage, let dataURL = ImageCodec.pngDataURL(from: img) else {
            ToastCenter.shared.error("图片处理失败"); return
        }
        busy = true
        defer { busy = false }
        do {
            let spent = try await MashanglingAPI.shared.card.uploadHen(image: dataURL)
            ToastCenter.shared.success(spent > 0 ? "母鸡已上传（消耗 \(spent) 积分）" : "母鸡已上传")
            henImage = nil
            await load()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func removeHen(_ h: CardHensResponse.HenItem) async {
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.card.removeHen(id: h.id)
            await load()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}

// MARK: - 卡片主题编辑器
struct CardThemeEditorSheet: View {
    var editing: CardThemeItem? = nil
    var onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var palette = "orange"
    @State private var gradient = false
    @State private var busy = false

    private var config: CardConfig {
        CardConfig(palette: palette, gradient: gradient, stickers: editing?.config.stickers ?? [])
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // 预览
                    CardThemeThumbnailView(config: config)
                        .frame(maxWidth: 220)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, lineWidth: 0.5))
                        .frame(maxWidth: .infinity)

                    AppTextField(text: $name, placeholder: "卡片主题名称")

                    VStack(alignment: .leading, spacing: 6) {
                        Text("配色")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.appForeground)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(CardPalettes.all, id: \.key) { p in
                                Button { palette = p.key } label: {
                                    VStack(spacing: 3) {
                                        Circle()
                                            .fill(p.p.primary)
                                            .frame(width: 26, height: 26)
                                            .overlay(Circle().stroke(Color.appForeground, lineWidth: palette == p.key ? 2 : 0))
                                        Text(p.p.label)
                                            .font(.system(size: 8))
                                            .foregroundColor(palette == p.key ? .appForeground : .appMutedFg)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Toggle("渐变背景", isOn: $gradient)
                        .font(.system(size: 13))
                        .foregroundColor(.appForeground)

                    if editing?.config.stickers.isEmpty == false {
                        Text("贴纸沿用原设计（\(editing?.config.stickers.count ?? 0) 个）")
                            .font(.system(size: 10))
                            .foregroundColor(.appMutedFg)
                    }

                    Button { Task { await save() } } label: {
                        Text(busy ? "保存中…" : (editing == nil ? "创建卡片" : "保存修改"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.appPrimaryFg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color.appPrimary)
                            .clipShape(Capsule())
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || busy)
                }
                .padding(16)
            }
            .background(Color.appBackground)
            .navigationTitle(editing == nil ? "新建卡片" : "编辑卡片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                        .font(.system(size: 13))
                        .foregroundColor(.appMutedFg)
                }
            }
        }
        .presentationDetents([.large])
        .onAppear {
            name = editing?.name ?? ""
            palette = editing?.config.palette ?? "orange"
            gradient = editing?.config.gradient ?? false
        }
    }

    private func save() async {
        busy = true
        defer { busy = false }
        do {
            if let t = editing {
                _ = try await MashanglingAPI.shared.card.update(
                    id: t.id, name: name.trimmingCharacters(in: .whitespaces), config: config)
                ToastCenter.shared.success("已保存")
            } else {
                let r = try await MashanglingAPI.shared.card.create(
                    name: name.trimmingCharacters(in: .whitespaces), config: config)
                ToastCenter.shared.success(r.cost > 0 ? "创建成功（消耗 \(r.cost) 积分），卡片码 \(r.code)" : "创建成功")
            }
            dismiss()
            onDone()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}

// MARK: - 发布卡片到广场
struct PublishCardSheet: View {
    let theme: CardThemeItem
    var onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var busy = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    CardThemeThumbnailView(config: theme.config)
                        .frame(width: 72)
                        .cornerRadius(8)
                    Text(theme.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.appForeground)
                }
                AppTextField(text: $title, placeholder: "广场展示标题")
                Text("发布后其他用户可以浏览、点赞、评论、收藏；你随时可以撤下。")
                    .font(.system(size: 11))
                    .foregroundColor(.appMutedFg)
                Button { Task { await publish() } } label: {
                    Text(busy ? "发布中…" : "发布到广场")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appPrimaryFg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.appPrimary)
                        .clipShape(Capsule())
                }
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || busy)
                Spacer()
            }
            .padding(20)
            .background(Color.appBackground)
            .navigationTitle("发布到卡片广场")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                        .font(.system(size: 13))
                        .foregroundColor(.appMutedFg)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func publish() async {
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.cardPlaza.publish(
                themeId: theme.id, title: title.trimmingCharacters(in: .whitespaces), tagIds: [])
            ToastCenter.shared.success("已发布到卡片广场")
            dismiss()
            onDone()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}
