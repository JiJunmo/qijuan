import { BookItem, BOOK_CATEGORIES } from '../model/BookData';
import promptAction from '@ohos.promptAction';
import abilityAccessCtrl, { PermissionRequestResult } from '@ohos.abilityAccessCtrl';
import { common } from '@kit.AbilityKit';
import { customScan, scanBarcode, scanCore } from '@kit.ScanKit';
import { BusinessError } from '@kit.BasicServicesKit';
import http from '@ohos.net.http';
import fs from '@ohos.file.fs';
import router from '@ohos.router';
import picker from '@ohos.file.picker';

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
  @State showNoApiDialog: boolean = false;
  @State showManualEntryDialog: boolean = false;
  @State pendingBook: BookItem = new BookItem('', '', '', $r('app.media.cover_placeholder'), '#5F8575', 'unread', '', '', '', 0, '', '');

  // Manual entry form fields
  @State manualTitle: string = '';
  @State manualAuthor: string = '';
  @State manualPublisher: string = '';
  @State manualIsbn: string = '';
  @State manualPages: string = '';
  @State manualSummary: string = '';
  @State manualCover: string = '';

  private mXComponentController: XComponentController = new XComponentController();
  private cameraWidth: number = 1080;
  private cameraHeight: number = 1920;
  private isScanning: boolean = false;

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
        // startScan is handled by XComponent onLoad
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
    if (this.isScanning) return;
    try {
      let surfaceId: string = this.mXComponentController.getXComponentSurfaceId();
      if (!surfaceId) return;

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
      this.isScanning = true;
      customScan.start(viewControl).then((scanResult: Array<scanBarcode.ScanResult>) => {
        if (scanResult && scanResult.length > 0) {
          let isbn = scanResult[0].originalValue;
          promptAction.showToast({ message: `扫码成功: ${isbn}` });
          this.stopScan();
          this.fetchBookDetails(isbn);
        }
      }).catch((error: BusinessError) => {
        console.error(`customScan.start Promise failed: ${error.code}, ${error.message}`);
        this.isScanning = false;
      });
    } catch (error) {
      const err = error as BusinessError;
      console.error(`customScan start calling error: ${err.code}, ${err.message}`);
      this.isScanning = false;
    }
  }

  // Stop custom scan and release resources
  stopScan() {
    if (!this.isScanning) return;
    try {
      customScan.stop();
      customScan.release();
    } catch (error) {
      console.error('customScan stop/release error: ' + JSON.stringify(error));
    } finally {
      this.isScanning = false;
    }
  }

  // Select local image
  async selectCoverImage() {
    try {
      let photoPicker = new picker.PhotoViewPicker();
      let options = new picker.PhotoSelectOptions();
      options.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;

      let photoSelectResult = await photoPicker.select(options);
      if (photoSelectResult && photoSelectResult.photoUris && photoSelectResult.photoUris.length > 0) {
        let uri = photoSelectResult.photoUris[0];
        let context = getContext(this) as common.UIAbilityContext;
        
        let file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
        let destPath = context.filesDir + '/cover_local_' + Date.now() + '.jpg';
        fs.copyFileSync(file.fd, destPath);
        fs.closeSync(file);

        this.manualCover = 'file://' + destPath;
      }
    } catch (err) {
      console.error('Failed to select cover image: ' + JSON.stringify(err));
      promptAction.showToast({ message: '选择图片失败' });
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

  // Perform cascading multi-source network query
  async fetchBookDetails(isbn: string) {
    if (!isbn || isbn.length < 10) {
      promptAction.showToast({ message: '请输入有效的 10 位或 13 位 ISBN 码' });
      return;
    }

    this.isSearching = true;

    // Custom Server API (if configured)
    if (this.customApiUrl) {
      promptAction.showToast({ message: '正在查询...' });
      const book = await this.queryCustomServer(isbn);
      if (book) {
        this.pendingBook = book;
        this.showConfirmDialog = true;
        this.isSearching = false;
        return;
      }
    }

    // Failed to query or API not configured
    this.isSearching = false;
    this.manualIsbn = isbn; // prefill ISBN for manual entry
    this.showNoApiDialog = true;
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

            // Manual input test tool and Direct Manual Entry
            Column() {
              Row() {
                TextInput({ text: this.testIsbn, placeholder: '或在此处手动输入ISBN条码...' })
                  .layoutWeight(1)
                  .height(40)
                  .fontSize(12)
                  .backgroundColor($r('app.color.card_bg'))
                  .placeholderColor($r('app.color.text_secondary'))
                  .borderRadius(8)
                  .onChange((val: string) => {
                    this.testIsbn = val;
                  })

                Button(this.isSearching ? '查询中' : '查询并录入')
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
              .width('100%')
              .padding({ left: 24, right: 24 })
              .margin({ bottom: 12 })

              // Direct Manual Entry Button
              Button('跳过条码，直接手动填写书籍信息')
                .fontSize(12)
                .height(36)
                .fontColor($r('app.color.primary'))
                .backgroundColor('transparent')
                .border({ width: 1, color: $r('app.color.primary'), radius: 18 })
                .padding({ left: 16, right: 16 })
                .onClick(() => {
                  this.stopScan();
                  this.manualTitle = '';
                  this.manualAuthor = '';
                  this.manualPublisher = '';
                  this.manualIsbn = this.testIsbn || '';
                  this.manualPages = '';
                  this.manualSummary = '';
                  this.manualCover = '';
                  this.showManualEntryDialog = true;
                })
            }
            .width('100%')
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
              Column() {
                Text('可以录入您的书籍了')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_secondary'))
                  .fontStyle(FontStyle.Italic)
                  .letterSpacing(1)
                  .margin({ top: 32 })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Center)
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
                  .onClick(() => {
                    router.pushUrl({
                      url: 'pages/BookDetail',
                      params: {
                        id: item.id,
                        title: item.title,
                        author: item.author,
                        cover: item.cover,
                        coverColor: item.coverColor,
                        status: item.status,
                        summary: item.summary,
                        publisher: item.publisher,
                        publishDate: item.publishDate,
                        pages: item.pages,
                        isbn: item.isbn,
                        category: item.category,
                        addTime: item.addTime
                      }
                    });
                  })
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

      // No API Configured Dialog
      if (this.showNoApiDialog) {
        Column() {
          Column() {
            Text('未查询到数据')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .margin({ bottom: 16 })
            
            Text('未查询到相关书籍信息。本应用目前处于内测邀请阶段，如需使用云端扫码录入功能，请通过设置页面联系开发者邮箱获取专属邀请码，配置后即可直接获取图书信息。')
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .lineHeight(18)
              .margin({ bottom: 20 })

            Row() {
              Button('关闭')
                .width(100)
                .height(36)
                .fontSize(14)
                .fontColor($r('app.color.text_primary'))
                .backgroundColor($r('app.color.background'))
                .onClick(() => {
                  this.showNoApiDialog = false;
                  this.startScan();
                })
              
              Button('手动填写录入')
                .width(120)
                .height(36)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor('#FFFFFF')
                .backgroundColor($r('app.color.primary'))
                .onClick(() => {
                  this.showNoApiDialog = false;
                  this.manualTitle = '';
                  this.manualAuthor = '';
                  this.manualPublisher = '';
                  this.manualPages = '';
                  this.manualSummary = '';
                  this.manualIsbn = '';
                  this.manualCover = '';
                  this.showManualEntryDialog = true;
                })
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceEvenly)
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

      // Manual Entry Dialog
      if (this.showManualEntryDialog) {
        Column() {
          Column() {
            Text('手动录入书籍')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .margin({ bottom: 16 })
            
            Scroll() {
              Column() {
                // Cover preview / selection area
                Row() {
                  if (this.manualCover) {
                    Image(this.manualCover)
                      .width(80)
                      .height(110)
                      .objectFit(ImageFit.Cover)
                      .borderRadius(8)
                      .onClick(() => {
                        this.selectCoverImage();
                      })
                  } else {
                    Column() {
                      Text('+')
                        .fontSize(24)
                        .fontColor($r('app.color.text_secondary'))
                        .margin({ bottom: 4 })
                      Text('添加封面')
                        .fontSize(12)
                        .fontColor($r('app.color.text_secondary'))
                    }
                    .width(80)
                    .height(110)
                    .backgroundColor('#F0F0F0')
                    .borderRadius(8)
                    .justifyContent(FlexAlign.Center)
                    .onClick(() => {
                      this.selectCoverImage();
                    })
                  }
                }
                .width('100%')
                .justifyContent(FlexAlign.Center)
                .margin({ bottom: 16 })

                TextInput({ text: this.manualTitle, placeholder: '书籍名称 (必填)' })
                  .height(40).fontSize(14).margin({ bottom: 12 })
                  .onChange((val: string) => this.manualTitle = val)
                
                TextInput({ text: this.manualAuthor, placeholder: '作者 (选填)' })
                  .height(40).fontSize(14).margin({ bottom: 12 })
                  .onChange((val: string) => this.manualAuthor = val)

                TextInput({ text: this.manualPublisher, placeholder: '出版社 (选填)' })
                  .height(40).fontSize(14).margin({ bottom: 12 })
                  .onChange((val: string) => this.manualPublisher = val)

                TextInput({ text: this.manualIsbn, placeholder: 'ISBN (选填)' })
                  .height(40).fontSize(14).margin({ bottom: 12 })
                  .onChange((val: string) => this.manualIsbn = val)

                TextInput({ text: this.manualPages, placeholder: '页数 (选填)' })
                  .height(40).fontSize(14).margin({ bottom: 12 }).type(InputType.Number)
                  .onChange((val: string) => this.manualPages = val)

                TextArea({ text: this.manualSummary, placeholder: '内容简介 (选填)' })
                  .height(80).fontSize(14).margin({ bottom: 16 })
                  .onChange((val: string) => this.manualSummary = val)
              }
              .width('100%')
            }
            .height(300)
            .scrollBar(BarState.Off)
            .margin({ bottom: 12 })

            Row() {
              Button('取消')
                .width(100)
                .height(36)
                .fontSize(14)
                .fontColor($r('app.color.text_primary'))
                .backgroundColor($r('app.color.background'))
                .onClick(() => {
                  this.showManualEntryDialog = false;
                  this.startScan();
                })
              
              Button('保存录入')
                .width(120)
                .height(36)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor('#FFFFFF')
                .backgroundColor($r('app.color.primary'))
                .onClick(() => {
                  if (!this.manualTitle.trim()) {
                    promptAction.showToast({ message: '请输入书籍名称' });
                    return;
                  }
                  
                  const book = new BookItem(
                    (this.books.length + 1).toString(),
                    this.manualTitle.trim(),
                    this.manualAuthor.trim() || '未知作者',
                    this.manualCover || $r('app.media.cover_placeholder'), // local URI or default
                    this.getRandomColor(),
                    'unread',
                    this.manualSummary.trim() || '暂无内容简介。',
                    this.manualPublisher.trim() || '未知出版社',
                    '--', // default pub date
                    parseInt(this.manualPages) || 0,
                    this.manualIsbn.trim() || '',
                    '手动录入'
                  );
                  
                  this.pendingBook = book;
                  this.confirmAddBook(); // uses pendingBook
                  this.showManualEntryDialog = false;
                })
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceEvenly)
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
