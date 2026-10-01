import SwiftUI
import PhotosUI
import UIKit

// MARK: - 通用视图组件

// MARK: 图片视图（支持 dataURL 与远程/相对 URL，与网页版一致）
struct AppImage: View {
    let path: String?
    var contentMode: ContentMode = .fill

    @State private var image: UIImage? = nil

    /// 进程内内存缓存（配合 CacheManager 的磁盘缓存）
    private static let memCache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 200
        return c
    }()

    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Color.appSecondary
            }
        }
        .task(id: path) { await load() }
    }

    @MainActor
    private func load() async {
        guard let p = path, !p.isEmpty else { image = nil; return }
        // dataURL（本地刚上传的图）
        if SiteConfig.isDataURL(p) {
            if let data = SiteConfig.dataFromDataURL(p) {
                image = UIImage(data: data)
            }
            return
        }
        guard let url = SiteConfig.absoluteURL(p) else { image = nil; return }
        let key = url.absoluteString as NSString
        // 1) 内存缓存
        if let cached = Self.memCache.object(forKey: key) {
            image = cached
            return
        }
        // 2) 磁盘缓存
        if let disk = await CacheManager.shared.loadImage(key: url.absoluteString) {
            Self.memCache.setObject(disk, forKey: key)
            image = disk
            return
        }
        // 3) 网络下载
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard !Task.isCancelled, let img = UIImage(data: data) else { return }
            Self.memCache.setObject(img, forKey: key)
            await CacheManager.shared.cacheImage(img, key: url.absoluteString)
            image = img
        } catch {
            // 加载失败保持占位色
        }
    }
}

// MARK: 头像（圆形，空时显示首字符）
struct AvatarView: View {
    let path: String?
    var name: String = ""
    var size: CGFloat = 36

    var body: some View {
        if let p = path, !p.isEmpty {
            AppImage(path: p)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.appSecondary)
                .frame(width: size, height: size)
                .overlay(
                    Text(String(name.prefix(1)))
                        .font(.system(size: size * 0.42, weight: .medium))
                        .foregroundColor(.appMutedFg)
                )
        }
    }
}

// MARK: 胶囊选择按钮（对应网页 rounded-full pill）
struct PillButton: View {
    let title: String
    let selected: Bool
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: selected ? .semibold : .regular))
                .foregroundColor(selected ? .appPrimaryFg : .appForeground)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(selected ? Color.appPrimary : Color.appSecondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: 小徽章标签
struct MiniBadge: View {
    let text: String
    var fg: Color = .appMutedFg
    var bg: Color = .appSecondary

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(fg)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(bg)
            .cornerRadius(6)
    }
}

// MARK: 卡片容器（对应网页 rounded-xl border bg-card；盐系 rounded-xl=4px）
struct SectionCard<Content: View>: View {
    var padding: CGFloat = 14
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(Color.appCard)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.appBorder, lineWidth: 0.5)
            )
    }
}

// MARK: - Toast 轻提示（对应网页 sonner toast）
@MainActor
class ToastCenter: ObservableObject {
    static let shared = ToastCenter()
    @Published var message: String? = nil
    @Published var isError = false
    private var workItem: DispatchWorkItem?

    func show(_ msg: String, error: Bool = false) {
        message = msg
        isError = error
        workItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.message = nil }
        }
        workItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2, execute: item)
    }

    func success(_ msg: String) { show(msg) }
    func error(_ msg: String) { show(msg, error: true) }
    func info(_ msg: String) { show(msg) }

    static func success(_ msg: String) { shared.show(msg) }
    static func error(_ msg: String) { shared.show(msg, error: true) }
    static func info(_ msg: String) { shared.show(msg) }
}

struct ToastOverlay: View {
    @StateObject private var center = ToastCenter.shared

    var body: some View {
        if let msg = center.message {
            VStack {
                Spacer()
                Text(msg)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background((center.isError ? Color.appDestructive : Color.black.opacity(0.78)))
                    .cornerRadius(20)
                    .padding(.bottom, 90)
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .animation(.easeInOut(duration: 0.2), value: center.message)
            .allowsHitTesting(false)
        }
    }
}

// MARK: - 图片选择器（iOS 16 兼容，PHPickerViewController）
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { image, _ in
                DispatchQueue.main.async {
                    if let uiImage = image as? UIImage {
                        self.parent.image = uiImage
                    }
                }
            }
        }
    }
}

