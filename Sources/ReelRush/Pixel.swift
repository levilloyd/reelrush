import SpriteKit
import AppKit

// MARK: - Color

struct PColor: Equatable {
    var r: UInt8, g: UInt8, b: UInt8, a: UInt8

    init(_ hex: UInt32, _ alpha: UInt8 = 255) {
        r = UInt8((hex >> 16) & 0xFF)
        g = UInt8((hex >> 8) & 0xFF)
        b = UInt8(hex & 0xFF)
        a = alpha
    }

    init(r: Int, g: Int, b: Int, a: Int = 255) {
        self.r = UInt8(max(0, min(255, r)))
        self.g = UInt8(max(0, min(255, g)))
        self.b = UInt8(max(0, min(255, b)))
        self.a = UInt8(max(0, min(255, a)))
    }

    static let clear = PColor(0, 0)
    static let white = PColor(0xFFFFFF)
    static let black = PColor(0x000000)
    static let ink = PColor(0x4A2A12)
    static let inkShadow = PColor(0xE0B478)
    static let gold = PColor(0xFFD23A)
    static let shadow = PColor(0x000000, 150)

    /// f > 0 lightens toward white, f < 0 darkens toward black.
    func shade(_ f: Double) -> PColor {
        func ch(_ v: UInt8) -> Int {
            let d = Double(v)
            return Int(f >= 0 ? d + (255 - d) * f : d * (1 + f))
        }
        return PColor(r: ch(r), g: ch(g), b: ch(b), a: Int(a))
    }

    func mix(_ o: PColor, _ t: Double) -> PColor {
        let t = max(0, min(1, t))
        func l(_ x: UInt8, _ y: UInt8) -> Int { Int(Double(x) + (Double(y) - Double(x)) * t) }
        return PColor(r: l(r, o.r), g: l(g, o.g), b: l(b, o.b), a: Int(a))
    }

    func alpha(_ v: UInt8) -> PColor { var c = self; c.a = v; return c }

    var hex: UInt32 { UInt32(r) << 16 | UInt32(g) << 8 | UInt32(b) }
    var ns: NSColor { NSColor(srgbRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255) }
    var key: String { String(format: "%06X%02X", hex, a) }
}

/// Deterministic hash noise in [0, 1).
@inline(__always) func hrand(_ x: Int, _ y: Int, _ s: Int = 0) -> Double {
    var h = UInt64(bitPattern: Int64(x &* 374761393 &+ y &* 668265263 &+ s &* 1442695041))
    h = (h ^ (h >> 13)) &* 1274126177
    h = (h ^ (h >> 16)) &* 2246822519
    h ^= h >> 15
    return Double(h & 0xFFFFFF) / Double(0x1000000)
}

// MARK: - Pixel buffer (y = 0 is the bottom row, matching SpriteKit)

final class PixelBuffer {
    let w: Int, h: Int
    private(set) var px: [PColor]

    init(_ w: Int, _ h: Int, fill: PColor = .clear) {
        self.w = max(1, w)
        self.h = max(1, h)
        px = Array(repeating: fill, count: self.w * self.h)
    }

    @inline(__always) func inside(_ x: Int, _ y: Int) -> Bool { x >= 0 && y >= 0 && x < w && y < h }

    subscript(x: Int, y: Int) -> PColor {
        get { inside(x, y) ? px[y * w + x] : .clear }
        set { if inside(x, y) { px[y * w + x] = newValue } }
    }

    /// Writes a pixel. Opaque/clear colors replace; translucent colors blend.
    @inline(__always) func set(_ x: Int, _ y: Int, _ c: PColor) {
        guard inside(x, y) else { return }
        if c.a == 255 || c.a == 0 { px[y * w + x] = c; return }
        let d = px[y * w + x]
        if d.a == 0 { px[y * w + x] = c; return }
        let t = Double(c.a) / 255
        var m = d.mix(c, t)
        m.a = UInt8(min(255, Int(d.a) + Int(Double(255 - Int(d.a)) * t)))
        px[y * w + x] = m
    }

    func rect(_ x: Int, _ y: Int, _ rw: Int, _ rh: Int, _ c: PColor) {
        guard rw > 0, rh > 0 else { return }
        for yy in max(0, y)..<min(h, y + rh) {
            for xx in max(0, x)..<min(w, x + rw) { set(xx, yy, c) }
        }
    }

