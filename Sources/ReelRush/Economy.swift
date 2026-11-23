import Foundation
import CoreGraphics

// MARK: - Farming

struct Crop {
    let id: String
    let name: String
    let seasons: Set<Season>
    let days: Int
    let seedPrice: Int
    let sell: Int
    let fruit: UInt32
    let leaf: UInt32
    let style: Int  // 0 root, 1 bush/berries, 2 tall, 3 big gourd, 4 leafy

    var produceID: String { "crop.\(id)" }
    var seedID: String { "seed.\(id)" }

    private static func c(_ id: String, _ name: String, _ seasons: String, _ days: Int, _ seed: Int, _ sell: Int,
                          _ fruit: UInt32, _ leaf: UInt32, _ style: Int) -> Crop {
        Crop(id: id, name: name, seasons: Set(Season.allCases.filter { seasons.contains($0.letter) }), days: days,
             seedPrice: seed, sell: sell, fruit: fruit, leaf: leaf, style: style)
    }

    static let all: [Crop] = [
        c("parsnip", "Parsnip", "P", 4, 20, 35, 0xF2E6B0, 0x5AAA3A, 0),
        c("potato", "Potato", "P", 6, 50, 80, 0xC8985A, 0x4A9A3A, 0),
        c("strawberry", "Strawberry", "P", 8, 100, 170, 0xE83A4A, 0x3E8A3A, 1),
        c("carrot", "Carrot", "PF", 5, 40, 70, 0xF28A2A, 0x5AAA3A, 0),
        c("tomato", "Tomato", "S", 6, 50, 90, 0xE84A3A, 0x3E8A3A, 1),
        c("corn", "Corn", "SF", 8, 75, 110, 0xF2D23A, 0x5AAA3A, 2),
        c("melon", "Melon", "S", 10, 80, 250, 0x6AC85A, 0x3E8A3A, 3),
        c("pumpkin", "Pumpkin", "F", 10, 100, 320, 0xF2822A, 0x4A8A3A, 3),
        c("cranberry", "Cranberries", "F", 7, 120, 200, 0xC82A4A, 0x5A8A3A, 1),
        c("kale", "Winter Kale", "W", 6, 70, 120, 0x4A8A5A, 0x2E6A3A, 4),
    ]
    static let byID: [String: Crop] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
}

struct Plot: Codable {
    var tilled = true
    var crop: String?
    var growth = 0
    var wateredDay = 0
    var dead = false

    var mature: Bool { crop.flatMap { Crop.byID[$0] }.map { growth >= $0.days } ?? false }
    var stage: Int {
        guard let c = crop.flatMap({ Crop.byID[$0] }) else { return 0 }
        return mature ? 3 : min(2, growth * 3 / max(1, c.days))
    }
}

// MARK: - Goods

enum GoodCat: String { case produce, seed, timber, ore, gem, bar, dish, food, tool }

struct Good {
    let id: String
    let name: String
    let cat: GoodCat
    let price: Int      // what the store pays (or charges, for seeds/tools)
    let c1: UInt32
    let c2: UInt32
    let energy: Int     // restored when eaten (0 = inedible)

    var sellable: Bool { cat != .seed && cat != .tool }

