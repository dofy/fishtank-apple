import SwiftUI
import UniformTypeIdentifiers

struct AquariumBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw AquariumError.invalidSave }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct SavedGamePanel: View {
    @ObservedObject private var localization = AppLocalization.shared
    @ObservedObject var store: AquariumStore
    @State private var importing = false
    @State private var pending: AquariumState?
    @State private var importSource = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) { PixelIcon("book", color: PixelTheme.gold); Text(L10n.text("Save and Restore")).foregroundStyle(PixelTheme.gold) }
            #if os(iOS)
            Text(store.isPreviewOnly ? L10n.text("This is a temporary preview; the original save was not overwritten. Restore a backup or import a valid file.") : L10n.text("Auto-saves every 15 seconds and keeps a previous snapshot every 5 minutes. Export before changing devices."))
                .font(PixelTheme.captionFont()).foregroundStyle(PixelTheme.muted).fixedSize(horizontal: false, vertical: true)
            #endif
            HStack {
                #if os(iOS)
                BackupExportButton(store: store)
                #endif
                Button(L10n.text("Import JSON")) { importing = true }
            }
            Text(L10n.text("Supports app backups and original web v1 JSON. Preview before confirming replacement; aquariums are not merged. Old web nicknames, favorites, and layout metadata remain in the original snapshot."))
                .font(PixelTheme.captionFont()).foregroundStyle(PixelTheme.muted).fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { recoveryActions }.frame(minWidth: 496)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: PixelTheme.metric(160, 240)), spacing: 8)], alignment: .leading, spacing: 8) {
                    recoveryActions
                }
            }
            if let candidate = pending {
                VStack(alignment: .leading, spacing: 14) {
                    Text(L10n.text("Import Preview · ") + importSource).foregroundStyle(PixelTheme.gold)
                    Text(L10n.text("Lv.\(candidate.level) · \(candidate.fish.count) fish · \(candidate.discovered.count) species · \(candidate.hearts)/5 hearts"))
                    Text(L10n.text("Last saved: ") + candidate.lastUpdated.formatted(date: .abbreviated, time: .shortened))
                    Text(L10n.text("Confirm to replace current progress and apply offline growth. The current file will be backed up first."))
                        .foregroundStyle(PixelTheme.pink).fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button(L10n.text("Cancel")) { pending = nil }
                        Spacer()
                        Button(L10n.text("Confirm Replacement")) { if store.importBackup(candidate) { pending = nil } }
                    }
                }.padding(14).pixelPanel(selected: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(16).pixelPanel()
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url): preview(url, title: url.lastPathComponent)
            case .failure(let error): store.message = L10n.text("File selection not completed: ") + error.localizedDescription
            }
        }

    }
    private var recoveryActions: some View {
        Group {
            ForEach(store.recoveryURLs, id: \.1) { title, url in
                Button { preview(url, title: title) } label: {
                    Text(L10n.text("Restore · ") + title).frame(minWidth: 136, maxWidth: .infinity)
                }
            }
            Button {
                pending = .newGame(at: Date()); importSource = L10n.text("New Aquarium")
            } label: {
                Text(L10n.text("Start a New Ocean")).frame(minWidth: 136, maxWidth: .infinity)
            }
        }
    }
    private func preview(_ url: URL, title: String) {
        do { pending = try store.previewImport(url); importSource = title }
        catch { pending = nil; store.message = L10n.text("Could not read this backup: ") + error.localizedDescription }
    }
}

struct BackupExportButton: View {
    @ObservedObject private var localization = AppLocalization.shared
    @ObservedObject var store: AquariumStore
    @State private var exporting = false
    @State private var document = AquariumBackupDocument()
    var body: some View {
        Button(L10n.text("Export JSON")) {
            do { document = try AquariumBackupDocument(data: store.exportBackup()); exporting = true }
            catch { store.message = L10n.text("Could not export: ") + error.localizedDescription }
        }.disabled(store.isPreviewOnly)
        .fileExporter(isPresented: $exporting, document: document, contentType: .json,
                      defaultFilename: "Fishtank-\(Date().formatted(.iso8601.year().month().day().dateSeparator(.dash)))") { result in
            switch result {
            case .success: store.message = L10n.text("Backup exported. Keep the JSON file safe.")
            case .failure(let error): store.message = L10n.text("Export not completed: ") + error.localizedDescription
            }
        }
    }
}
