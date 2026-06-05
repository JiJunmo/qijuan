<div align="center">
  <img src="AppScope/resources/base/media/app_icon.png" width="128" alt="栖卷 Logo"/>
  <h1>栖卷 (QiJuan)</h1>
  <p>纯粹、清爽的本地化个人书房与阅读管理工具</p>
</div>

---

## ✨ 简介

**栖卷 (QiJuan)** 是一款基于 ArkTS (HarmonyOS) 开发的极简本地化阅读管理应用。
在这个信息爆炸的时代，我们希望为您提供一个毫无商业干扰、没有社交压力的纯净阅读角落。在这里，您可以轻松整理藏书、跟进阅读进度、记录每一次翻页的记忆，让心灵在书卷中栖息。

## 🚀 核心特性

- **🔒 绝对的隐私安全 (纯本地)**：无云端数据悄悄同步，无广告，您的所有阅读记录和书房数据均只安全地存放在您的手机本地设备中。
- **📸 扫码快捷录入**：支持调用摄像头扫描书籍 ISBN 码一键录入。
- **🔌 自定义数据源**：不强绑商业图书数据库。支持在设置中配置您自己的“自建服务器 API”及 Token，将数据掌控权完全交还给您。（内置 Google Books 作为免费的备用查询通道）。
- **📊 数据统计与可视化**：清晰美观的饼图和折线趋势图，直观展示您的阅读状态、图书分类占比以及近期的藏书趋势。
- **💾 灵活的本地备份**：支持一键将书籍数据导出为本地 `.txt` (JSON 格式) 文件，方便在更换设备时进行妥善保存。
- **🎨 极简扁平美学**：全局采用纯净清爽的扁平化（Flat Design）设计语言，拒绝过度设计。

## 🛠 开发与构建

### 环境要求
- **IDE**: [DevEco Studio](https://developer.harmonyos.com/cn/develop/deveco-studio)
- **Language**: ArkTS
- **SDK**: API Version 9+ (兼容 HarmonyOS 及 OpenHarmony)

### 快速运行
1. 克隆本仓库到本地：
   ```bash
   git clone https://github.com/JiJunmo/qijuan.git
   ```
2. 在 DevEco Studio 中打开项目。
3. 由于本仓库为开源状态，已隐去原作者的签名信息。在编译前，请前往 **File -> Project Structure -> Signing Configs** 中配置您自己的个人签名证书（或直接勾选 `Automatically generate signature`）。
4. 连接真机或启动模拟器，点击 `Run` 或 `Build`。

## 💡 关于自建服务器 API
当使用扫码录入时，为了获取书籍的详细信息，应用会优先向您配置的服务器发起请求。
- **请求方式**：`GET`
- **请求拼接**：`[您的API地址]?isbn=[扫描到的ISBN]&token=[您的Token]`
- **返回格式要求**：需返回如下标准的 JSON 格式：
  ```json
  {
    "title": "书籍名称",
    "author": "作者姓名",
    "cover": "https://...封面图片链接",
    "summary": "内容简介",
    "publisher": "出版社名称",
    "pubdate": "出版日期",
    "pages": 300,
    "category": "书籍分类（如：文学、计算机等）"
  }
  ```

## 📜 协议
本项目后续可由原作者设定相关的开源协议（推荐 MIT 或 Apache 2.0）。在无特定协议文件声明前，请尊重原作者的著作权。

---

*“让心灵在书卷中栖息。”*
