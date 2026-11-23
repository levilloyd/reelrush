import Foundation

// MARK: - Habitats

enum Habitat: String, CaseIterable, Codable {
    case pond, lake, river, stream, swamp, ocean, lagoon, deepSea, alpine, cavern, waterfall, hotspring, kelp, trench, atoll

    var displayName: String {
        switch self {
        case .pond: return "Pond"
        case .lake: return "Lake"
        case .river: return "River"
        case .stream: return "Mountain Stream"
        case .swamp: return "Swamp"
        case .ocean: return "Ocean"
        case .lagoon: return "Lagoon"
        case .deepSea: return "Deep Sea"
        case .alpine: return "Alpine Lake"
        case .cavern: return "Cavern Pool"
        case .waterfall: return "Waterfall Pool"
        case .hotspring: return "Hot Spring"
        case .kelp: return "Kelp Forest"
        case .trench: return "Abyssal Trench"
        case .atoll: return "Coral Atoll"
        }
    }

    var spotName: String {
        switch self {
        case .pond: return "Mossy Pond"
        case .lake: return "Pinecrest Lake"
        case .river: return "Willow River"
        case .stream: return "Frostpeak Stream"
        case .swamp: return "Murky Marsh"
        case .ocean: return "Coral Bay"
        case .lagoon: return "Sunset Lagoon"
        case .deepSea: return "Deep Sea Pier"
        case .alpine: return "Glacier Tarn"
        case .cavern: return "Crystal Cavern"
        case .waterfall: return "Misty Falls"
        case .hotspring: return "Ember Springs"
        case .kelp: return "Kelp Forest"
        case .trench: return "Abyssal Trench"
        case .atoll: return "Coral Atoll"
        }
    }

    var water: PColor {
        switch self {
        case .pond: return PColor(0x4E9A86)
        case .lake: return PColor(0x3C8DC8)
        case .river: return PColor(0x4AA0DC)
        case .stream: return PColor(0x6CC4EA)
        case .swamp: return PColor(0x4E6A44)
        case .ocean: return PColor(0x2F78C4)
        case .lagoon: return PColor(0x34C0C8)
        case .deepSea: return PColor(0x1B4A8A)
        case .alpine: return PColor(0x5AC8E0)
        case .cavern: return PColor(0x2A3A6A)
        case .waterfall: return PColor(0x5AB8E0)
        case .hotspring: return PColor(0x6AD8C8)
        case .kelp: return PColor(0x1E5A6A)
        case .trench: return PColor(0x0E1A40)
        case .atoll: return PColor(0x3AE0D8)
        }
    }

    var isFresh: Bool { Habitat.fresh.contains(self) }
    static let fresh: Set<Habitat> = [.pond, .lake, .river, .stream, .swamp, .alpine, .waterfall, .hotspring]
    static let salt: Set<Habitat> = [.ocean, .lagoon, .deepSea, .kelp, .trench, .atoll]
}

// MARK: - Calendar

enum Season: Int, CaseIterable, Codable {
    case spring, summer, fall, winter

    var name: String { ["Spring", "Summer", "Fall", "Winter"][rawValue] }
    var letter: Character { ["P", "S", "F", "W"][rawValue] }
}

enum GameCalendar {
    static let daysPerSeason = 14
    static let weekdays = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

    static func season(_ day: Int) -> Season { Season(rawValue: ((day - 1) / daysPerSeason) % 4)! }
    static func dayOfSeason(_ day: Int) -> Int { (day - 1) % daysPerSeason + 1 }
    static func weekday(_ day: Int) -> String { weekdays[(day - 1) % 7] }
    static func year(_ day: Int) -> Int { (day - 1) / (daysPerSeason * 4) + 1 }
    static func label(_ day: Int) -> String { "\(season(day).name.uppercased()) \(dayOfSeason(day)) · \(weekday(day))" }
}

// MARK: - Time & weather

enum Weather: String, Codable, CaseIterable {
    case sunny, cloudy, rain, storm, fog, snow

    var name: String {
        switch self {
        case .sunny: return "Sunny"
        case .cloudy: return "Cloudy"
        case .rain: return "Rainy"
        case .storm: return "Stormy"
        case .fog: return "Foggy"
        case .snow: return "Snowy"
        }
    }

    var isWet: Bool { self == .rain || self == .storm }

    /// How weather changes feeding (real anglers love overcast & drizzle).
    var activity: Double {
        switch self {
        case .sunny: return 0.95
        case .cloudy: return 1.15
        case .rain: return 1.25
        case .storm: return 0.9
        case .fog: return 1.05
        case .snow: return 0.7
        }
    }

    static func roll(_ season: Season) -> Weather {
        let table: [(Weather, Double)]
        switch season {
        case .spring: table = [(.sunny, 35), (.cloudy, 20), (.rain, 32), (.storm, 6), (.fog, 7)]
        case .summer: table = [(.sunny, 52), (.cloudy, 12), (.rain, 14), (.storm, 16), (.fog, 6)]
        case .fall: table = [(.sunny, 30), (.cloudy, 25), (.rain, 25), (.storm, 5), (.fog, 15)]
        case .winter: table = [(.sunny, 28), (.cloudy, 25), (.snow, 32), (.fog, 12), (.storm, 3)]
        }
        var r = Double.random(in: 0..<table.reduce(0) { $0 + $1.1 })
        for (w, p) in table { if r < p { return w }; r -= p }
        return .sunny
    }
}

enum SkyPhase { case dawn, day, dusk, night }

enum Clock {
    static let minutesPerSecond = 2.0  // one in-game day ≈ 12 real minutes

    static func hour(_ minutes: Double) -> Double { minutes / 60 }

    static func isDay(_ minutes: Double) -> Bool {
        let h = hour(minutes)
        return h >= 6 && h < 19.5
    }

    static func phase(_ minutes: Double) -> SkyPhase {
        switch hour(minutes) {
        case 4.5..<7: return .dawn
        case 7..<17.5: return .day
        case 17.5..<19.75: return .dusk
        default: return .night
        }
    }

    static func timeString(_ minutes: Double) -> String {
        let total = Int(minutes) % 1440
        let h24 = total / 60
        let m = (total % 60) / 10 * 10
        let h12 = h24 % 12 == 0 ? 12 : h24 % 12
        return String(format: "%d:%02d %@", h12, m, h24 < 12 ? "AM" : "PM")
    }

    static func lighting(_ minutes: Double, weather: Weather) -> (PColor, Double) {
        let h = hour(minutes)
        let navy = PColor(0x0B1240), orange = PColor(0xE8743A), pink = PColor(0xC86A7A)
        var c: PColor, a: Double
        switch h {
        case 7..<17: c = navy; a = 0
        case 17..<19: let t = (h - 17) / 2; c = orange; a = 0.2 * t
        case 19..<21: let t = (h - 19) / 2; c = orange.mix(navy, t); a = 0.2 + 0.35 * t
        case 4.5..<7: let t = (h - 4.5) / 2.5; c = navy.mix(pink, t); a = 0.55 * (1 - t) + 0.05 * t
        default: c = navy; a = 0.55
        }
        switch weather {
        case .rain: c = c.mix(PColor(0x2A3440), a < 0.1 ? 1 : 0.4); a = max(a, 0.18)
        case .storm: c = c.mix(PColor(0x1A2430), a < 0.1 ? 1 : 0.5); a = max(a, 0.3)
        case .cloudy, .snow: if a < 0.1 { c = PColor(0x404858); a = 0.08 }
        default: break
        }
        return (c, a)
    }
}

// MARK: - Fish

enum Rarity: Int, CaseIterable {
    case common, uncommon, rare, legendary

    var name: String { ["Common", "Uncommon", "Rare", "Legendary"][rawValue] }
    var baseWeight: Double { [60, 26, 11, 3][rawValue] }

    var color: PColor {
        switch self {
        case .common: return PColor(0xE8ECF0)
        case .uncommon: return PColor(0x6ADC5A)
        case .rare: return PColor(0x5AB4FF)
        case .legendary: return PColor(0xFFC83A)
        }
    }

    var inkColor: PColor {
        switch self {
        case .common: return PColor(0x6A5A4A)
        case .uncommon: return PColor(0x2E8A2A)
        case .rare: return PColor(0x2A64C8)
        case .legendary: return PColor(0xC8781A)
        }
    }
}

/// When a species feeds, modelled on real-world angling patterns.
enum Feeding {
    case dawnDusk, day, night, allDay

    var label: String {
        switch self {
        case .dawnDusk: return "DAWN/DUSK"
        case .day: return "DAYTIME"
        case .night: return "NIGHT"
        case .allDay: return "ALL DAY"
        }
    }

    func activity(_ h: Double) -> Double {
        func g(_ c: Double, _ s: Double) -> Double {
            var d = abs(h - c)
            d = min(d, 24 - d)
            return exp(-(d * d) / (2 * s * s))
        }
        switch self {
        case .dawnDusk: return 0.2 + 1.5 * max(g(6.5, 1.4), g(19, 1.4))
        case .day: return 0.15 + 1.2 * g(12.5, 3.2)
        case .night: return 0.08 + 1.4 * g(0.5, 3.5)
        case .allDay: return 0.6 + 0.5 * max(g(6.5, 1.5), g(19, 1.5))
        }
    }
}

enum Behavior { case smooth, darter, sinker, floater, mixed }
enum FishShape { case normal, long, round, tall, sword, catfish, angler, shark }
enum FishPattern { case plain, stripes, spots }

struct FishSpecies {
    let id: String
    let name: String
    let habitat: Habitat
    let rarity: Rarity
    let minSize: Double
    let maxSize: Double
    let baseValue: Int
    let difficulty: Double
    let behavior: Behavior
    let shape: FishShape
    let pattern: FishPattern
    let body: UInt32
    let belly: UInt32
    let fin: UInt32
    let feeding: Feeding
    let seasons: Set<Season>
    let rainOnly: Bool
    /// Sharks only bite for anglers using a salt-water rod.
    var isShark: Bool { shape == .shark }

    var seasonLabel: String {
        seasons.count == 4 ? "ALL YEAR" : Season.allCases.filter { seasons.contains($0) }.map { ["SPR", "SUM", "FALL", "WIN"][$0.rawValue] }.joined(separator: "/")
    }

    private static func f(_ id: String, _ name: String, _ h: Habitat, _ r: Rarity,
                          _ size: ClosedRange<Double>, _ value: Int, _ diff: Double,
                          _ b: Behavior, _ s: FishShape, _ p: FishPattern,
                          _ body: UInt32, _ belly: UInt32, _ fin: UInt32,
                          _ feed: Feeding, _ seasons: String, rain: Bool = false) -> FishSpecies {
        let set = Set(Season.allCases.filter { seasons.contains($0.letter) })
        return FishSpecies(id: id, name: name, habitat: h, rarity: r, minSize: size.lowerBound, maxSize: size.upperBound,
                           baseValue: value, difficulty: diff, behavior: b, shape: s, pattern: p,
                           body: body, belly: belly, fin: fin, feeding: feed, seasons: set, rainOnly: rain)
    }

