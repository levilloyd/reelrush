import SpriteKit

final class FishingScene: BaseScene {
    private enum Phase { case aiming, casting, waiting, bite, reeling, result, escaped }

    let habitat: Habitat
    let boat: Boat?
    let school: Bool
    private let P: CGFloat = 4
    private let W = 320, H = 200
    private let waterY = 84
    private var phase: Phase = .aiming
    private var built = false
    private var lastTime: TimeInterval = 0
    private var clock = 0.0

    // Scene art
    private let bg = SKSpriteNode()
    private var bgKey = ""
    private var clouds: [SKSpriteNode] = []
    private let overlay = SKSpriteNode()
    private let overlayBuf = PixelBuffer(320, 200)
    private var overlayKey = ""
    private let playerSprite = SKSpriteNode()
    private let bobber = SKSpriteNode()
    private var feet = CGPoint.zero
    private var hand = CGPoint.zero
    private var tipRest = CGPoint.zero
    private var tip = CGPoint.zero
    private var bend: CGFloat = 0
    private var bobberPos = CGPoint.zero
    private var bobberDip: CGFloat = 0
    private var castX: CGFloat = 160
    private var castT = 0.0

    // Power meter
    private let powerNode = SKNode()
    private let powerFill = SKSpriteNode(color: .green, size: CGSize(width: 4, height: 24))
    private var power: CGFloat = 0
    private var powerDir: CGFloat = 1

    // Wait / bite
    private var waitElapsed = 0.0
    private var waitDuration = 0.0
    private var nibbles: [Double] = []
    private var biteTimeLeft = 0.0
    private var luck = 0.0
    private var hooked: FishSpecies?
    private var exclaim: PixelLabel?

    // Reel bar
    private let reelPanel = SKNode()
    private let chanX: CGFloat = 1144, chanBottom: CGFloat = 132, chanH: CGFloat = 472, progX: CGFloat = 1196
    private var catchBar = SKSpriteNode()
    private var fishIcon = SKSpriteNode()
    private let progressFill = SKSpriteNode(color: .green, size: CGSize(width: 16, height: 4))
    private var reelFrame = SKSpriteNode()
    private var barSize = 0.22, barPos = 0.0, barVel = 0.0
    private var fishPos = 0.5, fishVel = 0.0, fishTarget = 0.5, fishTimer = 0.0
    private var progress = 0.3
    private var perfect = true
    private var pendingT = 0.0
    private var pendingTrophy = false
    private var fightDifficulty = 0.5
    private var fightWeight = 1.0

    // UI
    private let message = PixelLabel("", scale: 4)
    private let hint = PixelLabel("", scale: 2)
    private let infoLabel = PixelLabel("", scale: 2, align: .left)
    private let coinLabel = PixelLabel("", scale: 3, color: .gold, align: .left)
    private let activityLabel = PixelLabel("", scale: 3, align: .right)
    private let gearLabel = PixelLabel("", scale: 2, align: .right)
    private let compLabel = PixelLabel("", scale: 2, color: .gold, align: .right)
    private var bonus: Bonuses { Game.shared.save.bonuses(habitat: habitat, onBoat: boat != nil) }
    private var card: SKNode?
    private var cardReadyAt = 0.0
    private var ambientTimer = 0.5

    // Atmosphere
    private let darkness = SKSpriteNode(color: .black, size: CGSize(width: 1280, height: 800))
    private let weatherLayer = SKNode()
    private var drops: [SKSpriteNode] = []
    private let flash = SKSpriteNode(color: .white, size: CGSize(width: 1280, height: 800))
    private var lightningTimer = 5.0
    private var shownWeather: Weather?

    init(habitat: Habitat, boat: Boat?, school: Bool) {
        self.habitat = habitat
        self.boat = boat
        self.school = school
        super.init(size: Game.sceneSize)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func pt(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * P, y: p.y * P) }

    override func sceneDidAppear() {
        lastTime = 0
        guard !built else { return }
        built = true
        backgroundColor = .black

        bg.anchorPoint = .zero
        bg.zPosition = 0
        addChild(bg)

        for i in 0..<3 {
            let c = pixelSprite(Tex.get("cloud|\(i)") { Icons.cloudBuffer(44 + i * 8, 16, seed: i + 10, base: PColor(0xFFFFFF), shade: PColor(0xD8E0EA)) }, scale: P)
            c.position = CGPoint(x: CGFloat(i) * 460 + CGFloat.random(in: 0...160), y: snap(CGFloat.random(in: 610...740), 4))
            c.zPosition = 1
            addChild(c)
            clouds.append(c)
        }
        refreshBackground(force: true)

        buildAngler()
        overlay.anchorPoint = .zero
        overlay.zPosition = 7
        addChild(overlay)

        bobber.setPixelTexture(PropArt.bobber(), scale: P)
        bobber.anchorPoint = CGPoint(x: 0.5, y: 0.35)
        bobber.zPosition = 8
        addChild(bobber)

        darkness.anchorPoint = .zero
        darkness.zPosition = 40
        addChild(darkness)
        weatherLayer.zPosition = 41
        addChild(weatherLayer)
        flash.anchorPoint = .zero
        flash.alpha = 0
        flash.zPosition = 42
        addChild(flash)

        buildUI()
        buildReelPanel()
        updateAtmosphere(0)
        startAiming()
        if school { bubbles() }
        if habitat == .hotspring {
            run(.repeatForever(.sequence([.run { [weak self] in
                guard let self else { return }
                let puff = SKSpriteNode(texture: Tex.glow())
                puff.size = CGSize(width: 120, height: 80)
                puff.alpha = 0.5
                puff.position = CGPoint(x: CGFloat.random(in: 320...1100), y: CGFloat(self.waterY) * self.P)
                puff.zPosition = 9
                self.addChild(puff)
                puff.run(.sequence([.group([.moveBy(x: CGFloat.random(in: -40...40), y: 180, duration: 3), .fadeOut(withDuration: 3), .scale(to: 1.8, duration: 3)]), .removeFromParent()]))
            }, .wait(forDuration: 0.35)])))
        }
    }

    // MARK: - Background painting

    private func refreshBackground(force: Bool = false) {
        let s = Game.shared.save
        let ph = Clock.phase(s.minutes)
        let key = "\(ph)|\(s.weather)"
        guard force || key != bgKey else { return }
        bgKey = key
        bg.setPixelTexture(paintBackground(ph, s.weather).texture(), scale: P)
        let cloudTint: PColor
        switch ph {
        case .night: cloudTint = PColor(0x3A4468)
        case .dusk: cloudTint = PColor(0xF2A08A)
        case .dawn: cloudTint = PColor(0xE8B8C8)
        case .day: cloudTint = .white
        }
        for c in clouds {
            c.color = (s.weather.isWet ? cloudTint.mix(PColor(0x7A8494), 0.6) : cloudTint).ns
            c.colorBlendFactor = (ph == .day && !s.weather.isWet) ? 0 : 1
            c.isHidden = s.weather == .fog || (s.weather == .sunny && c === clouds.last)
            if s.weather == .snow { c.color = PColor(0xC8D0DA).ns; c.colorBlendFactor = 0.6 }
        }
    }

