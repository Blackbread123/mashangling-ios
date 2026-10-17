import SwiftUI

// MARK: - 识图搜索结果页（对应网页 2026-10-17 ImageSearchPage.tsx）
// 拍一张实物/封面照片 → 服务端向量相似度匹配 → 复用橱窗卡片，左上角叠加相似度角标
struct ImageSearchResultView: View {
    /// 已压缩的 data URL（长边 ≤1200px JPEG 0.85）
    @State private var imageDataURL: String

    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var items: [Showcase] = []
    @State private var indexed = 0
    @State private var searching = false
    @State private var searched = false
    @State private var error: String? = nil
    @State private var showPicker = false
    @State private var showLogin = false
    @State private var openDetailId: Int? = nil

    init(imageDataURL: String) {
        _imageDataURL = State(initialValue: imageDataURL)
    }

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // 顶部：搜索图 + 换一张 + 提示（网页 mb-6 flex flex-col items-center gap-3）
                VStack(spacing: 12) {
                    if let img = decodedImage {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 192) // max-h-48
                            .cornerRadius(4)       // rounded-xl
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder.opacity(0.6), lineWidth: 1))
                    }
                    Button { showPicker = true } label: {
                        Text("换一张")
                            .font(.system(size: 14))
                            .foregroundColor(.appForeground)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .overlay(Capsule().stroke(Color.appBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    Text("拍一张实物或封面图，按图片相似度帮你匹配橱窗")
                        .font(.system(size: 14))
                        .foregroundColor(.appMutedFg)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 24)

                if searching {
                    Text("正在识别图片…")
                        .font(.system(size: 14))
                        .foregroundColor(.appMutedFg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 64)
                } else if let err = error {
                    Text(err)
                        .font(.system(size: 14))
                        .foregroundColor(.fixRed500)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 64)
                } else if searched {
                    Text("按图片相似度匹配到 \(items.count) 个橱窗（已索引 \(indexed) 个封面）")
                        .font(.system(size: 14))
                        .foregroundColor(.appMutedFg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 16)
                    if items.isEmpty {
                        Text("没有找到相似的橱窗，换个角度或更清晰的照片试试")
                            .font(.system(size: 14))
                            .foregroundColor(.appMutedFg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                    } else {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(items) { item in
                                ZStack(alignment: .topLeading) {
                                    ShowcaseCardView(item: item)
                                        .onTapGesture { openDetailId = item.id }
                                    if let sim = item.similarity {
                                        Text("\(sim)%")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8).padding(.vertical, 2)
                                            .background(Color.black.opacity(0.55))
                                            .clipShape(Capsule())
                                            .padding(8)
                                            .allowsHitTesting(false)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("识图搜索")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPicker) {
            ImagePicker(image: Binding(
                get: { nil },
                set: { if let img = $0 { replaceImage(img) } }
            ))
        }
        .sheet(isPresented: $showLogin) { LoginView() }
        .navigationDestination(isPresented: Binding(
            get: { openDetailId != nil },
            set: { if !$0 { openDetailId = nil } }
        )) {
            if let id = openDetailId {
                ShowcaseDetailView(showcaseId: id)
            }
        }
        .task { await runSearch() }
    }

    private var decodedImage: UIImage? {
        guard let data = SiteConfig.dataFromDataURL(imageDataURL) else { return nil }
        return UIImage(data: data)
    }

    private func replaceImage(_ img: UIImage) {
        guard let url = ImageCodec.imageSearchDataURL(from: img) else { return }
        imageDataURL = url
        Task { await runSearch() }
    }

    private func runSearch() async {
        guard authManager.isAuthenticated else {
            // 网页：未登录引导去登录
            showLogin = true
            return
        }
        searching = true
        error = nil
        defer { searching = false }
        do {
            let r = try await MashanglingAPI.shared.imageSearch.search(imageDataURL: imageDataURL)
            items = r.items
            indexed = r.indexed ?? 0
            searched = true
        } catch {
            self.error = error.localizedDescription
        }
    }
}
