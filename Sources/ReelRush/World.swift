import SpriteKit

struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

enum Tile: Equatable {
    case grass, path, sand, mud, rock, bridge, pier, building, soil, plaza, fence
    case tree(TreeKind)
    case water(Habitat)

    var walkable: Bool {
        switch self {
        case .grass, .path, .sand, .mud, .bridge, .pier, .soil, .plaza: return true
        default: return false
        }
    }

    var isWaterLike: Bool {
        switch self {
        case .water, .bridge, .pier: return true
        default: return false
        }
    }

    var habitat: Habitat? {
        if case .water(let h) = self { return h }
        return nil
    }
}

struct Signpost {
    let habitat: Habitat
    let waterTile: (Int, Int)
    let standTile: (Int, Int)
}

struct TreeSpot {
    let x: Int, y: Int
    let kind: TreeKind
    let variant: Int
    var key: String { "\(x),\(y)" }
}

enum BuildingKind: String { case tackle, general, house, cottageA, cottageB, cottageC, mine, fountain, shed, boatShed, autos, villa, garage, gas }

struct Building {
    let kind: BuildingKind
    let x: Int, y: Int, w: Int, h: Int
    var variant = 0
    var door: CGPoint { CGPoint(x: (CGFloat(x) + CGFloat(w) / 2) * WorldMap.ts, y: CGFloat(y) * WorldMap.ts) }
    var doorTile: (Int, Int) { (x + w / 2, y - 1) }
}

final class WorldMap {
    static let cols = 280
    static let rows = 190
    static let tilePx = 16
    static let scale: CGFloat = 2
    static var ts: CGFloat { CGFloat(tilePx) * scale }
    static var size: CGSize { CGSize(width: CGFloat(cols) * ts, height: CGFloat(rows) * ts) }

    private(set) var tiles: [Tile]
    private(set) var signs: [Signpost] = []
    private(set) var trees: [TreeSpot] = []
    private(set) var lamps: [CGPoint] = []
    let buildings: [Building] = [
        Building(kind: .tackle, x: 116, y: 92, w: 4, h: 3),
        Building(kind: .general, x: 126, y: 92, w: 5, h: 3),
        Building(kind: .cottageA, x: 138, y: 92, w: 4, h: 3),
        Building(kind: .cottageB, x: 113, y: 80, w: 4, h: 3),
        Building(kind: .cottageC, x: 140, y: 80, w: 4, h: 3),
        Building(kind: .house, x: 58, y: 72, w: 4, h: 3),
        Building(kind: .mine, x: 82, y: 119, w: 3, h: 2),
        Building(kind: .fountain, x: 128, y: 83, w: 2, h: 2),
        Building(kind: .shed, x: 65, y: 72, w: 3, h: 2),
        Building(kind: .boatShed, x: 51, y: 72, w: 4, h: 3),
        Building(kind: .garage, x: 70, y: 72, w: 4, h: 3),
        Building(kind: .autos, x: 132, y: 77, w: 5, h: 3),
        Building(kind: .gas, x: 148, y: 76, w: 4, h: 3),
        Building(kind: .villa, x: 120, y: 77, w: 4, h: 3, variant: 0),
        Building(kind: .villa, x: 110, y: 86, w: 4, h: 3, variant: 1),
        Building(kind: .villa, x: 144, y: 86, w: 4, h: 3, variant: 2),
        Building(kind: .villa, x: 110, y: 96, w: 4, h: 3, variant: 3),
        Building(kind: .villa, x: 142, y: 96, w: 4, h: 3, variant: 4),
    ]
    let boardTile = (x: 123, y: 89)
    let plazaRect = (x: 110, y: 76, w: 38, h: 24)
    let farmRect = (x: 48, y: 54, w: 24, h: 13)   // tillable interior

    func building(_ k: BuildingKind) -> Building { buildings.first { $0.kind == k }! }
    var shopDoor: CGPoint { building(.tackle).door }
    var generalDoor: CGPoint { building(.general).door }
    var houseDoor: CGPoint { building(.house).door }
    var mineDoor: CGPoint { building(.mine).door }
    var boardSpot: CGPoint { CGPoint(x: (CGFloat(boardTile.x) + 0.5) * Self.ts, y: CGFloat(boardTile.y) * Self.ts) }
    var spawn: CGPoint { CGPoint(x: houseDoor.x, y: houseDoor.y - 22) }

