import AppKit
import SpriteKit

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