    func ellipse(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, _ c: PColor) {
        guard rx > 0, ry > 0 else { return }
        let y0 = Int(floor(cy - ry)), y1 = Int(ceil(cy + ry))
        let x0 = Int(floor(cx - rx)), x1 = Int(ceil(cx + rx))
        for y in y0...y1 {
            for x in x0...x1 {
                let dx = (Double(x) + 0.5 - cx) / rx, dy = (Double(y) + 0.5 - cy) / ry
                if dx * dx + dy * dy <= 1 { set(x, y, c) }
            }
        }
    }

    func polygon(_ pts: [(Double, Double)], _ c: PColor) {
        guard pts.count >= 3 else { return }
        let minY = Int(floor(pts.map { $0.1 }.min()!)), maxY = Int(ceil(pts.map { $0.1 }.max()!))
        for y in minY...maxY {
            let sy = Double(y) + 0.5
            var xs: [Double] = []
            for i in 0..<pts.count {
                let a = pts[i], b = pts[(i + 1) % pts.count]
                if (a.1 <= sy && b.1 > sy) || (b.1 <= sy && a.1 > sy) {
                    xs.append(a.0 + (sy - a.1) / (b.1 - a.1) * (b.0 - a.0))
                }
            }
            xs.sort()
            var i = 0
            while i + 1 < xs.count {
                let xa = Int((xs[i] - 0.5).rounded(.up)), xb = Int((xs[i + 1] - 0.5).rounded(.down))
                if xa <= xb { for x in xa...xb { set(x, y, c) } }
                i += 2
            }
        }
    }

    func triangle(_ a: (Double, Double), _ b: (Double, Double), _ c: (Double, Double), _ col: PColor) {
        polygon([a, b, c], col)
    }

    func line(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, _ c: PColor, thick: Int = 1) {
        var x = x0, y = y0
        let dx = abs(x1 - x0), sx = x0 < x1 ? 1 : -1
        let dy = -abs(y1 - y0), sy = y0 < y1 ? 1 : -1
        var err = dx + dy
        while true {
            if thick <= 1 { set(x, y, c) } else { rect(x - thick / 2, y - thick / 2, thick, thick, c) }
            if x == x1 && y == y1 { break }
            let e2 = 2 * err
            if e2 >= dy { err += dy; x += sx }
            if e2 <= dx { err += dx; y += sy }
        }
    }

    /// Adds a 1px outline around all non-transparent pixels.
    func outline(_ c: PColor) {
        let src = px
        for y in 0..<h {
            for x in 0..<w where src[y * w + x].a == 0 {
                var touch = false
                for (nx, ny) in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)] where inside(nx, ny) {
                    if src[ny * w + nx].a > 0 { touch = true; break }
                }
                if touch { px[y * w + x] = c }
            }
        }
    }

    func replaceOpaque(_ c: PColor) {
        for i in 0..<px.count where px[i].a > 0 { px[i] = c }
    }

    func flippedH() -> PixelBuffer {
        let b = PixelBuffer(w, h)
        for y in 0..<h { for x in 0..<w { b.px[y * w + (w - 1 - x)] = px[y * w + x] } }
        return b
    }

    func flippedV() -> PixelBuffer {
        let b = PixelBuffer(w, h)
        for y in 0..<h { for x in 0..<w { b.px[(h - 1 - y) * w + x] = px[y * w + x] } }
        return b
    }

    func crop(_ x0: Int, _ y0: Int, _ cw: Int, _ ch: Int) -> PixelBuffer {
        let b = PixelBuffer(cw, ch)
        for y in 0..<ch { for x in 0..<cw { b[x, y] = self[x0 + x, y0 + y] } }
        return b
    }

    func blit(_ src: PixelBuffer, _ ox: Int, _ oy: Int) {
        for y in 0..<src.h { for x in 0..<src.w {
            let c = src.px[y * src.w + x]
            if c.a > 0 { set(ox + x, oy + y, c) }
        } }
    }

    func clear() {
        for i in 0..<px.count { px[i] = .clear }
    }

    func cgImage() -> CGImage {
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        for y in 0..<h {
            let row = h - 1 - y
            for x in 0..<w {
                let c = px[y * w + x]
                let i = (row * w + x) * 4
                let a = UInt16(c.a)
                bytes[i] = UInt8(UInt16(c.r) * a / 255)
                bytes[i + 1] = UInt8(UInt16(c.g) * a / 255)
                bytes[i + 2] = UInt8(UInt16(c.b) * a / 255)
                bytes[i + 3] = c.a
            }
        }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
                       space: CGColorSpace(name: CGColorSpace.sRGB)!,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    }

    func texture() -> SKTexture {
        let t = SKTexture(cgImage: cgImage())
        t.filteringMode = .nearest
        return t
    }
}

