import router from '@ohos.router';
import common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import picker from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import { NoteItem, readNoteFromFile, saveNoteToFile } from '../model/NoteData';

@Entry
@Component
struct NoteEditor {
  @StorageLink('globalNotes') globalNotes: NoteItem[] = [];
  
  @State noteItem: NoteItem | null = null;
  @State bookId: string = '';
  
  @State noteTitle: string = '';
  
  controller: RichEditorController = new RichEditorController();

  aboutToAppear() {
    let params = router.getParams() as Record<string, Object>;
    if (params) {
      if (params.noteItem) {
        this.noteItem = params.noteItem as NoteItem;
        this.bookId = this.noteItem.bookId;
        this.noteTitle = this.noteItem.title;
      } else if (params.bookId) {
        this.bookId = params.bookId as string;
      }
    }
  }

  onPageShow() {
    // Load content if editing an existing note
    if (this.noteItem) {
      let context = getContext(this) as common.UIAbilityContext;
      let fileContent = readNoteFromFile(context, this.noteItem.fileName);
      if (fileContent) {
        try {
          // Attempt to parse as JSON spans
          let spans: Object[] = JSON.parse(fileContent) as Object[];
          if (Array.isArray(spans)) {
            spans.forEach((spanObj: Object) => {
              let span = spanObj as Record<string, Object>;
              if (span.textStyle && typeof span.value === 'string') {
                this.controller.addTextSpan(span.value, { style: span.textStyle as RichEditorTextStyle });
              } else if (typeof span.value === 'string') {
                this.controller.addTextSpan(span.value);
              }
            });
          } else {
            this.controller.addTextSpan(fileContent);
          }
        } catch (e) {
          // Not JSON, probably raw text or old markdown
          this.controller.addTextSpan(fileContent);
        }
      }
    }
  }

  saveNote(): void {
    if (!this.noteTitle.trim()) {
      promptAction.showToast({ message: '请填写笔记标题' });
      return;
    }

    let context = getContext(this) as common.UIAbilityContext;
    
    // Get all spans from RichEditor
    let spans = this.controller.getSpans();
    let contentStr = JSON.stringify(spans);

    let fileName = '';
    if (this.noteItem) {
      fileName = this.noteItem.fileName;
      // Update existing
      saveNoteToFile(context, fileName, contentStr);
      let index = this.globalNotes.findIndex(n => n.id === this.noteItem!.id);
      if (index >= 0) {
        this.globalNotes[index].title = this.noteTitle;
        this.globalNotes[index].updateTime = new Date().toLocaleString();
        this.globalNotes = [...this.globalNotes];
      }
    } else {
      fileName = `note_${Date.now()}.json`;
      saveNoteToFile(context, fileName, contentStr);
      let newNote = new NoteItem(
        Date.now().toString(),
        this.bookId,
        this.noteTitle.trim(),
        fileName,
        new Date().toLocaleString()
      );
      this.globalNotes = [newNote, ...this.globalNotes];
    }

    promptAction.showToast({ message: '笔记保存成功！', duration: 1500 });
    router.back();
  }

  applyHeading(level: number): void {
    let selection = this.controller.getSelection();
    let start = selection.selection[0];
    let end = selection.selection[1];
    
    let fontSize = 16;
    let fontWeight = FontWeight.Normal;
    if (level === 1) { fontSize = 24; fontWeight = FontWeight.Bold; }
    else if (level === 2) { fontSize = 22; fontWeight = FontWeight.Bold; }
    else if (level === 3) { fontSize = 20; fontWeight = FontWeight.Bold; }
    else if (level === 4) { fontSize = 18; fontWeight = FontWeight.Bold; }
    else if (level === 5) { fontSize = 16; fontWeight = FontWeight.Bold; }

    if (start === end) {
      this.controller.setTypingStyle({ fontSize: fontSize, fontWeight: fontWeight });
    } else {
      this.controller.updateSpanStyle({ start, end, textStyle: { fontSize: fontSize, fontWeight: fontWeight } });
    }
  }

  toggleBold(): void {
    let selection = this.controller.getSelection();
    let start = selection.selection[0];
    let end = selection.selection[1];
    
    // Simplified bold toggle: just set bold. Real toggle requires checking current style.
    if (start === end) {
      this.controller.setTypingStyle({ fontWeight: FontWeight.Bold });
    } else {
      this.controller.updateSpanStyle({ start, end, textStyle: { fontWeight: FontWeight.Bold } });
    }
  }

  insertList(prefix: string): void {
    let selection = this.controller.getSelection();
    let start = selection.selection[0];
    this.controller.addTextSpan(prefix, { offset: start, style: { fontSize: 16, fontWeight: FontWeight.Bold } });
  }

