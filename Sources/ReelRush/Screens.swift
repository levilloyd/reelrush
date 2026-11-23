import SpriteKit

// MARK: - Title

final class TitleScene: BaseScene {
    private var built = false
    private var slot = 0
    private let slotsNode = SKNode()
    private let nameNode = SKNode()
    private var naming = false
    private var nameText = ""
    private var deleteArmed = false
    private var spawnTimer = 0.0
    private var lastTime: TimeInterval = 0
    private let waterY = 88

    override func sceneDidAppear() {
        lastTime = 0
        guard !built else { return }
        built = true

        let bg = pixelSprite(Tex.get("title.bg") { paint() }, scale: 4)
        bg.anchorPoint = .zero
        bg.zPosition = -10
        addChild(bg)

        for i in 0..<3 {
            let c = pixelSprite(Tex.get("title.cloud|\(i)") {
                Icons.cloudBuffer(48 + i * 6, 16, seed: i + 30, base: PColor(0xFFE8E0), shade: PColor(0xF2B8A8))
            }, scale: 4)
            c.position = CGPoint(x: CGFloat(i) * 480 + 80, y: CGFloat(640 + i * 28))
            c.zPosition = -9
            addChild(c)
            c.run(.repeatForever(.sequence([.moveBy(x: 1500, y: 0, duration: Double(70 + i * 20)), .moveBy(x: -1500, y: 0, duration: 0)])))
        }

        let boat = BoatNode(kind: .row, scale: 4)
        boat.position = CGPoint(x: 900, y: CGFloat(waterY) * 4 + 30)
        boat.zPosition = -5
        addChild(boat)
        boat.run(.repeatForever(.sequence([.moveBy(x: 0, y: 4, duration: 0.8), .moveBy(x: 0, y: -4, duration: 0.8)])))

        let title = PixelLabel("REEL RUSH", scale: 15, color: .gold, shadow: PColor(0x5A2A0A))
        title.position = CGPoint(x: 640, y: 580)
        addChild(title)
        title.run(.repeatForever(.sequence([.moveBy(x: 0, y: 8, duration: 1), .moveBy(x: 0, y: -8, duration: 1)])))
        let credit = PixelLabel("DESIGNED BY HENRY LLOYD", scale: 3, color: PColor(0xFFD9A0), shadow: PColor(0x5A2A0A))
        credit.position = CGPoint(x: 640, y: 490)
        addChild(credit)
        let sub = PixelLabel("AN ARCADE FISHING ADVENTURE", scale: 4, color: PColor(0xFFF4E0), shadow: PColor(0x5A2A0A))
        sub.position = CGPoint(x: 640, y: 440)
        addChild(sub)

        addChild(slotsNode)
        nameNode.zPosition = 50
        nameNode.isHidden = true
        addChild(nameNode)
        buildSlots()

        let controls = PixelLabel("←→: CHOOSE EXCURSION   SPACE: PLAY / NEW GAME   X: DELETE", scale: 2)
        controls.position = CGPoint(x: 640, y: 36)
        addChild(controls)

        for _ in 0..<5 { spawnFish(randomX: true) }
    }

    private func paint() -> PixelBuffer {
        let b = PixelBuffer(320, 200)
        let wy = waterY
        let bayer = [[0, 2], [3, 1]]
        func gradient(_ y0: Int, _ y1: Int, _ from: PColor, _ to: PColor) {
            for y in y0..<y1 {
                let t = Double(y - y0) / Double(y1 - y0 - 1), q = t * 9, lo = floor(q)
                for x in 0..<320 {
                    let thr = (Double(bayer[y % 2][x % 2]) + 0.5) / 4
                    b[x, y] = from.mix(to, (q - lo > thr ? lo + 1 : lo) / 9)
                }
            }
        }
        gradient(wy, 200, PColor(0xFFB07A), PColor(0x5A4A9A))
        b.ellipse(160, Double(wy) + 18, 26, 26, PColor(0xFFE08A))
        b.ellipse(160, Double(wy) + 18, 22, 22, PColor(0xFFF0B0))
        b.ellipse(40, Double(wy), 70, 14, PColor(0x6A4A7A))
        b.ellipse(290, Double(wy), 60, 18, PColor(0x5A3E6E))
        gradient(0, wy, PColor(0x0E2A5A), PColor(0x3A7AB8))
        for k in 0..<12 {
            let w = 40 - k * 3
            if w > 0 { b.rect(160 - w / 2 + Int(hrand(k, 1) * 6) - 3, wy - 2 - k * 3, w, 1, PColor(0xFFE08A, 170)) }
        }
        b.rect(0, wy - 1, 320, 1, PColor(0x8AC0F0))
        for i in 0..<40 {
            let x = Int(hrand(i, 2) * 320), y = wy - 4 - Int(hrand(i, 3) * 60)
            b.rect(x, y, 3 + Int(hrand(i, 4) * 5), 1, PColor(0x6AA8E0, 160))
        }
        for i in 0..<14 {
            let x0 = Int(hrand(i, 5) * 320), h = 8 + Int(hrand(i, 6) * 18)
            for y in 0..<h { b.set(x0 + Int(sin(Double(y) * 0.3 + Double(i)) * 1.5), y, PColor(0x1E4A3A)) }
        }
        return b
    }

    private func spawnFish(randomX: Bool = false) {
        let s = FishSpecies.all.randomElement()!
        let n = pixelSprite(FishPixel.texture(s, length: Int.random(in: 18...30)), scale: 4)
        let fromLeft = Bool.random()
        n.xScale = fromLeft ? 1 : -1
        let startX: CGFloat = randomX ? CGFloat.random(in: 0...1280) : (fromLeft ? -150 : 1430)
        n.position = CGPoint(x: startX, y: snap(CGFloat.random(in: 40...300), 4))
        n.zPosition = -6
        addChild(n)
        let endX: CGFloat = fromLeft ? 1430 : -150
        n.run(.sequence([.moveTo(x: endX, duration: Double(abs(endX - startX)) / Double.random(in: 60...130)), .removeFromParent()]))
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = lastTime == 0 ? 0 : min(1.0 / 30, currentTime - lastTime)
        lastTime = currentTime
        spawnTimer -= dt
        if spawnTimer <= 0 {
            spawnTimer = Double.random(in: 0.8...1.8)
            spawnFish()
        }
    }

