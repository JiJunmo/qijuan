import { BookItem, BOOK_CATEGORIES } from '../model/BookData';
import promptAction from '@ohos.promptAction';
import abilityAccessCtrl, { PermissionRequestResult } from '@ohos.abilityAccessCtrl';
import { common } from '@kit.AbilityKit';
import { customScan, scanBarcode, scanCore } from '@kit.ScanKit';
import { BusinessError } from '@kit.BasicServicesKit';
import http from '@ohos.net.http';
import fs from '@ohos.file.fs';

@Component
export struct ScanTab {
  @Link books: BookItem[];
  @Link customApiUrl: string;
  @Link customApiToken: string;
  @Link @Watch('onTabChanged') currentIndex: number;
  
  @State testIsbn: string = '';
  @State hasCameraPermission: boolean = false;
  @State isSearching: boolean = false;
  @State showConfirmDialog: boolean = false;
  @State pendingBook: BookItem = new BookItem('', '', '', $r('app.media.cover_placeholder'), '#5F8575', 'unread', '', '', '', 0, '', '');

  private mXComponentController: XComponentController = new XComponentController();
  private cameraWidth: number = 1080;
  private cameraHeight: number = 1920;

  aboutToAppear() {
    if (this.currentIndex === 1) {
      let hasPermission = this.checkCameraPermission();
      if (hasPermission) {
        this.hasCameraPermission = true;
      } else {
        this.requestCameraPermission();
      }
    }
  }

  aboutToDisappear() {
    this.stopScan();
  }

  onTabChanged() {
    if (this.currentIndex === 1) {
      let hasPermission = this.checkCameraPermission();
      if (hasPermission) {
        this.hasCameraPermission = true;
        // startScan is handled by XComponent onLoad if it mounts, 
        // but if it's already mounted we might need to manually start
        setTimeout(() => {
          this.startScan();
        }, 50);
      } else {
        this.requestCameraPermission();
      }
    } else {
      this.stopScan();
      this.hasCameraPermission = false;
    }
  }

  // Check camera permission status
  checkCameraPermission(): boolean {
    try {
      let context = getContext(this) as common.UIAbilityContext;
      let atManager = abilityAccessCtrl.createAtManager();
      let tokenID = context.applicationInfo.accessTokenId;
      let grantStatus = atManager.checkAccessTokenSync(tokenID, 'ohos.permission.CAMERA');
      return grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    } catch (err) {
      console.error('checkCameraPermission error: ' + JSON.stringify(err));
      return false;
    }
  }

  // Dynamic Camera Permission requesting
  requestCameraPermission() {
    let context = getContext(this) as common.UIAbilityContext;
    let atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    atManager.requestPermissionsFromUser(context, ['ohos.permission.CAMERA']).then((data: PermissionRequestResult) => {
      let grantStatus: number[] = data.authResults;
      if (grantStatus.length > 0 && grantStatus[0] === 0) {
        // Permission granted, start XComponent stream setup
        promptAction.showToast({ message: '相机权限已开启' });
        this.hasCameraPermission = true;
      } else {
        promptAction.showToast({ message: '扫码功能需要相机权限，请在设置中开启' });
        this.hasCameraPermission = false;
      }
    }).catch((err: BusinessError) => {
      console.error('Request permission failed: ' + JSON.stringify(err));
      this.hasCameraPermission = false;
    });
  }

  // Start Custom Scan preview
  startScan() {
    try {
      let surfaceId: string = this.mXComponentController.getXComponentSurfaceId();
      let viewControl: customScan.ViewControl = {
        width: this.cameraWidth,
        height: this.cameraHeight,
        surfaceId: surfaceId
      };

      let options: scanBarcode.ScanOptions = {
        scanTypes: [scanCore.ScanType.ALL],
        enableMultiMode: true,
        enableAlbum: true
      };

      customScan.init(options);
      customScan.start(viewControl).then((scanResult: Array<scanBarcode.ScanResult>) => {
        if (scanResult && scanResult.length > 0) {
          let isbn = scanResult[0].originalValue;
          promptAction.showToast({ message: `扫码成功: ${isbn}` });
          this.stopScan();
          this.fetchBookDetails(isbn);
        }
      }).catch((error: BusinessError) => {
        console.error(`customScan.start Promise failed: ${error.code}, ${error.message}`);
      });
    } catch (error) {
      const err = error as BusinessError;
      console.error(`customScan start calling error: ${err.code}, ${err.message}`);
    }
  }

