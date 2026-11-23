import SpriteKit

final class MineScene: BaseScene {
    private enum Cell { case floor, wall, water, up, down }
    private struct RockInfo {
        let kind: MineArt.Rock
        let gem: String
        var hp: Int
        let sprite: SKSpriteNode
        let hidesLadder: Bool
    }

    let level: Int
    private let cols = 40, rows = 22
    private let ts: CGFloat = 32
    private let yOff: CGFloat = 0
    private var cells: [Cell] = []
    private var rocks: [Int: RockInfo] = [:]
    private var built = false
    private var lastTime: TimeInterval = 0
    private let player = SKSpriteNode()
    private var pos = CGPoint.zero
    private var dir: Dir = .down
    private var walk = 0.0
    private let promptLabel = PixelLabel("", scale: 3)
    private var promptBG = SKSpriteNode()
    private let toast = PixelLabel("", scale: 3, color: .gold)
    private let info = PixelLabel("", scale: 3, align: .left)
    private let energyLabel = PixelLabel("", scale: 3, color: PColor(0x8AE85A), align: .right)
    private let light = SKSpriteNode(texture: Tex.glow())
    private var target: (Int, Int)?

    init(level: Int) {
        self.level = level
        super.init(size: Game.sceneSize)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func idx(_ x: Int, _ y: Int) -> Int { y * cols + x }
    private func cell(_ x: Int, _ y: Int) -> Cell { (x < 0 || y < 0 || x >= cols || y >= rows) ? .wall : cells[idx(x, y)] }
    private func center(_ x: Int, _ y: Int) -> CGPoint { CGPoint(x: (CGFloat(x) + 0.5) * ts, y: (CGFloat(y) + 0.5) * ts + yOff) }
    private func coord(_ p: CGPoint) -> (Int, Int) { (Int(floor(p.x / ts)), Int(floor((p.y - yOff) / ts))) }

    override func sceneDidAppear() {
        lastTime = 0
        guard !built else { return }
        built = true
        backgroundColor = PColor(0x140E0A).ns
        generate()
        Game.shared.save.mineDeepest = max(Game.shared.save.mineDeepest, level)

        // Floor & walls painted once
        let b = MineArt.floor(level: level)
        let wallC = PColor(level >= 15 ? 0x3A2A3A : 0x4A3E32)
        for y in 0..<rows {
            for x in 0..<cols {
                let ox = x * 16, oy = y * 16
                switch cell(x, y) {
                case .wall:
                    for py in 0..<16 { for px in 0..<16 { b[ox + px, oy + py] = hrand(ox + px, oy + py, 41) < 0.1 ? wallC.shade(-0.2) : wallC } }
                    if cell(x, y - 1) != .wall { b.rect(ox, oy, 16, 4, wallC.shade(-0.35)) }
                    if cell(x, y + 1) != .wall { b.rect(ox, oy + 14, 16, 2, wallC.shade(0.2)) }
                case .water:
                    let w = Habitat.cavern.water
                    for py in 0..<16 { for px in 0..<16 { b[ox + px, oy + py] = hrand(ox + px, oy + py, 42) < 0.08 ? w.shade(0.3) : w } }
                default: break
                }
            }
        }
        let bg = pixelSprite(b.texture(), scale: 2)
        bg.anchorPoint = .zero
        bg.position = CGPoint(x: 0, y: yOff)
        addChild(bg)

        for y in 0..<rows {
            for x in 0..<cols where cell(x, y) == .up || cell(x, y) == .down {
                let l = pixelSprite(MineArt.ladder(down: cell(x, y) == .down), scale: 2)
                l.position = center(x, y)
                l.zPosition = 1
                addChild(l)
            }
        }
        if level % 5 == 0 {
            for _ in 0..<6 {
                let c = SKSpriteNode(texture: Tex.glow())
                c.size = CGSize(width: 90, height: 90)
                c.color = PColor(0x8A6AFF).ns
                c.colorBlendFactor = 1
                c.blendMode = .add
                c.alpha = 0.5
                c.position = CGPoint(x: CGFloat.random(in: 100...1180), y: CGFloat.random(in: 80...680))
                c.zPosition = 30
                addChild(c)
            }
        }

        player.anchorPoint = CGPoint(x: 0.5, y: 0)
        player.setPixelTexture(PlayerArt.texture(.down, frame: 0), scale: 2)
        player.position = pos
        addChild(player)

        let dark = SKSpriteNode(color: .black, size: size)
        dark.anchorPoint = .zero
        dark.alpha = min(0.6, 0.25 + Double(level) * 0.02).cg
        dark.zPosition = 40
        addChild(dark)
        light.size = CGSize(width: 420, height: 420)
        light.blendMode = .add
        light.color = PColor(0xFFC880).ns
        light.colorBlendFactor = 1
        light.alpha = 0.35
        light.zPosition = 41
        addChild(light)

        let top = panelSprite(1280, 60, scale: 2, style: .dark)
        top.position = CGPoint(x: 640, y: 770)
        top.zPosition = 60
        addChild(top)
        info.position = CGPoint(x: 24, y: 770)
        info.zPosition = 61
        addChild(info)
        energyLabel.position = CGPoint(x: 1256, y: 770)
        info.pixelScale = 2
        energyLabel.zPosition = 61
        addChild(energyLabel)
        promptLabel.position = CGPoint(x: 640, y: 46)
        promptLabel.zPosition = 61
        addChild(promptLabel)
        toast.position = CGPoint(x: 640, y: 640)
        toast.zPosition = 61
        toast.alpha = 0
        addChild(toast)
        refreshInfo()
        if level == 1 && Game.shared.save.mineDeepest <= 1 { say("BREAK ROCKS WITH SPACE. ONE HIDES THE LADDER DOWN!") }
    }

    private func refreshInfo() {
        let s = Game.shared.save
        info.text = "MINE · LEVEL \(level)" + (level % 5 == 0 ? " · CRYSTAL CAVERN" : "") + "   ·   STONE \(s.count("stone"))  COAL \(s.count("coal"))  IRON \(s.count("iron"))   ·   I: BAG  ESC: LEAVE"
        energyLabel.text = "ENERGY \(s.energy)"
    }

    private func generate() {
        cells = Array(repeating: .floor, count: cols * rows)
        var rng = SeededRNG(seed: UInt64(level * 7919 + Int.random(in: 0...999)))
        func r() -> Double { Double.random(in: 0..<1, using: &rng) }
        let seed = Int(r() * 1000)
        for y in 0..<rows {
            for x in 0..<cols {
                let edge = x == 0 || y == 0 || x == cols - 1 || y == rows - 1
                let n = sin(Double(x) * 0.45 + Double(seed)) + cos(Double(y) * 0.5 + Double(seed) * 0.3) + sin(Double(x + y) * 0.21)
                if edge || n > 1.75 { cells[idx(x, y)] = .wall }
            }
        }
        if level % 5 == 0 {
            for y in 0..<rows { for x in 0..<cols {
                let dx = (Double(x) - 20) / 6, dy = (Double(y) - 11) / 3.5
                if dx * dx + dy * dy <= 1 { cells[idx(x, y)] = .water }
            } }
        }
        // Entrance (ladder up) with a cleared area
        let ex = 3, ey = rows / 2
        for y in (ey - 2)...(ey + 2) { for x in 1...6 where cell(x, y) == .wall && x > 0 { cells[idx(x, y)] = .floor } }
        cells[idx(ex, ey)] = .up
        pos = CGPoint(x: center(ex + 1, ey).x, y: center(ex + 1, ey).y - 14)

        // Rocks
        var candidates: [(Int, Int)] = []
        for y in 1..<(rows - 1) {
            for x in 1..<(cols - 1) where cell(x, y) == .floor && abs(x - ex) + abs(y - ey) > 3 {
                if r() < 0.24 { candidates.append((x, y)) }
            }
        }
        let ladderIdx = candidates.isEmpty ? -1 : Int(r() * Double(candidates.count))
        for (i, (x, y)) in candidates.enumerated() {
            let roll = r()
            var kind: MineArt.Rock = .stone
            var gem = "quartz"
            let L = level
            if roll < 0.08 { kind = .coal }
            else if roll < 0.18 { kind = .copper }
            else if roll < 0.18 + (L >= 3 ? 0.08 : 0) { kind = .iron }
            else if roll < 0.26 + (L >= 8 ? 0.05 : 0) && L >= 8 { kind = .gold }
            else if roll < 0.32 && L >= 5 {
                kind = .gem
                let pool = L >= 15 ? ["amethyst", "emerald", "ruby", "diamond"] : (L >= 10 ? ["quartz", "amethyst", "emerald"] : ["quartz", "amethyst"])
                gem = pool[Int(r() * Double(pool.count))]
            }
            let s = pixelSprite(MineArt.rock(kind, gem: gem, variant: x + y), scale: 2)
            s.position = center(x, y)
            s.zPosition = 5 + CGFloat(rows - y) * 0.01
            addChild(s)
            let hp = kind == .stone ? 1 : (kind == .gem || kind == .gold ? 3 : 2)
            rocks[idx(x, y)] = RockInfo(kind: kind, gem: gem, hp: hp, sprite: s, hidesLadder: i == ladderIdx)
        }
        if ladderIdx < 0 { cells[idx(cols - 4, rows / 2)] = .down }
    }

    private func walkable(_ x: Int, _ y: Int) -> Bool {
        let c = cell(x, y)
        return (c == .floor || c == .up || c == .down) && rocks[idx(x, y)] == nil
    }

    private func canStand(_ p: CGPoint) -> Bool {
        for (ox, oy) in [(-8.0, 0.0), (8.0, 0.0), (-8.0, 8.0), (8.0, 8.0)] {
            let (x, y) = coord(CGPoint(x: p.x + ox, y: p.y + oy))
            if !walkable(x, y) { return false }
        }
        return true
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = lastTime == 0 ? 0 : min(1.0 / 30, currentTime - lastTime)
        lastTime = currentTime
        if Game.shared.save.advance(seconds: dt) { Game.shared.save.persist() }
        var ix: CGFloat = 0, iy: CGFloat = 0
        if isDown(Key.left, Key.a) { ix -= 1 }
        if isDown(Key.right, Key.d) { ix += 1 }
        if isDown(Key.up, Key.w) { iy += 1 }
        if isDown(Key.down, Key.s) { iy -= 1 }
        let moving = ix != 0 || iy != 0
        if moving {
            let len = sqrt(ix * ix + iy * iy), step = 220 * CGFloat(dt)
            let nx = CGPoint(x: pos.x + ix / len * step, y: pos.y)
            if canStand(nx) { pos = nx }
            let ny = CGPoint(x: pos.x, y: pos.y + iy / len * step)
            if canStand(ny) { pos = ny }
            if ix != 0 && iy == 0 { dir = ix < 0 ? .left : .right } else if iy != 0 { dir = iy < 0 ? .down : .up }
            walk += dt * 8
        }
        player.texture = PlayerArt.texture(dir, frame: moving ? [1, 0, 2, 0][Int(walk) % 4] : 0)
        player.position = pos
        player.zPosition = 5 + (CGFloat(rows) - pos.y / ts) * 0.01 + 0.005
        light.position = CGPoint(x: pos.x, y: pos.y + 20)

        // What are we facing?
        let v: (CGFloat, CGFloat) = dir == .left ? (-1, 0) : dir == .right ? (1, 0) : dir == .up ? (0, 1) : (0, -1)
        target = nil
        var text = ""
        for d in [18.0, 34.0] as [CGFloat] {
            let (x, y) = coord(CGPoint(x: pos.x + v.0 * d, y: pos.y + 8 + v.1 * d))
            if let r = rocks[idx(x, y)], x >= 0, y >= 0, x < cols, y < rows {
                target = (x, y)
                let names: [MineArt.Rock: String] = [.stone: "ROCK", .coal: "COAL NODE", .copper: "COPPER NODE", .iron: "IRON NODE", .gold: "GOLD NODE", .gem: "GEM NODE"]
                text = "SPACE: MINE \(names[r.kind]!)  (-\(Tools.mineEnergy(Tools.level(.pickaxe, Game.shared.save))) ENERGY)"
                break
            }
            let c = cell(x, y)
            if c == .down { target = (x, y); text = "SPACE: CLIMB DOWN TO LEVEL \(level + 1)"; break }
            if c == .up { target = (x, y); text = "SPACE: CLIMB OUT OF THE MINE"; break }
            if c == .water { target = (x, y); text = "SPACE: FISH THE CRYSTAL CAVERN"; break }
        }
        if text != promptLabel.text {
            promptLabel.text = text
            promptBG.removeFromParent()
            if !text.isEmpty {
                promptBG = panelSprite(promptLabel.size.width + 44, 56, style: .dark)
                promptBG.position = promptLabel.position
                promptBG.zPosition = 60
                addChild(promptBG)
            }
        }
    }

    private func say(_ t: String) {
        toast.text = t
        toast.removeAllActions()
        toast.alpha = 1
        toast.run(.sequence([.wait(forDuration: 1.8), .fadeOut(withDuration: 0.4)]))
    }

    private func mine(_ x: Int, _ y: Int) {
        guard var r = rocks[idx(x, y)] else { return }
        let pick = Tools.level(.pickaxe, Game.shared.save)
        guard Game.shared.save.spend(Tools.mineEnergy(pick)) else { say("TOO TIRED! EAT SOMETHING OR GO HOME TO SLEEP."); Sound.play("Funk", volume: 0.3); return }
        r.hp -= Tools.mineDamage(pick)
        Sound.play("Tink", volume: 0.35)
        r.sprite.run(.sequence([.moveBy(x: 3, y: 0, duration: 0.03), .moveBy(x: -6, y: 0, duration: 0.05), .moveBy(x: 3, y: 0, duration: 0.03)]))
        rocks[idx(x, y)] = r
        guard r.hp <= 0 else { refreshInfo(); return }
        rocks[idx(x, y)] = nil
        r.sprite.run(.sequence([.group([.scale(to: 0.3, duration: 0.15), .fadeOut(withDuration: 0.15)]), .removeFromParent()]))
        var gained: [(String, Int)] = []
        let s = Game.shared
        func give(_ id: String, _ n: Int) {
            let bonus = id != "stone" && Double.random(in: 0...1) < Double(pick) * 0.1 ? 1 : 0
            s.save.add(id, n + bonus)
            gained.append((id, n + bonus))
        }
        switch r.kind {
        case .stone:
            give("stone", 1)
            if Double.random(in: 0...1) < 0.35 { give("flint", 1) }
            if Double.random(in: 0...1) < 0.08 { give("coal", 1) }
        case .coal: give("coal", Int.random(in: 1...2))
        case .copper: give("copper", Int.random(in: 1...3))
        case .iron: give("iron", Int.random(in: 1...2))
        case .gold: give("gold", Int.random(in: 1...2))
        case .gem: give(r.gem, 1)
        }
        let text = gained.map { "+\($0.1) \(Good.byID[$0.0]!.name.uppercased())" }.joined(separator: "  ")
        say(text)
        if r.hidesLadder {
            cells[idx(x, y)] = .down
            let l = pixelSprite(MineArt.ladder(down: true), scale: 2)
            l.position = center(x, y)
            l.zPosition = 1
            addChild(l)
            say(text + "\nYOU FOUND THE LADDER DOWN!")
            Sound.play("Glass", volume: 0.4)
        }
        refreshInfo()
    }

    override func keyPressed(_ key: UInt16) {
        switch key {
        case Key.space, Key.ret, Key.enter:
            guard let t = target else { return }
            let (x, y) = t
            if rocks[idx(x, y)] != nil { mine(x, y); return }
            switch cell(x, y) {
            case .down:
                Sound.play("Pop")
                Game.shared.save.persist()
                Game.shared.presentScene(MineScene(level: level + 1))
            case .up:
                Game.shared.leaveMine()
            case .water:
                guard Game.shared.save.energy >= Energy.cast else { say("TOO TIRED TO FISH!"); return }
                Game.shared.fishingReturn = self
                Game.shared.showFishing(.cavern, boat: nil, school: false)
            default: break
            }
        case Key.i: Game.shared.showInventory(returnTo: self)
        case Key.esc: Game.shared.leaveMine()
        default: break
        }
    }
}

private extension Double { var cg: CGFloat { CGFloat(self) } }
