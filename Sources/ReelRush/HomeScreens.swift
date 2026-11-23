import SpriteKit

// MARK: - House interior (walkable)

final class HouseScene: BaseScene {
    private struct Furniture {
        let name: String
        let rect: CGRect      // collision (pixels)
        let action: String?
    }

    private let P: CGFloat = 4
    private var built = false
    private var lastTime: TimeInterval = 0
    private let player = SKSpriteNode()
    private var pos = CGPoint(x: 160, y: 14)
    private var dir: Dir = .up
    private var walk = 0.0
    private var furniture: [Furniture] = []
    private let prompt = PixelLabel("", scale: 3)
    private var promptBG = SKSpriteNode()
    private let toast = PixelLabel("", scale: 4, color: .gold)
    private var target: Furniture?
    private var askingBaby = false
    private let question = SKNode()
    private var spouseSpot: CGPoint?
    private let darkness = SKSpriteNode(color: .black, size: CGSize(width: 1280, height: 800))
    private let fade = SKSpriteNode(color: .black, size: CGSize(width: 1280, height: 800))
    private let windowSprite = SKSpriteNode()

    override func sceneDidAppear() {
        lastTime = 0
        player.setPixelTexture(PlayerArt.texture(dir, frame: 0), scale: P)
        guard !built else { return }
        built = true
        let bg = pixelSprite(Tex.get("room") { PropArt.room() }, scale: P)
        bg.anchorPoint = .zero
        addChild(bg)

        func place(_ name: String, _ x: CGFloat, _ y: CGFloat, z: CGFloat = 2) -> SKSpriteNode {
            let s = pixelSprite(PropArt.furniture(name), scale: P)
            s.anchorPoint = .zero
            s.position = CGPoint(x: x * P, y: y * P)
            s.zPosition = z
            addChild(s)
            return s
        }
        windowSprite.setPixelTexture(PropArt.furniture("window"), scale: P)
        windowSprite.anchorPoint = .zero
        windowSprite.position = CGPoint(x: 22 * P, y: 152 * P)
        windowSprite.zPosition = 1
        addChild(windowSprite)
        _ = place("window", 276, 152, z: 1)
        _ = place("bed", 16, 96)
        _ = place("wardrobe", 74, 108)
        _ = place("plant", 108, 116)
        _ = place("table", 142, 54)
        _ = place("shelf", 200, 160, z: 1)
        _ = place("shelf", 200, 176, z: 1)
        let fire = place("fire", 148, 146, z: 1)
        fire.run(.repeatForever(.sequence([.fadeAlpha(to: 0.75, duration: 0.25), .fadeAlpha(to: 1, duration: 0.3)])))
        let glow = SKSpriteNode(texture: Tex.glow())
        glow.size = CGSize(width: 520, height: 520)
        glow.position = CGPoint(x: 160 * P, y: 150 * P)
        glow.blendMode = .add
        glow.color = PColor(0xFF9040).ns
        glow.colorBlendFactor = 1
        glow.alpha = 0.25
        glow.zPosition = 30
        addChild(glow)

        let save = Game.shared.save
        for (i, t) in save.trophies.prefix(8).enumerated() {
            let tr = pixelSprite(ItemArt.trophy(t.count + i), scale: P)
            tr.anchorPoint = CGPoint(x: 0.5, y: 0)
            tr.position = CGPoint(x: (208 + CGFloat(i % 4) * 15) * P, y: (i < 4 ? 166 : 182) * P)
            tr.zPosition = 2
            addChild(tr)
        }
        for i in 0..<save.chests {
            let c = pixelSprite(PropArt.chest(), scale: P)
            c.anchorPoint = .zero
            let cx: CGFloat = 296, cy = CGFloat(18 + i * 19)
            c.position = CGPoint(x: cx * P, y: cy * P)
            c.zPosition = 3
            addChild(c)
            furniture.append(Furniture(name: "chest", rect: CGRect(x: cx, y: cy, width: 16, height: 12), action: "SPACE: OPEN CHESTS"))
        }
        let stoveSprite = place("stove", 20, 40, z: 3)
        stoveSprite.setPixelTexture(PropArt.stove(lit: save.stoveLit), scale: P)
        furniture.append(Furniture(name: "stove", rect: CGRect(x: 20, y: 40, width: 30, height: 26),
                                   action: save.stoveLit ? "SPACE: COOK AT THE STOVE" : "SPACE: LIGHT THE STOVE"))
        if save.hasFridge {
            let f = place("stove", 58, 36, z: 3); f.setPixelTexture(PropArt.fridge(), scale: P)
            furniture.append(Furniture(name: "fridge", rect: CGRect(x: 58, y: 36, width: 22, height: 12), action: "SPACE: OPEN FRIDGE"))
        }
        if save.hasFreezer {
            let f = place("stove", 84, 36, z: 3); f.setPixelTexture(PropArt.freezer(), scale: P)
            furniture.append(Furniture(name: "freezer", rect: CGRect(x: 84, y: 36, width: 28, height: 12), action: "SPACE: OPEN FREEZER"))
        }
        for d in Decor.all where save.owned.contains(d.id) {
            let sp = place("stove", d.x, d.y, z: d.collide == nil ? 2.5 : 3)
            sp.setPixelTexture(PropArt.decor(d.id), scale: P)
            if d.id == "decor.tank" {
                let best = save.records.sorted { $0.value.best > $1.value.best }.prefix(3)
                for (i, r) in best.enumerated() {
                    guard let sp2 = FishSpecies.byID[r.key] else { continue }
                    let f = pixelSprite(FishPixel.texture(sp2, length: 10), scale: P)
                    f.position = CGPoint(x: (d.x + 10 + CGFloat(i) * 10) * P, y: (d.y + 14 + CGFloat(i % 2) * 6) * P)
                    f.zPosition = 3.1
                    addChild(f)
                    f.run(.repeatForever(.sequence([.moveBy(x: 16, y: 0, duration: 1.2 + Double(i) * 0.3), .moveBy(x: -16, y: 0, duration: 1.2 + Double(i) * 0.3)])))
                }
            }
            if let c = d.collide {
                let action = d.id == "decor.tank" ? "FISH TANK: YOUR BIGGEST CATCHES" : (d.id == "decor.bookshelf" ? "SPACE: READ FISHING BOOKS" : nil)
                furniture.append(Furniture(name: d.id, rect: c, action: action))
            }
        }
        furniture += [
            Furniture(name: "bed", rect: CGRect(x: 16, y: 96, width: 46, height: 44), action: "SPACE: SLEEP UNTIL MORNING"),
            Furniture(name: "wardrobe", rect: CGRect(x: 74, y: 108, width: 30, height: 32), action: "SPACE: WARDROBE"),
            Furniture(name: "plant", rect: CGRect(x: 108, y: 116, width: 16, height: 10), action: nil),
            Furniture(name: "table", rect: CGRect(x: 142, y: 54, width: 36, height: 14), action: nil),
            Furniture(name: "shelf", rect: CGRect(x: 200, y: 134, width: 40, height: 6), action: "TROPHIES: \(save.trophies.count)"),
            Furniture(name: "fire", rect: CGRect(x: 132, y: 128, width: 56, height: 12), action: nil),
        ]

        player.anchorPoint = CGPoint(x: 0.5, y: 0)
        player.setPixelTexture(PlayerArt.texture(dir, frame: 0), scale: P)
        addChild(player)

        darkness.anchorPoint = .zero
        darkness.zPosition = 25
        addChild(darkness)

        let panelY: CGFloat = 60
        prompt.position = CGPoint(x: 640, y: panelY)
        prompt.zPosition = 51
        addChild(prompt)
        toast.position = CGPoint(x: 640, y: 420)
        toast.zPosition = 60
        toast.alpha = 0
        addChild(toast)
        // Spouse is home in the mornings and evenings (works in town during the day)
        let hour = Clock.hour(save.minutes)
        if let v = save.spouseVillager, hour < 8 || hour >= 18 {
            let sp = pixelSprite(PlayerArt.texture(.down, frame: 0, outfit: v.outfit), scale: P)
            sp.anchorPoint = CGPoint(x: 0.5, y: 0)
            sp.position = CGPoint(x: 130 * P, y: 30 * P)
            sp.zPosition = 9
            addChild(sp)
            spouseSpot = CGPoint(x: 130, y: 30)
            furniture.append(Furniture(name: "spouse", rect: CGRect(x: 124, y: 30, width: 12, height: 6), action: "SPACE: TALK TO \(v.name.uppercased())"))
        }
        // Door to the kids' room after a house expansion
        if save.houseLevel > 0 {
            let door = SKSpriteNode(color: PColor(0x3A2010).ns, size: CGSize(width: 6 * P, height: 26 * P))
            door.anchorPoint = .zero
            door.position = CGPoint(x: 0, y: 70 * P)
            door.zPosition = 1
            addChild(door)
            let sign = PixelLabel("KIDS", scale: 2, color: .gold)
            sign.position = CGPoint(x: 14 * P, y: 100 * P)
            sign.zPosition = 51
            addChild(sign)
        }
        question.zPosition = 120
        question.isHidden = true
        addChild(question)

        let help = PixelLabel("ARROWS: MOVE   SPACE: USE   ESC / DOORMAT: GO OUTSIDE", scale: 2)
        help.position = CGPoint(x: 640, y: 786)
        help.zPosition = 51
        addChild(help)
        fade.anchorPoint = .zero
        fade.alpha = 0
        fade.zPosition = 100
        addChild(fade)
        updateLighting()
    }

