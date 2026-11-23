import SpriteKit

/// A wandering townsperson.
final class NPCNode: SKSpriteNode {
    let villager: Villager
    var dir: Dir = .down
    var target: CGPoint
    var pause = 0.0
    var walk = 0.0
    let bubble = PixelLabel("!", scale: 4, color: .gold)

    init(_ v: Villager, at p: CGPoint) {
        villager = v
        target = p
        super.init(texture: nil, color: .clear, size: .zero)
        anchorPoint = CGPoint(x: 0.5, y: 0)
        setPixelTexture(PlayerArt.texture(.down, frame: 0, outfit: v.outfit), scale: 2)
        position = p
        bubble.position = CGPoint(x: 0, y: 66)
        bubble.run(.repeatForever(.sequence([.moveBy(x: 0, y: 6, duration: 0.4), .moveBy(x: 0, y: -6, duration: 0.4)])))
        addChild(bubble)
        let name = PixelLabel(v.name.uppercased(), scale: 1.5, color: PColor(0xF2E6C8))
        name.position = CGPoint(x: 0, y: -8)
        addChild(name)
    }

    required init?(coder: NSCoder) { fatalError() }
}

final class MapScene: BaseScene {
    let world = WorldMap()
    private var built = false
    private let cam = SKCameraNode()
    private var lastTime: TimeInterval = 0
    private var clock = 0.0

    // Player / boat
    private let player = SKSpriteNode()
    private var playerDir: Dir = .down
    private var walkPhase = 0.0
    private var boatNode: BoatNode?
    private var boatVel = CGVector.zero
    private var wakeTimer = 0.0
    private(set) var inBoat = false
    private var moored = false
    private var carNode: CarNode?
    private var driving = false
    private var carVel = CGVector.zero

    // World objects
    private var treeSprites: [String: (SKSpriteNode, TreeSpot)] = [:]
    private var chopHits: [String: Int] = [:]
    private var plotNodes: [String: (SKSpriteNode, SKSpriteNode)] = [:]
    private var npcs: [NPCNode] = []
    private var bgSprite = SKSpriteNode()
    private let frost = SKSpriteNode(color: PColor(0xF4F8FF).ns, size: WorldMap.size)
    private var shownSeason: Season?

    // HUD
    private let hud = SKNode()
    private let dayLabel = inkLabel("", scale: 2, align: .left)
    private let timeLabel = inkLabel("", scale: 4)
    private let coinLabel = inkLabel("", scale: 3, align: .left)
    private let weatherIcon = SKSpriteNode()
    private let coolerLabel = inkLabel("", scale: 3, align: .left)
    private let gearLabel = inkLabel("", scale: 2, align: .left)
    private let baitLabel = inkLabel("", scale: 2, align: .left)
    private let seedLabel = inkLabel("", scale: 2, align: .left)
    private let energyFill = SKSpriteNode(color: .green, size: CGSize(width: 24, height: 4))
    private let energyLabel = PixelLabel("", scale: 2)
    private let prompt = SKNode()
    private var promptBG = SKSpriteNode()
    private let promptLabel = PixelLabel("", scale: 3)
    private let toastLabel = PixelLabel("", scale: 4, color: .gold)
    private let minimap = SKNode()
    private var buildSprites: [BuildingKind: SKSpriteNode] = [:]   // boat shed & garage (site until built)
    // Fish finder (sonar shown while out in a boat)
    private let finder = SKNode()
    private let finderSweep = SKSpriteNode()
    private let finderLabel = PixelLabel("", scale: 2, color: PColor(0x8AF2A8))
    private var finderBlips: [SKSpriteNode] = []
    private let finderRadius: CGFloat = 76          // on-screen radius of the sonar disc
    private let finderRange: CGFloat = 2400         // world distance covered (75 tiles)
    private let miniDot = SKSpriteNode(color: PColor(0xFF3B3B).ns, size: CGSize(width: 6, height: 6))
    private let miniScale: CGFloat = 0.026
    private let compPanel = SKNode()
    private var compBG = SKSpriteNode()
    private let compLabel = PixelLabel("", scale: 2)

    // Dialogue
    private let dialog = SKNode()
    private let dialogName = PixelLabel("", scale: 3, color: .gold, align: .left)
    private let dialogText = PixelLabel("", scale: 2, align: .left)
    private let dialogHint = PixelLabel("", scale: 2, color: PColor(0x8AE8FF), align: .left)
    private var talking: NPCNode?
    private let bigMap = SKNode()
    private var bigMapDot = SKSpriteNode()
    private var mapTexture: SKTexture?

    // Atmosphere
    private let darkness = SKSpriteNode(color: .black, size: CGSize(width: 1400, height: 900))
    private var glows: [(SKSpriteNode, CGFloat)] = []
    private let lantern = SKSpriteNode(texture: Tex.glow())
    private let weatherLayer = SKNode()
    private var drops: [SKSpriteNode] = []
    private var shownWeather: Weather?
    private var lightningTimer = 8.0
    private let flash = SKSpriteNode(color: .white, size: CGSize(width: 1400, height: 900))

    // Schools
    private var schools: [SKSpriteNode] = []
    private var schoolTimer = 1.0
    private lazy var schoolSpots: [(Int, Int)] = world.schoolCandidates()

    // Interaction state
    private enum Action {
        case none, fish(Habitat), chop(String), farm(String), door(BuildingKind), board, talk(NPCNode)
    }
    private var action: Action = .none
    private var facingHabitat: Habitat?
    private var facingPoint = CGPoint.zero
    private var shoreTarget: (CGPoint, Dir)?

    override func sceneDidAppear() {
        if !built { build(); built = true }
        lastTime = 0
        player.setPixelTexture(PlayerArt.texture(playerDir, frame: 0), scale: 2)
        if let n = boatNode { n.setDir(n.dir, force: true) }
        if let boat = Game.shared.save.boat, let node = boatNode, node.kind != boat.kind {
            let pos = node.position
            node.removeFromParent()
            boatNode = makeBoat(boat, at: pos)
        }
        for key in Game.shared.save.plots.keys { refreshPlot(key) }
        closeDialog()
        for (k, s) in buildSprites { s.setPixelTexture(Game.shared.save.isBuilt(k) ? PropArt.building(k) : PropArt.buildSite(), scale: 2) }
        syncCar()
        refreshHUD()
        showNews()
    }

    private func showNews() {
        let n = Game.shared.save.news
        guard !n.isEmpty else { return }
        Game.shared.save.news = []
        toast(n.map { PixelFont.wrap($0, maxWidth: 300) }.joined(separator: "\n"))
    }

    /// Makes sure the parked car matches the one selected at the Auto Shop.
    private func syncCar() {
        guard let car = Game.shared.save.activeCar else {
            carNode?.removeFromParent(); carNode = nil; driving = false; player.isHidden = inBoat
            return
        }
        if carNode?.car.id != car.id {
            let old = carNode?.position
            carNode?.removeFromParent()
            let n = CarNode(car: car)
            let garage = world.building(.garage).door
            n.position = old ?? CGPoint(x: garage.x, y: garage.y - 40)
            addChild(n)
            carNode = n
        }
        carNode?.setDir(carNode!.dir, force: true)
        carNode?.zPosition = depth(carNode!.position.y)
    }

    // MARK: - Build

    private func depth(_ y: CGFloat) -> CGFloat { 5 + (WorldMap.size.height - y) / WorldMap.size.height * 5 }

