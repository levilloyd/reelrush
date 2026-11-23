import SpriteKit

// MARK: - Stove & welding bench

final class CraftScene: BaseScene {
    let station: Station
    private var selected = 0
    private let content = SKNode()
    private let feedback = inkLabel("", scale: 3)
    private var built = false
    private var recipes: [Recipe] { Recipe.all.filter { $0.station == station } }

    init(station: Station) {
        self.station = station
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
        let title = inkLabel(station == .stove ? "STOVE · COOKING" : "WELDING MACHINE", scale: 5)
        title.position = CGPoint(x: 640, y: 746)
        addChild(title)
        let sub = inkLabel(station == .stove ? "EVERY DISH BURNS TIMBER. FISH COME FROM COOLER, CHESTS, FRIDGE, THEN FREEZER (CHEAPEST FIRST)."
                                             : "WELD ORE + COAL INTO BARS, OR WELD BARS ONTO TIMBER TO FORGE BETTER TOOLS.", scale: 2, color: PColor(0x9A6A3A))
        sub.position = CGPoint(x: 640, y: 700)
        addChild(sub)
        addChild(content)
        feedback.position = CGPoint(x: 640, y: 92)
        addChild(feedback)
        let help = inkLabel("↑↓: CHOOSE   SPACE: MAKE   ESC: BACK", scale: 2, color: PColor(0x9A6A3A))
        help.position = CGPoint(x: 640, y: 44)
        addChild(help)
        rebuild()
    }

    private func rebuild() {
        content.removeAllChildren()
        let s = Game.shared.save
        let visible = 8
        let start = max(0, min(selected - 3, recipes.count - visible))
        for (i, r) in recipes.enumerated() where i >= start && i < start + visible {
            let y = 630 - CGFloat(i - start) * 68
            let can = r.canMake(s)
            let row = panelSprite(1120, 62, scale: 2, style: i == selected ? .slotLit : .slot)
            row.position = CGPoint(x: 640, y: y)
            content.addChild(row)
            let tool = r.toolUpgrade
            let icon = pixelSprite(tool.map { ToolArt.icon($0.0, level: $0.1) } ?? GoodArt.icon(r.output), scale: 3)
            icon.position = CGPoint(x: -520, y: 0)
            row.addChild(icon)
            let n = inkLabel(r.name.uppercased(), scale: 3, color: can ? .ink : PColor(0x9A7A5A), align: .left)
            n.position = CGPoint(x: -480, y: 10)
            row.addChild(n)
            let info: String
            if let (k, l) = tool {
                info = Tools.level(k, s) >= l ? "ALREADY OWNED" : "FORGE A \(Tools.tiers[l].uppercased()) \(k.name.uppercased())"
            } else {
                let g = Good.byID[r.output]!
                info = "SELLS ~\(g.price)G" + (g.energy > 0 ? " · +\(g.energy) ENERGY" : "")
            }
            let val = inkLabel(info, scale: 2, color: PColor(0x9A6010), align: .left)
            val.position = CGPoint(x: -480, y: -14)
            row.addChild(val)
            var x: CGFloat = -40
            for (id, n) in r.inputs {
                let have = id == "fish" ? s.anyFishCount : s.count(id)
                let iconTex = id == "fish" ? Icons.fish() : GoodArt.icon(id)
                let ic = pixelSprite(iconTex, scale: 2)
                ic.position = CGPoint(x: x, y: 0)
                row.addChild(ic)
                let label = id == "fish" ? "ANY FISH" : Good.byID[id]!.name.uppercased()
                let t = inkLabel("\(label) \(min(have, n))/\(n)", scale: 2, color: have >= n ? PColor(0x2E8A2A) : PColor(0xC8281A), align: .left)
                t.position = CGPoint(x: x + 22, y: 0)
                row.addChild(t)
                x += 40 + t.size.width
            }
        }
    }

    override func keyPressed(_ key: UInt16) {
        switch key {
        case Key.up, Key.w: selected = max(0, selected - 1); rebuild()
        case Key.down, Key.s: selected = min(recipes.count - 1, selected + 1); rebuild()
        case Key.space, Key.ret, Key.enter:
            let r = recipes[selected]
            let game = Game.shared
            guard r.canMake(game.save) else {
                feedback.text = "MISSING INGREDIENTS!"
                feedback.textColor = PColor(0xC8281A)
                Sound.play("Funk", volume: 0.3)
                return
            }
            for (id, n) in r.inputs { if id == "fish" { game.save.takeFish(nil, n) } else { game.save.take(id, n) } }
            if let (k, l) = r.toolUpgrade { game.save.tools[k.rawValue] = l } else { game.save.add(r.output) }
            game.save.persist()
            feedback.text = r.toolUpgrade != nil ? "FORGED A \(r.name.uppercased())! IT'S IN YOUR HANDS NOW." : "MADE \(r.name.uppercased())! (YOU HAVE \(game.save.count(r.output)))"
            feedback.textColor = PColor(0x2E8A2A)
            Sound.play(station == .stove ? "Purr" : "Glass", volume: 0.4)
            rebuild()
        case Key.esc:
            if station == .welder {
                Game.shared.mapScene.placeAt(Game.shared.mapScene.world.building(.shed).door)
                Game.shared.showMap()
            } else {
                Game.shared.showHouse()
            }
        default: break
        }
    }
}

