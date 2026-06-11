import Foundation

/// 从 API 返回的扁平化书籍元数据
struct BookMetadata: Codable {
    var title: String
    var author: String
    var cover: String?
    var summary: String?
    var publisher: String?
    var pubdate: String?
    var isbn: String?
    
    // API 可能会将页数返回为 String 或 Int，需要自定义解码或支持多类型
    // 这里简单处理为 String，后续在 UI 层如果需要再转换为 Int
    var pages: String?
    
    enum CodingKeys: String, CodingKey {
        case title
        case author
        case cover
        case summary
        case publisher
        case pubdate
        case pages
        case isbn
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "未知书名"
        author = try container.decodeIfPresent(String.self, forKey: .author) ?? "未知作者"
        cover = try container.decodeIfPresent(String.self, forKey: .cover)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        publisher = try container.decodeIfPresent(String.self, forKey: .publisher)
        pubdate = try container.decodeIfPresent(String.self, forKey: .pubdate)
        isbn = try container.decodeIfPresent(String.self, forKey: .isbn)
        
        if let pagesInt = try? container.decodeIfPresent(Int.self, forKey: .pages) {
            pages = String(pagesInt)
        } else if let pagesStr = try? container.decodeIfPresent(String.self, forKey: .pages) {
            pages = pagesStr
        } else {
            pages = nil
        }
    }
    
    init(title: String, author: String, cover: String? = nil, summary: String? = nil, publisher: String? = nil, pubdate: String? = nil, pages: String? = nil, isbn: String? = nil) {
        self.title = title
        self.author = author
        self.cover = cover
        self.summary = summary
        self.publisher = publisher
        self.pubdate = pubdate
        self.pages = pages
        self.isbn = isbn
    }
}
