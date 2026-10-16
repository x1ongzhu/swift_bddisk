import Foundation
import Testing
@testable import NetDiskCore

@Test func cookiePreservesEquals() throws {
    let credentials = try Credentials(raw: "BDUSS=abc==;\n STOKEN=value")
    #expect(credentials.bduss == "abc==")
    #expect(credentials.cookie == "BDUSS=abc==; STOKEN=value")
    #expect(throws: NetDiskError.self) { try Credentials(raw: "STOKEN=x") }
}
@Test func downloadLinkDecodesPath() throws {
    let url = try #require(URL(string: "baidunetdisk://download?path=%2F%E6%96%87%E4%BB%B6%2Fa%2Bb.txt"))
    #expect(try DownloadLink(url: url).path == "/文件/a+b.txt")
}
@Test func downloadLinkRejectsInvalidInput() throws {
    for text in ["https://download?path=/a", "baidunetdisk://download?path=/../a", "baidunetdisk://download?path=/", "baidunetdisk://download?path=/a&path=/b"] {
        let url = try #require(URL(string: text))
        #expect(throws: NetDiskError.self) { try DownloadLink(url: url) }
    }
}
@Test func signatureMatchesReferenceAlgorithm() {
    let parameters = LocateSignature.parameters(bduss: "test", uid: 123456789, time: 1699999999)
    #expect(parameters["devuid"] == "098F6BCD4621D373CADE4E832627B4F6|0")
    #expect(parameters["cuid"] == parameters["devuid"])
    #expect(LocateSignature.md5(Data()) == "d41d8cd98f00b204e9800998ecf8427e")
    #expect(parameters["rand"] == "11a4deb4d5908c5e9ce3b62de3d1d148af925e3f")
}
@Test func fileDecodingPreservesLargeIdentifiers() throws {
    let data = Data(#"{"fs_id":9007199254740993,"path":"/a","server_filename":"a","size":2,"isdir":0}"#.utf8)
    let file = try JSONDecoder().decode(CloudFile.self, from: data)
    #expect(file.id == 9007199254740993)
    #expect(!file.isDirectory)
}

@Test func qrCodeDistinguishesScanFromConfirmation() throws {
    #expect(try QRCodeStatus.decode(Data(#"{"channel_v":"{\"status\":0}"}"#.utf8)) == .waiting)
    #expect(try QRCodeStatus.decode(Data(#"{"channel_v":"{\"status\":1}"}"#.utf8)) == .scanned)
    #expect(try QRCodeStatus.decode(Data(#"{"channel_v":"{\"status\":0,\"v\":\"confirmation\"}"}"#.utf8)) == .confirmed("confirmation"))
    #expect(try QRCodeStatus.decode(Data(#"{"channel_v":"{\"status\":-1}"}"#.utf8)) == .expired)
    #expect(throws: NetDiskError.self) { try QRCodeStatus.decode(Data(#"{"channel_v":"{\"status\":2}"}"#.utf8)) }
    #expect(throws: NetDiskError.self) { try QRCodeStatus.decode(Data(#"{"errno":1}"#.utf8)) }
}

@Test func webLoginNavigationRejectsLookalikeDomains() throws {
    for text in ["https://passport.baidu.com/v2/", "https://pan.baidu.com/disk/main", "https://passport.bdstatic.com/a", "about:blank"] {
        #expect(WebLoginPolicy.allowsNavigation(try #require(URL(string: text))))
    }
    for text in ["https://baidu.com.example.org/", "https://fakebaidu.com/", "http://passport.baidu.com/", "file:///tmp/a", "baidunetdisk://download?path=/a"] {
        #expect(!WebLoginPolicy.allowsNavigation(try #require(URL(string: text))))
    }
}

@Test func webLoginExtractsOnlyApplicableSessionCookies() throws {
    func cookie(_ name: String, value: String, domain: String, path: String = "/", expired: Bool = false) throws -> HTTPCookie {
        var properties: [HTTPCookiePropertyKey: Any] = [.name: name, .value: value, .domain: domain, .path: path]
        if expired { properties[.expires] = Date.now.addingTimeInterval(-60) }
        return try #require(HTTPCookie(properties: properties))
    }
    let cookies = try [cookie("BDUSS", value: "root", domain: ".baidu.com"), cookie("BDUSS", value: "netdisk", domain: "pan.baidu.com"), cookie("PTOKEN", value: "secret", domain: ".baidu.com"), cookie("BDUSS", value: "wrong", domain: "evil.baidu.com"), cookie("tracking", value: "ignored", domain: ".baidu.com"), cookie("STOKEN", value: "expired", domain: ".baidu.com", expired: true), cookie("PASSID", value: "wrong-path", domain: ".baidu.com", path: "/other")]
    let credentials = try #require(try WebLoginPolicy.credentials(from: cookies))
    #expect(credentials.bduss == "netdisk")
    #expect(credentials.cookie == "BDUSS=netdisk; PTOKEN=secret")
    #expect(try WebLoginPolicy.credentials(from: [cookie("BDUSS", value: "fake", domain: "baidu.com.example.org")]) == nil)
}