    static let all: [Good] = {
        var g: [Good] = [
            Good(id: "timber", name: "Timber", cat: .timber, price: 12, c1: 0xA0703C, c2: 0x6A4422, energy: 0),
            Good(id: "stone", name: "Stone", cat: .ore, price: 2, c1: 0x9A968E, c2: 0x6A665E, energy: 0),
            Good(id: "flint", name: "Flint", cat: .ore, price: 8, c1: 0x5A5A64, c2: 0xC8C8D0, energy: 0),
            Good(id: "coal", name: "Coal", cat: .ore, price: 15, c1: 0x2A2A2E, c2: 0x5A5A62, energy: 0),
            Good(id: "copper", name: "Copper Ore", cat: .ore, price: 12, c1: 0x9A968E, c2: 0xE8823A, energy: 0),
            Good(id: "iron", name: "Iron Ore", cat: .ore, price: 22, c1: 0x9A968E, c2: 0xC8A88A, energy: 0),
            Good(id: "gold", name: "Gold Ore", cat: .ore, price: 45, c1: 0x9A968E, c2: 0xFFD23A, energy: 0),
            Good(id: "quartz", name: "Quartz", cat: .gem, price: 30, c1: 0xF0F4F8, c2: 0xB8C8D8, energy: 0),
            Good(id: "amethyst", name: "Amethyst", cat: .gem, price: 90, c1: 0xB86AE8, c2: 0x7A3AB8, energy: 0),
            Good(id: "emerald", name: "Emerald", cat: .gem, price: 180, c1: 0x3AD87A, c2: 0x1E8A4A, energy: 0),
            Good(id: "ruby", name: "Ruby", cat: .gem, price: 240, c1: 0xE83A4A, c2: 0x9A1A2A, energy: 0),
            Good(id: "diamond", name: "Diamond", cat: .gem, price: 450, c1: 0xE8FAFF, c2: 0x8AD8F2, energy: 0),
            Good(id: "copperbar", name: "Copper Bar", cat: .bar, price: 70, c1: 0xE8823A, c2: 0xA8501C, energy: 0),
            Good(id: "ironbar", name: "Iron Bar", cat: .bar, price: 120, c1: 0xC8C8D0, c2: 0x7A7A84, energy: 0),
            Good(id: "steelbar", name: "Steel Bar", cat: .bar, price: 220, c1: 0x8AA0C8, c2: 0x4A5A7A, energy: 0),
            Good(id: "goldbar", name: "Gold Bar", cat: .bar, price: 260, c1: 0xFFD23A, c2: 0xC8961E, energy: 0),
            Good(id: "dish.grilled", name: "Grilled Fish", cat: .dish, price: 75, c1: 0xC88A4A, c2: 0xF2E8D0, energy: 40),
            Good(id: "dish.chips", name: "Fish & Chips", cat: .dish, price: 190, c1: 0xE8B85A, c2: 0xF2E8D0, energy: 60),
            Good(id: "dish.tacos", name: "Fish Tacos", cat: .dish, price: 260, c1: 0xF2D23A, c2: 0xE84A3A, energy: 70),
            Good(id: "dish.chowder", name: "Seafood Chowder", cat: .dish, price: 280, c1: 0xF2ECD8, c2: 0xF28A2A, energy: 80),
            Good(id: "dish.pie", name: "Pumpkin Fish Pie", cat: .dish, price: 420, c1: 0xF2822A, c2: 0xC8904A, energy: 100),
            Good(id: "dish.sushi", name: "Sushi Platter", cat: .dish, price: 220, c1: 0xF0F0F0, c2: 0xE85A4A, energy: 55),
            Good(id: "dish.kale", name: "Kale & Trout Bowl", cat: .dish, price: 240, c1: 0x4A8A5A, c2: 0xF0A080, energy: 75),
            Good(id: "food.bread", name: "Bread", cat: .food, price: 35, c1: 0xD8A05A, c2: 0xF2D8A0, energy: 25),
            Good(id: "food.coffee", name: "Coffee", cat: .food, price: 60, c1: 0x6A3A1A, c2: 0xF0F0F0, energy: 40),
            Good(id: "food.salad", name: "Garden Salad", cat: .food, price: 90, c1: 0x5AAA3A, c2: 0xE84A3A, energy: 60),
            Good(id: "food.cake", name: "Honey Cake", cat: .food, price: 150, c1: 0xF2C85A, c2: 0xF2F0E8, energy: 100),
            Good(id: "gift.pendant", name: "Promise Pendant", cat: .tool, price: 3000, c1: 0x5AE8FF, c2: 0xFFD23A, energy: 0),
            Good(id: "tool.welder", name: "Welding Machine", cat: .tool, price: 2000, c1: 0x5A6A8A, c2: 0xFFD23A, energy: 0),
            Good(id: "tool.striker", name: "Flint & Steel", cat: .tool, price: 0, c1: 0x8AA0C8, c2: 0x5A5A64, energy: 0),
        ]
        for c in Crop.all {
            g.append(Good(id: c.produceID, name: c.name, cat: .produce, price: c.sell, c1: c.fruit, c2: c.leaf, energy: max(8, c.sell / 5)))
            g.append(Good(id: c.seedID, name: c.name + " Seeds", cat: .seed, price: c.seedPrice, c1: c.fruit, c2: c.leaf, energy: 0))
        }
        return g
    }()

