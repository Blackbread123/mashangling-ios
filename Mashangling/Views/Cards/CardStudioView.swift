import SwiftUI
import UIKit

// MARK: - 个性化分享卡片（逐行复刻网页 CardStudio.tsx）
// 编辑器（命名/色系/RGB 自定义/渐变开关/PNG 素材上传+滑块调大小）+ 实时预览（拖动素材调位置）
// + 我的卡片列表（编辑/默认/分享/发布广场/删除）+ 自定义母鸡 + 卡片码分享弹窗 + 发布到广场弹窗
struct CardStudioView: View {
    @EnvironmentObject var authManager: AuthManager

    // 编辑状态（网页：editingId nil=新建）
    @State private var mine: CardMineResponse? = nil
    @State private var editingId: Int? = nil
    @State private var name = "我的卡片"
    @State private var palette = "orange"
    @State private var gradient = false
    @State private var stickers: [CardConfig.CardSticker] = []
    @State private var dirty = false
    // RGB 自定义色条
    @State private var customRgb: [Double] = [185, 28, 28]
    // 加载/提交
    @State private var loading = true
    @State private var saving = false
    // 弹窗
    @State private var shareTheme: CardThemeItem? = nil
    @State private var publishTheme: CardThemeItem? = nil
    @State private var deleteTheme: CardThemeItem? = nil
    // 素材/母鸡选图
    @State private var showStickerPicker = false
    @State private var stickerImage: UIImage? = nil
    @State private var showHenPicker = false
    @State private var henImage: UIImage? = nil
    @State private var replacingHenId: Int? = nil
    // 母鸡
    @State private var hens: CardHensResponse? = nil
    @State private var henBusy = false
    // 预览图导出
    @State private var exportImage: UIImage? = nil
    // 导入
    @State private var importCode = ""
    @State private var autoLoaded = false

    private var customHex: String {
        "#" + customRgb.map { String(format: "%02x", Int($0)) }.joined()
    }
    private var config: CardConfig { CardConfig(palette: palette, gradient: gradient, stickers: stickers) }

    var body: some View {
        NavigationStack {
            Group {
                if !authManager.isAuthenticated {
                    Text("登录后使用个性化卡片")
                        .font(.system(size: 14))
                        .foregroundColor(.appMutedFg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 64)
                        .overlay(RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.appBorder, style: StrokeStyle(lineWidth: 0.5, dash: [4, 3])))
                        .padding(16)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            header.padding(.top, 32)
                            if loading {
                                LoadingView().frame(maxWidth: .infinity).padding(.top, 60)
                            } else {
                                editorCard.padding(.top, 24)
                                previewSection.padding(.top, 24)
                                myCardsSection.padding(.top, 40)
                                henSection.padding(.top, 40)
                            }
                            FooterView().padding(.top, 16)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                    .refreshable { await load() }
                }
            }
            .background(Color.appBackground)
            .webHeader()
            .task { await load() }
            .sheet(item: $shareTheme) { t in ShareCardCodeSheet(theme: t) }
            .sheet(item: $publishTheme) { t in PublishCardSheet(theme: t) }
            .sheet(isPresented: $showStickerPicker) { ImagePicker(image: $stickerImage) }
            .sheet(isPresented: $showHenPicker) { ImagePicker(image: $henImage) }
            .sheet(isPresented: Binding(get: { exportImage != nil }, set: { if !$0 { exportImage = nil } })) {
                if let img = exportImage { ShareSheet(items: [img]) }
            }
            .alert("删除卡片", isPresented: Binding(get: { deleteTheme != nil }, set: { if !$0 { deleteTheme = nil } })) {
                Button("删除", role: .destructive) {
                    if let t = deleteTheme { Task { await removeTheme(t) } }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("删除「\(deleteTheme?.name ?? "")」？此操作不可恢复，已发布到广场的同款作品也会一并下架。")
            }
            .onChange(of: stickerImage) { img in
                if let img = img { addSticker(img) }
            }
            .onChange(of: henImage) { img in
                if let img = img { Task { await uploadHen(img) } }
            }
        }
    }