    static let all: [FishSpecies] = [
        // Pond
        f("bluegill", "Bluegill", .pond, .common, 12...25, 8, 0.15, .smooth, .round, .stripes, 0x4A7FA8, 0xF2B84B, 0x2E4E6E, .day, "PS"),
        f("pumpkinseed", "Pumpkinseed", .pond, .common, 10...22, 9, 0.20, .mixed, .round, .spots, 0x7FA34A, 0xF08A2E, 0xD9542B, .day, "SF"),
        f("shiner", "Golden Shiner", .pond, .common, 8...18, 6, 0.12, .darter, .long, .plain, 0xD8C050, 0xF8F0C0, 0xA88A2A, .allDay, "PSFW"),
        f("crucian", "Crucian Carp", .pond, .uncommon, 15...40, 22, 0.40, .sinker, .normal, .plain, 0xB8962E, 0xE8D08A, 0x8A6A1E, .allDay, "SF"),
        f("bullhead", "Brown Bullhead", .pond, .uncommon, 20...40, 24, 0.38, .sinker, .catfish, .plain, 0x6A5030, 0xC8B080, 0x3A2A18, .night, "SF"),
        f("crappie", "Black Crappie", .pond, .uncommon, 15...35, 26, 0.42, .floater, .tall, .spots, 0xB8C0A8, 0xEEF0E0, 0x2A3A2A, .dawnDusk, "PW"),
        f("koi", "Koi", .pond, .rare, 30...70, 70, 0.60, .smooth, .normal, .spots, 0xF4F1EA, 0xFFFFFF, 0xE0522D, .day, "SF"),
        f("lotuskoi", "Lotus Koi", .pond, .legendary, 60...100, 400, 0.88, .floater, .normal, .spots, 0xF7C6E0, 0xFFF0F8, 0xD94C9A, .night, "S"),
        // Lake
        f("perch", "Yellow Perch", .lake, .common, 15...30, 10, 0.20, .smooth, .normal, .stripes, 0xC9B23A, 0xF2E9B0, 0x3D4A1E, .day, "PFW"),
        f("lmbass", "Largemouth Bass", .lake, .common, 25...55, 14, 0.30, .mixed, .normal, .plain, 0x5E7D3A, 0xDDE3B5, 0x3D5226, .dawnDusk, "PS"),
        f("rockbass", "Rock Bass", .lake, .common, 15...30, 11, 0.25, .darter, .round, .spots, 0x7A6A3A, 0xD8C8A0, 0xA82A2A, .day, "SF"),
        f("walleye", "Walleye", .lake, .uncommon, 30...70, 30, 0.45, .sinker, .long, .plain, 0xA88E4A, 0xEDE3C0, 0x6B5A2A, .dawnDusk, "FW"),
        f("whitefish", "Lake Whitefish", .lake, .uncommon, 35...60, 28, 0.40, .smooth, .normal, .plain, 0xB8C4CC, 0xF0F4F8, 0x6A7A88, .allDay, "FW"),
        f("pike", "Northern Pike", .lake, .rare, 50...120, 90, 0.65, .darter, .long, .spots, 0x5C7A45, 0xE6EAC8, 0xD6E3A0, .dawnDusk, "PF"),
        f("muskie", "Muskellunge", .lake, .rare, 70...140, 130, 0.78, .darter, .long, .stripes, 0x8A8A5A, 0xE8E4C8, 0x4A4A2A, .dawnDusk, "SF"),
        f("oldwhiskers", "Old Whiskers", .lake, .legendary, 120...250, 500, 0.90, .sinker, .catfish, .plain, 0x4A4A55, 0x9A9AA5, 0x2A2A33, .night, "F", rain: true),
        // River
        f("chub", "Creek Chub", .river, .common, 10...25, 7, 0.15, .smooth, .normal, .plain, 0x9AA5B0, 0xE8ECEF, 0x6E7A85, .allDay, "PSF"),
        f("smbass", "Smallmouth Bass", .river, .common, 25...50, 15, 0.32, .darter, .normal, .stripes, 0x8A7A3A, 0xE0D8A8, 0x4A3F1A, .dawnDusk, "SF"),
        f("shad", "American Shad", .river, .common, 30...55, 12, 0.28, .darter, .normal, .plain, 0xA8B8C8, 0xF0F4F8, 0x5A6A7A, .day, "PW"),
        f("catfish", "Channel Catfish", .river, .uncommon, 35...90, 32, 0.45, .sinker, .catfish, .spots, 0x6F7F8A, 0xDDE2E5, 0x3E4A52, .night, "SF"),
        f("carp", "Common Carp", .river, .uncommon, 40...90, 20, 0.40, .sinker, .normal, .plain, 0xA88A3A, 0xE8D090, 0x7A5A1A, .day, "PS"),
        f("sturgeon", "Lake Sturgeon", .river, .rare, 100...200, 160, 0.74, .sinker, .long, .spots, 0x6A6A6A, 0xC8C8C8, 0x3A3A3A, .night, "PFW"),
        f("salmon", "Chinook Salmon", .river, .rare, 60...120, 95, 0.70, .floater, .normal, .spots, 0x8A9DB0, 0xF0C8C0, 0x3B4E63, .dawnDusk, "F"),
        f("gar", "Alligator Gar", .river, .legendary, 150...280, 520, 0.92, .darter, .long, .spots, 0x6E7A4A, 0xD9D4A8, 0x3E4422, .day, "S"),
        // Mountain stream
        f("brooktrout", "Brook Trout", .stream, .common, 15...30, 12, 0.25, .darter, .normal, .spots, 0x4E6A4A, 0xE8743B, 0xF2E36B, .dawnDusk, "PFW"),
        f("rainbow", "Rainbow Trout", .stream, .common, 25...55, 16, 0.30, .mixed, .normal, .spots, 0x8FA6A0, 0xF2A8B8, 0x3E4A3E, .dawnDusk, "PSF"),
        f("sculpin", "Mottled Sculpin", .stream, .common, 5...15, 6, 0.12, .sinker, .round, .spots, 0x6A6A4A, 0xB8B090, 0x3A3A2A, .night, "PSFW"),
        f("grayling", "Arctic Grayling", .stream, .uncommon, 25...45, 34, 0.50, .floater, .normal, .spots, 0x7A7F9A, 0xD8DAE8, 0x9A6AB8, .day, "SF"),
        f("browntrout", "Brown Trout", .stream, .uncommon, 30...70, 40, 0.55, .darter, .normal, .spots, 0x8A6A3A, 0xF0D890, 0xC83A2A, .night, "FW"),
        f("cutthroat", "Cutthroat Trout", .stream, .rare, 30...70, 85, 0.68, .darter, .normal, .spots, 0xA8A060, 0xF2E0B0, 0xD43A2A, .dawnDusk, "PS"),
        f("steelhead", "Steelhead", .stream, .rare, 60...100, 120, 0.76, .floater, .normal, .spots, 0x8AA0B8, 0xF4E8E8, 0xE87A8A, .dawnDusk, "PW"),
        f("glacierchar", "Glacier Char", .stream, .legendary, 60...110, 480, 0.90, .mixed, .normal, .spots, 0xBFE8F5, 0xFFFFFF, 0x5AB8E0, .night, "W"),
        // Swamp
        f("mudminnow", "Mudminnow", .swamp, .common, 6...14, 7, 0.15, .smooth, .normal, .plain, 0x6A6A3A, 0xA8A070, 0x4A4A28, .allDay, "PSFW"),
        f("bowfin", "Bowfin", .swamp, .common, 40...80, 15, 0.32, .sinker, .long, .spots, 0x5A6A3A, 0xC8C890, 0x2E3A1E, .dawnDusk, "SF"),
        f("warmouth", "Warmouth", .swamp, .common, 12...25, 10, 0.22, .smooth, .round, .spots, 0x6A5A3A, 0xD8B880, 0x8A2A2A, .dawnDusk, "PS"),
        f("snakehead", "Snakehead", .swamp, .uncommon, 40...90, 36, 0.50, .darter, .long, .stripes, 0x6A5A3A, 0xC8B890, 0x3A2A1A, .day, "S"),
        f("pickerel", "Chain Pickerel", .swamp, .uncommon, 30...60, 30, 0.50, .darter, .long, .stripes, 0x6A7A3A, 0xE0E0B0, 0x2E3A1E, .day, "FW"),
        f("swampeel", "Swamp Eel", .swamp, .rare, 50...100, 88, 0.68, .mixed, .long, .plain, 0x4A5A2A, 0xB8B070, 0xD8C84A, .night, "SF"),
        f("flathead", "Flathead Catfish", .swamp, .rare, 60...130, 110, 0.72, .sinker, .catfish, .spots, 0x7A6A3A, 0xD8C8A0, 0x4A3A1A, .night, "S"),
        f("boglurker", "Bog Lurker", .swamp, .legendary, 150...300, 540, 0.92, .sinker, .angler, .spots, 0x3A4A2A, 0x6A7A4A, 0x9AE84A, .night, "F", rain: true),
        // Ocean
        f("sardine", "Sardine", .ocean, .common, 10...22, 6, 0.15, .darter, .long, .plain, 0x6A8DB8, 0xEAF2FA, 0x3A5A85, .day, "PS"),
        f("mackerel", "Mackerel", .ocean, .common, 25...45, 12, 0.30, .smooth, .normal, .stripes, 0x2E7D8A, 0xE6EEF0, 0x1E3E4A, .dawnDusk, "SF"),
        f("flounder", "Flounder", .ocean, .common, 20...45, 13, 0.28, .sinker, .round, .spots, 0x8A7A5A, 0xEEE4D0, 0x5A4A30, .allDay, "FW"),
        f("puffer", "Pufferfish", .ocean, .uncommon, 15...35, 28, 0.42, .floater, .round, .spots, 0xE8C84A, 0xFFF5D0, 0x8A6A1A, .day, "S"),
        f("redsnapper", "Red Snapper", .ocean, .uncommon, 30...70, 40, 0.50, .sinker, .normal, .plain, 0xE05A4A, 0xFFD0C0, 0xA82A2A, .day, "SF"),
        f("stripedbass", "Striped Bass", .ocean, .uncommon, 40...90, 38, 0.52, .darter, .normal, .stripes, 0xB8C0C8, 0xF0F4F8, 0x2A3440, .dawnDusk, "PF"),
        f("barracuda", "Barracuda", .ocean, .rare, 60...150, 100, 0.72, .darter, .long, .stripes, 0x8A9AA8, 0xE8EEF2, 0x2A3A48, .day, "SW"),
        f("blacktip", "Blacktip Reef Shark", .ocean, .uncommon, 90...180, 85, 0.62, .darter, .shark, .plain, 0x7A8A98, 0xEEF2F4, 0x1A1A22, .dawnDusk, "PSF"),
        f("coralqueen", "Coral Queen", .ocean, .legendary, 30...60, 450, 0.88, .mixed, .tall, .stripes, 0x3A6AE8, 0xF2D23A, 0xF2D23A, .day, "P"),
        // Lagoon
        f("butterfly", "Butterflyfish", .lagoon, .common, 10...20, 11, 0.20, .smooth, .tall, .stripes, 0xF2D84A, 0xFFF2B0, 0x2A2A2A, .day, "PSFW"),
        f("parrotfish", "Parrotfish", .lagoon, .common, 30...60, 16, 0.30, .mixed, .normal, .plain, 0x3AC8A0, 0x8AE8F0, 0xE85AA0, .day, "SF"),
        f("sergeant", "Sergeant Major", .lagoon, .common, 10...20, 9, 0.20, .darter, .tall, .stripes, 0xE8E070, 0xF8F8D0, 0x2A2A2A, .day, "PS"),
        f("bluetang", "Blue Tang", .lagoon, .uncommon, 15...30, 34, 0.48, .darter, .tall, .plain, 0x2A5AE8, 0x4A8AF2, 0xF2D23A, .day, "SW"),
        f("trigger", "Triggerfish", .lagoon, .uncommon, 25...50, 36, 0.50, .mixed, .tall, .spots, 0x4A6AA8, 0xD8C890, 0xE8A03A, .day, "FW"),
        f("bonefish", "Bonefish", .lagoon, .rare, 40...80, 95, 0.74, .darter, .normal, .plain, 0xC8D0D8, 0xF4F8FC, 0x7A8A9A, .dawnDusk, "PS"),
        f("lionfish", "Lionfish", .lagoon, .rare, 20...40, 92, 0.70, .floater, .tall, .stripes, 0xE8E0D0, 0xFFF4E8, 0xC83A2A, .night, "FW"),
        f("lemonshark", "Lemon Shark", .lagoon, .uncommon, 150...280, 90, 0.60, .smooth, .shark, .plain, 0xC8B870, 0xF4F0D8, 0x9A8A4A, .dawnDusk, "PSF"),
        f("sunsetmarlin", "Sunset Marlin", .lagoon, .legendary, 200...400, 560, 0.93, .darter, .sword, .stripes, 0xE86A3A, 0xFFD0A0, 0x6A2AA8, .dawnDusk, "S"),
        // Deep sea
        f("cod", "Atlantic Cod", .deepSea, .common, 40...90, 18, 0.30, .sinker, .normal, .spots, 0x9A8A6A, 0xEDE6D6, 0x5A4E3A, .allDay, "FW"),
        f("haddock", "Haddock", .deepSea, .common, 35...70, 15, 0.28, .sinker, .normal, .plain, 0x7A7A82, 0xE8E8EC, 0x2A2A30, .day, "PW"),
        f("tuna", "Bluefin Tuna", .deepSea, .uncommon, 100...250, 60, 0.55, .smooth, .normal, .plain, 0x1E3A6A, 0xD8E0EA, 0xE8C83A, .dawnDusk, "S"),
        f("halibut", "Pacific Halibut", .deepSea, .uncommon, 80...200, 70, 0.60, .sinker, .round, .spots, 0x6A5A40, 0xF0EEE8, 0x4A3A28, .allDay, "PS"),
        f("mahimahi", "Mahi-Mahi", .deepSea, .uncommon, 80...150, 65, 0.62, .darter, .normal, .spots, 0x3AA86A, 0xF2D23A, 0x2A6AC8, .day, "S"),
        f("swordfish", "Swordfish", .deepSea, .rare, 150...400, 150, 0.75, .darter, .sword, .plain, 0x3A4A7A, 0xCDD6E8, 0x22305A, .night, "SF"),
        f("angler", "Anglerfish", .deepSea, .rare, 30...100, 130, 0.70, .sinker, .angler, .plain, 0x3A2E3A, 0x5A4A5A, 0xF2E85A, .night, "FW"),
        f("greatwhite", "Great White Shark", .deepSea, .legendary, 400...600, 1300, 0.96, .mixed, .shark, .plain, 0x6A727A, 0xF4F4F4, 0x4A5058, .dawnDusk, "SF"),
        f("oarfish", "Leviathan Oarfish", .deepSea, .legendary, 300...800, 800, 0.95, .mixed, .long, .plain, 0xC8D0DA, 0xEEF2F6, 0xE8453A, .night, "W", rain: false),
        // Glacier Tarn (alpine)
        f("alpminnow", "Alpine Minnow", .alpine, .common, 5...12, 8, 0.12, .smooth, .long, .plain, 0x8AA0A8, 0xE0E8EC, 0x4A5A62, .allDay, "PSF"),
        f("goldentrout", "Golden Trout", .alpine, .common, 20...40, 18, 0.30, .darter, .normal, .spots, 0xD8B040, 0xF08A3A, 0x6A8A3A, .dawnDusk, "SF"),
        f("laketrout", "Lake Trout", .alpine, .common, 40...80, 16, 0.30, .sinker, .normal, .spots, 0x5A6A6A, 0xD8DCD8, 0xC8C8B0, .allDay, "FW"),
        f("arcticchar", "Arctic Char", .alpine, .uncommon, 30...60, 38, 0.50, .mixed, .normal, .spots, 0x5A6A8A, 0xE85A3A, 0xF0E8D8, .night, "WP"),
        f("kokanee", "Kokanee", .alpine, .uncommon, 25...45, 32, 0.45, .floater, .normal, .plain, 0xC83A3A, 0xE8D0C0, 0x3A6A3A, .dawnDusk, "F"),
        f("burbot", "Burbot", .alpine, .uncommon, 40...80, 30, 0.50, .sinker, .catfish, .spots, 0x6A5A3A, 0xC8B890, 0x3A2A18, .night, "W"),
        f("tigertrout", "Tiger Trout", .alpine, .rare, 40...70, 110, 0.72, .darter, .normal, .stripes, 0xA89A5A, 0xF0E0B0, 0x4A3A1A, .dawnDusk, "PS"),
        f("snowfang", "Snowfang", .alpine, .legendary, 100...180, 600, 0.93, .darter, .long, .spots, 0xE8F2FA, 0xFFFFFF, 0x5AA8E8, .night, "W"),
        // Crystal Cavern (in the mine)
        f("cavefish", "Cave Fish", .cavern, .common, 6...14, 12, 0.18, .smooth, .normal, .plain, 0xF0D8D8, 0xFFF0F0, 0xE0B8B8, .allDay, "PSFW"),
        f("blindeel", "Blind Eel", .cavern, .common, 30...60, 16, 0.30, .mixed, .long, .plain, 0xD8C8D0, 0xF0E8EC, 0x9A8A92, .allDay, "PSFW"),
        f("stonefish", "Stonefish", .cavern, .common, 15...35, 14, 0.30, .sinker, .round, .spots, 0x7A6A5A, 0xA89A8A, 0x4A3A2A, .allDay, "PSFW"),
        f("glassperch", "Glass Perch", .cavern, .uncommon, 15...30, 40, 0.50, .darter, .normal, .plain, 0xC8E8F0, 0xE8F8FC, 0x8AC8E0, .allDay, "PSFW"),
        f("lavaeel", "Lava Eel", .cavern, .uncommon, 40...80, 55, 0.58, .darter, .long, .spots, 0xE84A2A, 0xFFB04A, 0x8A1A0A, .allDay, "PSFW"),
        f("crystalcarp", "Crystal Carp", .cavern, .rare, 40...80, 120, 0.70, .smooth, .normal, .spots, 0x9A6AE8, 0xD8C8FF, 0x5AE8E8, .allDay, "PSFW"),
        f("voidsalmon", "Void Salmon", .cavern, .rare, 50...90, 140, 0.76, .floater, .normal, .plain, 0x3A2A5A, 0x6A5A8A, 0xC83AE8, .allDay, "PSFW"),
        f("gemscale", "Gemscale Leviathan", .cavern, .legendary, 150...300, 900, 0.95, .mixed, .long, .spots, 0x2AC8A0, 0xA8F8E8, 0xE83A8A, .allDay, "PSFW"),
        // Misty Falls (waterfall pool)
        f("fallsdace", "Falls Dace", .waterfall, .common, 8...16, 9, 0.15, .darter, .long, .plain, 0x9AB0A8, 0xE8F0EC, 0x5A7068, .allDay, "PSF"),
        f("spottedbass", "Spotted Bass", .waterfall, .common, 20...45, 15, 0.30, .mixed, .normal, .spots, 0x6A8A4A, 0xE0E8C0, 0x3A4A2A, .dawnDusk, "SFW"),
        f("misttrout", "Mist Trout", .waterfall, .uncommon, 25...50, 42, 0.50, .darter, .normal, .spots, 0xA8C8D8, 0xF0F8FC, 0x6A98B8, .dawnDusk, "PSF"),
        f("climbgoby", "Climbing Goby", .waterfall, .uncommon, 8...14, 38, 0.48, .sinker, .round, .spots, 0x8A7A6A, 0xD8C8B0, 0x4A3A2A, .day, "PSW"),
        f("rainbowshiner", "Rainbow Shiner", .waterfall, .rare, 10...18, 110, 0.70, .darter, .long, .stripes, 0xE85AA0, 0x8AE8F0, 0xF2D23A, .day, "S"),
        f("cascadeking", "Cascade King", .waterfall, .legendary, 80...140, 650, 0.93, .floater, .normal, .spots, 0x3AC8E8, 0xF0FCFF, 0xFFD23A, .dawnDusk, "P"),
        // Ember Springs (hot spring)
        f("tilapia", "Warm Tilapia", .hotspring, .common, 15...35, 12, 0.20, .smooth, .normal, .plain, 0x8A9AA0, 0xE0E8EC, 0x5A6A70, .allDay, "PSFW"),
        f("steamguppy", "Steam Guppy", .hotspring, .common, 3...6, 10, 0.15, .darter, .round, .plain, 0xF28A3A, 0xFFE0B0, 0x3AA8E8, .allDay, "PSFW"),
        f("sulfurcat", "Sulfur Catfish", .hotspring, .uncommon, 30...70, 45, 0.50, .sinker, .catfish, .spots, 0xC8B83A, 0xF2EAB0, 0x6A5A1A, .night, "PSFW"),
        f("pupfish", "Ember Pupfish", .hotspring, .uncommon, 4...8, 40, 0.50, .darter, .round, .plain, 0x3A6AE8, 0x8AC8FF, 0x1A3AA8, .day, "FW"),
        f("thermaleel", "Thermal Eel", .hotspring, .rare, 40...90, 120, 0.74, .mixed, .long, .plain, 0xE84A2A, 0xF2A070, 0x8A1A0A, .night, "FW"),
        f("phoenixkoi", "Phoenix Koi", .hotspring, .legendary, 60...100, 700, 0.94, .floater, .normal, .spots, 0xFF6A2A, 0xFFE08A, 0xFFD23A, .day, "W"),
        // Kelp Forest (deep sea zone)
        f("kelpbass", "Kelp Bass", .kelp, .common, 25...55, 18, 0.30, .mixed, .normal, .spots, 0x6A5A3A, 0xD8C8A0, 0x3A2A1A, .allDay, "PSF"),
        f("garibaldi", "Garibaldi", .kelp, .common, 15...30, 20, 0.28, .smooth, .tall, .plain, 0xFF7A1A, 0xFFB04A, 0xE85A0A, .day, "PSFW"),
        f("sheephead", "Sheephead", .kelp, .uncommon, 40...90, 50, 0.52, .sinker, .normal, .stripes, 0x2A2A30, 0xE8E8E8, 0xC83A3A, .day, "SF"),
        f("lingcod", "Lingcod", .kelp, .uncommon, 60...150, 65, 0.60, .sinker, .long, .spots, 0x6A7A5A, 0xC8D0B0, 0x3A4A2A, .dawnDusk, "FW"),
        f("seabass", "Giant Sea Bass", .kelp, .rare, 150...250, 220, 0.80, .sinker, .normal, .spots, 0x3A3A44, 0x8A8A94, 0x1A1A20, .night, "SF"),
        f("leopardshark", "Leopard Shark", .kelp, .uncommon, 100...180, 70, 0.55, .smooth, .shark, .spots, 0x9A8A6A, 0xE8E0D0, 0x3A2A1A, .night, "PSF"),
        f("mako", "Shortfin Mako", .kelp, .rare, 200...350, 240, 0.85, .darter, .shark, .plain, 0x2A4A8A, 0xE8EEF4, 0x1A2A5A, .day, "SFW"),
        f("kelpwraith", "Kelp Wraith", .kelp, .legendary, 100...200, 900, 0.95, .mixed, .long, .plain, 0x5AE8A0, 0xD8FFE8, 0x2AA86A, .night, "F"),
        // Abyssal Trench (deep sea zone)
        f("lanternfish", "Lanternfish", .trench, .common, 5...15, 20, 0.25, .darter, .normal, .spots, 0x2A2A4A, 0x5A5A8A, 0x8AF2FF, .allDay, "PSFW"),
        f("gulper", "Gulper Eel", .trench, .common, 50...150, 28, 0.35, .mixed, .long, .plain, 0x1A1A2A, 0x3A3A5A, 0x8A3AE8, .allDay, "PSFW"),
        f("fangtooth", "Fangtooth", .trench, .uncommon, 10...20, 60, 0.55, .darter, .round, .plain, 0x2A1A2A, 0x5A3A4A, 0xE8E8E8, .allDay, "PSFW"),
        f("barreleye", "Barreleye", .trench, .uncommon, 10...20, 70, 0.55, .floater, .normal, .plain, 0x3A4A5A, 0x9AB8C8, 0x5AF2A0, .allDay, "PSFW"),
        f("viperfish", "Viperfish", .trench, .rare, 20...35, 180, 0.80, .darter, .long, .spots, 0x1A2A3A, 0x4A6A7A, 0x5AE8FF, .night, "PSFW"),
        f("goblinshark", "Goblin Shark", .trench, .rare, 250...400, 320, 0.86, .sinker, .shark, .plain, 0xD8A0A8, 0xF2D8DC, 0x9A6A72, .night, "PSFW"),
        f("abyssking", "The Abyss King", .trench, .legendary, 400...900, 1500, 0.97, .sinker, .angler, .spots, 0x14141E, 0x2A2A3A, 0xE83A3A, .night, "PSFW"),
        // Coral Atoll on Paradise Isle (rare fish only)
        f("atollsnapper", "Atoll Snapper", .atoll, .uncommon, 25...50, 60, 0.50, .smooth, .normal, .plain, 0xE86A6A, 0xFFD0C0, 0xC83A3A, .day, "PSFW"),
        f("clowntrigger", "Clown Triggerfish", .atoll, .uncommon, 25...45, 80, 0.55, .mixed, .tall, .spots, 0x1A1A2A, 0xF2E85A, 0xFFFFFF, .day, "PSFW"),
        f("napoleon", "Napoleon Wrasse", .atoll, .rare, 100...200, 260, 0.78, .sinker, .tall, .spots, 0x3AA8A0, 0x8AE8D8, 0x2A5A8A, .day, "SF"),
        f("goldtrevally", "Golden Trevally", .atoll, .rare, 60...120, 240, 0.80, .darter, .normal, .stripes, 0xF2D23A, 0xFFF4B0, 0x2A2A2A, .dawnDusk, "PSW"),
        f("moorishidol", "Moorish Idol", .atoll, .rare, 15...25, 200, 0.76, .floater, .tall, .stripes, 0xF2E85A, 0xFFFFFF, 0x1A1A1A, .day, "PSFW"),
        f("whitetip", "Oceanic Whitetip", .atoll, .rare, 200...300, 300, 0.82, .darter, .shark, .plain, 0x6A6A5A, 0xE8E8E0, 0xF4F4F4, .day, "PSFW"),
        f("tigershark", "Tiger Shark", .atoll, .rare, 250...450, 280, 0.84, .sinker, .shark, .stripes, 0x6A7A6A, 0xE8E8E0, 0x3A4A3A, .night, "SF"),
        f("islandspirit", "Island Spirit", .atoll, .legendary, 80...150, 1200, 0.95, .mixed, .sword, .spots, 0x5AE8FF, 0xFFFFFF, 0xFF5AC8, .night, "PSFW"),
    ]

