import SpriteKit

// MARK: - Fish

enum FishPixel {
    static func texture(_ s: FishSpecies, length: Int, silhouette: PColor? = nil) -> SKTexture {
        Tex.get("fish|\(s.id)|\(length)|\(silhouette?.key ?? "-")") {
            let b = buffer(s, length: length)
            if let sil = silhouette { b.replaceOpaque(sil) }
            return b
        }
    }

    static func buffer(_ s: FishSpecies, length L: Int) -> PixelBuffer {
        let hR: Double
        switch s.shape {
        case .normal: hR = 0.40
        case .long: hR = 0.20
        case .round: hR = 0.62
        case .tall: hR = 0.56
        case .sword: hR = 0.28
        case .catfish: hR = 0.30
        case .angler: hR = 0.52
        case .shark: hR = 0.30
        }
        let Ld = Double(L)
        let bodyW = Ld * (s.shape == .long ? 0.84 : s.shape == .shark ? 0.78 : 0.74)
        let bodyH = max(3, Ld * hR)
        let finH = s.shape == .tall ? bodyH * 0.7 : s.shape == .shark ? bodyH * 0.75 + 1 : bodyH * 0.35 + 1
        let extra = s.shape == .sword ? Int(Ld * 0.36) : 0
        let W = L + extra + 6
        let H = Int(ceil(bodyH + finH * 2)) + 5
        let b = PixelBuffer(W, H)
        let cy = Double(H) / 2
        let bx = 2 + Ld * 0.56
        let rx = bodyW / 2, ry = bodyH / 2
        let body = PColor(s.body), belly = PColor(s.belly), fin = PColor(s.fin)
        let top = body.shade(-0.18), dark = body.shade(-0.6)
        let sid = s.id.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }

        // Tail with a fork
        let tailBase = bx - bodyW * 0.42
        let th = max(bodyH * 0.5, Ld * 0.12)
        if s.shape == .shark {
            // Uneven shark tail: long upper lobe, short lower one
            b.triangle((tailBase + 2, cy + ry * 0.4), (1, cy + th * 1.5), (tailBase - 1, cy - ry * 0.3), body)
            b.triangle((tailBase + 1, cy - ry * 0.1), (Double(3), cy - th * 0.9), (tailBase - 1, cy + ry * 0.3), body)
        } else {
            b.triangle((tailBase, cy), (2, cy + th), (2, cy - th), fin)
            b.triangle((1.5, cy + th * 0.4), (2 + Ld * 0.07, cy), (1.5, cy - th * 0.4), .clear)
        }

        // Fins
        if s.shape == .shark {
            // Tall swept-back dorsal, small second dorsal, long pectoral
            b.triangle((bx - bodyW * 0.12, cy + ry * 0.7), (bx - bodyW * 0.16, cy + ry + finH * 0.95), (bx + bodyW * 0.12, cy + ry * 0.7), body.shade(-0.08))
            b.triangle((bx - bodyW * 0.36, cy + ry * 0.4), (bx - bodyW * 0.38, cy + ry + finH * 0.25), (bx - bodyW * 0.28, cy + ry * 0.5), body.shade(-0.08))
            b.triangle((bx + bodyW * 0.14, cy - ry * 0.5), (bx - bodyW * 0.06, cy - ry - finH * 0.7), (bx + bodyW * 0.03, cy - ry * 0.5), body.shade(-0.08))
        } else if s.shape == .tall {
            b.triangle((bx - bodyW * 0.32, cy + ry * 0.6), (bx - bodyW * 0.18, cy + ry + finH), (bx + bodyW * 0.2, cy + ry * 0.7), fin)
            b.triangle((bx - bodyW * 0.32, cy - ry * 0.6), (bx - bodyW * 0.18, cy - ry - finH), (bx + bodyW * 0.2, cy - ry * 0.7), fin)
        } else {
            b.triangle((bx - bodyW * 0.26, cy + ry * 0.75), (bx - bodyW * 0.12, cy + ry + finH), (bx + bodyW * 0.16, cy + ry * 0.8), fin)
            b.triangle((bx - bodyW * 0.12, cy - ry * 0.8), (bx - bodyW * 0.04, cy - ry - finH * 0.5), (bx + bodyW * 0.1, cy - ry * 0.8), fin)
        }
        if s.shape == .sword {
            b.triangle((bx + rx * 0.8, cy + ry * 0.3), (bx + rx + Ld * 0.36, cy + 0.5), (bx + rx * 0.8, cy - ry * 0.1), body.shade(-0.1))
        }

        // Body with countershading
        for y in Int(cy - ry - 1)...Int(cy + ry + 1) {
            for x in Int(bx - rx - 1)...Int(bx + rx + 1) {
                let dx = (Double(x) + 0.5 - bx) / rx, dy = (Double(y) + 0.5 - cy) / ry
                // Sharks taper to a pointed snout and a slim tail stock
                let taper = s.shape == .shark ? (dx > 0 ? 1 - 0.35 * dx : 1 + 0.3 * dx) : 1
                guard dx * dx + (dy / taper) * (dy / taper) <= 1 else { continue }
                var c = body
                if dy < -0.25 { c = belly } else if dy > 0.5 { c = top }
                if s.pattern == .stripes && dy > -0.7 {
                    for k in [-0.22, -0.02, 0.18] where x == Int(bx + bodyW * k) || (bodyW > 30 && x == Int(bx + bodyW * k) + 1) {
                        c = fin.shade(-0.1)
                    }
                }
                b.set(x, y, c)
            }
        }
        if s.pattern == .spots {
            let n = max(3, Int(bodyW * bodyH / 16))
            let big = bodyH >= 12 && (s.id == "koi" || s.id == "lotuskoi")
            for i in 0..<n {
                let px = bx + (hrand(i, sid, 1) - 0.5) * bodyW * 0.8
                let py = cy + (hrand(i, sid, 2) - 0.35) * bodyH * 0.7
                let dx = (px - bx) / rx, dy = (py - cy) / ry
                if dx * dx + dy * dy < 0.75 {
                    if big { b.rect(Int(px), Int(py), 2, 2, fin) } else { b.set(Int(px), Int(py), fin) }
                }
            }
        }
        // Gill line (sharks get a row of slits)
        if s.shape == .shark && bodyW >= 14 {
            let gx = Int(bx + bodyW * 0.16)
            for k in 0..<(bodyW >= 24 ? 3 : 2) {
                for y in Int(cy - ry * 0.3)...Int(cy + ry * 0.35) where b[gx + k * 2, y].a > 0 { b.set(gx + k * 2, y, body.shade(-0.3)) }
            }
        } else if bodyW >= 14 {
            let gx = Int(bx + bodyW * 0.22)
            for y in Int(cy - ry * 0.45)...Int(cy + ry * 0.45) where b[gx, y].a > 0 { b.set(gx, y, body.shade(-0.3)) }
        }
        // Eye
        let ex = Int(bx + bodyW * 0.33), ey = Int(cy + bodyH * 0.1)
        if s.shape == .shark {
            b.set(ex, ey, PColor(0x101010))
            if bodyW >= 24 { b.line(Int(bx + rx * 0.5), Int(cy - ry * 0.4), Int(bx + rx * 0.82), Int(cy - ry * 0.3), body.shade(-0.4)) }
        } else if bodyH >= 9 {
            b.rect(ex, ey, 2, 2, .white)
            b.set(ex + 1, ey, PColor(0x101010))
        } else {
            b.set(ex, ey, PColor(0x101010))
        }
        // Extras
        if s.shape == .catfish {
            let mx = Int(bx + rx) - 1, my = Int(cy) - 1
            b.line(mx, my, mx + 3, Int(cy - ry) - 1, fin.shade(-0.2))
            b.line(mx, my, mx + 4, my - 1, fin.shade(-0.2))
        }
        if s.shape == .angler {
            let sx = Int(bx + bodyW * 0.1), sy = Int(cy + ry)
            let tx = Int(bx + bodyW * 0.5), ty = Int(cy + ry + finH * 0.8)
            b.line(sx, sy, tx, ty, body.shade(0.3))
            b.rect(tx, ty - 1, 2, 2, fin)
        }
        b.outline(dark)
        return b
    }
}

// MARK: - Player

enum Dir: Int { case down, up, left, right }

enum PlayerArt {
    static let w = 18, h = 27

    static func texture(_ d: Dir, frame: Int, outfit: Outfit = Game.shared.save.outfit) -> SKTexture {
        Tex.get("player|\(d.rawValue)|\(frame)|\(outfit.key)") { buffer(d, frame: frame, outfit: outfit) }
    }

    /// Head + shoulders, for sitting in boats.
    static func upperBody(_ d: Dir, outfit: Outfit = Game.shared.save.outfit) -> SKTexture {
        Tex.get("player.upper|\(d.rawValue)|\(outfit.key)") {
            buffer(d, frame: 0, outfit: outfit).crop(0, 9, w, h - 9)
        }
    }