// MARK: - Texture cache & sprite helpers

enum Tex {
    private static var cache: [String: SKTexture] = [:]

    static func get(_ key: String, _ make: () -> PixelBuffer) -> SKTexture {
        if let t = cache[key] { return t }
        if cache.count > 900 { cache.removeAll() }
        let t = make().texture()
        cache[key] = t
        return t
    }

    static func glow() -> SKTexture {
        if let t = cache["glow"] { return t }
        let size = 64
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let g = CGGradient(colorsSpace: cs, colors: [NSColor.white.cgColor, NSColor(white: 1, alpha: 0).cgColor] as CFArray,
                           locations: [0, 1])!
        let c = CGPoint(x: size / 2, y: size / 2)
        ctx.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: CGFloat(size / 2), options: [])
        let t = SKTexture(cgImage: ctx.makeImage()!)
        cache["glow"] = t
        return t
    }
}

func pixelSprite(_ tex: SKTexture, scale: CGFloat) -> SKSpriteNode {
    let s = SKSpriteNode(texture: tex)
    s.size = CGSize(width: tex.size().width * scale, height: tex.size().height * scale)
    return s
}

extension SKSpriteNode {
    func setPixelTexture(_ tex: SKTexture, scale: CGFloat) {
        texture = tex
        size = CGSize(width: tex.size().width * scale, height: tex.size().height * scale)
    }
}

func colorSprite(_ c: PColor, _ size: CGSize) -> SKSpriteNode {
    SKSpriteNode(color: c.ns, size: size)
}

@inline(__always) func snap(_ v: CGFloat, _ grid: CGFloat) -> CGFloat { (v / grid).rounded() * grid }

// MARK: - Bitmap font (5x7, proportional)

enum TextAlign { case left, center, right }

enum PixelFont {
    struct Glyph { let w: Int; let rows: [[Bool]] }
    static let lineH = 9