    private func updateLighting() {
        let s = Game.shared.save
        let (c, a) = Clock.lighting(s.minutes, weather: s.weather)
        darkness.color = c.ns
        darkness.alpha = CGFloat(a) * 0.45
        let ph = Clock.phase(s.minutes)
        windowSprite.color = (ph == .night ? PColor(0x1A2450) : (ph == .day ? PColor(0xFFFFFF) : PColor(0xF2A07A))).ns
        windowSprite.colorBlendFactor = ph == .day ? 0 : 0.8
    }

    private func blocked(_ p: CGPoint) -> Bool {
        let box = CGRect(x: p.x - 5, y: p.y, width: 10, height: 4)
        if box.minX < 4 || box.maxX > 316 || box.minY < 1 || box.maxY > 138 { return true }
        return furniture.contains { $0.rect.intersects(box) }
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = lastTime == 0 ? 0 : min(1.0 / 30, currentTime - lastTime)
        lastTime = currentTime
        var ix: CGFloat = 0, iy: CGFloat = 0
        if isDown(Key.left, Key.a) { ix -= 1 }
        if isDown(Key.right, Key.d) { ix += 1 }
        if isDown(Key.up, Key.w) { iy += 1 }
        if isDown(Key.down, Key.s) { iy -= 1 }
        let moving = ix != 0 || iy != 0
        if moving && fade.alpha == 0 {
            let len = sqrt(ix * ix + iy * iy), step = 62 * CGFloat(dt)
            let nx = CGPoint(x: pos.x + ix / len * step, y: pos.y)
            if !blocked(nx) { pos = nx }
            let ny = CGPoint(x: pos.x, y: pos.y + iy / len * step)
            if !blocked(ny) { pos = ny }
            if ix != 0 && iy == 0 { dir = ix < 0 ? .left : .right } else if iy != 0 { dir = iy < 0 ? .down : .up }
            walk += dt * 8
            if pos.y < 6 && abs(pos.x - 160) < 16 && iy < 0 { leave(); return }
            if Game.shared.save.houseLevel > 0 && pos.x < 8 && pos.y > 66 && pos.y < 96 && ix < 0 { Game.shared.presentScene(KidsRoomScene(size: Game.sceneSize)); return }
        }
        player.texture = PlayerArt.texture(dir, frame: moving ? [1, 0, 2, 0][Int(walk) % 4] : 0)
        player.position = CGPoint(x: snap(pos.x * P, P), y: snap(pos.y * P, P))
        player.zPosition = 10

        // Interaction target: nearest furniture within reach of the player's feet.
        let reach = CGRect(x: pos.x - 14, y: pos.y - 8, width: 28, height: 24)
        target = furniture.first { $0.action != nil && $0.rect.insetBy(dx: -2, dy: -2).intersects(reach) }
        let text = target?.action ?? ""
        if text != prompt.text {
            prompt.text = text
            promptBG.removeFromParent()
            if !text.isEmpty {
                promptBG = panelSprite(prompt.size.width + 44, 56, style: .dark)
                promptBG.position = prompt.position
                promptBG.zPosition = 50
                addChild(promptBG)
            }
        }
    }

