import SwiftUI
import SwiftData

enum CalendarViewMode {
    case calendar
    case timeline
}

struct CalendarTabView: View {
    @State private var currentDate = Date()
    @State private var selectedDate: Date? = nil
    @State private var showDetailSheet = false
    @State private var viewMode: CalendarViewMode = .calendar
    @State private var heatmapData: [String: Int] = [:]
    
    @Query private var sessions: [ReadingSession]
    @Query private var books: [BookItem]
    
    // 数据源聚合
    let calendar = Calendar.current
    
    // 月份格式化
    var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年 MM月"
        return formatter.string(from: currentDate)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.Theme.background.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // 1. 月份切换头部
                    HStack {
                        Button(action: previousMonth) {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.title2)
                                .foregroundColor(Color.Theme.primary)
                        }
                        
                        Spacer()
                        
                        Text(monthYearString)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(Color.Theme.textPrimary)
                        
                        Spacer()
                        
                        Button(action: nextMonth) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.title2)
                                .foregroundColor(Color.Theme.primary)
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
                    
                    // 2. 视图切换器
                    Picker("视图", selection: $viewMode) {
                        Text("日历").tag(CalendarViewMode.calendar)
                        Text("时间轴").tag(CalendarViewMode.timeline)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, 40)
                    
                    // 3. 内容区
                    if viewMode == .calendar {
                        calendarGridView
                    } else {
                        TimelineViewComponent(currentDate: currentDate)
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("日历")
            .navigationBarHidden(true)
            .sheet(isPresented: $showDetailSheet) {
                if let date = selectedDate {
                    DailyDetailSheet(date: date)
                }
            }
            .onAppear {
                if heatmapData.isEmpty {
                    heatmapData = generateHeatmapData()
                }
            }
        }
    }
    
    // MARK: - 日历视图组件
    
    private var calendarGridView: some View {
        VStack(spacing: 24) {
            let weekdays = ["日", "一", "二", "三", "四", "五", "六"]
            HStack {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(Color.Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)
            
            let days = generateDaysInMonth(for: currentDate)
            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
            
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(days, id: \.self) { date in
                    if let date = date {
                        let dateString = formatDateKey(date)
                        let minutes = heatmapData[dateString] ?? 0
                        
                        HeatmapCell(date: date, minutes: minutes)
                            .onTapGesture {
                                if minutes > 0 {
                                    selectedDate = date
                                    showDetailSheet = true
                                }
                            }
                    } else {
                        Color.clear
                            .aspectRatio(1, contentMode: .fill)
                    }
                }
            }
            .padding(.horizontal, 20)
            
            HStack(spacing: 6) {
                Text("少")
                    .font(.caption2)
                    .foregroundColor(.gray)
                HeatmapCell(date: Date(), minutes: 0, isLegend: true).frame(width: 12)
                HeatmapCell(date: Date(), minutes: 15, isLegend: true).frame(width: 12)
                HeatmapCell(date: Date(), minutes: 45, isLegend: true).frame(width: 12)
                HeatmapCell(date: Date(), minutes: 90, isLegend: true).frame(width: 12)
                HeatmapCell(date: Date(), minutes: 150, isLegend: true).frame(width: 12)
                Text("多")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .padding(.top, 10)
        }
    }
    
    // MARK: - 逻辑与数据生成
    
    private func previousMonth() {
        if let newDate = calendar.date(byAdding: .month, value: -1, to: currentDate) {
            currentDate = newDate
        }
    }
    
    private func nextMonth() {
        if let newDate = calendar.date(byAdding: .month, value: 1, to: currentDate) {
            currentDate = newDate
        }
    }
    
    private func generateHeatmapData() -> [String: Int] {
        var data: [String: Int] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        for session in sessions {
            let date = Date(timeIntervalSince1970: session.startTime)
            let key = formatter.string(from: date)
            let minutes = Int(session.duration / 60)
            data[key, default: 0] += minutes
        }
        
        return data
    }
    
    private func formatDateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func generateDaysInMonth(for date: Date) -> [Date?] {
        var days: [Date?] = []
        guard let monthInterval = calendar.dateInterval(of: .month, for: date),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }
        let firstDayWeekday = calendar.component(.weekday, from: monthInterval.start) - 1
        for _ in 0..<firstDayWeekday { days.append(nil) }
        guard let range = calendar.range(of: .day, in: .month, for: date) else { return [] }
        for day in 1...range.count {
            if let d = calendar.date(bySetting: .day, value: day, of: date) { days.append(d) }
        }
        return days
    }
}

// MARK: - 时间轴 (甘特图) 视图组件

struct DayRange {
    let startDay: Int
    let endDay: Int
}
struct DayNote {
    let day: Int
    let note: NoteItem
}

struct TimelineViewComponent: View {
    let currentDate: Date
    @Query private var sessions: [ReadingSession]
    @Query private var books: [BookItem]
    @Query private var notes: [NoteItem]
    let rowHeight: CGFloat = 32
    // 使用一组不同的颜色来保证相邻列颜色互斥
    let palette: [Color] = [
        Color(hex: "#4E8975"), // Primary green
        Color(hex: "#3A5C7A"), // Blueish
        Color(hex: "#D4B886"), // Warm gold
        Color(hex: "#8E6B8E"), // Purple
        Color(hex: "#E07A5F")  // Coral red
    ]
    