    static let byID: [String: FishSpecies] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static func inHabitat(_ h: Habitat) -> [FishSpecies] { all.filter { $0.habitat == h } }

    /// Species that can actually bite here with the current rod (sharks need a salt-water rod).
    static func biting(_ h: Habitat, saltRod: Bool) -> [FishSpecies] { inHabitat(h).filter { saltRod || !$0.isShark } }

    /// How eager this species is to bite right now (0 = won't bite).
    func eagerness(minutes: Double, weather: Weather, day: Int) -> Double {
        let season = GameCalendar.season(day)
        if rarity == .legendary && !seasons.contains(season) { return 0 }
        if rainOnly && !weather.isWet { return 0 }
        // Out of season, fish are scarce: commons still turn up occasionally, others very rarely.
        let seasonal = seasons.contains(season) ? 1.6 : (rarity == .common ? 0.3 : 0.1)
        return feeding.activity(Clock.hour(minutes)) * seasonal * weather.activity
    }

    /// Overall bite activity for a habitat (≈0.2 dead … 1.6 hot).
    static func activity(_ h: Habitat, minutes: Double, weather: Weather, day: Int, saltRod: Bool = false) -> Double {
        let pool = biting(h, saltRod: saltRod)
        let total = pool.reduce(0.0) { $0 + $1.rarity.baseWeight * $1.eagerness(minutes: minutes, weather: weather, day: day) }
        let base = pool.reduce(0.0) { $0 + $1.rarity.baseWeight }
        return total / base
    }

