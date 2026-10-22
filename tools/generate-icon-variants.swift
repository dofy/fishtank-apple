import AppKit

@main struct IconVariants {
    static func main() throws {
        let root = URL(fileURLWithPath: "Sources/Resources/AppIcons")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("fishtank-icons-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        for design in AppIconCatalog.variants {
            let iconset = temporary.appendingPathComponent(design.id + ".iconset")
            try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
            for size in [16,32,128,256,512] { for scale in [1,2] {
                let image = AppIconArt.image(design, pixels: size * scale)
                let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
                let suffix = scale == 2 ? "@2x" : ""
                try png.write(to: iconset.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
                if size == 512 && scale == 1 { try png.write(to: root.appendingPathComponent(design.resourceName + ".png")) }
            } }
            let task = Process(); task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
            task.arguments = ["--convert", "icns", "--output", root.appendingPathComponent(design.resourceName + ".icns").path, iconset.path]
            try task.run(); task.waitUntilExit(); precondition(task.terminationStatus == 0)
        }
        let entries = AppIconCatalog.all.map { design -> [String: Any] in
            ["id": design.id, "name": design.name, "speciesID": design.speciesID,
             "speciesName": AppIconCatalog.label(design), "secondarySpeciesID": design.secondarySpeciesID ?? "",
             "tier": FishCatalog.byID[design.speciesID]!.tier, "resourceName": design.resourceName]
        }
        try JSONSerialization.data(withJSONObject: entries, options: [.prettyPrinted, .sortedKeys])
            .write(to: root.appendingPathComponent("AppIconCatalog.json"))
        print("Generated \(AppIconCatalog.variants.count) app icon variants in \(root.path)")
    }
}