    static func buffer(_ d: Dir, frame: Int, outfit o: Outfit) -> PixelBuffer {
        if d == .left { return buffer(.right, frame: frame, outfit: o).flippedH() }
        let b = PixelBuffer(w, h)
        let off = 1
        func r(_ x: Int, _ y: Int, _ rw: Int, _ rh: Int, _ c: PColor) { b.rect(x + off, y + off, rw, rh, c) }
        func p(_ x: Int, _ y: Int, _ c: PColor) { b.set(x + off, y + off, c) }
        let skin = PColor(o.skin), skinSh = PColor(o.skin).shade(-0.15), hair = PColor(o.hair)
        let hat = PColor(o.hat), hatSh = PColor(o.hat).shade(-0.25), band = PColor(o.hatBand)
        let pants = PColor(o.pants), pantsSh = PColor(o.pants2), boot = PColor(0x5A3418)
        let eye = PColor(0x1A1010), belt = PColor(0x6A3A1A)
        func shirtColor(_ x: Int, _ y: Int) -> PColor {
            let a = PColor(o.shirt), c = PColor(o.shirt2)
            switch o.pattern {
            case .plain: return a
            case .plaid: return ((x / 2 + y / 2) % 2 == 0) ? a : a.mix(c, 0.6)
            case .stripes: return y % 2 == 0 ? a : c
            case .floral: return (x * 3 + y * 5) % 7 == 0 ? c : a
            }
        }
        func shirtRect(_ x: Int, _ y: Int, _ rw: Int, _ rh: Int, shade: Bool = false) {
            for yy in y..<(y + rh) { for xx in x..<(x + rw) { p(xx, yy, shade ? shirtColor(xx, yy).shade(-0.2) : shirtColor(xx, yy)) } }
        }
        let legSkin = o.shorts

        if d == .down || d == .up {
            let lL = frame == 1 ? 1 : 0, rL = frame == 2 ? 1 : 0
            r(4, 2 + lL, 3, 5 - lL, legSkin ? skin : pants); r(9, 2 + rL, 3, 5 - rL, legSkin ? skin : pants)
            if legSkin { r(4, 5, 3, 2, pants); r(9, 5, 3, 2, pants) }
            r(4, lL, 3, 2, boot); r(9, rL, 3, 2, boot)
            if !legSkin { r(6, 4, 1, 3, pantsSh); r(9, 4, 1, 3, pantsSh) }
            shirtRect(3, 7, 10, 7)
            shirtRect(12, 7, 1, 7, shade: true)
            r(3, 7, 10, 1, belt)
            let la = frame == 1 ? 1 : 0, ra = frame == 2 ? 1 : 0
            shirtRect(2, 8 + la, 1, 5); shirtRect(13, 8 + ra, 1, 5, shade: true)
            p(2, 7 + la, skin); p(13, 7 + ra, skin)
            r(4, 14, 8, 7, skin)
            r(11, 14, 1, 7, skinSh)
            if d == .down {
                r(4, 18, 1, 3, hair); r(11, 18, 1, 3, hair)
                r(4, 20, 8, 1, hair)
                p(6, 17, eye); p(9, 17, eye)
                p(7, 15, skinSh); p(8, 15, skinSh)
            } else {
                r(4, 15, 8, 6, hair)
                r(6, 14, 4, 1, skinSh)
            }
            switch o.hatStyle {
            case .bucket:
                r(2, 21, 12, 1, hat); p(2, 21, hatSh); p(13, 21, hatSh)
                r(4, 22, 8, 2, hat); r(4, 22, 8, 1, band)
            case .straw:
                r(0, 21, 16, 1, hat); p(0, 21, hatSh); p(15, 21, hatSh)
                r(5, 22, 6, 2, hat); r(5, 22, 6, 1, band)
            case .cap:
                r(4, 21, 8, 3, hat); r(5, 24, 6, 1, hat)
                if d == .down { r(4, 21, 8, 1, band) } else { r(7, 22, 2, 1, band) }
            case .beanie:
                r(4, 20, 8, 4, hat); r(4, 20, 8, 1, band)
                for x in stride(from: 5, to: 12, by: 2) { p(x, 22, hatSh) }
                r(7, 24, 2, 1, band)
            case .wizard:
                r(2, 21, 12, 1, hat); r(4, 22, 8, 1, hat); r(5, 23, 6, 1, hat); r(6, 24, 4, 1, hat)
                p(8, 22, band)
            }
        } else {
            let fwd = frame == 1 ? 1 : (frame == 2 ? -1 : 0)
            r(7 + fwd, 2, 3, 5, legSkin ? skin : pants); r(6 - fwd, 2, 3, 5, legSkin ? skinSh : pantsSh)
            if legSkin { r(6, 5, 5, 2, pants) }
            r(7 + fwd, 0, 4, 2, boot); r(6 - fwd, 0, 3, 2, boot.shade(-0.2))
            shirtRect(5, 7, 6, 7); r(5, 7, 6, 1, belt)
            shirtRect(7 - fwd, 8, 3, 5, shade: true)
            p(8 - fwd, 7, skin); p(9 - fwd, 7, skin)
            r(5, 14, 7, 7, skin)
            r(5, 15, 2, 6, hair)
            p(10, 17, eye)
            p(12, 16, skin)
            switch o.hatStyle {
            case .bucket:
                r(4, 21, 10, 1, hat); p(13, 21, hatSh)
                r(5, 22, 6, 2, hat); r(5, 22, 6, 1, band)
            case .straw:
                r(2, 21, 14, 1, hat); p(15, 21, hatSh); p(2, 21, hatSh)
                r(5, 22, 6, 2, hat); r(5, 22, 6, 1, band)
            case .cap:
                r(5, 21, 7, 3, hat); r(6, 24, 5, 1, hat)
                r(11, 21, 4, 1, band)
            case .beanie:
                r(5, 20, 7, 4, hat); r(5, 20, 7, 1, band); r(7, 24, 2, 1, band)
            case .wizard:
                r(3, 21, 11, 1, hat); r(5, 22, 7, 1, hat); r(6, 23, 5, 1, hat); r(6, 24, 3, 1, hat); p(5, 25, hat)
                p(8, 22, band)
            }
        }
        b.outline(PColor(0x2A1A10))
        return b
    }
}

// MARK: - Item icons

enum ItemArt {
    static func icon(_ it: GearItem) -> SKTexture {
        Tex.get("item|\(it.id)") {
            let b = PixelBuffer(18, 18)
            let a = PColor(it.c1), c = PColor(it.c2)
            switch it.slot {
            case .lure:
                switch it.style {
                case 0: // spinner
                    b.line(3, 14, 14, 3, PColor(0x5A5A64)); b.ellipse(6, 11, 3, 4.5, a); b.set(5, 12, .white); b.rect(12, 3, 3, 3, c)
                case 1: // crankbait
                    b.ellipse(9, 9, 6.5, 3.5, a); b.rect(4, 9, 10, 2, c); b.set(13, 10, .black)
                    b.triangle((15, 8), (17, 6), (17, 9), PColor(0xD8DCE4)); b.line(6, 5, 6, 2, PColor(0x5A5A64))
                case 2: // fly
                    b.line(4, 4, 13, 13, PColor(0x5A5A64)); b.ellipse(9, 9, 3, 2, c)
                    b.triangle((8, 9), (2, 15), (5, 15), a); b.triangle((10, 9), (15, 15), (12, 16), a)
                case 3: // jig
                    b.ellipse(12, 12, 3, 3, PColor(0xC8CCD4)); for x in stride(from: 2, to: 11, by: 2) { b.line(10, 11, x, 3, a) }
                    b.set(13, 13, .black)
                case 4: // glow
                    b.ellipse(9, 9, 7, 7, a.alpha(70)); b.ellipse(9, 9, 4.5, 2.6, a); b.set(12, 10, c); b.line(3, 9, 5, 9, c)
                default: // golden spoon
                    b.ellipse(9, 8, 4.5, 6, a); b.ellipse(8, 9, 2, 3, PColor(0xFFF0A0)); b.rect(8, 14, 2, 3, c)
                }
            case .bait:
                switch it.style {
                case 0, 3: // worms / crawlers in a can
                    b.rect(3, 1, 12, 10, PColor(0x8A8A94)); b.rect(3, 9, 12, 2, PColor(0xB8B8C0))
                    b.line(5, 11, 8, 15, a, thick: 2); b.line(9, 11, 12, 14, a, thick: 2); b.rect(4, 4, 10, 3, c)
                case 1: // minnow bucket
                    b.polygon([(3, 12), (15, 12), (13, 1), (5, 1)], PColor(0x5A8AC8)); b.rect(3, 11, 12, 2, PColor(0x7AA8E0))
                    b.ellipse(9, 14, 3, 1.5, a); b.set(11, 14, .black)
                case 2: // shrimp
                    for i in 0..<6 { b.ellipse(4 + Double(i) * 2, 6 + sin(Double(i) * 0.6) * 4, 2.2, 2.2, i % 2 == 0 ? a : c) }
                    b.line(15, 11, 17, 15, c)
                default: // magic bait
                    b.ellipse(9, 7, 5, 5, a); b.rect(6, 12, 6, 3, PColor(0x5A3A1A))
                    for (x, y) in [(3, 14), (15, 13), (2, 4), (16, 5), (9, 16)] { b.set(x, y, c) }
                    b.set(7, 9, .white)
                }
            case .hat:
                let o = Outfit(hatStyle: HatStyle(rawValue: it.style)!, hat: it.c1, hatBand: it.c2, shirt: 0, shirt2: 0, pattern: .plain,
                               pants: 0, pants2: 0, shorts: false, hair: 0, skin: 0)
                let full = PlayerArt.buffer(.down, frame: 0, outfit: o)
                let crop = full.crop(0, 20, 18, 7)
                for y in 0..<crop.h { for x in 0..<crop.w where crop[x, y].a > 0 { b.rect(x, y * 2 + 2, 1, 2, crop[x, y]) } }
            case .shirt:
                let o = Outfit(hatStyle: .bucket, hat: 0, hatBand: 0, shirt: it.c1, shirt2: it.c2,
                               pattern: ShirtPattern(rawValue: it.style)!, pants: 0, pants2: 0, shorts: false, hair: 0, skin: 0xF4C49A)
                let full = PlayerArt.buffer(.down, frame: 0, outfit: o)
                for y in 8..<16 { for x in 2..<16 { let px = full[x, y]; if px.a > 0 { b.rect(x - 1, (y - 8) * 2 + 1, 1, 2, px) } } }
            case .pants:
                b.rect(4, 14, 10, 2, PColor(0x6A3A1A))
                let len = it.style == 1 ? 6 : 12
                b.rect(4, 14 - len, 4, len, a); b.rect(10, 14 - len, 4, len, a); b.rect(4, 10, 10, 4, a)
                b.rect(8, 14 - len, 2, len - 4, .clear); b.rect(12, 14 - len, 2, len, c.alpha(120))
            }
            b.outline(PColor(0x2A1408))
            return b
        }
    }

    static func chestIcon() -> SKTexture {
        Tex.get("icon.chest") {
            let b = PixelBuffer(16, 14)
            b.rect(1, 0, 14, 8, PColor(0xA0682E)); b.rect(1, 8, 14, 5, PColor(0xB87A3A))
            b.rect(1, 7, 14, 1, PColor(0x5A3418)); b.rect(7, 5, 2, 4, PColor(0xFFD23A))
            b.rect(1, 0, 1, 13, PColor(0x7A4A20)); b.rect(14, 0, 1, 13, PColor(0x7A4A20))
            b.outline(PColor(0x2A1408))
            return b
        }
    }

    static func trophy(_ i: Int) -> SKTexture {
        Tex.get("trophy|\(i % 3)") {
            let b = PixelBuffer(12, 14)
            let col = [PColor(0xFFD23A), PColor(0xD8DCE4), PColor(0xD88A4A)][i % 3]
            b.ellipse(6, 9, 4.5, 4, col); b.rect(5, 3, 2, 3, col); b.rect(3, 0, 6, 3, PColor(0x6A4A2A))
            b.rect(0, 9, 2, 3, col); b.rect(10, 9, 2, 3, col); b.set(4, 10, .white)
            b.outline(PColor(0x2A1408))
            return b
        }
    }
}

// MARK: - Boats