    private func say(_ t: String) {
        toast.text = t
        toast.removeAllActions()
        toast.alpha = 1
        toast.run(.sequence([.wait(forDuration: 2 + Double(t.count) / 40), .fadeOut(withDuration: 0.5)]))
    }

    private func leave() {
        Game.shared.mapScene.placeAtHome()
        Game.shared.showMap()
    }

    private func use() {
        guard let t = target else { return }
        switch t.name {
        case "bed":
            if Game.shared.save.comp != nil { say("NO NAPS DURING A CONTEST!"); return }
            let s = Game.shared.save
            if s.spouse != nil && s.babyDue == 0 && s.day - s.marriedDay >= 3 && s.day - s.lastBabyAsk >= 4 {
                if s.kids.count < s.kidBeds {
                    askBaby()
                    return
                } else if s.day - s.lastBabyAsk >= 7 {
                    Game.shared.save.lastBabyAsk = s.day
                    Game.shared.save.news.append("\(s.spouseVillager!.name.uppercased()) WISHES YOU HAD ROOM FOR A CHILD. EXPAND THE HOUSE AT HOME GOODS.")
                }
            }
            sleep()
        case "spouse":
            let s = Game.shared.save
            guard let v = s.spouseVillager else { return }
            let fridgeFood = s.fridgeItems.filter { [GoodCat.dish, .food, .produce].contains(Good.byID[$0.key]?.cat ?? .seed) }.values.reduce(0, +)
            let need = 1 + s.kids.count
            say("\(v.name.uppercased()): " + (fridgeFood < need * 2 ? "WE'RE LOW ON FOOD! WE NEED \(need) MEALS A DAY. STOCK THE FRIDGE PLEASE." : "WELCOME HOME, HONEY! THE FRIDGE IS NICELY STOCKED."))
        case "decor.bookshelf":
            Game.shared.presentScene(BookScene(size: Game.sceneSize))
        case "_sleep_":
            Sound.play("Purr", volume: 0.3)
            fade.run(.sequence([
                .fadeIn(withDuration: 0.8),
                .run { [weak self] in
                    Game.shared.save.sleep()
                    Game.shared.save.persist()
                    self?.updateLighting()
                    let s = Game.shared.save
                    var msg = "GOOD MORNING!\n\(GameCalendar.label(s.day)) · \(s.weather.name.uppercased())"
                    if let c = Competition.on(day: s.day) { msg += "\nTODAY: \(c.name.uppercased())!" }
                    if s.spoiledToday > 0 { msg += "\n\(s.spoiledToday) PRODUCE SPOILED - USE A FRIDGE!" }
                    self?.say(msg)
                },
                .wait(forDuration: 0.6),
                .fadeOut(withDuration: 0.8),
            ]))
        case "wardrobe":
            Game.shared.showGear(.hat, fromHouse: true)
        case "welder":
            Game.shared.showCraft(.welder)
        case "stove":
            let game = Game.shared
            if game.save.stoveLit { game.showCraft(.stove); return }
            if !game.save.hasStriker {
                guard game.save.count("flint") >= 1 && game.save.count("iron") >= 1 else {
                    say("TO LIGHT THE STOVE YOU NEED FLINT & STEEL.\nMINE 1 FLINT + 1 IRON ORE TO MAKE ONE.")
                    return
                }
                game.save.take("flint"); game.save.take("iron")
                game.save.hasStriker = true
                game.save.add("tool.striker")
            }
            guard game.save.take("timber") else { say("YOU HAVE FLINT & STEEL!\nNOW BRING 1 TIMBER TO START THE FIRE.") ; return }
            game.save.stoveLit = true
            game.save.persist()
            Sound.play("Hero", volume: 0.35)
            say("THE STOVE IS LIT! COOK FISH WITH TIMBER.")
            Game.shared.showHouse()
        case "chest":
            Game.shared.showStorage(.chest)
        case "fridge":
            Game.shared.showStorage(.fridge)
        case "freezer":
            Game.shared.showStorage(.freezer)
        case "shelf":
            let s = Game.shared.save
            say(s.trophies.isEmpty ? "NO TROPHIES YET.\nWIN A CONTEST!" : "\(s.trophies.count) TROPHIES:\n" + s.trophies.suffix(3).joined(separator: "\n").uppercased())
        default: break
        }
    }

    private func askBaby() {
        guard let v = Game.shared.save.spouseVillager else { return }
        askingBaby = true
        question.removeAllChildren()
        question.addChild(panelSprite(900, 200, scale: 3, style: .dark))
        question.position = CGPoint(x: 640, y: 420)
        let q = PixelLabel("\(v.name.uppercased()): HONEY... SHOULD WE HAVE A BABY?", scale: 3, color: .gold)
        q.position = CGPoint(x: 0, y: 40)
        question.addChild(q)
        let note = PixelLabel("EVERY KID NEEDS A BED AND A MEAL EACH DAY. TEENS GET JOBS!", scale: 2)
        note.position = CGPoint(x: 0, y: 0)
        question.addChild(note)
        let opts = PixelLabel("Y: YES!        N: NOT NOW", scale: 3, color: PColor(0x8AE8FF))
        opts.position = CGPoint(x: 0, y: -50)
        question.addChild(opts)
        question.isHidden = false
    }

    private func answerBaby(_ yes: Bool) {
        askingBaby = false
        question.isHidden = true
        let game = Game.shared
        game.save.lastBabyAsk = game.save.day
        if yes {
            game.save.babyDue = game.save.day + 1
            Sound.play("Hero", volume: 0.4)
        }
        sleep()
    }

    private func sleep() {
        Sound.play("Purr", volume: 0.3)
        fade.run(.sequence([
            .fadeIn(withDuration: 0.8),
            .run { [weak self] in
                Game.shared.save.sleep()
                Game.shared.save.persist()
                self?.updateLighting()
                let s = Game.shared.save
                var msg = "GOOD MORNING!\n\(GameCalendar.label(s.day)) · \(s.weather.name.uppercased())"
                if let c = Competition.on(day: s.day) { msg += "\nTODAY: \(c.name.uppercased())!" }
                if s.spoiledToday > 0 { msg += "\n\(s.spoiledToday) PRODUCE SPOILED - USE A FRIDGE!" }
                for n in s.news { msg += "\n" + PixelFont.wrap(n, maxWidth: 260) }
                Game.shared.save.news = []
                self?.say(msg)
            },
            .wait(forDuration: 0.6),
            .fadeOut(withDuration: 0.8),
        ]))
    }

