# 栖卷 (MyBookStore) - 笔记编辑器模块说明书

本文档对应用内的核心沉淀模块——“读书笔记编辑器”（`NoteEditor.ets`）的富文本架构、本地文件系统（FS）持久化方案、以及 Markdown 导出逻辑进行详细说明。

---

## 一、 核心富文本引擎 (RichEditor)

笔记页面彻底抛弃了简陋的 `TextArea` 纯文本框，采用了 HarmonyOS 原生的 **`RichEditor`** 组件，构建了一个轻量级的 WYSIWYG（所见即所得）富文本编辑器。

### 1. 控制器代理 (`RichEditorController`)
界面的所有排版逻辑全部通过实例化并绑定 `RichEditorController` 来完成。它负责监听光标选区（Selection），并在光标位置动态注入 `Span`（文本段落片段）。

### 2. 定制化工具栏 (Toolbar)
在软键盘和标题栏之间，提供了一个原生的编辑工具条：
- **标题体系 (Aa)**：绑定了一个原生的长按菜单 (`Menu`)，提供从 H1 到 H5 以及正文的排版选项。底层通过向 `controller.updateSpanStyle` 下发不同的 `fontSize` 和 `fontWeight: Bold` 来渲染层级差异。
- **加粗 (B)**：快速对当前光标选区触发加粗样式。
- **列表控制**：提供无序列表（`•`）和有序列表（`1.`）的前置占位符插入能力（`controller.addTextSpan`）。

---

## 二、 极限分离的存储架构 (Data Persistence)

考虑到富文本编辑器会产生极度冗长的 JSON 样式标签树，为了防止应用的主状态树（`AppStorage`）因负载过大而引发全局卡顿或 OOM（内存溢出），笔记模块采用了**元数据与实体分离**的设计。

### 1. 内存态只留“元数据” (`NoteItem`)
全局变量 `@StorageLink('globalNotes')` 数组中维护的 `NoteItem` 对象仅仅是一层极简的壳：
```typescript
{
  id: string,
  bookId: string, // 外键，指向具体书籍
  title: string,  // 笔记标题（列表展示用）
  fileName: string, // 物理层文件名！如 'note_17800000.json'
  updateTime: string
}
```

### 2. 沙箱物理存储 (File System IO)
- **保存 (Save)**：点击保存时，调用 `controller.getSpans()` 获取完整的排版树状结构数组，通过 `JSON.stringify` 序列化。然后利用 `@ohos.file.fs` 以覆写（`TRUNC`）模式将巨大的字符串直接写入沙箱绝对路径 `context.filesDir + fileName` 中。
- **回显 (Hydration)**：当从详情页点击某条笔记进入编辑器时，在 `onPageShow` 生命周期中，根据 `fileName` 找到物理文件，读取全部 JSON，再循环遍历恢复并重构渲染出原生的 Span 样式送回 `RichEditor` 中。如果解析 JSON 失败（兼容极其古老的旧纯文本数据），则无损降级为纯文本直接渲染。

---

## 三、 Markdown 语法逆向生成引擎

笔记编辑器不只是一个封闭的花园。为了保证用户的心血能够随时迁移到诸如 Obsidian、Notion 等主流知识库，它内置了**逆向 Markdown 编译器**。

### 1. AST 解析与转换 (`generateMarkdown`)
- 遍历 `controller.getSpans()` 返回的全部节点。
- 探测其挂载的 `textStyle`。如果 `fontSize >= 24` 逆向生成 `# `（H1），`>= 22` 生成 `## `，以此类推。
- 探测 `fontWeight === FontWeight.Bold` 且非标题的段落，自动在文本两侧包裹双星号 `**粗体**`。
- 将最终拼接好的纯文本在首部追加真实的 `# 笔记大标题`，生成标准的 Markdown 文本串。

### 2. 本地无障碍导出 (`exportToMarkdown`)
- 点击顶部的“导出”按钮，调用系统的 `@ohos.file.picker.DocumentViewPicker`，唤起操作系统的默认文档管理器。
- 引导用户在公域（如下载文件夹或文档库）创建 `[笔记标题].md` 文件，将上一步生成的 Markdown 串以 `utf-8` 编码流式写入，从而完成从私有沙箱到系统公域跨越的数据解放。