    static func activityLabel(_ a: Double) -> (String, PColor) {
        switch a {
        case ..<0.45: return ("SLOW", PColor(0xC8483A))
        case ..<0.8: return ("FAIR", PColor(0xE8A83A))
        case ..<1.15: return ("GOOD", PColor(0x6ADC5A))
        default: return ("HOT!", PColor(0x5AE8FF))
        }
    }

    /// Probability of each species biting right now (sums to 1).
    static func chances(_ h: Habitat, luck: Double, minutes: Double, weather: Weather, day: Int, saltRod: Bool = false) -> [(FishSpecies, Double)] {
        let pool = biting(h, saltRod: saltRod)
        let w = weights(pool, luck: luck, weather: weather, minutes: minutes, day: day)
        let total = max(0.0001, w.reduce(0, +))
        return zip(pool, w).map { ($0, $1 / total) }
    }

    private static func weights(_ pool: [FishSpecies], luck: Double, weather: Weather, minutes: Double, day: Int) -> [Double] {
        pool.map {
            var w: Double
            switch $0.rarity {
            case .common: w = 60 * (1 - min(0.6, luck))
            case .uncommon: w = 26 * (1 + luck)
            case .rare: w = 11 * (1 + luck * 3)
            case .legendary: w = 3 * (1 + luck * 5)
            }
            switch weather {
            case .storm: if $0.rarity == .legendary { w *= 2 } else if $0.rarity == .rare { w *= 1.5 }
            case .rain: if $0.rarity == .rare { w *= 1.25 }
            case .fog: if $0.rarity == .rare { w *= 1.3 } else if $0.rarity == .uncommon { w *= 1.2 }
            default: break
            }
            return w * $0.eagerness(minutes: minutes, weather: weather, day: day)
        }
    }

    static func pick(for h: Habitat, luck: Double, minutes: Double, weather: Weather, day: Int, allowLegendary: Bool = true, saltRod: Bool = false) -> FishSpecies {
        let pool = biting(h, saltRod: saltRod).filter { allowLegendary || $0.rarity != .legendary }
        let weights: [Double] = pool.map {
            var w: Double
            switch $0.rarity {
            case .common: w = 60 * (1 - min(0.6, luck))
            case .uncommon: w = 26 * (1 + luck)
            case .rare: w = 11 * (1 + luck * 3)
            case .legendary: w = 3 * (1 + luck * 5)
            }
            switch weather {
            case .storm: if $0.rarity == .legendary { w *= 2 } else if $0.rarity == .rare { w *= 1.5 }
            case .rain: if $0.rarity == .rare { w *= 1.25 }
            case .fog: if $0.rarity == .rare { w *= 1.3 } else if $0.rarity == .uncommon { w *= 1.2 }
            default: break
            }
            return w * $0.eagerness(minutes: minutes, weather: weather, day: day)
        }
        let total = weights.reduce(0, +)
        guard total > 0 else { return pool[0] }
        var roll = Double.random(in: 0..<total)
        for (i, w) in weights.enumerated() {
            if roll < w { return pool[i] }
            roll -= w
        }
        return pool[0]
    }

    func weightKg(_ cm: Double) -> Double {
        let k: Double
        switch shape {
        case .long: k = 0.6e-5
        case .round: k = 2.2e-5
        case .tall: k = 1.8e-5
        case .sword: k = 0.9e-5
        case .catfish: k = 1.2e-5
        case .angler: k = 2.0e-5
        case .shark: k = 1.1e-5
        case .normal: k = 1.4e-5
        }
        return k * cm * cm * cm
    }
}

// MARK: - Market

enum Market {
    /// Seasonal + daily price multiplier for a species.
    static func multiplier(_ s: FishSpecies, day: Int) -> Double {
        let season = GameCalendar.season(day)
        var m = s.seasons.contains(season) ? 0.85 : 1.3
        if s.seasons.count == 4 { m = 1.0 }
        if season == .winter { m *= 1.1 }
        let sid = s.id.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        m *= 1 + (hrand(day, sid, 77) * 0.3 - 0.15)
        return m
    }

    static func price(_ c: CaughtFish, day: Int, sellBonus: Double) -> Int {
        guard let s = FishSpecies.byID[c.id] else { return c.value }
        return Int((Double(c.value) * multiplier(s, day: day) * (1 + sellBonus) * c.freshness).rounded())
    }
}

// MARK: - Rods & boats

struct Rod {
    let name: String
    let price: Int
    let barSize: Double
    let reelSpeed: Double
    let luck: Double
    let blurb: String
    let color: UInt32
    var specialty: Set<Habitat>? = nil
    var winter = false
    var specialtyLabel = "ALL-ROUNDER"

    /// Salt-water specialists (Surf Caster, Deep Sea Rod) are strong enough to land sharks.
    var isSaltwater: Bool { specialty.map { !$0.isEmpty && $0.isSubset(of: Habitat.salt) } ?? false }

