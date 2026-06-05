import router from '@ohos.router';
import promptAction from '@ohos.promptAction';

interface RouteParams {
  id?: string;
  title?: string;
  author?: string;
  cover?: string | Resource;
  coverColor?: string;
  status?: 'unread' | 'reading' | 'read';
  summary?: string;
  publisher?: string;
  publishDate?: string;
  pages?: number;
  isbn?: string;
  category?: string;
}

@Entry
@Component
struct BookDetail {
  @State bookId: string = '';
  @State title: string = '未知图书';
  @State author: string = '未知作者';
  @State cover: string | Resource = $r('app.media.cover_placeholder');
  @State coverColor: string = '#5F8575';
  @State status: 'unread' | 'reading' | 'read' = 'unread';
  @State summary: string = '';
  @State publisher: string = '';
  @State publishDate: string = '';
  @State pages: number = 0;
  @State isbn: string = '';
  @State category: string = '';
  @State userNote: string = '';

  aboutToAppear() {
    const params = router.getParams() as RouteParams;
    if (params) {
      this.bookId = params.id || '';
      this.title = params.title || '未知图书';
      this.author = params.author || '未知作者';
      this.cover = params.cover || $r('app.media.cover_placeholder');
      this.coverColor = params.coverColor || '#5F8575';
      this.status = params.status || 'unread';
      this.summary = params.summary || '暂无简介。';
      this.publisher = params.publisher || '未知出版社';
      this.publishDate = params.publishDate || '--';
      this.pages = params.pages || 0;
      this.isbn = params.isbn || '--';
      this.category = params.category || '未分类';
    }
  }

  // Update book status interactively
  updateStatus(newStatus: 'unread' | 'reading' | 'read') {
    this.status = newStatus;
    const statusText = newStatus === 'read' ? '已读' : (newStatus === 'reading' ? '在读' : '未读');
    promptAction.showToast({
      message: `状态已成功更新为：${statusText}`,
      duration: 1500
    });
  }

  confirmDeleteBook() {
    AlertDialog.show({
      title: '删除书籍',
      message: `确定要将《${this.title}》从书架删除吗？删除后将无法恢复。`,
      autoCancel: true,
      alignment: DialogAlignment.Bottom,
      gridCount: 4,
      offset: { dx: 0, dy: -20 },
      primaryButton: {
        value: '取消',
        action: () => {
          console.info('Delete canceled');
        }
      },
      secondaryButton: {
        value: '确认删除',
        fontColor: '#D32F2F',
        action: () => {
          router.back({
            url: 'pages/Index',
            params: {
              deleteBookId: this.bookId
            }
          });
          promptAction.showToast({
            message: `《${this.title}》已成功从书架移除`,
            duration: 2000
          });
        }
      }
    });
  }

  @Builder MetaRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .width(80)
      Text(value)
        .fontSize(13)
        .fontColor($r('app.color.text_primary'))
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
    }
    .width('100%')
    .margin({ bottom: 10 })
  }

  @Builder StatusChip(targetStatus: 'unread' | 'reading' | 'read', label: string) {
    Text(label)
      .fontSize(12)
      .fontWeight(this.status === targetStatus ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.status === targetStatus ? '#FFFFFF' : $r('app.color.text_secondary'))
      .backgroundColor(
        this.status === targetStatus ?
        (targetStatus === 'read' ? $r('app.color.status_read') :
         (targetStatus === 'reading' ? $r('app.color.status_reading') : $r('app.color.status_unread')))
        : $r('app.color.primary_light')
      )
      .padding({ left: 16, right: 16, top: 6, bottom: 6 })
      .borderRadius(14)
      .margin({ right: 10 })
      .onClick(() => {
        this.updateStatus(targetStatus);
      })
  }

  build() {
    Column() {
      // Custom Navigation Bar
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
          router.back({
            url: 'pages/Index',
            params: {
              updatedBookId: this.bookId,
              updatedStatus: this.status
            }
          });
        })

        Text('图书详情')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .margin({ left: 8 })

        Image($r('app.media.ic_more'))
          .width(20)
          .height(20)
          .margin({ left: 8 })
          .fillColor($r('app.color.text_primary'))
          .bindMenu([
            {
              value: '从书架删除',
              action: () => {
                this.confirmDeleteBook();
              }
            }
          ])

        Blank()
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 16 })
      .backgroundColor($r('app.color.card_bg'))

      // Main Content Scroll Container
      Scroll() {
        Column() {
          // Book Hero Cover Panel
          Column() {
            Column() {
              Image(this.cover)
                .alt($r('app.media.cover_placeholder'))
                .width('100%')
                .height('100%')
                .objectFit(ImageFit.Contain)
            }
            .width(140)
            .height(190)
            .backgroundColor(this.coverColor)
            .borderRadius(12)
            .shadow({ radius: 10, color: '#1F000000', offsetX: 0, offsetY: 5 })
            .margin({ top: 20, bottom: 16 })

            Text(this.title)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .textAlign(TextAlign.Center)
              .margin({ bottom: 6 })

            Text(this.author)
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .textAlign(TextAlign.Center)
              .margin({ bottom: 20 })

            // Interactive Status Selector Rows
            Row() {
              this.StatusChip('unread', '未读')
              this.StatusChip('reading', '在读')
              this.StatusChip('read', '已读')
            }
            .margin({ bottom: 10 })
          }
          .width('100%')
          .padding(20)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(16)
          .margin({ bottom: 16 })

          // Book Meta Information Section
          Column() {
            Text('书籍信息')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .margin({ bottom: 12 })

            this.MetaRow('图书分类', this.category)
            this.MetaRow('出版社', this.publisher)
            this.MetaRow('出版日期', this.publishDate)
            this.MetaRow('书籍页数', `${this.pages} 页`)
            this.MetaRow('ISBN 编码', this.isbn)
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(16)
          .alignItems(HorizontalAlign.Start)
          .margin({ bottom: 16 })

          // Book Summary Section
          Column() {
            Text('内容简介')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .margin({ bottom: 8 })

            Text(this.summary)
              .fontSize(13)
              .fontColor($r('app.color.text_primary'))
              .lineHeight(20)
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(16)
          .alignItems(HorizontalAlign.Start)
          .margin({ bottom: 16 })

          // Book Notes Section (Interactive edit)
          Column() {
            Text('我的读书笔记')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .margin({ bottom: 8 })

            TextArea({
              placeholder: '在此输入您的阅读笔记或想法，感悟随心记...',
              text: this.userNote
            })
              .placeholderColor($r('app.color.text_secondary'))
              .placeholderFont({ size: 13 })
              .fontSize(13)
              .fontColor($r('app.color.text_primary'))
              .backgroundColor($r('app.color.background'))
              .borderRadius(8)
              .height(100)
              .width('100%')
              .onChange((val: string) => {
                this.userNote = val;
              })
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(16)
          .alignItems(HorizontalAlign.Start)
          .margin({ bottom: 30 })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }
}