    private func paintBackground(_ ph: SkyPhase, _ weather: Weather) -> PixelBuffer {
        let b = PixelBuffer(W, H)
        let wy = waterY
        var top: PColor, bot: PColor
        switch ph {
        case .day: top = PColor(0x4A98E0); bot = PColor(0xBCE4FF)
        case .dawn: top = PColor(0x5A6AB8); bot = PColor(0xFFC8A0)
        case .dusk: top = PColor(0x3A2E7A); bot = PColor(0xFF9050)
        case .night: top = PColor(0x080C24); bot = PColor(0x26345E)
        }
        switch weather {
        case .rain: top = top.mix(PColor(0x5A6474), 0.6); bot = bot.mix(PColor(0x8A94A4), 0.6)
        case .storm: top = top.mix(PColor(0x262E3C), 0.75); bot = bot.mix(PColor(0x4A5464), 0.7)
        case .fog: top = top.mix(PColor(0xC8CED6), 0.65); bot = bot.mix(PColor(0xE0E4E8), 0.7)
        case .cloudy: top = top.mix(PColor(0x8A98A8), 0.3); bot = bot.mix(PColor(0xC8D0D8), 0.3)
        case .snow: top = top.mix(PColor(0xA8B4C4), 0.6); bot = bot.mix(PColor(0xE8EEF4), 0.65)
        case .sunny: break
        }
        func tint(_ c: PColor) -> PColor {
            var r = c
            switch ph {
            case .night: r = r.mix(PColor(0x141C40), 0.6)
            case .dusk: r = r.mix(PColor(0x7A3A4A), 0.28)
            case .dawn: r = r.mix(PColor(0x8A6A9A), 0.2)
            case .day: break
            }
            if weather.isWet { r = r.mix(PColor(0x4A5464), weather == .storm ? 0.4 : 0.25) }
            if weather == .fog { r = r.mix(PColor(0xC8CED6), 0.45) }
            if weather == .snow { r = r.mix(PColor(0xE8EEF4), 0.3) }
            return r
        }
        let bayer = [[0, 2], [3, 1]]
        func gradient(_ y0: Int, _ y1: Int, _ from: PColor, _ to: PColor, levels: Double) {
            for y in y0..<y1 {
                let t = Double(y - y0) / Double(max(1, y1 - y0 - 1))
                let q = t * levels, lo = floor(q), frac = q - lo
                for x in 0..<W {
                    let thr = (Double(bayer[y % 2][x % 2]) + 0.5) / 4
                    b[x, y] = from.mix(to, (frac > thr ? lo + 1 : lo) / levels)
                }
            }
        }
        // Sky
        gradient(wy, H, bot, top, levels: 9)
        let cave = habitat == .cavern
        if cave {
            // Cave ceiling instead of sky: dark rock, stalactites, glowing crystals
            for y in wy..<H { for x in 0..<W {
                let n = hrand(x, y, 66)
                b[x, y] = PColor(0x2A2230).shade(Double(y - wy) / Double(H - wy) * -0.4 + (n < 0.08 ? 0.12 : 0))
            } }
            for i in 0..<22 {
                let x = Double(hrand(i, 67) * Double(W)), len = 10 + hrand(i, 68) * 40
                b.triangle((x - 4, Double(H)), (x, Double(H) - len), (x + 4, Double(H)), PColor(0x3A3040))
            }
            for i in 0..<14 {
                let x = Double(hrand(i, 69) * Double(W)), y = Double(wy) + 4 + hrand(i, 70) * 60
                let c = [PColor(0x8A6AFF), PColor(0x5AE8E8), PColor(0xE85AC8)][i % 3]
                b.ellipse(x, y, 7, 7, c.alpha(50))
                b.triangle((x - 3, y - 4), (x, y + 7), (x + 3, y - 4), c)
                b.set(Int(x), Int(y) + 2, .white)
            }
        }
        if ph == .night && weather != .fog && !weather.isWet && !cave {
            for i in 0..<80 {
                let x = Int(hrand(i, 1) * Double(W)), y = wy + 24 + Int(hrand(i, 2) * Double(H - wy - 24))
                b.set(x, y, PColor(0xFFFFFF, UInt8(120 + hrand(i, 3) * 135)))
                if hrand(i, 4) < 0.1 { b.set(x + 1, y, PColor(0xFFFFFF, 120)); b.set(x - 1, y, PColor(0xFFFFFF, 120)) }
            }
        }
        var celestial: (Double, Double, Double, PColor)?
        if (weather == .sunny || weather == .cloudy) && !cave {
            switch ph {
            case .day: celestial = (250, 168, 11, PColor(0xFFF2A8))
            case .dawn: celestial = (64, Double(wy) + 22, 12, PColor(0xFFC07A))
            case .dusk: celestial = (248, Double(wy) + 16, 14, PColor(0xFF8A4A))
            case .night: celestial = (238, 166, 9, PColor(0xF0F0E0))
            }
        }
        if let cel = celestial {
            let (cx, cy, r, c) = cel
            if ph != .night { b.ellipse(cx, cy, r + 3, r + 3, c.alpha(90)) }
            b.ellipse(cx, cy, r, r, c)
            if ph == .night {
                b.ellipse(cx + 3, cy + 2, 2, 2, PColor(0xC8C8B8))
                b.ellipse(cx - 3, cy - 3, 1.5, 1.5, PColor(0xC8C8B8))
            } else {
                b.ellipse(cx - r * 0.3, cy + r * 0.3, r * 0.35, r * 0.35, c.shade(0.4))
            }
        }

        // Far scenery
        switch habitat {
        case .pond, .lake:
            b.ellipse(40, Double(wy), 90, 26, tint(PColor(0x86C080)))
            b.ellipse(180, Double(wy), 120, 36, tint(PColor(0x6FA86A)))
            b.ellipse(310, Double(wy), 80, 22, tint(PColor(0x7FB87A)))
            var x = 70
            while x < W {
                let h = 10 + Int(hrand(x, 5) * 12)
                pine(b, x, wy, h, tint(PColor(0x2E6B3A)))
                x += 5 + Int(hrand(x, 6) * 8)
            }
        case .river:
            b.rect(0, wy, W, 8, tint(PColor(0x5DAE4E)))
            var x = 60
            while x < W {
                let r = 6 + hrand(x, 7) * 5
                b.rect(x - 1, wy + 4, 3, 10, tint(PColor(0x6B4626)))
                b.ellipse(Double(x), Double(wy) + 14 + r * 0.5, r, r * 0.9, tint(PColor(0x3E8A44).shade(hrand(x, 8) * 0.15 - 0.1)))
                x += 12 + Int(hrand(x, 9) * 10)
            }
        case .stream:
            for (mx, mw, mh) in [(70.0, 110.0, 80.0), (170, 140, 100), (270, 120, 84), (330, 100, 66)] {
                let fy = Double(wy)
                b.triangle((mx - mw / 2, fy), (mx, fy + mh), (mx + mw / 2, fy), tint(PColor(0x7A8496)))
                b.triangle((mx, fy), (mx, fy + mh), (mx + mw / 2, fy), tint(PColor(0x646E80)))
                let k = 0.3
                b.polygon([(mx - mw / 2 * k, fy + mh * (1 - k)), (mx, fy + mh), (mx + mw / 2 * k, fy + mh * (1 - k)),
                           (mx + 4, fy + mh * (1 - k) - 5), (mx - 3, fy + mh * (1 - k) + 1)], tint(PColor(0xF4F7FA)))
            }
            var x = 64
            while x < W { pine(b, x, wy, 8 + Int(hrand(x, 10) * 10), tint(PColor(0x2A5A3A))); x += 6 + Int(hrand(x, 11) * 8) }
        case .swamp:
            b.rect(0, wy, W, 5, tint(PColor(0x4A5A34)))
            var x = 70
            while x < W {
                let h = 18 + Int(hrand(x, 12) * 22)
                let c = tint(PColor(0x3A3A2E))
                b.rect(x, wy, 2, h, c)
                b.line(x, wy + h * 2 / 3, x - 6, wy + h - 2, c)
                b.line(x + 1, wy + h / 2, x + 7, wy + h - 6, c)
                for m in 0..<3 { b.rect(x - 4 + m * 4, wy + h - 10, 1, 5, tint(PColor(0x6A7A4A))) }
                x += 22 + Int(hrand(x, 13) * 20)
            }
            for x in stride(from: 0, to: W, by: 3) where hrand(x, 14) < 0.6 { b.rect(x, wy, 1, 3 + Int(hrand(x, 15) * 5), tint(PColor(0x5A6A34))) }
        case .ocean:
            b.ellipse(250, Double(wy), 34, 7, tint(PColor(0x4E8A5A)))
            b.rect(254, wy + 4, 1, 10, tint(PColor(0x6A5A3A)))
            b.line(254, wy + 14, 248, wy + 11, tint(PColor(0x3E7A3A)))
            b.line(254, wy + 14, 260, wy + 11, tint(PColor(0x3E7A3A)))
            b.triangle((150, Double(wy) + 2), (156, Double(wy) + 14), (156, Double(wy) + 2), tint(PColor(0xF0F0F0)))
            b.rect(148, wy, 12, 2, tint(PColor(0x8A5A3A)))
        case .lagoon:
            b.rect(110, wy, W - 110, 4, tint(PColor(0xEED7A1)))
            for (i, x) in [140, 180, 236, 290].enumerated() {
                let c = tint(PColor(0x8A6A3A)), g = tint(PColor(0x3E9A3A))
                for y in 0..<22 { b.set(x + Int(sin(Double(y) * 0.15 + Double(i)) * 2), wy + 3 + y, c) }
                let fx = x + Int(sin(22 * 0.15 + Double(i)) * 2), fy = wy + 25
                for (dx, dy) in [(-9, -4), (-7, 2), (0, 5), (7, 2), (9, -4)] { b.line(fx, fy, fx + dx, fy + dy, g) }
            }
        case .deepSea:
            let fy = Double(wy)
            b.polygon([(200, fy + 1), (238, fy + 1), (243, fy + 7), (195, fy + 7)], tint(PColor(0x2A3A55)))
            b.rect(212, wy + 7, 14, 6, tint(PColor(0x2A3A55)))
            b.rect(219, wy + 13, 2, 8, tint(PColor(0x2A3A55)))
        case .alpine:
            for (mx, mw, mh) in [(40.0, 160.0, 105.0), (160, 200, 115), (290, 170, 100)] {
                let fy = Double(wy)
                b.triangle((mx - mw / 2, fy), (mx, fy + mh), (mx + mw / 2, fy), tint(PColor(0x8A94A6)))
                b.triangle((mx, fy), (mx, fy + mh), (mx + mw / 2, fy), tint(PColor(0x6E7890)))
                b.polygon([(mx - mw * 0.2, fy + mh * 0.6), (mx, fy + mh), (mx + mw * 0.2, fy + mh * 0.6), (mx + 6, fy + mh * 0.55), (mx - 5, fy + mh * 0.62)], tint(PColor(0xF8FAFC)))
            }
            b.rect(0, wy, W, 4, tint(PColor(0x6AAA5A)))
            var x = 70
            while x < W { pine(b, x, wy, 9 + Int(hrand(x, 16) * 9), tint(PColor(0x2A5A3A))); x += 9 + Int(hrand(x, 17) * 12) }
        case .cavern:
            break
        case .waterfall:
            let fy = Double(wy)
            b.rect(0, wy, W, 70, tint(PColor(0x7A808C)))
            for i in 0..<30 { b.ellipse(hrand(i, 50) * Double(W), fy + 10 + hrand(i, 51) * 60, 10, 6, tint(PColor(0x8E95A3).shade(hrand(i, 52) * 0.2 - 0.1))) }
            for x in 150..<190 {
                for y in wy..<(wy + 70) {
                    let stripe = (x + y / 2 + Int(hrand(x, 53) * 4)) % 5
                    b[x, y] = tint(stripe == 0 ? PColor(0xFFFFFF) : PColor(0x9AD8F2).shade(Double(stripe) * 0.05))
                }
            }
            b.ellipse(170, fy + 2, 34, 8, tint(PColor(0xF0F8FF)))
            for x in stride(from: 10, to: W, by: 18) where x < 140 || x > 200 { pine(b, x, wy + 66, 12 + Int(hrand(x, 54) * 10), tint(PColor(0x2A5A3A))) }
        case .hotspring:
            let fy = Double(wy)
            b.rect(0, wy, W, 6, tint(PColor(0x8A7A5A)))
            for i in 0..<18 { b.ellipse(80 + hrand(i, 55) * 240, fy + 3, 8 + hrand(i, 56) * 8, 5, tint(PColor(0x7A6E62))) }
            for (mx, mh) in [(120.0, 70.0), (250, 90)] { b.triangle((mx - 60, fy), (mx, fy + mh), (mx + 60, fy), tint(PColor(0x8A6A5A))) }
            for i in 0..<14 { b.ellipse(90 + hrand(i, 57) * 220, fy + 6 + hrand(i, 58) * 30, 10 + hrand(i, 59) * 10, 6, PColor(0xF0F0F0, 120)) }
        case .kelp, .trench:
            if habitat == .trench {
                b.ellipse(260, Double(wy), 50, 3, tint(PColor(0x14203A)))
            } else {
                b.polygon([(200, Double(wy) + 1), (238, Double(wy) + 1), (243, Double(wy) + 7), (195, Double(wy) + 7)], tint(PColor(0x2A3A55)))
            }
        case .atoll:
            b.rect(80, wy, W - 80, 4, tint(PColor(0xF2E0B0)))
            for (i, x) in [110, 150, 200, 255, 300].enumerated() {
                let c = tint(PColor(0x8A6A3A)), g = tint(PColor(0x3EAA3A))
                for y in 0..<24 { b.set(x + Int(sin(Double(y) * 0.15 + Double(i)) * 2), wy + 3 + y, c) }
                let fx = x + Int(sin(24 * 0.15 + Double(i)) * 2), fy = wy + 27
                for (dx, dy) in [(-9, -4), (-7, 2), (0, 5), (7, 2), (9, -4)] { b.line(fx, fy, fx + dx, fy + dy, g) }
            }
        }

        // Water
        let wTop = tint(habitat.water.shade(0.12)), wBot = tint(habitat.water.shade(-0.6))
        gradient(0, wy, wBot, wTop, levels: 7)
        for i in 0..<46 {
            let x = Int(hrand(i, 20) * Double(W)), y = wy - 3 - Int(pow(hrand(i, 21), 1.6) * 40)
            b.rect(x, y, 3 + Int(hrand(i, 22) * 6), 1, wTop.shade(0.25).alpha(200))
        }
        if let cel = celestial {
            let (cx, _, r, c) = cel
            for k in 0..<9 {
                let y = wy - 2 - k * 3
                let w = Int(r * 1.6) - k
                if w > 0 { b.rect(Int(cx) - w / 2 + Int(hrand(k, 23) * 4) - 2, y, w, 1, c.alpha(150)) }
            }
        }
        b.rect(0, wy - 1, W, 1, wTop.shade(0.35))

        // Seabed
        switch habitat {
        case .kelp:
            for i in 0..<22 {
                let x0 = 70 + Int(hrand(i, 60) * 245), h = 40 + Int(hrand(i, 61) * 40)
                let c = tint(PColor(0x3A7A3A)).shade(-0.2)
                for y in 0..<h {
                    let x = x0 + Int(sin(Double(y) * 0.12 + Double(i)) * 4)
                    b.rect(x, y, 2, 1, c)
                    if y % 7 == 0 { b.ellipse(Double(x) + 3, Double(y), 3, 1.5, c.shade(0.15)) }
                }
            }
        case .trench:
            for y in 0..<20 { for x in 0..<W { b[x, y] = b[x, y].shade(-0.4) } }
            for i in 0..<12 { b.set(70 + Int(hrand(i, 62) * 245), 10 + Int(hrand(i, 63) * 60), PColor(0x8AF2FF)) }
        case .ocean, .lagoon, .atoll:
            for y in 0..<7 { for x in 0..<W where hrand(x, y, 24) < 0.9 - Double(y) * 0.1 { b[x, y] = tint(PColor(0xD8C08A)).shade(-0.2) } }
            for i in 0..<10 {
                let cx = 80 + hrand(i, 25) * 230
                let col = [PColor(0xFF7A8A), PColor(0xFFA04A), PColor(0xC86AE8)][i % 3]
                for j in 0..<4 { b.ellipse(cx + hrand(i, j, 26) * 10 - 5, 6 + hrand(i, j, 27) * 10, 2.5, 2.5, tint(col).shade(-0.25)) }
            }
        case .deepSea:
            break
        default:
            for i in 0..<16 {
                let x0 = 70 + Int(hrand(i, 28) * 245), h = 10 + Int(hrand(i, 29) * 22)
                let c = tint(PColor(habitat == .swamp ? 0x4A5A2A : 0x3E7A3A)).shade(-0.3)
                for y in 0..<h { b.set(x0 + Int(sin(Double(y) * 0.3 + Double(i)) * 1.5), y, c) }
            }
            for i in 0..<6 { b.ellipse(80 + hrand(i, 30) * 230, 1, 4 + hrand(i, 31) * 4, 3, tint(PColor(0x5A5E66)).shade(-0.35)) }
        }

        if boat == nil { paintShore(b, tint) }
        return b
    }

