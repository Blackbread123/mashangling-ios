import UIKit

// MARK: - 图片压缩为 base64 dataURL（与网页版 fileToCoverDataUrl 一致）
// 网页版：最长边 900px，webp 质量从 0.82 递减至 base64 ≤ 550KB，webp 不支持时回退 JPEG 0.8。
// iOS 原生不支持 webp 编码，直接走网页版的 JPEG 回退路径。
enum ImageCodec {

    /// 橱窗封面 / 头像 / 返图 / 凭证图：最长边 900px，JPEG 质量递减至 ≤550KB
    static func coverDataURL(from image: UIImage) -> String? {
        let resized = resize(image, maxSide: 900)
        var quality: CGFloat = 0.82
        var data = resized.jpegData(compressionQuality: quality)
        while let d = data, d.count * 4 / 3 > 550_000, quality > 0.35 {
            quality -= 0.08
            data = resized.jpegData(compressionQuality: quality)
        }
        guard let final = data else { return nil }
        return "data:image/jpeg;base64," + final.base64EncodedString()
    }

    /// PNG 贴纸 / 母鸡 / 好友徽章：保留透明通道，最长边 512px，PNG 编码
    static func pngDataURL(from image: UIImage, maxSide: CGFloat = 512) -> String? {
        let resized = resize(image, maxSide: maxSide)
        guard let data = resized.pngData() else { return nil }
        return "data:image/png;base64," + data.base64EncodedString()
    }

    /// 等比缩放到最长边不超过 maxSide
    static func resize(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let size = image.size
        let maxDim = max(size.width, size.height)
        guard maxDim > maxSide else { return image }
        let scale = maxSide / maxDim
        let newSize = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
