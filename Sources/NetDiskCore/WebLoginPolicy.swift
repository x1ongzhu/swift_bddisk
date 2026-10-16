import Foundation

public enum WebLoginPolicy {
    public static func allowsNavigation(_ url: URL) -> Bool {
        if url.absoluteString == "about:blank" { return true }
        guard url.scheme?.lowercased() == "https", let host = url.host?.lowercased() else { return false }
        return ["baidu.com", "bdstatic.com", "bdimg.com"].contains { host == $0 || host.hasSuffix("." + $0) }
    }

    public static func credentials(from cookies: [HTTPCookie], now: Date = .now) throws -> Credentials? {
        let allowed: Set<String> = ["BDUSS", "STOKEN", "PTOKEN", "BAIDUID", "PASSID", "SBOXTKN", "PANPSC", "csrfToken"]
        // Prefer the cookies actually applicable to the Netdisk host over Passport-only cookies.
        let candidates = cookies.filter {
            let domain = $0.domain.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
            return (domain == "baidu.com" || domain == "pan.baidu.com") && $0.path == "/"
                && allowed.contains($0.name) && !$0.value.isEmpty && ($0.expiresDate.map { $0 > now } ?? true)
        }.sorted { $0.domain.count < $1.domain.count }
        var values: [String: String] = [:]
        for cookie in candidates { values[cookie.name] = cookie.value }
        guard let bduss = values["BDUSS"], !bduss.isEmpty else { return nil }
        return try Credentials(raw: values.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "; "))
    }
}