enum BoatArt {
    /// Side view, bow to the right. `front` is the hull wall drawn over the seated player.
    static func side(_ kind: BoatKind, front: Bool) -> SKTexture {
        Tex.get("boat.side|\(kind)|\(front)") {
            let b: PixelBuffer
            switch kind {
            case .row, .kayak:
                b = PixelBuffer(36, 18)
                if front {
                    b.polygon([(3, 9), (32, 9), (35, 12), (31, 4), (27, 1), (8, 1), (4, 4)], PColor(kind == .kayak ? 0xF2C83A : 0xA8683A))
                    b.rect(4, 5, 28, 1, PColor(0x8A5230))
                    b.rect(3, 8, 30, 1, PColor(0xD09058))
                    b.rect(8, 1, 20, 1, PColor(0x6A3A1E))
                    b.line(12, 12, 5, 0, PColor(0x8A5A30))
                    b.rect(3, 0, 3, 2, PColor(0x8A5A30))
                } else {
                    b.rect(5, 9, 27, 2, PColor(0x7A4626))
                }
            case .skiff, .bass:
                b = PixelBuffer(40, 18)
                if front {
                    b.polygon([(5, 8), (34, 8), (39, 13), (34, 4), (30, 1), (8, 1), (5, 3)], PColor(kind == .bass ? 0xC82A3A : 0xEEF0F4))
                    b.rect(6, 5, 29, 2, PColor(kind == .bass ? 0xE8E8F0 : (kind == .yacht ? 0x1E2A5A : (kind == .pontoon ? 0x3AA8A0 : 0xC83A3A))))
                    b.rect(5, 8, 30, 1, PColor(0xC0C6D0))
                    b.rect(8, 1, 22, 1, PColor(0x9AA0AA))
                    b.rect(0, 7, 5, 7, PColor(0x5A5E66))
                    b.rect(0, 12, 5, 2, PColor(0x3A3E46))
                    b.rect(2, 2, 1, 5, PColor(0x3A3E46))
                } else {
                    b.rect(6, 9, 28, 1, PColor(0xA0A6B0))
                    b.rect(25, 9, 1, 5, PColor(0x5A5E66))
                    b.rect(26, 10, 4, 4, PColor(0x9AD8F2))
                    b.rect(30, 9, 1, 5, PColor(0x5A5E66))
                }
            case .trawler, .pontoon, .yacht:
                b = PixelBuffer(54, 30)
                if front {
                    b.polygon([(2, 10), (46, 10), (52, 15), (47, 4), (42, 1), (8, 1), (3, 4)], PColor(kind == .yacht ? 0xF4F4F8 : (kind == .pontoon ? 0xB8BCC4 : 0x2E5A9A)))
                    b.rect(3, 7, 44, 2, PColor(0xF0F0F0))
                    b.rect(2, 10, 45, 1, PColor(0x1E3A6A))
                    b.rect(8, 1, 34, 1, PColor(0x1A2A4A))
                    for x in stride(from: 12, to: 44, by: 8) { b.set(x, 5, PColor(0x9AC8F0)) }
                } else {
                    b.rect(4, 11, 42, 2, PColor(0x1E3A6A))
                    b.rect(27, 11, 15, 10, PColor(0xF0F0F0))
                    b.rect(41, 11, 1, 10, PColor(0xC8C8D0))
                    b.rect(29, 15, 4, 3, PColor(0x6AA8D8)); b.rect(35, 15, 4, 3, PColor(0x6AA8D8))
                    b.rect(26, 21, 17, 2, PColor(kind == .bass ? 0xE8E8F0 : (kind == .yacht ? 0x1E2A5A : (kind == .pontoon ? 0x3AA8A0 : 0xC83A3A))))
                    b.rect(34, 23, 1, 6, PColor(0x3A3A44))
                    b.rect(35, 26, 3, 2, PColor(0xFFD23A))
                    b.line(6, 11, 18, 24, PColor(0x5A4A3A))
                    b.rect(18, 22, 1, 3, PColor(0x5A4A3A))
                }
            }
            b.outline(PColor(0x1E140E))
            return b
        }
    }

    /// Where the seated player's feet go in the side view (pixels).
    static func seat(_ kind: BoatKind) -> (Int, Int) {
        switch kind {
        case .row, .kayak: return (17, 4)
        case .skiff, .bass: return (16, 4)
        case .trawler, .pontoon, .yacht: return (15, 6)
        }
    }

    /// Top view, bow pointing up.
    static func top(_ kind: BoatKind) -> SKTexture {
        Tex.get("boat.top|\(kind)") {
            let b: PixelBuffer
            switch kind {
            case .row, .kayak:
                b = PixelBuffer(24, 36)
                b.line(5, 17, 1, 12, PColor(0x8A5A30), thick: 2)
                b.line(18, 17, 22, 12, PColor(0x8A5A30), thick: 2)
                b.polygon([(12, 35), (18, 27), (19, 8), (16, 1), (8, 1), (5, 8), (6, 27)], PColor(kind == .kayak ? 0xF2C83A : 0xA8683A))
                b.polygon([(12, 31), (16, 25), (16.5, 9), (14.5, 4), (9.5, 4), (7.5, 9), (8, 25)], PColor(0x7A4626))
                b.rect(7, 16, 10, 2, PColor(0xC08050))
            case .skiff, .bass:
                b = PixelBuffer(22, 40)
                b.polygon([(11, 39), (18, 30), (19, 7), (16, 3), (6, 3), (3, 7), (4, 30)], PColor(kind == .bass ? 0xC82A3A : 0xEEF0F4))
                b.polygon([(11, 35), (16, 28), (16.5, 8), (14, 5.5), (8, 5.5), (5.5, 8), (6, 28)], PColor(0xC8CCD4))
                b.rect(6, 26, 10, 1, PColor(0x9AD8F2))
                b.rect(8, 0, 6, 4, PColor(0x5A5E66))
                b.rect(10, 0, 2, 1, PColor(0x3A3E46))
                for y in [12, 20] { b.rect(3, y, 1, 3, PColor(kind == .bass ? 0xE8E8F0 : (kind == .yacht ? 0x1E2A5A : (kind == .pontoon ? 0x3AA8A0 : 0xC83A3A)))); b.rect(18, y, 1, 3, PColor(kind == .bass ? 0xE8E8F0 : (kind == .yacht ? 0x1E2A5A : (kind == .pontoon ? 0x3AA8A0 : 0xC83A3A)))) }
            case .trawler, .pontoon, .yacht:
                b = PixelBuffer(28, 56)
                b.polygon([(14, 55), (24, 42), (25, 6), (21, 1), (7, 1), (3, 6), (4, 42)], PColor(kind == .yacht ? 0xF4F4F8 : (kind == .pontoon ? 0xB8BCC4 : 0x2E5A9A)))
                b.polygon([(14, 50), (21, 40), (21.5, 7), (19, 4), (9, 4), (6.5, 7), (7, 40)], PColor(0xA8743A))
                for y in stride(from: 6, to: 40, by: 3) { b.rect(7, y, 14, 1, PColor(0x8A5A30)) }
                b.rect(7, 28, 14, 12, PColor(0xF0F0F0))
                b.rect(7, 28, 14, 12, PColor(0xC83A3A, 255))
                b.rect(8, 29, 12, 10, PColor(kind == .yacht ? 0x2A3A7A : (kind == .pontoon ? 0x4AC8C0 : 0xE04A3A)))
                b.rect(13, 30, 2, 8, PColor(0xB83A2A))
            }
            b.outline(PColor(0x1E140E))
            return b
        }
    }
}

/// Map boat node: hull + seated player, oriented to the travel direction.
final class BoatNode: SKNode {
    let kind: BoatKind
    private let back = SKSpriteNode()
    private let rider = SKSpriteNode()
    private let front = SKSpriteNode()
    private(set) var dir: Dir = .right
    private let scale: CGFloat

    init(kind: BoatKind, scale: CGFloat = 2) {
        self.kind = kind
        self.scale = scale
        super.init()
        addChild(back)
        addChild(rider)
        addChild(front)
        setDir(.right, force: true)
    }

    required init?(coder: NSCoder) { fatalError() }

    func setDir(_ d: Dir, force: Bool = false) {
        guard d != dir || force else { return }
        dir = d
        switch d {
        case .left, .right:
            back.isHidden = false
            front.isHidden = false
            back.setPixelTexture(BoatArt.side(kind, front: false), scale: scale)
            front.setPixelTexture(BoatArt.side(kind, front: true), scale: scale)
            let flip: CGFloat = d == .left ? -1 : 1
            back.xScale = flip
            front.xScale = flip
            back.yScale = 1
            front.yScale = 1
            back.anchorPoint = CGPoint(x: 0.5, y: 0)
            front.anchorPoint = CGPoint(x: 0.5, y: 0)
            back.position = CGPoint(x: 0, y: -10)
            front.position = back.position
            let seat = BoatArt.seat(kind)
            let tw = BoatArt.side(kind, front: false).size().width
            rider.setPixelTexture(PlayerArt.texture(d, frame: 0), scale: scale)
            rider.anchorPoint = CGPoint(x: 0.5, y: 0)
            rider.position = CGPoint(x: (CGFloat(seat.0) - tw / 2) * scale * flip, y: -10 + CGFloat(seat.1) * scale)
        case .up, .down:
            back.isHidden = false
            front.isHidden = true
            back.setPixelTexture(BoatArt.top(kind), scale: scale)
            back.xScale = 1
            back.yScale = d == .down ? -1 : 1
            back.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            back.position = .zero
            rider.setPixelTexture(PlayerArt.upperBody(d), scale: scale)
            rider.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            rider.position = CGPoint(x: 0, y: d == .up ? -6 : 6)
        }
    }
}

// MARK: - World props

enum TreeKind: Int { case oak, pine, palm, dead, bush }

