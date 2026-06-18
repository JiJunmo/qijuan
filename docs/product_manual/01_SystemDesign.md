# MyBookStore (栖卷) - 工业级跨平台设计与架构说明书

本文档系统性地梳理了《栖卷》应用的核心业务领域、数据模型、架构设计以及核心 UI/UX 规范。这份说明书旨在为未来将应用迁移至其他平台（如 Android/Kotlin, iOS/Swift, Flutter, React Native 等）提供最高视角的工业级参考指南。

---

## 1. 核心架构模式 (Architecture Pattern)
当前应用基于鸿蒙系统的 `AppStorage` 构建了极简的**响应式单向数据流 (Unidirectional Data Flow)** 架构。
如果迁移到其他平台，强烈建议采用 **MVVM (Model-View-ViewModel)** 或 **MVI (Model-View-Intent)** 架构：
- **Model 层**：负责本地文件 IO (笔记 Markdown) 和 Key-Value 持久化存储 (书籍元数据、流水记录)。
- **ViewModel/Store 层**：维持全局统一的内存状态树（`Books`, `Sessions`, `Notes`），供不同页面订阅并进行数据的派生计算（如日历热力图计算）。
- **View 层**：完全数据驱动的声明式 UI（类似于 Compose, SwiftUI, Flutter）。

---

## 2. 领域数据模型 (Domain Models)

核心数据结构高度扁平化，所有实体依赖唯一 `id` 进行关联（如关系型数据库的外键）。

### 2.1 书籍实体 (`BookItem`)
管理书籍的元数据与生命周期状态。
- `id: string` (UUID，唯一键)
- `title, author, cover, publisher, publishDate, pages, isbn, summary`: 核心元信息
- `coverColor: string`: 根据封面提取的背景色，用于沉浸式 UI 的渲染
- `status: string`: 状态机，限值 `['Unread', 'Reading', 'Finished']`
- `category: string`: 分类标签（如 `['文学', '科技', '商业'...]`）
- `currentPage: number`: 当前阅读进度页码

### 2.2 阅读流水实体 (`ReadingSession`)
采用“事件溯源”理念，不直接修改总时长，而是追加增量流水记录。
- `id: string` (UUID)
- `bookId: string` (关联的书籍 ID)
- `startTime: number` (Unix 时间戳，精确到毫秒)
- `duration: number` (本次阅读总时长，单位：秒)

### 2.3 笔记元数据实体 (`NoteItem`)
用于管理富文本/Markdown格式的读书笔记的元信息。
- `id: string` (UUID)
- `bookId: string` (关联的书籍 ID)
- `title: string` (笔记标题)
- `fileName: string` (映射到本地文件系统的物理文件名，如 `note_17800000.json` 或 `.md`)
- `updateTime: string` (最后修改时间字符串格式，建议后续统一采用 ISO-8601 或时间戳)

---

## 3. 核心功能模块 (Core Modules)

整个应用被划分为四个顶级 Tab 和若干个核心二级页面。

### 3.1 书架模块 (Bookshelf)
- **瀑布流 / 列表混排**：展示用户的藏书。
- **动态筛选**：支持按 `status` 和 `category` 交叉过滤。
- **阅读进度可视化**：书籍条目中需包含全局联动的阅读进度条（通过 `currentPage / pages` 动态计算百分比）。

### 3.2 录入与获取模块 (Scan / Add Book)
- **ISBN 条码扫描**：调用系统相机捕获 ISBN 码。
- **自定义 API 网关**：支持配置第三方书籍元数据 API（如 OpenLibrary, 豆瓣API 的第三方镜像等）并解析 JSON 返回结果。
- **手动录入补底**：完善的书籍信息自定义表单。

### 3.3 统计与日历热力图模块 (Calendar & Stats)
- **GitHub 风格热力日历**：按月生成 7x5 或 7x6 的网格，动态聚合本月所有 `ReadingSession`。并按日时长（0, 30, 60, 120 分钟级别）将格子渲染成不同深度的绿色。
- **单日穿透详情**：
  - **书籍数据柱状图**：横轴为时间（60m/120m/180m/240m刻度），纵轴为封面，直观展示当天各书籍分配的阅读时长。
  - **单日笔记留存**：过滤并呈现该日更新的所有读书笔记入口。

### 3.4 个人中心模块 (Profile & Settings)
- **大盘统计视图**：聚合所有数据，展示“总阅读时长”、“藏书总数”、“笔记总数”。
- **偏好设置弹窗 (Settings Overlay)**：管理 API 密钥、自定义数据源等系统级变量。

### 3.5 沉浸式阅读器 (Immersive Reading)
- **常亮机制 (Wakelock)**：进入计时界面后，必须调用系统 API 强制保持屏幕常亮。
- **极简计时 UI**：巨大、清晰的数字表盘，配套从封面提取或预设的清新扁平背景。
- **生命周期阻断**：退出（滑动返回或点击结束）时，需弹出结算拦截面板（`ReadingStopDialog`），要求用户填入当前的页码 `currentPage` 并确认时长，随后生成一条 `ReadingSession` 落盘。

### 3.6 富文本/Markdown笔记编辑器 (Note Editor)
- **本地 IO 分离**：列表等内存结构只保留元数据。真实富文本内容（JSON Spans 或 Markdown 内容）需在打开编辑器时异步读取，并在保存时以覆盖写入的方式落盘。

---

## 4. UI / UX 设计规范 (Design Language)

### 4.1 色彩系统 (Color Palette)
应用以“清新、静谧、专注”的绿色为主基调（森林系护眼色系）。
- **Primary (主品牌色)**: `#4E8975`（用于按钮、热力图深色、进度条、激活状态）
- **Background (底色)**: `#F5F7F8`（极其柔和的灰白色，避免纯白刺眼）
- **Card Background (卡片色)**: `#FFFFFF`（带有 4px 到 12px 的大圆角和极端柔和的投影，如 `#0A000000 offsetY:2`）
- **Text Primary (主文本)**: `#333333`（高对比度，正文和标题）
- **Text Secondary (副文本)**: `#888888` 或 `#666666`（辅助信息，时间轴刻度）

### 4.2 排版与空间流 (Typography & Spacing)
- **网格系统**：全局采用 `16dp/pt` 的基础边距（Padding/Margin）。
- **无边框卡片**：UI 以卡片区块（Cards）作为容器，避免使用生硬的线条分割（Divider），采用背景色差（Surface vs Background）进行视距拉开。

### 4.3 核心交互与微动效 (Interactions)
- **弹性反馈**：所有卡片的点击都应带有轻微的缩放弹性或 Ripple 波纹（类似 iOS/Material You）。
- **模态交互 (Modal/Dialog)**：采用居中的大圆角（`16dp`）对话框，底部按钮多采用无边框的文本按钮设计（如取消/保存）。

---

## 5. 数据持久化与迁移策略

1. **统一序列化 (JSON)**：当前所有内存态数据都在变更时同步转换为 JSON String 储存在 UserDefaults / DataPreferences 中。
2. **关系重构建议**：如果迁移到具有 SQLite / Room / CoreData 的原生平台，强烈建议将 `BookItem`、`ReadingSession`、`NoteItem` 建立正式的外键级联关系，并采用流式观测（如 Kotlin `Flow`，Swift `Combine`），彻底取代现在的全局序列化覆写操作，能极大提升大型数据量下的渲染性能。