    private func buildSlots() {
        slotsNode.removeAllChildren()
        for i in 0..<3 {
            let save = SaveData.peek(i + 1)
            let card = panelSprite(360, 190, scale: 3, style: i == slot ? .parchment : .slot)
            card.position = CGPoint(x: 640 + CGFloat(i - 1) * 390, y: 250)
            if i == slot { card.setScale(1.05) }
            slotsNode.addChild(card)
            let head = inkLabel("EXCURSION \(i + 1)", scale: 2, color: PColor(0x9A6A3A))
            head.position = CGPoint(x: 0, y: 64)
            card.addChild(head)
            if let s = save {
                let n = inkLabel(s.playerName, scale: 4)
                n.position = CGPoint(x: 0, y: 30)
                card.addChild(n)
                var lines = ["\(GameCalendar.label(s.day)) · YEAR \(GameCalendar.year(s.day))", "\(s.coins)G · \(s.speciesCaught)/\(FishSpecies.all.count) FISH"]
                if let sp = s.spouseVillager { lines.append("MARRIED TO \(sp.name.uppercased())" + (s.kids.isEmpty ? "" : " · \(s.kids.count) KID\(s.kids.count == 1 ? "" : "S")")) }
                for (j, l) in lines.enumerated() {
                    let t = inkLabel(l, scale: 2)
                    t.position = CGPoint(x: 0, y: -6 - CGFloat(j) * 22)
                    card.addChild(t)
                }
            } else {
                let e = inkLabel("EMPTY\nSTART A NEW\nEXCURSION", scale: 3, color: PColor(0x9A7A5A))
                e.position = CGPoint(x: 0, y: 0)
                card.addChild(e)
            }
            if i == slot && deleteArmed {
                let w = inkLabel("PRESS X AGAIN TO DELETE!", scale: 2, color: PColor(0xC8281A))
                w.position = CGPoint(x: 0, y: -70)
                card.addChild(w)
            }
        }
    }

    private func showNaming() {
        naming = true
        nameText = ""
        nameNode.isHidden = false
        refreshName()
    }

    private func refreshName() {
        nameNode.removeAllChildren()
        nameNode.addChild(panelSprite(760, 260, scale: 4))
        nameNode.position = CGPoint(x: 640, y: 330)
        let q = inkLabel("NEW EXCURSION \(slot + 1): WHAT'S YOUR NAME, ANGLER?", scale: 3)
        q.position = CGPoint(x: 0, y: 70)
        nameNode.addChild(q)
        let box = panelSprite(520, 70, scale: 2, style: .slotLit)
        box.position = CGPoint(x: 0, y: 0)
        nameNode.addChild(box)
        let t = inkLabel(nameText + "_", scale: 5)
        t.position = CGPoint(x: 0, y: 0)
        nameNode.addChild(t)
        let h = inkLabel("TYPE A NAME · ENTER: START · ESC: CANCEL", scale: 2, color: PColor(0x9A6A3A))
        h.position = CGPoint(x: 0, y: -70)
        nameNode.addChild(h)
    }

    override func typed(_ text: String) {
        guard naming else { return }
        for ch in text.uppercased() where (ch.isLetter || ch.isNumber || ch == " ") && ch.isASCII && nameText.count < 12 {
            nameText.append(ch)
        }
        refreshName()
    }

    override func keyPressed(_ key: UInt16) {
        if naming {
            switch key {
            case Key.backspace: if !nameText.isEmpty { nameText.removeLast(); refreshName() }
            case Key.ret, Key.enter:
                let name = nameText.trimmingCharacters(in: .whitespaces)
                Game.shared.newGame(slot: slot + 1, name: name.isEmpty ? "FISHER" : name)
                Sound.play("Hero", volume: 0.4)
                Game.shared.showMap()
            case Key.esc: naming = false; nameNode.isHidden = true
            default: break
            }
            return
        }
        switch key {
        case Key.left, Key.a: slot = max(0, slot - 1); deleteArmed = false; buildSlots(); Sound.play("Tink", volume: 0.3)
        case Key.right, Key.d: slot = min(2, slot + 1); deleteArmed = false; buildSlots(); Sound.play("Tink", volume: 0.3)
        case Key.x:
            guard SaveData.peek(slot + 1) != nil else { return }
            if deleteArmed {
                SaveData.delete(slot + 1)
                deleteArmed = false
                Sound.play("Basso", volume: 0.3)
            } else {
                deleteArmed = true
            }
            buildSlots()
        case Key.space, Key.ret, Key.enter: start()
        default: break
        }
    }

    override func primaryPressed() { start() }

    private func start() {
        guard !naming else { return }
        Sound.play("Pop")
        if SaveData.peek(slot + 1) != nil {
            Game.shared.loadSlot(slot + 1)
            Game.shared.mapScene.placeAtHome()
            Game.shared.showMap()
        } else {
            showNaming()
        }
    }
}

// MARK: - Journal

final class JournalScene: BaseScene {
    private var page = 0
    private let content = SKNode()
    private var built = false

    override func sceneDidAppear() {
        guard !built else { return }
        built = true
        backgroundColor = PColor(0x2A1408).ns
        let paper = panelSprite(1264, 788, scale: 4)
        paper.position = CGPoint(x: 640, y: 400)
        addChild(paper)
        addChild(content)
        rebuild()
    }

    private func rebuild() {
        content.removeAllChildren()
        let save = Game.shared.save
        let pages = (Habitat.allCases.count + 3) / 4
        let title = inkLabel("FISH JOURNAL  ·  PAGE \(page + 1)/\(pages)", scale: 5)
        title.position = CGPoint(x: 640, y: 748)
        content.addChild(title)
        let season = save.season

        for (row, h) in Habitat.allCases[(page * 4)..<min(Habitat.allCases.count, page * 4 + 4)].enumerated() {
            let y = 618 - CGFloat(row) * 150
            let hl = inkLabel(PixelFont.wrap(h.displayName.uppercased(), maxWidth: 80), scale: 2, align: .left)
            hl.position = CGPoint(x: 40, y: y + 20)
            content.addChild(hl)
            let sl = inkLabel(PixelFont.wrap(h.spotName.uppercased(), maxWidth: 80), scale: 2, color: PColor(0x9A6A3A), align: .left)
            sl.position = CGPoint(x: 40, y: y - 20)
            content.addChild(sl)

            let species = FishSpecies.inHabitat(h)
            // Up to 8 cells fit at full size; squeeze rows with more (e.g. once sharks join).
            let step: CGFloat = species.count > 8 ? 890 / CGFloat(species.count - 1) : 126
            for (i, s) in species.enumerated() {
                let rec = save.records[s.id]
                let caught = (rec?.count ?? 0) > 0
                let cell = panelSprite(120, 140, scale: 2, style: caught ? .slotLit : .slot)
                cell.position = CGPoint(x: 290 + CGFloat(i) * step, y: y)
                if step < 126 { cell.setScale(snap((step - 6) / 120 * 20, 1) / 20) }
                content.addChild(cell)
                let len = (s.shape == .round || s.shape == .tall || s.shape == .angler) ? 15 : 22
                let art = pixelSprite(FishPixel.texture(s, length: len, silhouette: caught ? nil : PColor(0x6A4A2A, 150)), scale: 2)
                art.position = CGPoint(x: 0, y: 40)
                cell.addChild(art)
                let name = inkLabel(caught ? PixelFont.wrap(s.name.uppercased(), maxWidth: 72) : "???", scale: 1.5,
                                    color: caught ? .ink : PColor(0x9A7A5A))
                name.position = CGPoint(x: 0, y: 2)
                cell.addChild(name)
                let line1: String, line2: String
                if let r = rec, caught {
                    line1 = "×\(r.count)  ·  \(formatSize(r.best))"
                    line2 = s.feeding.label
                } else {
                    line1 = s.rarity.name.uppercased()
                    line2 = s.isShark ? "SALT ROD" : s.feeding.label + (s.rainOnly ? "+RAIN" : "")
                }
                for (j, t) in [line1, line2, s.seasonLabel].enumerated() {
                    var col = j == 0 && !caught ? s.rarity.inkColor : PColor(0x7A5A3A)
                    if j == 2 { col = s.seasons.contains(season) ? PColor(0x2E8A2A) : PColor(0xA08A70) }
                    let l = inkLabel(PixelFont.wrap(t, maxWidth: 74), scale: 1.5, color: col)
                    l.position = CGPoint(x: 0, y: -26 - CGFloat(j) * 16)
                    cell.addChild(l)
                }
            }
        }
        let summary = inkLabel("SPECIES \(save.speciesCaught)/\(FishSpecies.all.count)   ·   FISH CAUGHT \(save.totalCaught)   ·   GREEN = IN SEASON NOW (\(season.name.uppercased()))", scale: 2)
        summary.position = CGPoint(x: 640, y: 46)
        content.addChild(summary)
        let back = inkLabel("←→: PAGE   ESC: BACK", scale: 2, color: PColor(0x9A6A3A), align: .right)
        back.position = CGPoint(x: 1236, y: 712)
        content.addChild(back)
    }