    var body: some View {
        let (books, rangesData, notesData) = generateTimelineData()
        let daysCount = daysInMonth()
        
        if books.isEmpty {
            VStack {
                Spacer()
                Text("本月暂无阅读记录")
                    .foregroundColor(.gray)
                Spacer()
            }
        } else {
            GeometryReader { geometry in
                // 根据屏幕宽度动态计算书籍列宽。如果书很少，就占满屏幕；如果书多，就触发水平滑动。
                let availableWidth = geometry.size.width - 40 // 左侧日期列占 40
                let colWidth = max(80, availableWidth / CGFloat(max(1, books.count)))
                
                // 外层水平滚动 (供书籍列过多时滑动)
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        
                        // X轴表头：书籍列表 (冻结在顶部)
                        HStack(alignment: .bottom, spacing: 0) {
                            // 左侧留空，与下方的 Y轴刻度对齐
                            Spacer().frame(width: 40)
                            
                            ForEach(books) { book in
                                VStack(spacing: 6) {
                                    // 模拟书籍封面
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(hex: book.coverColorHex))
                                        .aspectRatio(0.7, contentMode: .fit)
                                        .frame(height: 40)
                                        .shadow(color: .black.opacity(0.1), radius: 2, x: 1, y: 1)
                                    
                                    Text(book.title)
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .foregroundColor(Color.Theme.textPrimary)
                                        .lineLimit(1)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(width: colWidth, height: 70, alignment: .bottom)
                                .padding(.bottom, 8)
                            }
                        }
                        .zIndex(1)
                        .background(Color.Theme.background)
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 2)
                        
                        // 内层垂直滚动 (滑动日期)
                        ScrollView(.vertical, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 0) {
                            
                            // Y轴表头：日期刻度 1...N
                            VStack(spacing: 0) {
                                ForEach(1...daysCount, id: \.self) { day in
                                    Text("\(day)")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                        .frame(width: 40, height: rowHeight, alignment: .center)
                                }
                            }
                            
                            // 数据列
                            ForEach(Array(books.enumerated()), id: \.element.id) { index, book in
                                ZStack(alignment: .top) {
                                    // 极细网格底纹：底部水平线 + 右侧垂直线
                                    ZStack {
                                        // 右侧垂直分割线
                                        HStack(spacing: 0) {
                                            Spacer()
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.2))
                                                .frame(width: 0.5)
                                        }
                                        
                                        // 水平分割线
                                        VStack(spacing: 0) {
                                            ForEach(1...daysCount, id: \.self) { _ in
                                                VStack(spacing: 0) {
                                                    Spacer()
                                                    Rectangle()
                                                        .fill(Color.gray.opacity(0.2))
                                                        .frame(height: 0.5)
                                                }
                                                .frame(width: colWidth, height: rowHeight)
                                            }
                                        }
                                    }
                                    
                                    // 垂直连贯色带
                                    if let ranges = rangesData[book.id] {
                                        ForEach(ranges, id: \.startDay) { range in
                                            TimelineCapsule(
                                                range: range,
                                                color: palette[index % palette.count],
                                                colWidth: colWidth,
                                                rowHeight: rowHeight
                                            )
                                        }
                                    }
                                    
                                    // 笔记锚点
                                    if let notes = notesData[book.id] {
                                        ForEach(notes, id: \.day) { noteData in
                                            TimelineNoteIcon(
                                                noteData: noteData,
                                                color: palette[index % palette.count],
                                                rowHeight: rowHeight
                                            )
                                        }
                                    }
                                }
                                .frame(width: colWidth, height: CGFloat(daysCount) * rowHeight, alignment: .top)
                            }
                            }
                        }
                    }
                }
            } // Close GeometryReader
            .padding(.top, 10)
        }
    }
    
    // 生成聚合后的甘特图数据
    private func generateTimelineData() -> ([BookItem], [String: [DayRange]], [String: [DayNote]]) {
        let calendar = Calendar.current
        var bookIds: Set<String> = []
        var rawDays: [String: Set<Int>] = [:]
        
        // 找出当月的 ReadingSession
        for session in sessions {
            let date = Date(timeIntervalSince1970: session.startTime)
            if calendar.isDate(date, equalTo: currentDate, toGranularity: .month) {
                let day = calendar.component(.day, from: date)
                bookIds.insert(session.bookId)
                if rawDays[session.bookId] == nil { rawDays[session.bookId] = [] }
                rawDays[session.bookId]?.insert(day)
            }
        }
        
        var rangesData: [String: [DayRange]] = [:]
        for (bookId, daysSet) in rawDays {
            let sortedDays = Array(daysSet).sorted()
            var ranges: [DayRange] = []
            var currentStart = -1
            var currentEnd = -1
            
            for day in sortedDays {
                if currentStart == -1 {
                    currentStart = day
                    currentEnd = day
                } else if day == currentEnd + 1 {
                    currentEnd = day
                } else {
                    ranges.append(DayRange(startDay: currentStart, endDay: currentEnd))
                    currentStart = day
                    currentEnd = day
                }
            }
            if currentStart != -1 {
                ranges.append(DayRange(startDay: currentStart, endDay: currentEnd))
            }
            rangesData[bookId] = ranges
        }
        
        let booksList = books.filter { bookIds.contains($0.id) }
        
        var notesData: [String: [DayNote]] = [:]
        for note in notes {
            if calendar.isDate(note.updateTime, equalTo: currentDate, toGranularity: .month) {
                let day = calendar.component(.day, from: note.updateTime)
                if notesData[note.bookId] == nil { notesData[note.bookId] = [] }
                notesData[note.bookId]?.append(DayNote(day: day, note: note))
            }
        }
        
        return (booksList, rangesData, notesData)
    }
    
    private func daysInMonth() -> Int {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: currentDate) else { return 30 }
        return range.count
    }
}