    /// Effective stats in a given water. Specialists shine in their waters and struggle elsewhere.
    func stats(_ h: Habitat, season: Season) -> (bar: Double, reel: Double, luck: Double, special: Bool?) {
        guard let spec = specialty else { return (barSize, reelSpeed, luck, nil) }
        let good = spec.contains(h) || (winter && season == .winter)
        return good ? (barSize + 0.08, reelSpeed * 1.2, luck + 0.06, true) : (barSize - 0.04, reelSpeed * 0.9, luck, false)
    }

    static let all: [Rod] = [
        Rod(name: "Twig Rod", price: 0, barSize: 0.22, reelSpeed: 1.0, luck: 0.0, blurb: "A stick with string. It works... mostly.", color: 0x8A6A3A),
        Rod(name: "Bamboo Rod", price: 150, barSize: 0.26, reelSpeed: 1.08, luck: 0.04, blurb: "Light and springy. A bigger catch zone.", color: 0xC9B25A),
        Rod(name: "Fiberglass Rod", price: 600, barSize: 0.30, reelSpeed: 1.16, luck: 0.08, blurb: "Sturdy and reliable. Rare fish notice.", color: 0x4AA8FF),
        Rod(name: "Carbon Pro", price: 1800, barSize: 0.33, reelSpeed: 1.26, luck: 0.13, blurb: "Pro sensitivity. Reels in fast.", color: 0x4A4A5E),
        Rod(name: "Legendary Rod", price: 5000, barSize: 0.37, reelSpeed: 1.36, luck: 0.20, blurb: "Forged for catching legends.", color: 0xFFC83A),
        Rod(name: "Fly Rod", price: 900, barSize: 0.27, reelSpeed: 1.1, luck: 0.06, blurb: "Delicate casts for trout water.", color: 0x6AC85A,
            specialty: [.stream, .river, .alpine], specialtyLabel: "STREAMS, RIVERS & ALPINE"),
        Rod(name: "Surf Caster", price: 1100, barSize: 0.28, reelSpeed: 1.12, luck: 0.06, blurb: "Long casts past the breakers. Lands sharks!", color: 0x3AC8C8,
            specialty: [.ocean, .lagoon], specialtyLabel: "OCEAN & LAGOON"),
        Rod(name: "Deep Sea Rod", price: 2400, barSize: 0.30, reelSpeed: 1.18, luck: 0.1, blurb: "Built to winch up giants - even sharks!", color: 0x2A3A8A,
            specialty: [.deepSea, .ocean], specialtyLabel: "DEEP SEA & OCEAN"),
        Rod(name: "Bayou Baitcaster", price: 700, barSize: 0.27, reelSpeed: 1.1, luck: 0.05, blurb: "Hauls bass out of the weeds.", color: 0x7A8A3A,
            specialty: [.swamp, .pond, .lake], specialtyLabel: "SWAMP, POND & LAKE"),
        Rod(name: "Ice Rod", price: 1400, barSize: 0.28, reelSpeed: 1.12, luck: 0.07, blurb: "Short and stiff for cold, dark water.", color: 0xBFE8F5,
            specialty: [.alpine, .cavern], winter: true, specialtyLabel: "ALPINE, CAVERN & ANY WATER IN WINTER"),
    ]
}

enum BoatKind: String { case kayak, row, skiff, bass, pontoon, trawler, yacht }

struct Boat {
    let kind: BoatKind
    let name: String
    let price: Int
    let speed: Double
    let waters: Set<Habitat>
    let sizeBonus: Double
    let extraChance: Double
    let capacity: Int
    let big: Bool
    let watersLabel: String
    let blurb: String

    var id: String { kind.rawValue }

    static let all: [Boat] = [
        Boat(kind: .kayak, name: "Kayak", price: 250, speed: 190, waters: Habitat.fresh, sizeBonus: 0.08, extraChance: 0.1, capacity: 25, big: false,
             watersLabel: "Fresh water", blurb: "Quick and quiet. Sneak up on spooky fish."),
        Boat(kind: .row, name: "Rowboat", price: 400, speed: 150, waters: Habitat.fresh, sizeBonus: 0.15, extraChance: 0.2, capacity: 30, big: false,
             watersLabel: "Fresh water", blurb: "Paddle out to the middle where the big ones hide."),
        Boat(kind: .skiff, name: "Motor Skiff", price: 1500, speed: 230, waters: Habitat.fresh.union([.ocean, .lagoon]), sizeBonus: 0.3,
             extraChance: 0.35, capacity: 45, big: false, watersLabel: "Fresh + ocean & lagoon", blurb: "Zippy outboard. Handles the open bay."),
        Boat(kind: .bass, name: "Bass Boat", price: 2200, speed: 280, waters: Habitat.fresh, sizeBonus: 0.38, extraChance: 0.4, capacity: 45, big: false,
             watersLabel: "Fresh water only", blurb: "Glitter-red speedster built for lake trophies."),
        Boat(kind: .pontoon, name: "Pontoon", price: 3000, speed: 140, waters: Habitat.fresh, sizeBonus: 0.2, extraChance: 0.5, capacity: 90, big: true,
             watersLabel: "Fresh water", blurb: "Slow, comfy, and a gigantic cooler."),
        Boat(kind: .trawler, name: "Trawler", price: 4500, speed: 260, waters: Set(Habitat.allCases), sizeBonus: 0.45, extraChance: 0.55,
             capacity: 70, big: true, watersLabel: "Everywhere + deep sea", blurb: "A real fishing vessel. Nets bring bonus fish."),
        Boat(kind: .yacht, name: "Luxury Yacht", price: 12000, speed: 320, waters: Set(Habitat.allCases), sizeBonus: 0.5, extraChance: 0.6,
             capacity: 100, big: true, watersLabel: "Everywhere", blurb: "The finest boat in the valley."),
    ]
    static let byID: [String: Boat] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
}

// MARK: - Vehicles

struct Car {
    let id: String
    let name: String
    let price: Int
    let speed: Double
    let tow: Int  // 0 can't tow, 1 small trailer, 2 any trailer
    let body: UInt32
    let blurb: String

    static let all: [Car] = [
        Car(id: "car.pickup", name: "Old Pickup", price: 1200, speed: 430, tow: 1, body: 0x9A5A2A, blurb: "Rusty but trusty. Tows small trailers."),
        Car(id: "car.jeep", name: "Trail Jeep", price: 2500, speed: 470, tow: 1, body: 0x4E7A3A, blurb: "Fast on grass and dirt. Tows small trailers."),
        Car(id: "car.truck", name: "Big Truck", price: 4000, speed: 470, tow: 2, body: 0x2A5AA8, blurb: "Tows any trailer, even yachts."),
        Car(id: "car.coupe", name: "Sports Coupe", price: 6000, speed: 680, tow: 0, body: 0xE83A3A, blurb: "Blazing fast. Can't tow anything."),
    ]
    static let byID: [String: Car] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
}

struct Trailer {
    let id: String
    let name: String
    let price: Int
    let size: Int  // 1 small boats, 2 big boats
    static let all: [Trailer] = [
        Trailer(id: "trailer.small", name: "Small Trailer", price: 600, size: 1),
        Trailer(id: "trailer.big", name: "Big Trailer", price: 2500, size: 2),
    ]
}

// MARK: - Gear (lures, bait, clothes)

enum Slot: String, Codable, CaseIterable {
    case lure, bait, hat, shirt, pants
    var title: String { ["LURES", "BAIT", "HATS", "SHIRTS", "PANTS"][Slot.allCases.firstIndex(of: self)!] }
}

enum HatStyle: Int { case bucket, straw, cap, beanie, wizard }
enum ShirtPattern: Int { case plain, plaid, stripes, floral }

enum Cond {
    case always, day, night, wet, snow, boat
    case waters(Set<Habitat>)
}

struct Effect {
    var bite = 1.0
    var luck = 0.0
    var size = 0.0
    var bar = 0.0
    var sell = 0.0
    var cond: Cond = .always
}

struct GearItem {
    let id: String
    let name: String
    let slot: Slot
    let price: Int
    let uses: Int  // bait pack size; 0 = permanent
    let perk: String
    let effect: Effect
    let c1: UInt32
    let c2: UInt32
    let style: Int