    static let byID: [String: Good] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    /// Daily price including a little market drift (produce also swings with the season).
    static func price(_ id: String, day: Int) -> Int {
        guard let g = byID[id] else { return 0 }
        var m = 1 + (hrand(day, id.count &* 97 &+ Int(id.unicodeScalars.first!.value), 31) * 0.2 - 0.1)
        if g.cat == .produce, let crop = Crop.byID[String(id.dropFirst(5))] {
            m *= crop.seasons.contains(GameCalendar.season(day)) ? 0.9 : 1.35
        }
        return max(1, Int((Double(g.price) * m).rounded()))
    }
}

// MARK: - Crafting

enum Station { case stove, welder }

struct Recipe {
    let id: String
    let name: String
    let station: Station
    let inputs: [(String, Int)]   // "fish" = any fish from cooler/chests
    let output: String

    static let all: [Recipe] = [
        Recipe(id: "r.grilled", name: "Grilled Fish", station: .stove, inputs: [("fish", 1), ("timber", 1)], output: "dish.grilled"),
        Recipe(id: "r.chips", name: "Fish & Chips", station: .stove, inputs: [("fish", 1), ("crop.potato", 1), ("timber", 1)], output: "dish.chips"),
        Recipe(id: "r.tacos", name: "Fish Tacos", station: .stove, inputs: [("fish", 1), ("crop.corn", 1), ("crop.tomato", 1), ("timber", 1)], output: "dish.tacos"),
        Recipe(id: "r.chowder", name: "Seafood Chowder", station: .stove, inputs: [("fish", 1), ("crop.potato", 1), ("crop.carrot", 1), ("timber", 1)], output: "dish.chowder"),
        Recipe(id: "r.pie", name: "Pumpkin Fish Pie", station: .stove, inputs: [("fish", 1), ("crop.pumpkin", 1), ("timber", 2)], output: "dish.pie"),
        Recipe(id: "r.sushi", name: "Sushi Platter", station: .stove, inputs: [("fish", 2), ("timber", 1)], output: "dish.sushi"),
        Recipe(id: "r.kale", name: "Kale & Trout Bowl", station: .stove, inputs: [("fish", 1), ("crop.kale", 1), ("timber", 1)], output: "dish.kale"),
        Recipe(id: "w.copper", name: "Copper Bar", station: .welder, inputs: [("copper", 3), ("coal", 1)], output: "copperbar"),
        Recipe(id: "w.iron", name: "Iron Bar", station: .welder, inputs: [("iron", 3), ("coal", 1)], output: "ironbar"),
        Recipe(id: "w.steel", name: "Steel Bar", station: .welder, inputs: [("ironbar", 1), ("coal", 2)], output: "steelbar"),
        Recipe(id: "w.gold", name: "Gold Bar", station: .welder, inputs: [("gold", 3), ("coal", 1)], output: "goldbar"),
    ] + ToolKind.allCases.flatMap { k in
        [(1, "copperbar", 3), (2, "ironbar", 4), (3, "goldbar", 6)].map { lvl, bar, timber in
            Recipe(id: "t.\(k.rawValue).\(lvl)", name: "\(Tools.tiers[lvl]) \(k.name)", station: .welder,
                   inputs: [(bar, 2), ("timber", timber)], output: "toolup.\(k.rawValue).\(lvl)")
        }
    }

    /// For tool recipes: which tool and level they produce.
    var toolUpgrade: (ToolKind, Int)? {
        guard output.hasPrefix("toolup.") else { return nil }
        let p = output.split(separator: ".")
        guard p.count == 3, let k = ToolKind(rawValue: String(p[1])), let l = Int(p[2]) else { return nil }
        return (k, l)
    }

    func canMake(_ s: SaveData) -> Bool {
        if let (k, l) = toolUpgrade, Tools.level(k, s) >= l { return false }
        return inputs.allSatisfy { $0.0 == "fish" ? s.anyFishCount >= $0.1 : s.count($0.0) >= $0.1 }
    }
}