    override func keyPressed(_ key: UInt16) {
        if askingBaby {
            if key == Key.y { answerBaby(true) }
            if key == Key.n || key == Key.esc { answerBaby(false) }
            return
        }
        switch key {
        case Key.space, Key.ret, Key.enter: use()
        case Key.esc: leave()
        default: break
        }
    }
}

// MARK: - Storage (chests, fridge, freezer)

enum StorageKind { case chest, fridge, freezer }

final class StorageScene: BaseScene {
    private struct Entry {
        let isFish: Bool
        let id: String
        let name: String
        let count: Int
        let worth: Int
        let fresh: Double?
        let icon: SKTexture
        let color: PColor
    }

    let kind: StorageKind
    private var column = 0
    private var row = [0, 0]
    private let content = SKNode()
    private let feedback = inkLabel("", scale: 3)
    private var built = false

    init(kind: StorageKind) {
        self.kind = kind
        super.init(size: Game.sceneSize)
    }

    required init?(coder: NSCoder) { fatalError() }

    private var title: String {
        switch kind {
        case .chest: return "STORAGE CHESTS"
        case .fridge: return "FRIDGE"
        case .freezer: return "FREEZER"
        }
    }

    override func sceneDidAppear() {
        guard !built else { return }
        built = true
        backgroundColor = PColor(0x2A1408).ns
        let paper = panelSprite(1264, 788, scale: 4)
        paper.position = CGPoint(x: 640, y: 400)
        addChild(paper)
        let t = inkLabel(title, scale: 5)
        t.position = CGPoint(x: 640, y: 746)
        addChild(t)
        let tip: String
        switch kind {
        case .chest: tip = "CHESTS HOLD FISH. FISH LOSE ~6% VALUE PER DAY OUTSIDE THE FRIDGE/FREEZER."
        case .fridge: tip = "THE FRIDGE KEEPS PRODUCE FROM SPOILING AND SLOWS FISH SPOILAGE TO 1.5% PER DAY."
        case .freezer: tip = "FROZEN FISH NEVER SPOIL. PERFECT FOR WAITING OUT A PRICE DROP."
        }
        let tl = inkLabel(tip, scale: 2, color: PColor(0x9A6A3A))
        tl.position = CGPoint(x: 640, y: 704)
        addChild(tl)
        addChild(content)
        feedback.position = CGPoint(x: 640, y: 92)
        addChild(feedback)
        let help = inkLabel("←→: SIDE   ↑↓: CHOOSE   SPACE: MOVE KIND   X: MOVE ALL   ESC: BACK", scale: 2, color: PColor(0x9A6A3A))
        help.position = CGPoint(x: 640, y: 44)
        addChild(help)
        rebuild()
    }

    private func fishEntries(_ list: [CaughtFish], _ s: SaveData) -> [Entry] {
        var g: [String: (Int, Int, Double)] = [:]
        for c in list {
            let v = g[c.id] ?? (0, 0, 0)
            g[c.id] = (v.0 + 1, v.1 + Market.price(c, day: s.day, sellBonus: s.sellBonus), v.2 + c.freshness)
        }
        return g.compactMap { id, v in
            guard let sp = FishSpecies.byID[id] else { return nil }
            return Entry(isFish: true, id: id, name: sp.name, count: v.0, worth: v.1, fresh: v.2 / Double(v.0),
                         icon: FishPixel.texture(sp, length: 14), color: sp.rarity.inkColor)
        }.sorted { $0.worth > $1.worth }
    }

    private func itemEntries(_ dict: [String: Int], _ s: SaveData) -> [Entry] {
        dict.compactMap { id, n in
            guard n > 0, let g = Good.byID[id], g.cat == .produce else { return nil }
            return Entry(isFish: false, id: id, name: g.name, count: n, worth: Good.price(id, day: s.day) * n, fresh: nil,
                         icon: GoodArt.icon(id), color: PColor(0x2E8A2A))
        }.sorted { $0.worth > $1.worth }
    }

    private func lists(_ s: SaveData) -> [[Entry]] {
        switch kind {
        case .chest: return [fishEntries(s.cooler, s), fishEntries(s.chest, s)]
        case .fridge: return [fishEntries(s.cooler, s) + itemEntries(s.items, s), fishEntries(s.fridgeFish, s) + itemEntries(s.fridgeItems, s)]
        case .freezer: return [fishEntries(s.cooler, s), fishEntries(s.freezer, s)]
        }
    }

    private func capacityText(_ s: SaveData) -> String {
        switch kind {
        case .chest: return "CHESTS \(s.chest.count)/\(s.chestCapacity)"
        case .fridge: return "FRIDGE \(s.fridgeUsed)/\(SaveData.fridgeSize)"
        case .freezer: return "FREEZER \(s.freezer.count)/\(SaveData.freezerSize)"
        }
    }

    private func rebuild() {
        content.removeAllChildren()
        let s = Game.shared.save
        let all = lists(s)
        let titles = [kind == .fridge ? "COOLER & BACKPACK" : "COOLER \(s.cooler.count)/\(s.coolerCapacity)", capacityText(s)]
        for col in 0..<2 {
            let x: CGFloat = col == 0 ? 340 : 940
            let head = panelSprite(520, 56, scale: 2, style: col == column ? .slotLit : .slot)
            head.position = CGPoint(x: x, y: 652)
            head.addChild(inkLabel(titles[col], scale: 3))
            content.addChild(head)
            let list = all[col]
            row[col] = max(0, min(row[col], list.count - 1))
            if list.isEmpty {
                let e = inkLabel("EMPTY", scale: 3, color: PColor(0x9A7A5A))
                e.position = CGPoint(x: x, y: 470)
                content.addChild(e)
            }
            let visible = 10
            let start = max(0, min(row[col] - visible / 2, list.count - visible))
            for (i, e) in list.enumerated() where i >= start && i < start + visible {
                let y = 594 - CGFloat(i - start) * 46
                let lit = col == column && i == row[col]
                let r = panelSprite(520, 42, scale: 2, style: lit ? .slotLit : .slot)
                r.position = CGPoint(x: x, y: y)
                content.addChild(r)
                let icon = pixelSprite(e.icon, scale: 2)
                icon.position = CGPoint(x: -230, y: 0)
                r.addChild(icon)
                let n = inkLabel(e.name.uppercased(), scale: 2, color: e.color, align: .left)
                n.position = CGPoint(x: -200, y: 0)
                r.addChild(n)
                var right = "×\(e.count)   ≈\(e.worth)G"
                if let f = e.fresh { right = "\(Int(f * 100))% FRESH   " + right }
                let c = inkLabel(right, scale: 2, color: (e.fresh ?? 1) < 0.75 ? PColor(0xC8281A) : .ink, align: .right)
                c.position = CGPoint(x: 240, y: 0)
                r.addChild(c)
            }
        }
        let arrow = inkLabel(column == 0 ? "→" : "←", scale: 6)
        arrow.position = CGPoint(x: 640, y: 400)
        content.addChild(arrow)
    }