    private func pine(_ b: PixelBuffer, _ x: Int, _ base: Int, _ h: Int, _ c: PColor) {
        let fx = Double(x), fb = Double(base), fh = Double(h)
        b.triangle((fx - fh * 0.35, fb), (fx, fb + fh), (fx + fh * 0.35, fb), c)
        b.triangle((fx, fb), (fx, fb + fh), (fx + fh * 0.35, fb), c.shade(-0.2))
    }

    private func paintShore(_ b: PixelBuffer, _ tint: (PColor) -> PColor) {
        let wy = waterY
        let land = PixelBuffer(W, H)
        let top = wy + 8
        if habitat == .deepSea {
            for x in [4, 24, 44] { land.rect(x, 0, 4, top, PColor(0x5A3A1E)); land.rect(x, 0, 1, top, PColor(0x7A5230)) }
            land.rect(0, top - 6, 62, 7, PColor(0xB0763C))
            for x in stride(from: 0, to: 62, by: 5) { land.rect(x, top - 6, 1, 7, PColor(0x7A4A22)) }
            land.rect(0, top, 62, 1, PColor(0xD09058))
            land.outline(PColor(0x2A1408))
        } else {
            let body: PColor, cap: PColor, capHi: PColor
            switch habitat {
            case .stream, .cavern: body = PColor(0x6E7480); cap = PColor(0x8E95A3); capHi = PColor(0xAEB5C3)
            case .ocean, .lagoon, .atoll: body = PColor(0xD8BC84); cap = PColor(0xEED7A1); capHi = PColor(0xF8E8BC)
            case .waterfall, .hotspring: body = PColor(0x6E7480); cap = PColor(0x8E95A3); capHi = PColor(0xAEB5C3)
            case .swamp: body = PColor(0x5A4628); cap = PColor(0x5E6E34); capHi = PColor(0x7A8A44)
            default: body = PColor(0x7A5A3A); cap = PColor(0x5FA83E); capHi = PColor(0x76C250)
            }
            let ft = Double(top), fw = Double(wy)
            land.polygon([(0, 0), (0, ft), (56, ft), (66, ft - 6), (74, fw - 14), (66, 0)], body)
            for i in 0..<20 {
                let x = Int(hrand(i, 40) * 60), y = Int(hrand(i, 41) * Double(top - 4))
                if land[x, y].a > 0 { land.rect(x, y, 3, 2, body.shade(hrand(i, 42) < 0.5 ? -0.18 : 0.12)) }
            }
            for y in (top - 3)..<top { for x in 0..<W where land[x, y].a > 0 { land[x, y] = cap } }
            land.rect(0, top - 1, 56, 1, capHi)
            if habitat == .stream || habitat == .cavern {
                for (x, y, r) in [(10.0, ft - 8, 6.0), (36, ft - 14, 8), (60, fw - 8, 6)] {
                    land.ellipse(x, y, r, r * 0.7, PColor(0x8E95A3))
                    land.ellipse(x - r * 0.3, y + r * 0.2, r * 0.4, r * 0.3, PColor(0xAEB5C3))
                }
            }
            if habitat == .swamp || habitat == .pond || habitat == .lake {
                for x in stride(from: 50, to: 70, by: 3) {
                    let h = 6 + Int(hrand(x, 43) * 8)
                    land.rect(x, top - 4, 1, h, PColor(0x4A7A2A))
                    if hrand(x, 44) < 0.5 { land.rect(x, top - 4 + h, 1, 3, PColor(0x6A4A2A)) }
                }
            } else if habitat != .ocean && habitat != .lagoon {
                for i in 0..<6 {
                    let x = 2 + Int(hrand(i, 45) * 50)
                    land.set(x, top, capHi.shade(-0.1)); land.set(x + 2, top, capHi.shade(-0.1)); land.set(x + 1, top + 1, capHi)
                }
            }
            land.outline(PColor(0x2A1E10))
        }
        let under = tint(habitat.water.shade(-0.3))
        for y in 0..<H {
            for x in 0..<W {
                var c = land[x, y]
                guard c.a > 0 else { continue }
                c = tint(c)
                if y < wy { c = c.mix(under, 0.5) }
                b[x, y] = c
            }
        }
    }