enum PropArt {
    static func tree(_ k: TreeKind, variant: Int) -> SKTexture {
        Tex.get("tree|\(k.rawValue)|\(variant)") {
            let v = Double(variant)
            switch k {
            case .oak:
                let b = PixelBuffer(30, 38)
                b.ellipse(15, 3, 8, 2.5, PColor(0x000000, 60))
                b.rect(12, 2, 6, 11, PColor(0x7A4A26))
                b.rect(16, 2, 2, 11, PColor(0x5A3418))
                b.rect(11, 2, 1, 2, PColor(0x7A4A26)); b.rect(18, 2, 1, 2, PColor(0x5A3418))
                let leaf = PColor(0x3E8A3A).shade(hrand(variant, 1) * 0.12 - 0.06)
                b.ellipse(15, 24, 13, 10, leaf)
                b.ellipse(8, 21, 7, 6, leaf)
                b.ellipse(22, 21, 7, 6, leaf)
                b.ellipse(15, 30, 9, 6, leaf)
                for y in 0..<38 { for x in 0..<30 where b[x, y] == leaf && y < 19 { b[x, y] = leaf.shade(-0.25) } }
                b.ellipse(11, 28, 4, 3, leaf.shade(0.18))
                b.ellipse(19, 31, 3, 2, leaf.shade(0.12))
                for i in 0..<6 {
                    let x = 4 + Int(hrand(i, variant, 3) * 22), y = 16 + Int(hrand(i, variant, 4) * 16)
                    if b[x, y].a > 0 && b[x, y] != PColor(0x7A4A26) { b.set(x, y, leaf.shade(-0.3)) }
                }
                if hrand(variant, 9) < 0.3 {
                    for i in 0..<4 { b.rect(6 + Int(hrand(i, variant, 5) * 18), 18 + Int(hrand(i, variant, 6) * 12), 2, 2, PColor(0xE84A3A)) }
                }
                b.outline(PColor(0x1E3A1E))
                return b
            case .pine:
                let b = PixelBuffer(24, 40)
                b.ellipse(12, 3, 7, 2.2, PColor(0x000000, 60))
                b.rect(10, 2, 4, 7, PColor(0x6A3E1E))
                let g = PColor(0x2E6A3E).shade(v * 0.03)
                for (i, (y0, hw)) in [(7.0, 11.0), (17.0, 9.0), (26.0, 6.5)].enumerated() {
                    b.triangle((12 - hw, y0), (12, y0 + 14 - Double(i) * 2), (12 + hw, y0), g)
                    b.triangle((12, y0), (12, y0 + 14 - Double(i) * 2), (12 + hw, y0), g.shade(-0.2))
                    b.rect(Int(12 - hw) + 1, Int(y0), Int(hw * 2) - 2, 1, g.shade(-0.35))
                }
                if hrand(variant, 2) < 0.5 { b.set(9, 30, g.shade(0.3)); b.set(7, 20, g.shade(0.3)) }
                b.outline(PColor(0x14301E))
                return b
            case .palm:
                let b = PixelBuffer(30, 40)
                b.ellipse(15, 3, 7, 2, PColor(0x000000, 60))
                for y in 2..<30 {
                    let x = 14 + Int(sin(Double(y) * 0.12) * 3)
                    b.rect(x, y, 3, 1, y % 4 == 0 ? PColor(0x8A6A3A) : PColor(0xB8905A))
                }
                let fx = 15 + Int(sin(30 * 0.12) * 3), fy = 31
                let g = PColor(0x4AA040)
                for (dx, dy) in [(-13, -6), (-11, 3), (-4, 7), (5, 7), (12, 3), (13, -6)] {
                    b.line(fx, fy, fx + dx, fy + dy, g, thick: 2)
                    b.line(fx, fy - 1, fx + dx, fy + dy - 1, g.shade(-0.25))
                }
                b.rect(fx - 2, fy - 3, 2, 2, PColor(0x6A4A2A)); b.rect(fx + 1, fy - 3, 2, 2, PColor(0x6A4A2A))
                b.outline(PColor(0x1E3A1E))
                return b
            case .dead:
                let b = PixelBuffer(24, 32)
                b.ellipse(12, 3, 6, 2, PColor(0x000000, 60))
                let c = PColor(0x6A5A4A)
                b.rect(10, 2, 4, 20, c)
                b.rect(12, 2, 2, 20, c.shade(-0.25))
                b.line(11, 14, 4, 22, c, thick: 2)
                b.line(4, 22, 3, 27, c)
                b.line(12, 18, 19, 26, c, thick: 2)
                b.line(19, 26, 21, 29, c)
                b.line(12, 21, 12, 29, c, thick: 2)
                for x in [5, 8, 17, 20] { b.rect(x, 17 + Int(hrand(x, variant) * 4), 1, 4, PColor(0x7A8A4A)) }
                b.outline(PColor(0x2A2018))
                return b
            case .bush:
                let b = PixelBuffer(20, 16)
                b.ellipse(10, 2, 7, 2, PColor(0x000000, 60))
                let g = PColor(0x4A9A3E)
                b.ellipse(10, 8, 8, 6, g)
                b.ellipse(6, 7, 5, 4, g); b.ellipse(14, 7, 5, 4, g)
                for y in 0..<6 { for x in 0..<20 where b[x, y] == g { b[x, y] = g.shade(-0.25) } }
                b.ellipse(8, 10, 2.5, 2, g.shade(0.15))
                if hrand(variant, 3) < 0.5 { for (x, y) in [(6, 8), (12, 10), (14, 6)] { b.set(x, y, PColor(0x5A6AE8)) } }
                b.outline(PColor(0x1E3A1E))
                return b
            }
        }
    }

    static func shop() -> SKTexture {
        Tex.get("shop") {
            let b = PixelBuffer(68, 60)
            b.rect(2, 0, 64, 2, PColor(0x000000, 60))
            // walls
            b.rect(4, 2, 60, 26, PColor(0xC08A50))
            for x in stride(from: 4, to: 64, by: 6) { b.rect(x, 2, 1, 26, PColor(0x8A5A30)) }
            b.rect(4, 2, 60, 2, PColor(0x6A4020))
            // roof
            for row in 0..<26 {
                let inset = row * 10 / 26
                let y = 28 + row
                let c = (row / 4) % 2 == 0 ? PColor(0xB8442E) : PColor(0xC85038)
                b.rect(1 + inset, y, 66 - inset * 2, 1, c)
                if row % 4 == 3 { b.rect(1 + inset, y, 66 - inset * 2, 1, PColor(0x8A2E1E)) }
            }
            b.rect(0, 27, 68, 2, PColor(0x7A2418))
            b.rect(12, 54, 44, 2, PColor(0x7A2418))
            // door
            b.rect(29, 2, 10, 17, PColor(0x6A3A1A))
            b.rect(30, 3, 8, 15, PColor(0x8A4E26))
            b.set(36, 10, PColor(0xFFD23A))
            // windows
            for wx in [9, 47] {
                b.rect(wx, 9, 12, 10, PColor(0x5A3418))
                b.rect(wx + 1, 10, 10, 8, PColor(0x9AD8F2))
                b.rect(wx + 6, 10, 1, 8, PColor(0x5A3418)); b.rect(wx + 1, 14, 10, 1, PColor(0x5A3418))
                b.set(wx + 2, 16, .white); b.set(wx + 3, 17, .white)
            }
            // sign
            b.rect(21, 20, 26, 9, PColor(0x5A3418))
            b.rect(22, 21, 24, 7, PColor(0x8A5A30))
            b.blit(PixelFont.render("FISH", color: PColor(0xFFD23A), shadow: nil, align: .left), 25, 21)
            // barrels
            b.rect(56, 2, 6, 7, PColor(0x8A5A30)); b.rect(56, 4, 6, 1, PColor(0x4A4A4A)); b.rect(56, 7, 6, 1, PColor(0x4A4A4A))
            b.outline(PColor(0x2A1408))
            return b
        }
    }

    static func sign() -> SKTexture {
        Tex.get("sign") {
            let b = PixelBuffer(14, 15)
            b.rect(6, 0, 2, 8, PColor(0x6A3E1E))
            b.rect(1, 7, 12, 7, PColor(0xB07A40))
            b.rect(1, 7, 12, 1, PColor(0x7A4A22))
            b.rect(3, 10, 8, 1, PColor(0x5A3418)); b.rect(3, 12, 6, 1, PColor(0x5A3418))
            b.outline(PColor(0x2A1408))
            return b
        }
    }

    static func lamp() -> SKTexture {
        Tex.get("lamp") {
            let b = PixelBuffer(8, 24)
            b.rect(3, 0, 2, 18, PColor(0x3A3A44))
            b.rect(2, 0, 4, 2, PColor(0x3A3A44))
            b.rect(1, 18, 6, 5, PColor(0x2A2A34))
            b.rect(2, 19, 4, 3, PColor(0xFFE08A))
            b.outline(PColor(0x14141A))
            return b
        }
    }

    static func school(frame: Int) -> SKTexture {
        Tex.get("school|\(frame)") {
            let b = PixelBuffer(22, 16)
            for i in 0..<8 {
                let a = Double(i) / 8 * .pi * 2 + Double(frame) * 0.4
                let x = 11 + cos(a) * 8, y = 8 + sin(a) * 5
                b.set(Int(x), Int(y), PColor(0xFFFFFF, 220))
                if (i + frame) % 3 == 0 { b.set(Int(x) + 1, Int(y) + 1, PColor(0xC8F0FF, 200)) }
            }
            for i in 0..<3 {
                let a = Double(i) * 2.1 + Double(frame) * 0.7
                let x = 11 + cos(a) * 4, y = 8 + sin(a) * 2.5
                b.rect(Int(x) - 1, Int(y), 3, 1, PColor(0x0A1A2A, 130))
            }
            return b
        }
    }

    static func bobber() -> SKTexture {
        Tex.get("bobber") {
            let b = PixelBuffer(7, 9)
            b.ellipse(3.5, 3, 3, 3, .white)
            b.ellipse(3.5, 3, 3, 3, .white)
            for y in 3..<7 { for x in 0..<7 where b[x, y].a > 0 { b[x, y] = PColor(0xE8382E) } }
            b.rect(3, 6, 1, 3, PColor(0x333333))
            b.set(2, 4, PColor(0xFF8A7A))
            b.outline(PColor(0x1A1A1A))
            return b
        }
    }

    static func ripple(frame: Int) -> SKTexture {
        Tex.get("ripple|\(frame)") {
            let rx = 4.0 + Double(frame) * 3, ry = 1.5 + Double(frame) * 0.8
            let b = PixelBuffer(Int(rx * 2) + 3, Int(ry * 2) + 3)
            let cx = Double(b.w) / 2, cy = Double(b.h) / 2
            for i in 0..<64 {
                let a = Double(i) / 64 * .pi * 2
                b.set(Int(cx + cos(a) * rx), Int(cy + sin(a) * ry), PColor(0xFFFFFF, frame < 2 ? 230 : 140))
            }
            return b
        }
    }

    static func dot(_ c: PColor, _ w: Int = 1, _ h: Int = 1) -> SKTexture {
        Tex.get("dot|\(c.key)|\(w)|\(h)") { PixelBuffer(w, h, fill: c) }
    }
}

// MARK: - Home & town props