    private func room(_ s: SaveData, toStorage: Bool, fish: Bool) -> Int {
        if !toStorage { return fish ? s.coolerCapacity - s.cooler.count : Int.max }
        switch kind {
        case .chest: return s.chestCapacity - s.chest.count
        case .fridge: return SaveData.fridgeSize - s.fridgeUsed
        case .freezer: return SaveData.freezerSize - s.freezer.count
        }
    }

    private func move(all: Bool) {
        let game = Game.shared
        let list = lists(game.save)[column]
        guard !list.isEmpty else { return }
        let entries = all ? list : [list[row[column]]]
        let toStorage = column == 0
        var moved = 0
        for e in entries {
            var space = room(game.save, toStorage: toStorage, fish: e.isFish)
            guard space > 0 else { continue }
            if e.isFish {
                var src: [CaughtFish], dst: [CaughtFish]
                switch (kind, toStorage) {
                case (.chest, true): src = game.save.cooler; dst = game.save.chest
                case (.chest, false): src = game.save.chest; dst = game.save.cooler
                case (.fridge, true): src = game.save.cooler; dst = game.save.fridgeFish
                case (.fridge, false): src = game.save.fridgeFish; dst = game.save.cooler
                case (.freezer, true): src = game.save.cooler; dst = game.save.freezer
                case (.freezer, false): src = game.save.freezer; dst = game.save.cooler
                }
                var kept: [CaughtFish] = []
                for c in src { if c.id == e.id && space > 0 { dst.append(c); space -= 1; moved += 1 } else { kept.append(c) } }
                switch (kind, toStorage) {
                case (.chest, true): game.save.cooler = kept; game.save.chest = dst
                case (.chest, false): game.save.chest = kept; game.save.cooler = dst
                case (.fridge, true): game.save.cooler = kept; game.save.fridgeFish = dst
                case (.fridge, false): game.save.fridgeFish = kept; game.save.cooler = dst
                case (.freezer, true): game.save.cooler = kept; game.save.freezer = dst
                case (.freezer, false): game.save.freezer = kept; game.save.cooler = dst
                }
            } else {
                let n = min(space, e.count)
                if toStorage {
                    game.save.take(e.id, n)
                    game.save.fridgeItems[e.id, default: 0] += n
                } else {
                    game.save.fridgeItems[e.id] = (game.save.fridgeItems[e.id] ?? 0) - n
                    if game.save.fridgeItems[e.id] == 0 { game.save.fridgeItems[e.id] = nil }
                    game.save.add(e.id, n)
                }
                moved += n
            }
        }
        guard moved > 0 else {
            feedback.text = toStorage ? "\(title) IS FULL!" : "YOUR COOLER IS FULL!"
            feedback.textColor = PColor(0xC8281A)
            Sound.play("Funk", volume: 0.3)
            return
        }
        game.save.persist()
        feedback.text = "MOVED \(moved) ITEM\(moved == 1 ? "" : "S")."
        feedback.textColor = PColor(0x2E8A2A)
        Sound.play("Tink", volume: 0.4)
        rebuild()
    }

    override func keyPressed(_ key: UInt16) {
        switch key {
        case Key.left, Key.a: column = 0; rebuild()
        case Key.right, Key.d: column = 1; rebuild()
        case Key.up, Key.w: row[column] -= 1; rebuild()
        case Key.down, Key.s: row[column] += 1; rebuild()
        case Key.space, Key.ret, Key.enter: move(all: false)
        case Key.x: move(all: true)
        case Key.esc: Game.shared.showHouse()
        default: break
        }
    }
}

// MARK: - Gear & wardrobe

final class GearScene: BaseScene {
    enum Tab: Int, CaseIterable { case lure, bait, hat, shirt, pants, look, rod }
    private static let names = ["LURE", "BAIT", "HAT", "SHIRT", "PANTS", "LOOK", "ROD"]
    private var tab: Tab
    private let fromHouse: Bool
    private var selected = 0
    private let content = SKNode()
    private let preview = SKNode()
    private var built = false