    // MARK: - Angler

    private func buildAngler() {
        let boatX: CGFloat = 46
        if let boat {
            let back = pixelSprite(BoatArt.side(boat.kind, front: false), scale: P)
            let front = pixelSprite(BoatArt.side(boat.kind, front: true), scale: P)
            for s in [back, front] {
                s.anchorPoint = CGPoint(x: 0.5, y: 0)
                s.position = pt(CGPoint(x: boatX, y: CGFloat(waterY) - 5))
                addChild(s)
                s.run(.repeatForever(.sequence([.moveBy(x: 0, y: 4, duration: 0.9), .moveBy(x: 0, y: -4, duration: 0.9)])))
            }
            back.zPosition = 5
            front.zPosition = 6.5
            let tw = BoatArt.side(boat.kind, front: false).size().width
            let seat = BoatArt.seat(boat.kind)
            feet = CGPoint(x: boatX - (tw / 2).rounded(.down) + CGFloat(seat.0), y: CGFloat(waterY) - 5 + CGFloat(seat.1))
            addCharterGuests(boatLeft: boatX - (tw / 2).rounded(.down), deckY: CGFloat(waterY) - 5 + CGFloat(seat.1))
            playerSprite.run(.repeatForever(.sequence([.moveBy(x: 0, y: 4, duration: 0.9), .moveBy(x: 0, y: -4, duration: 0.9)])))
        } else {
            feet = CGPoint(x: 34, y: CGFloat(waterY) + 8)
        }
        playerSprite.setPixelTexture(PlayerArt.texture(.right, frame: 0), scale: P)
        playerSprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        playerSprite.position = pt(feet)
        playerSprite.zPosition = 6
        addChild(playerSprite)
        hand = CGPoint(x: feet.x + 7, y: feet.y + 11)
        tipRest = CGPoint(x: hand.x + 34, y: hand.y + 44)
        tip = tipRest
    }

    // MARK: - Charter guests

    private var guestSprites: [SKSpriteNode] = []

    /// Charter clients stand on deck with their own rods.
    private func addCharterGuests(boatLeft: CGFloat, deckY: CGFloat) {
        let s = Game.shared.save
        guard let b = boat, b.charter, Game.shared.mapScene.partyAboard, let ch = s.charter, ch.day == s.day else { return }
        for (i, o) in ch.party.enumerated() {
            let g = SKSpriteNode()
            g.setPixelTexture(PlayerArt.texture(.right, frame: 0, outfit: o), scale: P)
            g.anchorPoint = CGPoint(x: 0.5, y: 0)
            let foot = CGPoint(x: boatLeft + 26 + CGFloat(i) * 9, y: deckY)
            g.position = pt(foot)
            g.zPosition = 5.5
            addChild(g)
            let rod = SKSpriteNode(color: PColor(0x3A2A1A).ns, size: CGSize(width: 26 * P, height: P))
            rod.anchorPoint = CGPoint(x: 0, y: 0.5)
            rod.position = CGPoint(x: 6 * P, y: 11 * P)
            rod.zRotation = 0.9 + CGFloat(i) * 0.12
            g.addChild(rod)
            g.run(.repeatForever(.sequence([.moveBy(x: 0, y: 4, duration: 0.9), .moveBy(x: 0, y: -4, duration: 0.9)])))
            guestSprites.append(g)
        }
    }

    private func guestCheers() {
        guard let g = guestSprites.randomElement() else { return }
        g.run(.sequence([.moveBy(x: 0, y: 6 * P, duration: 0.15), .moveBy(x: 0, y: -6 * P, duration: 0.2),
                         .moveBy(x: 0, y: 4 * P, duration: 0.12), .moveBy(x: 0, y: -4 * P, duration: 0.15)]))
    }

    // MARK: - UI

    private func buildUI() {
        message.position = CGPoint(x: 640, y: 712)
        message.zPosition = 60
        addChild(message)
        hint.position = CGPoint(x: 640, y: 22)
        hint.zPosition = 60
        addChild(hint)
        var titleText = habitat.spotName.uppercased()
        if let boat { titleText += "  ·  ON \(boat.name.uppercased())" }
        let title = PixelLabel(titleText, scale: 2, align: .left)
        title.position = CGPoint(x: 16, y: 786)
        title.zPosition = 60
        addChild(title)
        infoLabel.position = CGPoint(x: 16, y: 766)
        infoLabel.zPosition = 60
        addChild(infoLabel)
        coinLabel.position = CGPoint(x: 16, y: 740)
        coinLabel.zPosition = 60
        addChild(coinLabel)
        activityLabel.position = CGPoint(x: 1264, y: 786)
        activityLabel.zPosition = 60
        addChild(activityLabel)
        gearLabel.position = CGPoint(x: 1264, y: 766)
        gearLabel.zPosition = 60
        addChild(gearLabel)
        compLabel.position = CGPoint(x: 1264, y: 744)
        compLabel.zPosition = 60
        addChild(compLabel)
        refreshInfo()

        powerNode.position = CGPoint(x: 640, y: 626)
        powerNode.zPosition = 60
        addChild(powerNode)
        powerNode.addChild(panelSprite(456, 72, style: .dark))
        let track = SKSpriteNode(color: PColor(0x0A1020).ns, size: CGSize(width: 400, height: 24))
        track.position = CGPoint(x: 0, y: -6)
        powerNode.addChild(track)
        let gold = SKSpriteNode(color: PColor(0xFFD23A, 140).ns, size: CGSize(width: 40, height: 24))
        gold.position = CGPoint(x: 180, y: -6)
        powerNode.addChild(gold)
        powerFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        powerFill.position = CGPoint(x: -200, y: -6)
        powerNode.addChild(powerFill)
        let pl = PixelLabel("POWER", scale: 2)
        pl.position = CGPoint(x: 0, y: 18)
        powerNode.addChild(pl)
    }

    private func refreshInfo() {
        let s = Game.shared.save
        let act = FishSpecies.activity(habitat, minutes: s.minutes, weather: s.weather, day: s.day, saltRod: s.hasSaltRod)
        infoLabel.text = "\(GameCalendar.label(s.day))  \(Clock.timeString(s.minutes))  ·  \(s.weather.name.uppercased())  ·  COOLER \(s.cooler.count)/\(s.coolerCapacity)"
        coinLabel.text = "\(s.coins)G"
        let (word, col) = FishSpecies.activityLabel(act)
        activityLabel.text = "BITES: \(word)"
        activityLabel.textColor = col
        var gear = "LURE: \(s.item(.lure)?.name.uppercased() ?? "NONE")  BAIT: "
        gear += s.item(.bait).map { "\($0.name.uppercased()) ×\(s.baitLeft)" } ?? "NONE"
        gearLabel.text = gear
        if let c = s.comp {
            let st = c.standings(final: false)
            let place = (st.firstIndex { $0.2 } ?? 0) + 1
            let secs = Int(max(0, c.timeLeft))
            let here = c.comp.habitat == habitat ? "" : "  (FISH AT \(c.comp.habitat.spotName.uppercased())!)"
            compLabel.text = "\(c.comp.name.uppercased()) \(secs / 60):\(String(format: "%02d", secs % 60))  YOU \(c.comp.format(c.playerScore))  #\(place)\(here)"
        } else {
            compLabel.text = ""
        }
    }

