import SwiftUI

struct WebLoginView: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @ViewState<WebLoginSession> private var session = WebLoginSession()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("短信登录").font(.headline)
                    Label("百度网盘官方登录 · pan.baidu.com", systemImage: "lock.shield").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("刷新页面", systemImage: "arrow.clockwise", action: session.reload).labelStyle(.iconOnly)
                    .disabled(model.signingIn)
                Button("返回扫码登录") { dismiss() }.disabled(model.signingIn)
            }.padding()
            Divider()
            OfficialLoginWebView(session: session)
                .overlay(alignment: .top) { if session.loading { ProgressView().progressViewStyle(.linear) } }
            Divider()
            HStack {
                if model.signingIn { ProgressView().controlSize(.small) }
                Text(session.message).font(.callout).foregroundStyle(.secondary)
                Spacer()
                if session.failed { Button("重试连接", action: session.retrySession).disabled(model.signingIn) }
            }.padding().frame(minHeight: 56)
        }
        .frame(width: 720, height: 580)
        .task { await session.monitor(model: model) }
        .onChange(of: model.username) { if model.username != nil { dismiss() } }
    }
}
