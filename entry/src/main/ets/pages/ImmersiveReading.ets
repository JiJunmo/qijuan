import router from '@ohos.router';
import window from '@ohos.window';
import promptAction from '@ohos.promptAction';
import util from '@ohos.util';
import { BookItem } from '../model/BookData';
import { ReadingSession } from '../model/ReadingSessionData';

@CustomDialog
struct ReadingStopDialog {
  controller?: CustomDialogController;
  @Link elapsedSeconds: number;
  totalPages: number = 0;
  @Link inputPageStr: string;
  confirmAction: () => void = () => {};
  cancelAction: () => void = () => {};

  formatDurationReadable(totalSeconds: number): string {
    let m = Math.floor(totalSeconds / 60);
    let s = totalSeconds % 60;
    if (m > 0) {
      return `${m} 分 ${s} 秒`;
    }
    return `${s} 秒`;
  }

  build() {
    Column() {
      Text('停止阅读')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .margin({ bottom: 16 })
      
      Text(`您本次阅读时长 ${this.formatDurationReadable(this.elapsedSeconds)}，是否停止阅读并保存记录？`)
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .margin({ bottom: 16 })
      
      Row() {
        Text('当前阅读进度 ')
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
        TextInput({ text: this.inputPageStr })
          .type(InputType.Number)
          .width(80)
          .textAlign(TextAlign.Center)
          .onChange((value: string) => { this.inputPageStr = value })
        Text(` 页 (共 ${this.totalPages} 页)`)
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .margin({ bottom: 24 })
        
      Row() {
        Button('继续阅读')
          .backgroundColor(Color.Transparent)
          .fontColor('#4E8975')
          .onClick(() => {
            this.controller?.close();
            this.cancelAction();
          })
        Blank()
        Button('结束并保存')
          .backgroundColor(Color.Transparent)
          .fontColor('#E64545')
          .onClick(() => {
            this.controller?.close();
            this.confirmAction();
          })
      }
      .width('100%')
    }
    .padding(24)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
  }
}

@Entry
@Component
struct ImmersiveReading {
  @StorageLink('globalBooks') books: BookItem[] = [];
  @StorageLink('globalReadingSessions') readingSessions: ReadingSession[] = [];
  
  @State bookId: string = '';
  @State bookTitle: string = '';
  @State bookPages: number = 0;
  
  @State startTime: number = 0;
  @State elapsedSeconds: number = 0;
  @State isRunning: boolean = true;
  @State currentInputPage: string = '';
  
  private timerId: number = -1;
  private currentWindow: window.Window | null = null;

  dialogController: CustomDialogController = new CustomDialogController({
    builder: ReadingStopDialog({
      elapsedSeconds: $elapsedSeconds,
      totalPages: this.bookPages,
      inputPageStr: $currentInputPage,
      confirmAction: () => { this.saveRecordAndExit(); },
      cancelAction: () => { this.isRunning = true; }
    }),
    autoCancel: false,
    alignment: DialogAlignment.Center
  });

  aboutToAppear() {
    let params = router.getParams() as Record<string, Object>;
    if (params) {
      this.bookId = params.bookId as string;
      this.bookTitle = params.bookTitle as string;
      
      let book = this.books.find(b => b.id === this.bookId);
      if (book) {
        this.bookPages = book.pages;
        this.currentInputPage = (book.currentPage || 0).toString();
      }
    }
    this.startTime = new Date().getTime();
    this.startTimer();
    this.setKeepScreenOn(true);
  }

  aboutToDisappear() {
    this.stopTimer();
    this.setKeepScreenOn(false);
  }

  onBackPress(): boolean {
    this.confirmStopReading();
    return true; // Prevent default back behavior
  }

  startTimer() {
    this.timerId = setInterval(() => {
      if (this.isRunning) {
        this.elapsedSeconds++;
      }
    }, 1000);
  }

  stopTimer() {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  async setKeepScreenOn(isKeepOn: boolean) {
    try {
      if (!this.currentWindow) {
        this.currentWindow = await window.getLastWindow(getContext(this));
      }
      await this.currentWindow.setWindowKeepScreenOn(isKeepOn);
    } catch (err) {
      console.error('Failed to set keep screen on: ' + JSON.stringify(err));
    }
  }

  formatTime(totalSeconds: number): string {
    let h = Math.floor(totalSeconds / 3600);
    let m = Math.floor((totalSeconds % 3600) / 60);
    let s = totalSeconds % 60;
    
    let mStr = m < 10 ? '0' + m : m.toString();
    let sStr = s < 10 ? '0' + s : s.toString();
    
    if (h > 0) {
      let hStr = h < 10 ? '0' + h : h.toString();
      return `${hStr}:${mStr}:${sStr}`;
    }
    return `${mStr}:${sStr}`;
  }

  formatDurationReadable(totalSeconds: number): string {
    let m = Math.floor(totalSeconds / 60);
    let s = totalSeconds % 60;
    if (m > 0) {
      return `${m} 分 ${s} 秒`;
    }
    return `${s} 秒`;
  }

  confirmStopReading() {
    this.isRunning = false;
    this.dialogController.open();
  }

  saveRecordAndExit() {
    if (this.elapsedSeconds > 0) {
      let newSession = new ReadingSession(
        util.generateRandomUUID(),
        this.bookId,
        this.startTime,
        this.elapsedSeconds
      );
      this.readingSessions = [newSession, ...this.readingSessions];
      
      let newPageNum = parseInt(this.currentInputPage);
      if (!isNaN(newPageNum)) {
        this.books = this.books.map(b => {
          if (b.id === this.bookId) {
            b.currentPage = newPageNum;
          }
          return b;
        });
      }

      promptAction.showToast({ message: '阅读记录已保存' });
    } else {
      promptAction.showToast({ message: '阅读时长过短，未保存' });
    }
    router.back();
  }

  build() {
    Column() {
      // Top info
      Row() {
        Text(`正在阅读：${this.bookTitle}`)
          .fontSize(16)
          .fontColor('#888888')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .padding({ top: 40, left: 24, right: 24 })
      .justifyContent(FlexAlign.Center)

      Blank()

      // Timer Display
      Column() {
        Text(this.formatTime(this.elapsedSeconds))
          .fontSize(80)
          .fontWeight(FontWeight.Bolder)
          .fontColor('#2C3E50')
          .letterSpacing(4)
        
        Text('沉浸式阅读中...')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#2C3E50')
          .margin({ top: 16 })
      }
      .alignItems(HorizontalAlign.Center)
      
      Blank()

      // Stop button
      Button('结束阅读')
        .width('60%')
        .height(56)
        .backgroundColor('rgba(255, 255, 255, 0.45)')
        .fontColor('#2C3E50')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .borderRadius(28)
        .margin({ bottom: 60 })
        .shadow({ radius: 10, color: '#0A000000', offsetX: 0, offsetY: 5 })
        .onClick(() => {
          this.confirmStopReading();
        })
    }
    .width('100%')
    .height('100%')
    .backgroundImage($r('app.media.immersive_bg'))
    .backgroundImageSize(ImageSize.Cover)
    .backgroundImagePosition(Alignment.Center)
  }
}
