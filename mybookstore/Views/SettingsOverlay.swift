import SwiftUI
import SwiftData

// 文档导出包装器
struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .plainText] }
    var text: String
    
    init(text: String) {
        self.text = text
    }
    
    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
           let string = String(data: data, encoding: .utf8) {
            text = string
        } else {
            text = ""
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8)!
        return .init(regularFileWithContents: data)
    }
}
import UniformTypeIdentifiers

struct SettingsOverlay: View {
    @Environment(\.presentationMode) var presentationMode
    @AppStorage("customApiUrl") private var customApiUrl: String = "https://jixiaokui.icu/api/book"
    @AppStorage("customApiToken") private var apiToken: String = ""
    
    @State private var showExportDialog = false
    @State private var jsonDocument = JSONDocument(text: "")
    @State private var showAbout = false
    @State private var isTokenVisible = false
    
    let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "未知设备ID"
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("邀请码")) {
                    HStack {
                        if isTokenVisible {
                            TextField("输入邀请码", text: $apiToken)
                        } else {
                            SecureField("输入邀请码", text: $apiToken)
                        }
                        
                        Button(action: {
                            isTokenVisible.toggle()
                        }) {
                            Image(systemName: isTokenVisible ? "eye.slash" : "eye")
                                .foregroundColor(.gray)
                        }
                    }
                    Text("该邀请码将用于解锁线上书籍库的检索权限。")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Section(header: Text("数据管理")) {
                    Button("导出纯本地书籍数据 (备份)") {
                        prepareExport()
                    }
                    .foregroundColor(Color.Theme.primary)
                }
                
                Section(header: Text("设备与关于")) {
                    HStack {
                        Text("设备 ID")
                        Spacer()
                        Text(String(deviceId.prefix(8)) + "...")
                            .foregroundColor(.gray)
                        Button(action: {
                            UIPasteboard.general.string = deviceId
                        }) {
                            Image(systemName: "doc.on.doc")
                        }
                    }
                    
                    Button("关于我们") {
                        showAbout = true
                    }
                }
            }
            .navigationTitle("偏好设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            // 导出文件选择器
            .fileExporter(
                isPresented: $showExportDialog,
                document: jsonDocument,
                contentType: .plainText,
                defaultFilename: "栖卷_backup.txt"
            ) { result in
                switch result {
                case .success(let url):
                    print("已导出至: \(url)")
                case .failure(let error):
                    print("导出失败: \(error)")
                }
            }
            .sheet(isPresented: $showAbout) {
                AboutOverlay()
            }
        }
    }
    
    @Query private var books: [BookItem]
    
    private func prepareExport() {
        struct ExportBookDTO: Codable {
            let id: String
            let title: String
            let author: String
            let status: String
            let category: [String]
            let pages: Int
            let currentPage: Int
            let isbn: String
        }
        
        let exportData = books.map { book in
            ExportBookDTO(
                id: book.id,
                title: book.title,
                author: book.author,
                status: book.status.rawValue,
                category: book.category,
                pages: book.pages,
                currentPage: book.currentPage,
                isbn: book.isbn
            )
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(exportData),
           let string = String(data: data, encoding: .utf8) {
            jsonDocument = JSONDocument(text: string)
            showExportDialog = true
        }
    }
}

struct AboutOverlay: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 20) {
            Text("栖卷 (MyBookStore)")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("致力于为您打造沉浸式的本地化阅读记录体验。")
                .multilineTextAlignment(.center)
                .padding()
            
            Spacer()
            
            Button("关闭") {
                presentationMode.wrappedValue.dismiss()
            }
            .padding()
        }
        .padding(.top, 40)
    }
}
