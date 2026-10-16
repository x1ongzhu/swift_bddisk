import Foundation

public actor BaiduAPI {
    public static let userAgent = "netdisk;P2SP;3.0.0.8;netdisk;11.12.3;ANG-AN00;android-android;10.0;JSbridge4.4.0;jointBridge;1.1.0;"
    private let credentials: Credentials
    private let session: URLSession
    private var uid: UInt64 = 0
    public init(credentials: Credentials) {
        self.credentials = credentials
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 60
        configuration.httpShouldSetCookies = false
        session = URLSession(configuration: configuration)
    }
    private func request(_ endpoint: String, parameters: [String: String] = [:], method: String = "GET", body: Data? = nil, contentType: String? = nil) throws -> URLRequest {
        guard var components = URLComponents(string: endpoint) else { throw NetDiskError.message("无效接口地址") }
        components.queryItems = parameters.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { throw NetDiskError.message("无法构造请求") }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue(credentials.cookie, forHTTPHeaderField: "Cookie")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://pan.baidu.com/disk/home", forHTTPHeaderField: "Referer")
        if let contentType { request.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        return request
    }
    private func json(_ request: URLRequest) async throws -> [String: Any] {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode) else {
            throw NetDiskError.message("百度接口请求失败，请重试。")
        }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NetDiskError.message("接口返回格式异常。")
        }
        let code = (object["errno"] as? NSNumber ?? object["error_code"] as? NSNumber)?.intValue ?? 0
        guard code == 0 else { throw NetDiskError.message("百度接口错误 \(code)，请检查登录状态后重试。") }
        return object
    }
    private func form(_ endpoint: String, fields: [String: String]) async throws -> [String: Any] {
        var components = URLComponents()
        components.queryItems = fields.map { URLQueryItem(name: $0.key, value: $0.value) }
        let body = Data((components.percentEncodedQuery ?? "").replacing("+", with: "%2B").utf8)
        return try await json(request(endpoint, method: "POST", body: body, contentType: "application/x-www-form-urlencoded"))
    }
    public func login() async throws -> String {
        let object = try await json(request("https://pan.baidu.com/rest/2.0/membership/user/info", parameters: ["method": "query", "app_id": "250528", "clienttype": "0", "web": "1"]))
        guard let user = object["user_info"] as? [String: Any],
              let number = user["uk"] as? NSNumber ?? user["user_id"] as? NSNumber, number.uint64Value > 0 else {
            throw NetDiskError.message("无法验证账号，请更新 Cookie。")
        }
        uid = number.uint64Value
        return user["username"] as? String ?? user["baidu_name"] as? String ?? "百度网盘用户"
    }
    public func list(path: String) async throws -> [CloudFile] {
        var files: [CloudFile] = []
        var page = 1
        while true {
            try Task.checkCancellation()
            let object = try await json(request("https://pan.baidu.com/rest/2.0/xpan/file", parameters: ["method": "list", "dir": path, "order": "name", "desc": "0", "showempty": "0", "web": "1", "page": String(page), "num": "1000"]))
            guard let entries = object["list"] as? [[String: Any]] else { throw NetDiskError.message("文件列表返回格式异常。") }
            let batch = try JSONDecoder().decode([CloudFile].self, from: JSONSerialization.data(withJSONObject: entries))
            files.append(contentsOf: batch)
            if batch.count < 1000 { break }
            page += 1
        }
        return files
    }
    private func downloadURL(path: String) async throws -> URL {
        guard uid > 0 else { throw NetDiskError.message("请先登录。") }
        var parameters = LocateSignature.parameters(bduss: credentials.bduss, uid: uid, time: Int64(Date.now.timeIntervalSince1970))
        parameters.merge(["ant": "1", "check_blue": "1", "es": "1", "esl": "1", "app_id": "250528", "method": "locatedownload", "path": path, "ver": "4.0", "clienttype": "17", "channel": "0", "apn_id": "1_0", "freeisp": "0", "queryfree": "0", "use": "0"], uniquingKeysWith: { _, new in new })
        let object = try await json(request("https://pcs.baidu.com/rest/2.0/pcs/file", parameters: parameters, method: "POST"))
        guard let entries = object["urls"] as? [[String: Any]],
              let text = entries.first(where: { ($0["encrypt"] as? Int) == 0 })?["url"] as? String,
              var components = URLComponents(string: text) else { throw NetDiskError.message("没有可用的下载地址。") }
        // Download URLs may use HTTP; use TLS for the native client.
        components.scheme = "https"
        guard let url = components.url else { throw NetDiskError.message("下载地址无效。") }
        return url
    }
    public func download(file: CloudFile, destination: URL, progress: @Sendable (Int64, Int64) async -> Void) async throws {
        guard !file.isDirectory else { throw NetDiskError.message("请选择文件下载。") }
        let temporary = destination.deletingLastPathComponent().appending(path: ".\(UUID().uuidString).part")
        guard FileManager.default.createFile(atPath: temporary.path, contents: nil) else { throw NetDiskError.message("无法创建下载文件。") }
        defer { try? FileManager.default.removeItem(at: temporary) }
        let handle = try FileHandle(forWritingTo: temporary)
        defer { try? handle.close() }
        var offset: Int64 = 0
        var url = try await downloadURL(path: file.path)
        while offset < file.size {
            try Task.checkCancellation()
            let end = min(offset + 4 * 1024 * 1024 - 1, file.size - 1)
            var data: Data?
            for attempt in 0..<3 {
                var request = URLRequest(url: url)
                request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
                request.setValue("bytes=\(offset)-\(end)", forHTTPHeaderField: "Range")
                request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
                let (chunk, response) = try await session.data(for: request)
                if let response = response as? HTTPURLResponse, response.statusCode == 206,
                   response.value(forHTTPHeaderField: "Content-Range") == "bytes \(offset)-\(end)/\(file.size)", chunk.count == Int(end - offset + 1) {
                    data = chunk
                    break
                }
                if attempt < 2 { url = try await downloadURL(path: file.path) }
            }
            guard let data else { throw NetDiskError.message("下载分段校验失败，请重试。") }
            try handle.write(contentsOf: data)
            offset += Int64(data.count)
            await progress(offset, file.size)
        }
        try handle.synchronize()
        try Task.checkCancellation()
        // Never overwrite existing files.
        try FileManager.default.moveItem(at: temporary, to: destination)
        await progress(file.size, file.size)
    }
    public func upload(source: URL, directory: String, progress: @Sendable (Int64, Int64) async -> Void) async throws {
        let handle = try FileHandle(forReadingFrom: source)
        defer { try? handle.close() }
        let size = Int64(try handle.seekToEnd())
        try handle.seek(toOffset: 0)
        let chunkSize = 4 * 1024 * 1024
        var hashes: [String] = []
        repeat {
            try Task.checkCancellation()
            let data = try handle.read(upToCount: chunkSize) ?? Data()
            if data.isEmpty && !hashes.isEmpty { break }
            hashes.append(LocateSignature.md5(data))
            if data.count < chunkSize { break }
        } while true
        let path = (directory == "/" ? "" : directory) + "/" + source.lastPathComponent
        let blockList = String(decoding: try JSONEncoder().encode(hashes), as: UTF8.self)
        var fields = ["path": path, "size": String(size), "isdir": "0", "rtype": "1", "block_list": blockList, "autoinit": "1"]
        let precreate = try await form("https://pan.baidu.com/api/precreate", fields: fields)
        if precreate["return_type"] as? Int == 2 { await progress(size, size); return }
        guard let uploadID = precreate["uploadid"] as? String, !uploadID.isEmpty,
              let required = precreate["block_list"] as? [Int], required.allSatisfy({ hashes.indices.contains($0) }) else {
            throw NetDiskError.message("预创建上传返回格式异常。")
        }
        var completed = size - required.reduce(Int64(0)) { $0 + min(Int64(chunkSize), max(0, size - Int64($1 * chunkSize))) }
        for index in required {
            try Task.checkCancellation()
            try handle.seek(toOffset: UInt64(index * chunkSize))
            let data = try handle.read(upToCount: chunkSize) ?? Data()
            guard LocateSignature.md5(data) == hashes[index] else { throw NetDiskError.message("本地文件在上传期间发生变化。") }
            let boundary = UUID().uuidString
            var body = Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"file\"\r\nContent-Type: application/octet-stream\r\n\r\n".utf8)
            body.append(data)
            body.append(Data("\r\n--\(boundary)--\r\n".utf8))
            let object = try await json(request("https://d.pcs.baidu.com/rest/2.0/pcs/superfile2", parameters: ["method": "upload", "app_id": "250528", "type": "tmpfile", "path": path, "uploadid": uploadID, "partseq": String(index)], method: "POST", body: body, contentType: "multipart/form-data; boundary=\(boundary)"))
            guard object["md5"] as? String == hashes[index] else { throw NetDiskError.message("上传分片校验失败。") }
            completed += Int64(data.count)
            await progress(completed, size)
        }
        try Task.checkCancellation()
        fields.removeValue(forKey: "autoinit")
        fields["uploadid"] = uploadID
        _ = try await form("https://pan.baidu.com/api/create", fields: fields)
        await progress(size, size)
    }
}