// MARK: - Energy

enum Energy {
    static let max = 120
    static let cast = 2, chop = 4, mine = 3, till = 2, water = 1
}

// MARK: - Villagers & requests

enum Want { case fish, produce, timber, ore }

struct Villager {
    let id: String
    let name: String
    let outfit: Outfit
    let wants: [Want]
    let lines: [String]
    var female = false
    var job = "Town"
    var wage = 0

    private static func o(_ hat: HatStyle, _ hc: UInt32, _ band: UInt32, _ shirt: UInt32, _ s2: UInt32, _ pat: ShirtPattern,
                          _ pants: UInt32, _ hair: UInt32, _ skin: UInt32) -> Outfit {
        Outfit(hatStyle: hat, hat: hc, hatBand: band, shirt: shirt, shirt2: s2, pattern: pat, pants: pants,
               pants2: PColor(pants).shade(-0.2).hex, shorts: false, hair: hair, skin: skin)
    }

    static let all: [Villager] = [
        Villager(id: "marina", name: "Marina", outfit: o(.cap, 0x2A6AC8, 0xF0F0F0, 0x3AA8C8, 0xF0F0F0, .stripes, 0x2A3A5A, 0xC8582A, 0xF4C49A),
                 wants: [.fish, .fish], lines: ["The bay's been generous lately.", "Fresh fish makes the best stew!", "Seen any big ones out there?"],
                 female: true, job: "Bait & Tackle", wage: 140),
        Villager(id: "lars", name: "Lars", outfit: o(.beanie, 0xC83A3A, 0x2A2A2A, 0xC83A2A, 0x2A1A1A, .plaid, 0x4A4A5A, 0xE8C060, 0xE0A878),
                 wants: [.timber, .timber, .ore], lines: ["Nothing beats the smell of fresh timber.", "I'm building a new cabin.", "Mind the trees, they grow back slow."]),
        Villager(id: "rosa", name: "Rosa", outfit: o(.straw, 0xE8C870, 0xE84A6A, 0x6AA83A, 0xF2E85A, .floral, 0x8A6A3A, 0x2A1A10, 0xB87850),
                 wants: [.produce, .produce, .fish], lines: ["Water your crops every day!", "Rain is a farmer's best friend.", "Out-of-season crops just wither."],
                 female: true, job: "Market", wage: 130),
        Villager(id: "gus", name: "Gus", outfit: o(.cap, 0x3A3A44, 0xE8823A, 0x5A5A64, 0x3A3A44, .plain, 0x3A2A1A, 0x2A1A10, 0x8A5A3A),
                 wants: [.ore, .ore, .timber], lines: ["The deeper the mine, the better the ore.", "Gems glitter below level ten.", "Coal and iron make fine bars."]),
        Villager(id: "amelie", name: "Chef Amelie", outfit: o(.bucket, 0xF0F0F0, 0xF0F0F0, 0xF0F0F0, 0xD8D8D8, .plain, 0x2A2A34, 0x6A3A1A, 0xF4C49A),
                 wants: [.produce, .fish], lines: ["A stove and some timber - that's all you need.", "Tacos need corn AND tomatoes!", "Cooked fish sells far better than raw."],
                 female: true, job: "Market Kitchen", wage: 160),
        Villager(id: "ivy", name: "Ivy", outfit: o(.beanie, 0x6A3AA8, 0xF2D23A, 0x2AB8B0, 0xF2E85A, .floral, 0x3A3A5A, 0x2A1A10, 0xE0A878),
                 wants: [.ore, .produce, .fish], lines: ["I sew everything at the Boutique myself.", "Gems make the prettiest buttons.", "Have you tried the Glacier Tarn?"],
                 female: true, job: "Boutique", wage: 150),
        Villager(id: "pete", name: "Old Pete", outfit: o(.bucket, 0x8A7A4A, 0x5A4A2A, 0x4E8A3A, 0x3A6A2A, .plain, 0x5A4A3A, 0xD0D0D8, 0xE0A878),
                 wants: [.fish, .fish, .ore], lines: ["Fish bite best at dawn and dusk.", "I'll beat you at the next contest!", "Catfish come out at night."]),
    ]
    static let byID: [String: Villager] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
}

