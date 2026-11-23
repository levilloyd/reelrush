import SpriteKit

// MARK: - Gifts

final class GiftScene: BaseScene {
    private struct Option { let id: String; let isFish: Bool; let name: String; let count: Int; let icon: SKTexture; let points: Int }
    let npc: String
    private var selected = 0
    private let content = SKNode()
    private var built = false

    init(npc: String) {
        self.npc = npc
        super.init(size: Game.sceneSize)
    }

    required init?(coder: NSCoder) { fatalError() }

    private var options: [Option] {
        let s = Game.shared.save
        var out: [Option] = Good.all.filter { s.count($0.id) > 0 && $0.sellable }.map {
            Option(id: $0.id, isFish: false, name: $0.name, count: s.count($0.id), icon: GoodArt.icon($0.id), points: Romance.points($0.id, isFish: false))
        }
        var g: [String: Int] = [:]
        for c in s.cooler { g[c.id, default: 0] += 1 }
        for (id, n) in g.sorted(by: { $0.key < $1.key }) {
            guard let sp = FishSpecies.byID[id] else { continue }
            out.append(Option(id: id, isFish: true, name: sp.name, count: n, icon: FishPixel.texture(sp, length: 16), points: Romance.points(id, isFish: true)))
        }
        return out.sorted { $0.points > $1.points }
    }

    override func sceneDidAppear() {
        guard !built else { return }
        built = true
        backgroundColor = PColor(0x2A1408).ns
        let paper = panelSprite(1264, 788, scale: 4)
        paper.position = CGPoint(x: 640, y: 400)
        addChild(paper)
        let v = Villager.byID[npc]!
        let t = inkLabel("GIFT FOR \(v.name.uppercased())", scale: 5)
        t.position = CGPoint(x: 640, y: 746)
        addChild(t)
        let face = pixelSprite(PlayerArt.texture(.down, frame: 0, outfit: v.outfit), scale: 6)
        face.position = CGPoint(x: 150, y: 560)
        addChild(face)
        let hearts = inkLabel("HEARTS \(Game.shared.save.hearts(npc))/10", scale: 3, color: PColor(0xC83A5A))
        hearts.position = CGPoint(x: 150, y: 400)
        addChild(hearts)
        let tip = inkLabel(PixelFont.wrap("COOKED DISHES ARE LOVED MOST. GEMS, PRODUCE AND RARE FISH ARE GREAT TOO.", maxWidth: 80), scale: 2, color: PColor(0x9A6A3A))
        tip.position = CGPoint(x: 150, y: 320)
        addChild(tip)
        addChild(content)
        let help = inkLabel("ARROWS: CHOOSE   SPACE: GIVE   ESC: BACK", scale: 2, color: PColor(0x9A6A3A))
        help.position = CGPoint(x: 640, y: 44)
        addChild(help)
        rebuild()
    }

    private func rebuild() {
        content.removeAllChildren()
        let list = options
        selected = max(0, min(selected, list.count - 1))
        if list.isEmpty {
            let e = inkLabel("YOU HAVE NOTHING TO GIVE.\nTRY FOOD, PRODUCE, GEMS OR FISH.", scale: 3, color: PColor(0x9A7A5A))
            e.position = CGPoint(x: 760, y: 400)
            content.addChild(e)
            return
        }
        for (i, o) in list.prefix(30).enumerated() {
            let col = i % 6, row = i / 6
            let card = panelSprite(150, 118, scale: 2, style: i == selected ? .slotLit : .slot)
            card.position = CGPoint(x: 380 + CGFloat(col) * 158, y: 620 - CGFloat(row) * 126)
            content.addChild(card)
            let icon = pixelSprite(o.icon, scale: 3)
            icon.position = CGPoint(x: 0, y: 22)
            card.addChild(icon)
            let n = inkLabel(PixelFont.wrap(o.name.uppercased(), maxWidth: 64), scale: 1.5)
            n.position = CGPoint(x: 0, y: -18)
            card.addChild(n)
            let c = inkLabel("×\(o.count)  +\(o.points)♥".replacingOccurrences(of: "♥", with: ""), scale: 2, color: PColor(0xC83A5A))
            c.position = CGPoint(x: 0, y: -42)
            card.addChild(c)
        }
    }