    override func keyPressed(_ key: UInt16) {
        switch key {
        case Key.left, Key.a:
            let pages = (Habitat.allCases.count + 3) / 4
            page = (page + pages - 1) % pages
            Sound.play("Tink", volume: 0.3)
            rebuild()
        case Key.right, Key.d, Key.tab:
            page = (page + 1) % ((Habitat.allCases.count + 3) / 4)
            Sound.play("Tink", volume: 0.3)
            rebuild()
        case Key.esc, Key.j, Key.space:
            Game.shared.showMap()
        default: break
        }
    }
}

// MARK: - Shops

enum ShopKind { case tackle, boutique, market, hardware, homeGoods, autos }

final class ShopScene: BaseScene {
    private enum Tab { case sellFish, rods, boats, lures, bait, clothes, sellProduce, seeds, food, sellGoods, tools, home, decor, cars, trailers, charters }

    private struct Card {
        let title: String
        let icon: SKTexture
        let status: String
        let statusColor: PColor
        let detail: String
        let action: () -> (String, Bool)?
    }

    let kind: ShopKind
    private let tabs: [Tab]
    private var tab: Tab
    private var selected = 0
    private var fishSource = 0  // 0 cooler, 1 chests, 2 fridge, 3 freezer
    private var fishSources: [Int] { [0, 1] + (Game.shared.save.hasFridge ? [2] : []) + (Game.shared.save.hasFreezer ? [3] : []) }
    private func fishList(_ s: SaveData) -> [CaughtFish] { [s.cooler, s.chest, s.fridgeFish, s.freezer][fishSource] }
    private var sourceName: String { ["COOLER", "CHESTS", "FRIDGE", "FREEZER"][fishSource] }
    private let content = SKNode()
    private let tabsNode = SKNode()
    private let coinLabel = inkLabel("", scale: 3, align: .left)
    private let feedback = inkLabel("", scale: 3)
    private let help = inkLabel("", scale: 2, color: PColor(0x9A6A3A))
    private var built = false

    init(kind: ShopKind) {
        self.kind = kind
        switch kind {
        case .tackle: tabs = [.sellFish, .rods, .boats, .lures, .bait, .charters]
        case .boutique: tabs = [.clothes]
        case .market: tabs = [.sellProduce, .seeds, .food]
        case .hardware: tabs = [.sellGoods, .tools]
        case .homeGoods: tabs = [.home, .decor]
        case .autos: tabs = [.cars, .trailers]
        }
        tab = tabs[0]
        super.init(size: Game.sceneSize)
    }

    required init?(coder: NSCoder) { fatalError() }

    private var title: String {
        switch kind {
        case .tackle: return "BAIT & TACKLE"
        case .boutique: return "BOUTIQUE"
        case .market: return "ROSA'S MARKET"
        case .hardware: return "HARDWARE"
        case .homeGoods: return "HOME GOODS"
        case .autos: return "AUTO SHOP"
        }
    }