  // Stop custom scan and release resources
  stopScan() {
    try {
      customScan.stop();
      customScan.release();
    } catch (error) {
      console.error('customScan stop/release error: ' + JSON.stringify(error));
    }
  }

  getRandomColor(): string {
    const colors = ['#5F8575', '#4A6B82', '#BFA76F', '#2E3A3B', '#826C5F', '#7D6B88', '#7F5E5E', '#684C58'];
    return colors[Math.floor(Math.random() * colors.length)];
  }

  downloadCover(isbn: string, coverUrl: string): Promise<string | Resource> {
    return new Promise((resolve) => {
      if (!coverUrl || !coverUrl.startsWith('http')) {
        resolve($r('app.media.cover_placeholder'));
        return;
      }
      try {
        let context = getContext(this) as common.UIAbilityContext;
        let filePath = context.filesDir + '/' + isbn + '.jpg';
        
        // Check if file already exists
        try {
          if (fs.accessSync(filePath)) {
            resolve('file://' + filePath);
            return;
          }
        } catch (e) {
          // File does not exist, proceed to download
        }

        let httpRequest = http.createHttp();
        httpRequest.request(
          coverUrl,
          {
            method: http.RequestMethod.GET,
            expectDataType: http.HttpDataType.ARRAY_BUFFER,
            connectTimeout: 8000,
            readTimeout: 8000
          },
          (err, data) => {
            if (!err && data.responseCode === 200) {
              try {
                let file = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
                fs.writeSync(file.fd, data.result as ArrayBuffer);
                fs.closeSync(file);
                resolve('file://' + filePath);
                httpRequest.destroy();
                return;
              } catch (e) {
                console.error('保存本地封面文件失败: ' + JSON.stringify(e));
              }
            }
            resolve(coverUrl); // fallback to remote URL if download fails
            httpRequest.destroy();
          }
        );
      } catch (err) {
        console.error('下载本地封面抛错: ' + JSON.stringify(err));
        resolve(coverUrl);
      }
    });
  }

  // 1. Query Custom Server (returns Promise<BookItem | null>)
  queryCustomServer(isbn: string): Promise<BookItem | null> {
    return new Promise((resolve) => {
      if (!this.customApiUrl) {
        resolve(null);
        return;
      }

      let httpRequest = http.createHttp();
      let baseUrl = this.customApiUrl.trim();
      if (!baseUrl.startsWith('http://') && !baseUrl.startsWith('https://')) {
        baseUrl = 'http://' + baseUrl;
      }
      let fullUrl = '';
      if (baseUrl.includes('isbn=')) {
        if (baseUrl.endsWith('isbn=')) {
          fullUrl = baseUrl + isbn;
        } else {
          fullUrl = baseUrl;
        }
      } else {
        let separator = baseUrl.includes('?') ? '&' : '?';
        fullUrl = `${baseUrl}${separator}isbn=${isbn}`;
      }

      let headers: Record<string, string> = {
        'Content-Type': 'application/json'
      };
      if (this.customApiToken) {
        headers['X-API-Token'] = this.customApiToken;
      }

      httpRequest.request(
        fullUrl,
        {
          method: http.RequestMethod.GET,
          header: headers,
          connectTimeout: 8000,
          readTimeout: 8000
        },
        (err, data) => {
          if (!err && data.responseCode === 200) {
            try {
              const resObj = JSON.parse(data.result as string) as Record<string, Object>;
              const remoteCover = (resObj.cover as string) || '';
              this.downloadCover(isbn, remoteCover).then((localCover) => {
                const book = new BookItem(
                  (this.books.length + 1).toString(),
                  (resObj.title as string) || '未知书名',
                  (resObj.author as string) || '未知作者',
                  localCover,
                  this.getRandomColor(),
                  'unread',
                  (resObj.summary as string) || '暂无内容简介。',
                  (resObj.publisher as string) || '未知出版社',
                  (resObj.pubdate as string) || '--',
                  parseInt(resObj.pages as string) || (resObj.pages as number) || 0,
                  isbn,
                  '自建服务器'
                );
                resolve(book);
              }).catch(() => {
                resolve(null);
              });
              httpRequest.destroy();
              return;
            } catch (e) {
              console.error('自建服务器 JSON 解析报错: ' + JSON.stringify(e));
            }
          } else {
            console.error('自建服务器请求失败，状态码: ' + (data ? data.responseCode : 'none') + ', 错误: ' + JSON.stringify(err));
          }
          resolve(null);
          httpRequest.destroy();
        }
      );
    });
  }

