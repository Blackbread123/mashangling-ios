import XCTest
import SwiftUI
@testable import Mashangling

/// 渲染诊断：在 CI 模拟器里真实渲染 ShareCardCanvas，逐级定位贴纸不显示的原因。
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

    /// 采样某点 RGB（用于相对比较）
    private func pixel(_ img: UIImage, x: Int, y: Int) -> (Int, Int, Int)? {
        guard let cg = img.cgImage, x >= 0, y >= 0, x < cg.width, y < cg.height,
              let data = cg.dataProvider?.data, let ptr = CFDataGetBytePtr(data) else { return nil }
        let bpp = cg.bitsPerPixel / 8
        let off = y * cg.bytesPerRow + x * bpp
        return (Int(ptr[off]), Int(ptr[off + 1]), Int(ptr[off + 2]))
    }

    private func diffAt(_ a: UIImage, _ b: UIImage, x: Int, y: Int) -> Int {
        guard let pa = pixel(a, x: x, y: y), let pb = pixel(b, x: x, y: y) else { return -1 }
        return abs(pa.0 - pb.0) + abs(pa.1 - pb.1) + abs(pa.2 - pb.2)
    }

    // 第 1 级：解码管线（isDataURL / dataFromDataURL / UIImage(data:)）
    func testDecodePipeline() throws {
        let dataURL = try loadStickerDataURL()
        XCTAssertTrue(SiteConfig.isDataURL(dataURL), "isDataURL 判定失败")
        let data = SiteConfig.dataFromDataURL(dataURL)
        XCTAssertNotNil(data, "dataFromDataURL 返回 nil")
        XCTAssertGreaterThan(data?.count ?? 0, 700_000, "解码长度不对")
        let img = data.flatMap { UIImage(data: $0) }
        XCTAssertNotNil(img, "UIImage(data:) 解码失败")
        XCTAssertEqual(img?.size.width ?? 0, 1284, accuracy: 1)
        XCTAssertEqual(img?.size.height ?? 0, 1152, accuracy: 1)
    }

    // 第 2 级：裸 Image(uiImage:) 在 ImageRenderer 下能否画出来
    @MainActor
    func testBareImageView() throws {
        let dataURL = try loadStickerDataURL()
        let ui = UIImage(data: SiteConfig.dataFromDataURL(dataURL)!)!
        let withImg = render(
            ZStack(alignment: .topLeading) {
                Color.blue
                Image(uiImage: ui)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 374)
                    .offset(x: 350, y: 597)
            }, name: "bare-image")
        let without = render(ZStack { Color.blue }, name: "bare-none")
        XCTAssertGreaterThan(diffAt(withImg, without, x: 500, y: 700), 30,
                             "裸 Image(uiImage:) 都没能渲染出来")
    }

    // 第 3 级：贴纸放在画布左上角（0,0 大幅），排除坐标/裁切问题
    @MainActor
    func testCanvasStickerAtOrigin() throws {
        let dataURL = try loadStickerDataURL()
        var themed = CardConfig(palette: "blue", gradient: false, stickers: [])
        themed.stickers = [CardConfig.CardSticker(url: dataURL, x: 0, y: 0, scale: 0.5)]
        let plain = CardConfig(palette: "blue", gradient: false, stickers: [])

        func canvas(_ t: CardConfig?) -> some View {
            ShareCardCanvas(title: "示例橱窗标题", cover: nil, platformLabel: "外部无料",
                            authorName: "创作者", tags: ["纸制品", "同人"], theme: t)
        }
        let a = render(canvas(themed), name: "canvas-sticker-origin")
        let b = render(canvas(plain), name: "canvas-plain-2")
        XCTAssertGreaterThan(diffAt(a, b, x: 180, y: 180), 30,
                             "贴纸在 (0,0) 也没渲染出来 → 问题在画布贴纸层本身")
    }

    // 第 4 级：线上真实坐标（22小维万圣节）
    @MainActor
    func testStickerRealPosition() throws {
        let dataURL = try loadStickerDataURL()
        var themed = CardConfig(palette: "blue", gradient: false, stickers: [])
        themed.stickers = [CardConfig.CardSticker(url: dataURL,
                                                  x: 0.4857657657657656,
                                                  y: 0.6222980605791867,
                                                  scale: 0.52)]
        let plain = CardConfig(palette: "blue", gradient: false, stickers: [])
        func canvas(_ t: CardConfig?) -> some View {
            ShareCardCanvas(title: "示例橱窗标题", cover: nil, platformLabel: "外部无料",
                            authorName: "创作者", tags: ["纸制品", "同人"], theme: t)
        }
        let a = render(canvas(themed), name: "canvas-sticker-realpos")
        let b = render(canvas(plain), name: "canvas-plain-3")
        XCTAssertGreaterThan(diffAt(a, b, x: 446, y: 720), 30,
                             "真实坐标下贴纸没渲染出来")
    }
}
