import Foundation
import SwiftData

/// 阅读流水实体
@Model
final class ReadingSession: Identifiable {
    @Attribute(.unique) var id: String
    var bookId: String
    var startTime: TimeInterval
    var duration: TimeInterval // 单位：秒
    
    var book: BookItem?
    
    init(id: String = UUID().uuidString, bookId: String, startTime: TimeInterval, duration: TimeInterval) {
        self.id = id
        self.bookId = bookId
        self.startTime = startTime
        self.duration = duration
    }
}

extension ReadingSession {
    static let mockSessions: [ReadingSession] = []
}

/// 笔记元数据实体
@Model
final class NoteItem: Identifiable {
    @Attribute(.unique) var id: String
    var bookId: String
    var title: String
    var fileName: String // 指向沙盒里真实存在的文件名
    var updateTime: Date
    
    var book: BookItem?
    
    init(id: String = UUID().uuidString, bookId: String, title: String, fileName: String, updateTime: Date = Date()) {
        self.id = id
        self.bookId = bookId
        self.title = title
        self.fileName = fileName
        self.updateTime = updateTime
    }
}

extension NoteItem {
    static let mockNotes: [NoteItem] = []
}


