import SwiftUI
import SwiftData

enum ScanDialogState {
    case none
    case loading
    case success(BookMetadata)
    case error(String)
    case manualEntry(isbn: String?)
}

struct ScanTabView: View {
    private let networkManager = NetworkManager()
    @State private var dialogState: ScanDialogState = .none
    
    // Scanner 重置触发器，用于让 ScannerView 重启扫码
    @State private var scannerResetTrigger = false
    @Environment(\.modelContext) private var context
    @Query(sort: \BookItem.addTime, order: .reverse) private var books: [BookItem]
    @State private var manualIsbn: String = ""
    @State private var selectedCategory: String = "未分类"
    private let bookCategories = ["未分类", "文学", "科幻", "传记", "科技", "设计", "心理学", "管理", "经济", "其他"]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.Theme.background.ignoresSafeArea()
                
                VStack(spacing: 16) {
                    // 1. 上半部分扫码区域
                    ScannerView(
                        onResult: { barcode in
                            handleBarcode(barcode)
                        },
                        onPermissionDenied: {
                            dialogState = .error("需要相机权限才能扫码，请在设置中开启。")
                        }
                    )
                    .id(scannerResetTrigger)
                    .frame(height: 260)
                    .cornerRadius(16)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.Theme.primary.opacity(0.5), lineWidth: 2)
                            .padding(.horizontal)
                            .padding(.top, 8)
                    )
                    
                    // 2. ISBN 快捷搜索区
                    HStack {
                        TextField("输入 ISBN (如 9787111128069)", text: $manualIsbn)
                            .padding(12)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(8)
                            .keyboardType(.numberPad)
                        
                        Button(action: {
                            guard !manualIsbn.isEmpty else { return }
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            handleBarcode(manualIsbn)
                        }) {
                            Text("搜索")
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color.Theme.primary)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                    
                    HStack {
                        Spacer()
                        Button(action: {
                            dialogState = .manualEntry(isbn: manualIsbn.isEmpty ? nil : manualIsbn)
                        }) {
                            Text("或手动填表录入完整信息")
                                .font(.footnote)
                                .foregroundColor(Color.Theme.primary)
                                .underline()
                        }
                    }
                    .padding(.horizontal)
                    
                    // 3. 最近录入历史
                    VStack(alignment: .leading, spacing: 8) {
                        Text("最近录入")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if books.isEmpty {
                            Spacer()
                            Text("暂无录入历史")
                                .foregroundColor(Color.Theme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                            Spacer()
                        } else {
                            List {
                                ForEach(books.prefix(10)) { book in
                                    NavigationLink(destination: BookDetailView(book: book)) {
                                        HStack {
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
                                                .frame(width: 40, height: 60)
                                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                            } else {
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(Color(hex: book.coverColorHex))
                                                    .frame(width: 40, height: 60)
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(book.title)
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                Text(book.author)
                                                    .font(.caption)
                                                    .foregroundColor(Color.Theme.textSecondary)
                                            }
                                            Spacer()
                                            Text("已入库")
                                                .font(.caption2)
                                                .foregroundColor(Color.Theme.primary)
                                        }
                                    }
                                }
                            }
                            .listStyle(PlainListStyle())
                        }
                    }
                }
                .navigationTitle("扫码入库")
                .navigationBarTitleDisplayMode(.inline)
                
                // 黑色半透明遮罩
                if case .none = dialogState {
                    // do nothing
                } else {
                    Color.black.opacity(0.6).ignoresSafeArea()
                        .onTapGesture {
                            if case .loading = dialogState { return }
                            resetScanner()
                        }
                }
                
                // 弹窗层
                switch dialogState {
                case .none:
                    EmptyView()
                    
                case .loading:
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(Color.Theme.primary)
                        Text("正在解析中...")
                            .foregroundColor(.white)
                            .padding(.top)
                    }
                    
                case .success(let metadata):
                    successDialog(metadata: metadata)
                    
                case .error(let msg):
                    errorDialog(message: msg)
                    
                case .manualEntry(let isbn):
                    ManualEntryFormView(isbn: isbn, context: context) {
                        resetScanner()
                    }
                }
            }
        }
    }
    
    // MARK: - Logic
    private func handleBarcode(_ barcode: String) {
        // 防止重复触发
        if case .none = dialogState {
            dialogState = .loading
            Task {
                do {
                    var metadata = try await networkManager.fetchBookInfo(isbn: barcode)
                    if metadata.isbn == nil || metadata.isbn!.isEmpty {
                        metadata.isbn = barcode
                    }
                    DispatchQueue.main.async {
                        dialogState = .success(metadata)
                    }
                } catch {
                    DispatchQueue.main.async {
                        // Include detailed raw error to help debugging why network fails
                        dialogState = .error("错误描述: \(error.localizedDescription)\n\n底层日志: \(String(describing: error))")
                    }
                }
            }
        }
    }
    
    private func resetScanner() {
        dialogState = .none
        scannerResetTrigger.toggle()
        selectedCategory = "未分类"
    }
    
    // MARK: - Dialogs
    private func successDialog(metadata: BookMetadata) -> some View {
        VStack(spacing: 16) {
            Text("扫码成功")
                .font(.headline)
            
            if let coverUrl = metadata.cover, let url = URL(string: coverUrl) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fit)
                    } else if phase.error != nil {
                        Color.gray // 出错时的占位
                    } else {
                        ProgressView()
                    }
                }
                .frame(height: 120)
                .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 120)
                    .cornerRadius(8)
                    .overlay(Text("无封面").foregroundColor(.gray))
            }
            
            Text(metadata.title)
                .font(.title3)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text(metadata.author)
                .font(.subheadline)
                .foregroundColor(Color.Theme.textSecondary)
            
            if let pub = metadata.publisher {
                Text(pub)
                    .font(.footnote)
                    .foregroundColor(Color.Theme.textSecondary)
            }
            
            HStack {
                Text("分类:")
                    .font(.subheadline)
                    .foregroundColor(Color.Theme.textSecondary)
                Spacer()
                Picker("分类", selection: $selectedCategory) {
                    ForEach(bookCategories, id: \.self) { cat in
                        Text(cat).tag(cat)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            .padding(.horizontal, 20)
            
            HStack(spacing: 20) {
                Button("取消") {
                    resetScanner()
                }
                .foregroundColor(Color.Theme.textSecondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                
                Button("加入书架") {
                    let newBook = BookItem(
                        id: UUID().uuidString,
                        title: metadata.title,
                        author: metadata.author,
                        coverColorHex: ["#D4B886", "#3A5C7A", "#A45548", "#111A24", "#5E7790"].randomElement()!,
                        coverUrl: metadata.cover,
                        status: .unread,
                        category: [selectedCategory],
                        pages: Int(metadata.pages ?? "0") ?? 0,
                        currentPage: 0,
                        addTime: Date(),
                        publisher: metadata.publisher ?? "未知出版社",
                        publishDate: metadata.pubdate ?? "",
                        isbn: metadata.isbn ?? ""
                    )
                    context.insert(newBook)
                    resetScanner()
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.Theme.primary)
                .cornerRadius(20)
            }
            .padding(.top, 10)
        }
        .padding(24)
        .background(Color.Theme.cardBackground)
        .cornerRadius(16)
        .shadow(radius: 10)
        .padding(30)
    }
    
    private func errorDialog(message: String) -> some View {
        VStack(spacing: 16) {
            Text("查询失败")
                .font(.headline)
            
            Text(message)
                .font(.body)
                .foregroundColor(Color.Theme.textSecondary)
                .multilineTextAlignment(.center)
            
            Text("网络请求异常或书籍不存在。如果是接口鉴权问题，请检查「偏好设置」中的 Token 是否正确，且无多余空格。")
                .font(.footnote)
                .foregroundColor(Color.Theme.textSecondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 20) {
                Button("取消") {
                    resetScanner()
                }
                .foregroundColor(Color.Theme.textSecondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                
                Button("手动录入") {
                    dialogState = .manualEntry(isbn: nil) // 真实业务可带入已扫出的isbn
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.Theme.primary)
                .cornerRadius(20)
            }
            .padding(.top, 10)
        }
        .padding(24)
        .background(Color.Theme.cardBackground)
        .cornerRadius(16)
        .shadow(radius: 10)
        .padding(30)
    }
}

// 独立的手动录入表单视图
struct ManualEntryFormView: View {
    var isbn: String?
    var context: ModelContext
    var onClose: () -> Void
    
    @State private var title: String = ""
    @State private var author: String = ""
    @State private var publisher: String = ""
    @State private var publishDate: String = ""
    @State private var inputIsbn: String = ""
    @State private var pages: String = ""
    @State private var summary: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("必填信息")) {
                    TextField("书名", text: $title)
                    TextField("作者", text: $author)
                }
                
                Section(header: Text("可选信息")) {
                    TextField("出版社", text: $publisher)
                    TextField("出版日期 (如 2023-01)", text: $publishDate)
                    TextField("ISBN", text: $inputIsbn)
                    TextField("页数", text: $pages)
                        .keyboardType(.numberPad)
                    TextEditor(text: $summary)
                        .frame(height: 80)
                        .overlay(
                            VStack {
                                if summary.isEmpty {
                                    HStack {
                                        Text("内容简介")
                                            .foregroundColor(Color(UIColor.placeholderText))
                                            .padding(.top, 8)
                                            .padding(.leading, 4)
                                        Spacer()
                                    }
                                }
                                Spacer()
                            }
                        )
                }
            }
            .navigationTitle("手动录入书籍")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        onClose()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        let newBook = BookItem(
                            id: UUID().uuidString,
                            title: title,
                            author: author,
                            coverColorHex: ["#D4B886", "#3A5C7A", "#A45548", "#111A24", "#5E7790"].randomElement()!,
                            status: .unread,
                            category: ["未分类"],
                            pages: Int(pages) ?? 0,
                            currentPage: 0,
                            addTime: Date(),
                            publisher: publisher.isEmpty ? "未知" : publisher,
                            publishDate: publishDate.isEmpty ? "未知" : publishDate,
                            isbn: inputIsbn
                        )
                        context.insert(newBook)
                        onClose()
                    }
                    .disabled(title.isEmpty || author.isEmpty)
                }
            }
        }
        .cornerRadius(16)
        .padding(16)
        .onAppear {
            if let isbn = isbn {
                inputIsbn = isbn
            }
        }
    }
}

#Preview {
    ScanTabView()
}