// MARK: 空状态视图
struct EmptyStateView: View {
    let icon: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundColor(.appMutedFg)
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.appForeground)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.appMutedFg)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: 加载视图
struct LoadingView: View {
    var body: some View {
        ProgressView()
            .frame(maxWidth: .infinity, minHeight: 200)
            .tint(.appPrimary)
    }
}

// MARK: - 相对时间（对应网页的 x分钟前）
extension Date {
    func relativeText() -> String {
        let diff = Date().timeIntervalSince(self)
        if diff < 60 { return "刚刚" }
        if diff < 3600 { return "\(Int(diff / 60)) 分钟前" }
        if diff < 86400 { return "\(Int(diff / 3600)) 小时前" }
        if diff < 86400 * 7 { return "\(Int(diff / 86400)) 天前" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M/d HH:mm"
        return f.string(from: self)
    }
}

// MARK: - 全局网页顶栏（复刻 Header.tsx 移动端：左「码上领」，右裸搜索图标 + 头像菜单）
// 用在首页/广场等顶级页面：.webHeader()
struct WebHeaderModifier: ViewModifier {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var unreadManager = UnreadManager.shared
    @State private var mobileSearch = false
    @State private var searchInput = ""
    @State private var pushSearch = false
    @State private var showAvatarMenu = false

    func body(content: Content) -> some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                if mobileSearch { searchBar }
                content
            }
            if showAvatarMenu {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture { showAvatarMenu = false }
                AvatarMenuPanel(close: { showAvatarMenu = false })
                    .padding(.top, 44)
                    .padding(.trailing, 8)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topTrailing)))
                    .zIndex(1)
            }
        }
        .animation(.easeOut(duration: 0.15), value: showAvatarMenu)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Text("码上领")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.appForeground)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 6) {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { mobileSearch.toggle() }
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 20))
                            .foregroundColor(.appMutedFg)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if let me = authManager.currentUser {
                        Button { showAvatarMenu.toggle() } label: {
                            AvatarView(path: me.avatar, name: me.name ?? "U", size: 36)
                                .overlay(alignment: .topTrailing) {
                                    if unreadManager.totalUnread > 0 {
                                        Text(unreadManager.totalUnread > 99 ? "99+" : "\(unreadManager.totalUnread)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.appPrimaryFg)
                                            .padding(.horizontal, 4)
                                            .frame(height: 16)
                                            .background(Color.appPrimary)
                                            .cornerRadius(8)
                                            .overlay(Capsule().stroke(Color.appBackground, lineWidth: 2))
                                            .offset(x: 6, y: -6)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    } else {
                        NavigationLink(destination: LoginView()) {
                            HStack(spacing: 4) {
                                Image(systemName: "person").font(.system(size: 14))
                                Text("登录 / 注册").font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(.appPrimaryFg)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Color.appPrimary)
                            .cornerRadius(18)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationDestination(isPresented: $pushSearch) {
            SearchView(initialQuery: searchInput)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 0) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(.appMutedFg)
                .padding(.leading, 14)
            TextField("搜索无料码 / 发布人 / 关键词…", text: $searchInput)
                .font(.system(size: 16))
                .autocapitalization(.none)
                .padding(.leading, 8)
                .onSubmit {
                    let q = searchInput.trimmingCharacters(in: .whitespaces)
                    guard !q.isEmpty else { return }
                    mobileSearch = false
                    pushSearch = true
                }
        }
        .frame(height: 40)
        .background(Color.appCard)
        .overlay(Capsule().stroke(Color.appInput, lineWidth: 0.5))
        .clipShape(Capsule())
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Color.appBackground)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.appBorder.opacity(0.6)).frame(height: 0.5)
        }
    }
}

extension View {
    func webHeader() -> some View { modifier(WebHeaderModifier()) }
}
