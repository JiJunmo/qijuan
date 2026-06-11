import SwiftUI

struct MarkdownDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
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

struct NoteEditorView: View {
    @Environment(\.presentationMode) var presentationMode
    
    let note: NoteItem
    
    @State private var attributedText: NSAttributedString = NSAttributedString(string: "")
    @State private var textView: UITextView? = nil
    
    @State private var showExportDialog = false
    @State private var mdDocument = MarkdownDocument(text: "")
    @State private var showToast = false
    @State private var toastMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // 富文本编辑区
            RichTextEditor(text: $attributedText, internalTextView: $textView)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.Theme.background)
        }
        .navigationTitle(note.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // 右上角动作栏
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: saveNoteLocally) {
                        Label("保存笔记", systemImage: "externaldrive.fill")
                    }
                    
                    Button(action: exportToMarkdown) {
                        Label("导出为 Markdown", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(Color.Theme.primary)
                }
            }
            
            // 键盘上方排版工具条
            ToolbarItemGroup(placement: .keyboard) {
                HStack(spacing: 20) {
                    // 标题层级菜单
                    Menu {
                        Button("H1 大标题") { textView?.applyFontSize(24, isBold: true) }
                        Button("H2 中标题") { textView?.applyFontSize(20, isBold: true) }
                        Button("正文") { textView?.applyFontSize(16, isBold: false) }
                    } label: {
                        Image(systemName: "textformat.size")
                            .foregroundColor(.gray)
                    }
                    
                    // 加粗按钮
                    Button(action: { textView?.toggleBold() }) {
                        Image(systemName: "bold")
                            .foregroundColor(.gray)
                    }
                    
                    // 列表按钮 (由于 UITextView 不原生支持段落列表符，这里简单以插入文本来模拟)
                    Button(action: { insertTextAtCursor("• ") }) {
                        Image(systemName: "list.bullet")
                            .foregroundColor(.gray)
                    }
                    
                    Button(action: { insertTextAtCursor("1. ") }) {
                        Image(systemName: "list.number")
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Button("完成") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .foregroundColor(Color.Theme.primary)
                }
            }
        }
        .onAppear {
            loadNoteLocally()
        }
        .overlay(
            ToastView(isShowing: $showToast, message: toastMessage)
        )
        // Markdown 导出面板
        .fileExporter(
            isPresented: $showExportDialog,
            document: mdDocument,
            contentType: .plainText,
            defaultFilename: "\(note.title).md"
        ) { result in
            switch result {
            case .success(let url):
                showToast(msg: "成功导出至: \(url.lastPathComponent)")
            case .failure(let error):
                showToast(msg: "导出失败: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - 辅助方法
    private func insertTextAtCursor(_ string: String) {
        guard let tv = textView else { return }
        let currentAttr = tv.typingAttributes
        let str = NSAttributedString(string: string, attributes: currentAttr)
        
        let mutableStr = NSMutableAttributedString(attributedString: tv.attributedText)
        let range = tv.selectedRange
        mutableStr.replaceCharacters(in: range, with: str)
        
        tv.attributedText = mutableStr
        tv.selectedRange = NSRange(location: range.location + string.count, length: 0)
        attributedText = tv.attributedText // 同步回 SwiftUI 状态
    }
    
    private func saveNoteLocally() {
        let success = NoteFileManager.shared.saveNote(fileName: note.fileName, attributedString: attributedText)
        if success {
            showToast(msg: "笔记已保存至本地物理沙箱")
        } else {
            showToast(msg: "保存失败")
        }
    }
    
    private func loadNoteLocally() {
        if let savedStr = NoteFileManager.shared.loadNote(fileName: note.fileName) {
            self.attributedText = savedStr
        } else {
            // 如果不存在，初始化一份带标题的纯文本
            self.attributedText = NSAttributedString(string: "", attributes: [.font: UIFont.systemFont(ofSize: 16)])
        }
    }
    
    private func exportToMarkdown() {
        let mdString = NoteFileManager.shared.generateMarkdown(from: attributedText, title: note.title)
        self.mdDocument = MarkdownDocument(text: mdString)
        self.showExportDialog = true
    }
    
    private func showToast(msg: String) {
        toastMessage = msg
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showToast = false }
        }
    }
}

// 简单的轻量 Toast
struct ToastView: View {
    @Binding var isShowing: Bool
    let message: String
    
    var body: some View {
        VStack {
            if isShowing {
                Text(message)
                    .font(.footnote)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(20)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 50) // 避开导航栏
            }
            Spacer()
        }
        .animation(.easeInOut(duration: 0.3), value: isShowing)
    }
}

#Preview {
    NavigationView {
        NoteEditorView(note: NoteItem.mockNotes[0])
    }
}