struct Kid: Codable {
    let name: String
    let girl: Bool
    let born: Int

    enum Stage { case baby, child, teen }
    func stage(_ day: Int) -> Stage { day - born < 7 ? .baby : (day - born < 21 ? .child : .teen) }

    var outfit: Outfit {
        Outfit(hatStyle: girl ? .beanie : .cap, hat: girl ? 0xE85A8A : 0x3A6AE8, hatBand: 0xF0F0F0,
               shirt: girl ? 0xF2A0C8 : 0x5AB4E8, shirt2: 0xF0F0F0, pattern: girl ? .floral : .stripes,
               pants: 0x3A5A9A, pants2: 0x2A4272, shorts: !girl, hair: 0x6A3A1A, skin: 0xF4C49A)
    }
}

enum Romance {
    static let pendant = "gift.pendant"
    static let pendantPrice = 3000
    static let proposeHearts = 8

    /// Friendship points for a gift.
    static func points(_ id: String, isFish: Bool) -> Int {
        if isFish { return FishSpecies.byID[id]?.rarity == .legendary ? 6 : (FishSpecies.byID[id]?.rarity.rawValue ?? 0) + 2 }
        switch Good.byID[id]?.cat {
        case .dish: return 5
        case .gem: return 4
        case .food, .produce, .bar: return 3
        default: return 1
        }
    }

    static let houseExpansions: [(price: Int, timber: Int)] = [(5000, 50), (12000, 100), (25000, 150)]
}

struct Request: Codable {
    let npc: String
    let item: String
    let isFish: Bool
    let qty: Int
    let reward: Int
    let due: Int

    var itemName: String {
        isFish ? (FishSpecies.byID[item]?.name ?? item) : (Good.byID[item]?.name ?? item)
    }

    static func make(for v: Villager, day: Int) -> Request {
        let season = GameCalendar.season(day)
        let mult = Double.random(in: 1.6...2.4)
        let due = day + Int.random(in: 3...6)
        switch v.wants.randomElement()! {
        case .fish:
            let pool = FishSpecies.all.filter { $0.rarity != .legendary && $0.seasons.contains(season) && $0.habitat != .cavern && !$0.isShark }
            let f = pool.randomElement()!
            let qty = f.rarity == .common ? Int.random(in: 1...3) : 1
            return Request(npc: v.id, item: f.id, isFish: true, qty: qty, reward: Int(Double(f.baseValue * qty) * 1.3 * mult), due: due)
        case .produce:
            let crops = Crop.all.filter { $0.seasons.contains(season) }
            let c = crops.randomElement() ?? Crop.byID["kale"]!
            let qty = Int.random(in: 2...5)
            return Request(npc: v.id, item: c.produceID, isFish: false, qty: qty, reward: Int(Double(c.sell * qty) * mult), due: due)
        case .timber:
            let qty = Int.random(in: 5...20)
            return Request(npc: v.id, item: "timber", isFish: false, qty: qty, reward: Int(Double(12 * qty) * mult), due: due)
        case .ore:
            let id = ["stone", "coal", "copper", "iron", "quartz", "flint", "ironbar", "copperbar"].randomElement()!
            let g = Good.byID[id]!
            let qty = id == "stone" ? Int.random(in: 10...30) : Int.random(in: 2...6)
            return Request(npc: v.id, item: id, isFish: false, qty: qty, reward: Int(Double(g.price * qty) * mult), due: due)
        }
    }
}

// MARK: - Tools (axe, pickaxe, hoe upgrades)

enum ToolKind: String, CaseIterable {
    case axe, pickaxe, hoe
    var name: String { ["Axe", "Pickaxe", "Hoe"][ToolKind.allCases.firstIndex(of: self)!] }
}

enum Tools {
    static let tiers = ["Rusty", "Copper", "Iron", "Gold"]
    static let prices = [0, 500, 1500, 4000]
    static let colors: [UInt32] = [0x8A6A5A, 0xE8823A, 0xC8C8D0, 0xFFD23A]

