import SwiftUI

struct TransferView: View {
    @Bindable var model: AppModel
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("传输").font(.headline)
                Spacer()
                Button("清除已结束") { model.transfers.removeAll(where: \.finished) }
                Button("关闭", systemImage: "xmark") { model.showTransfers = false }.labelStyle(.iconOnly)
            }.padding()
            Divider()
            if model.transfers.isEmpty {
                ContentUnavailableView("暂无传输", systemImage: "arrow.up.arrow.down", description: Text("上传和下载任务会出现在这里。"))
            } else {
                List(model.transfers) { transfer in
                    HStack {
                        Image(systemName: transfer.upload ? "arrow.up.circle" : "arrow.down.circle").foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(transfer.name).lineLimit(1)
                            ProgressView(value: transfer.fraction).accessibilityLabel("传输进度")
                            HStack {
                                Text(transfer.state).lineLimit(2)
                                Spacer()
                                Text("\(ByteCountFormatter.string(fromByteCount: transfer.completed, countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: transfer.total, countStyle: .file))")
                            }.font(.caption).foregroundStyle(.secondary)
                        }
                        if !transfer.finished {
                            Button("取消", systemImage: "xmark.circle") { model.cancel(transfer.id) }.labelStyle(.iconOnly)
                        } else if let destination = transfer.destination, transfer.state == "已完成" {
                            Button("在 Finder 中显示", systemImage: "folder") { NSWorkspace.shared.activateFileViewerSelecting([destination]) }.labelStyle(.iconOnly)
                        }
                    }.padding(.vertical, 6)
                }
            }
        }.frame(width: 560, height: 380)
    }
}