    private func buildReelPanel() {
        reelPanel.zPosition = 50
        addChild(reelPanel)
        reelFrame = panelSprite(144, 536, scale: 4, style: .wood)
        reelFrame.position = CGPoint(x: 1160, y: 368)
        reelPanel.addChild(reelFrame)
        let chan = SKSpriteNode(color: PColor(0x14304A).ns, size: CGSize(width: 48, height: chanH))
        chan.position = CGPoint(x: chanX, y: chanBottom + chanH / 2)
        reelPanel.addChild(chan)
        for i in 0..<6 {
            let ripple = SKSpriteNode(color: PColor(0x2A5A7A).ns, size: CGSize(width: 12, height: 4))
            ripple.position = CGPoint(x: chanX - 12 + CGFloat(i % 2) * 20, y: chanBottom + 40 + CGFloat(i) * 76)
            reelPanel.addChild(ripple)
        }
        let ptrack = SKSpriteNode(color: PColor(0x2A1A0E).ns, size: CGSize(width: 16, height: chanH))
        ptrack.position = CGPoint(x: progX, y: chanBottom + chanH / 2)
        reelPanel.addChild(ptrack)
        progressFill.anchorPoint = CGPoint(x: 0.5, y: 0)
        progressFill.position = CGPoint(x: progX, y: chanBottom)
        reelPanel.addChild(progressFill)
        let t = PixelLabel("REEL!", scale: 3, color: .gold)
        t.position = CGPoint(x: 1160, y: 660)
        reelPanel.addChild(t)
        reelPanel.isHidden = true
    }

    // MARK: - Phases

    private func startAiming() {
        phase = .aiming
        card?.removeFromParent()
        card = nil
        exclaim?.removeFromParent()
        exclaim = nil
        bobber.isHidden = true
        powerNode.isHidden = false
        reelPanel.isHidden = true
        power = 0
        powerDir = 1
        bend = 0
        hooked = nil
        if Game.shared.save.coolerFull && !charterActive {
            message.text = "COOLER FULL!"
            message.textColor = PColor(0xFF8A7A)
            hint.text = "SELL YOUR FISH AT THE BAIT & TACKLE SHOP  ·  ESC: BACK TO MAP"
            powerNode.isHidden = true
            return
        }
        message.text = "PRESS SPACE TO CAST!"
        message.textColor = .white
        var h = "STOP IN THE GOLD ZONE FOR A PERFECT CAST"
        if boat != nil { h = "BOAT: BIGGER FISH + BONUS CATCHES  ·  " + h }
        if charterActive, let ch = Game.shared.save.charter { h = "CHARTER: \(ch.client) \(ch.caught)/\(ch.target) · " + h }
        if school { h = "FISH SCHOOL!  ·  " + h }
        hint.text = h + "  ·  ESC: MAP"
    }

    private func cast() {
        guard !Game.shared.save.coolerFull || charterActive else { return }
        guard Game.shared.save.spend(Energy.cast) else {
            message.text = "TOO TIRED TO CAST!"
            message.textColor = PColor(0xFF8A7A)
            hint.text = "EAT FOOD FROM YOUR BACKPACK (I ON THE MAP) OR SLEEP AT HOME  ·  ESC: BACK"
            return
        }
        phase = .casting
        powerNode.isHidden = true
        let perfectCast = power >= 0.9
        castX = (110 + power * 136).rounded()
        luck = Game.shared.save.rodStats(habitat).luck + bonus.luck + (perfectCast ? 0.12 : Double(power) * 0.04) + (school ? 0.08 : 0) + (boat != nil ? 0.04 : 0)
        castT = 0
        bobber.isHidden = false
        bobberPos = tip
        message.text = perfectCast ? "PERFECT CAST!" : (power > 0.6 ? "NICE CAST!" : "PLOP.")
        message.textColor = perfectCast ? .gold : .white
        hint.text = ""
        Sound.play("Pop")
    }

    private func landBobber() {
        ripple(at: CGPoint(x: castX, y: CGFloat(waterY)))
        splash(at: CGPoint(x: castX, y: CGFloat(waterY)))
        Sound.play("Bottle", volume: 0.3)
        let s = Game.shared.save
        phase = .waiting
        hooked = FishSpecies.pick(for: habitat, luck: luck, minutes: s.minutes, weather: s.weather, day: s.day, saltRod: s.hasSaltRod)
        waitElapsed = 0
        // Real-world-style feeding: wait scales inversely with how actively fish are feeding right now.
        let activity = max(0.25, FishSpecies.activity(habitat, minutes: s.minutes, weather: s.weather, day: s.day, saltRod: s.hasSaltRod))
        var mult = bonus.bite / activity
        if boat != nil { mult *= 0.85 }
        if school { mult *= 0.55 }
        waitDuration = min(40, max(2.5, Double.random(in: 5...12) * mult))
        nibbles = (0..<Int.random(in: 1...5)).map { _ in Double.random(in: 0.8...max(1.0, waitDuration - 0.6)) }.sorted()
        message.text = "WAIT FOR A BITE..."
        message.textColor = .white
        hint.text = "PRESS SPACE WHEN THE BOBBER GOES UNDER!  ·  TOO EARLY SCARES THE FISH"
    }

    private func bite() {
        guard let fish = hooked else { return }
        phase = .bite
        biteTimeLeft = 1.15 - 0.4 * fish.difficulty
        bobberDip = 5
        ripple(at: CGPoint(x: castX, y: CGFloat(waterY)))
        splash(at: CGPoint(x: castX, y: CGFloat(waterY)))
        let ex = PixelLabel("!", scale: 8, color: .gold)
        ex.position = pt(CGPoint(x: castX, y: CGFloat(waterY) + 20))
        ex.zPosition = 30
        ex.setScale(0.3)
        ex.run(.scale(to: 1, duration: 0.1))
        addChild(ex)
        exclaim = ex
        message.text = "BITE! PRESS SPACE!"
        message.textColor = .gold
        Sound.play("Ping", volume: 0.5)
    }

    private func startReel() {
        guard let fish = hooked else { return }
        phase = .reeling
        exclaim?.removeFromParent()
        exclaim = nil
        barSize = Game.shared.save.rodStats(habitat).bar + bonus.bar + 0.03
        Game.shared.save.useBait()
        // The size is decided at the bite: bigger / pricier fish fight harder and take longer to land.
        (pendingT, pendingTrophy) = rollSize(trophyAllowed: true)
        let sizeFrac = min(1.3, pendingT)
        fightDifficulty = min(0.95, fish.difficulty * 0.9 + 0.14 * sizeFrac + min(0.06, Double(fish.baseValue) / 8000))
        fightWeight = 1 + 0.5 * sizeFrac + (pendingTrophy ? 0.3 : 0) + Double(fish.rarity.rawValue) * 0.1
        fishPos = 0.5; fishVel = 0; fishTarget = 0.5; fishTimer = 0.5
        barPos = 0.5 - barSize / 2; barVel = 0
        progress = 0.3
        perfect = true

        catchBar.removeFromParent()
        let barH = snap(CGFloat(barSize) * chanH, 4)
        catchBar = SKSpriteNode(color: PColor(0x7CD04A).ns, size: CGSize(width: 48, height: barH))
        for y in [barH / 2 - 2, -barH / 2 + 2] {
            let edge = SKSpriteNode(color: PColor(0xC8FFA0).ns, size: CGSize(width: 48, height: 4))
            edge.position = CGPoint(x: 0, y: y)
            catchBar.addChild(edge)
        }
        reelPanel.addChild(catchBar)

        fishIcon.removeFromParent()
        let sil = fish.rarity == .legendary ? PColor(0xFFC83A) : PColor(0x0A1420)
        fishIcon = pixelSprite(FishPixel.texture(fish, length: 12, silhouette: sil), scale: P)
        fishIcon.zPosition = 1
        reelPanel.addChild(fishIcon)

        switch fish.rarity {
        case .legendary: message.text = "⚡ SOMETHING LEGENDARY! ⚡"; message.textColor = .gold
        case .rare: message.text = "SOMETHING STRONG IS PULLING!"; message.textColor = PColor(0x8AC8FF)
        default: message.text = "FISH ON! REEL IT IN!"; message.textColor = .white
        }
        if pendingT > 0.75 && fish.rarity != .legendary {
            message.text = pendingTrophy ? "A TROPHY MONSTER! HOLD ON!" : "IT'S A BIG ONE! HOLD ON!"
            message.textColor = PColor(0xFF9A5A)
        }
        if fish.isShark {
            message.text = fish.rarity == .legendary ? "⚡ A LEGENDARY SHARK! ⚡" : "SHARK ON THE LINE! HOLD ON!"
            message.textColor = fish.rarity == .legendary ? .gold : PColor(0xFF6A5A)
        }
        hint.text = "HOLD SPACE (OR MOUSE) TO RAISE THE GREEN BAR  ·  KEEP THE FISH INSIDE IT!"
        reelPanel.isHidden = false
        Sound.play("Tink", volume: 0.5)
        updateReelVisuals(inside: true)
    }

