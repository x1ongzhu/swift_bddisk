import Foundation

public actor QRCodeLogin {
    private let session: URLSession
    public init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        session = URLSession(configuration: configuration)
    }
    private func fetch(_ endpoint: String, parameters: [String: String]) async throws -> Data {
        guard var components = URLComponents(string: endpoint) else { throw NetDiskError.message("登录接口地址无效。") }
        components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { throw NetDiskError.message("登录请求无效。") }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { throw NetDiskError.message("无法连接百度登录服务，请重试。") }
        return data
    }
    public func generate() async throws -> QRCodeChallenge {
        let data = try await fetch("https://passport.baidu.com/v2/api/getqrcode", parameters: ["lp": "pc", "qrloginfrom": "pc", "gid": UUID().uuidString, "callback": "tangram_guid_client", "apiver": "v3", "tt": String(Int64(Date.now.timeIntervalSince1970 * 1000)), "tpl": "netdisk"])
        let text = String(decoding: data, as: UTF8.self)
        guard let start = text.firstIndex(of: "("), let end = text.lastIndex(of: ")"), start < end,
              let object = try JSONSerialization.jsonObject(with: Data(text[text.index(after: start)..<end].utf8)) as? [String: Any],
              let imageURL = object["imgurl"] as? String,
              let sign = URLComponents(string: imageURL.hasPrefix("http") ? imageURL : "https://" + imageURL)?.queryItems?.first(where: { $0.name == "sign" })?.value, !sign.isEmpty else {
            throw NetDiskError.message("无法获取二维码，请重试。")
        }
        let image = try await fetch("https://passport.baidu.com/v2/api/qrcode", parameters: ["sign": sign, "lp": "mobile", "qrloginfrom": "mobile", "tpl": "netdisk"])
        return QRCodeChallenge(sign: sign, image: image, expires: .now.addingTimeInterval(120))
    }
    public func poll(_ challenge: QRCodeChallenge) async throws -> QRCodeStatus {
        guard Date.now < challenge.expires else { return .expired }
        let data = try await fetch("https://passport.baidu.com/channel/unicast", parameters: ["channel_id": challenge.sign, "tpl": "netdisk", "apiver": "v3", "tt": String(Int64(Date.now.timeIntervalSince1970 * 1000))])
        guard Date.now < challenge.expires else { return .expired }
        return try QRCodeStatus.decode(data)
    }
    public func confirm(code: String) async throws -> Credentials {
        let timestamp = String(Int64(Date.now.timeIntervalSince1970 * 1000))
        _ = try await fetch("https://passport.baidu.com/v3/login/main/qrbdusslogin", parameters: ["v": timestamp, "bduss": code, "u": "https://pan.baidu.com/disk/main", "tpl": "netdisk", "qrcode": "1", "apiver": "v3", "tt": timestamp])
        let cookies = session.configuration.httpCookieStorage?.cookies ?? []
        let allowed: Set<String> = ["BDUSS", "STOKEN", "PTOKEN", "BAIDUID", "PASSID", "SBOXTKN", "PANPSC", "csrfToken"]
        var values: [String: String] = [:]
        for cookie in cookies where allowed.contains(cookie.name) && (cookie.domain == "baidu.com" || cookie.domain.hasSuffix(".baidu.com")) {
            values[cookie.name] = cookie.value
        }
        guard let bduss = values["BDUSS"], !bduss.isEmpty else {
            throw NetDiskError.message("登录确认未完成，请刷新二维码后重新扫码。")
        }
        return try Credentials(raw: values.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "; "))
    }
}