    override func keyPressed(_ key: UInt16) {
        let n = min(30, options.count)
        switch key {
        case Key.left, Key.a: selected = max(0, selected - 1); rebuild()
        case Key.right, Key.d: selected = min(max(0, n - 1), selected + 1); rebuild()
        case Key.up, Key.w: selected = max(0, selected - 6); rebuild()
        case Key.down, Key.s: selected = min(max(0, n - 1), selected + 6); rebuild()
        case Key.space, Key.ret, Key.enter:
            guard selected < n else { return }
            let o = options[selected]
            let game = Game.shared
            let ok = o.isFish ? game.save.takeFish(o.id, 1) : game.save.take(o.id)
            guard ok else { return }
            game.save.friendship[npc, default: 0] += o.points
            game.save.giftedDay[npc] = game.save.day
            game.save.persist()
            Sound.play("Purr", volume: 0.4)
            let v = Villager.byID[npc]!
            let reaction = o.points >= 5 ? "I LOVE IT! THANK YOU SO MUCH!" : (o.points >= 3 ? "OH, HOW THOUGHTFUL!" : "THANKS!")
            game.showMap()
            game.mapScene.toast("\(v.name.uppercased()): \(reaction)\nHEARTS \(game.save.hearts(npc))/10")
        case Key.esc: Game.shared.showMap()
        default: break
        }
    }
}

// MARK: - Boat shed

final class BoatShedScene: BaseScene {
    private var selected = 0
    private let content = SKNode()
    private let feedback = inkLabel("", scale: 3)
    private var built = false

    override func sceneDidAppear() {
        guard !built else { return }
        built = true
        backgroundColor = PColor(0x2A1408).ns
        let paper = panelSprite(1264, 788, scale: 4)
        paper.position = CGPoint(x: 640, y: 400)
        addChild(paper)
        let t = inkLabel("BOAT SHED", scale: 5)
        t.position = CGPoint(x: 640, y: 746)
        addChild(t)
        addChild(content)
        feedback.position = CGPoint(x: 640, y: 96)
        addChild(feedback)
        let help = inkLabel("←→: CHOOSE   SPACE: HITCH TO TRAILER   ESC: LEAVE", scale: 2, color: PColor(0x9A6A3A))
        help.position = CGPoint(x: 640, y: 44)
        addChild(help)
        if let h = Game.shared.save.hitched, let i = Game.shared.save.boatsOwned.firstIndex(of: h) { selected = i }
        rebuild()
    }

