import Foundation
import UIKit
import UniformTypeIdentifiers

class NoteFileManager {
    static let shared = NoteFileManager()
    
    private init() {}
    
    // 获取沙箱 Documents 路径
    private func getDocumentDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    /// 将富文本落盘为 RTF 数据保存到物理沙箱
    func saveNote(fileName: String, attributedString: NSAttributedString) -> Bool {
        let fileURL = getDocumentDirectory().appendingPathComponent(fileName)
        do {
            let data = try attributedString.data(from: NSRange(location: 0, length: attributedString.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
            try data.write(to: fileURL)
            return true
        } catch {
            print("Failed to save note: \(error)")
            return false
        }
    }
    
    /// 从物理沙箱反序列化恢复富文本
    func loadNote(fileName: String) -> NSAttributedString? {
        let fileURL = getDocumentDirectory().appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let attrStr = try NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
            return attrStr
        } catch {
            print("Failed to load note: \(error)")
            return nil
        }
    }
    
    /// AST 遍历引擎：将 NSAttributedString 逆向转换为 Markdown 文本
    func generateMarkdown(from attrStr: NSAttributedString, title: String) -> String {
        var markdown = "# \(title)\n\n"
        
        attrStr.enumerateAttributes(in: NSRange(location: 0, length: attrStr.length), options: []) { attributes, range, _ in
            let textSegment = (attrStr.string as NSString).substring(with: range)
            var currentSegment = textSegment
            
            // 过滤空换行片段的格式化解析，防止在空白处加上不必要的 **
            guard !currentSegment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                markdown += currentSegment
                return
            }
            
            if let font = attributes[.font] as? UIFont {
                let pointSize = font.pointSize
                let isBold = font.fontDescriptor.symbolicTraits.contains(.traitBold)
                
                // 处理标题层级
                if pointSize >= 24 {
                    currentSegment = "## " + currentSegment
                } else if pointSize >= 20 {
                    currentSegment = "### " + currentSegment
                } else {
                    // 正文部分如果有加粗，注入粗体 markdown 语法
                    if isBold {
                        // 防止破坏前后的空格
                        currentSegment = "**\(currentSegment.trimmingCharacters(in: .whitespacesAndNewlines))**"
                    }
                }
            }
            
            markdown += currentSegment
        }
        
        return markdown
    }
    
    /// 删除沙盒中的笔记文件
    func deleteNoteContent(fileName: String) {
        let fileURL = getDocumentDirectory().appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)
    }
}