  // 2. Query Google Books (returns Promise<BookItem | null>)
  queryGoogle(isbn: string): Promise<BookItem | null> {
    return new Promise((resolve) => {
      let httpRequest = http.createHttp();
      let url = `https://www.googleapis.com/books/v1/volumes?q=isbn:${isbn}`;
      httpRequest.request(
        url,
        {
          method: http.RequestMethod.GET,
          header: { 'Content-Type': 'application/json' },
          connectTimeout: 8000,
          readTimeout: 8000
        },
        (err, data) => {
          if (!err && data.responseCode === 200) {
            try {
              const resObj = JSON.parse(data.result as string) as Record<string, Object>;
              const items = resObj.items as Object[];
              if (items && items.length > 0) {
                const first = items[0] as Record<string, Object>;
                const volumeInfo = first.volumeInfo as Record<string, Object>;
                const title = volumeInfo.title as string;
                const authors = volumeInfo.authors as string[] || ['未知作者'];
                const desc = volumeInfo.description as string || '暂无内容简介。';
                const publisher = volumeInfo.publisher as string || '未知出版社';
                const publishedDate = volumeInfo.publishedDate as string || '--';
                const pageCount = volumeInfo.pageCount as number || 0;
                
                let remoteCover = '';
                if (volumeInfo.imageLinks && (volumeInfo.imageLinks as Record<string, string>).thumbnail) {
                  remoteCover = (volumeInfo.imageLinks as Record<string, string>).thumbnail;
                  if (remoteCover.startsWith('http://')) {
                    remoteCover = 'https://' + remoteCover.substring(7);
                  }
                }

                this.downloadCover(isbn, remoteCover).then((localCover) => {
                  const book = new BookItem(
                    (this.books.length + 1).toString(),
                    title,
                    authors.join(', '),
                    localCover,
                    this.getRandomColor(),
                    'unread',
                    desc,
                    publisher,
                    publishedDate,
                    pageCount,
                    isbn,
                    '网络录入(Google)'
                  );
                  resolve(book);
                }).catch(() => {
                  resolve(null);
                });
                httpRequest.destroy();
                return;
              }
            } catch (e) {
              console.error('Google parse error: ' + JSON.stringify(e));
            }
          }
          resolve(null);
          httpRequest.destroy();
        }
      );
    });
  }

  // Perform cascading multi-source network query
  async fetchBookDetails(isbn: string) {
    if (!isbn || isbn.length < 10) {
      promptAction.showToast({ message: '请输入有效的 10 位或 13 位 ISBN 码' });
      return;
    }

    this.isSearching = true;

    // Step 1: Custom Server API (if configured)
    if (this.customApiUrl) {
      promptAction.showToast({ message: '第一步：通过自建服务器查询...' });
      const book = await this.queryCustomServer(isbn);
      if (book) {
        this.pendingBook = book;
        this.showConfirmDialog = true;
        this.isSearching = false;
        return;
      }
    }

    // Step 2: Google Books API (free open backup)
    promptAction.showToast({ message: '第二步：通过 Google Books 查询...' });
    const gBook = await this.queryGoogle(isbn);
    if (gBook) {
      this.pendingBook = gBook;
      this.showConfirmDialog = true;
      this.isSearching = false;
      return;
    }

    // Both queries failed, inform the user and reset search state
    promptAction.showToast({ message: '未查询到该书籍详情' });
    this.isSearching = false;
    this.startScan();
  }