    private func rebuild() {
        content.removeAllChildren()
        let s = Game.shared.save
        let carText = s.activeCar.map { "CAR: \($0.name.uppercased())" + ($0.tow == 0 ? " (CAN'T TOW)" : $0.tow == 1 ? " (TOWS SMALL)" : " (TOWS ANY)") } ?? "CAR: NONE"
        let trailerText = s.trailerSize == 0 ? "TRAILER: NONE" : (s.trailerSize == 1 ? "TRAILER: SMALL" : "TRAILER: BIG")
        let status = inkLabel("\(carText)   ·   \(trailerText)   ·   " + (s.towProblem.map { "⚡ " + $0 } ?? "READY TO TOW! DRIVE (C) TO ANY WATER, PRESS E"), scale: 2,
                              color: s.towProblem == nil ? PColor(0x2E8A2A) : PColor(0xC8281A))
        status.position = CGPoint(x: 640, y: 690)
        content.addChild(status)
        let owned = s.boatsOwned.compactMap { Boat.byID[$0] }
        if owned.isEmpty {
            let e = inkLabel("NO BOATS YET.\nBUY ONE AT BAIT & TACKLE IN TOWN.", scale: 4, color: PColor(0x9A7A5A))
            e.position = CGPoint(x: 640, y: 420)
            content.addChild(e)
            return
        }
        selected = min(selected, owned.count - 1)
        for (i, b) in owned.enumerated() {
            let col = i % 4, row = i / 4
            let card = panelSprite(280, 250, scale: 2, style: i == selected ? .slotLit : .slot)
            card.position = CGPoint(x: 220 + CGFloat(col) * 280, y: 520 - CGFloat(row) * 260)
            content.addChild(card)
            let water = SKSpriteNode(color: PColor(0x3C8DC8).ns, size: CGSize(width: 240, height: 30))
            water.position = CGPoint(x: 0, y: 50)
            card.addChild(water)
            let node = BoatNode(kind: b.kind, scale: 2.5)
            node.position = CGPoint(x: 0, y: 66)
            card.addChild(node)
            let n = inkLabel(b.name.uppercased(), scale: 3)
            n.position = CGPoint(x: 0, y: 0)
            card.addChild(n)
            let size = inkLabel(b.big ? "BIG · NEEDS BIG TRAILER + TRUCK" : "SMALL · ANY TRAILER", scale: 1.5, color: PColor(0x7A5A3A))
            size.position = CGPoint(x: 0, y: -30)
            card.addChild(size)
            let w = inkLabel(b.watersLabel.uppercased(), scale: 1.5, color: PColor(0x2A64C8))
            w.position = CGPoint(x: 0, y: -52)
            card.addChild(w)
            if s.hitched == b.id {
                let h = inkLabel("HITCHED", scale: 3, color: PColor(0x2E8A2A))
                h.position = CGPoint(x: 0, y: -86)
                card.addChild(h)
            }
        }
    }

    override func keyPressed(_ key: UInt16) {
        let n = Game.shared.save.boatsOwned.count
        switch key {
        case Key.left, Key.a: selected = max(0, selected - 1); rebuild()
        case Key.right, Key.d: selected = min(max(0, n - 1), selected + 1); rebuild()
        case Key.up, Key.w: selected = max(0, selected - 4); rebuild()
        case Key.down, Key.s: selected = min(max(0, n - 1), selected + 4); rebuild()
        case Key.space, Key.ret, Key.enter:
            guard n > 0 else { return }
            Game.shared.save.hitched = Game.shared.save.boatsOwned[selected]
            Game.shared.save.persist()
            Game.shared.mapScene.returnBoatToTrailer()
            feedback.text = "HITCHED THE \(Boat.byID[Game.shared.save.hitched!]!.name.uppercased())!"
            feedback.textColor = PColor(0x2E8A2A)
            Sound.play("Tink", volume: 0.4)
            rebuild()
        case Key.esc:
            Game.shared.mapScene.placeAt(Game.shared.mapScene.world.building(.boatShed).door)
            Game.shared.showMap()
        default: break
        }
    }
}

// MARK: - Kids' room

final class KidsRoomScene: BaseScene {
    private let P: CGFloat = 4
    private var built = false
    private var lastTime: TimeInterval = 0
    private let player = SKSpriteNode()
    private var pos = CGPoint(x: 300, y: 70)
    private var dir: Dir = .left
    private var walk = 0.0
    private var kidSpots: [(Kid, CGPoint)] = []
    private let toast = PixelLabel("", scale: 3, color: .gold)
    private let prompt = PixelLabel("", scale: 3)

