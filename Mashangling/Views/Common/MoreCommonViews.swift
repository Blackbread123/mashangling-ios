import SwiftUI
import UIKit

// MARK: - 统一输入框（对应网页 Input 组件）
struct AppTextField: View {
    @Binding var text: String
    var placeholder: String = ""
    var keyboard: UIKeyboardType = .default
    var secure: Bool = false

    var body: some View {
        Group {
            if secure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboard)
            }
        }
        .font(.system(size: 14))
        .foregroundColor(.appForeground)
        .autocapitalization(.none)
        .disableAutocorrection(true)
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(Color.appCard)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appInput, lineWidth: 1))
        .cornerRadius(10)
    }
}

// MARK: - 流式布局（对应网页 flex-wrap，iOS 16 Layout 协议）
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > maxWidth {
                x = 0
                y += rowH + spacing
                rowH = 0
            }
            rowH = max(rowH, s.height)
            x += s.width + spacing
        }
        return CGSize(width: maxWidth, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > bounds.minX && x + s.width > bounds.maxX {
                x = bounds.minX
                y += rowH + spacing
                rowH = 0
            }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            rowH = max(rowH, s.height)
            x += s.width + spacing
        }
    }
}

// MARK: - 等级徽章（对应网页 LevelBadge）
struct LevelBadgeView: View {
    let level: Int

    var body: some View {
        // 网页 LevelBadge：纯文字 Lv.N，12px 加粗，莫兰迪映射 sky-600 = hsl(195 22% 46%)
        Text("Lv.\(max(1, level))")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(Color(h: 195, s: 22, l: 46))
    }
}

// MARK: - 头衔徽章（对应网页 TitleBadge）
struct TitleBadgeView: View {
    let equippedTitle: String?
    var plain: Bool = false

    private var meta: (label: String, icon: String, desc: String)? {
        guard let key = equippedTitle, !key.isEmpty else { return nil }
        return Levels.titles[key] ?? (key, "🏅", "")
    }

    var body: some View {
        if let m = meta {
            if plain {
                // plain：纯 emoji 图案，text-sm（排行榜等紧凑场景）
                Text(m.icon)
                    .font(.system(size: 14))
            } else {
                // 胶囊：bg-amber-100 hsl(40 14% 93%)、text-amber-700 hsl(36 22% 43%)、
                // ring-1 ring-amber-300/60、px-1.5 py-0.5、text-[10px] font-bold、rounded-full
                Text("\(m.icon) \(m.label)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(h: 36, s: 22, l: 43))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(h: 40, s: 14, l: 93))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color(h: 40, s: 13, l: 86).opacity(0.6), lineWidth: 1))
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - 多折线趋势图（对应网页 recharts LineChart）
struct MultiLineChartView: View {
    let labels: [String]
    let series: [(String, Color, [Int])]

    var body: some View {
        Canvas { ctx, size in
            let count = labels.count
            guard count > 0 else { return }
            let padL: CGFloat = 34, padR: CGFloat = 10, padT: CGFloat = 8, padB: CGFloat = 20
            let innerW = size.width - padL - padR
            let innerH = size.height - padT - padB
            let maxV = max(1, series.flatMap { $0.2 }.max() ?? 1)
            let x: (Int) -> CGFloat = { i in
                count == 1 ? padL + innerW / 2 : padL + innerW * CGFloat(i) / CGFloat(count - 1)
            }
            let y: (Int) -> CGFloat = { v in
                padT + innerH * (1 - CGFloat(v) / CGFloat(maxV))
            }

            // 网格 + Y 轴刻度
            for f in [0.0, 0.5, 1.0] {
                let gy = padT + innerH * f
                var p = Path()
                p.move(to: CGPoint(x: padL, y: gy))
                p.addLine(to: CGPoint(x: size.width - padR, y: gy))
                ctx.stroke(p, with: .color(.appBorder), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                let val = Int(Double(maxV) * (1 - f))
                ctx.draw(Text("\(val)").font(.system(size: 8)).foregroundColor(.appMutedFg),
                         at: CGPoint(x: padL - 6, y: gy), anchor: .trailing)
            }

            // X 轴日期标签（首/中/尾）
            for i in [0, count / 2, count - 1] where i >= 0 && i < count {
                let raw = labels[i]
                let lbl = raw.count >= 10 ? String(raw.suffix(5)) : raw
                ctx.draw(Text(lbl).font(.system(size: 8)).foregroundColor(.appMutedFg),
                         at: CGPoint(x: x(i), y: size.height - 8), anchor: .center)
            }

            // 折线
            for (_, color, values) in series {
                var p = Path()
                var started = false
                for i in 0..<count {
                    guard values.indices.contains(i) else { continue }
                    let pt = CGPoint(x: x(i), y: y(values[i]))
                    if started { p.addLine(to: pt) } else { p.move(to: pt); started = true }
                }
                ctx.stroke(p, with: .color(color), lineWidth: 1.5)
            }
        }
    }
}

// MARK: - 举报弹窗（对应网页 ReportDialog）
struct ReportSheet: View {
    let targetType: String
    let targetId: Int

    @Environment(\.dismiss) private var dismiss
    @State private var reason = ""
    @State private var sending = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("请描述举报原因，管理员会尽快处理。")
                    .font(.system(size: 12))
                    .foregroundColor(.appMutedFg)
                TextField("举报原因（至少 2 个字）…", text: $reason, axis: .vertical)
                    .font(.system(size: 14))
                    .lineLimit(3...6)
                    .padding(10)
                    .background(Color.appInput)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onChange(of: reason) { v in if v.count > 500 { reason = String(v.prefix(500)) } }
                Button {
                    Task { await submit() }
                } label: {
                    Text(sending ? "提交中…" : "提交举报")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appPrimaryFg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.appPrimary)
                        .clipShape(Capsule())
                }
                .disabled(reason.trimmingCharacters(in: .whitespaces).count < 2 || sending)
                Spacer()
            }
            .padding(20)
            .background(Color.appBackground)
            .navigationTitle("举报")
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

    private func submit() async {
        sending = true
        defer { sending = false }
        do {
            _ = try await MashanglingAPI.shared.report.create(
                targetType: targetType, targetId: targetId,
                reason: reason.trimmingCharacters(in: .whitespaces)
            )
            ToastCenter.shared.success("举报已提交，感谢反馈")
            dismiss()
        } catch {
            ToastCenter.shared.error(error.localizedDescription)
        }
    }
}

// MARK: - 系统分享面板封装
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - SwiftUI 视图渲染为图片（分享卡片导出，iOS 16+）
enum ViewSnapshot {
    @MainActor
    static func image<V: View>(of view: V, size: CGSize, scale: CGFloat = 2) -> UIImage? {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = scale
        return renderer.uiImage
    }
}
