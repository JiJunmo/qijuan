import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { BookItem, BOOK_CATEGORIES } from '../model/BookData';
import { NoteItem } from '../model/NoteData';

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
  addTime?: string;
}

@Component
struct MetaItem {
  @Prop label: string;
  @Prop value: string;

  build() {
    Row() {
      Text(this.label)
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .width(80)
      Text(this.value)
        .fontSize(13)
        .fontColor($r('app.color.text_primary'))
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
    }
    .width('100%')
    .margin({ bottom: 10 })
  }
}

@Entry
@Component
struct BookDetail {
  @StorageLink('globalBooks') globalBooks: BookItem[] = [];
  @StorageLink('globalNotes') globalNotes: NoteItem[] = [];
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
  @State addTime: string = '';
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
      this.addTime = params.addTime || '';
    }
  }

  getBookNotes(): NoteItem[] {
    return this.globalNotes.filter(n => n.bookId === this.bookId);
  }

  // Update book status interactively
  updateStatus(newStatus: 'unread' | 'reading' | 'read') {
    this.status = newStatus;
    const index = this.globalBooks.findIndex(b => b.id === this.bookId);
    if (index >= 0) {
      this.globalBooks[index].status = newStatus;
      this.globalBooks = [...this.globalBooks];
    }
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
          this.globalBooks = this.globalBooks.filter(b => b.id !== this.bookId);
          router.back();
          promptAction.showToast({
            message: `《${this.title}》已成功从书架移除`,
            duration: 2000
          });
        }
      }
    });
  }

  showCategoryPicker() {
    TextPickerDialog.show({
      range: BOOK_CATEGORIES,
      selected: BOOK_CATEGORIES.indexOf(this.category) >= 0 ? BOOK_CATEGORIES.indexOf(this.category) : BOOK_CATEGORIES.indexOf('其他'),
      onAccept: (value: TextPickerResult) => {
        if (value.value) {
          let selectedValue = Array.isArray(value.value) ? value.value[0] : value.value;
          this.category = selectedValue as string;
          const index = this.globalBooks.findIndex(b => b.id === this.bookId);
          if (index >= 0) {
            this.globalBooks[index].category = this.category;
            this.globalBooks = [...this.globalBooks];
          }
          promptAction.showToast({ message: `分类已修改为: ${this.category}`, duration: 1500 });
        }
      }
    });
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
          router.back();
        })

        Text('图书详情')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .margin({ left: 8 })

        Blank()

        Image($r('app.media.ic_more'))
          .width(20)
          .height(20)
          .fillColor($r('app.color.text_primary'))
          .bindMenu([
            {
              value: '修改分类',
              action: () => {
                this.showCategoryPicker();
              }
            },
            {
              value: '从书架删除',
              action: () => {
                this.confirmDeleteBook();
              }
            }
          ])
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

            MetaItem({ label: '图书分类', value: this.category })
            MetaItem({ label: '出版社', value: this.publisher })
            MetaItem({ label: '出版日期', value: this.publishDate })
            MetaItem({ label: '书籍页数', value: `${this.pages} 页` })
            MetaItem({ label: 'ISBN 编码', value: this.isbn })
            MetaItem({ label: '藏书时间', value: this.addTime })
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

          // Book Notes Section
          Column() {
            Row() {
              Text('关联读书笔记')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
              Blank()
              Button('+ 新建笔记')
                .fontSize(12)
                .height(28)
                .backgroundColor('#E8EAE8')
                .fontColor($r('app.color.primary'))
                .onClick(() => {
                  router.pushUrl({
                    url: 'pages/NoteEditor',
                    params: { bookId: this.bookId }
                  });
                })
            }
            .width('100%')
            .margin({ bottom: 12 })

            if (this.getBookNotes().length === 0) {
              Text('暂无笔记，您可以在“笔记”Tab中新建并关联到此书。')
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))
                .fontStyle(FontStyle.Italic)
                .padding(16)
            } else {
              ForEach(this.getBookNotes(), (note: NoteItem) => {
                Row() {
                  Column() {
                    Text(note.title)
                      .fontSize(14)
                      .fontWeight(FontWeight.Bold)
                      .fontColor($r('app.color.text_primary'))
                      .margin({ bottom: 4 })
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(note.updateTime)
                      .fontSize(11)
                      .fontColor($r('app.color.text_secondary'))
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)

                  Image($r('app.media.ic_more'))
                    .width(16)
                    .height(16)
                    .fillColor($r('app.color.text_secondary'))
                }
                .width('100%')
                .padding(12)
                .backgroundColor('#F5F7F8')
                .borderRadius(8)
                .margin({ bottom: 8 })
                .onClick(() => {
                  router.pushUrl({
                    url: 'pages/NoteEditor',
                    params: { noteItem: note }
                  });
                })
              }, (note: NoteItem) => note.id)
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(16)
          .alignItems(HorizontalAlign.Start)
          .margin({ bottom: 30 })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }
}
