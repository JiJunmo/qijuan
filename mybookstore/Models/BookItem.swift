import Foundation
import SwiftData

/// 书籍阅读状态
enum BookStatus: String, CaseIterable, Identifiable, Codable {
    case unread = "Unread"
    case reading = "Reading"
    case finished = "Finished"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .unread: return "未读"
        case .reading: return "在读"
        case .finished: return "已读"
        }
    }
}

/// 书籍实体模型
@Model
final class BookItem: Identifiable {
    @Attribute(.unique) var id: String
    var title: String
    var author: String
    var coverColorHex: String
    var coverUrl: String?
    var status: BookStatus
    var category: [String]
    var pages: Int
    var currentPage: Int
    var addTime: Date
    var publisher: String
    var publishDate: String
    var isbn: String
    
    @Relationship(deleteRule: .cascade, inverse: \ReadingSession.book)
    var sessions: [ReadingSession] = []
    
    @Relationship(deleteRule: .cascade, inverse: \NoteItem.book)
    var notes: [NoteItem] = []
    
    /// 用于计算阅读进度的百分比 (0.0...1.0)
    var progress: Double {
        guard pages > 0 else { return 0 }
        return Double(currentPage) / Double(pages)
    }
    
    init(id: String = UUID().uuidString,
         title: String,
         author: String,
         coverColorHex: String,
         coverUrl: String? = nil,
         status: BookStatus = .unread,
         category: [String] = [],
         pages: Int = 0,
         currentPage: Int = 0,
         addTime: Date = Date(),
         publisher: String = "",
         publishDate: String = "",
         isbn: String = "") {
        self.id = id
        self.title = title
        self.author = author
        self.coverColorHex = coverColorHex
        self.coverUrl = coverUrl
        self.status = status
        self.category = category
        self.pages = pages
        self.currentPage = currentPage
        self.addTime = addTime
        self.publisher = publisher
        self.publishDate = publishDate
        self.isbn = isbn
    }
}

extension BookItem {
    static let mockData: [BookItem] = []
}
