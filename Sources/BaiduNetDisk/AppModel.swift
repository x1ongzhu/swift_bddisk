import SwiftUI
import NetDiskCore
import UniformTypeIdentifiers

@Observable @MainActor
final class AppModel {
    var files: [CloudFile] = []
    var path = "/"
    var username: String?
    var loading = false
    var signingIn = false
    var error: String?
    var transfers: [Transfer] = []
    var pendingLink: DownloadLink?
    var showTransfers = false
    private var api: BaiduAPI?
    private var browseTask: Task<Void, Never>?
    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var browseGeneration = UUID()

    func restore() async {
        do { if let cookie = try KeychainStore.read() { await login(cookie: cookie) } }
        catch { self.error = error.localizedDescription }
    }
    func login(cookie: String) async {
        guard !signingIn else { return }
        signingIn = true
        defer { signingIn = false }
        do {
            let credentials = try Credentials(raw: cookie)
            let client = BaiduAPI(credentials: credentials)
            let name = try await client.login()
            try Task.checkCancellation()
            try KeychainStore.save(credentials.cookie)
            api = client
            username = name
            browse("/")
        } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
    }
    func logout() {
        do { try KeychainStore.delete() }
        catch { self.error = error.localizedDescription; return }
        browseTask?.cancel()
        browseGeneration = UUID()
        for id in Array(tasks.keys) { cancel(id) }
        api = nil
        username = nil
        files = []
        path = "/"
        loading = false
    }
    func browse(_ directory: String) {
        guard let api else { return }
        browseTask?.cancel()
        let generation = UUID()
        browseGeneration = generation
        path = directory
        files = []
        loading = true
        browseTask = Task {
            do {
                let items = try await api.list(path: directory)
                guard generation == browseGeneration else { return }
                files = items.sorted { $0.isDirectory == $1.isDirectory ? $0.name.localizedStandardCompare($1.name) == .orderedAscending : $0.isDirectory }
            } catch {
                if generation == browseGeneration && !Task.isCancelled { self.error = error.localizedDescription }
            }
            if generation == browseGeneration { loading = false }
        }
    }
    func parent() { browse((path as NSString).deletingLastPathComponent.isEmpty ? "/" : (path as NSString).deletingLastPathComponent) }
    func receive(_ url: URL) {
        do { pendingLink = try DownloadLink(url: url) }
        catch { self.error = error.localizedDescription }
    }
    func downloadLink(_ link: DownloadLink) async {
        guard let api else { return }
        pendingLink = nil
        do {
            let directory = (link.path as NSString).deletingLastPathComponent
            let files = try await api.list(path: directory.isEmpty ? "/" : directory)
            guard let file = files.first(where: { $0.path == link.path && !$0.isDirectory }) else { throw NetDiskError.message("链接中的文件不存在，或它是文件夹。") }
            download(file)
        } catch { self.error = error.localizedDescription }
    }
    func download(_ file: CloudFile) {
        guard let api, !file.isDirectory else { return }
        guard !file.name.isEmpty, file.name != ".", file.name != "..", !file.name.contains("/"), !file.name.contains("\0") else { error = "文件名无效。"; return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "下载到此文件夹"
        guard panel.runModal() == .OK, let directory = panel.url else { return }
        let destination = directory.appending(path: file.name)
        guard !FileManager.default.fileExists(atPath: destination.path) else { error = "目标文件已存在，请选择其他文件夹。"; return }
        let transfer = Transfer(name: file.name, upload: false, total: file.size, destination: destination)
        start(transfer) { progress in try await api.download(file: file, destination: destination, progress: progress) }
    }
    func chooseUpload() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.prompt = "上传"
        if panel.runModal() == .OK { upload(panel.urls) }
    }
    func upload(_ urls: [URL]) {
        guard let api else { return }
        let directory = path
        for url in urls {
            guard url.isFileURL else { continue }
            let transfer = Transfer(name: url.lastPathComponent, upload: true)
            start(transfer) { progress in
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                guard try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { throw NetDiskError.message("首版仅支持上传文件，请不要选择文件夹。") }
                try await api.upload(source: url, directory: directory, progress: progress)
            }
        }
    }
    private func start(_ transfer: Transfer, operation: @escaping @Sendable (@Sendable (Int64, Int64) async -> Void) async throws -> Void) {
        transfers.append(transfer)
        showTransfers = true
        let id = transfer.id
        tasks[id] = Task {
            update(id) { $0.state = "传输中" }
            do {
                try await operation { completed, total in
                    await self.report(id, completed: completed, total: total)
                }
                try Task.checkCancellation()
                update(id) { $0.state = "已完成"; $0.finished = true }
                if transfer.upload { browse(path) }
            } catch {
                update(id) { $0.state = Task.isCancelled ? "已取消" : error.localizedDescription; $0.finished = true }
            }
            tasks.removeValue(forKey: id)
        }
    }
    private func report(_ id: UUID, completed: Int64, total: Int64) {
        update(id) { $0.completed = completed; $0.total = total }
    }
    private func update(_ id: UUID, change: (inout Transfer) -> Void) {
        if let index = transfers.firstIndex(where: { $0.id == id }) { change(&transfers[index]) }
    }
    func cancel(_ id: UUID) { tasks[id]?.cancel() }
}