// MARK: - Backpack

final class InventoryScene: BaseScene {
    private let returnTo: SKScene?
    private var selected = 0
    private let content = SKNode()
    private let feedback = inkLabel("", scale: 3)
    private var built = false

    init(returnTo: SKScene?) {
        self.returnTo = returnTo
        super.init(size: Game.sceneSize)
    }

    required init?(coder: NSCoder) { fatalError() }

    private var ids: [String] {
        let s = Game.shared.save
        let order: [GoodCat] = [.food, .dish, .produce, .timber, .ore, .gem, .bar, .seed, .tool]
        return Good.all.filter { s.count($0.id) > 0 }.sorted {
            (order.firstIndex(of: $0.cat)!, $0.name) < (order.firstIndex(of: $1.cat)!, $1.name)
        }.map { $0.id }
    }

    override func sceneDidAppear() {
        guard !built else { return }
        built = true
        backgroundColor = PColor(0x2A1408).ns
        let paper = panelSprite(1264, 788, scale: 4)
        paper.position = CGPoint(x: 640, y: 400)
        addChild(paper)
        let title = inkLabel("BACKPACK", scale: 5)
        title.position = CGPoint(x: 640, y: 746)
        addChild(title)
        addChild(content)
        feedback.position = CGPoint(x: 640, y: 92)
        addChild(feedback)
        let help = inkLabel("ARROWS: CHOOSE   SPACE: EAT (FOOD RESTORES ENERGY)   ESC / I: BACK", scale: 2, color: PColor(0x9A6A3A))
        help.position = CGPoint(x: 640, y: 44)
        addChild(help)
        rebuild()
    }

    private func rebuild() {
        content.removeAllChildren()
        let s = Game.shared.save
        let list = ids
        selected = max(0, min(selected, list.count - 1))
        let stats = inkLabel("ENERGY \(s.energy)/\(Energy.max)   ·   FISH \(s.cooler.count) IN COOLER, \(s.chest.count) IN CHESTS   ·   \(s.coins)G", scale: 2, color: PColor(0x7A5A3A))
        stats.position = CGPoint(x: 640, y: 700)
        content.addChild(stats)
        if list.isEmpty {
            let e = inkLabel("EMPTY! CHOP TREES, MINE ROCKS,\nFARM CROPS AND COOK FISH.", scale: 4, color: PColor(0x9A7A5A))
            e.position = CGPoint(x: 640, y: 400)
            content.addChild(e)
            return
        }
        for (i, id) in list.enumerated() {
            let g = Good.byID[id]!
            let col = i % 8, row = i / 8
            let card = panelSprite(140, 118, scale: 2, style: i == selected ? .slotLit : .slot)
            card.position = CGPoint(x: 150 + CGFloat(col) * 140, y: 610 - CGFloat(row) * 126)
            content.addChild(card)
            let icon = pixelSprite(GoodArt.icon(id), scale: 3)
            icon.position = CGPoint(x: 0, y: 22)
            card.addChild(icon)
            let n = inkLabel(PixelFont.wrap(g.name.uppercased(), maxWidth: 60), scale: 1.5)
            n.position = CGPoint(x: 0, y: -18)
            card.addChild(n)
            let c = inkLabel("×\(s.count(id))", scale: 2, color: PColor(0x2A64C8))
            c.position = CGPoint(x: 0, y: -42)
            card.addChild(c)
        }
        let g = Good.byID[list[selected]]!
        var d = g.name.uppercased()
        if g.sellable { d += "  ·  STORE PAYS ~\(Good.price(g.id, day: s.day))G" }
        if g.energy > 0 { d += "  ·  EAT FOR +\(g.energy) ENERGY" }
        let detail = panelSprite(1100, 60, scale: 2, style: .dark)
        detail.position = CGPoint(x: 640, y: 150)
        detail.addChild(PixelLabel(d, scale: 2, color: .gold))
        content.addChild(detail)
    }

    override func keyPressed(_ key: UInt16) {
        let n = ids.count
        switch key {
        case Key.left, Key.a: selected = max(0, selected - 1); rebuild()
        case Key.right, Key.d: selected = min(max(0, n - 1), selected + 1); rebuild()
        case Key.up, Key.w: selected = max(0, selected - 8); rebuild()
        case Key.down, Key.s: selected = min(max(0, n - 1), selected + 8); rebuild()
        case Key.space, Key.ret, Key.enter:
            guard n > 0 else { return }
            let id = ids[selected]
            let gained = Game.shared.save.eat(id)
            if gained > 0 {
                feedback.text = "YUM! +\(gained) ENERGY"
                feedback.textColor = PColor(0x2E8A2A)
                Sound.play("Purr", volume: 0.4)
            } else {
                feedback.text = Game.shared.save.energy >= Energy.max && (Good.byID[id]?.energy ?? 0) > 0 ? "YOU'RE ALREADY FULL OF ENERGY!" : "YOU CAN'T EAT THAT!"
                feedback.textColor = PColor(0xC8281A)
                Sound.play("Funk", volume: 0.3)
            }
            rebuild()
        case Key.esc, Key.i:
            if let r = returnTo { Game.shared.presentScene(r) } else { Game.shared.showMap() }
        default: break
        }
    }
}
