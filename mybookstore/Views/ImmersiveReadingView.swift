import SwiftUI
import Combine
import SwiftData

struct ImmersiveReadingView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.modelContext) private var context
    @Bindable var book: BookItem
    
    @State private var elapsedSeconds: Int = 0
    @State private var isTimerRunning: Bool = true
    @State private var showStopDialog: Bool = false
    @State private var endPageInput: String = ""
    
    // 每秒触发一次的计时器
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // 背景层：全屏的书籍提取主题色
            Color(hex: book.coverColorHex)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // 顶部信息
                VStack(spacing: 8) {
                    Text("正在专注阅读")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("《\(book.title)》")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // 巨大的数字表盘
                Text(timeString(from: elapsedSeconds))
                    .font(.system(size: 80, weight: .thin, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 20)
                
                Spacer()
                
                // 结束按钮
                Button(action: {
                    isTimerRunning = false
                    endPageInput = "\(book.currentPage)"
                    withAnimation {
                        showStopDialog = true
                    }
                }) {
                    Text("结束本次阅读")
                        .font(.headline)
                        .foregroundColor(Color(hex: book.coverColorHex))
                        .padding(.vertical, 16)
                        .padding(.horizontal, 40)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                }
                .padding(.bottom, 60)
            }
            
            // 结算拦截面板 (Overlay)
            if showStopDialog {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .transition(.opacity)
                
                VStack(spacing: 24) {
                    Text("阅读结算")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    VStack(spacing: 8) {
                        Text("本次专注时长")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Text(timeString(from: elapsedSeconds))
                            .font(.largeTitle)
                            .fontWeight(.medium)
                            .foregroundColor(Color.Theme.primary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("读到了哪一页？(共 \(book.pages) 页)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        TextField("例如: 120", text: $endPageInput)
                            .keyboardType(.numberPad)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                    }
                    
                    HStack(spacing: 16) {
                        Button("继续阅读") {
                            withAnimation {
                                showStopDialog = false
                                isTimerRunning = true
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.1))
                        .foregroundColor(.gray)
                        .cornerRadius(10)
                        
                        Button("确认并保存") {
                            saveSessionAndExit()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.Theme.primary)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding(.top, 8)
                }
                .padding(24)
                .background(Color.white)
                .cornerRadius(20)
                .shadow(radius: 20)
                .padding(30)
                .transition(.scale.combined(with: .opacity))
            }
        }
        // 剥离原生 Navigation 行为
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar) // iOS 16+
        .onReceive(timer) { _ in
            if isTimerRunning {
                elapsedSeconds += 1
            }
        }
        .onAppear {
            // 强制屏幕常亮
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            // 恢复屏幕休眠策略
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
    
    // MARK: - 逻辑辅助
    
    private func timeString(from seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        
        if h > 0 {
            return String(format: "%02d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }
    
    private func saveSessionAndExit() {
        // 更新书籍当前进度
        if let newPage = Int(endPageInput), newPage >= 0, newPage <= book.pages {
            book.currentPage = newPage
        } else if let newPage = Int(endPageInput), newPage > book.pages {
            book.currentPage = book.pages // 防越界
        }
        
        let session = ReadingSession(
            id: UUID().uuidString,
            bookId: book.id,
            startTime: Date().timeIntervalSince1970 - Double(elapsedSeconds),
            duration: TimeInterval(elapsedSeconds)
        )
        session.book = book
        book.sessions.append(session)
        context.insert(session)
        try? context.save()
        print("已记录阅读流水: 耗时 \(elapsedSeconds) 秒，停在 \(book.currentPage) 页。")
        
        // 退出沉浸模式
        presentationMode.wrappedValue.dismiss()
    }
}

#Preview {
    let dummyBook = BookItem(id: "dummy", title: "测试书籍", author: "测试作者", coverColorHex: "#4E8975", status: .reading, category: ["测试"], pages: 100, currentPage: 50, addTime: Date(), publisher: "出版社", publishDate: "2023", isbn: "123")
    return ImmersiveReadingView(book: dummyBook)
}