    init(tab: Tab, fromHouse: Bool) {
        self.tab = tab
        self.fromHouse = fromHouse
        super.init(size: Game.sceneSize)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func sceneDidAppear() {
        guard !built else { return }
        built = true
        backgroundColor = PColor(0x2A1408).ns
        let paper = panelSprite(1264, 788, scale: 4)
        paper.position = CGPoint(x: 640, y: 400)
        addChild(paper)
        let title = inkLabel(fromHouse ? "WARDROBE" : "TACKLE BOX & OUTFIT", scale: 5)
        title.position = CGPoint(x: 640, y: 746)
        addChild(title)
        let stage = panelSprite(300, 520, scale: 3, style: .slot)
        stage.position = CGPoint(x: 190, y: 380)
        addChild(stage)
        addChild(preview)
        addChild(content)
        let help = inkLabel("1-6 / TAB: CATEGORY   ←→: CHOOSE   SPACE: EQUIP   ESC: BACK", scale: 2, color: PColor(0x9A6A3A))
        help.position = CGPoint(x: 640, y: 44)
        addChild(help)
        rebuild()
    }

    private var options: [GearItem?] {
        let s = Game.shared.save
        switch tab {
        case .lure: return [nil] + GearItem.inSlot(.lure).filter { s.owned.contains($0.id) }
        case .bait: return [nil] + GearItem.inSlot(.bait).filter { (s.bait[$0.id] ?? 0) > 0 }
        case .hat: return GearItem.inSlot(.hat).filter { s.owned.contains($0.id) }
        case .shirt: return GearItem.inSlot(.shirt).filter { s.owned.contains($0.id) }
        case .pants: return GearItem.inSlot(.pants).filter { s.owned.contains($0.id) }
        case .look, .rod: return []
        }
    }

    private var slot: Slot? { tab == .look || tab == .rod ? nil : Slot.allCases[tab.rawValue] }

    private func rebuild() {
        let s = Game.shared.save
        preview.removeAllChildren()
        for (i, d) in [Dir.down, .right, .up].enumerated() {
            let p = pixelSprite(PlayerArt.texture(d, frame: 0), scale: i == 0 ? 10 : 5)
            p.position = i == 0 ? CGPoint(x: 190, y: 470) : CGPoint(x: 130 + CGFloat(i - 1) * 120, y: 240)
            preview.addChild(p)
        }
        let b = s.bonuses(habitat: .lake, onBoat: false)
        let stats = inkLabel("LUCK +\(Int(b.luck * 100))%  ·  SIZE +\(Int(b.size * 100))%", scale: 2)
        stats.position = CGPoint(x: 190, y: 150)
        preview.addChild(stats)

        content.removeAllChildren()
        for t in Tab.allCases {
            let p = panelSprite(116, 50, scale: 2, style: t == tab ? .slotLit : .slot)
            p.position = CGPoint(x: 410 + CGFloat(t.rawValue) * 124, y: 670)
            p.addChild(inkLabel("\(t.rawValue + 1) \(Self.names[t.rawValue])", scale: 2, color: t == tab ? .ink : PColor(0x9A7A5A)))
            content.addChild(p)
        }

        if tab == .rod {
            let owned = s.rodsOwned.sorted()
            selected = max(0, min(selected, owned.count - 1))
            for (i, ri) in owned.enumerated() {
                let rod = Rod.all[ri]
                let col = i % 5, row = i / 5
                let card = panelSprite(160, 150, scale: 2, style: i == selected ? .slotLit : .slot)
                card.position = CGPoint(x: 490 + CGFloat(col) * 172, y: 560 - CGFloat(row) * 162)
                content.addChild(card)
                let line = SKSpriteNode(color: PColor(rod.color).ns, size: CGSize(width: 80, height: 6))
                line.zRotation = 0.6
                line.position = CGPoint(x: 0, y: 34)
                card.addChild(line)
                let n = inkLabel(rod.name.uppercased(), scale: rod.name.count > 11 ? 1.5 : 2)
                n.position = CGPoint(x: 0, y: -14)
                card.addChild(n)
                if s.rodLevel == ri { let e = inkLabel("EQUIPPED", scale: 2, color: PColor(0x2E8A2A)); e.position = CGPoint(x: 0, y: -42); card.addChild(e) }
            }
            if selected < owned.count {
                let detail = panelSprite(820, 80, scale: 2, style: .dark)
                detail.position = CGPoint(x: 830, y: 150)
                detail.addChild(PixelLabel("BEST FOR: " + Rod.all[owned[selected]].specialtyLabel, scale: 2))
                content.addChild(detail)
            }
            return
        }

        if tab == .look {
            for (r, (label, colors, idx)) in [("HAIR", GearItem.hairColors, s.hairIdx), ("SKIN", GearItem.skinTones, s.skinIdx)].enumerated() {
                let y: CGFloat = 520 - CGFloat(r) * 180
                let l = inkLabel(label, scale: 3, align: .left)
                l.position = CGPoint(x: 420, y: y + 70)
                content.addChild(l)
                for (i, c) in colors.enumerated() {
                    let sw = panelSprite(96, 96, scale: 2, style: (r == selected / 10 && i == selected % 10) ? .slotLit : .slot)
                    sw.position = CGPoint(x: 470 + CGFloat(i) * 112, y: y)
                    let chip = SKSpriteNode(color: PColor(c).ns, size: CGSize(width: 56, height: 56))
                    sw.addChild(chip)
                    if i == idx { let k = inkLabel("*", scale: 4); k.position = CGPoint(x: 30, y: -30); sw.addChild(k) }
                    content.addChild(sw)
                }
            }
            let hint = inkLabel("↑↓: HAIR / SKIN   ←→: COLOR   SPACE: APPLY", scale: 2, color: PColor(0x7A5A3A))
            hint.position = CGPoint(x: 820, y: 180)
            content.addChild(hint)
            return
        }

        let opts = options
        selected = max(0, min(selected, opts.count - 1))
        let equippedID = slot.flatMap { s.equipped[$0.rawValue] }
        if opts.isEmpty || (opts.count == 1 && opts[0] == nil) {
            let e = inkLabel("NOTHING HERE YET.\nBUY SOME AT THE BAIT & TACKLE SHOP!", scale: 3, color: PColor(0x9A7A5A))
            e.position = CGPoint(x: 820, y: 360)
            content.addChild(e)
        }
        for (i, it) in opts.enumerated() {
            let col = i % 5, row = i / 5
            let isOn = it?.id == equippedID
            let card = panelSprite(160, 150, scale: 2, style: i == selected ? .slotLit : .slot)
            card.position = CGPoint(x: 490 + CGFloat(col) * 172, y: 560 - CGFloat(row) * 162)
            content.addChild(card)
            if let it {
                let icon = pixelSprite(ItemArt.icon(it), scale: 3)
                icon.position = CGPoint(x: 0, y: 30)
                card.addChild(icon)
            }
            let n = inkLabel((it?.name ?? "NONE").uppercased(), scale: (it?.name.count ?? 0) > 11 ? 1.5 : 2)
            n.position = CGPoint(x: 0, y: -22)
            card.addChild(n)
            var st = isOn || (it == nil && equippedID == nil) ? "EQUIPPED" : ""
            if let it, it.slot == .bait { st += (st.isEmpty ? "" : " ") + "×\(s.bait[it.id] ?? 0)" }
            let sl = inkLabel(st, scale: 2, color: PColor(0x2E8A2A))
            sl.position = CGPoint(x: 0, y: -48)
            card.addChild(sl)
        }
        if selected < opts.count, let it = opts[selected] {
            let detail = panelSprite(820, 80, scale: 2, style: .dark)
            detail.position = CGPoint(x: 830, y: 150)
            detail.addChild(PixelLabel(it.perk.uppercased(), scale: 2))
            content.addChild(detail)
        }
    }

    private func equip() {
        let game = Game.shared
        if tab == .rod {
            let owned = game.save.rodsOwned.sorted()
            if selected < owned.count { game.save.rodLevel = owned[selected] }
        } else if tab == .look {
            if selected / 10 == 0 { game.save.hairIdx = selected % 10 } else { game.save.skinIdx = selected % 10 }
        } else if let slot {
            let opts = options
            guard selected < opts.count else { return }
            game.save.equipped[slot.rawValue] = opts[selected]?.id
            if game.save.equipped[slot.rawValue] == nil, let d = GearItem.defaults[slot] { game.save.equipped[slot.rawValue] = d }
        }
        game.save.persist()
        Sound.play("Tink", volume: 0.4)
        rebuild()
    }

    override func keyPressed(_ key: UInt16) {
        if let i = Key.numbers.firstIndex(of: key), i < Tab.allCases.count { tab = Tab(rawValue: i)!; selected = 0; rebuild(); return }
        let n = tab == .look ? (selected / 10 == 0 ? GearItem.hairColors.count : GearItem.skinTones.count) : (tab == .rod ? Game.shared.save.rodsOwned.count : options.count)
        switch key {
        case Key.tab: tab = Tab(rawValue: (tab.rawValue + 1) % Tab.allCases.count)!; selected = 0; rebuild()
        case Key.left, Key.a:
            if tab == .look { selected = (selected / 10) * 10 + max(0, selected % 10 - 1) } else { selected = max(0, selected - 1) }
            rebuild()
        case Key.right, Key.d:
            if tab == .look { selected = (selected / 10) * 10 + min(n - 1, selected % 10 + 1) } else { selected = min(n - 1, selected + 1) }
            rebuild()
        case Key.up, Key.w:
            if tab == .look { selected = selected % 10 } else { selected = max(0, selected - 5) }
            rebuild()
        case Key.down, Key.s:
            if tab == .look { selected = 10 + min(selected % 10, GearItem.skinTones.count - 1) } else { selected = min(n - 1, selected + 5) }
            rebuild()
        case Key.space, Key.ret, Key.enter: equip()
        case Key.esc, Key.g: fromHouse ? Game.shared.showHouse() : Game.shared.showMap()
        default: break
        }
    }
}

// MARK: - Competition board & results

final class BoardScene: BaseScene {
    private var built = false
    private var showHelp = false
    private let content = SKNode()
    private let feedback = inkLabel("", scale: 3)