    override func sceneDidAppear() {
        lastTime = 0
        guard !built else { return }
        built = true
        let bg = pixelSprite(Tex.get("kidsroom") {
            let b = PropArt.room()
            for y in 140..<200 { for x in 0..<320 where (x / 8 + y / 8) % 2 == 0 { b[x, y] = PColor(0xC8D8E8) } }
            for y in 140..<200 { for x in 0..<320 where (x / 8 + y / 8) % 2 == 1 { b[x, y] = PColor(0xB8C8E0) } }
            b.rect(0, 140, 320, 4, PColor(0x6A3E1E))
            b.rect(132, 144, 56, 46, PColor(0xB8C8E0))
            b.rect(316, 60, 4, 40, PColor(0x3A2010))
            return b
        }, scale: P)
        bg.anchorPoint = .zero
        addChild(bg)
        let s = Game.shared.save
        for i in 0..<s.kidBeds {
            let bx = CGFloat(20 + (i % 3) * 90), by = CGFloat(i < 3 ? 100 : 30)
            let bed = pixelSprite(Tex.get("kidbed|\(i % 3)") {
                let b = PixelBuffer(30, 34)
                let quilt = [PColor(0xE85A8A), PColor(0x5AB4E8), PColor(0x8AD05A)][i % 3]
                b.rect(0, 0, 30, 26, PColor(0x8A5A30)); b.rect(0, 24, 30, 10, PColor(0x6A3A1A))
                b.rect(2, 2, 26, 18, quilt); b.rect(4, 18, 22, 6, PColor(0xF4F0E8))
                b.outline(PColor(0x2A1408))
                return b
            }, scale: P)
            bed.anchorPoint = .zero
            bed.position = CGPoint(x: bx * P, y: by * P)
            bed.zPosition = 2
            addChild(bed)
            if i < s.kids.count {
                let k = s.kids[i]
                let stage = k.stage(s.day)
                let sp = pixelSprite(PlayerArt.texture(.down, frame: 0, outfit: k.outfit), scale: stage == .baby ? 1.8 : (stage == .child ? 2.8 : 3.6))
                sp.anchorPoint = CGPoint(x: 0.5, y: 0)
                let p = CGPoint(x: bx + 44, y: by - 6)
                sp.position = CGPoint(x: p.x * P, y: p.y * P)
                sp.zPosition = 5
                addChild(sp)
                let tag = PixelLabel("\(k.name) · \(stage == .baby ? "BABY" : (stage == .child ? "CHILD" : "TEEN (WORKS)"))", scale: 2)
                tag.position = CGPoint(x: sp.position.x, y: sp.position.y - 14)
                tag.zPosition = 6
                addChild(tag)
                kidSpots.append((k, p))
            } else {
                let free = PixelLabel("EMPTY BED", scale: 2, color: PColor(0x9A7A5A))
                free.position = CGPoint(x: (bx + 15) * P, y: (by - 4) * P)
                free.zPosition = 6
                addChild(free)
            }
        }
        player.anchorPoint = CGPoint(x: 0.5, y: 0)
        player.setPixelTexture(PlayerArt.texture(.left, frame: 0), scale: P)
        player.zPosition = 10
        addChild(player)
        let title = PixelLabel("KIDS' ROOM  ·  \(s.kids.count)/\(s.kidBeds) BEDS", scale: 3, color: .gold)
        title.position = CGPoint(x: 640, y: 780)
        title.zPosition = 50
        addChild(title)
        let help = PixelLabel("ARROWS: MOVE   SPACE: TALK   WALK RIGHT / ESC: BACK", scale: 2)
        help.position = CGPoint(x: 640, y: 16)
        help.zPosition = 50
        addChild(help)
        prompt.position = CGPoint(x: 640, y: 60)
        prompt.zPosition = 50
        addChild(prompt)
        toast.position = CGPoint(x: 640, y: 420)
        toast.zPosition = 60
        toast.alpha = 0
        addChild(toast)
    }

    private var nearKid: Kid? { kidSpots.first { hypot($0.1.x - pos.x, $0.1.y - pos.y) < 26 }?.0 }

