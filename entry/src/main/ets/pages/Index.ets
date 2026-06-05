import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import http from '@ohos.net.http';
import dataPreferences from '@ohos.data.preferences';
import abilityAccessCtrl, { PermissionRequestResult } from '@ohos.abilityAccessCtrl';
import { common } from '@kit.AbilityKit';
import { customScan, scanBarcode, scanCore } from '@kit.ScanKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { BookItem, MOCK_BOOKS } from '../model/BookData';
import fs from '@ohos.file.fs';

@Entry
@Component
struct Index {
  @State books: BookItem[] = MOCK_BOOKS;
  @State searchText: string = '';
  @State filterStatus: string = 'all'; // 'all' | 'unread' | 'reading' | 'read'
  @State currentIndex: number = 0;
  @State customApiUrl: string = '';
  @State customApiToken: string = '';
  @State testIsbn: string = '';
  @State hasCameraPermission: boolean = false;
  @State isSearching: boolean = false;
  @State showConfirmDialog: boolean = false;
  @State pendingBook: BookItem = new BookItem('', '', '', $r('app.media.cover_placeholder'), '#5F8575', 'unread', '', '', '', 0, '', '');
  private tabsController: TabsController = new TabsController();
  private mXComponentController: XComponentController = new XComponentController();
  private cameraWidth: number = 1080;
  private cameraHeight: number = 1920;