    private static let data: [Character: String] = [
        "A": ".###.|#...#|#...#|#####|#...#|#...#|#...#",
        "B": "####.|#...#|#...#|####.|#...#|#...#|####.",
        "C": ".###.|#...#|#....|#....|#....|#...#|.###.",
        "D": "####.|#...#|#...#|#...#|#...#|#...#|####.",
        "E": "#####|#....|#....|####.|#....|#....|#####",
        "F": "#####|#....|#....|####.|#....|#....|#....",
        "G": ".###.|#...#|#....|#.###|#...#|#...#|.####",
        "H": "#...#|#...#|#...#|#####|#...#|#...#|#...#",
        "I": "###|.#.|.#.|.#.|.#.|.#.|###",
        "J": "..###|...#.|...#.|...#.|...#.|#..#.|.##..",
        "K": "#...#|#..#.|#.#..|##...|#.#..|#..#.|#...#",
        "L": "#....|#....|#....|#....|#....|#....|#####",
        "M": "#...#|##.##|#.#.#|#.#.#|#...#|#...#|#...#",
        "N": "#...#|#...#|##..#|#.#.#|#..##|#...#|#...#",
        "O": ".###.|#...#|#...#|#...#|#...#|#...#|.###.",
        "P": "####.|#...#|#...#|####.|#....|#....|#....",
        "Q": ".###.|#...#|#...#|#...#|#.#.#|#..#.|.##.#",
        "R": "####.|#...#|#...#|####.|#.#..|#..#.|#...#",
        "S": ".####|#....|#....|.###.|....#|....#|####.",
        "T": "#####|..#..|..#..|..#..|..#..|..#..|..#..",
        "U": "#...#|#...#|#...#|#...#|#...#|#...#|.###.",
        "V": "#...#|#...#|#...#|#...#|#...#|.#.#.|..#..",
        "W": "#...#|#...#|#...#|#.#.#|#.#.#|#.#.#|.#.#.",
        "X": "#...#|#...#|.#.#.|..#..|.#.#.|#...#|#...#",
        "Y": "#...#|#...#|.#.#.|..#..|..#..|..#..|..#..",
        "Z": "#####|....#|...#.|..#..|.#...|#....|#####",
        "0": ".###.|#...#|#..##|#.#.#|##..#|#...#|.###.",
        "1": ".#.|##.|.#.|.#.|.#.|.#.|###",
        "2": ".###.|#...#|....#|...#.|..#..|.#...|#####",
        "3": "####.|....#|....#|.###.|....#|....#|####.",
        "4": "...#.|..##.|.#.#.|#..#.|#####|...#.|...#.",
        "5": "#####|#....|####.|....#|....#|#...#|.###.",
        "6": "..##.|.#...|#....|####.|#...#|#...#|.###.",
        "7": "#####|....#|...#.|..#..|.#...|.#...|.#...",
        "8": ".###.|#...#|#...#|.###.|#...#|#...#|.###.",
        "9": ".###.|#...#|#...#|.####|....#|...#.|.##..",
        ".": ".|.|.|.|.|.|#",
        ",": "..|..|..|..|..|.#|#.",
        "!": "#|#|#|#|#|.|#",
        "?": ".###.|#...#|....#|...#.|..#..|.....|..#..",
        "'": "#|#|.|.|.|.|.",
        "\"": "#.#|#.#|...|...|...|...|...",
        ":": ".|#|.|.|.|#|.",
        "-": "...|...|...|###|...|...|...",
        "+": ".....|..#..|..#..|#####|..#..|..#..|.....",
        "/": "....#|....#|...#.|..#..|.#...|#....|#....",
        "(": "..#|.#.|#..|#..|#..|.#.|..#",
        ")": "#..|.#.|..#|..#|..#|.#.|#..",
        "%": "##..#|##..#|...#.|..#..|.#...|#..##|#..##",
        "&": ".##..|#..#.|#.#..|.#...|#.#.#|#..#.|.##.#",
        "×": ".....|.....|#...#|.#.#.|..#..|.#.#.|#...#",
        "#": ".#.#.|.#.#.|#####|.#.#.|#####|.#.#.|.#.#.",
        "=": "....|....|####|....|####|....|....",
        "<": "...#|..#.|.#..|#...|.#..|..#.|...#",
        ">": "#...|.#..|..#.|...#|..#.|.#..|#...",
        "_": ".....|.....|.....|.....|.....|.....|#####",
        "~": ".....|.....|.##.#|#..##|.....|.....|.....",
        "≈": ".....|.##.#|#.##.|.....|.##.#|#.##.|.....",
        "*": ".....|#.#.#|.###.|#####|.###.|#.#.#|.....",
        "·": ".|.|.|#|.|.|.",
        "—": ".....|.....|.....|#####|.....|.....|.....",
        "←": ".....|..#..|.#...|#####|.#...|..#..|.....",
        "→": ".....|..#..|...#.|#####|...#.|..#..|.....",
        "↑": "..#..|.###.|#.#.#|..#..|..#..|..#..|..#..",
        "↓": "..#..|..#..|..#..|..#..|#.#.#|.###.|..#..",
        "⚡": "...#|..#.|.#..|####|..#.|.#..|#...",
    ]

    private static var glyphs: [Character: Glyph] = [:]

    static func glyph(_ raw: Character) -> Glyph {
        let ch = Character(String(raw).uppercased().first.map(String.init) ?? " ")
        if let g = glyphs[ch] { return g }
        let g: Glyph
        if let src = data[ch] {
            let rows = src.split(separator: "|").map { $0.map { $0 == "#" } }
            let w = rows.map { $0.count }.max() ?? 1
            let padded = rows.map { $0 + Array(repeating: false, count: w - $0.count) }
            g = Glyph(w: w, rows: padded)
        } else if ch == " " {
            g = Glyph(w: 3, rows: Array(repeating: [false, false, false], count: 7))
        } else {
            g = glyph("?")
        }
        glyphs[ch] = g
        return g
    }

    static func width(_ line: Substring) -> Int {
        guard !line.isEmpty else { return 0 }
        return line.reduce(0) { $0 + glyph($1).w + 1 } - 1
    }