    override func update(_ currentTime: TimeInterval) {
        let dt = lastTime == 0 ? 0 : min(1.0 / 30, currentTime - lastTime)
        lastTime = currentTime
        var ix: CGFloat = 0, iy: CGFloat = 0
        if isDown(Key.left, Key.a) { ix -= 1 }
        if isDown(Key.right, Key.d) { ix += 1 }
        if isDown(Key.up, Key.w) { iy += 1 }
        if isDown(Key.down, Key.s) { iy -= 1 }
        let moving = ix != 0 || iy != 0
        if moving {
            let len = sqrt(ix * ix + iy * iy)
            pos.x = min(320, max(6, pos.x + ix / len * 62 * CGFloat(dt)))
            pos.y = min(136, max(2, pos.y + iy / len * 62 * CGFloat(dt)))
            dir = ix != 0 ? (ix < 0 ? .left : .right) : (iy < 0 ? .down : .up)
            walk += dt * 8
            if pos.x >= 316 { Game.shared.showHouse(); return }
        }
        player.texture = PlayerArt.texture(dir, frame: moving ? [1, 0, 2, 0][Int(walk) % 4] : 0)
        player.position = CGPoint(x: snap(pos.x * P, P), y: snap(pos.y * P, P))
        prompt.text = nearKid.map { "SPACE: TALK TO \($0.name)" } ?? ""
    }

    override func keyPressed(_ key: UInt16) {
        switch key {
        case Key.space, Key.ret:
            guard let k = nearKid else { return }
            let lines: [String]
            switch k.stage(Game.shared.save.day) {
            case .baby: lines = ["GOO GOO!", "*HAPPY BABBLING*", "*GRABS YOUR FINGER*"]
            case .child: lines = ["CAN WE GO FISHING TOMORROW?", "I CAUGHT A BUG TODAY!", "I'M HUNGRY, IS THERE FISH?"]
            case .teen: lines = ["WORK WAS FINE, I GUESS.", "I SAVED UP SOME MONEY FOR THE FAMILY.", "CAN I BORROW THE CAR?"]
            }
            toast.text = "\(k.name): \(lines.randomElement()!)"
            toast.removeAllActions()
            toast.alpha = 1
            toast.run(.sequence([.wait(forDuration: 2), .fadeOut(withDuration: 0.4)]))
            Sound.play("Tink", volume: 0.3)
        case Key.esc: Game.shared.showHouse()
        default: break
        }
    }
}

// MARK: - Fishing books

final class BookScene: BaseScene {
    private var selected = 0
    private let content = SKNode()
    private var built = false

    override func sceneDidAppear() {
        guard !built else { return }
        built = true
        backgroundColor = PColor(0x2A1408).ns
        let paper = panelSprite(1264, 788, scale: 4)
        paper.position = CGPoint(x: 640, y: 400)
        addChild(paper)
        let t = inkLabel("BOOKSHELF", scale: 5)
        t.position = CGPoint(x: 640, y: 746)
        addChild(t)
        addChild(content)
        let help = inkLabel("↑↓: CHOOSE BOOK   SPACE: READ (PERMANENT FISHING BONUS)   ESC: BACK", scale: 2, color: PColor(0x9A6A3A))
        help.position = CGPoint(x: 640, y: 40)
        addChild(help)
        rebuild()
    }

