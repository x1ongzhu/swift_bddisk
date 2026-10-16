import SwiftUI
import NetDiskCore

struct LoginView: View {
    @Bindable var model: AppModel
    @ViewState<NSImage?> private var image = nil
    @ViewState<String> private var status = "正在获取二维码…"
    @ViewState<Bool> private var canRefresh = false
    @ViewState<UUID> private var generation = UUID()
    @ViewState<Bool> private var showWebLogin = false

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "externaldrive.badge.icloud").font(.largeTitle).foregroundStyle(.tint).accessibilityHidden(true)
            Text("扫码，回到你的文件。").font(.title2)
            Text("使用百度网盘 App 扫描二维码，并在手机上确认登录。")
                .foregroundStyle(.secondary)
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(.white)
                if let image {
                    Image(nsImage: image).interpolation(.none).resizable().scaledToFit().padding(12)
                        .accessibilityLabel("百度网盘登录二维码")
                        .opacity(canRefresh ? 0.2 : 1)
                } else if !canRefresh { ProgressView("加载二维码").foregroundStyle(.black) }
                if canRefresh {
                    Button("刷新二维码", systemImage: "arrow.clockwise") { generation = UUID() }
                        .buttonStyle(.borderedProminent)
                }
            }.frame(width: 220, height: 220)
            Text(status).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 380)
            Button("使用短信验证码登录") { showWebLogin = true }
                .buttonStyle(.link)
            Text("登录会话安全保存在本机钥匙串。")
                .font(.caption).foregroundStyle(.tertiary)
        }
        .padding(40)
        .sheet(isPresented: $showWebLogin) { WebLoginView(model: model) }
        .task(id: "\(generation)-\(showWebLogin)") { if !showWebLogin { await scan() } }
    }
    private func scan() async {
        image = nil
        canRefresh = false
        status = "正在获取二维码…"
        let client = QRCodeLogin()
        do {
            let challenge = try await client.generate()
            try Task.checkCancellation()
            guard let decoded = NSImage(data: challenge.image) else { throw NetDiskError.message("二维码图片加载失败。") }
            image = decoded
            status = "打开百度网盘 App 扫一扫"
            while !Task.isCancelled {
                let result = try await client.poll(challenge)
                try Task.checkCancellation()
                switch result {
                case .waiting: status = "打开百度网盘 App 扫一扫"
                case .scanned: status = "已扫描，请在手机上确认登录"
                case .expired: status = "二维码已过期"; canRefresh = true; return
                case .confirmed(let code):
                    status = "正在连接你的网盘…"
                    let credentials = try await client.confirm(code: code)
                    try Task.checkCancellation()
                    await model.login(cookie: credentials.cookie)
                    try Task.checkCancellation()
                    if model.username == nil { status = "登录未完成，请重新扫码"; canRefresh = true }
                    return
                }
                try await Task.sleep(for: .seconds(3))
            }
        } catch {
            guard !Task.isCancelled else { return }
            status = error.localizedDescription
            canRefresh = true
        }
    }
}