    static func render(_ text: String, color: PColor, shadow: PColor?, align: TextAlign) -> PixelBuffer {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let tw = max(1, lines.map { width($0) }.max() ?? 1)
        let th = lines.count * lineH - 2
        let sh = shadow == nil ? 0 : 1
        let b = PixelBuffer(tw + sh, th + sh)
        for pass in 0..<(sh + 1) {
            let isShadow = sh == 1 && pass == 0
            let col = isShadow ? shadow! : color
            let off = isShadow ? 1 : 0
            for (li, line) in lines.enumerated() {
                let lw = width(line)
                var x: Int
                switch align {
                case .left: x = 0
                case .center: x = (tw - lw) / 2
                case .right: x = tw - lw
                }
                let top = b.h - 1 - li * lineH
                for ch in line {
                    let g = glyph(ch)
                    for (r, row) in g.rows.enumerated() {
                        for (cx, on) in row.enumerated() where on {
                            b.set(x + cx + off, top - r - off, col)
                        }
                    }
                    x += g.w + 1
                }
            }
        }
        return b
    }

    /// Word-wraps text to a maximum pixel width.
    static func wrap(_ text: String, maxWidth: Int) -> String {
        var lines: [String] = []
        var cur = ""
        for word in text.split(separator: " ") {
            let candidate = cur.isEmpty ? String(word) : cur + " " + word
            if width(Substring(candidate)) > maxWidth && !cur.isEmpty {
                lines.append(cur)
                cur = String(word)
            } else {
                cur = candidate
            }
        }
        if !cur.isEmpty { lines.append(cur) }
        return lines.joined(separator: "\n")
    }
}

final class PixelLabel: SKSpriteNode {
    var text: String { didSet { if text != oldValue { redraw() } } }
    var textColor: PColor { didSet { if textColor != oldValue { redraw() } } }
    var shadowColor: PColor? { didSet { redraw() } }
    var pixelScale: CGFloat { didSet { redraw() } }
    let align: TextAlign

    init(_ text: String, scale: CGFloat = 3, color: PColor = .white, shadow: PColor? = .shadow, align: TextAlign = .center) {
        self.text = text
        self.textColor = color
        self.shadowColor = shadow
        self.pixelScale = scale
        self.align = align
        super.init(texture: nil, color: .clear, size: .zero)
        switch align {
        case .left: anchorPoint = CGPoint(x: 0, y: 0.5)
        case .center: anchorPoint = CGPoint(x: 0.5, y: 0.5)
        case .right: anchorPoint = CGPoint(x: 1, y: 0.5)
        }
        redraw()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func redraw() {
        let key = "t|\(text)|\(textColor.key)|\(shadowColor?.key ?? "-")|\(align)"
        let t = text, c = textColor, s = shadowColor, a = align
        setPixelTexture(Tex.get(key) { PixelFont.render(t, color: c, shadow: s, align: a) }, scale: pixelScale)
    }
}

/// Parchment-text convenience.
func inkLabel(_ text: String, scale: CGFloat = 2, color: PColor = .ink, align: TextAlign = .center) -> PixelLabel {
    PixelLabel(text, scale: scale, color: color, shadow: .inkShadow, align: align)
}

// MARK: - Panels (Stardew-style frames)

enum PanelStyle: String { case parchment, dark, slot, slotLit, wood }

func panelBuffer(_ w: Int, _ h: Int, _ style: PanelStyle) -> PixelBuffer {
    let b = PixelBuffer(w, h)
    switch style {
    case .parchment:
        b.rect(1, 0, w - 2, h, PColor(0x3B1E0C))
        b.rect(0, 1, w, h - 2, PColor(0x3B1E0C))
        b.rect(1, 1, w - 2, h - 2, PColor(0xD9792B))
        b.rect(2, h - 2, w - 4, 1, PColor(0xF2A55A))
        b.rect(2, 1, w - 4, 1, PColor(0xA8501C))
        b.rect(3, 3, w - 6, h - 6, PColor(0x7A3E14))
        b.rect(4, 4, w - 8, h - 8, PColor(0xF9DCA8))
        b.rect(4, h - 5, w - 8, 1, PColor(0xFFEBC8))
    case .dark:
        b.rect(1, 0, w - 2, h, PColor(0x0A0E1A, 235))
        b.rect(0, 1, w, h - 2, PColor(0x0A0E1A, 235))
        b.rect(1, 1, w - 2, h - 2, PColor(0x3A4E78, 235))
        b.rect(2, 2, w - 4, h - 4, PColor(0x182240, 225))
        b.rect(2, h - 3, w - 4, 1, PColor(0x26345A, 225))
    case .slot, .slotLit:
        let lit = style == .slotLit
        b.rect(0, 0, w, h, PColor(lit ? 0xC8781A : 0xB07A40))
        b.rect(1, 1, w - 2, h - 2, PColor(lit ? 0xFFE8B0 : 0xEDC58C))
        b.rect(1, h - 2, w - 2, 1, PColor(lit ? 0xF2C878 : 0xD2A468))
        b.rect(1, 1, 1, h - 2, PColor(lit ? 0xF2C878 : 0xD2A468))
    case .wood:
        b.rect(1, 0, w - 2, h, PColor(0x3B1E0C))
        b.rect(0, 1, w, h - 2, PColor(0x3B1E0C))
        b.rect(1, 1, w - 2, h - 2, PColor(0xB8743A))
        for x in stride(from: 4, to: w - 2, by: 6) { b.rect(x, 1, 1, h - 2, PColor(0x8A5226)) }
        b.rect(1, h - 2, w - 2, 1, PColor(0xD89050))
        b.rect(1, 1, 1, h - 2, PColor(0xD89050))
    }
    return b
}

func panelSprite(_ wPt: CGFloat, _ hPt: CGFloat, scale: CGFloat = 3, style: PanelStyle = .parchment) -> SKSpriteNode {
    let w = max(8, Int((wPt / scale).rounded())), h = max(8, Int((hPt / scale).rounded()))
    let tex = Tex.get("panel|\(w)|\(h)|\(style.rawValue)") { panelBuffer(w, h, style) }
    return pixelSprite(tex, scale: scale)
}

// MARK: - Icons

enum Icons {
    static func coin() -> SKTexture {
        Tex.get("icon.coin") {
            let b = PixelBuffer(9, 9)
            b.ellipse(4.5, 4.5, 4, 4, PColor(0xB8861A))
            b.ellipse(4.5, 4.5, 3, 3, PColor(0xF2C230))
            b.rect(4, 3, 1, 3, PColor(0xC8961E))
            b.set(3, 6, PColor(0xFFF0A0))
            b.set(2, 5, PColor(0xFFF0A0))
            return b
        }
    }