    static let all: [GearItem] = [
        // Lures
        GearItem(id: "lure.spinner", name: "Spinner", slot: .lure, price: 120, uses: 0, perk: "Bites 20% faster everywhere.",
                 effect: Effect(bite: 0.8), c1: 0xD8DCE4, c2: 0xE83A3A, style: 0),
        GearItem(id: "lure.crank", name: "Crankbait", slot: .lure, price: 350, uses: 0, perk: "+15% fish size in fresh water.",
                 effect: Effect(size: 0.15, cond: .waters(Habitat.fresh)), c1: 0x6AC83A, c2: 0xF2D23A, style: 1),
        GearItem(id: "lure.fly", name: "Dry Fly", slot: .lure, price: 300, uses: 0, perk: "Much faster bites + luck in streams & rivers.",
                 effect: Effect(bite: 0.65, luck: 0.05, cond: .waters([.stream, .river])), c1: 0xC8A06A, c2: 0x6A3A1A, style: 2),
        GearItem(id: "lure.jig", name: "Deep Jig", slot: .lure, price: 600, uses: 0, perk: "+20% size & luck in salt water.",
                 effect: Effect(luck: 0.05, size: 0.2, cond: .waters(Habitat.salt)), c1: 0xE85AA0, c2: 0x3A3A44, style: 3),
        GearItem(id: "lure.glow", name: "Glow Lure", slot: .lure, price: 500, uses: 0, perk: "At night: 40% faster bites, rarer fish.",
                 effect: Effect(bite: 0.6, luck: 0.08, cond: .night), c1: 0x8AFF6A, c2: 0x2A6A3A, style: 4),
        GearItem(id: "lure.golden", name: "Golden Spoon", slot: .lure, price: 2500, uses: 0, perk: "+Luck and +10% size everywhere.",
                 effect: Effect(luck: 0.12, size: 0.1), c1: 0xFFD23A, c2: 0xC8961E, style: 5),
        // Bait
        GearItem(id: "bait.worm", name: "Worms", slot: .bait, price: 30, uses: 15, perk: "Bites 25% faster in fresh water.",
                 effect: Effect(bite: 0.75, cond: .waters(Habitat.fresh)), c1: 0xE88A8A, c2: 0x6A4A2A, style: 0),
        GearItem(id: "bait.minnow", name: "Minnows", slot: .bait, price: 60, uses: 15, perk: "Attracts bigger predators (+12% size).",
                 effect: Effect(luck: 0.03, size: 0.12), c1: 0xC8D0D8, c2: 0x5A8AC8, style: 1),
        GearItem(id: "bait.shrimp", name: "Shrimp", slot: .bait, price: 60, uses: 15, perk: "Bites 30% faster in salt water.",
                 effect: Effect(bite: 0.7, cond: .waters(Habitat.salt)), c1: 0xF2A07A, c2: 0xC85A3A, style: 2),
        GearItem(id: "bait.crawler", name: "Nightcrawlers", slot: .bait, price: 80, uses: 15, perk: "At night: bites 40% faster.",
                 effect: Effect(bite: 0.6, cond: .night), c1: 0x8A4A5A, c2: 0x3A2A1A, style: 3),
        GearItem(id: "bait.magic", name: "Magic Bait", slot: .bait, price: 400, uses: 10, perk: "Legendary & rare fish far more likely.",
                 effect: Effect(bite: 0.8, luck: 0.15), c1: 0xC86AE8, c2: 0xFFD23A, style: 4),
        // Hats
        GearItem(id: "hat.bucket", name: "Bucket Hat", slot: .hat, price: 0, uses: 0, perk: "A trusty classic.",
                 effect: Effect(), c1: 0x4E8A3A, c2: 0xE8C05A, style: HatStyle.bucket.rawValue),
        GearItem(id: "hat.straw", name: "Straw Hat", slot: .hat, price: 100, uses: 0, perk: "Daytime: bites 10% faster.",
                 effect: Effect(bite: 0.9, cond: .day), c1: 0xE8C870, c2: 0xC83A2A, style: HatStyle.straw.rawValue),
        GearItem(id: "hat.captain", name: "Captain's Cap", slot: .hat, price: 400, uses: 0, perk: "On a boat: +8% fish size.",
                 effect: Effect(size: 0.08, cond: .boat), c1: 0xF0F0F0, c2: 0x1E2A5A, style: HatStyle.cap.rawValue),
        GearItem(id: "hat.beanie", name: "Cozy Beanie", slot: .hat, price: 120, uses: 0, perk: "In snow: bites 20% faster.",
                 effect: Effect(bite: 0.8, cond: .snow), c1: 0xC83A3A, c2: 0xF0F0F0, style: HatStyle.beanie.rawValue),
        GearItem(id: "hat.lucky", name: "Lucky Cap", slot: .hat, price: 800, uses: 0, perk: "+5% luck everywhere.",
                 effect: Effect(luck: 0.05), c1: 0x2E9A3A, c2: 0xFFD23A, style: HatStyle.cap.rawValue),
        GearItem(id: "hat.wizard", name: "Wizard Hat", slot: .hat, price: 3000, uses: 0, perk: "At night: +10% luck.",
                 effect: Effect(luck: 0.1, cond: .night), c1: 0x5A3AA8, c2: 0xFFD23A, style: HatStyle.wizard.rawValue),
        // Shirts
        GearItem(id: "shirt.vest", name: "Fishing Vest", slot: .shirt, price: 0, uses: 0, perk: "Lots of pockets.",
                 effect: Effect(), c1: 0xE8722E, c2: 0xB8521E, style: ShirtPattern.plain.rawValue),
        GearItem(id: "shirt.flannel", name: "Flannel", slot: .shirt, price: 150, uses: 0, perk: "Cozy. Purely stylish.",
                 effect: Effect(), c1: 0xC83A2A, c2: 0x2A1A1A, style: ShirtPattern.plaid.rawValue),
        GearItem(id: "shirt.slicker", name: "Rain Slicker", slot: .shirt, price: 250, uses: 0, perk: "In rain: bites 20% faster.",
                 effect: Effect(bite: 0.8, cond: .wet), c1: 0xF2D23A, c2: 0xC8A82A, style: ShirtPattern.plain.rawValue),
        GearItem(id: "shirt.hawaiian", name: "Hawaiian Shirt", slot: .shirt, price: 200, uses: 0, perk: "+3% luck in salt water.",
                 effect: Effect(luck: 0.03, cond: .waters(Habitat.salt)), c1: 0x2AB8B0, c2: 0xF2E85A, style: ShirtPattern.floral.rawValue),
        GearItem(id: "shirt.jersey", name: "Pro Jersey", slot: .shirt, price: 900, uses: 0, perk: "Catch zone +2%.",
                 effect: Effect(bar: 0.02), c1: 0x2A5AC8, c2: 0xF0F0F0, style: ShirtPattern.stripes.rawValue),
        GearItem(id: "shirt.suit", name: "Fancy Suit", slot: .shirt, price: 1500, uses: 0, perk: "Fish sell for 5% more.",
                 effect: Effect(sell: 0.05), c1: 0x2A2A34, c2: 0xF0F0F0, style: ShirtPattern.plain.rawValue),
        // Pants
        GearItem(id: "pants.jeans", name: "Blue Jeans", slot: .pants, price: 0, uses: 0, perk: "Comfy.",
                 effect: Effect(), c1: 0x3A5A9A, c2: 0x2A4272, style: 0),
        GearItem(id: "pants.khaki", name: "Khakis", slot: .pants, price: 80, uses: 0, perk: "Smart casual.",
                 effect: Effect(), c1: 0xB8A070, c2: 0x8A7650, style: 0),
        GearItem(id: "pants.overalls", name: "Overalls", slot: .pants, price: 150, uses: 0, perk: "Farmhand chic.",
                 effect: Effect(), c1: 0x4A6AB8, c2: 0x34508A, style: 0),
        GearItem(id: "pants.shorts", name: "Red Shorts", slot: .pants, price: 60, uses: 0, perk: "Beach ready.",
                 effect: Effect(), c1: 0xC83A3A, c2: 0x8A2A2A, style: 1),
        GearItem(id: "pants.waders", name: "Waders", slot: .pants, price: 300, uses: 0, perk: "Streams, rivers, swamp: bites 10% faster.",
                 effect: Effect(bite: 0.9, cond: .waters([.stream, .river, .swamp])), c1: 0x3E6A3A, c2: 0x2A4A28, style: 0),
    ]

    static let byID: [String: GearItem] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    static func inSlot(_ s: Slot) -> [GearItem] { all.filter { $0.slot == s } }
    static let defaults: [Slot: String] = [.hat: "hat.bucket", .shirt: "shirt.vest", .pants: "pants.jeans"]

    static let hairColors: [UInt32] = [0x6A3A1A, 0x2A1A10, 0xE8C060, 0xC8582A, 0xD0D0D8, 0x3A6AE8]
    static let skinTones: [UInt32] = [0xF4C49A, 0xE0A878, 0xB87850, 0x8A5A3A, 0x5A3A28]
}

struct Bonuses {
    var bite = 1.0, luck = 0.0, size = 0.0, bar = 0.0, sell = 0.0
}

struct Outfit {
    var hatStyle: HatStyle, hat: UInt32, hatBand: UInt32
    var shirt: UInt32, shirt2: UInt32, pattern: ShirtPattern
    var pants: UInt32, pants2: UInt32, shorts: Bool
    var hair: UInt32, skin: UInt32
    var key: String {
        "\(hatStyle.rawValue)|\(hat)|\(hatBand)|\(shirt)|\(shirt2)|\(pattern.rawValue)|\(pants)|\(shorts)|\(hair)|\(skin)"
    }
}

// MARK: - Competitions

enum CompGoal: String, Codable {
    case biggest, most, weight
    var label: String {
        switch self {
        case .biggest: return "HEAVIEST SINGLE FISH"
        case .most: return "MOST FISH CAUGHT"
        case .weight: return "TOTAL WEIGHT"
        }
    }
}

struct Competition {
    let id: String
    let name: String
    let habitat: Habitat
    let season: Season
    let dayOfSeason: Int
    let goal: CompGoal
    let fee: Int
    var prizes: [Int] { [fee * 8, fee * 4, fee * 2] }
    static let duration = 180.0  // real seconds
    static let entryHours = 6.0..<16.0

    static let all: [Competition] = [
        Competition(id: "c.bass", name: "Spring Bass Bash", habitat: .lake, season: .spring, dayOfSeason: 7, goal: .biggest, fee: 50),
        Competition(id: "c.trout", name: "Trout Opener", habitat: .stream, season: .spring, dayOfSeason: 14, goal: .most, fee: 75),
        Competition(id: "c.coral", name: "Coral Bay Classic", habitat: .ocean, season: .summer, dayOfSeason: 7, goal: .weight, fee: 100),
        Competition(id: "c.luau", name: "Lagoon Luau Cup", habitat: .lagoon, season: .summer, dayOfSeason: 14, goal: .most, fee: 100),
        Competition(id: "c.salmon", name: "Salmon Run Derby", habitat: .river, season: .fall, dayOfSeason: 7, goal: .biggest, fee: 120),
        Competition(id: "c.marsh", name: "Marsh Monster Hunt", habitat: .swamp, season: .fall, dayOfSeason: 14, goal: .weight, fee: 120),
        Competition(id: "c.cod", name: "Ice-Cold Cod-Off", habitat: .deepSea, season: .winter, dayOfSeason: 7, goal: .weight, fee: 150),
        Competition(id: "c.pond", name: "Pond Masters", habitat: .pond, season: .winter, dayOfSeason: 14, goal: .most, fee: 80),
    ]

    static let byID: [String: Competition] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static func on(day: Int) -> Competition? {
        all.first { $0.season == GameCalendar.season(day) && $0.dayOfSeason == GameCalendar.dayOfSeason(day) }
    }

    static func next(after day: Int) -> (Competition, Int) {
        for d in day...(day + 60) { if let c = on(day: d) { return (c, d) } }
        return (all[0], day)
    }

    func format(_ v: Double) -> String {
        switch goal {
        case .most: return "\(Int(v)) FISH"
        case .biggest, .weight: return formatWeight(v)
        }
    }

    static let rivalNames = ["OLD PETE", "CAPTAIN MAE", "LUCKY LOU", "DR. GILL", "SALTY SUE", "BIG RAY", "TINY TIM", "REEL RITA"]

    func makeRivals() -> [Rival] {
        let pool = FishSpecies.inHabitat(habitat).filter { $0.rarity != .legendary && !$0.isShark }
        func fishWeight(_ skill: Double) -> Double {
            let s = pool[min(pool.count - 1, Int(pow(Double.random(in: 0...1), 1.6 - skill) * Double(pool.count)))]
            let t = pow(Double.random(in: 0...1), 1.4 - skill)
            return s.weightKg(s.minSize + (s.maxSize - s.minSize) * t)
        }
        return Competition.rivalNames.shuffled().prefix(4).map { name in
            let skill = Double.random(in: 0.3...0.9)
            let score: Double
            switch goal {
            case .biggest: score = (0..<Int(3 + skill * 6)).map { _ in fishWeight(skill) }.max() ?? 1
            case .most: score = Double(Int((2 + skill * 9 + Double.random(in: -1...2)).rounded()))
            case .weight: score = (0..<Int(2 + skill * 8)).reduce(0) { a, _ in a + fishWeight(skill * 0.8) }
            }
            return Rival(name: name, final: score)
        }
    }
}

struct Rival: Codable {
    let name: String
    let final: Double
}

struct ActiveComp: Codable {
    let id: String
    var timeLeft: Double
    var rivals: [Rival]
    var best = 0.0
    var count = 0
    var weight = 0.0

    var comp: Competition { Competition.byID[id]! }
    var progress: Double { 1 - timeLeft / Competition.duration }

    var playerScore: Double {
        switch comp.goal {
        case .biggest: return best
        case .most: return Double(count)
        case .weight: return weight
        }
    }

    func rivalScore(_ r: Rival) -> Double {
        let p = min(1, progress * 1.15)
        return comp.goal == .most ? (r.final * p).rounded(.down) : r.final * p
    }

    mutating func log(_ s: FishSpecies, cm: Double) {
        let kg = s.weightKg(cm)
        best = max(best, kg)
        count += 1
        weight += kg
    }