  @Builder HeadingMenu() {
    Menu() {
      MenuItem({ content: '1级标题 (H1)' }).onClick(() => { this.applyHeading(1); })
      MenuItem({ content: '2级标题 (H2)' }).onClick(() => { this.applyHeading(2); })
      MenuItem({ content: '3级标题 (H3)' }).onClick(() => { this.applyHeading(3); })
      MenuItem({ content: '4级标题 (H4)' }).onClick(() => { this.applyHeading(4); })
      MenuItem({ content: '5级标题 (H5)' }).onClick(() => { this.applyHeading(5); })
      MenuItem({ content: '正文 (Normal)' }).onClick(() => { this.applyHeading(0); })
    }
  }

  generateMarkdown(): string {
    let spans = this.controller.getSpans();
    let md = '';
    spans.forEach(spanObj => {
      let span = spanObj as RichEditorTextSpanResult;
      let text = span.value;
      if (!text || typeof text !== 'string') return;
      
      let style = span.textStyle;
      let isBold = style && style.fontWeight === FontWeight.Bold;
      let fontSize = style ? (style.fontSize as number) : 16;
      
      let prefix = '';
      if (fontSize >= 24) prefix = '# ';
      else if (fontSize >= 22) prefix = '## ';
      else if (fontSize >= 20) prefix = '### ';
      else if (fontSize >= 18) prefix = '#### ';
      
      if (prefix) {
         let lines = text.split('\n');
         md += lines.map(l => l.trim().length > 0 ? prefix + l : l).join('\n');
      } else if (isBold && fontSize <= 16) {
         let lines = text.split('\n');
         md += lines.map(l => l.trim().length > 0 ? `**${l}**` : l).join('\n');
      } else {
         md += text;
      }
    });
    // Add title as H1 if not already present
    return `# ${this.noteTitle || '未命名笔记'}\n\n${md}`;
  }

  async exportToMarkdown() {
    let mdContent = this.generateMarkdown();
    try {
      let documentSaveOptions = new picker.DocumentSaveOptions();
      documentSaveOptions.newFileNames = [`${this.noteTitle || '笔记'}.md`];
      let documentPicker = new picker.DocumentViewPicker();
      let result = await documentPicker.save(documentSaveOptions);
      if (result && result.length > 0) {
        let uri = result[0];
        let file = fs.openSync(uri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
        fs.writeSync(file.fd, mdContent);
        fs.closeSync(file);
        promptAction.showToast({ message: '成功导出为 Markdown 文件', duration: 2000 });
      }
    } catch (err) {
      console.error('Export failed: ' + JSON.stringify(err));
      promptAction.showToast({ message: '导出取消或失败' });
    }
  }

  @Builder ToolbarIcon(text: string, onClick: () => void, bindMenu?: boolean) {
    Row() {
      Text(text)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontFamily('serif')
        .fontColor('#333')
    }
    .width(36)
    .height(36)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#F5F7F8')
    .borderRadius(8)
    .margin({ right: 12 })
    .onClick(onClick)
    .bindMenu(bindMenu ? this.HeadingMenu() : undefined)
  }

  build() {
    Column() {
      // Header
      Row() {
        Row() {
          Image($r('app.media.ic_back'))
            .width(22)
            .height(22)
            .fillColor($r('app.color.text_primary'))
        }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .onClick(() => { router.back(); })

        Text(this.noteItem ? '编辑笔记' : '新建笔记')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .margin({ left: 8 })

        Blank()

        Button('导出')
          .width(60)
          .height(30)
          .fontSize(13)
          .backgroundColor('#F0F0F0')
          .fontColor($r('app.color.text_primary'))
          .margin({ right: 10 })
          .onClick(() => { this.exportToMarkdown(); })

        Button('保存')
          .width(60)
          .height(30)
          .fontSize(13)
          .backgroundColor($r('app.color.primary'))
          .fontColor('#FFFFFF')
          .onClick(() => { this.saveNote(); })
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 16 })
      .backgroundColor($r('app.color.card_bg'))

      // Title Input
      TextInput({ text: this.noteTitle, placeholder: '输入笔记标题...' })
        .width('100%')
        .height(60)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .backgroundColor('#FFFFFF')
        .borderRadius(0)
        .padding({ left: 20, right: 20 })
        .onChange((val: string) => { this.noteTitle = val; })

      Divider().color('#EFEFEF').strokeWidth(1).margin({ left: 20, right: 20 })

      // Toolbar
      Row() {
        this.ToolbarIcon('Aa', () => {}, true) // Heading Menu
        this.ToolbarIcon('B', () => { this.toggleBold(); })
        this.ToolbarIcon('•', () => { this.insertList('• '); })
        this.ToolbarIcon('1.', () => { this.insertList('1. '); })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 12, bottom: 12 })
      .backgroundColor('#FFFFFF')

      // RichEditor Area
      RichEditor({ controller: this.controller })
        .width('100%')
        .layoutWeight(1)
        .padding(20)
        .backgroundColor('#FFFFFF')
        .aboutToIMEInput((value: RichEditorInsertValue) => {
          return true;
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