// MARK: - 基础组件复用

struct HeatmapCell: View {
    let date: Date
    let minutes: Int
    var isLegend: Bool = false
    
    private var colorLevel: Color {
        if minutes == 0 { return Color.gray.opacity(0.15) }
        else if minutes < 30 { return Color.Theme.primary.opacity(0.3) }
        else if minutes < 60 { return Color.Theme.primary.opacity(0.5) }
        else if minutes < 120 { return Color.Theme.primary.opacity(0.8) }
        else { return Color.Theme.primary }
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: isLegend ? 2 : 4)
                .fill(colorLevel)
                .aspectRatio(1, contentMode: .fit)
            
            if !isLegend && minutes > 0 {
                let dayStr = Calendar.current.component(.day, from: date)
                Text("\(dayStr)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
            } else if !isLegend {
                let dayStr = Calendar.current.component(.day, from: date)
                Text("\(dayStr)")
                    .font(.system(size: 10))
                    .foregroundColor(.gray.opacity(0.4))
            }
        }
    }
}

struct DailyDetailSheet: View {
    @Environment(\.presentationMode) var presentationMode
    let date: Date
    
    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        return formatter.string(from: date)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        bookTimeDistribution
                        dailyNotesList
                    }
                    .padding(.top, 24)
                }
            }
            .navigationTitle(dateString)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
    
    private var bookTimeDistribution: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("时间分配")
                .font(.headline)
                .foregroundColor(Color.Theme.textPrimary)
                .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    Color(hex: "#D4B886").frame(width: 150)
                    Color(hex: "#3A5C7A").frame(width: 80)
                    Color(hex: "#111A24").frame(maxWidth: .infinity)
                }
                .frame(height: 24)
                .cornerRadius(12)
                
                HStack {
                    legendItem(color: Color(hex: "#D4B886"), title: "百年孤独", duration: "60m")
                    legendItem(color: Color(hex: "#3A5C7A"), title: "硅谷钢铁侠", duration: "32m")
                    legendItem(color: Color(hex: "#111A24"), title: "三体", duration: "45m")
                }
            }
            .padding(20)
            .background(Color.Theme.cardBackground)
            .cornerRadius(16)
            .padding(.horizontal, 20)
        }
    }
    
    private func legendItem(color: Color, title: String, duration: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption2).foregroundColor(Color.Theme.textPrimary).lineLimit(1)
                Text(duration).font(.caption2).foregroundColor(Color.Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var dailyNotesList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("思维痕迹")
                .font(.headline)
                .foregroundColor(Color.Theme.textPrimary)
                .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("第一章笔记与摘抄")
                            .font(.subheadline)
                            .foregroundColor(Color.Theme.textPrimary)
                            .fontWeight(.medium)
                        Text("所属书籍: 《百年孤独》")
                            .font(.caption)
                            .foregroundColor(Color.Theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray.opacity(0.5))
                        .font(.system(size: 14))
                }
                .padding()
                .background(Color.Theme.cardBackground)
                .cornerRadius(12)
            }
            .padding(.horizontal, 20)
        }
    }
}

// 提取的子视图，避免编译器 Type-Check 超时
struct TimelineCapsule: View {
    let range: DayRange
    let color: Color
    let colWidth: CGFloat
    let rowHeight: CGFloat
    
    var body: some View {
        let span = CGFloat(range.endDay - range.startDay + 1)
        let rectHeight = span * rowHeight - 4
        let offsetY = CGFloat(range.startDay - 1) * rowHeight + 2
        
        Capsule()
            .fill(color)
            .frame(width: 24, height: rectHeight) // 固定一个优雅的宽度，不要随列宽膨胀
            .offset(y: offsetY)
    }
}

struct TimelineNoteIcon: View {
    let noteData: DayNote
    let color: Color
    let rowHeight: CGFloat
    
    var body: some View {
        let offsetY = CGFloat(noteData.day - 1) * rowHeight + (rowHeight - 20) / 2
        
        NavigationLink(destination: NoteEditorView(note: noteData.note)) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 10))
                .foregroundColor(color)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.white).shadow(radius: 1))
        }
        .offset(y: offsetY)
    }
}

#Preview {
    CalendarTabView()
}