    static func fish() -> SKTexture {
        Tex.get("icon.fish") {
            let b = PixelBuffer(12, 8)
            b.triangle((1, 1), (1, 7), (4, 4), PColor(0x3A8AC8))
            b.ellipse(7, 4, 4, 2.6, PColor(0x5AB4E8))
            b.rect(4, 2, 6, 1, PColor(0xC8E8F8))
            b.set(9, 5, .black)
            b.outline(PColor(0x1A3A5A))
            return b
        }
    }

    static func cloudBuffer(_ w: Int, _ h: Int, seed: Int, base: PColor, shade: PColor, outline: PColor? = nil) -> PixelBuffer {
        let b = PixelBuffer(w, h)
        let n = 3 + Int(hrand(seed, 1) * 3)
        for i in 0..<n {
            let cx = Double(w) * (0.2 + 0.6 * Double(i) / Double(max(1, n - 1)))
            let r = Double(h) * (0.28 + hrand(seed, i + 7) * 0.22)
            b.ellipse(cx, Double(h) * 0.4 + r * 0.3, r * 1.2, r, base)
        }
        b.rect(Int(Double(w) * 0.12), 1, Int(Double(w) * 0.76), Int(Double(h) * 0.3), base)
        for y in 0..<max(1, h / 4) { for x in 0..<w where b[x, y].a > 0 { b[x, y] = shade } }
        if let o = outline { b.outline(o) }
        return b
    }

