import SwiftUI

struct BookCardView: View {
    let book: BookItem
    
    var body: some View {
        VStack(spacing: 0) {
            // 封面区
            ZStack {
                if let coverUrl = book.coverUrl, let url = URL(string: coverUrl) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else if phase.error != nil {
                            Color(hex: book.coverColorHex)
                        } else {
                            Color.gray.opacity(0.3)
                        }
                    }
                    .frame(height: 140)
                    .clipShape(Rectangle())
                } else {
                    Color(hex: book.coverColorHex)
                    if let firstChar = book.title.first {
                        Text(String(firstChar))
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .frame(height: 140)
            .clipped()
            
            // 信息区
            VStack(alignment: .leading, spacing: 6) {
                Text(book.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.Theme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Text(book.author)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color.Theme.textSecondary)
                    .lineLimit(1)
                
                Spacer(minLength: 0)
                
                // 进度条与状态
                HStack(spacing: 4) {
                    Text(book.status.displayName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(statusColor(for: book.status))
                    
                    Spacer()
                    
                    if book.pages > 0 {
                        Text("\(Int(book.progress * 100))%")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color.Theme.textSecondary)
                    }
                }
                
                // 底部细条进度指示器
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.Theme.background)
                            .frame(height: 4)
                        
                        Capsule()
                            .fill(Color.Theme.primary)
                            .frame(width: geo.size.width * CGFloat(book.progress), height: 4)
                    }
                }
                .frame(height: 4)
                .padding(.top, 4)
            }
            .padding(12)
            .frame(height: 100)
        }
        .background(Color.Theme.cardBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
    
    private func statusColor(for status: BookStatus) -> Color {
        switch status {
        case .unread: return Color.gray
        case .reading: return Color.Theme.primary
        case .finished: return Color.blue
        }
    }
}

// 可点击的弹性按钮样式
struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

#Preview {
    let dummyBook = BookItem(id: "dummy", title: "测试书籍", author: "测试作者", coverColorHex: "#4E8975", status: .reading, category: ["测试"], pages: 100, currentPage: 50, addTime: Date(), publisher: "出版社", publishDate: "2023", isbn: "123")
    
    return ZStack {
        Color.Theme.background.ignoresSafeArea()
        HStack(spacing: 16) {
            BookCardView(book: dummyBook)
            BookCardView(book: dummyBook)
        }
        .padding(16)
    }
}
