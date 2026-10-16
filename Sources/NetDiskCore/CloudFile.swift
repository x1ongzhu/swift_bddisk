import Foundation

public struct CloudFile: Decodable, Identifiable, Hashable, Sendable {
    public let fs_id: UInt64
    public let path: String
    public let server_filename: String
    public let size: Int64
    public let isdir: Int
    public let server_mtime: Double?
    public var id: UInt64 { fs_id }
    public var isDirectory: Bool { isdir == 1 }
    public var name: String { server_filename }
}