extension PropArt {
    static func house() -> SKTexture {
        Tex.get("house") {
            let b = PixelBuffer(68, 64)
            b.rect(2, 0, 64, 2, PColor(0x000000, 60))
            // stone base + walls
            b.rect(4, 2, 60, 5, PColor(0x8A8A94))
            for x in stride(from: 4, to: 64, by: 5) { b.rect(x, 2, 1, 5, PColor(0x6A6A74)) }
            b.rect(4, 7, 60, 22, PColor(0xE8D8B8))
            for y in stride(from: 9, to: 29, by: 4) { b.rect(4, y, 60, 1, PColor(0xD0BC98)) }
            // roof
            for row in 0..<28 {
                let inset = row * 11 / 28
                let y = 29 + row
                let c = (row / 4) % 2 == 0 ? PColor(0x3A6AB8) : PColor(0x4A7AC8)
                b.rect(1 + inset, y, 66 - inset * 2, 1, c)
                if row % 4 == 3 { b.rect(1 + inset, y, 66 - inset * 2, 1, PColor(0x2A4A8A)) }
            }
            b.rect(0, 28, 68, 2, PColor(0x1E3A6A))
            // chimney
            b.rect(48, 44, 8, 18, PColor(0x9A5A4A)); b.rect(47, 60, 10, 3, PColor(0x7A4A3A))
            for y in stride(from: 46, to: 60, by: 3) { b.rect(48, y, 8, 1, PColor(0x7A4A3A)) }
            // door
            b.rect(29, 2, 10, 18, PColor(0x5A3418)); b.rect(30, 3, 8, 16, PColor(0x9A5A2E))
            b.rect(30, 10, 8, 1, PColor(0x7A4422)); b.set(36, 9, PColor(0xFFD23A))
            b.rect(27, 20, 14, 2, PColor(0x5A3418))
            // windows with flower boxes
            for wx in [9, 47] {
                b.rect(wx, 12, 12, 11, PColor(0x5A3418))
                b.rect(wx + 1, 13, 10, 9, PColor(0x9AD8F2))
                b.rect(wx + 6, 13, 1, 9, PColor(0x5A3418)); b.rect(wx + 1, 17, 10, 1, PColor(0x5A3418))
                b.rect(wx - 1, 9, 14, 3, PColor(0x8A5A30))
                for i in 0..<6 { b.set(wx + i * 2, 12, [PColor(0xE84A6A), PColor(0xFFD23A), PColor(0xF0F0F0)][i % 3]) }
            }
            b.outline(PColor(0x2A1408))
            return b
        }
    }

    static func board() -> SKTexture {
        Tex.get("board") {
            let b = PixelBuffer(26, 26)
            b.rect(3, 0, 3, 18, PColor(0x6A3E1E)); b.rect(20, 0, 3, 18, PColor(0x6A3E1E))
            b.rect(0, 8, 26, 16, PColor(0x8A5A30)); b.rect(1, 9, 24, 14, PColor(0xB07A40))
            b.rect(0, 23, 26, 3, PColor(0x6A3E1E))
            b.rect(3, 12, 8, 9, PColor(0xF4E8C8)); b.rect(14, 11, 9, 10, PColor(0xF4E8C8))
            for y in [14, 16, 18] { b.rect(4, y, 6, 1, PColor(0x8A7A6A)); b.rect(15, y + 1, 7, 1, PColor(0x8A7A6A)) }
            b.set(7, 20, PColor(0xE83A3A)); b.set(18, 20, PColor(0xE83A3A))
            b.rect(16, 12, 5, 2, PColor(0xFFD23A))
            b.outline(PColor(0x2A1408))
            return b
        }
    }

    static func chest(open: Bool = false) -> SKTexture {
        Tex.get("chest|\(open)") {
            let b = PixelBuffer(16, 14)
            b.rect(1, 0, 14, 7, PColor(0xA0682E))
            b.rect(1, 7, 14, 1, PColor(0x5A3418))
            b.rect(1, 8, 14, 5, open ? PColor(0x3A2010) : PColor(0xB87A3A))
            b.rect(1, 12, 14, 1, PColor(0xD09050))
            b.rect(7, 5, 2, 4, PColor(0xFFD23A))
            b.rect(1, 0, 1, 13, PColor(0x7A4A20)); b.rect(14, 0, 1, 13, PColor(0x7A4A20))
            b.outline(PColor(0x2A1408))
            return b
        }
    }

    /// Interior room background (320x200).
    static func room() -> PixelBuffer {
        let b = PixelBuffer(320, 200)
        // floor planks
        for y in 0..<140 {
            for x in 0..<320 {
                let plank = (y / 10)
                let seam = (x + plank * 37) % 64 == 0 || y % 10 == 0
                var c = PColor(0xB8824A).shade(hrand(plank, (x + plank * 37) / 64, 3) * 0.1 - 0.05)
                if seam { c = PColor(0x8A5A2E) }
                b[x, y] = c
            }
        }
        // back wall with wallpaper
        for y in 140..<200 {
            for x in 0..<320 {
                var c = PColor(0xE8C8A0)
                if (x / 8 + y / 8) % 2 == 0 { c = PColor(0xDDB890) }
                if x % 16 == 8 && y % 16 == 8 { c = PColor(0xC89A70) }
                b[x, y] = c
            }
        }
        b.rect(0, 140, 320, 4, PColor(0x6A3E1E))
        b.rect(0, 144, 320, 2, PColor(0x8A5A30))
        b.rect(0, 194, 320, 6, PColor(0x6A3E1E))
        // rug
        b.ellipse(160, 70, 70, 34, PColor(0x8A2A3A))
        b.ellipse(160, 70, 64, 29, PColor(0xC84A4A))
        b.ellipse(160, 70, 50, 20, PColor(0xE8B85A))
        b.ellipse(160, 70, 40, 14, PColor(0xC84A4A))
        // door mat
        b.rect(146, 0, 28, 8, PColor(0x6A8A3A)); b.rect(148, 1, 24, 6, PColor(0x8AAA4A))
        // fireplace
        b.rect(132, 144, 56, 44, PColor(0x8A5A4A))
        for y in stride(from: 146, to: 188, by: 5) { b.rect(132, y, 56, 1, PColor(0x6A3E30)) }
        b.rect(144, 144, 32, 24, PColor(0x1A0E08))
        b.rect(128, 186, 64, 4, PColor(0x5A3418))
        return b
    }

    static func furniture(_ name: String) -> SKTexture {
        Tex.get("furn|\(name)") {
            switch name {
            case "bed":
                let b = PixelBuffer(46, 44)
                b.rect(0, 0, 46, 34, PColor(0x7A4A26)); b.rect(0, 30, 46, 14, PColor(0x6A3A1A))
                b.rect(2, 2, 42, 28, PColor(0x3A6AB8)); b.rect(2, 2, 42, 4, PColor(0x2A4A8A))
                for x in stride(from: 4, to: 44, by: 8) { b.rect(x, 6, 4, 20, PColor(0x4A7AC8)) }
                b.rect(6, 22, 34, 8, PColor(0xF4F0E8)); b.rect(8, 24, 12, 5, PColor(0xFFFFFF)); b.rect(26, 24, 12, 5, PColor(0xFFFFFF))
                b.outline(PColor(0x2A1408))
                return b
            case "wardrobe":
                let b = PixelBuffer(30, 46)
                b.rect(0, 0, 30, 46, PColor(0x8A5A30)); b.rect(2, 2, 12, 38, PColor(0xA0703C)); b.rect(16, 2, 12, 38, PColor(0xA0703C))
                b.rect(12, 18, 1, 6, PColor(0xFFD23A)); b.rect(17, 18, 1, 6, PColor(0xFFD23A))
                b.rect(0, 42, 30, 4, PColor(0x6A3E1E))
                b.outline(PColor(0x2A1408))
                return b
            case "shelf":
                let b = PixelBuffer(64, 10)
                b.rect(0, 4, 64, 3, PColor(0x6A3E1E)); b.rect(4, 0, 3, 5, PColor(0x5A3418)); b.rect(57, 0, 3, 5, PColor(0x5A3418))
                b.outline(PColor(0x2A1408))
                return b
            case "window":
                let b = PixelBuffer(36, 30)
                b.rect(0, 0, 36, 30, PColor(0x6A3E1E)); b.rect(2, 2, 32, 26, PColor(0x9AD8F2))
                b.rect(17, 2, 2, 26, PColor(0x6A3E1E)); b.rect(2, 14, 32, 2, PColor(0x6A3E1E))
                return b
            case "table":
                let b = PixelBuffer(36, 22)
                b.rect(0, 10, 36, 12, PColor(0xA0703C)); b.rect(0, 20, 36, 2, PColor(0xC08A50))
                b.rect(3, 0, 3, 10, PColor(0x6A3E1E)); b.rect(30, 0, 3, 10, PColor(0x6A3E1E))
                b.rect(14, 22, 8, 0, .clear)
                b.outline(PColor(0x2A1408))
                return b
            case "plant":
                let b = PixelBuffer(16, 24)
                b.rect(4, 0, 8, 8, PColor(0xC8683A)); b.rect(3, 7, 10, 2, PColor(0xA8542A))
                b.ellipse(8, 15, 6, 7, PColor(0x3E8A3A)); b.ellipse(5, 18, 3, 4, PColor(0x5AAA4A)); b.ellipse(11, 13, 3, 3, PColor(0x5AAA4A))
                b.outline(PColor(0x1E3A1E))
                return b
            case "fire":
                let b = PixelBuffer(24, 16)
                b.rect(2, 0, 20, 3, PColor(0x5A3418))
                b.ellipse(12, 7, 8, 6, PColor(0xE8743A)); b.ellipse(12, 6, 5, 4, PColor(0xFFC83A)); b.ellipse(12, 5, 2, 2, PColor(0xFFF4B0))
                return b
            default:
                return PixelBuffer(1, 1)
            }
        }
    }
}

// MARK: - Farming, goods, town & mine art

enum FarmArt {
    static func soil(watered: Bool) -> SKTexture {
        Tex.get("soil|\(watered)") {
            let b = PixelBuffer(16, 16)
            let base = watered ? PColor(0x5A3A22) : PColor(0x8A5A34)
            for y in 0..<16 { for x in 0..<16 { b[x, y] = hrand(x, y, watered ? 81 : 80) < 0.15 ? base.shade(-0.15) : base } }
            for y in [3, 8, 13] { b.rect(1, y, 14, 1, base.shade(-0.25)) }
            b.rect(0, 0, 16, 1, base.shade(-0.3)); b.rect(0, 15, 16, 1, base.shade(0.12))
            return b
        }
    }

