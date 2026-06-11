import Foundation
import SwiftUI

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case serverError(statusCode: Int, url: String)
    case missingToken
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的 API 地址"
        case .noData: return "未返回任何数据"
        case .decodingError: return "数据解析失败，请确保 API 返回扁平化的 JSON"
        case .serverError(let code, let url): return "服务器错误 (状态码: \(code))\n请求地址: \(url)"
        case .missingToken: return "请到「偏好设置」中输入您的邀请码"
        }
    }
}

class NetworkManager {
    /// 根据 ISBN 请求书籍数据
    func fetchBookInfo(isbn: String) async throws -> BookMetadata {
        var customApiUrl = UserDefaults.standard.string(forKey: "customApiUrl") ?? "https://jixiaokui.icu/api/book"
        
        // 自动将旧的 http 和旧 IP 修正为最新的 https 域名，并同步到 UserDefaults
        if customApiUrl.hasPrefix("http://jixiaokui.icu") || customApiUrl.contains("118.25.58.73") {
            customApiUrl = "https://jixiaokui.icu/api/book"
            UserDefaults.standard.set(customApiUrl, forKey: "customApiUrl")
        }
        
        let rawToken = UserDefaults.standard.string(forKey: "customApiToken") ?? ""
        let customApiToken = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if customApiToken.isEmpty {
            throw NetworkError.missingToken
        }
        
        guard !customApiUrl.isEmpty else {
            // 提供一个本地 Mock 兜底，方便没有配置 API 的用户体验 UI
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 模拟网络延迟
            return BookMetadata(
                title: "代码大全 (Mock)",
                author: "史蒂夫·迈克康奈尔",
                cover: "https://img3.doubanio.com/view/subject/l/public/s1470003.jpg",
                summary: "这是一本经典的软件工程实践书籍...",
                publisher: "电子工业出版社",
                pubdate: "2006-03",
                pages: "944",
                isbn: isbn
            )
        }
        
        // 构建 URL
        // 如果 customApiUrl 本身带有参数(比如包含 "?")，则用 "&" 拼接，否则用 "?" 拼接
        // 这里做一个简单的处理，如文档所述：若没有插值，直接在尾部追加 isbn
        let trimmedIsbn = isbn.trimmingCharacters(in: .whitespacesAndNewlines)
        var urlString = customApiUrl
        if !urlString.contains("isbn=") {
            let separator = urlString.contains("?") ? "&" : "?"
            urlString = "\(urlString)\(separator)isbn=\(trimmedIsbn)"
        } else {
            // 如果用户自己配了类似 ?isbn= ，这里暂时不做智能替换，按文档逻辑是在末尾直接追加，
            // 假设用户输入的 url 带有 `isbn=`，则直接补齐：
            urlString = "\(urlString)\(trimmedIsbn)"
        }
        
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // 添加 Token
        if !customApiToken.isEmpty {
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue(customApiToken, forHTTPHeaderField: "X-API-Token")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.serverError(statusCode: 0, url: urlString)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.serverError(statusCode: httpResponse.statusCode, url: urlString)
        }
        
        do {
            let metadata = try JSONDecoder().decode(BookMetadata.self, from: data)
            return metadata
        } catch {
            print("Decoding error: \(error)")
            throw NetworkError.decodingError
        }
    }
}