    private func build() {
        backgroundColor = Habitat.deepSea.water.ns
        let f0 = world.texture(frame: 0), f1 = world.texture(frame: 1)
        let bg = pixelSprite(f0, scale: WorldMap.scale)
        bg.anchorPoint = .zero
        bg.zPosition = 0
        addChild(bg)
        bg.run(.repeatForever(.animate(with: [f0, f1], timePerFrame: 0.7)))
        bgSprite = bg
        frost.anchorPoint = .zero
        frost.zPosition = 0.5
        frost.alpha = 0
        addChild(frost)

        let save = Game.shared.save
        for t in world.trees {
            if let cut = save.removedTrees[t.key] {
                if save.day - cut < 10 { world.setTile(t.x, t.y, .grass); continue }
                Game.shared.save.removedTrees[t.key] = nil
            }
            let s = pixelSprite(PropArt.tree(t.kind, variant: t.variant), scale: 2)
            s.anchorPoint = CGPoint(x: 0.5, y: 0)
            s.position = CGPoint(x: (CGFloat(t.x) + 0.5) * WorldMap.ts, y: CGFloat(t.y) * WorldMap.ts + 2)
            s.zPosition = depth(s.position.y)
            addChild(s)
            treeSprites[t.key] = (s, t)
        }

        for b in world.buildings {
            let built = Game.shared.save.isBuilt(b.kind)
            let s = pixelSprite(built ? PropArt.building(b.kind, variant: b.variant) : PropArt.buildSite(), scale: 2)
            if Construction.costs[b.kind] != nil { buildSprites[b.kind] = s }
            s.anchorPoint = CGPoint(x: 0.5, y: 0)
            s.position = CGPoint(x: b.door.x, y: b.door.y - (b.kind == .mine ? 0 : 4))
            s.zPosition = depth(s.position.y)
            addChild(s)
            if [.tackle, .general, .house, .cottageA, .cottageB, .cottageC, .villa, .autos].contains(b.kind) {
                for dx in [-0.28, 0.28] as [CGFloat] {
                    addGlow(at: CGPoint(x: s.position.x + s.size.width * dx, y: s.position.y + 32), radius: 56, color: PColor(0xF2A050), strength: 0.3)
                }
            }
            let names: [BuildingKind: String] = [.tackle: "BAIT & TACKLE", .general: "HARDWARE", .cottageA: "BOUTIQUE", .cottageB: "MARKET", .cottageC: "HOME GOODS",
                                                 .house: "HOME", .mine: "MINE", .shed: "WORKSHOP", .boatShed: "BOAT SHED", .autos: "AUTO SHOP", .garage: "GARAGE"]
            if let n = names[b.kind] {
                let l = PixelLabel(n, scale: 2, color: .gold)
                l.position = CGPoint(x: s.position.x, y: s.position.y + s.size.height + 14)
                l.zPosition = 40
                addChild(l)
            }
        }
        let board = pixelSprite(PropArt.board(), scale: 2)
        board.anchorPoint = CGPoint(x: 0.5, y: 0)
        board.position = CGPoint(x: world.boardSpot.x, y: world.boardSpot.y + 2)
        board.zPosition = depth(board.position.y)
        addChild(board)
        let bl = PixelLabel("TOWN BOARD", scale: 2, color: .gold)
        bl.position = CGPoint(x: board.position.x, y: board.position.y + 66)
        bl.zPosition = 40
        addChild(bl)

        for lp in world.lamps {
            let l = pixelSprite(PropArt.lamp(), scale: 2)
            l.anchorPoint = CGPoint(x: 0.5, y: 0)
            l.position = CGPoint(x: lp.x, y: lp.y - 12)
            l.zPosition = depth(l.position.y)
            addChild(l)
            addGlow(at: CGPoint(x: lp.x, y: lp.y + 28), radius: 110, color: PColor(0xF2A860), strength: 0.35)
        }

        for s in world.signs {
            let p = world.center(s.standTile.0, s.standTile.1)
            let sign = pixelSprite(PropArt.sign(), scale: 2)
            sign.anchorPoint = CGPoint(x: 0.5, y: 0)
            sign.position = CGPoint(x: p.x + 14, y: p.y - 4)
            sign.zPosition = depth(sign.position.y)
            addChild(sign)
            let label = PixelLabel(s.habitat.spotName.uppercased(), scale: 2)
            label.position = CGPoint(x: sign.position.x, y: sign.position.y + 46)
            label.zPosition = 40
            addChild(label)
        }

        for v in Villager.all {
            let n = NPCNode(v, at: randomPlazaPoint())
            addChild(n)
            npcs.append(n)
        }

        player.anchorPoint = CGPoint(x: 0.5, y: 0)
        player.setPixelTexture(PlayerArt.texture(.down, frame: 0), scale: 2)
        player.position = world.spawn
        addChild(player)

        lantern.size = CGSize(width: 260, height: 260)
        lantern.blendMode = .add
        lantern.color = PColor(0xFFA850).ns
        lantern.colorBlendFactor = 1
        lantern.zPosition = 55
        addChild(lantern)

        camera = cam
        addChild(cam)
        darkness.zPosition = 50
        cam.addChild(darkness)
        weatherLayer.zPosition = 52
        cam.addChild(weatherLayer)
        flash.alpha = 0
        flash.zPosition = 53
        cam.addChild(flash)
        mapTexture = f0
        buildHUD(f0)
        updateCamera()
        updateAtmosphere(0)
    }

    private func randomPlazaPoint() -> CGPoint {
        let r = world.plazaRect
        for _ in 0..<40 {
            let x = r.x + 1 + Int.random(in: 0..<(r.w - 2)), y = r.y + 1 + Int.random(in: 0..<(r.h - 2))
            if world[x, y] == .plaza && world[x, y + 1] == .plaza { return world.center(x, y) }
        }
        return world.center(r.x + r.w / 2, r.y + 2)
    }

    private func addGlow(at p: CGPoint, radius: CGFloat, color: PColor, strength: CGFloat) {
        let g = SKSpriteNode(texture: Tex.glow())
        g.size = CGSize(width: radius * 2, height: radius * 2)
        g.position = p
        g.blendMode = .add
        g.color = color.ns
        g.colorBlendFactor = 1
        g.zPosition = 55
        addChild(g)
        glows.append((g, strength))
    }

    private func buildHUD(_ mapTex: SKTexture) {
        hud.zPosition = 100
        cam.addChild(hud)

        let clockPanel = panelSprite(252, 132)
        clockPanel.position = CGPoint(x: 640 - 136, y: 400 - 76)
        hud.addChild(clockPanel)
        dayLabel.position = CGPoint(x: -104, y: 40)
        clockPanel.addChild(dayLabel)
        weatherIcon.position = CGPoint(x: 84, y: 4)
        clockPanel.addChild(weatherIcon)
        timeLabel.position = CGPoint(x: -22, y: 4)
        clockPanel.addChild(timeLabel)
        let coin = pixelSprite(Icons.coin(), scale: 3)
        coin.position = CGPoint(x: -84, y: -36)
        clockPanel.addChild(coin)
        coinLabel.position = CGPoint(x: -66, y: -36)
        clockPanel.addChild(coinLabel)

        let info = panelSprite(430, 144)
        info.position = CGPoint(x: -640 + 225, y: 400 - 82)
        hud.addChild(info)
        let fish = pixelSprite(Icons.fish(), scale: 3)
        fish.position = CGPoint(x: -178, y: 40)
        info.addChild(fish)
        coolerLabel.position = CGPoint(x: -154, y: 40)
        info.addChild(coolerLabel)
        gearLabel.position = CGPoint(x: -190, y: 12)
        info.addChild(gearLabel)
        baitLabel.position = CGPoint(x: -190, y: -12)
        info.addChild(baitLabel)
        seedLabel.position = CGPoint(x: -190, y: -36)
        info.addChild(seedLabel)

        let eb = panelSprite(48, 220, scale: 2, style: .wood)
        eb.position = CGPoint(x: 640 - 40, y: -400 + 136)
        hud.addChild(eb)
        let track = SKSpriteNode(color: PColor(0x2A1A0E).ns, size: CGSize(width: 24, height: 180))
        track.position = CGPoint(x: 0, y: -6)
        eb.addChild(track)
        energyFill.anchorPoint = CGPoint(x: 0.5, y: 0)
        energyFill.position = CGPoint(x: 0, y: -96)
        eb.addChild(energyFill)
        let eLetter = PixelLabel("E", scale: 2, color: .gold)
        eLetter.position = CGPoint(x: 0, y: 98)
        eb.addChild(eLetter)
        energyLabel.position = CGPoint(x: 640 - 40, y: -400 + 14)
        hud.addChild(energyLabel)

        let mw = WorldMap.size.width * miniScale, mh = WorldMap.size.height * miniScale
        minimap.position = CGPoint(x: 640 - 80 - mw / 2 - 12, y: -400 + mh / 2 + 22)
        hud.addChild(minimap)
        minimap.addChild(panelSprite(mw + 24, mh + 24, scale: 2, style: .dark))
        minimap.addChild(SKSpriteNode(texture: mapTex, size: CGSize(width: mw, height: mh)))
        for s in world.signs {
            let d = SKSpriteNode(color: .white, size: CGSize(width: 4, height: 4))
            d.position = miniPoint(world.center(s.waterTile.0, s.waterTile.1))
            minimap.addChild(d)
        }
        for b in world.buildings where b.kind != .fountain {
            let d = SKSpriteNode(color: (b.kind == .house ? PColor(0x5AB4FF) : PColor(0xFFD23A)).ns, size: CGSize(width: 6, height: 6))
            d.position = miniPoint(b.door)
            minimap.addChild(d)
        }
        miniDot.run(.repeatForever(.sequence([.fadeAlpha(to: 0.3, duration: 0.35), .fadeAlpha(to: 1, duration: 0.35)])))
        minimap.addChild(miniDot)

        buildFinder(above: minimap.position, mapHeight: mh)

        compPanel.position = CGPoint(x: 0, y: 400 - 40)
        compPanel.addChild(compBG)
        compPanel.addChild(compLabel)
        compPanel.isHidden = true
        hud.addChild(compPanel)

        prompt.position = CGPoint(x: 0, y: -300)
        prompt.addChild(promptBG)
        prompt.addChild(promptLabel)
        prompt.isHidden = true
        hud.addChild(prompt)

        toastLabel.position = CGPoint(x: 0, y: 190)
        toastLabel.alpha = 0
        hud.addChild(toastLabel)

        dialog.position = CGPoint(x: -80, y: -290)
        dialog.addChild(panelSprite(1060, 170, scale: 3, style: .dark))
        dialogName.position = CGPoint(x: -490, y: 50)
        dialog.addChild(dialogName)
        dialogText.position = CGPoint(x: -490, y: 4)
        dialog.addChild(dialogText)
        dialogHint.position = CGPoint(x: -490, y: -56)
        dialog.addChild(dialogHint)
        dialog.isHidden = true
        hud.addChild(dialog)

        bigMap.zPosition = 200
        bigMap.isHidden = true
        hud.addChild(bigMap)

        let help = PixelLabel("SPACE: ACT  E: BOAT  C: CAR  Q: SEED  I: BAG  G: GEAR  J: JOURNAL  M: MAP  ESC: MENU", scale: 2, align: .left)
        help.position = CGPoint(x: -628, y: -384)
        hud.addChild(help)
    }