  // Get the last 10 scanned or added books (newest first)
  getScanHistory(): BookItem[] {
    const list = [...this.books];
    list.sort((a, b) => {
      if (a.addTime === b.addTime) {
        return parseInt(b.id) - parseInt(a.id);
      }
      return b.addTime.localeCompare(a.addTime);
    });
    return list.slice(0, 10);
  }

  // Confirm and add the pending book to library list
  confirmAddBook() {
    if (this.books.some(b => b.isbn === this.pendingBook.isbn)) {
      promptAction.showToast({
        message: `书籍《${this.pendingBook.title}》已在书房中，无需重复录入！`,
        duration: 2000
      });
      return;
    }
    this.books.push(this.pendingBook);
    promptAction.showToast({
      message: `《${this.pendingBook.title}》已成功加入书房！`,
      duration: 2000
    });

    this.startScan();
  }

  build() {
    Stack() {
      Column() {
        Scroll() {
          Column() {
            Text('扫码录入')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .margin({ top: 24, bottom: 20 })

            // Viewfinder Stack containing live camera feed
            Stack() {
              // 1. Live Camera Stream Component or Permission Placeholder
              if (this.hasCameraPermission) {
                XComponent({
                  id: 'scan_xcomponent',
                  type: XComponentType.SURFACE,
                  controller: this.mXComponentController
                })
                .onLoad(() => {
                  this.startScan();
                })
                .width('100%')
                .height('100%')
                .borderRadius(16)
              } else {
                Column() {
                  Image($r('app.media.ic_scan'))
                    .width(48)
                    .height(48)
                    .fillColor($r('app.color.text_secondary'))
                    .margin({ bottom: 12 })
                  Text('需开启相机权限以使用扫码功能')
                    .fontSize(11)
                    .fontColor($r('app.color.text_secondary'))
                    .margin({ bottom: 16 })
                  Button('开启权限')
                    .fontSize(11)
                    .height(28)
                    .backgroundColor($r('app.color.primary'))
                    .onClick(() => {
                      this.requestCameraPermission();
                    })
                }
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)
                .width('100%')
                .height('100%')
              }

              // 2. Border viewfinder overlay
              Column()
                .width(200)
                .height(200)
                .border({ width: 2, color: $r('app.color.primary'), radius: 16, style: BorderStyle.Dashed })

              // 3. Target scanning line
              Divider()
                .color('#FF4D4D')
                .strokeWidth(3)
                .width(170)
                .shadow({ radius: 4, color: '#40FF4D4D' })

              // 4. Instruction text overlay
              Text('将条形码/ISBN放入框内')
                .fontSize(11)
                .fontColor('#FFFFFF') // White text to stand out over camera stream
                .backgroundColor('#80000000') // Translucent black background
                .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                .borderRadius(8)
                .margin({ top: 100 })
            }
            .width(220)
            .height(220)
            .alignContent(Alignment.Center)
            .margin({ bottom: 24 })

            // Manual input test tool
            Row() {
              TextInput({ text: this.testIsbn, placeholder: '或在此处手动输入ISBN条码...' })
                .width(220)
                .height(40)
                .fontSize(12)
                .backgroundColor($r('app.color.card_bg'))
                .placeholderColor($r('app.color.text_secondary'))
                .borderRadius(8)
                .onChange((val: string) => {
                  this.testIsbn = val;
                })

              Button(this.isSearching ? '查询中' : '录入')
                .fontSize(12)
                .height(40)
                .fontWeight(FontWeight.Medium)
                .fontColor('#FFFFFF')
                .backgroundColor($r('app.color.primary'))
                .margin({ left: 12 })
                .onClick(() => {
                  if (this.isSearching) return;
                  if (this.testIsbn) {
                    this.stopScan();
                    this.fetchBookDetails(this.testIsbn);
                  } else {
                    promptAction.showToast({ message: '请输入ISBN码' });
                  }
                })
            }
            .margin({ bottom: 32 })

            // Recent Scanned / Added History list
            Row() {
              Text('最近录入')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
              Blank()
            }
            .width('100%')
            .padding({ left: 24, right: 24 })
            .margin({ bottom: 12 })

            if (this.getScanHistory().length === 0) {
              Text('暂无录入记录')
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .margin({ top: 16 })
            } else {
              Column() {
                ForEach(this.getScanHistory(), (item: BookItem) => {
                  Row() {
                    Image(item.cover)
                      .alt($r('app.media.cover_placeholder'))
                      .width(36)
                      .height(48)
                      .objectFit(ImageFit.Contain)
                      .backgroundColor(item.coverColor)
                      .borderRadius(4)
                      .margin({ right: 12 })

                    Column() {
                      Text(item.title)
                        .fontSize(13)
                        .fontWeight(FontWeight.Medium)
                        .fontColor($r('app.color.text_primary'))
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .margin({ bottom: 4 })
                      Text(`${item.author} | ${item.addTime.substring(0, 10)}`)
                        .fontSize(10)
                        .fontColor($r('app.color.text_secondary'))
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)

                    Image($r('app.media.ic_back'))
                      .width(16)
                      .height(16)
                      .rotate({ angle: 180 })
                      .fillColor($r('app.color.text_secondary'))
                      .opacity(0.5)
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16, top: 12, bottom: 12 })
                  .backgroundColor($r('app.color.card_bg'))
                  .borderRadius(12)
                  .margin({ bottom: 12 })
                  .shadow({ radius: 4, color: '#08000000', offsetY: 2 })
                }, (item: BookItem) => item.id)
              }
              .width('100%')
              .padding({ left: 24, right: 24 })
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.background'))

      // Custom Overlay Confirmation Dialog
      if (this.showConfirmDialog) {
        Column() {
          Column() {
            Text('扫描成功！是否加入书架？')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .margin({ bottom: 16 })

            // Book Cover Preview
            Column() {
              Image(this.pendingBook.cover)
                .alt($r('app.media.cover_placeholder'))
                .width(100)
                .height(130)
                .objectFit(ImageFit.Contain)
                .backgroundColor(this.pendingBook.coverColor)
                .borderRadius(8)
            }
            .margin({ bottom: 16 })

            Text(this.pendingBook.title)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .textAlign(TextAlign.Center)
              .margin({ bottom: 8 })

            Text(this.pendingBook.author)
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .margin({ bottom: 16 })
              
            Text(`出版社: ${this.pendingBook.publisher}`)
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .margin({ bottom: 4 })

            Text(`数据来源: ${this.pendingBook.category}`)
              .fontSize(12)
              .fontColor($r('app.color.primary'))
              .margin({ bottom: 16 })

            Text(this.pendingBook.summary)
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .lineHeight(18)
              .maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ bottom: 16 })

            // Book Category Selector (Standalone, Styled)
            Select(BOOK_CATEGORIES.map(cat => ({ value: cat } as SelectOption)))
              .value(BOOK_CATEGORIES.includes(this.pendingBook.category) ? this.pendingBook.category : '其他')
              .font({ size: 14, weight: FontWeight.Medium })
              .fontColor($r('app.color.primary'))
              .selectedOptionFont({ size: 14, weight: FontWeight.Medium })
              .optionFont({ size: 14 })
              .backgroundColor($r('app.color.primary_light'))
              .borderRadius(16)
              .height(32)
              .padding({ left: 16, right: 16, top: 2, bottom: 2 })
              .margin({ bottom: 20 })
              .onSelect((index: number, value: string) => {
                this.pendingBook.category = value;
              })

            // Action Buttons
            Row() {
              Button('取消')
                .width(100)
                .height(36)
                .fontSize(14)
                .fontColor($r('app.color.text_primary'))
                .backgroundColor($r('app.color.background'))
                .onClick(() => {
                  this.showConfirmDialog = false;
                  this.startScan();
                })
              
              Button('加入书房')
                .width(120)
                .height(36)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor('#FFFFFF')
                .backgroundColor($r('app.color.primary'))
                .onClick(() => {
                  this.showConfirmDialog = false;
                  this.confirmAddBook();
                })
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceEvenly)
            .margin({ top: 12 })
          }
          .width('85%')
          .padding(24)
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
    .width('100%')
    .height('100%')
  }
}