    // MARK: 标题区（网页：Palette 图标 24 主色 + 24px 粗标题 + 说明 + 去卡片广场逛逛）
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "paintpalette")
                    .font(.system(size: 22))
                    .foregroundColor(.appPrimary)
                Text("个性化分享卡片")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.appForeground)
            }
            Text("设计你的专属橱窗分享卡片：上传 PNG 素材（免抠图直接用）、换色系、摆位置。网站名称和网址会缩小保留在卡片底部。分享橱窗/生成分享图时会自动应用你的默认卡片。")
                .font(.system(size: 14))
                .foregroundColor(.appMutedFg)
                .padding(.top, 6)
            NavigationLink(destination: CardPlazaView()) {
                HStack(spacing: 6) {
                    Image(systemName: "megaphone").font(.system(size: 12))
                    Text("去卡片广场逛逛").font(.system(size: 13))
                }
                .foregroundColor(.appForeground)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
        }
    }

    // MARK: 编辑器卡片（网页左侧 section：rounded-2xl border bg-card p-5）
    private var editorCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 命名行
            HStack(spacing: 8) {
                TextField("卡片名字", text: $name)
                    .font(.system(size: 14))
                    .foregroundColor(.appForeground)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(width: 176)
                    .background(Color.appCard)
                    .cornerRadius(3)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.appInput, lineWidth: 0.5))
                    .onChange(of: name) { _ in dirty = true }
                Text(editingId.map { "正在编辑 #\($0)" } ?? "新卡片（未保存）")
                    .font(.system(size: 12))
                    .foregroundColor(.appMutedFg)
                    .lineLimit(1)
            }
            HStack {
                Spacer()
                if editingId != nil {
                    Button { resetEditor() } label: {
                        Text("新建一套")
                            .font(.system(size: 13))
                            .foregroundColor(.appForeground)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
                Button { Task { await save() } } label: {
                    Text(saving ? "保存中…" : (editingId != nil ? "保存修改" : saveLabel))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.appPrimaryFg)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.appPrimary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(saving || (editingId != nil && !dirty))
            }
            .padding(.top, 8)

            // 色系
            HStack {
                Text("卡片色系").font(.system(size: 14, weight: .medium)).foregroundColor(.appForeground)
                Spacer()
                // 渐变开关（网页自制 switch：36×20 胶囊 + 16 圆钮）
                Button {
                    gradient.toggle()
                    dirty = true
                } label: {
                    HStack(spacing: 8) {
                        Text(gradient ? "渐变背景" : "纯色背景")
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                        ZStack(alignment: gradient ? .trailing : .leading) {
                            Capsule()
                                .fill(gradient ? Color.appPrimary : Color.appSecondary)
                                .frame(width: 36, height: 20)
                            Circle()
                                .fill(Color.white)
                                .frame(width: 16, height: 16)
                                .shadow(radius: 1)
                                .padding(2)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 20)

            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading),
                                GridItem(.flexible(), alignment: .leading),
                                GridItem(.flexible(), alignment: .leading)], spacing: 8) {
                ForEach(CardPalettes.all, id: \.key) { item in
                    Button {
                        palette = item.key
                        dirty = true
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(item.p.primary)
                                .frame(width: 16, height: 16)
                            Text(item.p.label)
                                .font(.system(size: 14, weight: palette == item.key ? .medium : .regular))
                                .foregroundColor(.appForeground)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(palette == item.key ? Color.appPrimary.opacity(0.05) : Color.clear)
                        .overlay(Capsule().stroke(palette == item.key ? Color.appPrimary : Color.appBorder,
                                                  lineWidth: palette == item.key ? 1.5 : 0.5))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 8)

            // RGB 自定义色条
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("自定义颜色（RGB 色条）")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.appMutedFg)
                    Spacer()
                    Circle()
                        .fill(Color(hex: customHex))
                        .frame(width: 20, height: 20)
                        .overlay(Circle().stroke(Color.appBorder, lineWidth: 0.5))
                    Text(customHex)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.appMutedFg)
                }
                rgbSlider("R", 0, Color.twRed500).padding(.top, 8)
                rgbSlider("G", 1, Color.twEmerald500).padding(.top, 6)
                rgbSlider("B", 2, Color.twSky700).padding(.top, 6)
                Button {
                    palette = customHex
                    dirty = true
                } label: {
                    Text(palette == customHex ? "已应用此颜色" : "应用此颜色")
                        .font(.system(size: 12, weight: palette == customHex ? .semibold : .medium))
                        .foregroundColor(palette == customHex ? Color.appPrimaryFg : Color.appPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(palette == customHex ? Color.appPrimary : Color.clear)
                        .cornerRadius(3)
                        .overlay(RoundedRectangle(cornerRadius: 3)
                            .stroke(palette == customHex ? Color.clear : Color.appPrimary.opacity(0.5), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
            .padding(12)
            .background(Color.appSecondary.opacity(0.3))
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 0.5))
            .padding(.top, 16)

            Text("开启「渐变背景」后，卡片底色为该色系的浅→深渐变；不开启则是纯色色块。")
                .font(.system(size: 11))
                .foregroundColor(.appMutedFg)
                .padding(.top, 6)

            // 素材
            HStack {
                Text("素材（PNG · 最多两个）")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.appForeground)
                Spacer()
                Button { showStickerPicker = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.square").font(.system(size: 14))
                        Text("上传素材").font(.system(size: 13))
                    }
                    .foregroundColor(.appForeground)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .disabled(stickers.count >= 2)
                .opacity(stickers.count >= 2 ? 0.5 : 1)
            }
            .padding(.top, 20)

            if stickers.isEmpty {
                Text("还没有素材。上传后在右侧预览图上直接拖动调整位置，下方滑块调大小。")
                    .font(.system(size: 12))
                    .foregroundColor(.appMutedFg)
                    .padding(.top, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(stickers.enumerated()), id: \.element.id) { i, st in
                        stickerRow(i, st)
                    }
                }
                .padding(.top, 8)
            }

            // 导入
            Rectangle().fill(Color.appBorder.opacity(0.6)).frame(height: 0.5).padding(.top, 20)
            Text("用卡片码导入别人的设计")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.appForeground)
                .padding(.top, 16)
            HStack(spacing: 8) {
                TextField("输入 8 位卡片码", text: $importCode)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.appForeground)
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(width: 176)
                    .background(Color.appCard)
                    .cornerRadius(3)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.appInput, lineWidth: 0.5))
                    .onChange(of: importCode) { v in
                        let up = v.uppercased()
                        if up != v { importCode = up }
                        if importCode.count > 8 { importCode = String(importCode.prefix(8)) }
                    }
                Button { Task { await importTheme() } } label: {
                    Text("导入")
                        .font(.system(size: 13))
                        .foregroundColor(.appForeground)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .disabled(importCode.trimmingCharacters(in: .whitespaces).count < 4 || saving)
            }
            .padding(.top, 8)
            Text("导入的卡片会占用一套卡片位置（套数价格和自制相同）。")
                .font(.system(size: 11))
                .foregroundColor(.appMutedFg)
                .padding(.top, 6)
        }
        .padding(20)
        .background(Color.appCard)
        .cornerRadius(5)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appBorder, lineWidth: 0.5))
    }

    private func rgbSlider(_ label: String, _ idx: Int, _ tint: Color) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.appMutedFg)
                .frame(width: 16)
            Slider(value: Binding(get: { customRgb[idx] }, set: { customRgb[idx] = $0.rounded() }),
                   in: 0...255)
                .tint(tint)
            Text("\(Int(customRgb[idx]))")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.appMutedFg)
                .frame(width: 32, alignment: .trailing)
        }
    }

    // MARK: 素材行（网页：40px 缩略图 + 名称 + 滑块 0.05~1 + 百分比 + 删除）
    private func stickerRow(_ i: Int, _ st: CardConfig.CardSticker) -> some View {
        HStack(spacing: 12) {
            stickerImageView(st.url)
                .frame(width: 40, height: 40)
                .background(Color.appSecondary)
                .cornerRadius(3)
            Text("素材 \(i + 1)")
                .font(.system(size: 12))
                .foregroundColor(.appMutedFg)
            Slider(value: Binding(
                get: { stickers[i].scale },
                set: { stickers[i].scale = $0; dirty = true }), in: 0.05...1)
                .tint(.appPrimary)
            Text("\(Int((stickers[i].scale * 100).rounded()))%")
                .font(.system(size: 12))
                .foregroundColor(.appMutedFg)
                .frame(width: 40, alignment: .trailing)
            Button {
                stickers.remove(at: i)
                dirty = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12))
                    .foregroundColor(.appMutedFg)
                    .padding(4)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 0.5))
        .cornerRadius(4)
    }

    /// 贴纸图（dataURL 直接解码）
    private func stickerImageView(_ url: String) -> some View {
        Group {
            if let data = SiteConfig.dataFromDataURL(url), let ui = UIImage(data: data) {
                Image(uiImage: ui).resizable().aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "photo").foregroundColor(.appMutedFg)
            }
        }
    }

    // MARK: 实时预览（网页右侧：可拖动热区 + 下载预览图）
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("实时预览（拖动素材调整位置）")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.appForeground)

            // 用 Color.clear 确立 3:4 尺寸，GeometryReader 放 overlay 里才能拿到真实宽度
            Color.clear
                .aspectRatio(ShareCardCanvas.designW / ShareCardCanvas.designH, contentMode: .fit)
                .overlay {
                    GeometryReader { geo in
                        let w = geo.size.width
                        let h = w * ShareCardCanvas.designH / ShareCardCanvas.designW
                        ZStack(alignment: .topLeading) {
                    ShareCardCanvas(
                        title: "示例橱窗标题 · 同人吧唧三件套",
                        cover: nil,
                        platformLabel: "外部无料",
                        authorName: "你的名字",
                        tags: ["纸制品", "制品", "同人"],
                        theme: config
                    )
                    .scaleEffect(w / ShareCardCanvas.designW, anchor: .topLeading)
                    .frame(width: w, height: h, alignment: .topLeading)
                    .clipped()

                    // 可拖动热区（虚线框，与素材位置对应）
                    ForEach(Array(stickers.enumerated()), id: \.element.id) { i, st in
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Color.appPrimary.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            .frame(width: w * st.scale, height: w * st.scale)
                            .offset(x: w * st.x, y: h * st.y)
                            .gesture(
                                DragGesture()
                                    .onChanged { v in
                                        let start = dragStart(for: i, fallback: st)
                                        let nx = start.x + v.translation.width / w
                                        let ny = start.y + v.translation.height / h
                                        stickers[i].x = min(1, max(-0.3, nx))
                                        stickers[i].y = min(1, max(-0.3, ny))
                                    }
                                    .onEnded { _ in
                                        dragStarts[i] = nil
                                        dirty = true
                                    }
                            )
                    }
                }
                .frame(width: w, height: h)
                    }
                }
                .cornerRadius(5)
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appBorder, lineWidth: 0.5))

            Button { exportPreview() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.to.line").font(.system(size: 12))
                    Text("下载预览图").font(.system(size: 13))
                }
                .foregroundColor(.appForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    @State private var dragStarts: [Int: CGPoint] = [:]
    private func dragStart(for i: Int, fallback: CardConfig.CardSticker) -> CGPoint {
        if let s = dragStarts[i] { return s }
        let p = CGPoint(x: fallback.x, y: fallback.y)
        dragStarts[i] = p
        return p
    }

    // MARK: 我的卡片列表（网页：系统默认卡片 + ThemeSlot 网格）
    private var myCardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let m = mine {
                HStack {
                    Text("我的卡片（\(m.count)/\(m.maxThemes)）")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.appForeground)
                    Spacer()
                    if let next = m.nextCost {
                        Text(next == 0
                             ? (m.count == 0 ? "第 1 套免费" : "有已购空位 · 补建免费")
                             : "下一套解锁需 \(next) 积分（可用 \(m.availablePoints)）")
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                    }
                }
                // 系统默认
                ThemeSlotView(active: m.defaultThemeId == nil,
                              title: "系统默认卡片",
                              subtitle: "暖阳橙 · 无素材",
                              badge: m.defaultThemeId == nil ? "使用中" : nil) {
                    if m.defaultThemeId != nil {
                        slotBtn("设为默认", icon: "star") { Task { await setDefault(nil) } }
                    }
                }
                ForEach(m.themes) { t in
                    ThemeSlotView(active: m.defaultThemeId == t.id,
                                  title: t.name,
                                  subtitle: "\(paletteLabel(t.config.palette)) · 素材 \(t.config.stickers.count) 个\(t.source == "imported" ? " · 导入" : "")",
                                  badge: m.defaultThemeId == t.id ? "使用中" : nil) {
                        slotBtn("编辑") { loadTheme(t) }
                        if m.defaultThemeId != t.id {
                            slotBtn("默认", icon: "star") { Task { await setDefault(t.id) } }
                        }
                        slotBtn("分享", icon: "square.and.arrow.up") { shareTheme = t }
                        slotBtn("发布到广场", icon: "megaphone") { publishTheme = t }
                        Button { deleteTheme = t } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                                .foregroundColor(.appDestructive)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func paletteLabel(_ key: String) -> String {
        CardPalettes.all.first(where: { $0.key == key })?.p.label ?? key
    }

    private func slotBtn(_ title: String, icon: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon { Image(systemName: icon).font(.system(size: 10)) }
                Text(title).font(.system(size: 12))
            }
            .foregroundColor(.appForeground)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: 自定义母鸡（网页 HenManager）
    private var henSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("自定义母鸡\(hens.map { "（\($0.count)/\($0.maxHens)）" } ?? "")")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.appForeground)
                Text("透明底 PNG 免抠图 · 会显示在你个人主页的鸡场里")
                    .font(.system(size: 12))
                    .foregroundColor(.appMutedFg)
                    .lineLimit(2)
            }
            if let d = hens {
                if let next = d.nextCost {
                    HStack {
                        Spacer()
                        Text(next == 0
                             ? (d.count == 0 ? "第 1 只免费" : "有已购空位 · 补传免费")
                             : "下一只需 \(next) 积分（可用 \(d.availablePoints)）")
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                    }
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(Array(d.hens.enumerated()), id: \.element.id) { i, hen in
                        VStack(spacing: 4) {
                            AppImage(path: hen.image, contentMode: .fit)
                                .frame(width: 64, height: 64)
                            Text("第 \(i + 1) 只")
                                .font(.system(size: 10))
                                .foregroundColor(.appMutedFg)
                            HStack(spacing: 6) {
                                Button {
                                    replacingHenId = hen.id
                                    showHenPicker = true
                                } label: {
                                    Text("换图")
                                        .font(.system(size: 12))
                                        .foregroundColor(.appForeground)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                                }
                                .buttonStyle(.plain)
                                .disabled(henBusy)
                                Button { Task { await removeHen(hen) } } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12))
                                        .foregroundColor(.appMutedFg)
                                }
                                .buttonStyle(.plain)
                                .disabled(henBusy)
                            }
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(Color.appSecondary.opacity(0.3))
                        .cornerRadius(4)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 0.5))
                    }
                    if d.nextCost != nil {
                        Button {
                            replacingHenId = nil
                            showHenPicker = true
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "plus.square")
                                    .font(.system(size: 18))
                                Text(d.nextCost == 0
                                     ? (d.count == 0 ? "上传第 1 只（免费）" : "补传第 \(d.count + 1) 只（免费）")
                                     : "上传第 \(d.count + 1) 只（\(d.nextCost ?? 0) 积分）")
                                    .font(.system(size: 12))
                                    .multilineTextAlignment(.center)
                            }
                            .foregroundColor(.appMutedFg)
                            .frame(maxWidth: .infinity, minHeight: 120)
                            .overlay(RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.appBorder, style: StrokeStyle(lineWidth: 0.5, dash: [4, 3])))
                        }
                        .buttonStyle(.plain)
                        .disabled(henBusy)
                    }
                }
                if d.nextCost == nil {
                    Text("鸡场住满啦（最多 7 只）。")
                        .font(.system(size: 12))
                        .foregroundColor(.appMutedFg)
                }
                Text("每只都可以随时免费换图；删除后积分不退还。7 只母鸡会自动等比缩小，不会超出鸡场框。")
                    .font(.system(size: 11))
                    .foregroundColor(.appMutedFg)
            }
        }
        .padding(20)
        .background(Color.appCard)
        .cornerRadius(5)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appBorder, lineWidth: 0.5))
    }

    // MARK: 逻辑
    private var saveLabel: String {
        guard let m = mine, let next = m.nextCost else { return "保存" }
        return next == 0 ? "保存（免费）" : "保存（\(next) 积分）"
    }

    private func resetEditor() {
        editingId = nil
        name = "我的卡片"
        palette = "orange"
        gradient = false
        stickers = []
        dirty = false
    }

    private func loadTheme(_ t: CardThemeItem) {
        editingId = t.id
        name = t.name
        palette = t.config.palette
        gradient = t.config.gradient
        stickers = t.config.stickers
        dirty = false
    }

    private func addSticker(_ img: UIImage) {
        stickerImage = nil
        if stickers.count >= 2 {
            ToastCenter.shared.error("一套最多上传两个素材")
            return
        }
        guard let dataURL = ImageCodec.pngDataURL(from: img) else {
            ToastCenter.shared.error("图片处理失败")
            return
        }
        // dataURL base64 体积 ≈ 原始 × 4/3
        if dataURL.count * 3 / 4 > 1_024 * 1_024 {
            ToastCenter.shared.error("素材请控制在 1MB 以内")
            return
        }
        stickers.append(CardConfig.CardSticker(url: dataURL, x: 0.62, y: 0.55, scale: 0.22))
        dirty = true
    }

    private func exportPreview() {
        let canvas = ShareCardCanvas(
            title: "示例橱窗标题 · 同人吧唧三件套",
            cover: nil, platformLabel: "外部无料", authorName: "你的名字",
            tags: ["纸制品", "制品", "同人"], theme: config)
        if let img = ViewSnapshot.image(of: canvas, size: CGSize(width: ShareCardCanvas.designW, height: ShareCardCanvas.designH)) {
            exportImage = img
        }
    }

    private func load() async {
        loading = true
        mine = try? await MashanglingAPI.shared.card.mine()
        hens = try? await MashanglingAPI.shared.card.hens()
        loading = false
        // 首次进入自动载入当前使用的卡片（默认卡片，否则第一套）
        if !autoLoaded, let m = mine {
            autoLoaded = true
            if let cur = m.themes.first(where: { $0.id == m.defaultThemeId }) ?? m.themes.first {
                loadTheme(cur)
            }
        }
    }

    private func save() async {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else {
            ToastCenter.shared.error("给这套卡片起个名字")
            return
        }
        saving = true
        defer { saving = false }
        do {
            if let eid = editingId {
                _ = try await MashanglingAPI.shared.card.update(id: eid, name: n, config: config)
                ToastCenter.shared.success("已保存修改")
            } else {
                let r = try await MashanglingAPI.shared.card.create(name: n, config: config)
                editingId = r.id
                ToastCenter.shared.success(r.cost > 0
                                           ? "已保存（消耗 \(r.cost) 积分）· 卡片码 \(r.code)"
                                           : "已保存 · 卡片码 \(r.code)")
            }
            dirty = false
            await load()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func removeTheme(_ t: CardThemeItem) async {
        do {
            _ = try await MashanglingAPI.shared.card.remove(id: t.id)
            ToastCenter.shared.success("已删除")
            if editingId == t.id { resetEditor() }
            await load()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func setDefault(_ id: Int?) async {
        do {
            _ = try await MashanglingAPI.shared.card.setDefault(themeId: id)
            ToastCenter.shared.success(id == nil ? "已恢复系统默认卡片" : "已设为默认卡片")
            await load()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func importTheme() async {
        saving = true
        defer { saving = false }
        do {
            let r = try await MashanglingAPI.shared.card.importByCode(code: importCode.trimmingCharacters(in: .whitespaces))
            ToastCenter.shared.success(r.cost > 0 ? "已导入「\(r.name)」（消耗 \(r.cost) 积分）" : "已导入「\(r.name)」")
            importCode = ""
            await load()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func uploadHen(_ img: UIImage) async {
        henImage = nil
        guard let dataURL = ImageCodec.pngDataURL(from: img) else {
            ToastCenter.shared.error("图片处理失败")
            return
        }
        if dataURL.count * 3 / 4 > 1_024 * 1_024 {
            ToastCenter.shared.error("图片请控制在 1MB 以内")
            return
        }
        henBusy = true
        defer { henBusy = false }
        do {
            if let rid = replacingHenId {
                _ = try await MashanglingAPI.shared.card.updateHen(id: rid, image: dataURL)
                ToastCenter.shared.success("母鸡已换装")
            } else {
                let spent = try await MashanglingAPI.shared.card.uploadHen(image: dataURL)
                ToastCenter.shared.success(spent > 0 ? "母鸡入住鸡场（消耗 \(spent) 积分）" : "第一只母鸡免费入住鸡场！")
            }
            hens = try? await MashanglingAPI.shared.card.hens()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func removeHen(_ h: CardHensResponse.HenItem) async {
        henBusy = true
        defer { henBusy = false }
        do {
            _ = try await MashanglingAPI.shared.card.removeHen(id: h.id)
            ToastCenter.shared.success("已删除这只母鸡（积分不退还）")
            hens = try? await MashanglingAPI.shared.card.hens()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}

// MARK: - ThemeSlot（网页同名组件：rounded-xl border p-4，使用中高亮）
struct ThemeSlotView<Actions: View>: View {
    let active: Bool
    let title: String
    let subtitle: String
    var badge: String? = nil
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.appForeground)
                    .lineLimit(1)
                Spacer()
                if let badge = badge {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
                        Text(badge).font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.appPrimaryFg)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.appPrimary)
                    .clipShape(Capsule())
                }
            }
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundColor(.appMutedFg)
                .padding(.top, 2)
            HStack(spacing: 6) { actions }
                .padding(.top, 12)
        }
        .padding(16)
        .background(active ? Color.appPrimary.opacity(0.05) : Color.appCard)
        .cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4)
            .stroke(active ? Color.appPrimary : Color.appBorder, lineWidth: active ? 1.5 : 0.5))
    }
}

// MARK: - 分享卡片码弹窗（网页 shareOpen Dialog：大字卡片码 + 复制 + 好友私信列表）
struct ShareCardCodeSheet: View {
    let theme: CardThemeItem
    @Environment(\.dismiss) private var dismiss
    @State private var friends: [FollowUser] = []
    @State private var friendsLoading = true
    @State private var sentTo: Set<Int> = []
    @State private var sending = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // 卡片码
                    VStack(spacing: 0) {
                        Text("卡片码")
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                        Text(theme.code)
                            .font(.system(size: 30, weight: .bold, design: .monospaced))
                            .tracking(5)
                            .foregroundColor(.appForeground)
                            .padding(.top, 4)
                        Button {
                            UIPasteboard.general.string = theme.code
                            ToastCenter.shared.success("卡片码已复制")
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.doc").font(.system(size: 12))
                                Text("复制").font(.system(size: 13))
                            }
                            .foregroundColor(.appForeground)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 12)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(Color.appSecondary.opacity(0.5))
                    .cornerRadius(4)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 0.5))

                    // 好友列表
                    if friendsLoading {
                        LoadingView().frame(maxWidth: .infinity).padding(.top, 24)
                    } else if friends.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "person.2")
                                .font(.system(size: 18))
                                .foregroundColor(.appMutedFg)
                            Text("卡片码只能分享给互相关注的好友。\n还没有好友——去对方个人页点「关注」，对方回关后即成为好友。")
                                .font(.system(size: 12))
                                .foregroundColor(.appMutedFg)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .overlay(RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.appBorder, style: StrokeStyle(lineWidth: 0.5, dash: [4, 3])))
                        .padding(.top, 12)
                    } else {
                        VStack(spacing: 4) {
                            ForEach(friends) { f in
                                HStack(spacing: 10) {
                                    Text(f.name ?? "")
                                        .font(.system(size: 14))
                                        .foregroundColor(.appForeground)
                                        .lineLimit(1)
                                    Spacer()
                                    Button { Task { await sendTo(f.userId) } } label: {
                                        Text(sentTo.contains(f.userId) ? "已发送" : "发送卡片码")
                                            .font(.system(size: 12))
                                            .foregroundColor(sentTo.contains(f.userId) ? Color.appMutedFg : Color.appPrimaryFg)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 5)
                                            .background(sentTo.contains(f.userId) ? Color.appSecondary : Color.appPrimary)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(sentTo.contains(f.userId) || sending)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                            }
                        }
                        .padding(.top, 12)
                    }

                    Text("只有互相关注的好友才能收到卡片码私信；对方在「个性化」页输入卡片码即可导入你的设计（占用对方一套卡片位置）。")
                        .font(.system(size: 11))
                        .foregroundColor(.appMutedFg)
                        .padding(.top, 12)
                }
                .padding(20)
            }
            .background(Color.appBackground)
            .navigationTitle("分享这套卡片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                        .font(.system(size: 13))
                        .foregroundColor(.appMutedFg)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .task {
            friends = (try? await MashanglingAPI.shared.follow.mutuals()) ?? []
            friendsLoading = false
        }
    }

    private func sendTo(_ userId: Int) async {
        sending = true
        defer { sending = false }
        do {
            _ = try await MashanglingAPI.shared.dm.send(
                toUserId: userId,
                content: "我把我的分享卡片设计分享给你！打开「个性化」页，在「用卡片码导入」处输入这个卡片码就能用上同款：\(theme.code)",
                requireMutual: true)
            sentTo.insert(userId)
            ToastCenter.shared.success("卡片码已私信给对方")
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}

// MARK: - 发布到卡片广场弹窗（网页 PublishToPlazaDialog：标题 + 至少 1 个标签）
struct PublishCardSheet: View {
    let theme: CardThemeItem
    var onDone: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var q = ""
    @State private var picked: [Tag] = []
    @State private var results: [Tag] = []
    @State private var busy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("发布后以 SHOW ONLY 形式展示设计，不会公开卡片码。发布可获得 2 积分，点赞 / 想要 / 评论 / 转发也会带来少量积分。")
                        .font(.system(size: 12))
                        .foregroundColor(.appMutedFg)
                        .lineSpacing(8)

                    Text("作品标题")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appForeground)
                        .padding(.top, 16)
                    AppTextField(text: $title, placeholder: "给作品起个标题")
                        .padding(.top, 6)

                    HStack(spacing: 4) {
                        Image(systemName: "tag").font(.system(size: 11))
                        Text("标签（至少 1 个）")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.appForeground)
                    .padding(.top, 12)

                    if !picked.isEmpty {
                        FlowRow(spacing: 6) {
                            ForEach(picked) { t in
                                Button { picked.removeAll { $0.id == t.id } } label: {
                                    Text("\(t.name) ✕")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.appPrimaryFg)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.appPrimary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 8)
                    }

                    AppTextField(text: $q, placeholder: "搜索标签…")
                        .padding(.top, 8)
                        .onChange(of: q) { _ in Task { await searchTags() } }

                    FlowRow(spacing: 6) {
                        ForEach(results) { t in
                            let on = picked.contains { $0.id == t.id }
                            Button {
                                if on { picked.removeAll { $0.id == t.id } } else { picked.append(t) }
                            } label: {
                                Text(t.name)
                                    .font(.system(size: 12, weight: on ? .medium : .regular))
                                    .foregroundColor(on ? Color.appPrimary : Color.appForeground)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(on ? Color.appPrimary.opacity(0.1) : Color.clear)
                                    .overlay(Capsule().stroke(on ? Color.appPrimary : Color.appBorder, lineWidth: 0.5))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 8)

                    Button { Task { await publish() } } label: {
                        Text(busy ? "发布中…" : "发布")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.appPrimaryFg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color.appPrimary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || picked.isEmpty || busy)
                    .padding(.top, 16)
                }
                .padding(20)
            }
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
        .presentationDetents([.large])
        .onAppear {
            if title.isEmpty { title = theme.name }
            Task { await searchTags() }
        }
    }

    private func searchTags() async {
        results = (try? await MashanglingAPI.shared.tag.search(q: q, limit: 20)) ?? []
    }

    private func publish() async {
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.cardPlaza.publish(
                themeId: theme.id,
                title: title.trimmingCharacters(in: .whitespaces),
                tagIds: picked.map { $0.id })
            ToastCenter.shared.success("已发布到卡片广场（+2 积分）")
            dismiss()
            onDone()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}

// MARK: - 简易流式换行布局（iOS 16 Layout 协议）
struct FlowRow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? 0
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > w, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += size.width + spacing
            rowH = max(rowH, size.height)
        }
        return CGSize(width: w, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowH + spacing; rowH = 0
            }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowH = max(rowH, size.height)
        }
    }
}
