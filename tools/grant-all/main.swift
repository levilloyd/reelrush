// Developer cheat for Reel Rush: give a save slot one of everything.
// Built and run by tools/grant-all.sh, which compiles it together with the game's own
// sources (everything except main.swift), so it always matches the current save format.

import Foundation

let domain = ProcessInfo.processInfo.environment["REELRUSH_PREFS_DOMAIN"] ?? "com.reelrush.game"
func key(_ slot: Int) -> String { "ReelRushSave.slot\(slot)" }

func usage(_ code: Int32 = 2) -> Never {
    print("""
    usage:
      tools/grant-all.sh <slot 1-3> [--name NAME]   give the slot one of everything
      tools/grant-all.sh --restore <slot 1-3> <backup.json>   put a backup back

    The slot's current save (name, day, progress) is kept and everything is added on top.
    A backup is written to build/slot<N>-backup-<time>.json before anything changes.
    An empty slot gets a fresh save named ANGLER (or --name).
    """)
    exit(code)
}

guard let defaults = UserDefaults(suiteName: domain) else { print("can't open the game's save storage"); exit(1) }
var args = Array(CommandLine.arguments.dropFirst())
guard !args.isEmpty else { usage() }
if args[0] == "-h" || args[0] == "--help" { usage(0) }

// --restore <slot> <file>
if args[0] == "--restore" {
    guard args.count == 3, let slot = Int(args[1]), (1...3).contains(slot) else { usage() }
    let data = try Data(contentsOf: URL(fileURLWithPath: args[2]))
    let s = try JSONDecoder().decode(SaveData.self, from: data)   // make sure it's a real save
    defaults.set(data, forKey: key(slot))
    defaults.synchronize()
    print("restored slot \(slot) (\(s.playerName), day \(s.day)) from \(args[2])")
    exit(0)
}

guard let slot = Int(args.removeFirst()), (1...3).contains(slot) else { usage() }
var name: String?
while !args.isEmpty {
    let a = args.removeFirst()
    if a == "--name", !args.isEmpty { name = args.removeFirst().uppercased() } else { usage() }
}

// Start from the existing save (keeping its name and progress), backing it up first.
var s = SaveData()
if let old = defaults.data(forKey: key(slot)) {
    let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "")
    let path = "build/slot\(slot)-backup-\(stamp).json"
    try FileManager.default.createDirectory(atPath: "build", withIntermediateDirectories: true)
    try old.write(to: URL(fileURLWithPath: path))
    s = try JSONDecoder().decode(SaveData.self, from: old)
    print("backed up slot \(slot) (\(s.playerName), day \(s.day)) to \(path)")
} else {
    s.playerName = "ANGLER"
    print("slot \(slot) was empty; creating a new save")
}
if let n = name { s.playerName = n }

func addOnce<T: Equatable>(_ list: inout [T], _ items: [T]) { for i in items where !list.contains(i) { list.append(i) } }

// Rods, boats, fish finder, home buildings
addOnce(&s.rodsOwned, Array(Rod.all.indices))
s.rodLevel = Rod.all.firstIndex { $0.name == "Legendary Rod" } ?? s.rodLevel
s.boatShedBuilt = true
s.garageBuilt = true
addOnce(&s.boatsOwned, Boat.all.map { $0.id })
s.hitched = "yacht"
s.fishFinder = true
// Cars and trailers (Big Truck + Big Trailer can tow anything)
addOnce(&s.carsOwned, Car.all.map { $0.id })
s.car = "car.truck"
addOnce(&s.trailers, Trailer.all.map { $0.id })
// Full gas in every car and boat
for id in s.carsOwned + s.boatsOwned { s.fuel[id] = Fuel.tank(id) }
// Every lure and outfit piece, one pack of every bait
for g in GearItem.all {
    if g.slot == .bait { if (s.bait[g.id] ?? 0) == 0 { s.bait[g.id] = g.uses } } else { s.owned.insert(g.id) }
}
// Furniture and home upgrades
for d in Decor.all { s.owned.insert(d.id) }
s.hasFridge = true
s.hasFreezer = true
s.chests = SaveData.maxChests
s.houseLevel = Romance.houseExpansions.count
s.hasWelder = true
s.hasStriker = true
for k in ToolKind.allCases { s.tools[k.rawValue] = Tools.tiers.count - 1 }
// At least one of every good: seeds, produce, food, dishes, ore, gems, bars, timber, stone, the pendant
// (the welder and flint & steel are installed above instead).
for g in Good.all where g.id != "tool.welder" && g.id != "tool.striker" && s.count(g.id) == 0 { s.add(g.id) }
// One of every fish species you don't already have stored, mid-size, in the chests
// (the journal is left for you to fill). Running the tool again doesn't pile up duplicates.
let stored = Set((s.chest + s.cooler + s.fridgeFish + s.freezer).map { $0.id })
for f in FishSpecies.all where !stored.contains(f.id) {
    let t = 0.5
    s.chest.append(CaughtFish(id: f.id, size: f.minSize + (f.maxSize - f.minSize) * t,
                              value: Int((Double(f.baseValue) * (0.8 + 0.7 * t)).rounded())))
}
let room = SaveData.chestSize * s.chests
if s.chest.count > room { print("note: chests over capacity (\(s.chest.count)/\(room)); extra fish are still kept") }

let data = try JSONEncoder().encode(s)
let back = try JSONDecoder().decode(SaveData.self, from: data)
defaults.set(data, forKey: key(slot))
defaults.synchronize()

print("slot \(slot) (\(back.playerName)) now has:")
print("  rods \(back.rodsOwned.count)/\(Rod.all.count) · boats \(back.boatsOwned.count)/\(Boat.all.count) · cars \(back.carsOwned.count)/\(Car.all.count) · trailers \(back.trailers.count)/\(Trailer.all.count) · fish finder")
print("  gear + decor \(back.owned.count) · bait packs \(back.bait.count) · goods \(back.items.count) · fish in chests \(back.chest.count)")
print("  gold tools · house expansions \(back.houseLevel) · chests \(back.chests) · fridge, freezer, welder · boat shed + garage built · full tanks")
print("  towing: \(back.towProblem ?? "ready")")