    /// Standings as (name, score, isPlayer), best first.
    func standings(final: Bool) -> [(String, Double, Bool)] {
        var rows = rivals.map { ($0.name, final ? $0.final : rivalScore($0), false) }
        rows.append(("YOU", playerScore, true))
        return rows.sorted { $0.1 > $1.1 }
    }
}

struct CompResult: Codable {
    let id: String
    let standings: [String]
    let scores: [Double]
    let place: Int
    let prize: Int
}

// MARK: - Save data

struct FishRecord: Codable {
    var count = 0
    var best = 0.0
}

struct CaughtFish: Codable {
    let id: String
    let size: Double
    let value: Int  // base value; the market sets the actual sale price
    var fresh: Double?  // 1.0 = just caught; nil (old saves) counts as fresh

    init(id: String, size: Double, value: Int) {
        self.id = id
        self.size = size
        self.value = value
        self.fresh = 1
    }

    var freshness: Double { fresh ?? 1 }

    func aged(_ amount: Double, floor: Double) -> CaughtFish {
        var c = self
        c.fresh = max(floor, min(freshness, freshness - amount))
        return c
    }
}

struct SaveData: Codable {
    var coins = 0
    var rodLevel = 0          // equipped rod index
    var boatLevel = 0         // legacy (pre boat shed)
    var rodsOwned: [Int] = [0]
    var boatsOwned: [String] = []
    var fishFinder = false    // sonar for spotting schools from any boat
    var hitched: String?
    var carsOwned: [String] = []
    var car: String?
    var trailers: [String] = []
    var playerName = "ANGLER"
    var giftedDay: [String: Int] = [:]
    var spouse: String?
    var engaged: String?
    var weddingDay = 0
    var marriedDay = 0
    var kids: [Kid] = []
    var babyDue = 0
    var lastBabyAsk = 0
    var houseLevel = 0
    var news: [String] = []
    var booksRead: [String] = []
    var charter: Charter?
    var totalCaught = 0
    var records: [String: FishRecord] = [:]
    var cooler: [CaughtFish] = []
    var day = 1
    var minutes = 6.0 * 60
    var weather: Weather = .sunny
    var owned: Set<String> = ["hat.bucket", "shirt.vest", "pants.jeans"]
    var equipped: [String: String] = ["hat": "hat.bucket", "shirt": "shirt.vest", "pants": "pants.jeans"]
    var bait: [String: Int] = [:]
    var hairIdx = 0
    var skinIdx = 0
    var chest: [CaughtFish] = []
    var chests = 2
    var trophies: [String] = []
    var comp: ActiveComp?
    var compEnteredDay = 0
    var lastResult: CompResult?
    var items: [String: Int] = [:]
    var plots: [String: Plot] = [:]
    var removedTrees: [String: Int] = [:]
    var hasWelder = false
    var stoveLit = false
    var hasStriker = false
    var requests: [Request] = []
    var friendship: [String: Int] = [:]
    var mineDeepest = 0
    var seedIdx = 0
    var energy = Energy.max
    var tools: [String: Int] = [:]
    var fridgeFish: [CaughtFish] = []
    var fridgeItems: [String: Int] = [:]
    var freezer: [CaughtFish] = []
    var hasFridge = false
    var hasFreezer = false

