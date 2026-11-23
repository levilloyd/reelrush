import AppKit
import SpriteKit

final class Game {
    static let shared = Game()
    static let sceneSize = CGSize(width: 1280, height: 800)

    weak var view: SKView?
    var save = SaveData()
    /// Only write saves once the player has picked a slot on the title screen.
    var slotChosen = false
    private var map: MapScene?
    var mapScene: MapScene {
        if let m = map { return m }
        let m = MapScene(size: Game.sceneSize)
        map = m
        return m
    }

    func loadSlot(_ n: Int) {
        SaveData.slot = n
        save = SaveData.load()
        map = nil
        slotChosen = true
    }

    func newGame(slot n: Int, name: String) {
        SaveData.slot = n
        save = SaveData()
        save.playerName = name
        map = nil
        slotChosen = true
        save.persist()
    }

    private func present(_ scene: SKScene) {
        if slotChosen { save.persist() }
        scene.scaleMode = .aspectFit
        view?.presentScene(scene, transition: .fade(with: .black, duration: 0.3))
    }

    func showTitle() { present(TitleScene(size: Game.sceneSize)) }
    func showMap() { present(mapScene) }
    func showFishing(_ h: Habitat, boat: Boat?, school: Bool) { present(FishingScene(habitat: h, boat: boat, school: school)) }
    func showJournal() { present(JournalScene(size: Game.sceneSize)) }
    func showShop(_ kind: ShopKind = .tackle) { present(ShopScene(kind: kind)) }
    func showInventory(returnTo: SKScene? = nil) { present(InventoryScene(returnTo: returnTo)) }
    func showCraft(_ station: Station) { present(CraftScene(station: station)) }
    func presentScene(_ scene: SKScene) { present(scene) }

    /// Where the fishing scene returns to (nil = the map).
    var fishingReturn: SKScene?
    func leaveFishing() {
        if let r = fishingReturn { fishingReturn = nil; present(r) } else { showMap() }
    }

    func enterMine() {
        let d = save.mineDeepest
        let level = d >= 5 ? (d / 5) * 5 : 1
        present(MineScene(level: level))
        if level > 1 { mapScene.toast("ELEVATOR TO LEVEL \(level)") }
    }

    func leaveMine() {
        mapScene.placeAt(mapScene.world.mineDoor)
        showMap()
    }
    func showHouse() { present(HouseScene(size: Game.sceneSize)) }
    func showStorage(_ kind: StorageKind) { present(StorageScene(kind: kind)) }
    func showBoard() { present(BoardScene(size: Game.sceneSize)) }
    func showGear(_ slot: Slot, fromHouse: Bool = false) {
        let tab = GearScene.Tab(rawValue: Slot.allCases.firstIndex(of: slot) ?? 0) ?? .lure
        present(GearScene(tab: tab, fromHouse: fromHouse))
    }

    /// Counts down an active contest. Returns true (and shows results) when it ends.
    func tickCompetition(_ dt: Double) -> Bool {
        guard var c = save.comp else { return false }
        c.timeLeft -= dt
        save.comp = c
        guard c.timeLeft <= 0 else { return false }
        let standings = c.standings(final: true)
        let place = (standings.firstIndex { $0.2 } ?? 4) + 1
        let comp = c.comp
        let prize = place <= 3 ? comp.prizes[place - 1] : 0
        save.coins += prize
        if place == 1 { save.trophies.append(comp.name) }
        save.lastResult = CompResult(id: comp.id, standings: standings.map { $0.0 }, scores: standings.map { $0.1 }, place: place, prize: prize)
        save.comp = nil
        Sound.play(place == 1 ? "Hero" : "Glass", volume: 0.5)
        present(CompResultScene(size: Game.sceneSize))
        return true
    }
}

final class GameView: SKView {
    override var acceptsFirstResponder: Bool { true }
}

func makeAppIcon() -> NSImage {
    NSImage(size: NSSize(width: 512, height: 512), flipped: false) { _ in
        let bg = NSBezierPath(roundedRect: NSRect(x: 32, y: 32, width: 448, height: 448), xRadius: 100, yRadius: 100)
        NSGradient(starting: PColor(0x5FB8F0).ns, ending: PColor(0x0B3A66).ns)!.draw(in: bg, angle: -90)
        PColor(0xFF8A2E).ns.setFill()
        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: 180, y: 220))
        tail.line(to: NSPoint(x: 96, y: 290))
        tail.line(to: NSPoint(x: 96, y: 150))
        tail.close()
        tail.fill()
        NSBezierPath(ovalIn: NSRect(x: 140, y: 150, width: 270, height: 140)).fill()
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: 345, y: 225, width: 30, height: 30)).fill()
        NSColor.black.setFill()
        NSBezierPath(ovalIn: NSRect(x: 355, y: 232, width: 16, height: 16)).fill()
        NSColor.white.setStroke()
        let l = NSBezierPath()
        l.move(to: NSPoint(x: 390, y: 470))
        l.line(to: NSPoint(x: 390, y: 330))
        l.appendArc(withCenter: NSPoint(x: 372, y: 330), radius: 18, startAngle: 0, endAngle: 200, clockwise: true)
        l.lineWidth = 8
        l.lineCapStyle = .round
        l.stroke()
        return true
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let size = NSSize(width: 1280, height: 800)
        window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "Reel Rush"
        window.contentAspectRatio = size
        window.minSize = NSSize(width: 640, height: 400)
        let view = GameView(frame: NSRect(origin: .zero, size: size))
        window.contentView = view
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)
        NSApp.applicationIconImage = makeAppIcon()

        Game.shared.view = view
        if let dir = ProcessInfo.processInfo.environment["REELRUSH_SNAPSHOT"] {
            runSnapshots(view: view, dir: dir)
            return
        }
        Game.shared.showTitle()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) { if Game.shared.slotChosen { Game.shared.save.persist() } }
}

// `ReelRush --export-icon out.png` writes the app icon (used by build.sh).
if let i = CommandLine.arguments.firstIndex(of: "--export-icon"), i + 1 < CommandLine.arguments.count {
    let img = makeAppIcon()
    if let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
       let png = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: CommandLine.arguments[i + 1]))
    }
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)

let mainMenu = NSMenu()
let appItem = NSMenuItem()
mainMenu.addItem(appItem)
let appMenu = NSMenu()
appMenu.addItem(withTitle: "Toggle Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
appMenu.addItem(.separator())
appMenu.addItem(withTitle: "Quit Reel Rush", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
appItem.submenu = appMenu
app.mainMenu = mainMenu
app.run()