    override func sceneDidAppear() {
        guard !built else { return }
        built = true
        backgroundColor = PColor(0x2A1408).ns
        let paper = panelSprite(1264, 788, scale: 4)
        paper.position = CGPoint(x: 640, y: 400)
        addChild(paper)
        addChild(content)
        feedback.position = CGPoint(x: 640, y: 74)
        addChild(feedback)
        showHelp = !Game.shared.save.requests.isEmpty && Competition.on(day: Game.shared.save.day) == nil
        rebuild()
    }

    private func rebuild() {
        content.removeAllChildren()
        let save = Game.shared.save
        let title = inkLabel("TOWN BOARD", scale: 5)
        title.position = CGPoint(x: 640, y: 746)
        content.addChild(title)
        for (i, name) in ["1 CONTESTS", "2 HELP WANTED"].enumerated() {
            let lit = (i == 1) == showHelp
            let p = panelSprite(280, 48, scale: 2, style: lit ? .slotLit : .slot)
            p.position = CGPoint(x: 490 + CGFloat(i) * 300, y: 690)
            p.addChild(inkLabel(name, scale: 2, color: lit ? .ink : PColor(0x9A7A5A)))
            content.addChild(p)
        }
        let today = inkLabel("TODAY: \(GameCalendar.label(save.day))  \(Clock.timeString(save.minutes))   ·   TROPHIES WON: \(save.trophies.count)", scale: 2, color: PColor(0x9A6A3A))
        today.position = CGPoint(x: 640, y: 646)
        content.addChild(today)
        showHelp ? buildHelp(save) : buildContests(save)
        let help = inkLabel(showHelp ? "TALK TO TOWNSFOLK WITH A ! TO DELIVER   ·   TAB: SWITCH   ESC: BACK" : "SPACE: ENTER TODAY'S CONTEST   ·   TAB: SWITCH   ESC: BACK", scale: 2, color: PColor(0x9A6A3A))
        help.position = CGPoint(x: 640, y: 36)
        content.addChild(help)
    }

    private func buildHelp(_ save: SaveData) {
        if save.requests.isEmpty {
            let e = inkLabel("NO REQUESTS RIGHT NOW.\nCHECK BACK TOMORROW!", scale: 4, color: PColor(0x9A7A5A))
            e.position = CGPoint(x: 640, y: 400)
            content.addChild(e)
            return
        }
        for (i, r) in save.requests.enumerated() {
            let y = 590 - CGFloat(i) * 76
            let row = panelSprite(1120, 68, scale: 2, style: .slot)
            row.position = CGPoint(x: 640, y: y)
            content.addChild(row)
            let icon = pixelSprite(r.isFish ? FishPixel.texture(FishSpecies.byID[r.item]!, length: 16) : GoodArt.icon(r.item), scale: 2)
            icon.position = CGPoint(x: -520, y: 0)
            row.addChild(icon)
            let who = inkLabel(Villager.byID[r.npc]?.name.uppercased() ?? r.npc, scale: 3, color: PColor(0x2A64C8), align: .left)
            who.position = CGPoint(x: -480, y: 12)
            row.addChild(who)
            let have = r.isFish ? save.fishCount(r.item) : save.count(r.item)
            let what = inkLabel("WANTS \(r.qty) \(r.itemName.uppercased())  ·  YOU HAVE \(have)", scale: 2, color: have >= r.qty ? PColor(0x2E8A2A) : .ink, align: .left)
            what.position = CGPoint(x: -480, y: -14)
            row.addChild(what)
            let pay = inkLabel("PAYS \(r.reward)G", scale: 3, color: PColor(0x9A6010), align: .right)
            pay.position = CGPoint(x: 520, y: 12)
            row.addChild(pay)
            let due = inkLabel("BY \(GameCalendar.label(r.due))", scale: 2, color: r.due - save.day <= 1 ? PColor(0xC8281A) : PColor(0x7A5A3A), align: .right)
            due.position = CGPoint(x: 520, y: -14)
            row.addChild(due)
        }
    }

