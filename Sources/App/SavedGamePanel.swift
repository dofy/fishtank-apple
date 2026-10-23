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
            HStack(spacing: 8) { PixelIcon("book", color: PixelTheme.gold); Text(L10n.text("存档与恢复")).foregroundStyle(PixelTheme.gold) }
            #if os(iOS)
            Text(store.isPreviewOnly ? L10n.text("当前是临时预览，原存档未被覆盖。请从备份恢复，或导入有效文件。") : L10n.text("每 15 秒自动保存；每 5 分钟保留一份上次进度。建议在换设备前导出。"))
                .font(PixelTheme.captionFont()).foregroundStyle(PixelTheme.muted).fixedSize(horizontal: false, vertical: true)
            #endif
            HStack {
                #if os(iOS)
                BackupExportButton(store: store)
                #endif
                Button(L10n.text("导入 JSON")) { importing = true }
            }
            Text(L10n.text("支持本应用备份和原网页版 v1 JSON。导入前先预览，再确认替换；不会合并两个鱼缸。网页版旧昵称、收藏和布局元数据保留在原始快照中。"))
                .font(PixelTheme.captionFont()).foregroundStyle(PixelTheme.muted).fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { recoveryActions }.frame(minWidth: 496)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: PixelTheme.metric(160, 240)), spacing: 8)], alignment: .leading, spacing: 8) {
                    recoveryActions
                }
            }
            if let candidate = pending {
                VStack(alignment: .leading, spacing: 14) {
                    Text(L10n.text("导入预览 · ") + importSource).foregroundStyle(PixelTheme.gold)
                    Text(L10n.text("Lv.\(candidate.level) · \(candidate.fish.count) 条鱼 · \(candidate.discovered.count) 种图鉴 · \(candidate.hearts)/5 爱心"))
                    Text(L10n.text("上次保存：") + candidate.lastUpdated.formatted(date: .abbreviated, time: .shortened))
                    Text(L10n.text("确认后替换当前进度，并结算离线成长。当前原文件会先备份。"))
                        .foregroundStyle(PixelTheme.pink).fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button(L10n.text("取消")) { pending = nil }
                        Spacer()
                        Button(L10n.text("确认替换")) { if store.importBackup(candidate) { pending = nil } }
                    }
                }.padding(14).pixelPanel(selected: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(16).pixelPanel()
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url): preview(url, title: url.lastPathComponent)
            case .failure(let error): store.message = L10n.text("文件选择未完成：") + error.localizedDescription
            }
        }

    }
    private var recoveryActions: some View {
        Group {
            ForEach(store.recoveryURLs, id: \.1) { title, url in
                Button { preview(url, title: title) } label: {
                    Text(L10n.text("恢复 · ") + title).frame(minWidth: 136, maxWidth: .infinity)
                }
            }
            Button {
                pending = .newGame(at: Date()); importSource = L10n.text("全新鱼缸")
            } label: {
                Text(L10n.text("重新开始一缸海")).frame(minWidth: 136, maxWidth: .infinity)
            }
        }
    }
    private func preview(_ url: URL, title: String) {
        do { pending = try store.previewImport(url); importSource = title }
        catch { pending = nil; store.message = L10n.text("无法读取此备份：") + error.localizedDescription }
    }
}

struct BackupExportButton: View {
    @ObservedObject private var localization = AppLocalization.shared
    @ObservedObject var store: AquariumStore
    @State private var exporting = false
    @State private var document = AquariumBackupDocument()
    var body: some View {
        Button(L10n.text("导出 JSON")) {
            do { document = try AquariumBackupDocument(data: store.exportBackup()); exporting = true }
            catch { store.message = L10n.text("无法导出：") + error.localizedDescription }
        }.disabled(store.isPreviewOnly)
        .fileExporter(isPresented: $exporting, document: document, contentType: .json,
                      defaultFilename: "Fishtank-\(Date().formatted(.iso8601.year().month().day().dateSeparator(.dash)))") { result in
            switch result {
            case .success: store.message = L10n.text("备份已导出。请妥善保留 JSON 文件。")
            case .failure(let error): store.message = L10n.text("导出未完成：") + error.localizedDescription
            }
        }
    }
}