    /// Rolls where in the species' size range this fish lands (1.0 = max; >1 = trophy).
    private func rollSize(trophyAllowed: Bool) -> (Double, Bool) {
        let sizeBonus = min(0.75, (boat?.sizeBonus ?? 0) + (school ? 0.1 : 0) + bonus.size)
        let t = pow(Double.random(in: 0...1), 1.6 * (1 - sizeBonus))
        if trophyAllowed && boat != nil && Double.random(in: 0...1) < 0.04 + sizeBonus * 0.12 {
            return (Double.random(in: 1.05...1.3), true)
        }
        return (t, false)
    }

    private func rollCatch(_ fish: FishSpecies, bonus: Bool, preset: (Double, Bool)? = nil) -> (CaughtFish, Bool) {
        let (t, trophy) = preset ?? rollSize(trophyAllowed: !bonus)
        let size = fish.minSize + (fish.maxSize - fish.minSize) * t
        var value = Double(fish.baseValue) * (0.8 + 0.7 * t)
        if !bonus && perfect { value *= 1.5 }
        if trophy { value *= 2 }
        return (CaughtFish(id: fish.id, size: size, value: Int(value.rounded())), trophy)
    }

    /// True when this catch belongs to a paying charter client.
    private var charterActive: Bool {
        guard let ch = Game.shared.save.charter, let b = boat, b.charter, ch.water == habitat, ch.caught < ch.target else { return false }
        return true
    }
    private var charterPay = 0

    private func record(_ c: CaughtFish) -> (isNew: Bool, isRecord: Bool) {
        let game = Game.shared
        var rec = game.save.records[c.id] ?? FishRecord()
        let isNew = rec.count == 0
        let isRecord = !isNew && c.size > rec.best
        rec.count += 1
        rec.best = max(rec.best, c.size)
        game.save.records[c.id] = rec
        game.save.totalCaught += 1
        if charterActive, var ch = game.save.charter {
            ch.caught += 1
            var pay = ch.perFish
            if ch.caught >= ch.target { pay += ch.bonus }
            game.save.coins += pay
            game.save.charter = ch
            charterPay += pay
            guestCheers()
        } else if game.save.cooler.count < game.save.coolerCapacity {
            game.save.cooler.append(c)
        }
        return (isNew, isRecord)
    }

    private func caught() {
        guard let fish = hooked else { return }
        phase = .result
        reelPanel.isHidden = true
        bobber.isHidden = true
        bend = 0
        let s = Game.shared.save

        charterPay = 0
        let (main, trophy) = rollCatch(fish, bonus: false, preset: (pendingT, pendingTrophy))
        let flags = record(main)
        logComp(fish, main.size)

        var extras: [FishSpecies] = []
        let chance = (boat?.extraChance ?? 0) + (school ? 0.6 : 0)
        var roll = Double.random(in: 0...1)
        while roll < chance && extras.count < 3 && !Game.shared.save.coolerFull {
            let e = FishSpecies.pick(for: habitat, luck: 0, minutes: s.minutes, weather: s.weather, day: s.day, allowLegendary: false)
            let ec = rollCatch(e, bonus: true).0
            _ = record(ec)
            logComp(e, ec.size)
            extras.append(e)
            roll = Double.random(in: 0...1) + Double(extras.count) * 0.25
        }
        Game.shared.save.persist()
        refreshInfo()

        message.text = ""
        hint.text = ""
        showCard(fish, main, isNew: flags.isNew, isRecord: flags.isRecord, trophy: trophy, extras: extras)
        Sound.play(fish.rarity == .legendary || trophy ? "Hero" : "Glass", volume: 0.5)
        if fish.rarity.rawValue >= Rarity.rare.rawValue || trophy { confetti() }
    }

    private func escape(_ text: String) {
        phase = .escaped
        reelPanel.isHidden = true
        exclaim?.removeFromParent()
        exclaim = nil
        if !bobber.isHidden { ripple(at: CGPoint(x: bobberPos.x, y: CGFloat(waterY))) }
        bobber.isHidden = true
        bend = 0
        message.text = text
        message.textColor = PColor(0xFF8A7A)
        hint.text = ""
        Sound.play("Basso", volume: 0.35)
        run(.sequence([.wait(forDuration: 1.6), .run { [weak self] in self?.startAiming() }]), withKey: "escape")
    }

    private func logComp(_ s: FishSpecies, _ cm: Double) {
        guard var c = Game.shared.save.comp, c.comp.habitat == habitat else { return }
        c.log(s, cm: cm)
        Game.shared.save.comp = c
    }

    // MARK: - Result card

    private func showCard(_ fish: FishSpecies, _ c: CaughtFish, isNew: Bool, isRecord: Bool, trophy: Bool, extras: [FishSpecies]) {
        let node = SKNode()
        node.position = CGPoint(x: 600, y: 430)
        node.zPosition = 100
        addChild(node)
        card = node
        cardReadyAt = clock + 0.6

        node.addChild(panelSprite(660, 456, scale: 4))
        func add(_ n: SKNode, _ y: CGFloat, _ x: CGFloat = 0) { n.position = CGPoint(x: x, y: y); node.addChild(n) }

        add(inkLabel("YOU CAUGHT A", scale: 3), 180)
        add(PixelLabel(fish.name.uppercased(), scale: fish.name.count > 14 ? 4 : 5, color: fish.rarity.inkColor, shadow: .inkShadow), 140)
        let tag = panelSprite(200, 36, scale: 2, style: .dark)
        tag.addChild(PixelLabel(fish.rarity.name.uppercased(), scale: 2, color: fish.rarity.color))
        add(tag, 100)

        let art = pixelSprite(FishPixel.texture(fish, length: 56), scale: 3)
        add(art, 12, fish.shape == .sword ? -20 : 0)
        art.run(.repeatForever(.sequence([.moveBy(x: 0, y: 8, duration: 0.5), .moveBy(x: 0, y: -8, duration: 0.5)])))

        add(inkLabel("SIZE " + formatSize(c.size) + "  ·  " + formatWeight(fish.weightKg(c.size)) + (trophy ? "  (TROPHY!)" : ""), scale: 3), -76)
        let sv = Game.shared.save
        let mult = Market.multiplier(fish, day: sv.day)
        let trend = mult > 1.08 ? "  ↑ HIGH DEMAND" : (mult < 0.92 ? "  ↓ IN SEASON" : "")
        add(inkLabel("WORTH \(Market.price(c, day: sv.day, sellBonus: sv.sellBonus))G TODAY" + (perfect ? "  PERFECT ×1.5" : "") + trend,
                     scale: 2.5, color: PColor(0x9A6010)), -110)
        if !extras.isEmpty {
            let names = extras.map { $0.name.uppercased() }.joined(separator: ", ")
            add(inkLabel("+\(extras.count) BONUS: \(names)", scale: 2, color: PColor(0x2E7A2A)), -142)
        }
        let s = Game.shared.save
        if charterPay > 0, let ch = s.charter {
            let done = ch.caught >= ch.target
            add(inkLabel("\(ch.client) KEEPS IT · +\(charterPay)G · \(ch.caught)/\(ch.target)" + (done ? " · CHARTER COMPLETE!" : ""), scale: 2,
                         color: PColor(0x2E8A2A)), -168)
        } else {
            add(inkLabel("COOLER \(s.cooler.count)/\(s.coolerCapacity)" + (s.coolerFull ? "  FULL!" : ""), scale: 2,
                         color: s.coolerFull ? PColor(0xC8281A) : .ink), -168)
        }
        add(inkLabel("SPACE: CAST AGAIN     ESC: BACK TO MAP", scale: 2), -196)

        var badges: [(String, PColor)] = []
        if isNew { badges.append(("NEW!", PColor(0xE83A5A))) }
        if isRecord { badges.append(("RECORD!", PColor(0x2E9A3A))) }
        if trophy { badges.append(("TROPHY!", PColor(0xC8781A))) }
        for (i, bd) in badges.enumerated() {
            let p = panelSprite(156, 44, scale: 2, style: .dark)
            p.addChild(PixelLabel(bd.0, scale: 3, color: bd.1.shade(0.3)))
            add(p, 190 - CGFloat(i) * 50, 300)
            p.run(.repeatForever(.sequence([.scale(to: 1.08, duration: 0.35), .scale(to: 1, duration: 0.35)])))
        }

        node.setScale(0.5)
        node.alpha = 0
        node.run(.group([.scale(to: 1, duration: 0.15), .fadeIn(withDuration: 0.15)]))
    }

