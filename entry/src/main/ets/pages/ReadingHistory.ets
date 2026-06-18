import router from '@ohos.router';
import util from '@ohos.util';
import promptAction from '@ohos.promptAction';
import { ReadingSession } from '../model/ReadingSessionData';

@CustomDialog
struct ManualRecordDialog {
  controller?: CustomDialogController;
  @Link inputDateStr: string; // YYYY-MM-DD
  @Link inputTimeStr: string; // HH:mm
  @Link inputDurationMins: string;
  confirmAction: () => void = () => {};

  build() {
    Column() {
      Text('补录阅读记录')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 16 })
      
      Row() {
        Text('开始日期').width(80)
        TextInput({ text: this.inputDateStr, placeholder: 'YYYY-MM-DD' })
          .layoutWeight(1)
          .onChange((v) => this.inputDateStr = v)
      }.width('100%').margin({ bottom: 12 })
      
      Row() {
        Text('开始时间').width(80)
        TextInput({ text: this.inputTimeStr, placeholder: 'HH:mm' })
          .layoutWeight(1)
          .onChange((v) => this.inputTimeStr = v)
      }.width('100%').margin({ bottom: 12 })
      
      Row() {
        Text('阅读时长').width(80)
        TextInput({ text: this.inputDurationMins, placeholder: '分钟' })
          .type(InputType.Number)
          .layoutWeight(1)
          .onChange((v) => this.inputDurationMins = v)
      }.width('100%').margin({ bottom: 24 })
      
      Row() {
        Button('取消')
          .backgroundColor(Color.Transparent)
          .fontColor('#888')
          .onClick(() => this.controller?.close())
        Blank()
        Button('保存')
          .backgroundColor(Color.Transparent)
          .fontColor($r('app.color.primary'))
          .onClick(() => {
             this.controller?.close();
             this.confirmAction();
          })
      }.width('100%')
    }
    .padding(24)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
  }
}

@Entry
@Component
struct ReadingHistory {
  @StorageLink('globalReadingSessions') readingSessions: ReadingSession[] = [];
  
  @State bookId: string = '';
  @State bookTitle: string = '';
  
  @State inputDateStr: string = '';
  @State inputTimeStr: string = '';
  @State inputDurationMins: string = '';
  
  dialogController: CustomDialogController = new CustomDialogController({
    builder: ManualRecordDialog({
      inputDateStr: $inputDateStr,
      inputTimeStr: $inputTimeStr,
      inputDurationMins: $inputDurationMins,
      confirmAction: () => { this.saveManualRecord(); }
    }),
    alignment: DialogAlignment.Center
  });

  aboutToAppear() {
    let params = router.getParams() as Record<string, Object>;
    if (params) {
      this.bookId = params.bookId as string;
      this.bookTitle = params.bookTitle as string;
    }
  }

  getSessions(): ReadingSession[] {
    return this.readingSessions.filter(s => s.bookId === this.bookId).sort((a, b) => b.startTime - a.startTime);
  }

  openManualRecordDialog() {
    let now = new Date();
    let pad = (n: number) => n < 10 ? '0' + n : n.toString();
    this.inputDateStr = `${now.getFullYear()}-${pad(now.getMonth()+1)}-${pad(now.getDate())}`;
    this.inputTimeStr = `${pad(now.getHours())}:${pad(now.getMinutes())}`;
    this.inputDurationMins = '30';
    this.dialogController.open();
  }

  saveManualRecord() {
    let dateParts = this.inputDateStr.split('-');
    let timeParts = this.inputTimeStr.split(':');
    if (dateParts.length !== 3 || timeParts.length !== 2) {
      promptAction.showToast({ message: '日期或时间格式不正确' });
      return;
    }
    let startTime = new Date(
      parseInt(dateParts[0]), 
      parseInt(dateParts[1])-1, 
      parseInt(dateParts[2]), 
      parseInt(timeParts[0]), 
      parseInt(timeParts[1])
    ).getTime();
    
    let durationMins = parseInt(this.inputDurationMins);
    if (isNaN(durationMins) || durationMins <= 0) {
      promptAction.showToast({ message: '时长请输入有效数字' });
      return;
    }
    
    let newSession = new ReadingSession(
      util.generateRandomUUID(),
      this.bookId,
      startTime,
      durationMins * 60
    );
    this.readingSessions = [newSession, ...this.readingSessions];
    promptAction.showToast({ message: '补录成功' });
  }

  formatDate(timestamp: number): string {
    let date = new Date(timestamp);
    let y = date.getFullYear();
    let m = date.getMonth() + 1;
    let d = date.getDate();
    let hh = date.getHours();
    let mm = date.getMinutes();
    
    let mStr = m < 10 ? '0' + m : m;
    let dStr = d < 10 ? '0' + d : d;
    let hhStr = hh < 10 ? '0' + hh : hh;
    let mmStr = mm < 10 ? '0' + mm : mm;
    
    return `${y}年${mStr}月${dStr}日 ${hhStr}:${mmStr}`;
  }

  formatDuration(seconds: number): string {
    let h = Math.floor(seconds / 3600);
    let m = Math.floor((seconds % 3600) / 60);
    let s = seconds % 60;
    
    let res = '';
    if (h > 0) res += `${h}小时 `;
    if (m > 0 || h > 0) res += `${m}分钟 `;
    res += `${s}秒`;
    return res;
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
        .onClick(() => {
          router.back();
        })

        Text('阅读记录')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .margin({ left: 8 })
          
        Blank()
        
        Text('补录记录')
          .fontSize(14)
          .fontColor($r('app.color.primary'))
          .onClick(() => this.openManualRecordDialog())
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 16 })
      .backgroundColor($r('app.color.card_bg'))

      // Title
      Text(`《${this.bookTitle}》`)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .margin({ top: 16, bottom: 16 })

      // List
      List({ space: 12 }) {
        if (this.getSessions().length === 0) {
          ListItem() {
            Text('暂无阅读记录')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ top: 40 })
          }
        } else {
          ForEach(this.getSessions(), (session: ReadingSession) => {
            ListItem() {
              Row() {
                Column() {
                  Text('开始时间')
                    .fontSize(12)
                    .fontColor($r('app.color.text_secondary'))
                    .margin({ bottom: 4 })
                  Text(this.formatDate(session.startTime))
                    .fontSize(14)
                    .fontColor($r('app.color.text_primary'))
                }
                .alignItems(HorizontalAlign.Start)
                
                Blank()
                
                Column() {
                  Text('阅读时长')
                    .fontSize(12)
                    .fontColor($r('app.color.text_secondary'))
                    .margin({ bottom: 4 })
                  Text(this.formatDuration(session.duration))
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('app.color.primary'))
                }
                .alignItems(HorizontalAlign.End)
              }
              .width('100%')
              .padding(16)
              .backgroundColor($r('app.color.card_bg'))
              .borderRadius(12)
            }
          }, (item: ReadingSession) => item.id)
        }
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }
}