    static func crop(_ c: Crop, stage: Int, dead: Bool) -> SKTexture {
        Tex.get("crop|\(c.id)|\(stage)|\(dead)") {
            let b = PixelBuffer(16, 22)
            let leaf = dead ? PColor(0x8A7A4A) : PColor(c.leaf), fruit = PColor(c.fruit)
            switch stage {
            case 0:
                b.set(5, 3, PColor(0x3A2A18)); b.set(9, 4, PColor(0x3A2A18)); b.set(7, 2, leaf)
            case 1:
                b.rect(7, 2, 2, 4, leaf); b.rect(5, 5, 2, 2, leaf); b.rect(9, 5, 2, 2, leaf)
            case 2:
                b.rect(7, 2, 2, 8, leaf); b.ellipse(5, 8, 3, 2, leaf); b.ellipse(11, 9, 3, 2, leaf); b.ellipse(8, 11, 3, 2, leaf.shade(0.15))
            default:
                switch c.style {
                case 0: // root veg poking out
                    b.ellipse(8, 4, 4, 3, fruit); b.set(6, 5, fruit.shade(0.3))
                    for (dx, h) in [(-3, 8), (0, 10), (3, 8)] { b.line(8, 6, 8 + dx, 6 + h, leaf, thick: 2) }
                case 1: // bush with berries
                    b.ellipse(8, 8, 6, 6, leaf); b.ellipse(8, 9, 4, 4, leaf.shade(0.15))
                    for (x, y) in [(5, 7), (10, 10), (8, 5), (11, 6), (5, 11)] { b.rect(x, y, 2, 2, fruit) }
                case 2: // corn stalk
                    b.rect(7, 1, 2, 20, leaf); b.line(8, 8, 3, 13, leaf, thick: 2); b.line(8, 12, 13, 17, leaf, thick: 2)
                    b.ellipse(11, 10, 2, 4, fruit); b.rect(7, 19, 2, 2, PColor(0xC8A040))
                case 3: // gourd
                    b.line(2, 9, 14, 11, leaf); b.ellipse(8, 5, 6.5, 4.5, fruit); b.rect(4, 2, 1, 6, fruit.shade(-0.15)); b.rect(11, 2, 1, 6, fruit.shade(-0.15))
                    b.rect(7, 9, 2, 3, PColor(0x5A4A2A)); b.set(5, 7, fruit.shade(0.35))
                default: // leafy kale
                    for (x, y) in [(5.0, 7.0), (11, 7), (8, 10), (8, 5)] { b.ellipse(x, y, 3.5, 3.5, fruit) }
                    b.ellipse(8, 8, 2, 2, fruit.shade(0.25))
                }
            }
            b.outline(PColor(0x1E2A14, 200))
            return b
        }
    }
}

enum GoodArt {
    static func icon(_ id: String) -> SKTexture {
        Tex.get("good|\(id)") {
            let b = PixelBuffer(18, 18)
            guard let g = Good.byID[id] else { return b }
            let a = PColor(g.c1), c = PColor(g.c2)
            switch g.cat {
            case .produce:
                if let crop = Crop.byID[String(id.dropFirst(5))] {
                    switch crop.style {
                    case 0: b.ellipse(9, 7, 4, 5.5, a); b.line(9, 12, 6, 16, c, thick: 2); b.line(9, 12, 12, 16, c, thick: 2); b.set(7, 8, a.shade(0.35))
                    case 1: for (x, y) in [(6.0, 7.0), (11, 7), (8.5, 11), (8.5, 4)] { b.ellipse(x, y, 3, 3, a) }; b.rect(8, 13, 2, 3, c)
                    case 2: b.ellipse(9, 9, 3.5, 7, a); b.line(6, 3, 4, 14, c, thick: 2); b.line(12, 3, 14, 14, c, thick: 2)
                    case 3: b.ellipse(9, 8, 7, 6, a); b.rect(5, 3, 1, 10, a.shade(-0.15)); b.rect(12, 3, 1, 10, a.shade(-0.15)); b.rect(8, 13, 2, 3, PColor(0x5A4A2A))
                    default: for (x, y) in [(6.0, 8.0), (12, 8), (9, 12), (9, 5)] { b.ellipse(x, y, 4, 4, a) }
                    }
                }
            case .seed:
                b.rect(3, 1, 12, 15, PColor(0xE8D8B0)); b.rect(3, 13, 12, 3, PColor(0xC8A870))
                b.ellipse(9, 7, 3.5, 3.5, a); b.rect(8, 3, 2, 2, c)
            case .timber:
                b.rect(2, 5, 14, 8, a); b.ellipse(15, 9, 2.5, 4, PColor(0xD8B07A)); b.ellipse(15, 9, 1.2, 2, PColor(0xB08A5A))
                b.rect(2, 7, 12, 1, c); b.rect(2, 11, 12, 1, c)
            case .ore:
                b.ellipse(9, 7, 7, 6, a); b.ellipse(7, 9, 3, 2, a.shade(0.2))
                for (x, y) in [(6, 6), (11, 9), (9, 4), (12, 5), (5, 9)] { b.rect(x, y, 2, 2, c) }
            case .gem:
                b.polygon([(9, 16), (16, 9), (13, 3), (5, 3), (2, 9)], a); b.polygon([(9, 16), (12, 9), (6, 9)], c)
                b.set(6, 5, .white); b.set(7, 6, .white)
            case .bar:
                b.polygon([(2, 3), (16, 3), (13, 10), (5, 10)], a); b.rect(5, 9, 8, 1, a.shade(0.35)); b.rect(2, 3, 14, 1, c)
            case .food:
                switch id {
                case "food.coffee":
                    b.rect(4, 2, 9, 11, c); b.rect(5, 11, 7, 2, a); b.rect(13, 5, 3, 5, c); b.line(7, 14, 8, 17, PColor(0xC8C8C8))
                case "food.bread":
                    b.ellipse(9, 7, 7.5, 5, a); b.ellipse(9, 8, 6, 3.5, c); for x in [5, 9, 13] { b.line(x, 6, x + 2, 10, a.shade(-0.2)) }
                default:
                    b.ellipse(9, 4, 8, 3, PColor(0xF4F4F0)); b.rect(4, 5, 10, 8, a); b.rect(4, 11, 10, 2, c); b.set(9, 14, PColor(0xE84A3A))
                }
            case .dish:
                b.ellipse(9, 6, 8, 3.5, PColor(0xF4F4F0)); b.ellipse(9, 6.5, 6, 2.5, PColor(0xD8D8D0))
                b.ellipse(9, 9, 5, 3.5, a); b.ellipse(7, 10, 2, 1.5, c); b.ellipse(12, 9, 1.5, 1.5, c)
            case .tool:
                if id == "tool.welder" {
                    b.rect(2, 2, 14, 10, a); b.rect(4, 8, 4, 2, c); b.rect(10, 5, 4, 4, PColor(0x2A2A34)); b.line(14, 12, 16, 16, PColor(0x2A2A34))
                } else {
                    b.polygon([(3, 4), (9, 10), (7, 12), (1, 6)], PColor(0x5A5A64)); b.rect(10, 3, 6, 3, a); b.set(9, 9, PColor(0xFFD23A)); b.set(11, 10, PColor(0xFF8A2A))
                }
            }
            b.outline(PColor(0x2A1408))
            return b
        }
    }
}

extension PropArt {
    static func building(_ k: BuildingKind, variant: Int = 0) -> SKTexture {
        if k == .villa { return villa(variant) }
        switch k {
        case .tackle: return shop()
        case .house: return house()
        default: break
        }
        return Tex.get("bld|\(k.rawValue)") {
            switch k {
            case .general:
                let b = PixelBuffer(84, 64)
                b.rect(2, 0, 80, 2, PColor(0x000000, 60))
                b.rect(4, 2, 76, 28, PColor(0xE8D0A8))
                for x in stride(from: 4, to: 80, by: 8) { b.rect(x, 2, 1, 28, PColor(0xC8B088)) }
                for row in 0..<26 {
                    let inset = row * 12 / 26
                    b.rect(1 + inset, 30 + row, 82 - inset * 2, 1, (row / 4) % 2 == 0 ? PColor(0x4E8A3A) : PColor(0x5E9A4A))
                    if row % 4 == 3 { b.rect(1 + inset, 30 + row, 82 - inset * 2, 1, PColor(0x2E5A22)) }
                }
                b.rect(0, 29, 84, 2, PColor(0x2E5A22))
                b.rect(36, 2, 12, 18, PColor(0x5A3418)); b.rect(37, 3, 10, 16, PColor(0x9AD8F2)); b.rect(41, 3, 2, 16, PColor(0x5A3418))
                for wx in [8, 58] {
                    b.rect(wx, 8, 18, 12, PColor(0x5A3418)); b.rect(wx + 1, 9, 16, 10, PColor(0x9AD8F2))
                    b.rect(wx + 1, 9, 16, 3, PColor(0xE84A4A)); for i in stride(from: 0, to: 16, by: 4) { b.rect(wx + 1 + i, 9, 2, 3, PColor(0xF0F0F0)) }
                }
                b.rect(22, 21, 40, 9, PColor(0x5A3418)); b.rect(23, 22, 38, 7, PColor(0xF2E8C8))
                b.blit(PixelFont.render("TOOLS", color: PColor(0x2E5A22), shadow: nil, align: .left), 30, 22)
                b.rect(66, 2, 5, 6, PColor(0x8A5A30)); b.rect(72, 2, 6, 5, PColor(0xC89A5A))
                b.outline(PColor(0x2A1408))
                return b
            case .cottageA, .cottageB, .cottageC:
                let roof = [BuildingKind.cottageA: 0xB8442E, .cottageB: 0x6A5AA8, .cottageC: 0xC89A2A][k]!
                let wall = [BuildingKind.cottageA: 0xF0E0C0, .cottageB: 0xD8E8E0, .cottageC: 0xE8D0D8][k]!
                let b = PixelBuffer(68, 58)
                b.rect(2, 0, 64, 2, PColor(0x000000, 60))
                b.rect(4, 2, 60, 24, PColor(UInt32(wall)))
                for row in 0..<28 {
                    let inset = row * 13 / 28
                    b.rect(1 + inset, 26 + row, 66 - inset * 2, 1, (row / 4) % 2 == 0 ? PColor(UInt32(roof)) : PColor(UInt32(roof)).shade(0.1))
                }
                b.rect(0, 25, 68, 2, PColor(UInt32(roof)).shade(-0.35))
                b.rect(29, 2, 10, 16, PColor(0x6A3A1A)); b.set(36, 9, PColor(0xFFD23A))
                for wx in [9, 47] { b.rect(wx, 9, 12, 10, PColor(0x5A3418)); b.rect(wx + 1, 10, 10, 8, PColor(0x9AD8F2)); b.rect(wx + 6, 10, 1, 8, PColor(0x5A3418)) }
                do {
                    let word = k == .cottageA ? "STYLE" : (k == .cottageB ? "FOOD" : "HOME")
                    b.rect(22, 19, 24, 8, PColor(0x5A3418)); b.rect(23, 20, 22, 6, PColor(0xF2E8C8))
                    b.blit(PixelFont.render(word, color: PColor(UInt32(roof)).shade(-0.2), shadow: nil, align: .left).crop(0, 1, 30, 7), 24, 19)
                }
                b.outline(PColor(0x2A1408))
                return b
            case .mine:
                let b = PixelBuffer(52, 40)
                b.ellipse(26, 14, 24, 20, PColor(0x6A665E))
                b.rect(10, 0, 32, 30, PColor(0x1A1410))
                b.rect(8, 0, 4, 32, PColor(0x8A5A30)); b.rect(40, 0, 4, 32, PColor(0x8A5A30)); b.rect(6, 30, 40, 5, PColor(0x8A5A30))
                b.rect(6, 30, 40, 1, PColor(0xB07A40))
                b.line(14, 2, 24, 10, PColor(0x5A5A64)); b.rect(30, 1, 8, 5, PColor(0x6A4A2A)); b.rect(31, 6, 2, 2, PColor(0x3A3A44)); b.rect(36, 6, 2, 2, PColor(0x3A3A44))
                b.outline(PColor(0x1A1410))
                return b
            case .boatShed:
                let b = PixelBuffer(68, 52)
                b.rect(2, 0, 64, 2, PColor(0x000000, 60))
                b.rect(4, 2, 60, 26, PColor(0x6A8AA8))
                for x in stride(from: 4, to: 64, by: 6) { b.rect(x, 2, 1, 26, PColor(0x4A6A88)) }
                for row in 0..<22 { let inset = row * 10 / 22; b.rect(1 + inset, 28 + row, 66 - inset * 2, 1, row % 3 == 2 ? PColor(0x5A5E66) : PColor(0x8A8E96)) }
                b.rect(14, 2, 40, 20, PColor(0x3A4A5A)); for y in stride(from: 4, to: 22, by: 3) { b.rect(14, y, 40, 1, PColor(0x5A6A7A)) }
                b.rect(18, 22, 32, 6, PColor(0xF2E8C8)); b.blit(PixelFont.render("BOATS", color: PColor(0x2A4A8A), shadow: nil, align: .left), 20, 22)
                b.outline(PColor(0x2A1408))
                return b
            case .autos:
                let b = PixelBuffer(84, 60)
                b.rect(2, 0, 80, 2, PColor(0x000000, 60))
                b.rect(4, 2, 76, 30, PColor(0xD8D8E0))
                b.rect(4, 30, 76, 6, PColor(0xC83A3A)); for x in stride(from: 4, to: 80, by: 8) { b.rect(x, 30, 4, 6, PColor(0xF0F0F0)) }
                b.rect(2, 36, 80, 4, PColor(0x5A5E66))
                b.rect(10, 2, 30, 22, PColor(0x3A3A44)); for y in stride(from: 4, to: 24, by: 3) { b.rect(10, y, 30, 1, PColor(0x5A5A64)) }
                b.rect(48, 8, 26, 14, PColor(0x9AD8F2)); b.rect(60, 8, 1, 14, PColor(0x5A5E66))
                b.rect(22, 42, 40, 10, PColor(0x2A2A34)); b.blit(PixelFont.render("AUTOS", color: PColor(0xFFD23A), shadow: nil, align: .left), 28, 43)
                b.outline(PColor(0x1A1A20))
                return b
            case .shed:
                let b = PixelBuffer(52, 48)
                b.rect(2, 0, 48, 2, PColor(0x000000, 60))
                b.rect(4, 2, 44, 22, PColor(0x8A6A4A))
                for x in stride(from: 4, to: 48, by: 5) { b.rect(x, 2, 1, 22, PColor(0x6A4A2A)) }
                for row in 0..<20 {
                    let inset = row * 9 / 20
                    b.rect(1 + inset, 24 + row, 50 - inset * 2, 1, row % 3 == 2 ? PColor(0x5A5E66) : PColor(0x8A8E96))
                }
                b.rect(19, 2, 14, 16, PColor(0x5A5E66)); b.rect(20, 3, 12, 14, PColor(0x7A7E86))
                for y in [6, 10, 14] { b.rect(20, y, 12, 1, PColor(0x5A5E66)) }
                b.rect(14, 19, 24, 7, PColor(0x3A3A44)); b.blit(PixelFont.render("WELD", color: PColor(0xFFD23A), shadow: nil, align: .left), 16, 19)
                b.rect(38, 8, 6, 6, PColor(0x9AD8F2)); b.rect(40, 30, 4, 12, PColor(0x5A5A64))
                b.outline(PColor(0x2A1408))
                return b
            case .fountain:
                let b = PixelBuffer(36, 36)
                b.ellipse(18, 12, 17, 10, PColor(0xA8A098)); b.ellipse(18, 13, 14, 7.5, PColor(0x4AA0DC))
                b.rect(16, 13, 4, 14, PColor(0xC0B8A8)); b.ellipse(18, 27, 6, 3, PColor(0xC0B8A8))
                b.rect(17, 28, 2, 6, PColor(0x8AD0F2)); b.set(15, 31, PColor(0x8AD0F2)); b.set(21, 30, PColor(0x8AD0F2))
                b.outline(PColor(0x3A342C))
                return b
            default:
                return PixelBuffer(1, 1)
            }
        }
    }
}

