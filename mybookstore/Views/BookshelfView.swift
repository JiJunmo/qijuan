import SwiftUI
import SwiftData

struct BookshelfView: View {
    @Query(sort: \BookItem.addTime, order: .reverse) var books: [BookItem]
    @State private var searchText: String = ""
    @State private var selectedFilter: FilterType = .all
    
    // 使用所有状态的枚举作为筛选器，加上“全部”
    enum FilterType: String, CaseIterable, Identifiable {
        case all = "全部"
        case reading = "在读"
        case unread = "未读"
        case finished = "已读"
        
        var id: String { self.rawValue }
    }
    
    // 两列网格布局，列间距 16
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var filteredBooks: [BookItem] {
        var result = books
        
        // 1. 状态过滤
        if selectedFilter != .all {
            result = result.filter { book in
                switch selectedFilter {
                case .all: return true
                case .reading: return book.status == .reading
                case .unread: return book.status == .unread
                case .finished: return book.status == .finished
                }
            }
        }
        
        // 2. 搜索框过滤
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.author.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return result
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.Theme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 动态筛选栏
                    filterBar
                    
                    // 瀑布流/列表展示区
                    ScrollView {
                        if filteredBooks.isEmpty {
                            VStack(spacing: 20) {
                                Spacer().frame(height: 120)
                                Image(systemName: "books.vertical")
                                    .font(.system(size: 64, weight: .light))
                                    .foregroundColor(Color.Theme.textSecondary.opacity(0.3))
                                Text("书架空空如也\n快去扫码录入你的第一本书吧")
                                    .font(.subheadline)
                                    .foregroundColor(Color.Theme.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(8)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(filteredBooks) { book in
                                    NavigationLink(destination: BookDetailView(book: book)) {
                                        BookCardView(book: book)
                                    }
                                    .buttonStyle(CardButtonStyle())
                                }
                            }
                            .padding(16)
                        }
                    }
                }
            }
            .navigationTitle("栖卷")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "搜索书名或作者")
        }
    }
    
    // 提取的筛选器组件
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(FilterType.allCases) { filter in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFilter = filter
                        }
                    }) {
                        Text(filter.rawValue)
                            .font(.system(size: 14, weight: selectedFilter == filter ? .semibold : .regular))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selectedFilter == filter ? Color.Theme.primary : Color.Theme.cardBackground)
                            )
                            .foregroundColor(selectedFilter == filter ? .white : Color.Theme.textSecondary)
                            .shadow(color: Color.black.opacity(selectedFilter == filter ? 0.1 : 0.02), radius: 4, x: 0, y: 2)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color.Theme.background)
    }
}

#Preview {
    BookshelfView()
}
