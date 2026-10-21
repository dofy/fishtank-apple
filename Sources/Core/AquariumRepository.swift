import Foundation

/// All writes go through an atomic primary replacement. Recovery files are written first.
final class AquariumRepository {
    let primary: URL
    let recent: URL
    let preRestore: URL
    init(primary: URL) {
        self.primary = primary
        recent = primary.appendingPathExtension("recent.json")
        preRestore = primary.appendingPathExtension("pre-restore.json")
    }
    func read(_ url: URL) throws -> Data {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
        guard size <= AquariumBackup.maximumBytes else { throw AquariumError.invalidSave }
        let data = try Data(contentsOf: url)
        guard data.count <= AquariumBackup.maximumBytes else { throw AquariumError.invalidSave }
        return data
    }
    private func preservePrimaryBeforeRestore() throws {
        let manager = FileManager.default
        if manager.fileExists(atPath: preRestore.path),
           try preRestore.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile != true { throw AquariumError.invalidSave }
        let temporary = primary.deletingLastPathComponent().appendingPathComponent("restore-snapshot-" + UUID().uuidString)
        defer { try? manager.removeItem(at: temporary) }
        // Copy instead of decoding or loading: even an oversized corrupt file is preserved.
        try manager.copyItem(at: primary, to: temporary)
        if manager.fileExists(atPath: preRestore.path) { _ = try manager.replaceItemAt(preRestore, withItemAt: temporary) }
        else { try manager.moveItem(at: temporary, to: preRestore) }
    }
    func persist(_ state: AquariumState, replacing: Bool = false, at date: Date = Date()) throws {
        guard state.isValid else { throw AquariumError.invalidSave }
        let data = try JSONEncoder().encode(state)
        guard data.count <= AquariumBackup.maximumBytes else { throw AquariumError.invalidSave }
        let manager = FileManager.default
        try manager.createDirectory(at: primary.deletingLastPathComponent(), withIntermediateDirectories: true)
        if manager.fileExists(atPath: primary.path) {
            if replacing {
                // Preserve raw bytes too: a damaged primary can be recovered outside the app.
                try preservePrimaryBeforeRestore()
            } else {
                let modified = try? recent.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                if modified == nil || date.timeIntervalSince(modified!) >= 300 {
                    let old = try read(primary)
                    _ = try AquariumSave.decode(old) // Never rotate a corrupt primary over a healthy backup.
                    try old.write(to: recent, options: .atomic)
                }
            }
        }
        try data.write(to: primary, options: .atomic)
    }
}