    private func tabName(_ t: Tab) -> String {
        switch t {
        case .sellFish: return "SELL FISH"
        case .rods: return "RODS"
        case .boats: return "BOATS"
        case .lures: return "LURES"
        case .bait: return "BAIT"
        case .clothes: return "CLOTHES"
        case .sellProduce: return "SELL PRODUCE"
        case .seeds: return "SEEDS"
        case .food: return "FOOD"
        case .sellGoods: return "SELL GOODS"
        case .tools: return "TOOLS"
        case .home: return "STORAGE"
        case .decor: return "DECOR"
        case .cars: return "CARS"
        case .trailers: return "TRAILERS"
        case .charters: return "CHARTERS"
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
        t.position = CGPoint(x: 560, y: 746)
        addChild(t)
        let coin = pixelSprite(Icons.coin(), scale: 3)
        coin.position = CGPoint(x: 1010, y: 746)
        addChild(coin)
        coinLabel.position = CGPoint(x: 1030, y: 746)
        addChild(coinLabel)
        addChild(tabsNode)
        addChild(content)
        feedback.position = CGPoint(x: 640, y: 86)
        addChild(feedback)
        help.position = CGPoint(x: 640, y: 44)
        addChild(help)
        if kind == .tackle && Game.shared.save.cooler.isEmpty && Game.shared.save.chest.isEmpty { tab = .bait }
        rebuild()
    }

    // MARK: Data

    private var clothes: [GearItem] { GearItem.inSlot(.hat) + GearItem.inSlot(.shirt) + GearItem.inSlot(.pants) }

    private var sellCats: Set<GoodCat> { tab == .sellProduce ? [.produce, .dish, .food] : [.timber, .ore, .gem, .bar] }

    private func sellRows() -> [(id: String, name: String, count: Int, price: Int, mult: Double, icon: SKTexture, color: PColor)] {
        let s = Game.shared.save
        if tab == .sellFish {
            var g: [String: (Int, Int)] = [:]
            for c in fishList(s) {
                let v = g[c.id] ?? (0, 0)
                g[c.id] = (v.0 + 1, v.1 + Market.price(c, day: s.day, sellBonus: s.sellBonus))
            }
            return g.compactMap { id, v in
                guard let sp = FishSpecies.byID[id] else { return nil }
                return (id, sp.name, v.0, v.1, Market.multiplier(sp, day: s.day), FishPixel.texture(sp, length: 16), sp.rarity.inkColor)
            }.sorted { $0.price > $1.price }
        }
        return Good.all.filter { sellCats.contains($0.cat) && s.count($0.id) > 0 }.map { g in
            let unit = sellPrice(g.id, s)
            return (g.id, g.name, s.count(g.id), unit * s.count(g.id), Double(unit) / Double(max(1, g.price)), GoodArt.icon(g.id), PColor.ink)
        }.sorted { $0.price > $1.price }
    }

    private func sellPrice(_ id: String, _ s: SaveData) -> Int {
        let p = Good.price(id, day: s.day)
        return Good.byID[id]?.cat == .food ? p / 2 : p
    }

    static let fishFinderPrice = 1200

    private func fishFinderCard(_ s: SaveData) -> Card {
        let price = Self.fishFinderPrice
        let icon = Tex.get("icon.fishfinder") {
            let b = PixelBuffer(18, 18)
            b.rect(2, 3, 14, 12, PColor(0x2A2E34))
            b.ellipse(9, 9, 5, 5, PColor(0x0A3A1E))
            b.line(9, 9, 13, 12, PColor(0x5AF28A))
            b.set(6, 7, PColor(0xFFE05A)); b.set(11, 6, PColor(0xFFE05A))
            b.rect(7, 1, 4, 2, PColor(0x4A4E56))
            b.outline(PColor(0x14161A))
            return b
        }
        return Card(title: "Fish Finder", icon: icon, status: s.fishFinder ? "INSTALLED" : "\(price)G",
                    statusColor: s.fishFinder ? PColor(0x2E8A2A) : (s.coins >= price ? PColor(0x9A6010) : PColor(0xC8281A)),
                    detail: "SONAR FOR ALL YOUR BOATS · SHOWS FISH SCHOOLS AROUND YOU WHILE YOU DRIVE, PLUS DISTANCE AND DIRECTION TO THE NEAREST ONE") {
            let game = Game.shared
            guard !game.save.fishFinder else { return ("YOUR BOATS ALREADY HAVE A FISH FINDER.", false) }
            guard game.save.coins >= price else { return ("NEED \(price - game.save.coins)G MORE!", false) }
            game.save.coins -= price
            game.save.fishFinder = true
            return ("FISH FINDER INSTALLED! LAUNCH A BOAT TO SEE IT.", true)
        }
    }

    private func cards() -> [Card] {
        let s = Game.shared.save
        switch tab {
        case .lures: return GearItem.inSlot(.lure).map { gearCard($0, s) }
        case .bait: return GearItem.inSlot(.bait).map { gearCard($0, s) }
        case .clothes:
            let pendant = Card(title: "Promise Pendant", icon: GoodArt.icon(Romance.pendant), status: "\(Romance.pendantPrice)G",
                               statusColor: s.coins >= Romance.pendantPrice ? PColor(0x9A6010) : PColor(0xC8281A),
                               detail: "GIVE IT TO SOMEONE WITH \(Romance.proposeHearts)+ HEARTS TO PROPOSE (TALK, THEN P)" + (s.count(Romance.pendant) > 0 ? " · YOU HAVE ONE" : "")) {
                let game = Game.shared
                guard game.save.coins >= Romance.pendantPrice else { return ("NEED \(Romance.pendantPrice - game.save.coins)G MORE!", false) }
                game.save.coins -= Romance.pendantPrice
                game.save.add(Romance.pendant)
                return ("BOUGHT A PROMISE PENDANT. GOOD LUCK!", true)
            }
            return clothes.map { gearCard($0, s) } + [pendant]
        case .rods:
            return Rod.all.enumerated().map { i, rod in
                let owned = s.rodsOwned.contains(i), on = s.rodLevel == i
                let icon = Tex.get("rodicon|\(i)") {
                    let b = PixelBuffer(18, 18)
                    b.line(2, 2, 16, 16, PColor(rod.color), thick: 2); b.line(2, 2, 5, 5, PColor(0x3A2A1A), thick: 2)
                    b.ellipse(5, 3, 2, 2, PColor(0x3A3E46)); b.outline(PColor(0x2A1408))
                    return b
                }
                return Card(title: rod.name, icon: icon, status: on ? "EQUIPPED" : (owned ? "OWNED" : "\(rod.price)G"),
                            statusColor: on ? PColor(0x2E8A2A) : (owned ? PColor(0x9A7A5A) : (s.coins >= rod.price ? PColor(0x9A6010) : PColor(0xC8281A))),
                            detail: "\(rod.specialtyLabel) · ZONE \(Int(rod.barSize * 100)) · REEL \(String(format: "%.2f", rod.reelSpeed))X · LUCK +\(Int(rod.luck * 100))%"
                                + (rod.specialty != nil ? " · STRONG IN ITS WATERS, WEAKER ELSEWHERE" : "")) {
                    let game = Game.shared
                    if !game.save.rodsOwned.contains(i) {
                        guard game.save.coins >= rod.price else { return ("NEED \(rod.price - game.save.coins)G MORE!", false) }
                        game.save.coins -= rod.price
                        game.save.rodsOwned.append(i)
                    }
                    game.save.rodLevel = i
                    return ("\(rod.name.uppercased()) EQUIPPED!", true)
                }
            }
        case .boats:
            return Boat.all.map { b in
                let owned = s.boatsOwned.contains(b.id)
                return Card(title: b.name, icon: BoatArt.side(b.kind, front: true), status: owned ? "OWNED" : "\(b.price)G",
                            statusColor: owned ? PColor(0x2E8A2A) : (s.coins >= b.price ? PColor(0x9A6010) : PColor(0xC8281A)),
                            detail: "\(b.watersLabel.uppercased()) · +\(Int(b.sizeBonus * 100))% SIZE · \(Int(b.extraChance * 100))% BONUS · COOLER \(b.capacity) · \(b.big ? "BIG: TRUCK + BIG TRAILER" : "SMALL TRAILER")") {
                    let game = Game.shared
                    guard !game.save.boatsOwned.contains(b.id) else { return ("ALREADY IN YOUR BOAT SHED.", false) }
                    guard game.save.boatShedBuilt else { return ("BUILD YOUR BOAT SHED FIRST (\(Construction.costLabel(.boatShed))).", false) }
                    guard game.save.coins >= b.price else { return ("NEED \(b.price - game.save.coins)G MORE!", false) }
                    game.save.coins -= b.price
                    game.save.boatsOwned.append(b.id)
                    if game.save.hitched == nil { game.save.hitched = b.id }
                    return ("THE \(b.name.uppercased()) IS IN YOUR BOAT SHED AT HOME!", true)
                }
            } + [fishFinderCard(s)]
        case .charters:
            let hasBoat = s.boatsOwned.contains { Boat.byID[$0]?.charter == true }
            return Charter.offers(day: s.day).map { ch in
                let active = s.charter?.client == ch.client && s.charter?.day == ch.day
                let icon = FishPixel.texture(FishSpecies.inHabitat(ch.water)[1], length: 16)
                return Card(title: ch.client.capitalized, icon: icon,
                            status: active ? "IN PROGRESS \(s.charter!.caught)/\(ch.target)" : "\(ch.perFish)G/FISH",
                            statusColor: active ? PColor(0x2E8A2A) : PColor(0x9A6010),
                            detail: "CATCH \(ch.target) FISH AT \(ch.water.spotName.uppercased()) FROM A CHARTER BOAT TODAY · \(ch.perFish)G EACH + \(ch.bonus)G BONUS · CLIENTS KEEP THE FISH") {
                    let game = Game.shared
                    guard hasBoat else { return ("YOU NEED A CHARTER BOAT: PONTOON, TRAWLER OR YACHT.", false) }
                    guard game.save.charter == nil else { return ("YOU'RE ALREADY RUNNING A CHARTER TODAY.", false) }
                    game.save.charter = ch
                    return ("CHARTER BOOKED! TOW YOUR BOAT TO \(ch.water.spotName.uppercased()).", true)
                }
            }
        case .cars:
            return Car.all.map { c in
                let owned = s.carsOwned.contains(c.id), on = s.car == c.id
                return Card(title: c.name, icon: CarArt.side(c), status: on ? "YOUR RIDE" : (owned ? "OWNED" : "\(c.price)G"),
                            statusColor: on ? PColor(0x2E8A2A) : (owned ? PColor(0x9A7A5A) : (s.coins >= c.price ? PColor(0x9A6010) : PColor(0xC8281A))),
                            detail: c.blurb.uppercased() + " · PRESS C NEAR IT TO DRIVE") {
                    let game = Game.shared
                    if !game.save.carsOwned.contains(c.id) {
                        guard game.save.garageBuilt else { return ("BUILD YOUR GARAGE FIRST (\(Construction.costLabel(.garage))).", false) }
                        guard game.save.coins >= c.price else { return ("NEED \(c.price - game.save.coins)G MORE!", false) }
                        game.save.coins -= c.price
                        game.save.carsOwned.append(c.id)
                    }
                    game.save.car = c.id
                    return ("THE \(c.name.uppercased()) IS PARKED AT YOUR GARAGE!", true)
                }
            }
        case .trailers:
            return Trailer.all.map { t in
                let owned = s.trailers.contains(t.id)
                return Card(title: t.name, icon: CarArt.trailer(t.size == 2), status: owned ? "OWNED" : "\(t.price)G",
                            statusColor: owned ? PColor(0x2E8A2A) : (s.coins >= t.price ? PColor(0x9A6010) : PColor(0xC8281A)),
                            detail: t.size == 2 ? "CARRIES ANY BOAT (NEEDS THE BIG TRUCK FOR BIG BOATS)" : "CARRIES KAYAKS, ROWBOATS, SKIFFS & BASS BOATS") {
                    let game = Game.shared
                    guard !game.save.trailers.contains(t.id) else { return ("ALREADY OWNED.", false) }
                    guard game.save.coins >= t.price else { return ("NEED \(t.price - game.save.coins)G MORE!", false) }
                    game.save.coins -= t.price
                    game.save.trailers.append(t.id)
                    return ("BOUGHT THE \(t.name.uppercased())!", true)
                }
            }
        case .seeds:
            return Crop.all.map { c in
                let inSeason = c.seasons.contains(s.season)
                let seasons = Season.allCases.filter { c.seasons.contains($0) }.map { ["SPR", "SUM", "FALL", "WIN"][$0.rawValue] }.joined(separator: "/")
                return Card(title: c.name, icon: GoodArt.icon(c.seedID), status: "\(c.seedPrice * 5)G ×5", statusColor: s.coins >= c.seedPrice * 5 ? PColor(0x9A6010) : PColor(0xC8281A),
                            detail: "\(seasons) · \(c.days) DAYS TO GROW · SELLS ~\(c.sell)G" + (inSeason ? "" : " · OUT OF SEASON - IT WILL WITHER!") + (s.count(c.seedID) > 0 ? " · YOU HAVE \(s.count(c.seedID))" : "")) {
                    let game = Game.shared
                    guard game.save.coins >= c.seedPrice * 5 else { return ("NEED \(c.seedPrice * 5 - game.save.coins)G MORE!", false) }
                    game.save.coins -= c.seedPrice * 5
                    game.save.add(c.seedID, 5)
                    return ("BOUGHT 5 \(c.name.uppercased()) SEEDS! PLANT THEM ON YOUR FARM.", true)
                }
            }
        case .food:
            return Good.all.filter { $0.cat == .food }.map { g in
                Card(title: g.name, icon: GoodArt.icon(g.id), status: "\(g.price)G", statusColor: s.coins >= g.price ? PColor(0x9A6010) : PColor(0xC8281A),
                     detail: "EAT FOR +\(g.energy) ENERGY (FROM YOUR BACKPACK)" + (s.count(g.id) > 0 ? " · YOU HAVE \(s.count(g.id))" : "")) {
                    let game = Game.shared
                    guard game.save.coins >= g.price else { return ("NEED \(g.price - game.save.coins)G MORE!", false) }
                    game.save.coins -= g.price
                    game.save.add(g.id)
                    return ("BOUGHT \(g.name.uppercased())!", true)
                }
            }
        case .tools:
            var list: [Card] = ToolKind.allCases.map { k in
                let lvl = Tools.level(k, s)
                let maxed = lvl >= Tools.tiers.count - 1
                let next = min(lvl + 1, Tools.tiers.count - 1)
                return Card(title: "\(Tools.tiers[lvl]) \(k.name)", icon: ToolArt.icon(k, level: lvl),
                            status: maxed ? "MAXED" : "UPGRADE \(Tools.prices[next])G", statusColor: maxed ? PColor(0x2E8A2A) : (s.coins >= Tools.prices[next] ? PColor(0x9A6010) : PColor(0xC8281A)),
                            detail: maxed ? "BEST \(k.name.uppercased()) THERE IS: \(Tools.perks(k, lvl))" : "NOW: \(Tools.perks(k, lvl))  →  \(Tools.tiers[next].uppercased()): \(Tools.perks(k, next))") {
                    let game = Game.shared
                    guard !maxed else { return ("ALREADY THE BEST!", false) }
                    guard game.save.coins >= Tools.prices[next] else { return ("NEED \(Tools.prices[next] - game.save.coins)G MORE!", false) }
                    game.save.coins -= Tools.prices[next]
                    game.save.tools[k.rawValue] = next
                    return ("UPGRADED TO A \(Tools.tiers[next].uppercased()) \(k.name.uppercased())!", true)
                }
            }
            let w = Good.byID["tool.welder"]!
            list.append(Card(title: "Welding Machine", icon: GoodArt.icon(w.id), status: s.hasWelder ? "OWNED" : "\(w.price)G",
                             statusColor: s.hasWelder ? PColor(0x2E8A2A) : (s.coins >= w.price ? PColor(0x9A6010) : PColor(0xC8281A)),
                             detail: "INSTALLED IN THE WORKSHOP SHED NEXT TO YOUR HOUSE. WELD ORE + COAL INTO BARS.") {
                let game = Game.shared
                guard !game.save.hasWelder else { return ("YOU ALREADY HAVE ONE AT HOME.", false) }
                guard game.save.coins >= w.price else { return ("NEED \(w.price - game.save.coins)G MORE!", false) }
                game.save.coins -= w.price
                game.save.hasWelder = true
                return ("THE WELDING MACHINE WAS SET UP IN YOUR WORKSHOP SHED!", true)
            })
            return list
        case .decor:
            return Decor.all.map { d in
                let owned = s.owned.contains(d.id)
                return Card(title: d.name, icon: PropArt.decor(d.id), status: owned ? "IN YOUR HOUSE" : "\(d.price)G",
                            statusColor: owned ? PColor(0x2E8A2A) : (s.coins >= d.price ? PColor(0x9A6010) : PColor(0xC8281A)),
                            detail: d.blurb.uppercased() + " · APPEARS IN YOUR HOUSE") {
                    let game = Game.shared
                    guard !owned else { return ("ALREADY IN YOUR HOUSE!", false) }
                    guard game.save.coins >= d.price else { return ("NEED \(d.price - game.save.coins)G MORE!", false) }
                    game.save.coins -= d.price
                    game.save.owned.insert(d.id)
                    return ("THE \(d.name.uppercased()) WAS DELIVERED TO YOUR HOUSE!", true)
                }
            }
        case .home:
            let maxed = s.chests >= SaveData.maxChests
            let appliance: [Card] = [
                Card(title: "Fridge", icon: PropArt.fridge(), status: s.hasFridge ? "OWNED" : "\(Appliance.fridgePrice)G",
                     statusColor: s.hasFridge ? PColor(0x2E8A2A) : (s.coins >= Appliance.fridgePrice ? PColor(0x9A6010) : PColor(0xC8281A)),
                     detail: "HOLDS \(SaveData.fridgeSize) FISH OR PRODUCE · PRODUCE NEVER SPOILS · FISH SPOIL 4X SLOWER") {
                    let game = Game.shared
                    guard !game.save.hasFridge else { return ("YOU ALREADY HAVE A FRIDGE.", false) }
                    guard game.save.coins >= Appliance.fridgePrice else { return ("NEED \(Appliance.fridgePrice - game.save.coins)G MORE!", false) }
                    game.save.coins -= Appliance.fridgePrice
                    game.save.hasFridge = true
                    return ("A FRIDGE WAS INSTALLED IN YOUR KITCHEN!", true)
                },
                Card(title: "Freezer", icon: PropArt.freezer(), status: s.hasFreezer ? "OWNED" : "\(Appliance.freezerPrice)G",
                     statusColor: s.hasFreezer ? PColor(0x2E8A2A) : (s.coins >= Appliance.freezerPrice ? PColor(0x9A6010) : PColor(0xC8281A)),
                     detail: "HOLDS \(SaveData.freezerSize) FISH · FROZEN FISH NEVER LOSE VALUE") {
                    let game = Game.shared
                    guard !game.save.hasFreezer else { return ("YOU ALREADY HAVE A FREEZER.", false) }
                    guard game.save.coins >= Appliance.freezerPrice else { return ("NEED \(Appliance.freezerPrice - game.save.coins)G MORE!", false) }
                    game.save.coins -= Appliance.freezerPrice
                    game.save.hasFreezer = true
                    return ("A FREEZER WAS INSTALLED IN YOUR KITCHEN!", true)
                },
            ]
            let lvl = s.houseLevel
            let expansion: [Card] = lvl >= Romance.houseExpansions.count ? [] : [{
                let e = Romance.houseExpansions[lvl]
                return Card(title: "House Expansion \(lvl + 1)", icon: PropArt.house(), status: "\(e.price)G + \(e.timber) TIMBER",
                            statusColor: s.coins >= e.price && s.count("timber") >= e.timber ? PColor(0x9A6010) : PColor(0xC8281A),
                            detail: "ADDS A KIDS' ROOM WITH 2 MORE BEDS (NOW \(s.kidBeds) BEDS). EACH CHILD NEEDS A BED.") {
                    let game = Game.shared
                    guard game.save.coins >= e.price, game.save.count("timber") >= e.timber else { return ("NEED \(e.price)G AND \(e.timber) TIMBER!", false) }
                    game.save.coins -= e.price
                    game.save.take("timber", e.timber)
                    game.save.houseLevel += 1
                    return ("YOUR HOUSE WAS EXPANDED! \(game.save.kidBeds) KID BEDS.", true)
                }
            }()]
            return appliance + expansion + [Card(title: "Storage Chest", icon: ItemArt.chestIcon(), status: maxed ? "MAXED" : "300G",
                         statusColor: maxed ? PColor(0x2E8A2A) : (s.coins >= 300 ? PColor(0x9A6010) : PColor(0xC8281A)),
                         detail: "+\(SaveData.chestSize) FISH OF STORAGE AT HOME · YOU HAVE \(s.chests)/\(SaveData.maxChests) CHESTS") {
                let game = Game.shared
                guard game.save.chests < SaveData.maxChests else { return ("YOUR HOUSE IS FULL OF CHESTS!", false) }
                guard game.save.coins >= 300 else { return ("NEED \(300 - game.save.coins)G MORE!", false) }
                game.save.coins -= 300
                game.save.chests += 1
                return ("A NEW CHEST WAS DELIVERED TO YOUR HOUSE!", true)
            }]
        default:
            return []
        }
    }

    private func gearCard(_ it: GearItem, _ s: SaveData) -> Card {
        let status: String, col: PColor
        if it.slot == .bait {
            status = "\(it.price)G"; col = s.coins >= it.price ? PColor(0x9A6010) : PColor(0xC8281A)
        } else if s.equipped[it.slot.rawValue] == it.id {
            status = "EQUIPPED"; col = PColor(0x2E8A2A)
        } else if s.owned.contains(it.id) {
            status = "OWNED"; col = PColor(0x9A7A5A)
        } else {
            status = "\(it.price)G"; col = s.coins >= it.price ? PColor(0x9A6010) : PColor(0xC8281A)
        }
        var detail = it.perk.uppercased()
        if it.uses > 0 { detail = "PACK OF \(it.uses) · " + detail + " · YOU HAVE \(s.bait[it.id] ?? 0)" }
        return Card(title: it.name, icon: ItemArt.icon(it), status: status, statusColor: col, detail: detail) {
            let game = Game.shared
            if it.slot != .bait && game.save.owned.contains(it.id) {
                game.save.equipped[it.slot.rawValue] = it.id
                return ("EQUIPPED THE \(it.name.uppercased()).", true)
            }
            guard game.save.coins >= it.price else { return ("NEED \(it.price - game.save.coins)G MORE!", false) }
            game.save.coins -= it.price
            if it.slot == .bait { game.save.bait[it.id, default: 0] += it.uses } else { game.save.owned.insert(it.id) }
            game.save.equipped[it.slot.rawValue] = it.id
            return ("BOUGHT \(it.name.uppercased())! EQUIPPED.", true)
        }
    }

    private var listCount: Int {
        switch tab {
        case .sellFish, .sellProduce, .sellGoods: return sellRows().count
        default: return cards().count
        }
    }

    // MARK: Layout

    private func rebuild() {
        let save = Game.shared.save
        coinLabel.text = "\(save.coins)G"
        selected = max(0, min(selected, listCount - 1))
        tabsNode.removeAllChildren()
        let w: CGFloat = min(280, 1180 / CGFloat(tabs.count))
        for (i, t) in tabs.enumerated() {
            let p = panelSprite(w - 12, 50, scale: 2, style: t == tab ? .slotLit : .slot)
            p.position = CGPoint(x: 640 + (CGFloat(i) - CGFloat(tabs.count - 1) / 2) * w, y: 680)
            p.addChild(inkLabel("\(i + 1) \(tabName(t))", scale: 2, color: t == tab ? .ink : PColor(0x9A7A5A)))
            tabsNode.addChild(p)
        }
        content.removeAllChildren()
        switch tab {
        case .sellFish, .sellProduce, .sellGoods: buildSell(save)
        default: buildCards()
        }
        switch tab {
        case .sellFish: help.text = "C: SWITCH STORAGE   ↑↓: CHOOSE   SPACE: SELL KIND   X: SELL ALL   TAB: NEXT   ESC: LEAVE"
        case .sellProduce, .sellGoods: help.text = "↑↓: CHOOSE   SPACE: SELL KIND   X: SELL ALL   TAB: NEXT   ESC: LEAVE"
        default: help.text = "ARROWS: CHOOSE   SPACE: BUY   TAB / NUMBERS: TABS   ESC: LEAVE"
        }
    }

    private func buildSell(_ save: SaveData) {
        let header: String
        switch tab {
        case .sellFish:
            header = "SELLING FROM: \(sourceName) (\(fishList(save).count))"
                + "  ·  \(save.season.name.uppercased()) FISH PRICES" + (save.sellBonus > 0 ? "  (+\(Int(save.sellBonus * 100))% SUIT)" : "")
        case .sellProduce: header = "WE BUY PRODUCE, DISHES & FOOD  ·  \(save.season.name.uppercased()) PRICES"
        default: header = "WE BUY TIMBER, ORE, GEMS & BARS"
        }
        let h = inkLabel(header, scale: 3)
        h.position = CGPoint(x: 640, y: 618)
        content.addChild(h)
        let rows = sellRows()
        guard !rows.isEmpty else {
            let msg: String
            switch tab {
            case .sellFish: msg = "YOUR \(sourceName) IS EMPTY.\nPRESS C TO SWITCH STORAGE."
            case .sellProduce: msg = "NOTHING TO SELL.\nGROW CROPS OR COOK FISH!"
            default: msg = "NOTHING TO SELL.\nCHOP TREES AND VISIT THE MINE!"
            }
            let e = inkLabel(msg, scale: 4)
            e.position = CGPoint(x: 640, y: 400)
            content.addChild(e)
            return
        }
        let visible = 9
        let start = max(0, min(selected - visible / 2, rows.count - visible))
        for (i, r) in rows.enumerated() where i >= start && i < start + visible {
            let y = 568 - CGFloat(i - start) * 48
            let row = panelSprite(900, 44, scale: 2, style: i == selected ? .slotLit : .slot)
            row.position = CGPoint(x: 640, y: y)
            content.addChild(row)
            let icon = pixelSprite(r.icon, scale: 2)
            icon.position = CGPoint(x: -410, y: 0)
            row.addChild(icon)
            let n = inkLabel(r.name.uppercased(), scale: 3, color: r.color, align: .left)
            n.position = CGPoint(x: -370, y: 0)
            row.addChild(n)
            let c = inkLabel("×\(r.count)", scale: 3, align: .right)
            c.position = CGPoint(x: 90, y: 0)
            row.addChild(c)
            let m = r.mult
            let arrow = m > 1.08 ? "↑" : (m < 0.92 ? "↓" : "-")
            let mc = m > 1.08 ? PColor(0x2E8A2A) : (m < 0.92 ? PColor(0xC8281A) : PColor(0x7A5A3A))
            let ml = inkLabel(String(format: "%@ ×%.2f", arrow, m), scale: 2, color: mc, align: .right)
            ml.position = CGPoint(x: 250, y: 0)
            row.addChild(ml)
            let v = inkLabel("\(r.price)G", scale: 3, color: PColor(0x9A6010), align: .right)
            v.position = CGPoint(x: 430, y: 0)
            row.addChild(v)
        }
        let total = rows.reduce(0) { $0 + $1.price }
        let button = panelSprite(560, 56, scale: 2, style: .dark)
        button.position = CGPoint(x: 640, y: 128)
        button.addChild(PixelLabel("X: SELL EVERYTHING FOR \(total)G", scale: 3, color: .gold))
        content.addChild(button)
    }

    private func buildCards() {
        let list = cards()
        let perRow = 6
        for (i, c) in list.enumerated() {
            let col = i % perRow, row = i / perRow
            let card = panelSprite(184, 132, scale: 2, style: i == selected ? .slotLit : .slot)
            card.position = CGPoint(x: 190 + CGFloat(col) * 180, y: 570 - CGFloat(row) * 140)
            content.addChild(card)
            let icon = pixelSprite(c.icon, scale: min(3, 60 / max(1, c.icon.size().height)))
            icon.position = CGPoint(x: 0, y: 28)
            card.addChild(icon)
            let n = inkLabel(c.title.uppercased(), scale: c.title.count > 12 ? 1.5 : 2)
            n.position = CGPoint(x: 0, y: -22)
            card.addChild(n)
            let sl = inkLabel(c.status, scale: 2, color: c.statusColor)
            sl.position = CGPoint(x: 0, y: -46)
            card.addChild(sl)
        }
        guard selected < list.count else { return }
        let detail = panelSprite(1160, 80, scale: 2, style: .dark)
        detail.position = CGPoint(x: 640, y: 158)
        content.addChild(detail)
        let name = PixelLabel(list[selected].title.uppercased(), scale: 3, color: .gold)
        name.position = CGPoint(x: 0, y: 16)
        detail.addChild(name)
        let perk = PixelLabel(list[selected].detail, scale: 2)
        perk.position = CGPoint(x: 0, y: -16)
        detail.addChild(perk)
    }

    private func statBar(_ label: String, _ v: Double, width: CGFloat, at p: CGPoint, in parent: SKNode) {
        let l = inkLabel(label, scale: 2, align: .left)
        l.position = CGPoint(x: p.x, y: p.y + 10)
        parent.addChild(l)
        let track = SKSpriteNode(color: PColor(0xC89A5C).ns, size: CGSize(width: width, height: 8))
        track.anchorPoint = CGPoint(x: 0, y: 0.5)
        track.position = CGPoint(x: p.x, y: p.y - 6)
        parent.addChild(track)
        let fill = SKSpriteNode(color: PColor(0x4EA83A).ns, size: CGSize(width: snap(width * CGFloat(max(0.05, min(1, v))), 4), height: 8))
        fill.anchorPoint = CGPoint(x: 0, y: 0.5)
        fill.position = track.position
        parent.addChild(fill)
    }

    private func buildRods(_ save: SaveData) {
        for (i, rod) in Rod.all.enumerated() {
            let card = panelSprite(224, 460, scale: 2, style: i == selected ? .slotLit : .slot)
            card.position = CGPoint(x: 640 + CGFloat(i - 2) * 236, y: 370)
            content.addChild(card)
            let art = pixelSprite(Tex.get("rodart|\(i)") {
                let b = PixelBuffer(40, 24)
                b.line(4, 3, 36, 21, PColor(rod.color), thick: 2)
                b.line(4, 3, 10, 6, PColor(0x3A2A1A), thick: 2)
                b.ellipse(10, 4, 3, 3, PColor(0x3A3E46))
                b.set(10, 4, PColor(0xA8A8B0))
                b.outline(PColor(0x2A1408))
                return b
            }, scale: 4)
            art.position = CGPoint(x: 0, y: 160)
            card.addChild(art)
            let name = inkLabel(rod.name.uppercased(), scale: 2)
            name.position = CGPoint(x: 0, y: 92)
            card.addChild(name)
            let status: String, col: PColor
            if i == save.rodLevel { status = "EQUIPPED"; col = PColor(0x2E8A2A) }
            else if i < save.rodLevel { status = "OWNED"; col = PColor(0x9A7A5A) }
            else { status = "\(rod.price)G"; col = save.coins >= rod.price ? PColor(0x9A6010) : PColor(0xC8281A) }
            let st = inkLabel(status, scale: 3, color: col)
            st.position = CGPoint(x: 0, y: 62)
            card.addChild(st)
            statBar("CATCH ZONE", (rod.barSize - 0.18) / 0.2, width: 180, at: CGPoint(x: -90, y: 18), in: card)
            statBar("REEL SPEED", (rod.reelSpeed - 0.9) / 0.5, width: 180, at: CGPoint(x: -90, y: -24), in: card)
            statBar("LUCK", (rod.luck + 0.02) / 0.22, width: 180, at: CGPoint(x: -90, y: -66), in: card)
            let blurb = inkLabel(PixelFont.wrap(rod.blurb.uppercased(), maxWidth: 92), scale: 2, color: PColor(0x7A5A3A))
            blurb.position = CGPoint(x: 0, y: -150)
            card.addChild(blurb)
        }
    }

    private func buildBoats(_ save: SaveData) {
        for (i, boat) in Boat.all.enumerated() {
            let card = panelSprite(372, 470, scale: 2, style: i == selected ? .slotLit : .slot)
            card.position = CGPoint(x: 640 + CGFloat(i - 1) * 390, y: 365)
            content.addChild(card)
            let water = SKSpriteNode(color: PColor(0x3C8DC8).ns, size: CGSize(width: 332, height: 40))
            water.position = CGPoint(x: 0, y: 136)
            card.addChild(water)
            let node = BoatNode(kind: boat.kind, scale: 3)
            node.position = CGPoint(x: 0, y: 150)
            card.addChild(node)
            let name = inkLabel(boat.name.uppercased(), scale: 3)
            name.position = CGPoint(x: 0, y: 86)
            card.addChild(name)
            let level = i + 1
            let status: String, col: PColor
            if level == save.boatLevel { status = "OWNED"; col = PColor(0x2E8A2A) }
            else if level < save.boatLevel { status = "UPGRADED"; col = PColor(0x9A7A5A) }
            else { status = "\(boat.price)G"; col = save.coins >= boat.price ? PColor(0x9A6010) : PColor(0xC8281A) }
            let st = inkLabel(status, scale: 3, color: col)
            st.position = CGPoint(x: 0, y: 54)
            card.addChild(st)
            statBar("SPEED", boat.speed / 270, width: 300, at: CGPoint(x: -150, y: 14), in: card)
            statBar("BIGGER FISH  +\(Int(boat.sizeBonus * 100))%", boat.sizeBonus / 0.45, width: 300, at: CGPoint(x: -150, y: -26), in: card)
            statBar("BONUS CATCH  \(Int(boat.extraChance * 100))%", boat.extraChance / 0.55, width: 300, at: CGPoint(x: -150, y: -66), in: card)
            let cooler = inkLabel("COOLER: \(boat.capacity) FISH", scale: 2, align: .left)
            cooler.position = CGPoint(x: -150, y: -104)
            card.addChild(cooler)
            let w = inkLabel(boat.watersLabel.uppercased(), scale: 2, color: PColor(0x2A64C8))
            w.position = CGPoint(x: 0, y: -134)
            card.addChild(w)
            let blurb = inkLabel(PixelFont.wrap(boat.blurb.uppercased(), maxWidth: 160), scale: 2, color: PColor(0x7A5A3A))
            blurb.position = CGPoint(x: 0, y: -180)
            card.addChild(blurb)
        }
    }

    // MARK: Actions

    private func say(_ text: String, good: Bool) {
        feedback.text = text
        feedback.textColor = good ? PColor(0x2E8A2A) : PColor(0xC8281A)
        Sound.play(good ? "Purr" : "Funk", volume: 0.4)
    }

    private func sell(all: Bool) {
        let game = Game.shared
        let rows = sellRows()
        guard !rows.isEmpty else { say("NOTHING TO SELL!", good: false); return }
        let ids: Set<String> = all ? Set(rows.map { $0.id }) : [rows[selected].id]
        var total = 0, n = 0
        if tab == .sellFish {
            let day = game.save.day, bonus = game.save.sellBonus
            func take(_ list: inout [CaughtFish]) {
                list.removeAll { c in
                    guard ids.contains(c.id) else { return false }
                    total += Market.price(c, day: day, sellBonus: bonus)
                    n += 1
                    return true
                }
            }
            switch fishSource {
            case 1: take(&game.save.chest)
            case 2: take(&game.save.fridgeFish)
            case 3: take(&game.save.freezer)
            default: take(&game.save.cooler)
            }
        } else {
            for id in ids {
                let count = game.save.count(id)
                total += sellPrice(id, game.save) * count
                n += count
                game.save.take(id, count)
            }
        }
        game.save.coins += total
        game.save.persist()
        say("SOLD \(n) ITEM\(n == 1 ? "" : "S") FOR \(total)G!", good: true)
        rebuild()
    }

    private func buy() {
        let game = Game.shared
        switch tab {
        case .sellFish, .sellProduce, .sellGoods:
            sell(all: false)
            return
        default:
            let list = cards()
            guard selected < list.count, let res = list[selected].action() else { return }
            say(res.0, good: res.1)
        }
        game.save.persist()
        rebuild()
    }

    private func switchTab(_ t: Tab) {
        tab = t
        let s = Game.shared.save
        switch t {
        case .rods: selected = s.rodLevel
        default: selected = 0
        }
        feedback.text = ""
        Sound.play("Tink", volume: 0.3)
        rebuild()
    }

    override func keyPressed(_ key: UInt16) {
        if let i = Key.numbers.firstIndex(of: key), i < tabs.count { switchTab(tabs[i]); return }
        let grid = !(tab == .sellFish || tab == .sellProduce || tab == .sellGoods)
        let isList = tab == .sellFish || tab == .sellProduce || tab == .sellGoods
        switch key {
        case Key.tab: switchTab(tabs[(tabs.firstIndex(of: tab)! + 1) % tabs.count])
        case Key.left, Key.a: selected = max(0, selected - 1); rebuild()
        case Key.right, Key.d: selected = min(listCount - 1, selected + 1); rebuild()
        case Key.up, Key.w: selected = max(0, selected - (grid ? 6 : 1)); rebuild()
        case Key.down, Key.s: selected = min(listCount - 1, selected + (grid ? 6 : 1)); rebuild()
        case Key.c where tab == .sellFish:
            let src = fishSources
            fishSource = src[((src.firstIndex(of: fishSource) ?? 0) + 1) % src.count]
            selected = 0; feedback.text = ""; rebuild()
        case Key.x where isList: sell(all: true)
        case Key.space, Key.ret, Key.enter: buy()
        case Key.esc: Game.shared.showMap()
        default: break
        }
    }
}