    private static let river: [(Double, Double)] = [(12, 191), (18, 151), (24, 132), (32, 116), (44, 104), (60, 96), (82, 92), (98, 82),
                                                     (110, 66), (128, 52), (150, 44), (182, 40)]
    private static let bridgeColumns = [45, 46, 104, 105, 140, 141]
    private static let pierRows = [88, 89]

    init() {
        tiles = Array(repeating: .grass, count: Self.cols * Self.rows)
        generate()
    }

    subscript(x: Int, y: Int) -> Tile {
        get {
            guard x >= 0, y >= 0, x < Self.cols, y < Self.rows else { return .rock }
            return tiles[y * Self.cols + x]
        }
        set {
            guard x >= 0, y >= 0, x < Self.cols, y < Self.rows else { return }
            tiles[y * Self.cols + x] = newValue
        }
    }

    func setTile(_ x: Int, _ y: Int, _ t: Tile) { self[x, y] = t }

    func center(_ x: Int, _ y: Int) -> CGPoint {
        CGPoint(x: (CGFloat(x) + 0.5) * Self.ts, y: (CGFloat(y) + 0.5) * Self.ts)
    }

    func tileCoord(_ p: CGPoint) -> (Int, Int) { (Int(floor(p.x / Self.ts)), Int(floor(p.y / Self.ts))) }

    func tile(at p: CGPoint) -> Tile {
        let c = tileCoord(p)
        return self[c.0, c.1]
    }

    func navigable(_ p: CGPoint, boat: Boat) -> Bool {
        switch tile(at: p) {
        case .water(let h): return boat.waters.contains(h)
        case .bridge: return boat.waters.contains(.river)
        default: return false
        }
    }

    func inPlaza(_ p: CGPoint) -> Bool {
        let (x, y) = tileCoord(p)
        return x >= plazaRect.x && x < plazaRect.x + plazaRect.w && y >= plazaRect.y && y < plazaRect.y + plazaRect.h
    }

    private func coast(_ fy: Double) -> Double { 168 + 4 * sin(fy * 0.13) + 3 * sin(fy * 0.05 + 1) }

    private func ell(_ x: Double, _ y: Double, _ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double) -> Double {
        let dx = (x - cx) / rx, dy = (y - cy) / ry
        return dx * dx + dy * dy
    }

    private func segDist(_ x: Double, _ y: Double, _ a: (Double, Double), _ b: (Double, Double)) -> Double {
        let vx = b.0 - a.0, vy = b.1 - a.1
        let t = max(0, min(1, ((x - a.0) * vx + (y - a.1) * vy) / (vx * vx + vy * vy)))
        return hypot(x - (a.0 + t * vx), y - (a.1 + t * vy))
    }

    private func distToRiver(_ x: Double, _ y: Double) -> Double {
        var best = Double.infinity
        for i in 0..<(Self.river.count - 1) { best = min(best, segDist(x, y, Self.river[i], Self.river[i + 1])) }
        return best
    }

    // MARK: - Generation