    private func confetti() {
        let colors = [PColor(0xFFD23A), PColor(0xFF5A7A), PColor(0x6ADC5A), PColor(0x5AB4FF), PColor(0xC86AE8)]
        for _ in 0..<60 {
            let p = SKSpriteNode(color: colors.randomElement()!.ns, size: CGSize(width: 8, height: 8))
            p.position = CGPoint(x: snap(CGFloat.random(in: 0...1280), 4), y: 820)
            p.zPosition = 110
            addChild(p)
            let dur = Double.random(in: 1.8...3.2)
            p.run(.sequence([.moveBy(x: CGFloat.random(in: -100...100), y: -900, duration: dur), .removeFromParent()]))
        }
    }

    // MARK: - Effects

    private func ripple(at p: CGPoint) {
        let r = SKSpriteNode()
        r.setPixelTexture(PropArt.ripple(frame: 0), scale: P)
        r.position = pt(p)
        r.zPosition = 7.5
        addChild(r)
        let frames = (0..<4).map { PropArt.ripple(frame: $0) }
        r.run(.sequence([.animate(with: frames, timePerFrame: 0.15, resize: true, restore: false), .removeFromParent()]))
    }

    private func splash(at p: CGPoint) {
        for _ in 0..<7 {
            let d = pixelSprite(PropArt.dot(PColor(0xEAF6FF)), scale: P)
            d.position = pt(p)
            d.zPosition = 9
            addChild(d)
            let dx = snap(CGFloat.random(in: -36...36), 4), up = snap(CGFloat.random(in: 24...56), 4)
            d.run(.sequence([
                .moveBy(x: dx / 2, y: up, duration: 0.22),
                .moveBy(x: dx / 2, y: -up - 8, duration: 0.22),
                .removeFromParent(),
            ]))
        }
    }

    private func bubbles() {
        run(.repeatForever(.sequence([
            .run { [weak self] in
                guard let self else { return }
                let b = pixelSprite(PropArt.dot(PColor(0xFFFFFF, 200), 2, 2), scale: self.P)
                b.position = self.pt(CGPoint(x: CGFloat.random(in: 120...250).rounded(), y: CGFloat.random(in: 10...40).rounded()))
                b.zPosition = 3
                self.addChild(b)
                b.run(.sequence([.moveTo(y: CGFloat(self.waterY) * self.P, duration: 1.6), .removeFromParent()]))
            },
            .wait(forDuration: 0.12),
        ])))
    }

    private func spawnAmbientFish() {
        guard let s = FishSpecies.inHabitat(habitat).randomElement() else { return }
        let n = pixelSprite(FishPixel.texture(s, length: Int.random(in: 14...26), silhouette: PColor(0x000000, 60)), scale: P)
        let fromLeft = Bool.random()
        n.xScale = fromLeft ? 1 : -1
        n.position = CGPoint(x: fromLeft ? 260 : 1360, y: snap(CGFloat.random(in: 40...(CGFloat(waterY) * P - 60)), 4))
        n.zPosition = 3
        addChild(n)
        n.run(.sequence([.moveTo(x: fromLeft ? 1360 : 260, duration: Double.random(in: 8...14)), .removeFromParent()]))
    }

    // MARK: - Atmosphere

    private func updateAtmosphere(_ dt: Double) {
        let s = Game.shared.save
        let (c, a) = Clock.lighting(s.minutes, weather: s.weather)
        darkness.color = c.ns
        darkness.alpha = habitat == .cavern ? 0.15 : CGFloat(a) * 0.55
        if habitat == .cavern { clouds.forEach { $0.isHidden = true }; return }
        if shownWeather != s.weather { buildWeather(s.weather) }
        let t = CGFloat(dt)
        let surface = CGFloat(waterY) * P
        let snowing = s.weather == .snow
        for d in drops {
            d.position.x -= (snowing ? 30 + sin(CGFloat(clock) * 2 + d.position.y * 0.02) * 30 : (s.weather == .storm ? 260 : 140)) * t
            d.position.y -= (snowing ? 100 : (s.weather == .storm ? 1000 : 760)) * t
            if d.position.y < surface {
                if !snowing && Double.random(in: 0...1) < 0.08 { rainRipple(x: d.position.x) }
                d.position.y += 820 - surface + CGFloat.random(in: 0...60)
                d.position.x = CGFloat.random(in: 0...1400)
            }
        }
        if s.weather == .storm {
            lightningTimer -= dt
            if lightningTimer <= 0 {
                lightningTimer = Double.random(in: 5...12)
                flash.run(.sequence([.fadeAlpha(to: 0.7, duration: 0.05), .fadeAlpha(to: 0.1, duration: 0.1),
                                     .fadeAlpha(to: 0.5, duration: 0.05), .fadeOut(withDuration: 0.4)]))
                run(.sequence([.wait(forDuration: 0.5), .run { Sound.play("Submarine", volume: 0.25) }]))
            }
        }
    }

    private func rainRipple(x: CGFloat) {
        let r = pixelSprite(PropArt.ripple(frame: 0), scale: 2)
        r.position = CGPoint(x: snap(x, 4), y: CGFloat(waterY) * P - 4 - snap(CGFloat.random(in: 0...60), 4))
        r.zPosition = 4
        r.alpha = 0.6
        addChild(r)
        r.run(.sequence([.group([.scale(to: 1.8, duration: 0.5), .fadeOut(withDuration: 0.5)]), .removeFromParent()]))
    }

    private func buildWeather(_ w: Weather) {
        shownWeather = w
        weatherLayer.removeAllChildren()
        drops.removeAll()
        let surface = CGFloat(waterY) * P
        if w.isWet || w == .snow {
            for _ in 0..<(w == .storm ? 140 : (w == .snow ? 110 : 80)) {
                let d = w == .snow ? SKSpriteNode(color: .white, size: CGSize(width: 8, height: 8))
                                   : SKSpriteNode(color: PColor(0xB8D4F4, 170).ns, size: CGSize(width: 4, height: 16))
                d.position = CGPoint(x: CGFloat.random(in: 0...1400), y: CGFloat.random(in: surface...820))
                weatherLayer.addChild(d)
                drops.append(d)
            }
        } else if w == .fog {
            let veil = SKSpriteNode(color: PColor(0xDDE2E8).ns, size: size)
            veil.anchorPoint = .zero
            veil.alpha = 0.25
            weatherLayer.addChild(veil)
            for i in 0..<4 {
                let f = SKSpriteNode(texture: Tex.glow())
                f.size = CGSize(width: 800, height: 260)
                f.alpha = 0.4
                f.position = CGPoint(x: CGFloat(i) * 420, y: surface + CGFloat.random(in: -40...120))
                weatherLayer.addChild(f)
                f.run(.repeatForever(.sequence([.moveBy(x: 200, y: 0, duration: 12), .moveBy(x: -200, y: 0, duration: 12)])))
            }
        }
    }

    // MARK: - Update loop

    override func update(_ currentTime: TimeInterval) {
        let dt = lastTime == 0 ? 0 : min(1.0 / 30, currentTime - lastTime)
        lastTime = currentTime
        clock += dt

        if Game.shared.save.advance(seconds: dt) { Game.shared.save.persist() }
        if Game.shared.tickCompetition(dt) { return }
        if Int(clock) != Int(clock - dt) { refreshBackground(); refreshInfo() }
        updateAtmosphere(dt)

        for (i, c) in clouds.enumerated() {
            c.position.x += CGFloat(6 + i * 3) * CGFloat(dt)
            if c.position.x > 1450 { c.position.x = -200 }
        }

        ambientTimer -= dt
        if ambientTimer <= 0 {
            ambientTimer = Double.random(in: 1.5...3.5)
            spawnAmbientFish()
        }

        bobberDip = max(0, bobberDip - CGFloat(dt) * 10)

        switch phase {
        case .aiming:
            power += powerDir * CGFloat(dt) * 1.3
            if power >= 1 { power = 1; powerDir = -1 }
            if power <= 0 { power = 0; powerDir = 1 }
            powerFill.size.width = max(4, snap(400 * power, 4))
            powerFill.color = power >= 0.9 ? PColor(0xFFD23A).ns : NSColor(hue: 0.33 * (1 - power), saturation: 0.75, brightness: 0.95, alpha: 1)
        case .casting:
            castT += dt / 0.7
            let t = CGFloat(min(1, castT))
            bobberPos = CGPoint(x: tip.x + (castX - tip.x) * t, y: tip.y + (CGFloat(waterY) - tip.y) * t + sin(t * .pi) * 40)
            if castT >= 1 { landBobber() }
        case .waiting:
            waitElapsed += dt
            while let n = nibbles.first, waitElapsed >= n {
                nibbles.removeFirst()
                bobberDip = 2.5
                ripple(at: CGPoint(x: castX, y: CGFloat(waterY)))
                Sound.play("Tink", volume: 0.2)
            }
            bobberPos = CGPoint(x: castX, y: CGFloat(waterY) + (sin(clock * 3) > 0 ? 1 : 0) - bobberDip.rounded())
            if waitElapsed >= waitDuration { bite() }
        case .bite:
            biteTimeLeft -= dt
            bobberPos = CGPoint(x: castX + (Int(clock * 30) % 2 == 0 ? 1 : 0), y: CGFloat(waterY) - 4)
            if biteTimeLeft <= 0 { escape("TOO SLOW... IT STOLE THE BAIT!") }
        case .reeling:
            updateReel(dt)
        case .result, .escaped:
            break
        }

        bobber.position = CGPoint(x: snap(bobberPos.x * P, P), y: snap(bobberPos.y * P, P))
        drawRodAndLine()
    }

