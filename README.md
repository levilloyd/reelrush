# 🎣 Reel Rush

A pixel-art arcade fishing game for macOS, built with Swift + SpriteKit. No Xcode needed.

## Build & run
```bash
./build.sh
open build/ReelRush.app
```

## How to play
**Title screen:** three save slots ("excursions"). Pick one, or start a new excursion and type your name. Press X twice to delete one.

A huge Stardew-style world (280×190 tiles): your **home, farm, boat shed and workshop** in the west, a busy **town** (shops, cottages, a fountain and townsfolk) in the middle-east, mountains with a **mine** and **Glacier Tarn** to the north-west, and the sea to the east. Press **M** for a full-screen labelled map.

- **SPACE does the obvious thing** for whatever you're facing: fish, chop, till/plant/water/harvest, enter a door, talk.
- **Energy:** working costs energy, 1.5× after 8 PM and 2× after midnight. Sleep or eat (backpack **I**) to recover.
- **Fishing:** 80 species in 10 places.
  - Fish bite at realistic times, in their seasons and weather. Bigger fish fight harder. Fish slowly lose freshness unless refrigerated or frozen.
  - **Rods:** all-rounders (Twig → Legendary) plus specialists (Fly, Surf Caster, Deep Sea, Bayou Baitcaster, Ice) that are great in their waters and weaker elsewhere. Switch rods with **G** → ROD.
  - **Sharks:** eight sharks (Blacktip, Lemon, Leopard, Mako, Goblin, Whitetip, Tiger and the legendary Great White) roam the salt waters, but they only bite when a salt-water rod (Surf Caster or Deep Sea Rod) is equipped.
  - **Build your home base:** the **boat shed** (40 timber + 30 stone) and the **garage** (30 timber + 50 stone) start as empty plots by your house. Walk up and press SPACE to build them. You need the boat shed before you can buy boats and the garage before you can buy cars. Cars park at the garage, and pressing SPACE there switches between the cars you own.
  - **Trailering:** after you launch, your car tows an empty trailer. To load the boat back on, either sail up to your parked car and press **E** (you end up at the wheel), or go ashore and drive up next to the moored boat and press **E**. Re-hitching a boat at the boat shed also brings it home.
  - **Gas:** every car and boat has a gas tank that drains as you drive or sail, and towing a boat burns extra. Fill up at the **Gas Station** in town (2G per liter). The gauge appears bottom-left while you're at the wheel. With an empty tank you can only crawl along slowly.
  - **Fish Finder (1200G, Bait & Tackle → Boats):** sonar fitted to all your boats. While you're out on the water it shows fish schools around you (yellow = water your boat can reach) and the distance and direction to the nearest one.
  - **Books:** buy the bookshelf (Home Goods). Each book lists a water's fish with your live % chance of catching each one, and reading it gives a permanent fishing bonus.
- **Boats, cars & trailers:**
  - Buy boats at Bait & Tackle: Kayak, Rowboat, Skiff, Bass Boat, Pontoon, Trawler, Luxury Yacht. They're kept in your **Boat Shed**, where you choose which one to hitch.
  - Buy a car and trailer at the **Auto Shop**. Small boats need any car that tows plus a small trailer; big boats need the Big Truck and the big trailer.
  - Press **C** near your car to drive, drive to the water, and press **E** to launch.
- **Charters:** with a Pontoon, Trawler or Yacht, take clients out from the CHARTERS tab at Bait & Tackle. They pay per fish plus a big bonus, but keep every fish.
- **Farming, timber, mining, cooking:** same as before.
  - New: at the **Workshop** you can weld bars onto timber to forge Copper/Iron/Gold axes, pickaxes and hoes.
- **Romance & family:**
  - Gift townsfolk once a day (talk, then **G**). Cooked dishes are loved most.
  - With 8+ hearts, propose to Marina, Rosa, Chef Amelie or Ivy using a **Promise Pendant** (Boutique): talk, then **P**. The wedding is the next morning.
  - Your spouse keeps a job in town and brings home a daily wage, and is home in the evenings.
  - After a few days of marriage, bedtime may ask about having a baby (Y/N). A yes means a child arrives the next morning.
  - Each child needs a bed: buy **House Expansions** at Home Goods for a kids' room.
  - Every family member eats one meal each morning (dishes, store food or produce from the fridge, then your backpack). If anyone goes hungry, nobody works that day.
  - Kids become teens after 21 days and earn money too.
- **Town stores:** Bait & Tackle · Boutique · Market · Hardware · Home Goods · Auto Shop. Villagers with a **!** pay extra for things they need (also on the Town Board's HELP WANTED tab).
- **Keys:** arrows/WASD move · SPACE act · E boat · C car · Q seed · I backpack · G gear · J journal · M map · ESC back

## Fishing places (110 species)
- **Land spots:** Mossy Pond · Pinecrest Lake · Willow River · Frostpeak Stream · Murky Marsh · Coral Bay · Sunset Lagoon · Glacier Tarn · **Misty Falls** (waterfall pool) and **Ember Springs** (hot spring) in the northern highlands · Crystal Cavern (in the mine).
- **Deep-sea spots:** Deep Sea Pier (from the end of the pier) · **Kelp Forest** and **Abyssal Trench** far offshore (boat only, needs a Trawler or Yacht).
- **Paradise Isle:** a tropical island far out to sea.
  - Sail there (Trawler or Yacht), press **E** at the shore to go ashore, explore the palms and fish the **Coral Atoll** lagoon for rare fish only.
  - Your boat stays moored at the shore; walk back to it and press **E** to sail home.

## Code
- `Pixel.swift`: pixel buffer engine, 5×7 bitmap font, Stardew-style panels, icons, input, sound
- `Sprites.swift`: pixel fish, player (4 directions, walk frames), boats, trees, buildings
- `World.swift`: generates the map (terrain, paths, trees) and renders the tiles
- `MapScene.swift`: walking, boat driving, schools, day/night lighting, weather, HUD
- `FishingScene.swift`: painted backgrounds, cast/bite/reel mini-game, catch rewards
- `Screens.swift`: title, journal, shop (sell, rods, boats, lures, bait, clothes, home)
- `Economy.swift`: crops, goods, recipes, tools, decor, villagers & requests
- `MineScene.swift`: the mine
- `Crafting.swift`: stove/welder crafting and the backpack
- `Family.swift`: gifts, boat shed, kids' room, books
- `HomeScreens.swift`: house interior, chest storage, gear/wardrobe, competition board and results
- `GameData.swift`: habitats, fish, rods, boats, clock, weather, save data
- `Snapshot.swift`: `REELRUSH_SNAPSHOT=dir` renders every screen to PNG (for testing; doesn't save)
