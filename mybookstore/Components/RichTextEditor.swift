import SwiftUI
import UIKit

/// 富文本底层引擎，封装 UIKit 的 UITextView 以支持选区级别的排版操作
struct RichTextEditor: UIViewRepresentable {
    @Binding var text: NSAttributedString
    @Binding var internalTextView: UITextView? // 暴露底层视图引用，便于外层 Toolbar 直接操作选区
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = true
        textView.isScrollEnabled = true
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        
        // 设置默认内边距
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        
        DispatchQueue.main.async {
            self.internalTextView = textView
        }
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        // 为了防止用户在输入时不断的更新导致光标跳跃，只在初始化或者外层强行覆盖时更新
        if uiView.attributedText != text && !context.coordinator.isEditing {
            uiView.attributedText = text
            // 确保有个默认字体
            if uiView.font == nil {
                uiView.font = UIFont.systemFont(ofSize: 16)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditor
        var isEditing: Bool = false
        
        init(_ parent: RichTextEditor) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            isEditing = true
            parent.text = textView.attributedText
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            isEditing = false
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            isEditing = true
        }
    }
}

// MARK: - 工具栏辅助扩展
extension UITextView {
    /// 对当前光标选中的文字应用加粗/取消加粗
    func toggleBold() {
        guard let currentFont = typingAttributes[.font] as? UIFont else { return }
        let isBold = currentFont.fontDescriptor.symbolicTraits.contains(.traitBold)
        
        var traits = currentFont.fontDescriptor.symbolicTraits
        if isBold {
            traits.remove(.traitBold)
        } else {
            traits.insert(.traitBold)
        }
        
        if let newDescriptor = currentFont.fontDescriptor.withSymbolicTraits(traits) {
            let newFont = UIFont(descriptor: newDescriptor, size: currentFont.pointSize)
            applyAttributeToSelection(key: .font, value: newFont)
        }
    }
    
    /// 对当前选区应用字号修改（用作多级标题 H1, H2, 正文）
    func applyFontSize(_ size: CGFloat, isBold: Bool = false) {
        var font = UIFont.systemFont(ofSize: size)
        if isBold {
            if let desc = font.fontDescriptor.withSymbolicTraits(.traitBold) {
                font = UIFont(descriptor: desc, size: size)
            }
        }
        applyAttributeToSelection(key: .font, value: font)
    }
    
    private func applyAttributeToSelection(key: NSAttributedString.Key, value: Any) {
        let range = selectedRange
        if range.length > 0 {
            // 如果选中了具体文本，直接修改选中部分的属性
            let mutableString = NSMutableAttributedString(attributedString: attributedText)
            mutableString.addAttribute(key, value: value, range: range)
            attributedText = mutableString
            selectedRange = range // 恢复选区
        } else {
            // 如果只在光标位置，改变后续输入的默认属性
            var attrs = typingAttributes
            attrs[key] = value
            typingAttributes = attrs
        }
    }
}
