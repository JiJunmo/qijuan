import SwiftUI
import SwiftData

struct BookDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.modelContext) private var context
    
    @Bindable var book: BookItem
    
    @State private var showDeleteAlert = false
    @State private var showCategoryPicker = false
    @State private var navigateToHistory = false
    
    // 静态词典，用于分类选择
    let bookCategories = ["文学", "科幻", "传记", "科技", "设计", "心理学", "管理", "经济", "其他"]
    
    var body: some View {
        ZStack(alignment: .top) {
            Color.Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // 1. 封面与核心操作
                    heroSection
                        .background(
                            Color(hex: book.coverColorHex)
                                .padding(.top, -1000)
                                .padding(.bottom, 24)
                        )
                    
                    // 2. 档案展陈区块
                    metaSection
                    
                    // 3. 内容简介卡
                    summarySection
                    
                    // 4. 伴生笔记卡
                    notesSection
                    
                    Spacer(minLength: 40)
                    
                    // 隐藏的导航链接，供右上角菜单触发
                    NavigationLink(destination: ReadingHistoryView(book: book), isActive: $navigateToHistory) {
                        EmptyView()
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        navigateToHistory = true
                    }) {
                        Label("阅读记录", systemImage: "clock.arrow.circlepath")
                    }
                    
                    Button(action: {
                        showCategoryPicker = true
                    }) {
                        Label("修改分类", systemImage: "tag")
                    }
                    
                    Button(role: .destructive, action: {
                        showDeleteAlert = true
                    }) {
                        Label("从书架删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
        }
        .alert("删除书籍", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                // 清理所有笔记文件
                for note in book.notes {
                    NoteFileManager.shared.deleteNoteContent(fileName: note.fileName)
                }
                context.delete(book)
                try? context.save()
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("确定要将《\(book.title)》从书架移除吗？相关笔记也会被一并删除。")
        }
        // 简易的系统 Picker 底部弹窗演示修改分类
        .confirmationDialog("选择新的分类", isPresented: $showCategoryPicker, titleVisibility: .visible) {
            ForEach(bookCategories, id: \.self) { cat in
                Button(cat) {
                    book.category = [cat] 
                    try? context.save()
                }
            }
            Button("取消", role: .cancel) { }
        }
    }
    
    // MARK: - 1. 封面枢纽
    private var heroSection: some View {
        VStack(spacing: 20) {
            Group {
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
                    .frame(width: 140, height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: book.coverColorHex).opacity(0.8))
                        .frame(width: 140, height: 190)
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                        .overlay(
                            Text(book.title.prefix(1))
                                .font(.system(size: 60, weight: .bold))
                                .foregroundColor(.white.opacity(0.5))
                        )
                }
            }
            .padding(.top, 40)
            
            VStack(spacing: 8) {
                Text(book.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(book.author)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            // 状态机切换器 (Status Chips)
            HStack(spacing: 16) {
                StatusChip(title: "未读", isActive: book.status == .unread, color: Color(hex: "#8C9D96")) {
                    book.status = .unread
                    try? context.save()
                }
                StatusChip(title: "在读", isActive: book.status == .reading, color: Color(hex: "#D99B26")) {
                    book.status = .reading
                    try? context.save()
                }
                StatusChip(title: "已读", isActive: book.status == .finished, color: Color.Theme.primary) {
                    book.status = .finished
                    try? context.save()
                }
            }
            .padding(.top, 8)
            
            // 沉浸式阅读按钮
            NavigationLink(destination: ImmersiveReadingView(book: book)) {
                Text("进入沉浸式阅读")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.Theme.primary)
                    .cornerRadius(12)
                    .padding(.horizontal, 24)
                    .shadow(color: Color.Theme.primary.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding(.top, 10)
        }
    }
    
    // MARK: - 2. 档案卡片
    private var metaSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("档案与信息")
                .font(.headline)
                .foregroundColor(Color.Theme.textPrimary)
            
            VStack(spacing: 12) {
                MetaItem(label: "阅读进度", value: "\(book.currentPage) / \(book.pages) 页")
                MetaItem(label: "图书分类", value: book.category.joined(separator: ", "))
                MetaItem(label: "出版社", value: book.publisher)
                MetaItem(label: "出版日期", value: book.publishDate)
                MetaItem(label: "ISBN 编码", value: book.isbn)
                MetaItem(label: "入库时间", value: formatDate(book.addTime))
            }
            .padding()
            .background(Color.Theme.cardBackground)
            .cornerRadius(12)
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - 3. 简介卡片
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("内容简介")
                .font(.headline)
                .foregroundColor(Color.Theme.textPrimary)
            
            Text("这是一段模拟的书籍大段简介内容。该书由 \(book.author) 编写，主要分类在 \(book.category.first ?? "未知") 领域，总共有 \(book.pages) 页。\n\n应用通过设定 lineHeight 等参数，确保长文本具备极佳的阅读体验。这部分数据通常会在扫码入库时由远端 API (如 Google Books API 或豆瓣 API) 返回并存入本地。")
                .font(.body)
                .foregroundColor(Color.Theme.textSecondary)
                .lineSpacing(6)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.Theme.cardBackground)
                .cornerRadius(12)
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - 4. 伴生笔记卡
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("伴生笔记")
                    .font(.headline)
                    .foregroundColor(Color.Theme.textPrimary)
                
                Spacer()
                
                Button(action: {
                    let newFileName = "note_\(UUID().uuidString).txt"
                    let newNote = NoteItem(id: UUID().uuidString, bookId: book.id, title: "新建笔记", fileName: newFileName, updateTime: Date())
                    newNote.book = book
                    book.notes.append(newNote)
                    context.insert(newNote)
                    try? context.save()
                }) {
                    Text("+ 新建笔记")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.Theme.primary.opacity(0.1))
                        .foregroundColor(Color.Theme.primary)
                        .cornerRadius(8)
                }
            }
            
            if book.notes.isEmpty {
                Text("暂无笔记，点击右上角新建。")
                    .font(.subheadline)
                    .foregroundColor(Color.Theme.textSecondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.Theme.cardBackground)
                    .cornerRadius(12)
            } else {
                ForEach(book.notes.sorted(by: { $0.updateTime > $1.updateTime })) { note in
                    NavigationLink(destination: NoteEditorView(note: note)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(note.title)
                                    .font(.subheadline)
                                    .foregroundColor(Color.Theme.textPrimary)
                                    .lineLimit(1)
                                
                                Text(formatDate(note.updateTime))
                                    .font(.caption2)
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
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// 状态药丸组件
struct StatusChip: View {
    let title: String
    let isActive: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isActive ? .bold : .medium))
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(isActive ? color : Color.Theme.cardBackground)
                .foregroundColor(isActive ? .white : Color.Theme.textSecondary)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(isActive ? 0 : 0.05), radius: 3, x: 0, y: 2)
                .animation(.easeInOut(duration: 0.2), value: isActive)
        }
    }
}

// 左灰右黑键值对
struct MetaItem: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(Color.Theme.textSecondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(Color.Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
