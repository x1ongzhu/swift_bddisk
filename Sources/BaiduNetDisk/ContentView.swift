import SwiftUI
import NetDiskCore

struct ContentView: View {
    @Bindable var model: AppModel
    @ViewState<Set<CloudFile.ID>> private var selection: Set<CloudFile.ID> = []
    @ViewState<String> private var search = ""
    @ViewState<Bool> private var targeted = false
    private var visibleFiles: [CloudFile] { model.files.filter { search.isEmpty || $0.name.localizedStandardContains(search) } }
    var body: some View {
        Group {
            if model.username == nil { LoginView(model: model) }
            else { browser }
        }
        .frame(minWidth: 640, minHeight: 420)
        .sheet(isPresented: $model.showTransfers) { TransferView(model: model) }
        .alert("操作失败", isPresented: hasError) { Button("好") { model.error = nil } } message: { Text(model.error ?? "") }
        .alert("下载链接", isPresented: hasLink) {
            if model.username != nil { Button("选择下载位置…") { if let link = model.pendingLink { Task { await model.downloadLink(link) } } } }
            Button("取消", role: .cancel) { model.pendingLink = nil }
        } message: { Text(model.username == nil ? "请先登录，然后重新打开下载链接。" : "下载 \(model.pendingLink?.path ?? "")") }
    }
    private var hasError: Binding<Bool> { Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } }) }
    private var hasLink: Binding<Bool> { Binding(get: { model.pendingLink != nil }, set: { if !$0 { model.pendingLink = nil } }) }
    private var browser: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "folder").foregroundStyle(.secondary)
                Text(model.path).lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                Spacer()
                if model.loading { ProgressView().controlSize(.small) }
            }.padding(.horizontal, 18).padding(.vertical, 10)
            Divider()
            Table(visibleFiles, selection: $selection) {
                TableColumn("名称") { file in
                    HStack {
                        Image(systemName: file.isDirectory ? "folder.fill" : "doc").foregroundStyle(file.isDirectory ? Color.accentColor : .secondary)
                        Text(file.name).lineLimit(1)
                    }
                }
                TableColumn("大小") { file in
                    Text(file.isDirectory ? "—" : ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file)).foregroundStyle(.secondary)
                }.width(110)
                TableColumn("修改时间") { file in
                    if let timestamp = file.server_mtime { Text(Date(timeIntervalSince1970: timestamp), format: .dateTime.year().month().day()).foregroundStyle(.secondary) }
                }.width(130)
            }
            .contextMenu(forSelectionType: CloudFile.ID.self) { ids in
                if let file = model.files.first(where: { ids.contains($0.id) }) {
                    Button(file.isDirectory ? "打开文件夹" : "下载…") { open(file) }
                }
            } primaryAction: { ids in
                if let file = model.files.first(where: { ids.contains($0.id) }) { open(file) }
            }
            .overlay {
                if !model.loading && visibleFiles.isEmpty {
                    ContentUnavailableView(search.isEmpty ? "文件夹为空" : "没有匹配的文件", systemImage: search.isEmpty ? "folder" : "magnifyingglass", description: Text(search.isEmpty ? "拖入文件，或点击上传。" : "尝试其他名称。"))
                        .allowsHitTesting(false)
                }
            }
            .dropDestination(for: URL.self) { urls, _ in model.upload(urls); return !urls.isEmpty } isTargeted: { targeted = $0 }
            .overlay { if targeted { RoundedRectangle(cornerRadius: 8).stroke(.tint, lineWidth: 2).padding(8).allowsHitTesting(false) } }
            Divider()
            HStack {
                Text("\(visibleFiles.count) 个项目")
                Spacer()
                Text(model.username ?? "")
            }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 18).padding(.vertical, 8)
        }
        .searchable(text: $search, placement: .toolbar, prompt: "筛选当前文件夹")
        .onChange(of: model.path) { selection = []; search = "" }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button("上一级", systemImage: "chevron.left") { model.parent() }.disabled(model.path == "/" || model.loading)
                Button("刷新", systemImage: "arrow.clockwise") { model.browse(model.path) }.disabled(model.loading)
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button("上传", systemImage: "arrow.up") { model.chooseUpload() }
                Button("下载", systemImage: "arrow.down") { for file in model.files where selection.contains(file.id) && !file.isDirectory { model.download(file) } }
                    .disabled(!model.files.contains { selection.contains($0.id) && !$0.isDirectory })
                Button("传输", systemImage: "arrow.up.arrow.down") { model.showTransfers = true }
                Menu {
                    Text(model.username ?? "")
                    Button("退出登录") { model.logout() }
                } label: { Label("账号", systemImage: "person.crop.circle") }
            }
        }
    }
    private func open(_ file: CloudFile) { if file.isDirectory { model.browse(file.path) } else { model.download(file) } }
}
