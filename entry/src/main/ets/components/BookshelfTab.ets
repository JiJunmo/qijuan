import { BookItem } from '../model/BookData';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';

@Component
export struct BookshelfTab {
  @Link books: BookItem[];
  @Link searchText: string;
  @Link filterStatus: string;

  // Helper method to filter books
  getFilteredBooks(): BookItem[] {
    return this.books.filter(book => {
      let matchStatus = this.filterStatus === 'all' || book.status === this.filterStatus;
      let matchSearch = book.title.toLowerCase().includes(this.searchText.toLowerCase()) ||
                        book.author.toLowerCase().includes(this.searchText.toLowerCase());
      return matchStatus && matchSearch;
    });
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
          category: item.category,
          addTime: item.addTime
        }
      });
    })
  }

  build() {
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
          Text(this.books.length === 0 ? '可以录入您的书籍了' : '书房里没有找到符合条件的书籍')
            .fontSize(this.books.length === 0 ? 18 : 14)
            .fontWeight(this.books.length === 0 ? FontWeight.Medium : FontWeight.Normal)
            .fontStyle(this.books.length === 0 ? FontStyle.Italic : FontStyle.Normal)
            .letterSpacing(this.books.length === 0 ? 1 : 0)
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
          }, (item: BookItem) => item.id + '_' + item.status + '_' + item.category)
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
}