enum MineArt {
    enum Rock: Int { case stone, coal, copper, iron, gold, gem }

    static func rock(_ r: Rock, gem: String = "quartz", variant: Int = 0) -> SKTexture {
        Tex.get("rock|\(r.rawValue)|\(gem)|\(variant % 3)") {
            let b = PixelBuffer(16, 14)
            let base = PColor(r == .coal ? 0x4A4A50 : 0x8E8A84).shade(Double(variant % 3) * 0.05 - 0.05)
            b.ellipse(8, 6.5, 7.5, 6.5, base)
            b.ellipse(6, 9, 4, 3, base.shade(0.18))
            b.rect(2, 1, 12, 2, base.shade(-0.25))
            let speck: PColor?
            switch r {
            case .stone: speck = nil
            case .coal: speck = PColor(0x1A1A1E)
            case .copper: speck = PColor(0xE8823A)
            case .iron: speck = PColor(0xD8B89A)
            case .gold: speck = PColor(0xFFD23A)
            case .gem: speck = PColor(Good.byID[gem]?.c1 ?? 0xFFFFFF)
            }
            if let s = speck {
                for (x, y) in [(5, 6), (10, 8), (8, 3), (11, 4), (4, 9), (7, 10)] { b.rect(x, y, 2, 2, s) }
                if r == .gem { b.set(8, 9, .white); b.set(11, 5, .white) }
            }
            b.outline(PColor(0x2A2620))
            return b
        }
    }

    static func ladder(down: Bool) -> SKTexture {
        Tex.get("ladder|\(down)") {
            let b = PixelBuffer(16, 16)
            if down { b.rect(1, 1, 14, 14, PColor(0x0E0A08)) }
            b.rect(3, 0, 2, 16, PColor(0x8A5A30)); b.rect(11, 0, 2, 16, PColor(0x8A5A30))
            for y in stride(from: 2, to: 16, by: 4) { b.rect(3, y, 10, 2, PColor(0xB07A40)) }
            return b
        }
    }

    static func floor(level: Int) -> PixelBuffer {
        // 40 x 22 tiles of 16px
        let b = PixelBuffer(640, 352)
        let base = level >= 15 ? PColor(0x5A4A5A) : (level >= 8 ? PColor(0x6A5A4A) : PColor(0x7A6E5E))
        for y in 0..<352 { for x in 0..<640 {
            let n = hrand(x, y, level &* 7 &+ 3)
            b[x, y] = n < 0.06 ? base.shade(-0.15) : (n < 0.1 ? base.shade(0.1) : base)
        } }
        return b
    }
}

extension PropArt {
    static func stove(lit: Bool) -> SKTexture {
        Tex.get("stove|\(lit)") {
            let b = PixelBuffer(30, 34)
            b.rect(0, 0, 30, 26, PColor(0x3A3A44)); b.rect(2, 2, 26, 22, PColor(0x4A4A56))
            b.rect(6, 4, 18, 12, PColor(0x1A1A20))
            if lit { b.ellipse(15, 9, 7, 4.5, PColor(0xE8743A)); b.ellipse(15, 8, 4, 3, PColor(0xFFD23A)) }
            b.rect(0, 24, 30, 3, PColor(0x5A5A66))
            b.ellipse(8, 28, 4, 1.5, PColor(0x2A2A30)); b.ellipse(22, 28, 4, 1.5, PColor(0x2A2A30))
            b.rect(24, 27, 4, 7, PColor(0x3A3A44))
            b.outline(PColor(0x141418))
            return b
        }
    }

    static func welder() -> SKTexture {
        Tex.get("welderprop") {
            let b = PixelBuffer(30, 28)
            b.rect(0, 0, 30, 20, PColor(0x5A6A8A)); b.rect(2, 2, 26, 16, PColor(0x6A7A9A))
            b.rect(4, 12, 8, 4, PColor(0xFFD23A)); b.rect(16, 6, 9, 9, PColor(0x2A2A34)); b.ellipse(20.5, 10.5, 3, 3, PColor(0x8AA0C8))
            b.rect(2, 20, 26, 3, PColor(0x3A3A44)); b.line(26, 23, 29, 27, PColor(0x2A2A34))
            b.outline(PColor(0x141418))
            return b
        }
    }
}

enum ToolArt {
    static func icon(_ k: ToolKind, level: Int) -> SKTexture {
        Tex.get("tool|\(k.rawValue)|\(level)") {
            let b = PixelBuffer(18, 18)
            let metal = PColor(Tools.colors[level]), handle = PColor(0x8A5A30)
            b.line(3, 1, 13, 15, handle, thick: 2)
            switch k {
            case .axe:
                b.polygon([(10, 11), (16, 15), (17, 9), (12, 8)], metal); b.rect(15, 9, 1, 6, metal.shade(0.35))
            case .pickaxe:
                b.line(5, 14, 16, 11, metal, thick: 2); b.line(16, 11, 17, 8, metal); b.line(5, 14, 3, 12, metal)
            case .hoe:
                b.rect(10, 13, 7, 3, metal); b.rect(15, 9, 2, 5, metal); b.rect(10, 15, 7, 1, metal.shade(0.35))
            }
            b.outline(PColor(0x2A1408))
            return b
        }
    }
}