    private func buildContests(_ save: SaveData) {
        let todays = Competition.on(day: save.day)
        for (i, c) in Competition.all.enumerated() {
            let y = 594 - CGFloat(i) * 54
            let isToday = c.id == todays?.id
            let row = panelSprite(1120, 48, scale: 2, style: isToday ? .slotLit : .slot)
            row.position = CGPoint(x: 640, y: y)
            content.addChild(row)
            let date = inkLabel("\(c.season.name.uppercased()) \(c.dayOfSeason)", scale: 2, color: isToday ? PColor(0xC8281A) : .ink, align: .left)
            date.position = CGPoint(x: -540, y: 0)
            row.addChild(date)
            let n = inkLabel(c.name.uppercased(), scale: 3, align: .left)
            n.position = CGPoint(x: -390, y: 0)
            row.addChild(n)
            let d = inkLabel("\(c.habitat.spotName.uppercased()) · \(c.goal.label)", scale: 2, color: PColor(0x7A5A3A), align: .left)
            d.position = CGPoint(x: 40, y: 8)
            row.addChild(d)
            let f = inkLabel("FEE \(c.fee)G · 1ST WINS \(c.prizes[0])G + TROPHY", scale: 2, color: PColor(0x9A6010), align: .left)
            f.position = CGPoint(x: 40, y: -12)
            row.addChild(f)
        }
        let status: String
        let h = Clock.hour(save.minutes)
        if save.comp != nil { status = "YOU'RE ALREADY COMPETING. GET FISHING!" }
        else if let c = todays {
            if save.compEnteredDay == save.day { status = "YOU ALREADY ENTERED TODAY'S CONTEST." }
            else if Competition.entryHours.contains(h) { status = "SPACE: ENTER \(c.name.uppercased()) FOR \(c.fee)G  (3 MINUTES, FISH AT \(c.habitat.spotName.uppercased()))" }
            else { status = "REGISTRATION FOR \(c.name.uppercased()) IS OPEN 6 AM – 4 PM." }
        } else {
            let (c, d) = Competition.next(after: save.day)
            status = "NEXT: \(c.name.uppercased()) IN \(d - save.day) DAYS (\(GameCalendar.label(d)))"
        }
        let st = panelSprite(1160, 56, scale: 2, style: .dark)
        st.position = CGPoint(x: 640, y: 128)
        st.addChild(PixelLabel(status, scale: 2, color: .gold))
        content.addChild(st)
    }

    override func keyPressed(_ key: UInt16) {
        switch key {
        case Key.tab, Key.left, Key.right: showHelp.toggle(); rebuild()
        case Key.one: showHelp = false; rebuild()
        case Key.two: showHelp = true; rebuild()
        case Key.space, Key.ret, Key.enter:
            guard !showHelp else { return }
            let game = Game.shared
            guard game.save.comp == nil, let c = Competition.on(day: game.save.day), game.save.compEnteredDay != game.save.day,
                  Competition.entryHours.contains(Clock.hour(game.save.minutes)) else {
                Sound.play("Funk", volume: 0.3)
                return
            }
            guard game.save.coins >= c.fee else {
                feedback.text = "YOU NEED \(c.fee)G TO ENTER."
                feedback.textColor = PColor(0xC8281A)
                Sound.play("Funk", volume: 0.3)
                return
            }
            game.save.coins -= c.fee
            game.save.compEnteredDay = game.save.day
            game.save.comp = ActiveComp(id: c.id, timeLeft: Competition.duration, rivals: c.makeRivals())
            game.save.persist()
            Sound.play("Hero", volume: 0.4)
            game.showMap()
            game.mapScene.toast("GO! FISH AT \(c.habitat.spotName.uppercased())!\n\(c.goal.label) WINS")
        case Key.esc:
            Game.shared.showMap()
        default: break
        }
    }
}

final class CompResultScene: BaseScene {
    private var built = false

    override func sceneDidAppear() {
        guard !built else { return }
        built = true
        backgroundColor = PColor(0x2A1408).ns
        let paper = panelSprite(900, 640, scale: 4)
        paper.position = CGPoint(x: 640, y: 400)
        addChild(paper)
        guard let r = Game.shared.save.lastResult, let c = Competition.byID[r.id] else { return }
        let title = inkLabel(c.name.uppercased(), scale: 5)
        title.position = CGPoint(x: 640, y: 664)
        addChild(title)
        let sub = inkLabel("FINAL RESULTS  ·  \(c.goal.label)", scale: 2, color: PColor(0x9A6A3A))
        sub.position = CGPoint(x: 640, y: 622)
        addChild(sub)
        for (i, name) in r.standings.enumerated() {
            let y = 560 - CGFloat(i) * 62
            let you = name == "YOU"
            let row = panelSprite(700, 54, scale: 2, style: you ? .slotLit : .slot)
            row.position = CGPoint(x: 640, y: y)
            addChild(row)
            let place = inkLabel(["1ST", "2ND", "3RD", "4TH", "5TH"][min(i, 4)], scale: 3, color: i == 0 ? PColor(0xC8781A) : .ink, align: .left)
            place.position = CGPoint(x: -320, y: 0)
            row.addChild(place)
            let n = inkLabel(name, scale: 3, color: you ? PColor(0x2A64C8) : .ink, align: .left)
            n.position = CGPoint(x: -200, y: 0)
            row.addChild(n)
            let sc = inkLabel(c.format(r.scores[i]), scale: 3, align: .right)
            sc.position = CGPoint(x: 320, y: 0)
            row.addChild(sc)
        }
        let msg: String
        switch r.place {
        case 1: msg = "YOU WON! +\(r.prize)G AND A TROPHY FOR YOUR HOUSE!"
        case 2, 3: msg = "\(r.place == 2 ? "2ND" : "3RD") PLACE! +\(r.prize)G"
        default: msg = "NO PRIZE THIS TIME. PRACTICE AND TRY AGAIN!"
        }
        let m = inkLabel(msg, scale: 3, color: r.place == 1 ? PColor(0xC8781A) : .ink)
        m.position = CGPoint(x: 640, y: 200)
        addChild(m)
        if r.place == 1 {
            let t = pixelSprite(ItemArt.trophy(0), scale: 8)
            t.position = CGPoint(x: 640, y: 290)
            addChild(t)
            t.run(.repeatForever(.sequence([.moveBy(x: 0, y: 8, duration: 0.5), .moveBy(x: 0, y: -8, duration: 0.5)])))
        }
        let h = inkLabel("SPACE: CONTINUE", scale: 2, color: PColor(0x9A6A3A))
        h.position = CGPoint(x: 640, y: 120)
        addChild(h)
    }

    override func keyPressed(_ key: UInt16) {
        if key == Key.space || key == Key.ret || key == Key.esc { Game.shared.showMap() }
    }
}
