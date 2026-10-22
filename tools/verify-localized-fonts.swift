// Inspect embedded font files directly; no system font installation is required.
import Foundation
import CoreText
let root = URL(fileURLWithPath:FileManager.default.currentDirectoryPath)
let faces = ["en":"DepartureMono-Regular", "zh-Hans":"FusionPixel", "zh-Hant":"FusionPixel-Traditional", "ja":"FusionPixel-Japanese"]
let nativeNames = ["en":"English", "zh-Hans":"简体中文", "zh-Hant":"繁體中文", "ja":"日本語"]
var failed = false
for (language, resource) in faces.sorted(by:{$0.key < $1.key}) {
    let url = root.appendingPathComponent("Sources/Resources/Fonts/\(resource).otf")
    guard let provider = CGDataProvider(url:url as CFURL), let cgFont = CGFont(provider) else { print("FAIL missing font",resource);exit(2) }
    let font = CTFontCreateWithGraphicsFont(cgFont,12,nil,nil)
    let catalog = try JSONDecoder().decode([String:String].self,from:Data(contentsOf:root.appendingPathComponent("Sources/Core/Resources/Localizations/\(language).json")))
    var missing: Set<String> = []
    for character in Set(catalog.values.joined() + nativeNames[language]! + "Fishtank Claude Code Codex Cursor Gemini CLI OpenCode ×★-+") {
        if character.unicodeScalars.allSatisfy({CharacterSet.controlCharacters.contains($0) || $0.value==0xFE0F}) { continue }
        let units = Array(String(character).utf16);var glyphs = Array(repeating:CGGlyph(0),count:units.count)
        if !CTFontGetGlyphsForCharacters(font,units,&glyphs,units.count) { missing.insert(String(character)) }
    }
    if missing.isEmpty { print("PASS",language,CTFontCopyPostScriptName(font),"all catalog glyphs covered") }
    else { failed=true; print("FAIL",language,"missing",missing.sorted().joined()) }
}
exit(failed ? 2:0)
