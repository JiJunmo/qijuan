# 栖卷 (MyBookStore) - 书籍详情页模块说明书

本文档对应用内的“书籍详情页”模块（`BookDetail.ets`）的界面架构、数据路由流转、以及交互逻辑层面的底层实现进行详细拆解。

---

## 一、 数据路由与接驳 (Routing & Params)

当从主书架、搜索页、日历页等入口点击某本书籍时，系统通过 `@ohos.router` 进行页面跳转。

- **解耦设计**：为了极速呈现 UI，详情页**并不**在内部通过 `bookId` 去庞大的全局字典中重查所有数据，而是要求上游在调用 `router.pushUrl` 时，以 **强类型 `RouteParams` 载荷** 的形式将书籍全部元数据一次性注入进来。
- **状态接管**：在 `aboutToAppear` 生命周期钩子中，页面将入参映射为组件的本地 `@State`（如 `title`, `cover`, `summary` 等），并接管后续的内部渲染。

---

## 二、 顶栏交互面板 (Top Navigation Bar)

顶栏放弃了原生的默认 TitleBar，采用高度定制化的极简设计：
- **左侧**：自定义的沉浸式返回按钮。
- **右侧“更多”动作菜单**：基于 `bindMenu` 实现原生下拉菜单，提供三大高阶功能入口：
  1. **阅读记录**：点击直接携 `bookId` 跃迁至独立的 `ReadingHistory.ets` 流水记录页。
  2. **修改分类**：调用原生的底部滑动选择器（`TextPickerDialog`），拉取静态字典 `BOOK_CATEGORIES`。选中后，直接定点修改 `@StorageLink('globalBooks')` 中该书的 category 并刷入内存。
  3. **从书架删除**：唤起危险操作弹窗（`AlertDialog`）。确认后从 `globalBooks` 数组中执行过滤销毁，并触发 `router.back()` 回退到主页。

---

## 三、 封面海报与沉浸式枢纽 (Hero Cover & Actions)

这是整个详情页视觉冲击力最强、最核心的枢纽区块。

### 1. 动态色温底座 (CoverColor Backdrop)
提取扫码入库时随机生成的沉浸式色彩码 `coverColor`，作为封面底图容器（宽 `140vp`，高 `190vp`，带 `10px` 阴影）的背景色。使每本书的详情页都拥有截然不同的色彩氛围感。

### 2. 状态机切换器 (Status Chips)
书名和作者下方设计了三个药丸状（Chip）的动态状态按钮：
- 提供 **未读 (Unread)**、**在读 (Reading)**、**已读 (Read)** 三种状态。
- 通过 `@Builder StatusChip` 复用 UI 组件，点击后直接调用 `updateStatus` 修改全局内存树并弹出吐司（Toast）反馈。激活状态会自动变更底色（灰色/橙色/深绿色）。

### 3. 沉浸式阅读入口
最醒目的全屏宽度的绿色圆角主操作按钮 `Button('进入沉浸式阅读')`，它负责将用户带入防止息屏的深度专注环境 (`ImmersiveReading.ets`)。

---

## 四、 档案展陈区块 (Information Sections)

下方通过标准的卡片流（Card Layout）依次呈现详细元数据。

### 1. 书籍档案卡 (Meta Information)
封装了低耦合的内部子组件 `@Component struct MetaItem`，用标准化的左灰右黑（Label-Value）单行网格，呈现：
- **阅读进度**：动态调用 `getCurrentPage()` 结合总页数输出“已读 / 总页码”。
- 其他静态字段：图书分类、出版社、出版日期、页数、ISBN 编码、藏书时间等。

### 2. 内容简介卡 (Summary)
将抓取到的原生大段简介通过 `lineHeight(20)` 的长文本块舒适展示，背景与档案卡同级隔离。

### 3. 伴生笔记卡 (Book Notes)
直接与富文本编辑器生态交互的区块。
- **实时过滤**：依靠 `@StorageLink('globalNotes')` 和 `getBookNotes()` 函数，实时从全局下发该书籍专属的全部笔记阵列。
- **新建动作**：标题栏右侧配有低饱和度的灰底绿字 `+ 新建笔记` 按钮，将当前 `bookId` 传递至富文本编辑器。
- **动态列表**：当存在笔记时，通过 `ForEach` 生成浅灰色背景块。左侧展示截断的单行笔记标题和更新时间，右侧保留箭头/更多 Icon，点击后将整条笔记实体 `noteItem` 发送给编辑器实现数据回显。
