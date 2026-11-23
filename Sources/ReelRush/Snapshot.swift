import SpriteKit

/// Debug helper: `REELRUSH_SNAPSHOT=/some/dir ReelRush` renders each screen to PNG and quits.
/// Progress is not saved in this mode.
func runSnapshots(view: SKView, dir: String) {
    SaveData.persistenceEnabled = false
    let game = Game.shared
    game.save = SaveData()
    game.slotChosen = false
    var steps: [(String, () -> Void)] = []

    func shot(_ name: String) {
        guard let scene = view.scene, let tex = view.texture(from: scene) else { return }
        let rep = NSBitmapImageRep(cgImage: tex.cgImage())
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
    }
    func present(_ s: SKScene) { s.scaleMode = .aspectFit; view.presentScene(s) }
    func setTime(_ hour: Double, _ w: Weather) { game.save.minutes = hour * 60; game.save.weather = w }

    steps.append(("20_title", { present(TitleScene(size: Game.sceneSize)) }))
    steps.append(("21_island", {
        setTime(10, .sunny)
        game.save.boatsOwned = ["yacht"]; game.save.hitched = "yacht"
        present(game.mapScene)
        let w = game.mapScene.world
        game.mapScene.debugWalk(to: w.center(236, 92), facing: .up)
    }))
    steps.append(("22_bigmap", { (view.scene as? MapScene)?.keyPressed(Key.m) }))
    steps.append(("23_highlands", {
        (view.scene as? MapScene)?.keyPressed(Key.m)
        let w = game.mapScene.world
        game.mapScene.debugWalk(to: w.center(137, 164), facing: .up)
    }))
    steps.append(("24_fish_kelp", { present(FishingScene(habitat: .kelp, boat: Boat.byID["yacht"], school: false)) }))
    steps.append(("25_fish_trench", { setTime(22, .sunny); present(FishingScene(habitat: .trench, boat: Boat.byID["yacht"], school: false)) }))
    steps.append(("26_fish_atoll", { setTime(9, .sunny); present(FishingScene(habitat: .atoll, boat: nil, school: false)) }))
    steps.append(("27_fish_waterfall", { present(FishingScene(habitat: .waterfall, boat: nil, school: false)) }))
    steps.append(("28_fish_hotspring", { setTime(16, .snow); present(FishingScene(habitat: .hotspring, boat: nil, school: false)) }))
    steps.append(("29_books", { present(BookScene(size: Game.sceneSize)) }))
    steps.append(("30_journal_sharks", {
        for sp in FishSpecies.all where Habitat.salt.contains(sp.habitat) && sp.id != "tigershark" { game.save.records[sp.id] = FishRecord(count: 1, best: sp.maxSize) }
        let j = JournalScene(size: Game.sceneSize); present(j); j.keyPressed(Key.right)
    }))
    steps.append(("31_journal_deep", { (view.scene as? JournalScene)?.keyPressed(Key.right); (view.scene as? JournalScene)?.keyPressed(Key.right) }))
    steps.append(("34_fish_finder", {
        setTime(10, .sunny); game.save.fishFinder = true
        game.save.boatsOwned = ["yacht"]; game.save.hitched = "yacht"
        present(game.mapScene); game.mapScene.debugBoard(.ocean); game.mapScene.debugSchoolsNearBoat()
    }))
    steps.append(("37_moored_trailer", {
        setTime(14, .sunny)
        game.save.boatsOwned = ["skiff"]; game.save.hitched = "skiff"
        game.save.carsOwned = ["car.truck"]; game.save.car = "car.truck"; game.save.trailers = ["trailer.big"]
        present(game.mapScene); game.mapScene.debugMooredAtShore(.lake)
    }))
    steps.append(("38_loaded_trailer", { game.mapScene.keyPressed(Key.e) }))
    steps.append(("35_home_sites", {
        setTime(11, .sunny); game.save.boatShedBuilt = false; game.save.garageBuilt = false
        game.save.add("timber", 12); game.save.add("stone", 8)
        present(game.mapScene)
        let g = game.mapScene.world.building(.garage).door
        game.mapScene.debugWalk(to: CGPoint(x: g.x, y: g.y - 20), facing: .up)
    }))
    steps.append(("36_home_built", {
        game.save.boatShedBuilt = true; game.save.garageBuilt = true
        game.save.carsOwned = ["car.truck", "car.coupe"]; game.save.car = "car.truck"
        present(TitleScene(size: Game.sceneSize)); present(game.mapScene)
        let g = game.mapScene.world.building(.garage).door
        game.mapScene.debugWalk(to: CGPoint(x: g.x - 140, y: g.y - 30), facing: .up)
    }))
    steps.append(("32_shark_hooked", {
        setTime(7, .sunny); game.save.rodsOwned = [0, 7]; game.save.rodLevel = 7
        let f = FishingScene(habitat: .deepSea, boat: Boat.byID["yacht"], school: false); present(f)
        f.debugForceReel(rarity: .legendary, species: "greatwhite")
    }))
    steps.append(("33_shark_caught", {
        let f = FishingScene(habitat: .atoll, boat: nil, school: false); present(f)
        f.debugForceReel(rarity: .rare, species: "tigershark"); f.debugForceCatch()
    }))

    func run(_ i: Int) {
        guard i < steps.count else { NSApp.terminate(nil); return }
        steps[i].1()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            shot(steps[i].0)
            run(i + 1)
        }
    }
    run(0)
}
