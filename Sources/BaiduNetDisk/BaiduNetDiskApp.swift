import SwiftUI

@main
struct BaiduNetDiskApp: App {
    @ViewState<AppModel> private var model = AppModel()
    var body: some Scene {
        WindowGroup("网盘", id: "main") {
            ContentView(model: model)
                .task { await model.restore() }
                .onOpenURL { model.receive($0) }
        }
        .defaultSize(width: 860, height: 580)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("上传文件…") { model.chooseUpload() }
                    .keyboardShortcut("u", modifiers: [.command, .shift])
                    .disabled(model.username == nil)
                Button("刷新") { model.browse(model.path) }
                    .keyboardShortcut("r").disabled(model.username == nil)
                Button("传输列表") { model.showTransfers.toggle() }
                    .keyboardShortcut("j")
            }
        }
    }
}
