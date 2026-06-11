import SwiftUI
import SwiftData

struct ReadingHistoryView: View {
    @Environment(\.modelContext) private var context
    let book: BookItem
    
    @State private var showManualRecordSheet = false
    
    var body: some View {
        ZStack {
            Color.Theme.background.ignoresSafeArea()
            
            if book.sessions.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 60))
                        .foregroundColor(Color.Theme.textSecondary.opacity(0.5))
                    
                    Text("暂无阅读记录")
                        .font(.title3)
                        .foregroundColor(Color.Theme.textSecondary)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(book.sessions.sorted(by: { $0.startTime > $1.startTime })) { session in
                            SessionCard(session: session)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("阅读记录")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showManualRecordSheet = true
                }) {
                    Image(systemName: "plus.circle")
                        .foregroundColor(Color.Theme.primary)
                }
            }
        }
        .sheet(isPresented: $showManualRecordSheet) {
            ManualRecordSheet(book: book)
        }
    }
}

struct SessionCard: View {
    let session: ReadingSession
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(formatDate(session.startTime))
                    .font(.headline)
                    .foregroundColor(Color.Theme.textPrimary)
                
                Text(formatTime(session.startTime))
                    .font(.caption)
                    .foregroundColor(Color.Theme.textSecondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(session.duration / 60))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color.Theme.primary)
                
                Text("分钟")
                    .font(.caption)
                    .foregroundColor(Color.Theme.textSecondary)
            }
        }
        .padding(16)
        .background(Color.Theme.cardBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func formatDate(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        return formatter.string(from: date)
    }
    
    private func formatTime(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct ManualRecordSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.presentationMode) var presentationMode
    
    let book: BookItem
    
    @State private var selectedDate = Date()
    @State private var durationString = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("阅读时间")) {
                    DatePicker("开始时间", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section(header: Text("阅读时长 (分钟)")) {
                    TextField("例如: 45", text: $durationString)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("补录记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveRecord()
                    }
                    .disabled(durationString.isEmpty || Int(durationString) == nil)
                }
            }
        }
    }
    
    private func saveRecord() {
        guard let durationMinutes = Int(durationString) else { return }
        let durationSeconds = TimeInterval(durationMinutes * 60)
        
        let newSession = ReadingSession(
            id: UUID().uuidString,
            bookId: book.id,
            startTime: selectedDate.timeIntervalSince1970,
            duration: durationSeconds
        )
        
        // 双向绑定关联
        newSession.book = book
        book.sessions.append(newSession)
        
        // 由于是从 context 获取的 book，直接保存即可
        try? context.save()
        
        presentationMode.wrappedValue.dismiss()
    }
}