    static var persistenceEnabled = true
    /// Active save slot (1...3). Each slot is a separate farm/account.
    static var slot = 1
    private static var key: String { "ReelRushSave.slot\(slot)" }
    private static let legacyKey = "ReelRushSave.v1"
    static let chestSize = 40
    static let maxChests = 6

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        coins = try c.decodeIfPresent(Int.self, forKey: .coins) ?? 0
        rodLevel = try c.decodeIfPresent(Int.self, forKey: .rodLevel) ?? 0
        boatLevel = try c.decodeIfPresent(Int.self, forKey: .boatLevel) ?? 0
        totalCaught = try c.decodeIfPresent(Int.self, forKey: .totalCaught) ?? 0
        records = try c.decodeIfPresent([String: FishRecord].self, forKey: .records) ?? [:]
        cooler = try c.decodeIfPresent([CaughtFish].self, forKey: .cooler) ?? []
        day = try c.decodeIfPresent(Int.self, forKey: .day) ?? 1
        minutes = try c.decodeIfPresent(Double.self, forKey: .minutes) ?? 360
        weather = (try? c.decodeIfPresent(Weather.self, forKey: .weather)) ?? .sunny
        owned = try c.decodeIfPresent(Set<String>.self, forKey: .owned) ?? owned
        equipped = try c.decodeIfPresent([String: String].self, forKey: .equipped) ?? equipped
        bait = try c.decodeIfPresent([String: Int].self, forKey: .bait) ?? [:]
        hairIdx = try c.decodeIfPresent(Int.self, forKey: .hairIdx) ?? 0
        skinIdx = try c.decodeIfPresent(Int.self, forKey: .skinIdx) ?? 0
        chest = try c.decodeIfPresent([CaughtFish].self, forKey: .chest) ?? []
        chests = try c.decodeIfPresent(Int.self, forKey: .chests) ?? 2
        trophies = try c.decodeIfPresent([String].self, forKey: .trophies) ?? []
        comp = try? c.decodeIfPresent(ActiveComp.self, forKey: .comp)
        compEnteredDay = try c.decodeIfPresent(Int.self, forKey: .compEnteredDay) ?? 0
        lastResult = try? c.decodeIfPresent(CompResult.self, forKey: .lastResult)
        items = try c.decodeIfPresent([String: Int].self, forKey: .items) ?? [:]
        plots = try c.decodeIfPresent([String: Plot].self, forKey: .plots) ?? [:]
        removedTrees = try c.decodeIfPresent([String: Int].self, forKey: .removedTrees) ?? [:]
        hasWelder = try c.decodeIfPresent(Bool.self, forKey: .hasWelder) ?? false
        stoveLit = try c.decodeIfPresent(Bool.self, forKey: .stoveLit) ?? false
        hasStriker = try c.decodeIfPresent(Bool.self, forKey: .hasStriker) ?? false
        requests = (try? c.decodeIfPresent([Request].self, forKey: .requests)) ?? []
        friendship = try c.decodeIfPresent([String: Int].self, forKey: .friendship) ?? [:]
        mineDeepest = try c.decodeIfPresent(Int.self, forKey: .mineDeepest) ?? 0
        seedIdx = try c.decodeIfPresent(Int.self, forKey: .seedIdx) ?? 0
        energy = try c.decodeIfPresent(Int.self, forKey: .energy) ?? Energy.max
        rodsOwned = try c.decodeIfPresent([Int].self, forKey: .rodsOwned) ?? Array(0...max(0, rodLevel))
        boatsOwned = try c.decodeIfPresent([String].self, forKey: .boatsOwned) ?? Array(["row", "skiff", "trawler"].prefix(boatLevel))
        hitched = try c.decodeIfPresent(String.self, forKey: .hitched) ?? boatsOwned.last
        carsOwned = try c.decodeIfPresent([String].self, forKey: .carsOwned) ?? []
        fishFinder = try c.decodeIfPresent(Bool.self, forKey: .fishFinder) ?? false
        car = try c.decodeIfPresent(String.self, forKey: .car)
        trailers = try c.decodeIfPresent([String].self, forKey: .trailers) ?? []
        playerName = try c.decodeIfPresent(String.self, forKey: .playerName) ?? "ANGLER"
        if playerName == "FARMER" || playerName == "FISHER" { playerName = "ANGLER" }  // old defaults
        giftedDay = try c.decodeIfPresent([String: Int].self, forKey: .giftedDay) ?? [:]
        spouse = try c.decodeIfPresent(String.self, forKey: .spouse)
        engaged = try c.decodeIfPresent(String.self, forKey: .engaged)
        weddingDay = try c.decodeIfPresent(Int.self, forKey: .weddingDay) ?? 0
        marriedDay = try c.decodeIfPresent(Int.self, forKey: .marriedDay) ?? 0
        kids = try c.decodeIfPresent([Kid].self, forKey: .kids) ?? []
        babyDue = try c.decodeIfPresent(Int.self, forKey: .babyDue) ?? 0
        lastBabyAsk = try c.decodeIfPresent(Int.self, forKey: .lastBabyAsk) ?? 0
        houseLevel = try c.decodeIfPresent(Int.self, forKey: .houseLevel) ?? 0
        news = try c.decodeIfPresent([String].self, forKey: .news) ?? []
        booksRead = try c.decodeIfPresent([String].self, forKey: .booksRead) ?? []
        charter = try? c.decodeIfPresent(Charter.self, forKey: .charter)
        tools = try c.decodeIfPresent([String: Int].self, forKey: .tools) ?? [:]
        fridgeFish = try c.decodeIfPresent([CaughtFish].self, forKey: .fridgeFish) ?? []
        fridgeItems = try c.decodeIfPresent([String: Int].self, forKey: .fridgeItems) ?? [:]
        freezer = try c.decodeIfPresent([CaughtFish].self, forKey: .freezer) ?? []
        hasFridge = try c.decodeIfPresent(Bool.self, forKey: .hasFridge) ?? false
        hasFreezer = try c.decodeIfPresent(Bool.self, forKey: .hasFreezer) ?? false
    }

    static func load() -> SaveData { peek(slot) ?? SaveData() }

    /// Reads a slot without activating it (nil = empty). Old single-save data migrates into slot 1.
    static func peek(_ n: Int) -> SaveData? {
        let k = "ReelRushSave.slot\(n)"
        var data = UserDefaults.standard.data(forKey: k)
        if data == nil && n == 1, let old = UserDefaults.standard.data(forKey: legacyKey) {
            UserDefaults.standard.set(old, forKey: k)
            UserDefaults.standard.removeObject(forKey: legacyKey)
            data = old
        }
        guard let d = data else { return nil }
        return try? JSONDecoder().decode(SaveData.self, from: d)
    }

    static func delete(_ n: Int) { UserDefaults.standard.removeObject(forKey: "ReelRushSave.slot\(n)") }

    func persist() {
        guard Self.persistenceEnabled else { return }
        if let data = try? JSONEncoder().encode(self) { UserDefaults.standard.set(data, forKey: Self.key) }
    }

    var rod: Rod { Rod.all[min(max(rodLevel, 0), Rod.all.count - 1)] }
    /// The boat currently hitched for towing (and used on the water).
    var boat: Boat? { hitched.flatMap { boatsOwned.contains($0) ? Boat.byID[$0] : nil } }
    var coolerCapacity: Int { boatsOwned.compactMap { Boat.byID[$0]?.capacity }.max() ?? 20 }
    var activeCar: Car? { car.flatMap { carsOwned.contains($0) ? Car.byID[$0] : nil } }
    var trailerSize: Int { trailers.compactMap { id in Trailer.all.first { $0.id == id }?.size }.max() ?? 0 }

    /// Can the hitched boat be towed with the current car + trailers?
    var towProblem: String? {
        guard let b = boat else { return boatsOwned.isEmpty ? "BUY A BOAT AT BAIT & TACKLE" : "HITCH A BOAT AT YOUR BOAT SHED" }
        guard let c = activeCar else { return "YOU NEED A CAR (AUTO SHOP) TO TOW YOUR BOAT" }
        let need = b.big ? 2 : 1
        if c.tow < need { return "YOUR \(c.name.uppercased()) CAN'T TOW THE \(b.name.uppercased())" }
        if trailerSize < need { return "YOU NEED A \(need == 2 ? "BIG" : "SMALL") TRAILER (AUTO SHOP)" }
        return nil
    }

    func rodStats(_ h: Habitat) -> (bar: Double, reel: Double, luck: Double, special: Bool?) { rod.stats(h, season: season) }
    var hasSaltRod: Bool { rod.isSaltwater }

    var kidBeds: Int { houseLevel * 2 }
    var spouseVillager: Villager? { spouse.flatMap { Villager.byID[$0] } }
    func hearts(_ id: String) -> Int { min(10, (friendship[id] ?? 0) / 5) }
    var coolerFull: Bool { cooler.count >= coolerCapacity }
    var chestCapacity: Int { chests * Self.chestSize }
    var speciesCaught: Int { records.values.filter { $0.count > 0 }.count }
    var season: Season { GameCalendar.season(day) }

    func item(_ slot: Slot) -> GearItem? { equipped[slot.rawValue].flatMap { GearItem.byID[$0] } }
    var baitLeft: Int { item(.bait).map { bait[$0.id] ?? 0 } ?? 0 }

    var outfit: Outfit {
        let hat = item(.hat) ?? GearItem.byID["hat.bucket"]!
        let shirt = item(.shirt) ?? GearItem.byID["shirt.vest"]!
        let pants = item(.pants) ?? GearItem.byID["pants.jeans"]!
        return Outfit(hatStyle: HatStyle(rawValue: hat.style) ?? .bucket, hat: hat.c1, hatBand: hat.c2,
                      shirt: shirt.c1, shirt2: shirt.c2, pattern: ShirtPattern(rawValue: shirt.style) ?? .plain,
                      pants: pants.c1, pants2: pants.c2, shorts: pants.style == 1,
                      hair: GearItem.hairColors[hairIdx % GearItem.hairColors.count],
                      skin: GearItem.skinTones[skinIdx % GearItem.skinTones.count])
    }

    func bonuses(habitat: Habitat, onBoat: Bool) -> Bonuses {
        var b = Bonuses()
        var items = [Slot.lure, .hat, .shirt, .pants].compactMap { item($0) }
        if let bt = item(.bait), (bait[bt.id] ?? 0) > 0 { items.append(bt) }
        for it in items {
            let e = it.effect
            let ok: Bool
            switch e.cond {
            case .always: ok = true
            case .day: ok = Clock.isDay(minutes)
            case .night: ok = !Clock.isDay(minutes)
            case .wet: ok = weather.isWet
            case .snow: ok = weather == .snow
            case .boat: ok = onBoat
            case .waters(let set): ok = set.contains(habitat)
            }
            guard ok else { continue }
            b.bite *= e.bite
            b.luck += e.luck
            b.size += e.size
            b.bar += e.bar
        }
        // Books: general know-how plus local knowledge
        b.luck += 0.01 * Double(booksRead.count) + (booksRead.contains(habitat.rawValue) ? 0.04 : 0)
        b.bar += 0.004 * Double(booksRead.count)
        return b
    }

    var sellBonus: Double { [Slot.lure, .hat, .shirt, .pants].compactMap { item($0)?.effect.sell }.reduce(0, +) }

    mutating func useBait() {
        guard let bt = item(.bait) else { return }
        let left = (bait[bt.id] ?? 0) - 1
        bait[bt.id] = max(0, left)
        if left <= 0 { equipped[Slot.bait.rawValue] = nil }
    }

    /// Advances the clock; returns true if a new day started.
    mutating func advance(seconds: Double) -> Bool {
        let before = minutes
        minutes += seconds * Clock.minutesPerSecond
        if minutes >= 1440 { minutes -= 1440 }
        if before < 360 && minutes >= 360 { startNewDay(); return true }
        return false
    }

    mutating func startNewDay() {
        let prev = day
        day += 1
        weather = Weather.roll(GameCalendar.season(day))
        let season = GameCalendar.season(day)
        for (k, var p) in plots {
            if let cid = p.crop, let crop = Crop.byID[cid], !p.dead {
                if !crop.seasons.contains(season) { p.dead = true }
                else if p.wateredDay == prev { p.growth += 1 }
            }
            if weather.isWet { p.wateredDay = day }
            plots[k] = p
        }
        // Spoilage: coolers/chests age fish fast, fridges slowly, freezers not at all.
        cooler = cooler.map { $0.aged(0.06, floor: 0.4) }
        chest = chest.map { $0.aged(0.06, floor: 0.4) }
        fridgeFish = fridgeFish.map { $0.aged(0.015, floor: 0.7) }
        spoiledToday = 0
        for (id, n) in items where id.hasPrefix("crop.") {
            let lost = (0..<n).filter { _ in Double.random(in: 0...1) < 0.06 }.count
            if lost > 0 { items[id] = n - lost; spoiledToday += lost; if items[id] == 0 { items[id] = nil } }
        }
        if let ch = charter, ch.day < day {
            news.append("YOUR CHARTER WITH \(ch.client) ENDED (\(ch.caught)/\(ch.target) FISH).")
            charter = nil
        }
        familyMorning()
        requests.removeAll { $0.due < day }
        for v in Villager.all where !requests.contains(where: { $0.npc == v.id }) && Double.random(in: 0...1) < 0.45 {
            requests.append(Request.make(for: v, day: day))
        }
    }

    /// Wedding, births, feeding the family and collecting wages.
    mutating func familyMorning() {
        if let e = engaged, weddingDay == day {
            spouse = e
            engaged = nil
            marriedDay = day
            news.append("YOU MARRIED \(Villager.byID[e]?.name.uppercased() ?? e)! THEY MOVED IN.")
        }
        if babyDue != 0 && babyDue <= day {
            babyDue = 0
            let girl = Bool.random()
            let name = (girl ? ["LILY", "ROSE", "IVY", "MAE", "JUNE", "PEARL"] : ["FINN", "BROOK", "REED", "COLE", "RIVER", "TOBY"]).randomElement()!
            kids.append(Kid(name: name, girl: girl, born: day))
            news.append("\(name) WAS BORN! WELCOME TO THE FAMILY.")
        }
        guard let sv = spouseVillager else { return }
        let members = 1 + kids.count
        var fed = 0
        for _ in 0..<members where feedOne() { fed += 1 }
        if fed == members {
            let teens = kids.filter { $0.stage(day) == .teen }
            let wage = sv.wage + hearts(sv.id) * 8 + teens.count * 70
            coins += wage
            var msg = "FAMILY FED (\(members) MEAL\(members == 1 ? "" : "S")). \(sv.name.uppercased()) EARNED \(sv.wage + hearts(sv.id) * 8)G AT THE \(sv.job.uppercased())"
            if !teens.isEmpty { msg += ", KIDS EARNED \(teens.count * 70)G" }
            news.append(msg + ". +\(wage)G")
        } else {
            friendship[sv.id] = max(0, (friendship[sv.id] ?? 0) - 3)
            news.append("NOT ENOUGH FOOD! ONLY \(fed)/\(members) FED. NOBODY WORKED TODAY. STOCK THE FRIDGE!")
        }
    }

    /// Eats one food item for a family member: fridge first, then backpack; dishes, store food, then produce.
    private mutating func feedOne() -> Bool {
        let order: [GoodCat] = [.dish, .food, .produce]
        for cat in order {
            if let id = fridgeItems.keys.sorted().first(where: { Good.byID[$0]?.cat == cat && (fridgeItems[$0] ?? 0) > 0 }) {
                fridgeItems[id]! -= 1
                if fridgeItems[id] == 0 { fridgeItems[id] = nil }
                return true
            }
            if let id = items.keys.sorted().first(where: { Good.byID[$0]?.cat == cat && (items[$0] ?? 0) > 0 }) {
                _ = take(id)
                return true
            }
        }
        return false
    }

    func count(_ id: String) -> Int { items[id] ?? 0 }

    mutating func add(_ id: String, _ n: Int = 1) { items[id, default: 0] += n }

    @discardableResult
    mutating func take(_ id: String, _ n: Int = 1) -> Bool {
        guard count(id) >= n else { return false }
        items[id] = count(id) - n
        if items[id] == 0 { items[id] = nil }
        return true
    }

    var spoiledToday: Int {
        get { items["_spoiled"] ?? 0 }
        set { items["_spoiled"] = newValue == 0 ? nil : newValue }
    }
    static let fridgeSize = 60, freezerSize = 50
    var fridgeUsed: Int { fridgeFish.count + fridgeItems.values.reduce(0, +) }

    func fishCount(_ id: String) -> Int {
        (cooler + chest + fridgeFish + freezer).filter { $0.id == id }.count
    }
    var anyFishCount: Int { cooler.count + chest.count + fridgeFish.count + freezer.count }

    /// Removes fish (cheapest first, cooler before chests). `id == nil` means any species.
    @discardableResult
    mutating func takeFish(_ id: String?, _ n: Int) -> Bool {
        let have = id.map { fishCount($0) } ?? anyFishCount
        guard have >= n else { return false }
        var left = n
        for src in 0..<4 where left > 0 {
            var list = [cooler, chest, fridgeFish, freezer][src]
            let idx = list.indices.filter { id == nil || list[$0].id == id }.sorted { list[$0].value < list[$1].value }
            for i in idx.prefix(left).sorted(by: >) { list.remove(at: i); left -= 1 }
            switch src {
            case 0: cooler = list
            case 1: chest = list
            case 2: fridgeFish = list
            default: freezer = list
            }
        }
        return true
    }

    var ownedSeeds: [Crop] { Crop.all.filter { count("seed.\($0.id)") > 0 } }
    var selectedSeed: Crop? {
        let s = ownedSeeds
        return s.isEmpty ? nil : s[seedIdx % s.count]
    }

    mutating func sleep() {
        minutes = 360
        startNewDay()
        energy = Energy.max
    }

    /// Spends energy; returns false (and spends nothing) if too tired.
    /// Late nights are tiring: x1.5 energy after 8 PM, x2 after midnight (until 6 AM).
    var nightFactor: Double {
        let h = Clock.hour(minutes)
        if h < 6 { return 2 }
        if h >= 20 { return 1.5 }
        return 1
    }

    mutating func spend(_ base: Int) -> Bool {
        let e = Int((Double(base) * nightFactor).rounded(.up))
        guard energy >= e else { return false }
        energy -= e
        return true
    }

    mutating func eat(_ id: String) -> Int {
        guard let g = Good.byID[id], g.energy > 0, energy < Energy.max, take(id) else { return 0 }
        let before = energy
        energy = min(Energy.max, energy + g.energy)
        return energy - before
    }
}

func formatSize(_ cm: Double) -> String {
    cm >= 100 ? String(format: "%.2fM", cm / 100) : String(format: "%.1fCM", cm)
}

func formatWeight(_ kg: Double) -> String {
    switch kg {
    case ..<10: return String(format: "%.2fKG", kg)
    case ..<100: return String(format: "%.1fKG", kg)
    default: return String(format: "%.0fKG", kg)
    }
}
