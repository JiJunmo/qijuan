import { BookItem } from '../model/BookData';
import promptAction from '@ohos.promptAction';
import dataPreferences from '@ohos.data.preferences';
import picker from '@ohos.file.picker';
import pasteboard from '@ohos.pasteboard';
import fs from '@ohos.file.fs';

@Component
export struct SettingsOverlay {
  @Link books: BookItem[];
  @Link customApiUrl: string;
  @Link customApiToken: string;
  @Link showSettingsOverlay: boolean;
  @Link showAboutOverlay: boolean;

  // Save custom server API URL to preferences
  saveCustomApiUrl(url: string) {
    try {
      let pref = dataPreferences.getPreferencesSync(getContext(this), { name: 'myBookStorePrefs' });
      pref.putSync('customApiUrl', url);
      pref.flushSync();
    } catch (err) {
      console.error('Failed to save API URL: ' + JSON.stringify(err));
    }
  }

  // Save custom server API Token to preferences
  saveCustomApiToken(token: string) {
    try {
      let pref = dataPreferences.getPreferencesSync(getContext(this), { name: 'myBookStorePrefs' });
      pref.putSync('customApiToken', token);
      pref.flushSync();
    } catch (err) {
      console.error('Failed to save API Token: ' + JSON.stringify(err));
    }
  }

