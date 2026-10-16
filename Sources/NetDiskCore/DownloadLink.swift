import Foundation

public struct DownloadLink: Equatable, Sendable {
    public let path: String
    public init(url: URL) throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "baidunetdisk", components.host == "download",
              let items = components.queryItems,
              items.count == 1, items[0].name == "path", let path = items[0].value,
              path.hasPrefix("/"), path != "/", !path.contains("\0"),
              !path.split(separator: "/").contains("..") else {
            throw NetDiskError.message("链接格式应为 baidunetdisk://download?path=/目录/文件，路径需要 URL 编码。")
        }
        self.path = path
    }
}
