import XCTest
import SwiftUI
@testable import Mashangling

/// 渲染诊断：在 CI 模拟器里真实渲染 ShareCardCanvas，输出 PNG 附件 + 像素断言。
/// 目的：定位「卡片贴纸在 App 里不显示」——用线上真实贴纸数据（22小维万圣节）渲染。
final class ShareCardRenderTests: XCTestCase {

    private func loadStickerDataURL() throws -> String {
        let url = Bundle(for: type(of: self)).url(forResource: "sticker_real", withExtension: "png")
        guard let url else { throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "sticker_real.png missing"]) }
        let data = try Data(contentsOf: url)
        return "data:image/png;base64," + data.base64EncodedString()
    }

    @MainActor
    private func render(_ theme: CardConfig?, name: String) throws -> UIImage {
        let view = ShareCardCanvas(
            title: "示例橱窗标题",
            cover: nil,
            platformLabel: "外部无料",
            authorName: "创作者",
            tags: ["纸制品", "同人"],
            theme: theme
        )
        let renderer = ImageRenderer(content: view.frame(width: 720, height: 960))
        renderer.scale = 1
        renderer.isOpaque = true
        guard let img = renderer.uiImage, let png = img.pngData() else {
            XCTFail("ImageRenderer 输出为空")
            return UIImage()
        }
        let att = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        att.lifetime = .keepAlways
        att.name = name
        add(att)
        return img
    }

    /// 采样某点 RGBA
    private func pixel(_ img: UIImage, x: Int, y: Int) -> (Int, Int, Int, Int)? {
        guard let cg = img.cgImage else { return nil }
        let w = cg.width, h = cg.height
        guard x >= 0, y >= 0, x < w, y < h else { return nil }
        guard let data = cg.dataProvider?.data else { return nil }
        guard let ptr = CFDataGetBytePtr(data) else { return nil }
        let bpp = cg.bitsPerPixel / 8
        let bpr = cg.bytesPerRow
        let off = y * bpr + x * bpp
        // ImageRenderer 输出通常是 RGBA 或 BGRA 预乘；只需相对比较
        return (Int(ptr[off]), Int(ptr[off + 1]), Int(ptr[off + 2]), bpp > 3 ? Int(ptr[off + 3]) : 255)
    }

    @MainActor
    func testStickerRendersOnCanvas() throws {
        let dataURL = try loadStickerDataURL()

        // 无贴纸主题
        let plain = CardConfig(palette: "blue", gradient: false, stickers: [])
        // 带真实贴纸（线上 22小维万圣节 的坐标/缩放）
        var themed = CardConfig(palette: "blue", gradient: false, stickers: [])
        themed.stickers = [CardConfig.CardSticker(url: dataURL,
                                                  x: 0.4857657657657656,
                                                  y: 0.6222980605791867,
                                                  scale: 0.52)]

        let imgPlain = try render(plain, name: "canvas-no-sticker")
        let imgSticker = try render(themed, name: "canvas-with-sticker")

        // 贴纸中心附近（设计坐标 x=0.62W, y=0.75H 处必然被贴纸覆盖）
        let px = Int(720 * 0.62), py = Int(960 * 0.75)
        let a = pixel(imgPlain, x: px, y: py)
        let b = pixel(imgSticker, x: px, y: py)
        XCTAssertNotNil(a); XCTAssertNotNil(b)
        if let a, let b {
            let diff = abs(a.0 - b.0) + abs(a.1 - b.1) + abs(a.2 - b.2)
            XCTAssertGreaterThan(diff, 30,
                "贴纸区域像素与无贴纸版本几乎相同（diff=\(diff)），贴纸没有渲染出来。a=\(a) b=\(b)")
        }
    }
}