    private func updateReel(_ dt: Double) {
        guard let fish = hooked else { return }
        let holding = isDown(Key.space, Key.ret) || mouseHeld
        barVel += (holding ? 3.4 : -2.8) * dt
        barVel = max(-1.8, min(1.8, barVel))
        barPos += barVel * dt
        if barPos < 0 { barPos = 0; barVel = barVel < -0.4 ? -barVel * 0.3 : 0 }
        if barPos > 1 - barSize { barPos = 1 - barSize; barVel = 0 }

        updateFish(dt, fish)
        let inside = fishPos >= barPos && fishPos <= barPos + barSize
        if inside {
            progress += 0.34 * Game.shared.save.rodStats(habitat).reel / fightWeight * dt
        } else {
            progress -= (0.13 + 0.1 * fightDifficulty) * dt
            perfect = false
        }
        progress = max(0, min(1, progress))
        updateReelVisuals(inside: inside)

        bend = 0.55 + (inside ? 0.3 : 0.1) + (Int(clock * 12) % 2 == 0 ? 0.04 : 0)
        let bx = (castX - (castX - (tip.x + 16)) * CGFloat(progress) * 0.85).rounded()
        bobberPos = CGPoint(x: bx + (Int(clock * 20) % 2 == 0 ? 1 : 0), y: CGFloat(waterY) - 2)
        if Double.random(in: 0...1) < dt * 3 { ripple(at: CGPoint(x: bx, y: CGFloat(waterY))) }

        if progress >= 1 { caught() } else if progress <= 0 { escape("IT GOT AWAY!") }
    }

    private func updateFish(_ dt: Double, _ fish: FishSpecies) {
        let d = fightDifficulty
        fishTimer -= dt
        if fishTimer <= 0 {
            var b = fish.behavior
            if b == .mixed { b = [.smooth, .darter, .sinker, .floater].randomElement()! }
            switch b {
            case .smooth:
                fishTarget = Double.random(in: 0.08...0.92); fishTimer = Double.random(in: 0.9...1.8) * (1.15 - d * 0.5)
            case .darter:
                fishTarget = Double.random(in: 0...1); fishTimer = Double.random(in: 0.25...0.9) * (1.2 - d * 0.6)
            case .sinker:
                fishTarget = Double.random(in: 0...1) < 0.75 ? Double.random(in: 0...0.35) : Double.random(in: 0.5...1)
                fishTimer = Double.random(in: 0.6...1.4) * (1.15 - d * 0.5)
            case .floater:
                fishTarget = Double.random(in: 0...1) < 0.75 ? Double.random(in: 0.65...1) : Double.random(in: 0...0.5)
                fishTimer = Double.random(in: 0.6...1.4) * (1.15 - d * 0.5)
            case .mixed:
                break
            }
        }
        let maxSpeed = 0.22 + d * 0.95
        let desired = max(-maxSpeed, min(maxSpeed, (fishTarget - fishPos) * (2.5 + d * 5)))
        fishVel += (desired - fishVel) * min(1, (3 + d * 9) * dt)
        fishPos += fishVel * dt
        if fishPos < 0.03 { fishPos = 0.03; fishVel = 0 }
        if fishPos > 0.97 { fishPos = 0.97; fishVel = 0 }
    }

    private func updateReelVisuals(inside: Bool) {
        let barH = catchBar.size.height
        catchBar.position = CGPoint(x: chanX, y: snap(chanBottom + CGFloat(barPos) * chanH + barH / 2, 4))
        catchBar.alpha = inside ? 0.95 : 0.6
        let jitter: CGFloat = inside ? (Int(clock * 20) % 2 == 0 ? 4 : -4) : 0
        fishIcon.position = CGPoint(x: chanX + jitter, y: snap(chanBottom + CGFloat(fishPos) * chanH, 4))
        progressFill.size.height = max(4, snap(CGFloat(progress) * chanH, 4))
        progressFill.color = NSColor(hue: 0.33 * CGFloat(progress), saturation: 0.8, brightness: 0.95, alpha: 1)
    }

    private func drawRodAndLine() {
        tip = CGPoint(x: (tipRest.x + 8 * bend).rounded(), y: (tipRest.y - 32 * bend).rounded())
        let showLine = !bobber.isHidden
        let key = "\(Int(tip.x)),\(Int(tip.y)),\(showLine ? "\(Int(bobberPos.x)),\(Int(bobberPos.y))" : "-"),\(phase == .reeling)"
        guard key != overlayKey else { return }
        overlayKey = key
        let b = overlayBuf
        b.clear()
        let rodC = PColor(Game.shared.save.rod.color)
        func quad(_ a: CGPoint, _ c: CGPoint, _ e: CGPoint, _ t: CGFloat) -> CGPoint {
            let u = 1 - t
            return CGPoint(x: u * u * a.x + 2 * u * t * c.x + t * t * e.x, y: u * u * a.y + 2 * u * t * c.y + t * t * e.y)
        }
        if showLine {
            let end = CGPoint(x: bobberPos.x, y: bobberPos.y + 3)
            let sag: CGFloat = phase == .reeling ? 0 : (phase == .casting ? -12 : 14)
            let ctrl = CGPoint(x: (tip.x + end.x) / 2, y: min(tip.y, end.y) - sag)
            var prev = tip
            for i in 1...20 {
                let p = quad(tip, ctrl, end, CGFloat(i) / 20)
                b.line(Int(prev.x), Int(prev.y), Int(p.x), Int(p.y), PColor(0xF0F0F0, 230))
                prev = p
            }
        }
        let ctrl = CGPoint(x: hand.x + (tip.x - hand.x) * 0.2, y: hand.y + (tip.y - hand.y) * 0.85 + 6 * bend)
        var prev = hand
        for i in 1...14 {
            let p = quad(hand, ctrl, tip, CGFloat(i) / 14)
            b.line(Int(prev.x), Int(prev.y), Int(p.x), Int(p.y), i < 4 ? PColor(0x3A2A1A) : rodC, thick: i < 8 ? 2 : 1)
            prev = p
        }
        b.rect(Int(hand.x) + 1, Int(hand.y) + 2, 3, 3, PColor(0x3A3E46))
        b.set(Int(hand.x) + 2, Int(hand.y) + 3, PColor(0xA8A8B0))
        overlay.setPixelTexture(b.texture(), scale: P)
    }

    // MARK: - Input

    override func keyPressed(_ key: UInt16) {
        if key == Key.esc {
            Game.shared.leaveFishing()
            return
        }
        if key == Key.space || key == Key.ret || key == Key.enter { primaryAction() }
    }

    override func primaryPressed() { primaryAction() }

    private func primaryAction() {
        switch phase {
        case .aiming: cast()
        case .waiting: escape("TOO EARLY! YOU SPOOKED THE FISH.")
        case .bite: startReel()
        case .result: if clock >= cardReadyAt { startAiming() }
        default: break
        }
    }

    // MARK: - Debug hooks (snapshot mode)

    func debugForceReel(rarity: Rarity, species: String? = nil) {
        hooked = species.flatMap { FishSpecies.byID[$0] } ?? FishSpecies.inHabitat(habitat).first { $0.rarity == rarity }
        powerNode.isHidden = true
        bobber.isHidden = false
        castX = 220
        bobberPos = CGPoint(x: 200, y: CGFloat(waterY))
        startReel()
        fishPos = 0.62; barPos = 0.45; progress = 0.55
        updateReelVisuals(inside: true)
    }

    func debugForceCatch() { caught() }
}