    static func level(_ k: ToolKind, _ s: SaveData) -> Int { s.tools[k.rawValue] ?? 0 }

    static func chopHits(_ l: Int) -> Int { [3, 2, 2, 1][l] }
    static func chopEnergy(_ l: Int) -> Int { [4, 3, 2, 2][l] }
    static func mineDamage(_ l: Int) -> Int { [1, 2, 2, 3][l] }
    static func mineEnergy(_ l: Int) -> Int { [3, 3, 2, 2][l] }
    static func tillEnergy(_ l: Int) -> Int { [2, 1, 1, 1][l] }
    static func tillArea(_ l: Int) -> Int { [1, 1, 2, 3][l] }

    static func perks(_ k: ToolKind, _ l: Int) -> String {
        switch k {
        case .axe: return "\(chopHits(l)) CHOPS PER TREE · \(chopEnergy(l)) ENERGY · +\(l) TIMBER"
        case .pickaxe: return "\(mineDamage(l)) DAMAGE · \(mineEnergy(l)) ENERGY · +\(l * 10)% ORE"
        case .hoe: return "TILLS \(tillArea(l)) TILE\(tillArea(l) > 1 ? "S" : "") · \(tillEnergy(l)) ENERGY"
        }
    }
}

// MARK: - Fuel

/// Every car and boat has a gas tank. Driving and sailing burn fuel by distance.
enum Fuel {
    static let pricePerLiter = 2
    /// (tank size in liters, liters burned per tile travelled)
    static let specs: [String: (tank: Double, burn: Double)] = [
        "car.pickup": (40, 0.10), "car.jeep": (50, 0.12), "car.truck": (90, 0.18), "car.coupe": (45, 0.14),
        "kayak": (8, 0.02), "row": (8, 0.02), "skiff": (40, 0.12), "bass": (60, 0.20),
        "pontoon": (70, 0.16), "trawler": (160, 0.40), "yacht": (300, 0.75),
    ]
    static func tank(_ id: String) -> Double { specs[id]?.tank ?? 50 }
    static func burn(_ id: String) -> Double { specs[id]?.burn ?? 0.12 }
    /// Speed multiplier when the tank is empty: you can still crawl home.
    static let emptyCrawl: CGFloat = 0.2
}

// MARK: - Construction

/// Home buildings you build yourself from timber and stone.
enum Construction {
    static let costs: [BuildingKind: (timber: Int, stone: Int)] = [.boatShed: (40, 30), .garage: (30, 50)]

    static func name(_ k: BuildingKind) -> String { k == .garage ? "GARAGE" : "BOAT SHED" }
    static func costLabel(_ k: BuildingKind) -> String {
        guard let c = costs[k] else { return "" }
        return "\(c.timber) TIMBER + \(c.stone) STONE"
    }
}

// MARK: - House decor

struct Decor {
    let id: String
    let name: String
    let price: Int
    let blurb: String
    let x: CGFloat, y: CGFloat          // room position (pixels)
    let collide: CGRect?

    static let all: [Decor] = [
        Decor(id: "decor.bookshelf", name: "Bookshelf", price: 350, blurb: "Packed with fishing almanacs.", x: 244, y: 100, collide: CGRect(x: 244, y: 100, width: 24, height: 12)),
        Decor(id: "decor.armchair", name: "Armchair", price: 400, blurb: "A comfy spot by the fire.", x: 196, y: 56, collide: CGRect(x: 196, y: 56, width: 22, height: 10)),
        Decor(id: "decor.tank", name: "Fish Tank", price: 900, blurb: "Shows off your three biggest catches.", x: 194, y: 96, collide: CGRect(x: 194, y: 96, width: 40, height: 12)),
        Decor(id: "decor.lamp", name: "Floor Lamp", price: 180, blurb: "Warm light for long nights.", x: 274, y: 66, collide: CGRect(x: 274, y: 66, width: 10, height: 6)),
        Decor(id: "decor.painting", name: "Lake Painting", price: 250, blurb: "Pinecrest Lake at dawn.", x: 64, y: 156, collide: nil),
        Decor(id: "decor.fern", name: "Potted Fern", price: 120, blurb: "Brings the outdoors in.", x: 276, y: 116, collide: CGRect(x: 276, y: 116, width: 16, height: 8)),
        Decor(id: "decor.radio", name: "Radio", price: 220, blurb: "Plays the fishing report.", x: 150, y: 70, collide: nil),
    ]
}