    static func weather(_ w: Weather) -> SKTexture {
        Tex.get("icon.weather.\(w.rawValue)") {
            let b = PixelBuffer(14, 12)
            switch w {
            case .sunny:
                for (dx, dy) in [(0, 5), (0, -5), (5, 0), (-5, 0), (4, 4), (-4, 4), (4, -4), (-4, -4)] {
                    b.set(7 + dx, 6 + dy, PColor(0xFFA020))
                }
                b.ellipse(7.5, 6.5, 3.5, 3.5, PColor(0xFFD23A))
                b.set(6, 8, PColor(0xFFF4B0))
            case .cloudy:
                b.blit(cloudBuffer(13, 9, seed: 3, base: PColor(0xF4F6FA), shade: PColor(0xC0C8D4), outline: PColor(0x5A6474)), 0, 2)
            case .rain:
                b.blit(cloudBuffer(13, 8, seed: 4, base: PColor(0xD8DEE6), shade: PColor(0xA8B2C0), outline: PColor(0x4A5464)), 0, 4)
                for x in [3, 7, 11] { b.rect(x, 0, 1, 3, PColor(0x4A9AE8)) }
            case .storm:
                b.blit(cloudBuffer(13, 8, seed: 5, base: PColor(0x7A8494), shade: PColor(0x5A6474), outline: PColor(0x2A3444)), 0, 4)
                b.line(8, 5, 6, 2, PColor(0xFFE04A))
                b.line(6, 2, 8, 2, PColor(0xFFE04A))
                b.line(8, 2, 6, 0, PColor(0xFFE04A))
            case .fog:
                for (y, x0) in [(9, 1), (6, 3), (3, 0), (0, 2)] { b.rect(x0, y, 11, 2, PColor(0xC8CED6)) }
            case .snow:
                b.blit(cloudBuffer(13, 8, seed: 6, base: PColor(0xF4F6FA), shade: PColor(0xC8D0DA), outline: PColor(0x5A6474)), 0, 4)
                for (x, y) in [(2, 2), (6, 0), (10, 2), (4, 0), (8, 3)] { b.set(x, y, .white); b.set(x, y + 1, PColor(0xC8E0FF)) }
            }
            return b
        }
    }
}

// MARK: - Input base scene

enum Key {
    static let space: UInt16 = 49, esc: UInt16 = 53, ret: UInt16 = 36, enter: UInt16 = 76, tab: UInt16 = 48
    static let left: UInt16 = 123, right: UInt16 = 124, down: UInt16 = 125, up: UInt16 = 126
    static let w: UInt16 = 13, a: UInt16 = 0, s: UInt16 = 1, d: UInt16 = 2
    static let e: UInt16 = 14, q: UInt16 = 12, j: UInt16 = 38, m: UInt16 = 46
    static let one: UInt16 = 18, two: UInt16 = 19, three: UInt16 = 20, four: UInt16 = 21, five: UInt16 = 23
    static let six: UInt16 = 22, seven: UInt16 = 26, g: UInt16 = 5, x: UInt16 = 7, c: UInt16 = 8, i: UInt16 = 34, p: UInt16 = 35, y: UInt16 = 16, n: UInt16 = 45, backspace: UInt16 = 51
    static let numbers: [UInt16] = [18, 19, 20, 21, 23, 22, 26, 28]
}

class BaseScene: SKScene {
    private(set) var keysDown = Set<UInt16>()
    private(set) var mouseHeld = false

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .aspectFit
    }

    required init?(coder: NSCoder) { fatalError() }

    override func didMove(to view: SKView) {
        keysDown.removeAll()
        mouseHeld = false
        sceneDidAppear()
    }

    func sceneDidAppear() {}
    func keyPressed(_ key: UInt16) {}
    func typed(_ text: String) {}
    func primaryPressed() {}

    override func keyDown(with event: NSEvent) {
        keysDown.insert(event.keyCode)
        if !event.isARepeat {
            keyPressed(event.keyCode)
            if let c = event.characters, !c.isEmpty { typed(c) }
        }
    }

    override func keyUp(with event: NSEvent) { keysDown.remove(event.keyCode) }

    override func mouseDown(with event: NSEvent) {
        mouseHeld = true
        primaryPressed()
    }

    override func mouseUp(with event: NSEvent) { mouseHeld = false }

    func isDown(_ keys: UInt16...) -> Bool { keys.contains { keysDown.contains($0) } }
}

// MARK: - Sound (built-in macOS system sounds)

enum Sound {
    private static var playing: [NSSound] = []

    static func play(_ name: String, volume: Float = 0.45) {
        playing.removeAll { !$0.isPlaying }
        guard let base = NSSound(named: NSSound.Name(name)),
              let s = base.copy() as? NSSound else { return }
        s.volume = volume
        s.play()
        playing.append(s)
    }
}