    private func miniPoint(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.x * miniScale - WorldMap.size.width * miniScale / 2, y: p.y * miniScale - WorldMap.size.height * miniScale / 2)
    }

    private func refreshHUD() {
        let s = Game.shared.save
        dayLabel.text = GameCalendar.label(s.day)
        timeLabel.text = Clock.timeString(s.minutes)
        coinLabel.text = "\(s.coins)G"
        weatherIcon.setPixelTexture(Icons.weather(s.weather), scale: 3)
        coolerLabel.text = "COOLER \(s.cooler.count)/\(s.coolerCapacity)"
        coolerLabel.textColor = s.coolerFull ? PColor(0xC8281A) : .ink
        gearLabel.text = s.rod.name.uppercased() + "  ·  " + (s.boat?.name.uppercased() ?? "NO BOAT")
        let lure = s.item(.lure)?.name.uppercased() ?? "NONE"
        let bait = s.item(.bait).map { "\($0.name.uppercased()) ×\(s.baitLeft)" } ?? "NONE"
        baitLabel.text = "LURE: \(lure)  ·  BAIT: \(bait)"
        seedLabel.text = "SEED (Q): " + (s.selectedSeed.map { "\($0.name.uppercased()) ×\(s.count($0.seedID))" } ?? "NONE") + "  ·  TIMBER \(s.count("timber"))"
        let frac = CGFloat(s.energy) / CGFloat(Energy.max)
        energyFill.size.height = max(4, snap(180 * frac, 4))
        energyFill.color = NSColor(hue: 0.33 * frac, saturation: 0.75, brightness: 0.9, alpha: 1)
        energyLabel.text = "\(s.energy)"
        energyLabel.textColor = s.nightFactor > 1 ? PColor(0xFF9A4A) : .white
        let hour = Clock.hour(s.minutes)
        for n in npcs where n.villager.id == s.spouse { n.isHidden = hour < 8 || hour >= 18 }
        for n in npcs { n.bubble.isHidden = !s.requests.contains { $0.npc == n.villager.id } }
        if let c = s.comp {
            let st = c.standings(final: false)
            let place = (st.firstIndex { $0.2 } ?? 0) + 1
            let secs = Int(max(0, c.timeLeft))
            let text = "\(c.comp.name.uppercased())  \(secs / 60):\(String(format: "%02d", secs % 60))  ·  YOU \(c.comp.format(c.playerScore))  ·  #\(place) OF 5  ·  \(c.comp.habitat.spotName.uppercased())"
            if compLabel.text != text {
                compLabel.text = text
                compBG.removeFromParent()
                compBG = panelSprite(compLabel.size.width + 40, 48, scale: 2, style: .dark)
                compPanel.insertChild(compBG, at: 0)
            }
            compPanel.isHidden = false
        } else if let ch = s.charter {
            let text = "CHARTER: \(ch.client) WANTS \(ch.target) FISH AT \(ch.water.spotName.uppercased())  ·  \(ch.caught)/\(ch.target)  ·  \(ch.perFish)G EACH"
            if compLabel.text != text {
                compLabel.text = text
                compBG.removeFromParent()
                compBG = panelSprite(compLabel.size.width + 40, 48, scale: 2, style: .dark)
                compPanel.insertChild(compBG, at: 0)
            }
            compPanel.isHidden = false
        } else {
            compPanel.isHidden = true
        }
    }

    func toast(_ text: String) {
        toastLabel.text = text
        toastLabel.removeAllActions()
        toastLabel.alpha = 1
        toastLabel.run(.sequence([.wait(forDuration: 2.4), .fadeOut(withDuration: 0.5)]))
    }

    private func setPrompt(_ text: String?) {
        guard let text, talking == nil else { prompt.isHidden = true; return }
        prompt.isHidden = false
        if promptLabel.text != text {
            promptLabel.text = text
            promptBG.removeFromParent()
            promptBG = panelSprite(promptLabel.size.width + 48, 60, style: .dark)
            prompt.insertChild(promptBG, at: 0)
        }
    }

    private func tired() {
        toast("TOO TIRED! EAT SOMETHING (I) OR SLEEP.")
        Sound.play("Funk", volume: 0.3)
    }

    // MARK: - Update

    override func update(_ currentTime: TimeInterval) {
        let dt = lastTime == 0 ? 0 : min(1.0 / 30, currentTime - lastTime)
        lastTime = currentTime
        clock += dt

        if Game.shared.save.advance(seconds: dt) {
            let s = Game.shared.save
            if let c = Competition.on(day: s.day) {
                toast("\(GameCalendar.label(s.day))\nTODAY: \(c.name.uppercased())! SEE THE BOARD")
            } else {
                toast("\(GameCalendar.label(s.day))  ·  \(s.weather.name.uppercased())")
            }
            for key in s.plots.keys { refreshPlot(key) }
            s.persist()
            run(.sequence([.wait(forDuration: 2.6), .run { [weak self] in self?.showNews() }]))
        }
        if Game.shared.tickCompetition(dt) { return }
        let h = Clock.hour(Game.shared.save.minutes)
        if Int(h) != Int(Clock.hour(Game.shared.save.minutes - dt * Clock.minutesPerSecond)) {
            if Int(h) == 20 { toast("IT'S GETTING LATE...\nEVERYTHING TAKES 50% MORE ENERGY") }
            if Int(h) == 0 { toast("IT'S PAST MIDNIGHT!\nEVERYTHING TAKES DOUBLE ENERGY. GO TO BED!") }
        }

        var ix: CGFloat = 0, iy: CGFloat = 0
        if talking == nil && bigMap.isHidden {
            if isDown(Key.left, Key.a) { ix -= 1 }
            if isDown(Key.right, Key.d) { ix += 1 }
            if isDown(Key.up, Key.w) { iy += 1 }
            if isDown(Key.down, Key.s) { iy -= 1 }
        }
        if inBoat { updateBoat(dt, ix, iy) } else if driving { updateDriving(dt, ix, iy) } else { updateWalking(dt, ix, iy) }

        updateNPCs(dt)
        updateCamera()
        updateSchools(dt)
        updateFinder(dt)
        updateInteraction()
        updateAtmosphere(dt)
        if Int(clock * 4) != Int((clock - dt) * 4) { refreshHUD() }
    }

    private func updateWalking(_ dt: Double, _ ix: CGFloat, _ iy: CGFloat) {
        let moving = ix != 0 || iy != 0
        if moving {
            let len = sqrt(ix * ix + iy * iy)
            let step = 260 * CGFloat(dt)
            let nx = player.position.x + ix / len * step
            if canStand(CGPoint(x: nx, y: player.position.y)) { player.position.x = nx }
            let ny = player.position.y + iy / len * step
            if canStand(CGPoint(x: player.position.x, y: ny)) { player.position.y = ny }
            if ix != 0 && iy == 0 { playerDir = ix < 0 ? .left : .right }
            else if iy != 0 && ix == 0 { playerDir = iy < 0 ? .down : .up }
            else if (playerDir == .up || playerDir == .down) == false { playerDir = ix < 0 ? .left : .right }
            else { playerDir = iy < 0 ? .down : .up }
            walkPhase += dt * 8
        } else {
            walkPhase = 0
        }
        let frame = moving ? [1, 0, 2, 0][Int(walkPhase) % 4] : 0
        player.texture = PlayerArt.texture(playerDir, frame: frame)
        player.zPosition = depth(player.position.y)
        lantern.position = CGPoint(x: player.position.x, y: player.position.y + 24)
    }

    private func carFits(_ p: CGPoint) -> Bool {
        for (ox, oy) in [(-14.0, 0.0), (14.0, 0.0), (-14.0, 14.0), (14.0, 14.0)] {
            let t = world.tile(at: CGPoint(x: p.x + ox, y: p.y + oy))
            if !t.walkable || t == .soil { return false }
        }
        return true
    }

    private func updateDriving(_ dt: Double, _ ix: CGFloat, _ iy: CGFloat) {
        guard let node = carNode else { driving = false; return }
        let t = CGFloat(dt)
        let tile = world.tile(at: node.position)
        let road = tile == .path || tile == .plaza || tile == .bridge || tile == .pier
        let maxSp = CGFloat(node.car.speed) * (road ? 1 : (node.car.id == "car.jeep" ? 0.9 : 0.55))
        let len = max(1, sqrt(ix * ix + iy * iy))
        carVel.dx += ix / len * 1400 * t
        carVel.dy += iy / len * 1400 * t
        let drag = 1 - min(1, 4 * t)
        carVel.dx *= drag
        carVel.dy *= drag
        let sp = sqrt(carVel.dx * carVel.dx + carVel.dy * carVel.dy)
        if sp > maxSp { carVel.dx *= maxSp / sp; carVel.dy *= maxSp / sp }
        let nx = CGPoint(x: node.position.x + carVel.dx * t, y: node.position.y)
        if carFits(nx) { node.position = nx } else { carVel.dx = 0 }
        let ny = CGPoint(x: node.position.x, y: node.position.y + carVel.dy * t)
        if carFits(ny) { node.position = ny } else { carVel.dy = 0 }
        if sp > 20 {
            if abs(carVel.dx) > abs(carVel.dy) { node.setDir(carVel.dx < 0 ? .left : .right) } else { node.setDir(carVel.dy < 0 ? .down : .up) }
        }
        node.zPosition = depth(node.position.y)
        player.position = node.position
        lantern.position = node.position
    }

    private func toggleCar() {
        guard let node = carNode else {
            toast(Game.shared.save.carsOwned.isEmpty ? "BUY A CAR AT THE AUTO SHOP IN TOWN!" : "PICK A CAR AT THE AUTO SHOP")
            return
        }
        if driving {
            driving = false
            for off in [CGPoint(x: 0, y: -34), CGPoint(x: 34, y: 0), CGPoint(x: -34, y: 0), CGPoint(x: 0, y: 40)] {
                let p = CGPoint(x: node.position.x + off.x, y: node.position.y + off.y)
                if canStand(p) { player.position = p; break }
            }
            player.isHidden = false
            Sound.play("Pop", volume: 0.3)
        } else if hypot(node.position.x - player.position.x, node.position.y - player.position.y) < 70 {
            driving = true
            player.isHidden = true
            carVel = .zero
            Sound.play("Purr", volume: 0.3)
        } else {
            toast("WALK TO YOUR CAR TO DRIVE IT")
        }
    }

    private func canStand(_ p: CGPoint) -> Bool {
        for (ox, oy) in [(-8.0, 0.0), (8.0, 0.0), (-8.0, 8.0), (8.0, 8.0)] {
            if !world.tile(at: CGPoint(x: p.x + ox, y: p.y + oy)).walkable { return false }
        }
        return true
    }

    private func dirVector(_ d: Dir) -> CGVector {
        switch d {
        case .up: return CGVector(dx: 0, dy: 1)
        case .down: return CGVector(dx: 0, dy: -1)
        case .left: return CGVector(dx: -1, dy: 0)
        case .right: return CGVector(dx: 1, dy: 0)
        }
    }

    private func updateNPCs(_ dt: Double) {
        for n in npcs {
            if n === talking { continue }
            if n.pause > 0 { n.pause -= dt; n.texture = PlayerArt.texture(n.dir, frame: 0, outfit: n.villager.outfit); continue }
            let dx = n.target.x - n.position.x, dy = n.target.y - n.position.y
            let dist = hypot(dx, dy)
            if dist < 6 {
                n.pause = Double.random(in: 1.5...5)
                n.target = randomPlazaPoint()
                continue
            }
            let step = min(dist, 70 * CGFloat(dt))
            let next = CGPoint(x: n.position.x + dx / dist * step, y: n.position.y + dy / dist * step)
            if world.tile(at: next).walkable && world.tile(at: CGPoint(x: next.x, y: next.y + 8)).walkable {
                n.position = next
            } else {
                n.target = randomPlazaPoint()
            }
            n.dir = abs(dx) > abs(dy) ? (dx < 0 ? .left : .right) : (dy < 0 ? .down : .up)
            n.walk += dt * 7
            n.texture = PlayerArt.texture(n.dir, frame: [1, 0, 2, 0][Int(n.walk) % 4], outfit: n.villager.outfit)
            n.zPosition = depth(n.position.y)
        }
    }

    // MARK: Boat

    private func makeBoat(_ boat: Boat, at p: CGPoint) -> BoatNode {
        let n = BoatNode(kind: boat.kind)
        n.position = p
        n.zPosition = depth(p.y)
        addChild(n)
        return n
    }

    private func boatFits(_ p: CGPoint, _ boat: Boat) -> Bool {
        for (ox, oy) in [(-12.0, -8.0), (12.0, -8.0), (-12.0, 8.0), (12.0, 8.0)] {
            if !world.navigable(CGPoint(x: p.x + ox, y: p.y + oy), boat: boat) { return false }
        }
        return true
    }

    private func launchBoat() {
        let save = Game.shared.save
        if let problem = save.towProblem { toast(problem); Sound.play("Funk", volume: 0.3); return }
        guard driving else { toast("DRIVE YOUR CAR (C) TO THE WATER TO LAUNCH YOUR BOAT"); return }
        guard let boat = save.boat, let h = facingHabitat else { return }
        guard boat.waters.contains(h) else {
            toast("YOUR \(boat.name.uppercased()) CAN'T HANDLE THE \(h.displayName.uppercased())!")
            Sound.play("Funk", volume: 0.3)
            return
        }
        let c = world.tileCoord(facingPoint)
        var spot = world.center(c.0, c.1)
        let v = dirVector(carNode?.dir ?? playerDir)
        if !boatFits(spot, boat) {
            let further = CGPoint(x: spot.x + v.dx * WorldMap.ts, y: spot.y + v.dy * WorldMap.ts)
            guard boatFits(further, boat) else { toast("TOO NARROW TO LAUNCH HERE"); return }
            spot = further
        }
        inBoat = true
        driving = false
        moored = false
        player.isHidden = true
        boatNode?.removeFromParent()
        boatNode = makeBoat(boat, at: spot)
        boatNode?.setDir(carNode?.dir ?? playerDir, force: true)
        boatVel = .zero
        Sound.play("Bottle", volume: 0.35)
    }

    private func goAshore() {
        guard let st = shoreTarget else { return }
        inBoat = false
        // The boat stays moored here so you can sail back (e.g. from Paradise Isle).
        moored = true
        player.isHidden = false
        player.position = st.0
        playerDir = st.1
        Sound.play("Pop", volume: 0.3)
    }

    private func updateBoat(_ dt: Double, _ ix: CGFloat, _ iy: CGFloat) {
        guard let node = boatNode, let boat = Game.shared.save.boat else { return }
        let t = CGFloat(dt)
        let len = max(1, sqrt(ix * ix + iy * iy))
        boatVel.dx += ix / len * 600 * t
        boatVel.dy += iy / len * 600 * t
        let drag = 1 - min(1, 1.8 * t)
        boatVel.dx *= drag
        boatVel.dy *= drag
        let sp = sqrt(boatVel.dx * boatVel.dx + boatVel.dy * boatVel.dy)
        let maxSp = CGFloat(boat.speed) * 1.2
        if sp > maxSp { boatVel.dx *= maxSp / sp; boatVel.dy *= maxSp / sp }
        let nx = node.position.x + boatVel.dx * t
        if boatFits(CGPoint(x: nx, y: node.position.y), boat) { node.position.x = nx } else { boatVel.dx *= -0.3 }
        let ny = node.position.y + boatVel.dy * t
        if boatFits(CGPoint(x: node.position.x, y: ny), boat) { node.position.y = ny } else { boatVel.dy *= -0.3 }
        if sp > 25 {
            if abs(boatVel.dx) > abs(boatVel.dy) * 1.2 { node.setDir(boatVel.dx < 0 ? .left : .right) }
            else if abs(boatVel.dy) > abs(boatVel.dx) * 1.2 { node.setDir(boatVel.dy < 0 ? .down : .up) }
        }
        node.zPosition = depth(node.position.y - 10)
        lantern.position = node.position
        wakeTimer -= dt
        if sp > 60 && wakeTimer <= 0 {
            wakeTimer = 0.07
            let w = pixelSprite(PropArt.ripple(frame: 0), scale: 2)
            let back = CGVector(dx: -boatVel.dx / sp, dy: -boatVel.dy / sp)
            w.position = CGPoint(x: node.position.x + back.dx * 30 + CGFloat.random(in: -4...4), y: node.position.y + back.dy * 22 - 6 + CGFloat.random(in: -3...3))
            w.zPosition = 3
            addChild(w)
            w.run(.sequence([.group([.scale(to: 2, duration: 0.7), .fadeOut(withDuration: 0.7)]), .removeFromParent()]))
        }
    }

    private func updateCamera() {
        let W = WorldMap.size.width, H = WorldMap.size.height
        let focus = inBoat ? (boatNode?.position ?? player.position) : (driving ? (carNode?.position ?? player.position) : player.position)
        cam.position = CGPoint(x: min(max(focus.x, 640), W - 640), y: min(max(focus.y, 400), H - 400))
        miniDot.position = miniPoint(focus)
    }

    // MARK: Schools

    private func updateSchools(_ dt: Double) {
        schoolTimer -= dt
        guard schoolTimer <= 0 else { return }
        schoolTimer = Double.random(in: 4...8)
        schools.removeAll { $0.parent == nil }
        guard schools.count < 10, let c = schoolSpots.randomElement() else { return }
        let s = SKSpriteNode()
        s.setPixelTexture(PropArt.school(frame: 0), scale: 2)
        s.position = world.center(c.0, c.1)
        s.zPosition = 3
        s.alpha = 0
        addChild(s)
        s.run(.repeatForever(.animate(with: (0..<4).map { PropArt.school(frame: $0) }, timePerFrame: 0.18)))
        s.run(.sequence([.fadeIn(withDuration: 1), .wait(forDuration: Double.random(in: 60...110)), .fadeOut(withDuration: 1.5), .removeFromParent()]))
        schools.append(s)
    }

    // MARK: Construction

    private func construct(_ k: BuildingKind) {
        guard let cost = Construction.costs[k] else { return }
        let game = Game.shared
        let t = game.save.count("timber"), st = game.save.count("stone")
        guard t >= cost.timber, st >= cost.stone else {
            toast("TO BUILD THE \(Construction.name(k)) YOU NEED \(Construction.costLabel(k)).\nYOU HAVE \(t) TIMBER + \(st) STONE.")
            Sound.play("Funk", volume: 0.3)
            return
        }
        game.save.take("timber", cost.timber)
        game.save.take("stone", cost.stone)
        if k == .boatShed { game.save.boatShedBuilt = true } else { game.save.garageBuilt = true }
        game.save.persist()
        buildSprites[k]?.setPixelTexture(PropArt.building(k), scale: 2)
        Sound.play("Glass", volume: 0.5)
        toast(k == .garage ? "YOU BUILT A GARAGE! BUY CARS AT THE AUTO SHOP." : "YOU BUILT A BOAT SHED! BUY BOATS AT BAIT & TACKLE.")
        refreshHUD()
    }

    private func switchCar() {
        let s = Game.shared.save
        guard !s.carsOwned.isEmpty else { toast("YOUR GARAGE IS EMPTY.\nBUY A CAR AT THE AUTO SHOP!"); return }
        let i = s.car.flatMap { s.carsOwned.firstIndex(of: $0) } ?? -1
        let next = s.carsOwned[(i + 1) % s.carsOwned.count]
        Game.shared.save.car = next
        carNode?.removeFromParent(); carNode = nil
        syncCar()
        toast("NOW DRIVING: \(Car.byID[next]?.name.uppercased() ?? "")")
    }

    // MARK: Fish finder

    private func buildFinder(above mini: CGPoint, mapHeight mh: CGFloat) {
        finder.position = CGPoint(x: mini.x, y: mini.y + mh / 2 + 12 + 10 + 122)
        finder.isHidden = true
        hud.addChild(finder)
        finder.addChild(panelSprite(204, 244, scale: 2, style: .dark))
        let title = PixelLabel("FISH FINDER", scale: 2, color: .gold)
        title.position = CGPoint(x: 0, y: 104)
        finder.addChild(title)
        let screen = pixelSprite(Tex.get("finder.screen") {
            let n = 80, c = 40.0
            let b = PixelBuffer(n, n)
            b.ellipse(c, c, 40, 40, PColor(0x3A4A44))
            b.ellipse(c, c, 38, 38, PColor(0x082A18))
            let ring = PColor(0x1E6A3A)
            for r in [12.7, 25.3] {
                for k in 0..<160 {
                    let a = Double(k) / 160 * 2 * .pi
                    b.set(Int(c + cos(a) * r), Int(c + sin(a) * r), ring)
                }
            }
            for i in 4..<76 where i % 2 == 0 { b.set(i, 40, ring); b.set(40, i, ring) }
            return b
        }, scale: 2)
        screen.position = CGPoint(x: 0, y: 12)
        finder.addChild(screen)
        finderSweep.color = PColor(0x5AF28A, 150).ns
        finderSweep.size = CGSize(width: finderRadius - 2, height: 2)
        finderSweep.anchorPoint = CGPoint(x: 0, y: 0.5)
        finderSweep.position = screen.position
        finder.addChild(finderSweep)
        let you = SKSpriteNode(color: .white, size: CGSize(width: 6, height: 6))
        you.position = screen.position
        finder.addChild(you)
        finderLabel.position = CGPoint(x: 0, y: -96)
        finder.addChild(finderLabel)
    }

    private func updateFinder(_ dt: Double) {
        let save = Game.shared.save
        guard save.fishFinder, inBoat, bigMap.isHidden, let boatPos = boatNode?.position else { finder.isHidden = true; return }
        finder.isHidden = false
        finderSweep.zRotation -= CGFloat(dt) * 2.6
        let sweep = finderSweep.zRotation
        let live = schools.filter { $0.parent != nil }
        while finderBlips.count < live.count + 1 {
            let b = SKSpriteNode(color: .white, size: CGSize(width: 6, height: 6))
            finder.addChild(b)
            finderBlips.append(b)
        }
        finderBlips.forEach { $0.isHidden = true }

        var nearest: (d: CGFloat, dx: CGFloat, dy: CGFloat)?
        var anyReachable = false
        for (i, s) in live.enumerated() {
            let dx = s.position.x - boatPos.x, dy = s.position.y - boatPos.y
            let d = hypot(dx, dy)
            var reachable = true
            if case .water(let h) = world.tile(at: s.position), let boat = save.boat { reachable = boat.waters.contains(h) }
            if reachable {
                anyReachable = true
                if nearest == nil || d < nearest!.d { nearest = (d, dx, dy) }
            }
            guard d <= finderRange else { continue }
            let blip = finderBlips[i]
            blip.isHidden = false
            blip.position = CGPoint(x: snap(dx / finderRange * finderRadius, 2), y: 12 + snap(dy / finderRange * finderRadius, 2))
            blip.color = (reachable ? PColor(0xFFE05A) : PColor(0x6A7A70)).ns
            // Blips flare as the sweep passes, then fade.
            var behind = (sweep - atan2(dy, dx)).truncatingRemainder(dividingBy: 2 * .pi)
            if behind < 0 { behind += 2 * .pi }
            blip.alpha = max(0.35, 1 - (2 * .pi - behind) / (2 * .pi) * 1.3)
        }
        // Schools beyond range show as a dim marker on the rim.
        if let n = nearest, n.d > finderRange {
            let edge = finderBlips[live.count]
            edge.isHidden = false
            edge.color = PColor(0xFFE05A).ns
            edge.alpha = 0.55
            edge.position = CGPoint(x: snap(n.dx / n.d * (finderRadius - 4), 2), y: 12 + snap(n.dy / n.d * (finderRadius - 4), 2))
        }
        if let n = nearest {
            let dirs = ["E", "NE", "N", "NW", "W", "SW", "S", "SE"]
            var a = atan2(n.dy, n.dx); if a < 0 { a += 2 * .pi }
            let dir = dirs[Int((a / (.pi / 4)).rounded()) % 8]
            let m = Int(n.d / WorldMap.ts)
            finderLabel.text = m < 3 ? "SCHOOL HERE!" : "SCHOOL \(m)M \(dir)"
        } else {
            finderLabel.text = live.isEmpty || !anyReachable ? "NO SCHOOLS" : ""
        }
    }

    private func school(near p: CGPoint, within r: CGFloat) -> SKSpriteNode? {
        schools.first { $0.parent != nil && hypot($0.position.x - p.x, $0.position.y - p.y) < r }
    }

    // MARK: Farm & trees

    private func plotKey(_ x: Int, _ y: Int) -> String { "\(x),\(y)" }

    private func refreshPlot(_ key: String) {
        let parts = key.split(separator: ",").compactMap { Int($0) }
        guard parts.count == 2 else { return }
        let (x, y) = (parts[0], parts[1])
        let p = Game.shared.save.plots[key]
        if plotNodes[key] == nil {
            let soil = SKSpriteNode(), crop = SKSpriteNode()
            soil.position = world.center(x, y)
            soil.zPosition = 1
            crop.anchorPoint = CGPoint(x: 0.5, y: 0)
            crop.position = CGPoint(x: world.center(x, y).x, y: CGFloat(y) * WorldMap.ts + 2)
            crop.zPosition = depth(crop.position.y)
            addChild(soil)
            addChild(crop)
            plotNodes[key] = (soil, crop)
        }
        let (soil, crop) = plotNodes[key]!
        guard let p, p.tilled else { soil.isHidden = true; crop.isHidden = true; return }
        soil.isHidden = false
        soil.setPixelTexture(FarmArt.soil(watered: p.wateredDay == Game.shared.save.day), scale: 2)
        if let cid = p.crop, let c = Crop.byID[cid] {
            crop.isHidden = false
            crop.setPixelTexture(FarmArt.crop(c, stage: p.stage, dead: p.dead), scale: 2)
        } else {
            crop.isHidden = true
        }
    }

    private func farmPrompt(_ key: String) -> String {
        let s = Game.shared.save
        guard let p = s.plots[key], p.tilled else {
            let h = Tools.level(.hoe, s)
            return "SPACE: TILL SOIL" + (Tools.tillArea(h) > 1 ? " ×\(Tools.tillArea(h))" : "") + "  (-\(Tools.tillEnergy(h)) ENERGY)"
        }
        guard let cid = p.crop, let c = Crop.byID[cid] else {
            if let seed = s.selectedSeed { return "SPACE: PLANT \(seed.name.uppercased())" + (seed.seasons.contains(s.season) ? "" : " (OUT OF SEASON!)") + "   Q: CHANGE SEED" }
            return "NO SEEDS - BUY SOME AT THE MARKET"
        }
        if p.dead { return "SPACE: CLEAR WITHERED \(c.name.uppercased())" }
        if p.mature { return "SPACE: HARVEST \(c.name.uppercased())" }
        if p.wateredDay != s.day { return "SPACE: WATER \(c.name.uppercased())  (\(c.days - p.growth) DAYS LEFT)" }
        return "\(c.name.uppercased()): WATERED  ·  \(c.days - p.growth) DAYS LEFT"
    }

    private func doFarm(_ key: String) {
        let game = Game.shared
        var p = game.save.plots[key] ?? Plot(tilled: false)
        if !p.tilled {
            let hoe = Tools.level(.hoe, game.save)
            guard game.save.spend(Tools.tillEnergy(hoe)) else { tired(); return }
            p = Plot()
            if game.save.weather.isWet { p.wateredDay = game.save.day }
            Sound.play("Pop", volume: 0.25)
            // Better hoes till extra tiles in the facing direction
            let parts = key.split(separator: ",").compactMap { Int($0) }
            let v = dirVector(playerDir)
            for i in 1..<Tools.tillArea(hoe) {
                let (x, y) = (parts[0] + Int(v.dx) * i, parts[1] + Int(v.dy) * i)
                let k2 = plotKey(x, y)
                guard world[x, y] == .soil, game.save.plots[k2]?.tilled != true else { continue }
                var extra = Plot()
                if game.save.weather.isWet { extra.wateredDay = game.save.day }
                game.save.plots[k2] = extra
                refreshPlot(k2)
            }
        } else if let cid = p.crop, let c = Crop.byID[cid] {
            if p.dead {
                p.crop = nil; p.dead = false; p.growth = 0
            } else if p.mature {
                let n = Double.random(in: 0...1) < 0.2 ? 2 : 1
                game.save.add(c.produceID, n)
                p.crop = nil; p.growth = 0
                toast("+\(n) \(c.name.uppercased())")
                Sound.play("Purr", volume: 0.35)
            } else if p.wateredDay != game.save.day {
                guard game.save.spend(Energy.water) else { tired(); return }
                p.wateredDay = game.save.day
                Sound.play("Bottle", volume: 0.2)
                if let sp = plotNodes[key]?.0 { splashAt(sp.position) }
            } else { return }
        } else {
            guard let seed = game.save.selectedSeed else { toast("NO SEEDS! BUY SOME AT THE MARKET"); return }
            game.save.take(seed.seedID)
            p.crop = seed.id
            p.growth = 0
            p.dead = !seed.seasons.contains(game.save.season)
            Sound.play("Tink", volume: 0.3)
        }
        game.save.plots[key] = p
        refreshPlot(key)
        refreshHUD()
    }

    private func splashAt(_ p: CGPoint) {
        for _ in 0..<5 {
            let d = SKSpriteNode(color: PColor(0x8AC8F2).ns, size: CGSize(width: 4, height: 4))
            d.position = p
            d.zPosition = 30
            addChild(d)
            d.run(.sequence([.moveBy(x: CGFloat.random(in: -14...14), y: CGFloat.random(in: 4...16), duration: 0.25), .fadeOut(withDuration: 0.15), .removeFromParent()]))
        }
    }

    private func chop(_ key: String) {
        guard let entry = treeSprites[key] else { return }
        let (sprite, t) = entry
        let axe = Tools.level(.axe, Game.shared.save)
        guard Game.shared.save.spend(Tools.chopEnergy(axe)) else { tired(); return }
        let hits = (chopHits[key] ?? 0) + 1
        chopHits[key] = hits
        Sound.play("Pop", volume: 0.3)
        sprite.run(.sequence([.moveBy(x: 4, y: 0, duration: 0.04), .moveBy(x: -8, y: 0, duration: 0.06), .moveBy(x: 4, y: 0, duration: 0.04)]))
        let needed = t.kind == .bush ? 1 : Tools.chopHits(axe)
        guard hits >= needed else { return }
        let gain: Int
        switch t.kind {
        case .oak: gain = Int.random(in: 3...5)
        case .pine: gain = Int.random(in: 3...4)
        case .palm: gain = 2
        case .dead, .bush: gain = 1
        }
        Game.shared.save.add("timber", gain + axe)
        Game.shared.save.removedTrees[key] = Game.shared.save.day
        world.setTile(t.x, t.y, .grass)
        treeSprites[key] = nil
        chopHits[key] = nil
        sprite.run(.sequence([.group([.rotate(byAngle: playerDir == .left ? 1.4 : -1.4, duration: 0.4), .fadeOut(withDuration: 0.5)]), .removeFromParent()]))
        toast("+\(gain + axe) TIMBER")
        Sound.play("Frog", volume: 0.3)
        refreshHUD()
    }

    // MARK: Interaction

    private func updateInteraction() {
        let save = Game.shared.save
        facingHabitat = nil
        shoreTarget = nil
        action = .none
        guard talking == nil else { setPrompt(nil); return }

        if inBoat, let node = boatNode {
            let here = world.tile(at: node.position)
            facingHabitat = here.habitat ?? (here == .bridge ? .river : nil)
            facingPoint = node.position
            for d in [node.dir, .up, .down, .left, .right] {
                let v = dirVector(d)
                let p = CGPoint(x: node.position.x + v.dx * 34, y: node.position.y + v.dy * 30 - 8)
                let c = world.tileCoord(p)
                if world[c.0, c.1].walkable && world[c.0, c.1] != .bridge {
                    let target = world.center(c.0, c.1)
                    if canStand(CGPoint(x: target.x, y: target.y - 8)) { shoreTarget = (CGPoint(x: target.x, y: target.y - 8), d); break }
                }
            }
            var parts: [String] = []
            if let h = facingHabitat {
                action = .fish(h)
                parts.append("SPACE: FISH FROM BOAT")
                parts.append("BITES: \(FishSpecies.activityLabel(FishSpecies.activity(h, minutes: save.minutes, weather: save.weather, day: save.day, saltRod: save.hasSaltRod)).0)")
            }
            if shoreTarget != nil { parts.append("E: GO ASHORE") }
            if school(near: node.position, within: 90) != nil { parts.append("* FISH SCHOOL! *") }
            setPrompt(parts.isEmpty ? nil : parts.joined(separator: "    "))
            return
        }

        if driving, let node = carNode {
            let v = dirVector(node.dir)
            var parts = ["C: GET OUT"]
            for dist in [44.0, 64.0] as [CGFloat] {
                let p = CGPoint(x: node.position.x + v.dx * dist, y: node.position.y + 10 + v.dy * dist)
                if let h = world.tile(at: p).habitat {
                    facingHabitat = h
                    facingPoint = p
                    if let problem = save.towProblem { parts.append(problem) }
                    else if let b = save.boat { parts.append(b.waters.contains(h) ? "E: LAUNCH \(b.name.uppercased())" : "(\(b.name.uppercased()) CAN'T GO ON THE \(h.displayName.uppercased()))") }
                    break
                }
            }
            setPrompt(parts.joined(separator: "    "))
            return
        }

        let pp = player.position
        if let b = boatNode, moored, hypot(b.position.x - pp.x, b.position.y - pp.y) < 90 {
            setPrompt("E: BOARD YOUR MOORED BOAT")
            return
        }
        let doorNames: [BuildingKind: String] = [.tackle: "ENTER BAIT & TACKLE (FISHING)", .general: "ENTER HARDWARE (TOOLS)", .cottageA: "ENTER BOUTIQUE (CLOTHES)",
                                                 .cottageB: "ENTER MARKET (SEEDS & FOOD)", .cottageC: "ENTER HOME GOODS (FURNITURE)",
                                                 .boatShed: "BOAT SHED (CHOOSE BOAT TO TOW)", .autos: "ENTER AUTO SHOP (CARS & TRAILERS)", .villa: "KNOCK ON THE DOOR", .house: "ENTER HOME", .mine: "ENTER THE MINE", .shed: "USE WORKSHOP (WELDING)"]
        for b in world.buildings {
            guard hypot(b.door.x - pp.x, b.door.y - pp.y) < 56 else { continue }
            if !Game.shared.save.isBuilt(b.kind) {
                action = .door(b.kind)
                setPrompt("SPACE: BUILD \(Construction.name(b.kind)) (\(Construction.costLabel(b.kind)))")
                return
            }
            var label = doorNames[b.kind]
            if b.kind == .garage {
                let cars = Game.shared.save.carsOwned
                label = cars.count > 1 ? "GARAGE (SWITCH CAR)" : (cars.isEmpty ? "GARAGE (BUY CARS AT THE AUTO SHOP)" : "GARAGE")
            }
            guard let name = label else { continue }
            action = .door(b.kind)
            setPrompt("SPACE: \(name)")
            return
        }
        if hypot(world.boardSpot.x - pp.x, world.boardSpot.y - pp.y) < 50 {
            action = .board
            setPrompt("SPACE: TOWN BOARD (CONTESTS & HELP WANTED)")
            return
        }
        if let n = npcs.first(where: { hypot($0.position.x - pp.x, $0.position.y - pp.y) < 48 }) {
            action = .talk(n)
            setPrompt("SPACE: TALK TO \(n.villager.name.uppercased())" + (n.bubble.isHidden ? "" : "  (HAS A REQUEST!)"))
            return
        }

        let v = dirVector(playerDir)
        for dist in [20.0, 36.0] as [CGFloat] {
            let p = CGPoint(x: pp.x + v.dx * dist, y: pp.y + 6 + v.dy * dist)
            let (tx, ty) = world.tileCoord(p)
            switch world[tx, ty] {
            case .water(let h):
                facingHabitat = h
                facingPoint = p
                action = .fish(h)
                let act = FishSpecies.activity(h, minutes: save.minutes, weather: save.weather, day: save.day, saltRod: save.hasSaltRod)
                var parts = ["SPACE: FISH (\(h.displayName.uppercased()))", "BITES: \(FishSpecies.activityLabel(act).0)"]
                if let boat = save.boat, save.towProblem == nil, boat.waters.contains(h) { parts.append("(DRIVE HERE TO LAUNCH \(boat.name.uppercased()))") }
                if school(near: p, within: 100) != nil { parts.append("* SCHOOL! *") }
                setPrompt(parts.joined(separator: "    "))
                return
            case .tree(let k):
                let key = plotKey(tx, ty)
                guard treeSprites[key] != nil else { continue }
                action = .chop(key)
                let names: [TreeKind: String] = [.oak: "OAK", .pine: "PINE", .palm: "PALM", .dead: "DEAD TREE", .bush: "BUSH"]
                setPrompt("SPACE: CHOP \(names[k]!)  (-\(Tools.chopEnergy(Tools.level(.axe, save))) ENERGY)")
                return
            case .soil where dist == 20:
                let key = plotKey(tx, ty)
                action = .farm(key)
                setPrompt(farmPrompt(key))
                return
            default:
                continue
            }
        }
        setPrompt(nil)
    }

    private func startFishing(_ h: Habitat) {
        let save = Game.shared.save
        let charterOK = inBoat && save.boat?.charter == true && save.charter?.water == h
        if save.coolerFull && !charterOK { toast("COOLER FULL! SELL OR STORE YOUR FISH"); Sound.play("Funk", volume: 0.3); return }
        let origin = inBoat ? (boatNode?.position ?? facingPoint) : facingPoint
        let sch = school(near: origin, within: inBoat ? 90 : 100)
        sch?.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
        Sound.play("Pop")
        Game.shared.fishingReturn = nil
        Game.shared.showFishing(h, boat: inBoat ? save.boat : nil, school: sch != nil)
    }

    // MARK: Dialogue

    private func openDialog(_ n: NPCNode) {
        talking = n
        let dx = player.position.x - n.position.x, dy = player.position.y - n.position.y
        n.dir = abs(dx) > abs(dy) ? (dx < 0 ? .left : .right) : (dy < 0 ? .down : .up)
        n.texture = PlayerArt.texture(n.dir, frame: 0, outfit: n.villager.outfit)
        let s = Game.shared.save
        let v = n.villager
        let hearts = s.hearts(v.id)
        let status = s.spouse == v.id ? "  ·  YOUR SPOUSE" : (s.engaged == v.id ? "  ·  ENGAGED!" : "")
        dialogName.text = v.name.uppercased() + "  ·  HEARTS \(hearts)/10" + status
        var extra = "   G: GIFT" + (s.giftedDay[v.id] == s.day ? " (DONE TODAY)" : "")
        if v.female && s.spouse == nil && s.engaged == nil {
            extra += hearts >= Romance.proposeHearts ? (s.count(Romance.pendant) > 0 ? "   P: PROPOSE!" : "   (BUY A PROMISE PENDANT AT THE BOUTIQUE)") : ""
        }
        if let r = s.requests.first(where: { $0.npc == n.villager.id }) {
            let have = r.isFish ? s.fishCount(r.item) : s.count(r.item)
            dialogText.text = PixelFont.wrap("COULD YOU BRING ME \(r.qty) \(r.itemName.uppercased()) BY \(GameCalendar.label(r.due))? I'LL PAY \(r.reward)G - WAY MORE THAN THE STORE!", maxWidth: 500)
            dialogHint.text = (have >= r.qty ? "SPACE: GIVE \(r.qty) \(r.itemName.uppercased()) (+\(r.reward)G)" : "YOU HAVE \(have)/\(r.qty)") + extra + "   ESC: CLOSE"
        } else {
            var line = v.lines.randomElement()!.uppercased()
            if s.spouse == v.id {
                line = ["HI HONEY! WORK AT THE \(v.job.uppercased()) WAS BUSY TODAY.", "DON'T FORGET TO KEEP THE FRIDGE STOCKED!",
                        "THE KIDS LOVE YOUR FISH STORIES.", "I'M SO HAPPY WE GOT MARRIED."].randomElement()!.uppercased()
            } else if hearts >= 6 && v.female {
                line = ["I ALWAYS LOOK FORWARD TO SEEING YOU.", "YOU'RE SWEET, YOU KNOW THAT?", "WANT TO WATCH THE SUNSET SOMETIME?"].randomElement()!
            }
            dialogText.text = PixelFont.wrap(line, maxWidth: 500)
            dialogHint.text = "SPACE: CLOSE" + extra
        }
        dialog.isHidden = false
        Sound.play("Tink", volume: 0.3)
    }

    private func propose(_ n: NPCNode) {
        let game = Game.shared
        let v = n.villager
        guard v.female, game.save.spouse == nil, game.save.engaged == nil else { return }
        guard game.save.hearts(v.id) >= Romance.proposeHearts else { toast("YOU NEED \(Romance.proposeHearts) HEARTS TO PROPOSE"); return }
        guard game.save.take(Romance.pendant) else { toast("YOU NEED A PROMISE PENDANT (BOUTIQUE)"); return }
        game.save.engaged = v.id
        game.save.weddingDay = game.save.day + 1
        game.save.persist()
        closeDialog()
        Sound.play("Hero", volume: 0.5)
        toast("\(v.name.uppercased()): YES! YES!\nTHE WEDDING IS TOMORROW MORNING!")
    }

    /// Full-screen labelled map.
    private func toggleBigMap() {
        guard bigMap.isHidden, let tex = mapTexture else { bigMap.isHidden = true; return }
        bigMap.removeAllChildren()
        bigMap.addChild(panelSprite(1240, 780, scale: 4, style: .dark))
        let mw: CGFloat = 960, mh: CGFloat = 960 * WorldMap.size.height / WorldMap.size.width
        let k = mw / WorldMap.size.width
        let map = SKSpriteNode(texture: tex, size: CGSize(width: mw, height: mh))
        map.position = CGPoint(x: -100, y: 0)
        bigMap.addChild(map)
        func pt(_ p: CGPoint) -> CGPoint { CGPoint(x: -100 - mw / 2 + p.x * k, y: -mh / 2 + p.y * k) }
        func label(_ text: String, _ p: CGPoint, _ color: PColor, dy: CGFloat = 14, dx: CGFloat = 0) {
            let dot = SKSpriteNode(color: color.ns, size: CGSize(width: 8, height: 8))
            dot.position = pt(p)
            bigMap.addChild(dot)
            let l = PixelLabel(text, scale: 2, color: color, shadow: PColor(0x000000, 220))
            l.position = CGPoint(x: dot.position.x + dx, y: dot.position.y + dy)
            bigMap.addChild(l)
        }
        for s in world.signs { label(s.habitat.spotName.uppercased(), world.center(s.waterTile.0, s.waterTile.1), PColor(0x8AE8FF)) }
        let names: [BuildingKind: String] = [.house: "HOME", .mine: "MINE", .boatShed: "BOAT SHED", .shed: "WORKSHOP"]
        let offsets: [BuildingKind: (CGFloat, CGFloat)] = [.house: (0, 22), .boatShed: (-52, 0), .shed: (54, 0), .mine: (0, 14)]
        for b in world.buildings {
            if let n = names[b.kind] { label(n, b.door, b.kind == .house ? PColor(0x8AFF8A) : .gold, dy: offsets[b.kind]?.1 ?? 14, dx: offsets[b.kind]?.0 ?? 0) }
        }
        let r = world.plazaRect
        let town = PixelLabel("TOWN", scale: 4, color: .gold, shadow: PColor(0x000000, 220))
        town.position = pt(world.center(r.x + r.w / 2, r.y + r.h + 3))
        bigMap.addChild(town)
        for (name, p) in world.zones { label(name, p, PColor(0xFF9AE8)) }
        label("FARM", world.center(world.farmRect.x + world.farmRect.w / 2, world.farmRect.y + world.farmRect.h / 2), PColor(0x8AFF8A))
        // Store legend on the side
        let stores: [(BuildingKind, String)] = [(.tackle, "BAIT & TACKLE"), (.cottageA, "BOUTIQUE"), (.cottageB, "MARKET"), (.general, "HARDWARE"),
                                                (.cottageC, "HOME GOODS"), (.autos, "AUTO SHOP")]
        let legend = PixelLabel("TOWN STORES", scale: 2, color: .gold)
        legend.position = CGPoint(x: 500, y: 300)
        bigMap.addChild(legend)
        for (i, (kind, name)) in stores.enumerated() {
            let b = world.building(kind)
            let dot = SKSpriteNode(color: PColor(0xFFD23A).ns, size: CGSize(width: 6, height: 6))
            dot.position = pt(b.door)
            bigMap.addChild(dot)
            let n = PixelLabel("\(i + 1)", scale: 2, color: .white, shadow: PColor(0x000000, 220))
            n.position = CGPoint(x: dot.position.x, y: dot.position.y + 10)
            bigMap.addChild(n)
            let l = PixelLabel("\(i + 1) \(name)", scale: 2, align: .left)
            l.position = CGPoint(x: 410, y: 266 - CGFloat(i) * 26)
            bigMap.addChild(l)
        }
        let focus = inBoat ? (boatNode?.position ?? player.position) : (driving ? (carNode?.position ?? player.position) : player.position)
        bigMapDot = SKSpriteNode(color: PColor(0xFF3B3B).ns, size: CGSize(width: 12, height: 12))
        bigMapDot.position = pt(focus)
        bigMapDot.run(.repeatForever(.sequence([.fadeAlpha(to: 0.2, duration: 0.3), .fadeAlpha(to: 1, duration: 0.3)])))
        bigMap.addChild(bigMapDot)
        let you = PixelLabel("YOU", scale: 2, color: PColor(0xFF6A6A), shadow: PColor(0x000000, 220))
        you.position = CGPoint(x: bigMapDot.position.x, y: bigMapDot.position.y - 18)
        bigMap.addChild(you)
        let help = PixelLabel("M / ESC: CLOSE MAP", scale: 2)
        help.position = CGPoint(x: 500, y: -340)
        bigMap.addChild(help)
        bigMap.isHidden = false
        Sound.play("Tink", volume: 0.3)
    }

    private func closeDialog() {
        talking = nil
        dialog.isHidden = true
    }

    private func dialogSpace() {
        guard let n = talking else { return }
        let game = Game.shared
        if let i = game.save.requests.firstIndex(where: { $0.npc == n.villager.id }) {
            let r = game.save.requests[i]
            let ok = r.isFish ? game.save.takeFish(r.item, r.qty) : game.save.take(r.item, r.qty)
            if ok {
                game.save.coins += r.reward
                game.save.friendship[r.npc, default: 0] += 1
                game.save.requests.remove(at: i)
                game.save.persist()
                Sound.play("Hero", volume: 0.4)
                closeDialog()
                toast("\(n.villager.name.uppercased()): THANK YOU!\n+\(r.reward)G")
                refreshHUD()
                return
            }
        }
        closeDialog()
    }

    // MARK: Atmosphere

    private func updateAtmosphere(_ dt: Double) {
        let save = Game.shared.save
        let (c, a) = Clock.lighting(save.minutes, weather: save.weather)
        darkness.color = c.ns
        darkness.alpha = CGFloat(a)
        let night = CGFloat(max(0, min(1, (a - 0.12) / 0.43)))
        for (g, k) in glows { g.alpha = night * k }
        lantern.alpha = night * 0.3
        if shownWeather != save.weather { buildWeather(save.weather) }
        if shownSeason != save.season { applySeason(save.season) }
        let t = CGFloat(dt)
        let snowing = save.weather == .snow
        for d in drops {
            d.position.x -= (snowing ? 40 + sin(CGFloat(clock) * 2 + d.position.y * 0.02) * 30 : (save.weather == .storm ? 320 : 180)) * t
            d.position.y -= (snowing ? 110 : (save.weather == .storm ? 1100 : 800)) * t
            if d.position.y < -420 { d.position.y += 860; d.position.x = CGFloat.random(in: -660...760) }
        }
        if save.weather == .storm {
            lightningTimer -= dt
            if lightningTimer <= 0 {
                lightningTimer = Double.random(in: 6...14)
                flash.removeAllActions()
                flash.run(.sequence([.fadeAlpha(to: 0.7, duration: 0.05), .fadeAlpha(to: 0.1, duration: 0.1),
                                     .fadeAlpha(to: 0.5, duration: 0.05), .fadeOut(withDuration: 0.4)]))
                run(.sequence([.wait(forDuration: 0.6), .run { Sound.play("Submarine", volume: 0.25) }]))
            }
        }
    }

    private func applySeason(_ season: Season) {
        shownSeason = season
        bgSprite.color = PColor(0xE8B070).ns
        bgSprite.colorBlendFactor = season == .fall ? 0.18 : 0
        frost.alpha = season == .winter ? 0.32 : 0
        for (s, t) in treeSprites.values {
            switch (season, t.kind) {
            case (.fall, .oak), (.fall, .bush):
                s.color = [PColor(0xE8823A), PColor(0xD8A83A), PColor(0xC8482A)][abs(t.x + t.y) % 3].ns
                s.colorBlendFactor = 0.55
            case (.winter, .oak), (.winter, .bush), (.winter, .pine):
                s.color = PColor(0xB8C8D8).ns
                s.colorBlendFactor = t.kind == .pine ? 0.35 : 0.6
            default:
                s.colorBlendFactor = 0
            }
        }
    }

    private func buildWeather(_ w: Weather) {
        shownWeather = w
        weatherLayer.removeAllChildren()
        drops.removeAll()
        switch w {
        case .rain, .storm:
            for _ in 0..<(w == .storm ? 170 : 100) {
                let d = SKSpriteNode(color: PColor(0xA8C8F0, 170).ns, size: CGSize(width: 3, height: 15))
                d.zRotation = 0.25
                d.position = CGPoint(x: CGFloat.random(in: -660...760), y: CGFloat.random(in: -420...440))
                weatherLayer.addChild(d)
                drops.append(d)
            }
        case .snow:
            for _ in 0..<140 {
                let d = SKSpriteNode(color: PColor(0xFFFFFF, 230).ns, size: CGSize(width: 6, height: 6))
                d.position = CGPoint(x: CGFloat.random(in: -660...760), y: CGFloat.random(in: -420...440))
                weatherLayer.addChild(d)
                drops.append(d)
            }
        case .fog:
            let veil = SKSpriteNode(color: PColor(0xDDE2E8).ns, size: CGSize(width: 1400, height: 900))
            veil.alpha = 0.3
            weatherLayer.addChild(veil)
            for i in 0..<6 {
                let f = SKSpriteNode(texture: Tex.glow())
                f.size = CGSize(width: 700, height: 360)
                f.alpha = 0.35
                f.position = CGPoint(x: CGFloat(i) * 300 - 750, y: CGFloat.random(in: -300...300))
                weatherLayer.addChild(f)
                f.run(.repeatForever(.sequence([.moveBy(x: 260, y: 0, duration: 14), .moveBy(x: -260, y: 0, duration: 14)])))
            }
        case .cloudy:
            for i in 0..<4 {
                let s = SKSpriteNode(texture: Tex.glow())
                s.size = CGSize(width: 800, height: 420)
                s.color = .black
                s.colorBlendFactor = 1
                s.alpha = 0.16
                s.position = CGPoint(x: CGFloat(i) * 500 - 900, y: CGFloat.random(in: -250...250))
                weatherLayer.addChild(s)
                s.run(.repeatForever(.sequence([.moveBy(x: 1800, y: 0, duration: 60), .moveBy(x: -1800, y: 0, duration: 0)])))
            }
        case .sunny:
            break
        }
    }

    // MARK: - Input

    override func keyPressed(_ key: UInt16) {
        if !bigMap.isHidden {
            if key == Key.m || key == Key.esc || key == Key.space { bigMap.isHidden = true }
            return
        }
        if let n = talking {
            if key == Key.space || key == Key.ret || key == Key.enter { dialogSpace() }
            if key == Key.esc { closeDialog() }
            if key == Key.g {
                if Game.shared.save.giftedDay[n.villager.id] == Game.shared.save.day { toast("YOU ALREADY GAVE A GIFT TODAY"); return }
                closeDialog()
                Game.shared.presentScene(GiftScene(npc: n.villager.id))
            }
            if key == Key.p { propose(n) }
            return
        }
        switch key {
        case Key.space, Key.ret, Key.enter:
            switch action {
            case .fish(let h):
                if driving { return }
                guard Game.shared.save.energy >= Energy.cast else { tired(); return }
                startFishing(h)
            case .chop(let k): chop(k)
            case .farm(let k): doFarm(k)
            case .door(let b):
                if !Game.shared.save.isBuilt(b) { construct(b); return }
                Sound.play("Pop")
                switch b {
                case .garage: switchCar()
                case .tackle: Game.shared.showShop(.tackle)
                case .general: Game.shared.showShop(.hardware)
                case .cottageA: Game.shared.showShop(.boutique)
                case .cottageB: Game.shared.showShop(.market)
                case .cottageC: Game.shared.showShop(.homeGoods)
                case .boatShed: Game.shared.presentScene(BoatShedScene(size: Game.sceneSize))
                case .autos: Game.shared.showShop(.autos)
                case .villa: toast(["NOBODY'S HOME.", "YOU HEAR A RADIO PLAYING INSIDE.", "A CAT MEOWS FROM THE WINDOW.", "SMELLS LIKE FRESH BREAD!"].randomElement()!)
                case .house: Game.shared.showHouse()
                case .mine: Game.shared.enterMine()
                case .shed:
                    if Game.shared.save.hasWelder { Game.shared.showCraft(.welder) }
                    else { toast("AN EMPTY WORKSHOP SHED.\nBUY A WELDING MACHINE AT HARDWARE!") }
                default: break
                }
            case .board: Sound.play("Pop"); Game.shared.showBoard()
            case .talk(let n): openDialog(n)
            case .none: break
            }
        case Key.e:
            if inBoat { goAshore() }
            else if let b = boatNode, moored, !driving, hypot(b.position.x - player.position.x, b.position.y - player.position.y) < 90 {
                inBoat = true
                moored = false
                player.isHidden = true
                boatVel = .zero
                Sound.play("Bottle", volume: 0.35)
            }
            else if facingHabitat != nil { launchBoat() }
        case Key.c:
            if !inBoat { toggleCar() }
        case Key.q:
            let s = Game.shared.save.ownedSeeds
            if s.isEmpty { toast("NO SEEDS - BUY SOME AT THE MARKET") } else { Game.shared.save.seedIdx = (Game.shared.save.seedIdx + 1) % s.count }
            Sound.play("Tink", volume: 0.25)
            refreshHUD()
        case Key.i: Game.shared.showInventory()
        case Key.j: Game.shared.showJournal()
        case Key.g: Game.shared.showGear(.lure)
        case Key.m: toggleBigMap()
        case Key.esc: Game.shared.showTitle()
        default: break
        }
    }

    // MARK: - Placement helpers

    func placeAt(_ door: CGPoint) { debugWalk(to: CGPoint(x: door.x, y: door.y - 24), facing: .down) }
    func placeAtHome() { placeAt(world.houseDoor) }

    func debugWalk(to p: CGPoint, facing d: Dir) {
        inBoat = false
        boatNode?.removeFromParent()
        boatNode = nil
        player.isHidden = false
        player.position = p
        playerDir = d
        updateCamera()
    }

    /// Snapshot helper: fill the water around the boat with schools.
    func debugSchoolsNearBoat() {
        guard let b = boatNode?.position else { return }
        let near = schoolSpots.filter { hypot(world.center($0.0, $0.1).x - b.x, world.center($0.0, $0.1).y - b.y) < finderRange * 0.9 }.shuffled().prefix(5)
        for c in near {
            let s = SKSpriteNode()
            s.setPixelTexture(PropArt.school(frame: 0), scale: 2)
            s.position = world.center(c.0, c.1)
            s.zPosition = 3
            addChild(s)
            schools.append(s)
        }
        schoolTimer = 999
    }

    func debugBoard(_ h: Habitat) {
        guard let boat = Game.shared.save.boat else { return }
        for (x, y) in schoolSpots where world[x, y] == .water(h) {
            let p = world.center(x, y)
            guard boatFits(p, boat) else { continue }
            inBoat = true
            player.isHidden = true
            boatNode?.removeFromParent()
            boatNode = makeBoat(boat, at: p)
            boatNode?.setDir(.right, force: true)
            updateCamera()
            return
        }
    }
}