    private func generate() {
        for y in 0..<Self.rows {
            for x in 0..<Self.cols {
                let fx = Double(x), fy = Double(y)
                var t: Tile = .grass

                let mEdge = 118 + 3 * sin(fx * 0.3) + 2 * sin(fx * 0.11)
                if fy > mEdge && fx < 100 + 6 * sin(fy * 0.2) { t = .rock }

                let c = coast(fy)
                if fx >= c + 14 { t = .water(.deepSea) }
                else if fx >= c { t = .water(.ocean) }
                else if fx >= c - 4 { t = .sand }

                let lake = ell(fx, fy, 30, 40, 12, 8)
                if lake <= 1 { t = .water(.lake) } else if lake <= 1.3 && t == .grass { t = .sand }

                if ell(fx, fy, 100, 110, 6, 4) <= 1 { t = .water(.pond) }

                if ell(fx, fy, 28, 14, 24, 12) <= 1 {
                    let n = sin(fx * 0.9) + cos(fy * 1.1) + sin((fx + fy) * 0.5)
                    t = (ell(fx, fy, 28, 14, 13, 6.5) <= 1 || n > 1.3) ? .water(.swamp) : .mud
                }

                let lag = ell(fx, fy, 150, 18, 10, 6)
                if lag <= 1 { t = .water(.lagoon) } else if lag <= 1.7 && (t == .grass || t == .mud) { t = .sand }

                // Alpine meadow + Glacier Tarn, reached by a mountain pass
                if ell(fx, fy, 60, 134, 16, 8.5) <= 1 { t = .grass }
                if segDist(fx, fy, (66, 110), (61, 128)) < 2.2 && t == .rock { t = .grass }
                if ell(fx, fy, 60, 135, 7.5, 4) <= 1 { t = .water(.alpine) }
                // Deep-sea zones far offshore
                if t == .water(.deepSea) {
                    if ell(fx, fy, 205, 40, 14, 9) <= 1 { t = .water(.kelp) }
                    if ell(fx, fy, 258, 160, 14, 20) <= 1 { t = .water(.trench) }
                }
                // Paradise Isle with its coral atoll
                let isle = ell(fx, fy, 236, 95, 18, 12)
                if isle <= 1 { t = isle <= 0.6 ? .grass : .sand }
                if ell(fx, fy, 236, 97, 6.5, 3.5) <= 1 { t = .water(.atoll) }
                // Northern highlands: Misty Falls (pool under a cliff) and Ember Springs
                if fx >= 110 && fx <= 134 && fy >= 174 && fy <= 180 { t = .rock }
                if ell(fx, fy, 122, 168, 6, 4) <= 1 || (fx >= 121 && fx <= 123 && fy >= 171 && fy <= 180) { t = .water(.waterfall) }
                let spring = ell(fx, fy, 152, 170, 5, 3.5)
                if spring <= 1 { t = .water(.hotspring) } else if spring <= 1.8 && t == .grass { t = .mud }
                // Clearing in front of the mine
                if fx >= 78 && fx <= 88 && fy >= 110 && fy <= 118 && t == .rock { t = .grass }

                let d = distToRiver(fx, fy)
                let isStream = fy >= 112
                if d < (isStream ? 1.0 : 1.7) && fx < c { t = .water(isStream ? .stream : .river) }

                self[x, y] = t
            }
        }

        for x in Self.bridgeColumns {
            for y in 0..<Self.rows where self[x, y] == .water(.river) { self[x, y] = .bridge }
        }

        var pierEnd = 180
        for y in Self.pierRows {
            for x in 0..<Self.cols {
                if self[x, y] == .water(.deepSea) { pierEnd = x; break }
                if self[x, y] == .water(.ocean) { self[x, y] = .pier }
            }
        }

        for y in plazaRect.y..<(plazaRect.y + plazaRect.h) {
            for x in plazaRect.x..<(plazaRect.x + plazaRect.w) where self[x, y] == .grass { self[x, y] = .plaza }
        }
        for y in (farmRect.y - 1)...(farmRect.y + farmRect.h) {
            for x in (farmRect.x - 1)...(farmRect.x + farmRect.w) {
                let edge = x == farmRect.x - 1 || x == farmRect.x + farmRect.w || y == farmRect.y - 1 || y == farmRect.y + farmRect.h
                self[x, y] = edge ? .fence : .soil
            }
        }
        let gateX = farmRect.x + farmRect.w / 2
        for x in (gateX - 1)...gateX { self[x, farmRect.y + farmRect.h] = .path }

        for b in buildings {
            for y in b.y..<(b.y + b.h) { for x in b.x..<(b.x + b.w) { self[x, y] = .building } }
        }
        self[boardTile.x, boardTile.y] = .building

        let prefs: [(Habitat, Double, Double)] = [
            (.pond, 100, 105), (.lake, 30, 50), (.river, 92, 89), (.stream, 30, 122),
            (.swamp, 42, 16), (.ocean, 160, 120), (.lagoon, 150, 26), (.deepSea, Double(pierEnd), 89), (.alpine, 60, 130),
            (.waterfall, 122, 162), (.hotspring, 152, 165), (.atoll, 236, 93),
        ]
        signs = prefs.compactMap { findSign($0.0, $0.1, $0.2) }

        layPaths()

        let p = plazaRect
        lamps = [center(p.x + 1, p.y + 1), center(p.x + p.w - 2, p.y + 1), center(p.x + 1, p.y + p.h - 2),
                 center(p.x + p.w - 2, p.y + p.h - 2), center(121, 89), center(133, 89),
                 center(building(.house).x - 1, building(.house).y - 1)]
        if let pierStart = (0..<Self.cols).first(where: { self[$0, Self.pierRows[1]] == .pier }) {
            lamps.append(center(pierStart - 1, Self.pierRows[1] + 1))
        }

        placeTrees()
    }