  aboutToAppear() {
    this.loadServerConfigs();
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

  // Load user API configurations from preferences
  loadServerConfigs() {
    try {
      let pref = dataPreferences.getPreferencesSync(getContext(this), { name: 'myBookStorePrefs' });
      this.customApiUrl = pref.getSync('customApiUrl', '') as string;
      this.customApiToken = pref.getSync('customApiToken', '') as string;
    } catch (err) {
      console.error('Failed to load server configs: ' + JSON.stringify(err));
    }
  }

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

  // Helper method to filter books
  getFilteredBooks(): BookItem[] {
    return this.books.filter(book => {
      const matchesSearch = book.title.toLowerCase().includes(this.searchText.toLowerCase());
      const matchesFilter = this.filterStatus === 'all' || book.status === this.filterStatus;
      return matchesSearch && matchesFilter;
    });
  }

  // Get reading count stats
  getStats(status: string): number {
    return this.books.filter(b => b.status === status).length;
  }

  // Add book object to local store list
  addBookToStore(
    title: string,
    author: string,
    summary: string,
    publisher: string,
    publishDate: string,
    pages: number,
    isbn: string,
    category: string
  ) {
    const colors = ['#5F8575', '#4A6B82', '#BFA76F', '#2E3A3B', '#826C5F', '#7D6B88', '#7F5E5E', '#684C58'];
    const randomColor = colors[Math.floor(Math.random() * colors.length)];

    const newBook = new BookItem(
      (this.books.length + 1).toString(),
      title,
      author,
      $r('app.media.cover_placeholder'),
      randomColor,
      'unread',
      summary,
      publisher,
      publishDate,
      pages,
      isbn,
      category
    );

    this.books.push(newBook);
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

    // Auto navigate to library list tab
    this.currentIndex = 0;
    this.tabsController.changeIndex(0);
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

  // Finish search actions
  finishSearch() {
    this.isSearching = false;
    this.currentIndex = 0;
    this.tabsController.changeIndex(0);
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
    
    // If still on the scanner tab, restart scan for the next barcode
    if (this.currentIndex === 1) {
      this.startScan();
    }
  }

  @Builder TabBuilder(index: number, name: string, icon: Resource) {
    Column() {
      Image(icon)
        .width(22)
        .height(22)
        .margin({ bottom: 4 })
        .fillColor(this.currentIndex === index ? $r('app.color.primary') : $r('app.color.text_secondary'))
      Text(name)
        .fontSize(10)
        .fontColor(this.currentIndex === index ? $r('app.color.primary') : $r('app.color.text_secondary'))
        .fontWeight(this.currentIndex === index ? FontWeight.Medium : FontWeight.Normal)
    }
    .width('100%')
    .height(56)
    .justifyContent(FlexAlign.Center)
  }

  // Dropdown menu content builder
  @Builder FilterMenuBuilder() {
    Menu() {
      MenuItem({ content: '全部书籍' })
        .onClick(() => {
          this.filterStatus = 'all';
          promptAction.showToast({ message: '已筛选：全部书籍', duration: 1000 });
        })
      MenuItem({ content: '未读书籍' })
        .onClick(() => {
          this.filterStatus = 'unread';
          promptAction.showToast({ message: '已筛选：未读', duration: 1000 });
        })
      MenuItem({ content: '在读书籍' })
        .onClick(() => {
          this.filterStatus = 'reading';
          promptAction.showToast({ message: '已筛选：在读', duration: 1000 });
        })
      MenuItem({ content: '已读书籍' })
        .onClick(() => {
          this.filterStatus = 'read';
          promptAction.showToast({ message: '已筛选：已读', duration: 1000 });
        })
    }
  }

  // Individual Book Card builder
  @Builder BookCardBuilder(item: BookItem) {
    Column() {
      Stack({ alignContent: Alignment.TopEnd }) {
        // Geometric minimalist cover
        Column() {
          Image(item.cover)
            .alt($r('app.media.cover_placeholder'))
            .width('100%')
            .height(150)
            .objectFit(ImageFit.Contain)
            .backgroundColor(item.coverColor)
            .borderRadius({ topLeft: 12, topRight: 12 })
        }
        .width('100%')
        .height(150)

        // Reading Status Badge
        Text(item.status === 'read' ? '已读' : (item.status === 'reading' ? '在读' : '未读'))
          .fontSize(9)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
          .backgroundColor(
            item.status === 'read' ? $r('app.color.status_read') :
            (item.status === 'reading' ? $r('app.color.status_reading') : $r('app.color.status_unread'))
          )
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .borderRadius({ bottomLeft: 8, topRight: 12 })
      }
      .width('100%')
      .height(150)

      Column() {
        Text(item.title)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ bottom: 4 })

        Text(item.author)
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .padding(10)
      .alignItems(HorizontalAlign.Start)
    }
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(12)
    .shadow({ radius: 6, color: '#0F000000', offsetX: 0, offsetY: 3 })
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
          category: item.category
        }
      });
    })
  }

  // Tab 1: Book List View
  @Builder BookListTab() {
    Column() {
      // Header Search and Filter Bar
      Row() {
        Search({ value: this.searchText, placeholder: '搜索图书书名...' })
          .layoutWeight(1)
          .height(40)
          .backgroundColor($r('app.color.card_bg'))
          .placeholderColor($r('app.color.text_secondary'))
          .placeholderFont({ size: 14 })
          .textFont({ size: 14 })
          .borderRadius(20)
          .onChange((value: string) => {
            this.searchText = value;
          })

        // Filter Dropdown Trigger Button
        Row() {
          Image($r('app.media.ic_filter'))
            .width(22)
            .height(22)
            .fillColor($r('app.color.primary'))
        }
        .width(40)
        .height(40)
        .margin({ left: 12 })
        .borderRadius(20)
        .backgroundColor($r('app.color.card_bg'))
        .justifyContent(FlexAlign.Center)
        .bindMenu(this.FilterMenuBuilder())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      // Active filter indicator badge
      if (this.filterStatus !== 'all') {
        Row() {
          Text(`当前筛选: ${this.filterStatus === 'read' ? '已读' : (this.filterStatus === 'reading' ? '在读' : '未读')}`)
            .fontSize(12)
            .fontColor($r('app.color.primary'))
          Image($r('app.media.ic_back')) // reuse as close/back arrow
            .width(12)
            .height(12)
            .margin({ left: 4 })
            .rotate({ angle: 270 }) // make it face downward or look like action
            .fillColor($r('app.color.primary'))
        }
        .padding({ left: 10, right: 10, top: 4, bottom: 4 })
        .margin({ left: 16, bottom: 8 })
        .borderRadius(12)
        .backgroundColor($r('app.color.primary_light'))
        .onClick(() => {
          this.filterStatus = 'all';
        })
      }

      // Empty State
      if (this.getFilteredBooks().length === 0) {
        Column() {
          Image($r('app.media.cover_placeholder'))
            .width(80)
            .height(100)
            .margin({ bottom: 16 })
            .opacity(0.3)
          Text('书房里没有找到符合条件的书籍')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        // Book Grid
        Grid() {
          ForEach(this.getFilteredBooks(), (item: BookItem) => {
            GridItem() {
              this.BookCardBuilder(item)
            }
          }, (item: BookItem) => item.id)
        }
        .columnsTemplate('1fr 1fr')
        .columnsGap(14)
        .rowsGap(14)
        .padding({ left: 16, right: 16, bottom: 16 })
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }

  // Tab 2: Scan Add View Placeholder
  @Builder ScanTab() {
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
          .borderRadius(8)
          .margin({ left: 8 })
          .enabled(!this.isSearching)
          .onClick(() => {
            this.fetchBookDetails(this.testIsbn);
          })
      }
      .width('calc(100% - 32px)')
      .justifyContent(FlexAlign.Center)
      .margin({ bottom: 20 })

      Text('配置自建服务器API及密钥后，将优先通过您的服务器获取真实的图书详情。未配置则默认使用国外公开接口。')
        .fontSize(10)
        .fontColor($r('app.color.text_secondary'))
        .width('80%')
        .textAlign(TextAlign.Center)
        .lineHeight(14)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
  }

  // Tab 3: Personal Center View Placeholder
  @Builder ProfileTab() {
    Column() {
      // Profile Info Header
      Column() {
        Row() {
          Image($r('app.media.ic_user'))
            .width(64)
            .height(64)
            .fillColor($r('app.color.primary'))
            .margin({ right: 16 })

          Column() {
            Text('书房主人')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .margin({ bottom: 4 })
            Text('我的专属数字阅读空间')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
          }
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding(20)
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius(16)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 24, bottom: 16 })

      // Statistics Section
      Row() {
        Column() {
          Text(this.books.length.toString())
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.primary'))
            .margin({ bottom: 4 })
          Text('书房藏书')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1)

        Divider()
          .vertical(true)
          .height(24)
          .color($r('app.color.divider'))

        Column() {
          Text(this.getStats('reading').toString())
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.status_reading'))
            .margin({ bottom: 4 })
          Text('在读')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1)

        Divider()
          .vertical(true)
          .height(24)
          .color($r('app.color.divider'))

        Column() {
          Text(this.getStats('read').toString())
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.status_read'))
            .margin({ bottom: 4 })
          Text('已读')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1)
      }
      .width('calc(100% - 32px)')
      .margin({ left: 16, right: 16, bottom: 16 })
      .padding({ top: 16, bottom: 16 })
      .backgroundColor($r('app.color.card_bg'))
      .borderRadius(16)

      // Settings List Placeholder
      Column() {
        this.ProfileSettingItem('书房管理设置', '整理书籍与标签')
        Divider().color($r('app.color.divider')).margin({ left: 16, right: 16 })

        // Custom Server API configurations
        Column() {
          Row() {
            Column() {
              Text('自建服务器 API 地址')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
                .margin({ bottom: 2 })
              Text('优先调用的中转查询接口')
                .fontSize(10)
                .fontColor($r('app.color.text_secondary'))
            }
            .alignItems(HorizontalAlign.Start)

            Blank()

            TextInput({ text: this.customApiUrl, placeholder: '输入自建服务器接口' })
              .width(150)
              .height(36)
              .fontSize(11)
              .backgroundColor($r('app.color.background'))
              .borderRadius(6)
              .placeholderColor($r('app.color.text_secondary'))
              .onChange((val: string) => {
                this.customApiUrl = val;
                this.saveCustomApiUrl(val);
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 6 })

          Row() {
            Column() {
              Text('API 访问密钥 (Token)')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
                .margin({ bottom: 2 })
              Text('用于自建服务器安全校验')
                .fontSize(10)
                .fontColor($r('app.color.text_secondary'))
            }
            .alignItems(HorizontalAlign.Start)

            Blank()

            TextInput({ text: this.customApiToken, placeholder: 'API 校验密钥 Token' })
              .width(150)
              .height(36)
              .fontSize(11)
              .backgroundColor($r('app.color.background'))
              .borderRadius(6)
              .placeholderColor($r('app.color.text_secondary'))
              .onChange((val: string) => {
                this.customApiToken = val;
                this.saveCustomApiToken(val);
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 6, bottom: 12 })
        }

        Divider().color($r('app.color.divider')).margin({ left: 16, right: 16 })
        this.ProfileSettingItem('数据备份与同步', '备份书籍至云端')
        Divider().color($r('app.color.divider')).margin({ left: 16, right: 16 })
        this.ProfileSettingItem('关于 myBookStore', '版本 1.0.0 (支持自定义API)')
      }
      .width('calc(100% - 32px)')
      .margin({ left: 16, right: 16 })
      .backgroundColor($r('app.color.card_bg'))
      .borderRadius(16)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }

  @Builder ProfileSettingItem(title: string, desc: string) {
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
    .padding(16)
    .onClick(() => {
      promptAction.showToast({ message: `点击了: ${title} (此项暂未开放)`, duration: 1500 });
    })
  }

  // App entry container build
  build() {
    Stack() {
      Column() {
        // Bottom Navigation Tabs
        Tabs({ barPosition: BarPosition.End, controller: this.tabsController }) {
          TabContent() {
            this.BookListTab()
          }
          .tabBar(this.TabBuilder(0, '图书', $r('app.media.ic_book_list')))

          TabContent() {
            this.ScanTab()
          }
          .tabBar(this.TabBuilder(1, '扫码录入', $r('app.media.ic_scan')))

          TabContent() {
            this.ProfileTab()
          }
          .tabBar(this.TabBuilder(2, '我', $r('app.media.ic_user')))
        }
        .width('100%')
        .height('100%')
        .onChange((index: number) => {
          this.currentIndex = index;
          if (index === 1) {
            let hasPermission = this.checkCameraPermission();
            if (hasPermission) {
              this.hasCameraPermission = true;
            } else {
              this.requestCameraPermission();
            }
          } else {
            this.stopScan();
            this.hasCameraPermission = false;
          }
        })
        .backgroundColor($r('app.color.card_bg'))
      }
      .width('100%')
      .height('100%')

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
            .shadow({ radius: 4, color: '#20000000', offsetY: 2 })
            .margin({ bottom: 16 })

            // Book Title
            Text(this.pendingBook.title)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ bottom: 6 })

            // Book Author
            Text(this.pendingBook.author)
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ bottom: 20 })

            // Action Buttons
            Row() {
              Button('取消')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_secondary'))
                .backgroundColor('#F0F0F0')
                .height(40)
                .layoutWeight(1)
                .margin({ right: 12 })
                .onClick(() => {
                  this.showConfirmDialog = false;
                  // If still on scan tab, restart scanner
                  if (this.currentIndex === 1) {
                    this.startScan();
                  }
                })

              Button('确认加入')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor('#FFFFFF')
                .backgroundColor($r('app.color.primary'))
                .height(40)
                .layoutWeight(1)
                .onClick(() => {
                  this.showConfirmDialog = false;
                  this.confirmAddBook();
                })
            }
            .width('100%')
          }
          .width(280)
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
