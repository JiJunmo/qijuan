import Foundation
import SwiftUI
import Combine

struct CategoryStat: Identifiable {
    let id = UUID()
    let name: String
    let count: Int
    let color: Color
}

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Int
}

class ProfileViewModel: ObservableObject {
    @Published var totalReadingMinutes: Int = 0
    @Published var totalBooks: Int = 0
    @Published var totalNotes: Int = 0
    
    @Published var readingCount: Int = 0
    @Published var readCount: Int = 0
    @Published var unreadCount: Int = 0
    
    @Published var topCategories: [CategoryStat] = []
    
    @Published var yearTrendData: [ChartDataPoint] = []
    @Published var allTrendData: [ChartDataPoint] = []
    
    func calculateStats(books: [BookItem], sessions: [ReadingSession], notes: [NoteItem]) {
        
        // 1. 顶部总览
        let totalDurationSeconds = sessions.reduce(0) { $0 + $1.duration }
        totalReadingMinutes = Int(totalDurationSeconds / 60)
        totalBooks = books.count
        totalNotes = notes.count
        
        // 2. 阅读状态分布
        readingCount = books.filter { $0.status == .reading }.count
        readCount = books.filter { $0.status == .finished }.count
        unreadCount = books.filter { $0.status == .unread }.count
        
        // 3. 分类排行榜
        var categoryMap: [String: Int] = [:]
        for book in books {
            if book.category.isEmpty {
                categoryMap["未分类", default: 0] += 1
            } else {
                for cat in book.category {
                    categoryMap[cat, default: 0] += 1
                }
            }
        }
        
        let sortedCats = categoryMap.sorted { $0.value > $1.value }
        let colors: [Color] = [.blue, .purple, .orange, .pink, .gray]
        var topCats: [CategoryStat] = []
        var othersCount = 0
        
        for (index, item) in sortedCats.enumerated() {
            if index < 4 {
                topCats.append(CategoryStat(name: item.key, count: item.value, color: colors[index % colors.count]))
            } else {
                othersCount += item.value
            }
        }
        if othersCount > 0 {
            topCats.append(CategoryStat(name: "其他", count: othersCount, color: .gray))
        }
        self.topCategories = topCats
        
        // 4. 折线图数据 (按月/按年)
        calculateTrendData(books: books)
    }
    
    private func calculateTrendData(books: [BookItem]) {
        let calendar = Calendar.current
        let now = Date()
        
        // --- 近一年数据 (按月) ---
        var yearData: [ChartDataPoint] = []
        for i in (0..<12).reversed() {
            guard let monthDate = calendar.date(byAdding: .month, value: -i, to: now) else { continue }
            let month = calendar.component(.month, from: monthDate)
            let year = calendar.component(.year, from: monthDate)
            
            let count = books.filter {
                let m = calendar.component(.month, from: $0.addTime)
                let y = calendar.component(.year, from: $0.addTime)
                return m == month && y == year
            }.count
            yearData.append(ChartDataPoint(label: "\(month)月", value: count))
        }
        self.yearTrendData = yearData
        
        // --- 全部数据 (按年累计) ---
        var allData: [ChartDataPoint] = []
        var runningTotal = 0
        let currentYear = calendar.component(.year, from: now)
        
        // 计算 5 年前的总量 (更早)
        let olderBooks = books.filter { calendar.component(.year, from: $0.addTime) < currentYear - 4 }
        runningTotal += olderBooks.count
        allData.append(ChartDataPoint(label: "更早", value: runningTotal))
        
        for i in (0..<5).reversed() {
            let targetYear = currentYear - i
            let count = books.filter { calendar.component(.year, from: $0.addTime) == targetYear }.count
            runningTotal += count
            allData.append(ChartDataPoint(label: String(targetYear), value: runningTotal))
        }
        self.allTrendData = allData
    }
}