extension PropArt {
    static func decor(_ id: String) -> SKTexture {
        Tex.get("decor|\(id)") {
            switch id {
            case "decor.bookshelf":
                let b = PixelBuffer(24, 40)
                b.rect(0, 0, 24, 40, PColor(0x6A3E1E)); b.rect(2, 2, 20, 36, PColor(0x4A2A12))
                for (row, y) in [4, 16, 28].enumerated() {
                    b.rect(2, y - 2, 20, 2, PColor(0x8A5A30))
                    var x = 3
                    while x < 21 { let w = 2 + Int(hrand(x, row, 3) * 2); b.rect(x, y, w, 9, [PColor(0xC83A3A), PColor(0x3A6AB8), PColor(0x4E8A3A), PColor(0xE8C05A)][(x + row) % 4]); x += w + 1 }
                }
                b.outline(PColor(0x2A1408)); return b
            case "decor.armchair":
                let b = PixelBuffer(22, 24)
                b.rect(0, 0, 22, 14, PColor(0x8A2A3A)); b.rect(3, 12, 16, 12, PColor(0xA83A4A)); b.rect(0, 8, 4, 10, PColor(0x6A1E2A)); b.rect(18, 8, 4, 10, PColor(0x6A1E2A))
                b.rect(4, 8, 14, 4, PColor(0xC85A6A)); b.outline(PColor(0x2A1408)); return b
            case "decor.tank":
                let b = PixelBuffer(40, 32)
                b.rect(0, 0, 40, 8, PColor(0x6A3E1E)); b.rect(1, 8, 38, 22, PColor(0x4AA0DC, 230)); b.rect(1, 28, 38, 2, PColor(0x8AD0F2))
                b.rect(1, 8, 38, 3, PColor(0xD8C08A)); for x in [6, 12, 30] { b.rect(x, 11, 1, 8, PColor(0x3E8A3A)) }
                b.rect(0, 30, 40, 2, PColor(0x3A3A44)); b.outline(PColor(0x1A1A20)); return b
            case "decor.lamp":
                let b = PixelBuffer(12, 34)
                b.rect(5, 0, 2, 24, PColor(0x3A3A44)); b.rect(2, 0, 8, 2, PColor(0x3A3A44)); b.polygon([(1, 24), (11, 24), (8, 33), (4, 33)], PColor(0xF2D28A))
                b.outline(PColor(0x1A1A20)); return b
            case "decor.painting":
                let b = PixelBuffer(28, 22)
                b.rect(0, 0, 28, 22, PColor(0xC8961E)); b.rect(2, 2, 24, 18, PColor(0xFFC8A0)); b.rect(2, 2, 24, 7, PColor(0x3C8DC8))
                b.triangle((4, 9), (12, 18), (20, 9), PColor(0x4E7A5A)); b.ellipse(20, 15, 3, 3, PColor(0xFFE08A)); return b
            case "decor.fern":
                let b = PixelBuffer(16, 24)
                b.rect(4, 0, 8, 7, PColor(0x3A6AB8)); for (dx, dy) in [(-6, 14), (-3, 17), (0, 18), (3, 17), (6, 14)] { b.line(8, 7, 8 + dx, 7 + dy, PColor(0x3E9A3A), thick: 2) }
                b.outline(PColor(0x1E3A1E)); return b
            case "decor.radio":
                let b = PixelBuffer(16, 11)
                b.rect(0, 0, 16, 10, PColor(0x8A5A30)); b.ellipse(5, 5, 3, 3, PColor(0x3A2A1A)); b.rect(10, 3, 4, 2, PColor(0xE8C05A)); b.line(13, 10, 15, 14, PColor(0x3A3A44))
                b.outline(PColor(0x2A1408)); return b
            default: return PixelBuffer(1, 1)
            }
        }
    }

    static func fridge() -> SKTexture {
        Tex.get("fridge") {
            let b = PixelBuffer(22, 36)
            b.rect(0, 0, 22, 36, PColor(0xE8ECF0)); b.rect(0, 22, 22, 1, PColor(0xA8B0B8)); b.rect(18, 25, 2, 8, PColor(0x8A9098)); b.rect(18, 12, 2, 8, PColor(0x8A9098))
            b.rect(1, 34, 20, 2, PColor(0xFFFFFF)); b.rect(3, 26, 5, 4, PColor(0xE84A4A))
            b.outline(PColor(0x3A4048)); return b
        }
    }

    static func freezer() -> SKTexture {
        Tex.get("freezerprop") {
            let b = PixelBuffer(28, 24)
            b.rect(0, 0, 28, 20, PColor(0xD8E8F4)); b.rect(0, 18, 28, 6, PColor(0xB8D0E4)); b.rect(10, 16, 8, 2, PColor(0x6A8AA8))
            for (x, y) in [(4, 6), (20, 9), (14, 4)] { b.set(x, y, PColor(0x8AC8F2)); b.set(x + 1, y + 1, .white) }
            b.outline(PColor(0x3A4A5A)); return b
        }
    }
}

extension PropArt {
    static func villa(_ v: Int) -> SKTexture {
        Tex.get("villa|\(v)") {
            let roofs: [UInt32] = [0x8A4A8A, 0x3A8A6A, 0xC86A2A, 0x5A6AB8, 0xA83A3A]
            let walls: [UInt32] = [0xF2E2C8, 0xE8E0D0, 0xF0D8C0, 0xE0E8F0, 0xF4ECD8]
            let roof = PColor(roofs[v % 5]), wall = PColor(walls[v % 5])
            let b = PixelBuffer(68, 58)
            b.rect(2, 0, 64, 2, PColor(0x000000, 60))
            b.rect(4, 2, 60, 24, wall)
            for y in stride(from: 6, to: 26, by: 5) { b.rect(4, y, 60, 1, wall.shade(-0.08)) }
            for row in 0..<28 {
                let inset = row * 13 / 28
                b.rect(1 + inset, 26 + row, 66 - inset * 2, 1, (row / 4) % 2 == 0 ? roof : roof.shade(0.1))
            }
            b.rect(0, 25, 68, 2, roof.shade(-0.35))
            b.rect(28 + (v % 2) * 4, 2, 10, 16, PColor(0x6A3A1A)); b.set(35 + (v % 2) * 4, 9, PColor(0xFFD23A))
            for wx in [8, 48] { b.rect(wx, 9, 12, 10, PColor(0x5A3418)); b.rect(wx + 1, 10, 10, 8, PColor(0x9AD8F2)); b.rect(wx + 6, 10, 1, 8, PColor(0x5A3418)) }
            for i in 0..<5 { b.set(9 + i * 2, 8, [PColor(0xE84A6A), PColor(0xFFD23A), PColor(0xF0F0F0)][(i + v) % 3]) }
            if v % 2 == 0 { b.rect(50, 46, 6, 10, PColor(0x9A5A4A)) }
            b.outline(PColor(0x2A1408))
            return b
        }
    }
}

enum CarArt {
    static func side(_ c: Car) -> SKTexture {
        Tex.get("car.side|\(c.id)") {
            let b = PixelBuffer(38, 20)
            let body = PColor(c.body)
            switch c.id {
            case "car.coupe":
                b.polygon([(1, 4), (37, 4), (37, 8), (28, 12), (12, 12), (4, 8)], body)
                b.polygon([(13, 11), (26, 11), (22, 15), (16, 15)], PColor(0x9AD8F2))
            case "car.truck", "car.pickup":
                b.rect(1, 4, 36, 7, body); b.rect(20, 10, 14, 8, body); b.rect(22, 12, 10, 4, PColor(0x9AD8F2))
                b.rect(2, 10, 17, 2, body.shade(-0.25))
            default:
                b.rect(2, 4, 34, 8, body); b.rect(10, 11, 22, 7, body.shade(-0.1)); b.rect(12, 13, 8, 4, PColor(0x9AD8F2)); b.rect(22, 13, 8, 4, PColor(0x9AD8F2))
                b.rect(1, 12, 2, 6, PColor(0x3A3A44))
            }
            b.rect(1, 6, 36, 1, body.shade(0.3))
            for wx in [8.0, 29.0] { b.ellipse(wx, 3.5, 3.5, 3.5, PColor(0x1A1A20)); b.ellipse(wx, 3.5, 1.5, 1.5, PColor(0xA8A8B0)) }
            b.rect(35, 6, 2, 2, PColor(0xFFE08A))
            b.outline(PColor(0x14141A))
            return b
        }
    }

    static func top(_ c: Car) -> SKTexture {
        Tex.get("car.top|\(c.id)") {
            let b = PixelBuffer(20, 36)
            let body = PColor(c.body)
            b.rect(3, 2, 14, 32, body)
            b.rect(1, 6, 2, 6, PColor(0x1A1A20)); b.rect(17, 6, 2, 6, PColor(0x1A1A20)); b.rect(1, 24, 2, 6, PColor(0x1A1A20)); b.rect(17, 24, 2, 6, PColor(0x1A1A20))
            b.rect(5, 20, 10, 7, PColor(0x9AD8F2)); b.rect(5, 12, 10, 6, body.shade(-0.2))
            b.rect(5, 33, 3, 1, PColor(0xFFE08A)); b.rect(12, 33, 3, 1, PColor(0xFFE08A))
            b.outline(PColor(0x14141A))
            return b
        }
    }

    static func trailer(_ big: Bool) -> SKTexture {
        Tex.get("trailer|\(big)") {
            let b = PixelBuffer(big ? 30 : 22, 10)
            b.rect(0, 3, b.w - 3, 3, PColor(0x5A5E66)); b.rect(b.w - 4, 4, 4, 1, PColor(0x3A3A44))
            b.ellipse(Double(b.w) / 2 - 3, 2.5, 2.5, 2.5, PColor(0x1A1A20))
            b.outline(PColor(0x14141A))
            return b
        }
    }
}

/// Map car: body + optional trailer carrying the hitched boat.
final class CarNode: SKNode {
    let car: Car
    private let body = SKSpriteNode()
    private let trailer = SKSpriteNode()
    private let cargo = SKSpriteNode()
    private(set) var dir: Dir = .right

    init(car: Car) {
        self.car = car
        super.init()
        addChild(trailer)
        addChild(cargo)
        addChild(body)
        setDir(.right, force: true)
    }

    required init?(coder: NSCoder) { fatalError() }

    func setDir(_ d: Dir, force: Bool = false) {
        guard d != dir || force else { return }
        dir = d
        let s = Game.shared.save
        let towing = s.towProblem == nil ? s.boat : nil
        switch d {
        case .left, .right:
            body.setPixelTexture(CarArt.side(car), scale: 2)
            body.anchorPoint = CGPoint(x: 0.5, y: 0)
            body.xScale = d == .left ? -1 : 1
            body.position = .zero
        case .up, .down:
            body.setPixelTexture(CarArt.top(car), scale: 2)
            body.anchorPoint = CGPoint(x: 0.5, y: 0.2)
            body.xScale = 1
            body.yScale = d == .down ? -1 : 1
            body.position = .zero
        }
        if d == .left || d == .right { body.yScale = 1 }
        trailer.isHidden = towing == nil
        cargo.isHidden = towing == nil
        if let boat = towing {
            let back: CGFloat = d == .left ? 1 : (d == .right ? -1 : 0)
            let backY: CGFloat = d == .up ? -1 : (d == .down ? 1 : 0)
            trailer.setPixelTexture(CarArt.trailer(boat.big), scale: 2)
            trailer.anchorPoint = CGPoint(x: 0.5, y: 0)
            trailer.xScale = d == .left ? -1 : 1
            trailer.position = CGPoint(x: back * 62, y: backY * 70)
            cargo.setPixelTexture(BoatArt.side(boat.kind, front: true), scale: 1.2)
            cargo.anchorPoint = CGPoint(x: 0.5, y: 0)
            cargo.xScale = d == .left ? -1 : 1
            cargo.position = CGPoint(x: back * 62, y: backY * 70 + 8)
        }
    }
}
