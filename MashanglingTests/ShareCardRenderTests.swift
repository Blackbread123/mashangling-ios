import XCTest
import SwiftUI
@testable import Mashangling

/// 渲染回归测试：在 CI 模拟器里真实渲染 ShareCardCanvas，验证贴纸出现在正确位置。
/// 曾修复的 bug：贴纸层 ZStack 的 .frame 没写 alignment 导致整体居中、offset 错位出画布。
final class ShareCardRenderTests: XCTestCase {

    private func loadStickerDataURL() throws -> String {
        let url = Bundle(for: type(of: self)).url(forResource: "sticker_real", withExtension: "png")
        guard let url else { throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "sticker_real.png missing"]) }
        let data = try Data(contentsOf: url)
        return "data:image/png;base64," + data.base64EncodedString()
    }

    @MainActor
    private func render<V: View>(_ view: V, name: String, w: CGFloat = 720, h: CGFloat = 960) -> UIImage {
        let renderer = ImageRenderer(content: view.frame(width: w, height: h))
        renderer.scale = 1
        renderer.isOpaque = true
        guard let img = renderer.uiImage, let png = img.pngData() else {
            XCTFail("ImageRenderer 输出为空：\(name)")
            return UIImage()
        }
        let att = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        att.lifetime = .keepAlways
        att.name = name
        add(att)
        return img
    }

    private func rgb(_ img: UIImage, x: Int, y: Int) -> (Int, Int, Int)? {
        guard let cg = img.cgImage, x >= 0, y >= 0, x < cg.width, y < cg.height,
              let data = cg.dataProvider?.data, let ptr = CFDataGetBytePtr(data) else { return nil }
        let bpp = cg.bitsPerPixel / 8
        let off = y * cg.bytesPerRow + x * bpp
        return (Int(ptr[off]), Int(ptr[off + 1]), Int(ptr[off + 2]))
    }

    /// 区域内两图差异像素数
    private func diffCount(_ a: UIImage, _ b: UIImage, in rect: CGRect) -> Int {
        var n = 0
        let x0 = Int(rect.minX), y0 = Int(rect.minY), x1 = Int(rect.maxX), y1 = Int(rect.maxY)
        var y = y0
        while y < y1 {
            var x = x0
            while x < x1 {
                if let pa = rgb(a, x: x, y: y), let pb = rgb(b, x: x, y: y),
                   abs(pa.0 - pb.0) + abs(pa.1 - pb.1) + abs(pa.2 - pb.2) > 30 { n += 1 }
                x += 4
            }
            y += 4
        }
        return n
    }

    private func canvas(_ t: CardConfig?) -> some View {
        ShareCardCanvas(title: "示例橱窗标题", cover: nil, platformLabel: "外部无料",
                        authorName: "创作者", tags: ["纸制品", "同人"], theme: t)
    }

    // 解码管线
    func testDecodePipeline() throws {
        let dataURL = try loadStickerDataURL()
        XCTAssertTrue(SiteConfig.isDataURL(dataURL))
        let data = SiteConfig.dataFromDataURL(dataURL)
        XCTAssertNotNil(data)
        let img = data.flatMap { UIImage(data: $0) }
        XCTAssertNotNil(img)
        XCTAssertEqual(img?.size.width ?? 0, 1284, accuracy: 1)
        XCTAssertEqual(img?.size.height ?? 0, 1152, accuracy: 1)
    }

    // 贴纸在画布左上角：应覆盖 (0,0)-(360,323)
    @MainActor
    func testCanvasStickerAtOrigin() throws {
        let dataURL = try loadStickerDataURL()
        var themed = CardConfig(palette: "blue", gradient: false, stickers: [])
        themed.stickers = [CardConfig.CardSticker(url: dataURL, x: 0, y: 0, scale: 0.5)]
        let plain = CardConfig(palette: "blue", gradient: false, stickers: [])
        let a = render(canvas(themed), name: "canvas-sticker-origin")
        let b = render(canvas(plain), name: "canvas-plain-2")
        // 贴纸主体内容区（图片中心一带必有内容）
        XCTAssertGreaterThan(diffCount(a, b, in: CGRect(x: 40, y: 40, width: 280, height: 240)), 500,
                             "贴纸在 (0,0) 没出现在左上区域")
        // 画布中心（360,480）附近不应有贴纸（防居中回归）
        XCTAssertLessThan(diffCount(a, b, in: CGRect(x: 300, y: 430, width: 120, height: 100)), 50,
                          "贴纸被错误居中到画布中央")
    }

    // 线上真实坐标（22小维万圣节）：贴纸应覆盖 (350,597)-(724,933)
    @MainActor
    func testStickerRealPosition() throws {
        let dataURL = try loadStickerDataURL()
        var themed = CardConfig(palette: "blue", gradient: false, stickers: [])
        themed.stickers = [CardConfig.CardSticker(url: dataURL,
                                                  x: 0.4857657657657656,
                                                  y: 0.6222980605791867,
                                                  scale: 0.52)]
        let plain = CardConfig(palette: "blue", gradient: false, stickers: [])
        let a = render(canvas(themed), name: "canvas-sticker-realpos")
        let b = render(canvas(plain), name: "canvas-plain-3")
        XCTAssertGreaterThan(diffCount(a, b, in: CGRect(x: 360, y: 610, width: 340, height: 280)), 500,
                             "真实坐标下贴纸没渲染在预期区域")
    }
}