enum Appliance {
    static let fridgePrice = 800, freezerPrice = 1500, chestPrice = 300
}

// MARK: - Charters

struct Charter: Codable {
    let client: String
    let habitat: String     // Habitat rawValue
    let perFish: Int
    let bonus: Int
    let target: Int
    var caught = 0
    let day: Int

    var water: Habitat { Habitat(rawValue: habitat) ?? .lake }

    static let clients = ["MR. HOLLOWAY", "THE KIM FAMILY", "DR. VANCE", "BACHELOR PARTY", "CEO MORGAN", "TOURISTS FROM AFAR", "RETIRED ADMIRAL"]

    /// Today's charter offers (same for the whole day).
    static func offers(day: Int) -> [Charter] {
        var rng = SeededRNG(seed: UInt64(day * 7_919 + 17))
        let waters: [Habitat] = [.lake, .river, .ocean, .lagoon, .deepSea, .pond, .swamp, .alpine, .kelp, .trench]
        return (0..<3).map { i in
            let w = waters[Int.random(in: 0..<waters.count, using: &rng)]
            let target = Int.random(in: 3...7, using: &rng)
            let per = Int.random(in: 60...160, using: &rng) * (w == .deepSea ? 2 : 1)
            return Charter(client: clients[(day + i * 3) % clients.count], habitat: w.rawValue, perFish: per,
                           bonus: target * per, target: target, day: day)
        }
    }
}

extension Charter {
    /// How many clients come along on the boat.
    var partySize: Int {
        switch client {
        case "THE KIM FAMILY", "BACHELOR PARTY": return 3
        case "TOURISTS FROM AFAR": return 2
        default: return 1
        }
    }
    var complete: Bool { caught >= target }
    /// The clients' looks (stable for each client).
    var party: [Outfit] { (0..<partySize).map { Charter.guest(client, $0) } }

    static func guest(_ client: String, _ i: Int) -> Outfit {
        let sid = client.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        func pick<T>(_ a: [T], _ k: Int) -> T { a[Int(hrand(i, sid, k) * Double(a.count)) % a.count] }
        let shirts: [UInt32] = [0xE85A5A, 0x3A8AE8, 0xF2C83A, 0x5AC87A, 0xE88A3A, 0xA85AE8, 0xF0F0F0, 0x2AB8B0]
        let pants: [UInt32] = [0x2A3A5A, 0x5A4A3A, 0xC8B890, 0x3A3A44, 0x6A8A4A]
        var hat: HatStyle = pick([.bucket, .straw, .cap, .beanie], 1)
        var hatC: UInt32 = pick([0xF0E8D0, 0xC8A050, 0x3A6AE8, 0xE85A5A, 0x2A2A34], 2)
        var shirt = pick(shirts, 3)
        if client == "RETIRED ADMIRAL" { hat = .cap; hatC = 0xF4F4F4; shirt = 0x1A2A5A }
        if client == "CEO MORGAN" { hat = .straw; shirt = 0x2A2A34 }
        if client == "BACHELOR PARTY" && i == 0 { hat = .straw; hatC = 0xFFD23A }
        let p = pick(pants, 4)
        return Outfit(hatStyle: hat, hat: hatC, hatBand: PColor(hatC).shade(-0.3).hex, shirt: shirt, shirt2: PColor(shirt).shade(-0.25).hex,
                      pattern: pick([.plain, .stripes, .floral, .plain], 5), pants: p, pants2: PColor(p).shade(-0.2).hex,
                      shorts: hrand(i, sid, 6) < 0.4, hair: pick(GearItem.hairColors.prefix(5).map { $0 }, 7), skin: pick(GearItem.skinTones, 8))
    }
}

extension Boat {
    /// Big boats can carry paying clients.
    var charter: Bool { big }
}