    private func findSign(_ h: Habitat, _ px: Double, _ py: Double) -> Signpost? {
        var best: Signpost?
        var bestD = Double.infinity
        for y in 0..<Self.rows {
            for x in 0..<Self.cols where self[x, y] == .water(h) {
                for (nx, ny) in [(x, y + 1), (x, y - 1), (x + 1, y), (x - 1, y)] {
                    let n = self[nx, ny]
                    guard n == .grass || n == .sand || n == .mud || n == .pier else { continue }
                    let d = hypot(Double(x) - px, Double(y) - py)
                    if d < bestD { bestD = d; best = Signpost(habitat: h, waterTile: (x, y), standTile: (nx, ny)) }
                }
            }
        }
        return best
    }

    private func layPaths() {
        let start = building(.house).doorTile
        var parent = [Int](repeating: -1, count: Self.cols * Self.rows)
        var queue = [start.1 * Self.cols + start.0]
        parent[queue[0]] = queue[0]
        var head = 0
        while head < queue.count {
            let i = queue[head]; head += 1
            let x = i % Self.cols, y = i / Self.cols
            for (nx, ny) in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)] {
                guard nx >= 0, ny >= 0, nx < Self.cols, ny < Self.rows else { continue }
                let ni = ny * Self.cols + nx
                let t = self[nx, ny]
                if parent[ni] == -1 && t.walkable && t != .soil { parent[ni] = i; queue.append(ni) }
            }
        }
        var targets = signs.map { $0.standTile }
        targets += buildings.filter { $0.kind != .fountain && $0.kind != .house }.map { $0.doorTile }
        targets.append((boardTile.x, boardTile.y - 1))
        targets.append((farmRect.x + farmRect.w / 2, farmRect.y + farmRect.h + 1))
        for t in targets {
            var i = t.1 * Self.cols + t.0
            guard i >= 0, i < parent.count, parent[i] != -1 else { continue }
            while parent[i] != i {
                let x = i % Self.cols, y = i / Self.cols
                if self[x, y] == .grass { self[x, y] = .path }
                i = parent[i]
            }
        }
        if self[start.0, start.1] == .grass { self[start.0, start.1] = .path }
    }

    private func placeTrees() {
        var rng = SeededRNG(seed: 20261122)
        var clear: [(Int, Int, Int)] = signs.map { ($0.standTile.0, $0.standTile.1, 3) }
        for b in buildings { clear.append((b.doorTile.0, b.doorTile.1, 3)) }
        clear.append((boardTile.x, boardTile.y - 1, 2))
        for y in 0..<Self.rows { for x in 0..<Self.cols where self[x, y] == .bridge { clear.append((x, y, 2)) } }

        for y in 0..<Self.rows {
            for x in 0..<Self.cols {
                let t = self[x, y]
                guard t == .grass || t == .mud || t == .sand else { continue }
                let roll = Double.random(in: 0..<1, using: &rng)
                let variant = Int.random(in: 0..<6, using: &rng)
                if x >= farmRect.x - 3 && x <= farmRect.x + farmRect.w + 2 && y >= farmRect.y - 3 && y <= farmRect.y + farmRect.h + 8 { continue }
                if x >= plazaRect.x - 2 && x <= plazaRect.x + plazaRect.w + 1 && y >= plazaRect.y - 2 && y <= plazaRect.y + plazaRect.h + 1 { continue }
                if clear.contains(where: { abs($0.0 - x) <= $0.2 && abs($0.1 - y) <= $0.2 }) { continue }
                let fx = Double(x), fy = Double(y)
                let edge = x < 3 || y < 2 || y > Self.rows - 4
                var kind: TreeKind?
                if ell(fx, fy, 236, 95, 18, 12) <= 1 {
                    if roll < 0.12 { kind = .palm }
                } else if t == .sand {
                    if ell(fx, fy, 150, 18, 17, 11) <= 1 && roll < 0.1 { kind = .palm }
                } else if t == .mud || ell(fx, fy, 28, 14, 27, 15) <= 1 {
                    if roll < 0.1 { kind = variant < 3 ? .dead : .bush }
                } else if ell(fx, fy, 150, 18, 19, 12) <= 1 {
                    if roll < 0.1 { kind = .palm }
                } else if roll < (edge ? 0.45 : 0.085) {
                    if fy > 100 { kind = variant < 4 ? .pine : .oak }
                    else { kind = variant < 4 ? .oak : (variant == 4 ? .bush : .pine) }
                }
                if let k = kind {
                    self[x, y] = .tree(k)
                    trees.append(TreeSpot(x: x, y: y, kind: k, variant: variant))
                }
            }
        }
    }

    /// Named offshore fishing zones (for the big map).
    var zones: [(String, CGPoint)] {
        [("KELP FOREST", center(205, 40)), ("ABYSSAL TRENCH", center(258, 160)), ("PARADISE ISLE", center(236, 109))]
    }

    func schoolCandidates() -> [(Int, Int)] {
        var out: [(Int, Int)] = []
        for y in 1..<(Self.rows - 1) {
            for x in 1..<(Self.cols - 1) {
                guard case .water = self[x, y] else { continue }
                var open = true
                for dy in -1...1 { for dx in -1...1 where self[x + dx, y + dy].habitat == nil { open = false } }
                if open { out.append((x, y)) }
            }
        }
        return out
    }

    // MARK: - Rendering

    func texture(frame: Int) -> SKTexture {
        let tp = Self.tilePx
        let b = PixelBuffer(Self.cols * tp, Self.rows * tp)
        for y in 0..<Self.rows {
            for x in 0..<Self.cols { paint(b, x, y, frame) }
        }
        for y in 1..<Self.rows {
            for x in 0..<Self.cols {
                let t = self[x, y]
                guard !t.isWaterLike && t != .rock, case .water = self[x, y - 1] else { continue }
                b.rect(x * tp, y * tp, tp, 2, PColor(0x7A5A3A))
                b.rect(x * tp, y * tp + 2, tp, 1, PColor(0x9A7448))
            }
        }
        return b.texture()
    }

    private func paint(_ b: PixelBuffer, _ x: Int, _ y: Int, _ frame: Int) {
        let ox = x * Self.tilePx, oy = y * Self.tilePx
        switch self[x, y] {
        case .grass, .tree, .building:
            paintGrass(b, ox, oy, x, y)
        case .soil:
            noise(b, ox, oy, PColor(0x7AB050), PColor(0x8A7A4A), PColor(0x8AC060), salt: 12)
        case .fence:
            paintGrass(b, ox, oy, x, y)
            let post = PColor(0x8A5A30), rail = PColor(0xB07A40), dark = PColor(0x5A3418)
            let horiz = self[x - 1, y] == .fence || self[x + 1, y] == .fence
            let vert = self[x, y - 1] == .fence || self[x, y + 1] == .fence
            if horiz { b.rect(ox, oy + 6, 16, 2, rail); b.rect(ox, oy + 11, 16, 2, rail); b.rect(ox, oy + 5, 16, 1, dark) }
            if vert { b.rect(ox + 6, oy, 2, 16, rail); b.rect(ox + 9, oy, 2, 16, rail) }
            b.rect(ox + 6, oy + 2, 4, 13, post); b.rect(ox + 6, oy + 14, 4, 1, PColor(0xD09058)); b.rect(ox + 9, oy + 2, 1, 12, dark)
        case .plaza:
            for py in 0..<16 {
                for px in 0..<16 {
                    let row = (oy + py) / 5
                    let brick = ((ox + px) + (row % 2) * 4) / 8
                    let seam = (oy + py) % 5 == 0 || ((ox + px) + (row % 2) * 4) % 8 == 0
                    b[ox + px, oy + py] = seam ? PColor(0x8A8478) : PColor(0xC0B8A8).shade(hrand(brick, row, 13) * 0.12 - 0.06)
                }
            }
        case .path:
            noise(b, ox, oy, PColor(0xC9A066), PColor(0xAE8650), PColor(0xDDB880), salt: 3)
            for i in 0..<2 {
                let px = ox + 1 + Int(hrand(x, y, 30 + i) * 13), py = oy + 1 + Int(hrand(x, y, 40 + i) * 13)
                b.rect(px, py, 2, 1, PColor(0xE8CC98)); b.rect(px, py - 1, 2, 1, PColor(0x9A7444))
            }
            let grassy: (Tile) -> Bool = { if case .tree = $0 { return true }; return $0 == .grass || $0 == .building || $0 == .soil }
            let g = PColor(0x5FA83E)
            for i in 0..<16 {
                if grassy(self[x - 1, y]) { if hrand(ox, oy + i, 5) < 0.6 { b.set(ox, oy + i, g) }; if hrand(ox, oy + i, 6) < 0.25 { b.set(ox + 1, oy + i, g) } }
                if grassy(self[x + 1, y]) { if hrand(ox + 15, oy + i, 5) < 0.6 { b.set(ox + 15, oy + i, g) }; if hrand(ox, oy + i, 7) < 0.25 { b.set(ox + 14, oy + i, g) } }
                if grassy(self[x, y + 1]) { if hrand(ox + i, oy + 15, 5) < 0.6 { b.set(ox + i, oy + 15, g) }; if hrand(ox + i, oy, 8) < 0.25 { b.set(ox + i, oy + 14, g) } }
                if grassy(self[x, y - 1]) { if hrand(ox + i, oy, 5) < 0.6 { b.set(ox + i, oy, g) }; if hrand(ox + i, oy, 9) < 0.25 { b.set(ox + i, oy + 1, g) } }
            }
        case .sand:
            noise(b, ox, oy, PColor(0xEED7A1), PColor(0xDCC08A), PColor(0xF8E8BC), salt: 4)
            if hrand(x, y, 50) < 0.05 { b.rect(ox + 6, oy + 7, 2, 2, PColor(0xF2B8B0)); b.set(ox + 6, oy + 7, PColor(0xD8908A)) }
        case .mud:
            noise(b, ox, oy, PColor(0x6E5634), PColor(0x5A4428), PColor(0x84693F), salt: 5)
            if hrand(x, y, 51) < 0.3 { b.ellipse(Double(ox) + 4 + hrand(x, y, 52) * 8, Double(oy) + 4 + hrand(x, y, 53) * 8, 3, 2, PColor(0x5E6E34)) }
        case .rock:
            let snow = y >= 135
            let base = PColor(snow ? 0xE4ECF2 : 0x8E8A84), dark = PColor(snow ? 0xB4C6D8 : 0x66625A), light = PColor(snow ? 0xFFFFFF : 0xACA89E)
            noise(b, ox, oy, base, dark, light, salt: 6)
            b.ellipse(Double(ox) + 4 + hrand(x, y, 54) * 8, Double(oy) + 8 + hrand(x, y, 55) * 4, 4, 3, light)
            b.line(ox + 2 + Int(hrand(x, y, 56) * 10), oy + 3, ox + 4 + Int(hrand(x, y, 57) * 10), oy + 9, dark)
            if self[x, y - 1] != .rock && self[x, y - 1] != .building {
                b.rect(ox, oy, 16, 5, dark.shade(-0.1))
                for i in stride(from: 1, to: 16, by: 4) { b.rect(ox + i, oy + 1, 1, 3, base.shade(-0.05)) }
            }
        case .water(let h):
            paintWater(b, ox, oy, x, y, h, frame)
        case .bridge:
            paintWater(b, ox, oy, x, y, .river, frame)
            b.rect(ox, oy, 16, 16, PColor(0xB0763C))
            for i in stride(from: 0, to: 16, by: 4) {
                b.rect(ox, oy + i, 16, 1, PColor(0x7A4A22))
                b.set(ox + 3, oy + i + 2, PColor(0x5A3418)); b.set(ox + 12, oy + i + 2, PColor(0x5A3418))
            }
            if self[x - 1, y] != .bridge { b.rect(ox, oy, 2, 16, PColor(0x5A3418)); b.rect(ox, oy + 6, 3, 3, PColor(0x7A4A22)) }
            if self[x + 1, y] != .bridge { b.rect(ox + 14, oy, 2, 16, PColor(0x5A3418)); b.rect(ox + 13, oy + 6, 3, 3, PColor(0x7A4A22)) }
        case .pier:
            paintWater(b, ox, oy, x, y, .ocean, frame)
            b.rect(ox, oy, 16, 16, PColor(0xB0763C))
            for i in stride(from: 0, to: 16, by: 4) { b.rect(ox + i, oy, 1, 16, PColor(0x7A4A22)) }
            if self[x, y + 1] != .pier { b.rect(ox, oy + 14, 16, 2, PColor(0x5A3418)) }
            if self[x, y - 1] != .pier { b.rect(ox, oy, 16, 2, PColor(0x5A3418)) }
        }
    }

    private func noise(_ b: PixelBuffer, _ ox: Int, _ oy: Int, _ base: PColor, _ dark: PColor, _ light: PColor, salt: Int) {
        for py in 0..<16 {
            for px in 0..<16 {
                let n = hrand(ox + px, oy + py, salt)
                b[ox + px, oy + py] = n < 0.07 ? dark : (n < 0.12 ? light : base)
            }
        }
    }

    private func paintGrass(_ b: PixelBuffer, _ ox: Int, _ oy: Int, _ x: Int, _ y: Int) {
        let base = PColor(0x5FA83E), light = PColor(0x76C250), dark = PColor(0x4C9030)
        noise(b, ox, oy, base, dark, light, salt: 11)
        for i in 0..<3 where hrand(x, y, 20 + i) < 0.6 {
            let tx = ox + 1 + Int(hrand(x, y, 30 + i) * 12), ty = oy + 1 + Int(hrand(x, y, 40 + i) * 12)
            b.set(tx, ty, dark); b.set(tx, ty + 1, dark)
            b.set(tx + 2, ty, dark); b.set(tx + 2, ty + 1, dark)
            b.set(tx + 1, ty + 1, light); b.set(tx + 1, ty + 2, light)
        }
        if hrand(x, y, 60) < 0.05 {
            let colors = [PColor(0xFFFFFF), PColor(0xFFE14A), PColor(0xF28AB0), PColor(0x8AB4FF)]
            let c = colors[Int(hrand(x, y, 61) * 4)]
            let fx = ox + 3 + Int(hrand(x, y, 62) * 10), fy = oy + 3 + Int(hrand(x, y, 63) * 10)
            b.set(fx - 1, fy, c); b.set(fx + 1, fy, c); b.set(fx, fy - 1, c); b.set(fx, fy + 1, c)
            b.set(fx, fy, PColor(0xFFC83A))
        }
    }

    private func paintWater(_ b: PixelBuffer, _ ox: Int, _ oy: Int, _ x: Int, _ y: Int, _ h: Habitat, _ frame: Int) {
        let base = h.water, deep = base.shade(-0.1), light = base.shade(0.25)
        for py in 0..<16 {
            for px in 0..<16 { b[ox + px, oy + py] = hrand(ox + px, oy + py, 70) < 0.06 ? deep : base }
        }
        for i in 0..<2 where hrand(x, y, 71 + i) < 0.7 {
            let wx = ox + Int(hrand(x, y, 73 + i) * 10) + frame * 2, wy = oy + 2 + Int(hrand(x, y, 75 + i) * 12)
            b.rect(wx, wy, frame == 0 ? 4 : 3, 1, light)
        }
        if h == .lagoon && hrand(x, y, 77) < 0.4 {
            let cx = ox + Int(hrand(x, y, 78) * 12)
            b.line(cx, oy + 4 + frame, cx + 3, oy + 7 + frame, base.shade(0.35))
        }
        if (h == .swamp && hrand(x, y, 90) < 0.14) || (h == .pond && hrand(x, y, 90) < 0.07) {
            let lx = Double(ox) + 4 + hrand(x, y, 91) * 8, ly = Double(oy) + 4 + hrand(x, y, 92) * 8
            b.ellipse(lx, ly, 2.6, 2, PColor(0x5A9A3A))
            b.set(Int(lx), Int(ly), base)
            if hrand(x, y, 93) < 0.3 { b.set(Int(lx) - 1, Int(ly) + 1, PColor(0xF28AB0)) }
        }
        let foam = PColor(0xEAF6FF), foamIn = base.shade(0.35)
        let land: (Int, Int) -> Bool = { !self[$0, $1].isWaterLike }
        for i in 0..<16 {
            let shimmer = frame == 1 && (i / 2) % 2 == 0
            if land(x - 1, y) { b.set(ox, oy + i, foam); if !shimmer { b.set(ox + 1, oy + i, foamIn) } }
            if land(x + 1, y) { b.set(ox + 15, oy + i, foam); if !shimmer { b.set(ox + 14, oy + i, foamIn) } }
            if land(x, y + 1) { b.set(ox + i, oy + 15, foam); if !shimmer { b.set(ox + i, oy + 14, foamIn) } }
            if land(x, y - 1) { b.set(ox + i, oy, foam); if !shimmer { b.set(ox + i, oy + 1, foamIn) } }
        }
    }
}