    private func rebuild() {
        content.removeAllChildren()
        let s = Game.shared.save
        for (i, h) in Habitat.allCases.enumerated() {
            let read = s.booksRead.contains(h.rawValue)
            let row = panelSprite(380, 38, scale: 2, style: i == selected ? .slotLit : .slot)
            row.position = CGPoint(x: 230, y: 690 - CGFloat(i) * 41)
            content.addChild(row)
            let spine = SKSpriteNode(color: [PColor(0xC83A3A), PColor(0x3A6AB8), PColor(0x4E8A3A), PColor(0xC8961E), PColor(0x6A3AA8)][i % 5].ns,
                                     size: CGSize(width: 12, height: 26))
            spine.position = CGPoint(x: -170, y: 0)
            row.addChild(spine)
            let n = inkLabel("\(h.spotName.uppercased())", scale: 2, align: .left)
            n.position = CGPoint(x: -150, y: 0)
            row.addChild(n)
            let r = inkLabel(read ? "READ" : "UNREAD", scale: 2, color: read ? PColor(0x2E8A2A) : PColor(0x9A7A5A), align: .right)
            r.position = CGPoint(x: 170, y: 0)

            row.addChild(r)
        }
        let h = Habitat.allCases[selected]
        let page = panelSprite(800, 650, scale: 2, style: .slot)
        page.position = CGPoint(x: 840, y: 392)
        content.addChild(page)
        let title = inkLabel("THE ANGLER'S GUIDE TO \(h.spotName.uppercased())", scale: 3)
        title.position = CGPoint(x: 0, y: 290)
        page.addChild(title)
        let b = s.bonuses(habitat: h, onBoat: false)
        let luck = s.rodStats(h).luck + b.luck
        let chances = FishSpecies.chances(h, luck: luck, minutes: s.minutes, weather: s.weather, day: s.day, saltRod: s.hasSaltRod)
        let act = FishSpecies.activity(h, minutes: s.minutes, weather: s.weather, day: s.day, saltRod: s.hasSaltRod)
        let sub = inkLabel("RIGHT NOW (\(Clock.timeString(s.minutes)), \(s.weather.name.uppercased()), \(s.season.name.uppercased())): BITES \(FishSpecies.activityLabel(act).0)",
                           scale: 2, color: PColor(0x7A5A3A))
        sub.position = CGPoint(x: 0, y: 258)
        page.addChild(sub)
        for (i, (sp, p)) in chances.enumerated() {
            let y = 210 - CGFloat(i) * 56
            let icon = pixelSprite(FishPixel.texture(sp, length: 18), scale: 2)
            icon.position = CGPoint(x: -340, y: y)
            page.addChild(icon)
            let caught = (s.records[sp.id]?.count ?? 0) > 0
            let n = inkLabel(caught || s.booksRead.contains(h.rawValue) ? sp.name.uppercased() : "???", scale: 2, color: sp.rarity.inkColor, align: .left)
            n.position = CGPoint(x: -300, y: y + 10)
            page.addChild(n)
            let info = inkLabel("\(sp.rarity.name.uppercased()) · \(sp.feeding.label) · \(sp.seasonLabel)" + (sp.rainOnly ? " · RAIN" : ""), scale: 1.5, color: PColor(0x7A5A3A), align: .left)
            info.position = CGPoint(x: -300, y: y - 10)
            page.addChild(info)
            let pct = inkLabel(String(format: "%.1f%%", p * 100), scale: 3, color: p > 0.2 ? PColor(0x2E8A2A) : (p > 0.03 ? .ink : PColor(0xC8281A)), align: .right)
            pct.position = CGPoint(x: 360, y: y)
            page.addChild(pct)
            let bar = SKSpriteNode(color: PColor(0x4EA83A).ns, size: CGSize(width: max(2, snap(CGFloat(p) * 200, 2)), height: 8))
            bar.anchorPoint = CGPoint(x: 0, y: 0.5)
            bar.position = CGPoint(x: 60, y: y)
            page.addChild(bar)
        }
        let read = s.booksRead.contains(h.rawValue)
        let foot = inkLabel(read ? "YOU'VE STUDIED THIS BOOK: +4% LUCK HERE, PLUS A SMALL BONUS EVERYWHERE." : "READ IT TO LEARN ALL NAMES, +4% LUCK HERE AND A SMALL BONUS EVERYWHERE.",
                            scale: 2, color: read ? PColor(0x2E8A2A) : PColor(0x9A6010))
        foot.position = CGPoint(x: 0, y: -296)
        page.addChild(foot)
    }

    override func keyPressed(_ key: UInt16) {
        switch key {
        case Key.up, Key.w: selected = max(0, selected - 1); rebuild()
        case Key.down, Key.s: selected = min(Habitat.allCases.count - 1, selected + 1); rebuild()
        case Key.space, Key.ret, Key.enter:
            let h = Habitat.allCases[selected].rawValue
            if !Game.shared.save.booksRead.contains(h) {
                Game.shared.save.booksRead.append(h)
                Game.shared.save.persist()
                Sound.play("Glass", volume: 0.4)
                rebuild()
            }
        case Key.esc: Game.shared.showHouse()
        default: break
        }
    }
}