  // Export books data to a local text file
  async exportBooksToLocal() {
    try {
      let documentSaveOptions = new picker.DocumentSaveOptions();
      documentSaveOptions.newFileNames = ['栖卷_backup.txt'];
      let documentPicker = new picker.DocumentViewPicker();
      let documentSaveResult = await documentPicker.save(documentSaveOptions);
      if (documentSaveResult && documentSaveResult.length > 0) {
        let uri = documentSaveResult[0];
        let file = fs.openSync(uri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
        let jsonStr = JSON.stringify(this.books, null, 2);
        fs.writeSync(file.fd, jsonStr);
        fs.closeSync(file);
        promptAction.showToast({ message: '书籍数据已成功导出到本地', duration: 2000 });
      }
    } catch (err) {
      console.error('Export books failed: ' + JSON.stringify(err));
      promptAction.showToast({ message: '导出失败，请重试', duration: 2000 });
    }
  }

  @Builder ProfileSettingItem(title: string, desc: string, action?: () => void) {
    Row() {
      Column() {
        Text(title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .margin({ bottom: 2 })
        Text(desc)
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      Image($r('app.media.ic_back'))
        .width(16)
        .height(16)
        .rotate({ angle: 180 }) // face right
        .fillColor($r('app.color.text_secondary'))
        .opacity(0.6)
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
    .onClick(() => {
      if (action) {
        action();
      } else {
        promptAction.showToast({ message: `点击了: ${title} (此项暂未开放)`, duration: 1500 });
      }
    })
  }

  build() {
    Stack() {
      // Custom Settings Overlay Dialog
      if (this.showSettingsOverlay) {
        Column() {
          Column() {
            // Header with title and Close button
            Row() {
              Text('设置')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
              
              Blank()
              
              Image($r('app.media.ic_back'))
                .width(20)
                .height(20)
                .rotate({ angle: 90 }) // point down or close shape
                .fillColor($r('app.color.text_secondary'))
                .onClick(() => {
                  this.showSettingsOverlay = false;
                })
            }
            .width('100%')
            .margin({ bottom: 16 })

            // Content Scroll
            Scroll() {
              Column() {
                // Settings List
                this.ProfileSettingItem('书房管理设置', '整理书籍与标签')
                Divider().color($r('app.color.divider')).margin({ top: 12, bottom: 12 })

                // Custom API URL is hidden from UI per user request

                // 邀请码
                Column() {
                  Row() {
                    Text('邀请码')
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .fontColor($r('app.color.text_primary'))
                    Blank()
                  }
                  .width('100%')
                  .margin({ bottom: 6 })

                  TextInput({ text: this.customApiToken, placeholder: '输入邀请码' })
                    .width('100%')
                    .height(40)
                    .fontSize(12)
                    .backgroundColor($r('app.color.background'))
                    .borderRadius(8)
                    .placeholderColor($r('app.color.text_secondary'))
                    .onChange((val: string) => {
                      this.customApiToken = val;
                      this.saveCustomApiToken(val);
                    })
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
                .margin({ bottom: 16 })

                Divider().color($r('app.color.divider')).margin({ top: 12, bottom: 12 })
                this.ProfileSettingItem('数据备份与同步', '导出书籍数据到本地', () => {
                  this.exportBooksToLocal();
                })
                Divider().color($r('app.color.divider')).margin({ top: 12, bottom: 12 })
                this.ProfileSettingItem('关于 栖卷', '版本 1.0.0', () => {
                  this.showAboutOverlay = true;
                })
                Divider().color($r('app.color.divider')).margin({ top: 12, bottom: 12 })
                this.ProfileSettingItem('联系开发者', 'jihe_neu@foxmail.com', () => {
                  let pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, 'jihe_neu@foxmail.com');
                  let systemPasteboard = pasteboard.getSystemPasteboard();
                  systemPasteboard.setData(pasteData).then(() => {
                    promptAction.showToast({ message: '邮箱已复制到剪贴板', duration: 1500 });
                  }).catch((err: Error) => {
                    promptAction.showToast({ message: '复制失败', duration: 1500 });
                  });
                })
              }
              .width('100%')
            }
            .layoutWeight(1)
            .scrollBar(BarState.Off)

            // Bottom close button
            Button('关闭')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFF')
              .backgroundColor($r('app.color.primary'))
              .width('100%')
              .height(40)
              .margin({ top: 16 })
              .onClick(() => {
                this.showSettingsOverlay = false;
              })
          }
          .width('90%')
          .constraintSize({ maxHeight: '75%' })
          .padding(20)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(16)
          .shadow({ radius: 12, color: '#30000000', offsetY: 6 })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#60000000') // Translucent mask
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }

      // About 栖卷 Overlay Dialog
      if (this.showAboutOverlay) {
        Column() {
          Column() {
            // Header
            Row() {
              Text('关于 栖卷')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
              Blank()
              Image($r('app.media.ic_back'))
                .width(20)
                .height(20)
                .rotate({ angle: 90 })
                .fillColor($r('app.color.text_secondary'))
                .onClick(() => {
                  this.showAboutOverlay = false;
                })
            }
            .width('100%')
            .margin({ bottom: 16 })

            // Content Scroll
            Scroll() {
              Column() {
                Text('✨ 欢迎来到您的掌上私人书房')
                  .fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary')).margin({ bottom: 6 })
                Text('栖卷 是一款致力于为您提供纯粹、清爽阅读管理的本地化应用。在这里，您可以轻松整理您的藏书、跟进阅读进度，并记录下每一次阅读的心得体会，让每一次翻页的记忆都得以妥善安放。')
                  .fontSize(13).fontColor($r('app.color.text_secondary')).lineHeight(20).margin({ bottom: 16 })

                Text('🔌 关于图书扫码录入功能')
                  .fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary')).margin({ bottom: 6 })
                Text('为了给您提供极简、无商业干扰的体验，本应用目前采用邀请制，不直接对外提供大规模图书接口。若需要使用“扫码录入”功能，请通过下方的邮箱联系开发者获取邀请码，并在上方设置中填写邀请码后即可正常使用。')
                  .fontSize(13).fontColor($r('app.color.text_secondary')).lineHeight(20).margin({ bottom: 16 })

                Text('🔒 关于数据隐私与安全提示')
                  .fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary')).margin({ bottom: 6 })
                Text('我们深知每一条阅读记录对您而言都弥足珍贵。为了最大程度地保护您的隐私：\n栖卷 始终作为一个纯本地应用运行。开发者不提供任何远程服务器用于保存、读取您的个人记录，也完全不会进行任何形式的云端数据悄悄同步。\n您所有的藏书信息均只安全地存放在您的手机本地设备中。为了避免设备更换或卸载带来的数据丢失，请您务必养成好习惯，定期使用设置中的“导出书籍数据到本地”功能，将备份文件妥善保存。')
                  .fontSize(13).fontColor($r('app.color.text_secondary')).lineHeight(20).margin({ bottom: 16 })

                Text('🚀 未来计划')
                  .fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary')).margin({ bottom: 6 })
                Text('近期打算做的事：\n1. 更科学的书籍自动化分类\n2. 阅读时间统计和管理\n3. 多样化的图书录入方式\n\n永远不打算做的事：\n1. 朋友圈和社交功能\n2. 云端同步功能')
                  .fontSize(13).fontColor($r('app.color.text_secondary')).lineHeight(20).margin({ bottom: 20 })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }
            .layoutWeight(1)
            .scrollBar(BarState.Off)

            Button('关闭')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFF')
              .backgroundColor($r('app.color.primary'))
              .width('100%')
              .height(40)
              .margin({ top: 16 })
              .onClick(() => {
                this.showAboutOverlay = false;
              })
          }
          .width('90%')
          .constraintSize({ maxHeight: '80%' })
          .padding(20)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(16)
          .shadow({ radius: 12, color: '#30000000', offsetY: 6 })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#60000000') // Translucent mask
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
    }
  }
}
