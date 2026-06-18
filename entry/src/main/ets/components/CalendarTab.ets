import router from '@ohos.router';
import { BookItem } from '../model/BookData';
import { ReadingSession } from '../model/ReadingSessionData';
import { NoteItem } from '../model/NoteData';

class ReadBookInfo {
  book: BookItem;
  duration: number;
  constructor(book: BookItem, duration: number) {
    this.book = book;
    this.duration = duration;
  }
}

@Component
export struct CalendarTab {
  @StorageLink('globalBooks') books: BookItem[] = [];
  @StorageLink('globalReadingSessions') readingSessions: ReadingSession[] = [];
  @StorageLink('globalNotes') notes: NoteItem[] = [];

  @State currentYear: number = new Date().getFullYear();
  @State currentMonth: number = new Date().getMonth() + 1; // 1-12
  @State selectedDate: Date = new Date(); // Defaults to today
  
  // Date format utility
  formatDateStr(y: number, m: number, d: number): string {
    const pad = (n: number) => n < 10 ? '0' + n : n.toString();
    return `${y}-${pad(m)}-${pad(d)}`;
  }

  // Get total days in month
  getDaysInMonth(year: number, month: number): number {
    return new Date(year, month, 0).getDate();
  }

  // Get start weekday of month (0 = Sunday, 1 = Monday ...)
  getStartWeekday(year: number, month: number): number {
    return new Date(year, month - 1, 1).getDay();
  }

  // Calculate daily reading duration in minutes
  getDailyDuration(dateStr: string): number {
    let totalSeconds = 0;
    const startOfDay = new Date(dateStr + 'T00:00:00').getTime();
    const endOfDay = startOfDay + 24 * 60 * 60 * 1000;
    
    this.readingSessions.forEach(session => {
      if (session.startTime >= startOfDay && session.startTime < endOfDay) {
        totalSeconds += session.duration;
      }
    });
    return Math.floor(totalSeconds / 60);
  }

  // Map duration to color
  getHeatColor(durationMinutes: number): ResourceColor {
    if (durationMinutes === 0) return '#FFFFFF';
    if (durationMinutes <= 30) return '#C8E6C9'; 
    if (durationMinutes <= 60) return '#81C784'; 
    if (durationMinutes <= 120) return '#4CAF50'; 
    return '#2E7D32'; 
  }

  // Get books read on selected date
  getBooksReadOnSelectedDate(): ReadBookInfo[] {
    const dateStr = this.formatDateStr(this.selectedDate.getFullYear(), this.selectedDate.getMonth() + 1, this.selectedDate.getDate());
    const startOfDay = new Date(dateStr + 'T00:00:00').getTime();
    const endOfDay = startOfDay + 24 * 60 * 60 * 1000;

    let bookDurations: Record<string, number> = {};
    this.readingSessions.forEach(session => {
      if (session.startTime >= startOfDay && session.startTime < endOfDay) {
        if (!bookDurations[session.bookId]) {
          bookDurations[session.bookId] = 0;
        }
        bookDurations[session.bookId] += session.duration;
      }
    });

    let result: ReadBookInfo[] = [];
    Object.keys(bookDurations).forEach(bookId => {
      const book = this.books.find(b => b.id === bookId);
      if (book) {
        result.push(new ReadBookInfo(book, Math.floor(bookDurations[bookId] / 60)));
      }
    });
    return result;
  }

  // Get notes for selected date
  getNotesOnSelectedDate(): NoteItem[] {
    let y = this.selectedDate.getFullYear();
    let m = this.selectedDate.getMonth() + 1;
    let d = this.selectedDate.getDate();
    let pad = (n: number) => n < 10 ? '0' + n : n.toString();
    
    let str1 = `${y}-${pad(m)}-${pad(d)}`; // 2026-06-09
    let str2 = `${y}/${m}/${d}`;           // 2026/6/9
    let str3 = `${y}/${pad(m)}/${pad(d)}`; // 2026/06/09
    let str4 = `${y}年${m}月${d}日`;       // 2026年6月9日
    let str5 = `${m}/${d}/${y}`;           // 6/9/2026
    let str6 = `${pad(m)}/${pad(d)}/${y}`; // 06/09/2026

    return this.notes.filter(n => {
      if (!n.updateTime) return false;
      let ut = n.updateTime;
      return ut.includes(str1) || ut.includes(str2) || ut.includes(str3) || 
             ut.includes(str4) || ut.includes(str5) || ut.includes(str6);
    });
  }

  changeMonth(delta: number) {
    let newMonth = this.currentMonth + delta;
    let newYear = this.currentYear;
    if (newMonth < 1) {
      newMonth = 12;
      newYear -= 1;
    } else if (newMonth > 12) {
      newMonth = 1;
      newYear += 1;
    }
    this.currentYear = newYear;
    this.currentMonth = newMonth;
  }


  getCellsArray(): number[] {
    let daysInMonth = this.getDaysInMonth(this.currentYear, this.currentMonth);
    let startWeekday = this.getStartWeekday(this.currentYear, this.currentMonth);
    let totalCells = daysInMonth + startWeekday;
    let rows = Math.ceil(totalCells / 7);
    let cells: number[] = [];
    for (let i = 0; i < rows * 7; i++) {
      cells.push(i);
    }
    return cells;
  }

  @Builder
  DayCell(day: number) {
    Column() {
      Text(day.toString())
        .fontSize(14)
        .fontColor(this.getDailyDuration(this.formatDateStr(this.currentYear, this.currentMonth, day)) > 60 ? '#FFFFFF' : '#333333')
    }
    .width('100%')
    .aspectRatio(1)
    .backgroundColor(this.getHeatColor(this.getDailyDuration(this.formatDateStr(this.currentYear, this.currentMonth, day))))
    .borderRadius(8)
    .justifyContent(FlexAlign.Center)
    .borderWidth((this.selectedDate.getFullYear() === this.currentYear && this.selectedDate.getMonth() + 1 === this.currentMonth && this.selectedDate.getDate() === day) ? 2 : 0)
    .borderColor($r('app.color.primary'))
    .onClick(() => {
      this.selectedDate = new Date(this.currentYear, this.currentMonth - 1, day);
    })
  }

  @Builder
  CalendarGrid() {
    Column() {
      // Weekday headers
      Row() {
        ForEach(['日', '一', '二', '三', '四', '五', '六'], (day: string) => {
          Text(day)
            .fontSize(12)
            .fontColor('#888888')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
        })
      }.width('100%').margin({ bottom: 8 })

      // Grid
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
        ForEach(this.getCellsArray(), (index: number) => {
          Column() {
            if (index >= this.getStartWeekday(this.currentYear, this.currentMonth) && index < this.getStartWeekday(this.currentYear, this.currentMonth) + this.getDaysInMonth(this.currentYear, this.currentMonth)) {
              this.DayCell(index - this.getStartWeekday(this.currentYear, this.currentMonth) + 1)
            } else {
              Column().width('100%').aspectRatio(1) // Empty cell
            }
          }
          .width('13%')
          .margin({ bottom: 8 })
        })
      }
      .width('100%')
    }
    .padding(16)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
    .shadow({ radius: 6, color: '#0A000000', offsetX: 0, offsetY: 3 })
    .margin({ left: 16, right: 16, bottom: 16 })
  }

  @Builder
  BarChart(durationMinutes: number) {
    Stack({ alignContent: Alignment.Start }) {
      // Grid lines (every 60 mins -> 25%)
      Row() {
        ForEach([1, 2, 3], (val: number) => {
          Blank().layoutWeight(1)
          Divider().vertical(true).strokeWidth(1).color('#E0E0E0').height('100%')
        })
        Blank().layoutWeight(1)
      }.width('100%').height('100%')

      // Actual bar
      Row()
        .height('100%')
        .width(`${Math.min(durationMinutes / 240, 1) * 100}%`)
        .backgroundColor($r('app.color.primary'))
        .borderRadius(4)
        .opacity(0.8)
        
      Text(`${durationMinutes} 分钟`)
        .fontSize(10)
        .fontColor((Math.min(durationMinutes / 240, 1) * 100) > 20 ? '#FFFFFF' : $r('app.color.text_secondary'))
        .margin({ left: (Math.min(durationMinutes / 240, 1) * 100) > 20 ? 8 : `${(Math.min(durationMinutes / 240, 1) * 100) + 2}%` })
    }
    .width('100%')
    .height(20)
    .backgroundColor('#F5F5F5')
    .borderRadius(4)
  }

  @Builder
  BooksListBuilder() {
    Column() {
      if (this.getBooksReadOnSelectedDate().length === 0) {
        Column() {
          Text('你今天还没有阅读哦')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 20, bottom: 20 })
        }.width('100%').alignItems(HorizontalAlign.Center)
      } else {
        Column() {
          // X-Axis
          Row() {
            Text('').width(40).margin({ right: 12 }) // offset for cover
            Flex({ justifyContent: FlexAlign.SpaceBetween }) {
              Text('60m').fontSize(10).fontColor('#BDBDBD')
              Text('120m').fontSize(10).fontColor('#BDBDBD')
              Text('180m').fontSize(10).fontColor('#BDBDBD')
              Text('240m').fontSize(10).fontColor('#BDBDBD')
            }.layoutWeight(1)
          }.width('100%').margin({ bottom: 8 })

          // Chart Rows
          ForEach(this.getBooksReadOnSelectedDate(), (item: ReadBookInfo) => {
            Row() {
              Image(item.book.cover)
                .width(40)
                .height(56)
                .borderRadius(4)
                .objectFit(ImageFit.Cover)
                .margin({ right: 12 })
                .onClick(() => {
                  router.pushUrl({
                    url: 'pages/BookDetail',
                    params: {
                      id: item.book.id,
                      title: item.book.title,
                      author: item.book.author,
                      cover: item.book.cover,
                      coverColor: item.book.coverColor,
                      status: item.book.status,
                      summary: item.book.summary,
                      publisher: item.book.publisher,
                      publishDate: item.book.publishDate,
                      pages: item.book.pages,
                      isbn: item.book.isbn,
                      category: item.book.category
                    }
                  });
                })
              
              Column() {
                Text(item.book.title)
                  .fontSize(12)
                  .fontColor('#666666')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ bottom: 6 })

                Stack({ alignContent: Alignment.Start }) {
                  // Background grid lines
                  Row() {
                    Blank().layoutWeight(1)
                    Divider().vertical(true).strokeWidth(1).color('#EEEEEE').height('100%')
                    Blank().layoutWeight(1)
                    Divider().vertical(true).strokeWidth(1).color('#EEEEEE').height('100%')
                    Blank().layoutWeight(1)
                    Divider().vertical(true).strokeWidth(1).color('#EEEEEE').height('100%')
                    Blank().layoutWeight(1)
                    Divider().vertical(true).strokeWidth(1).color('#EEEEEE').height('100%')
                  }.width('100%').height('100%')

                  // Data Bar
                  Row()
                    .height(20)
                    .width(`${Math.min(item.duration / 240, 1) * 100}%`)
                    .backgroundColor($r('app.color.primary'))
                    .borderRadius(4)
                    
                  Text(`${item.duration}m`)
                    .fontSize(10)
                    .fontColor((Math.min(item.duration / 240, 1) * 100) > 20 ? '#FFFFFF' : '#888')
                    .margin({ left: (Math.min(item.duration / 240, 1) * 100) > 20 ? 8 : `${Math.min(item.duration / 240, 1) * 100 + 2}%` })
                }
                .width('100%')
                .height(20)
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              .justifyContent(FlexAlign.Center)
              .height(56)
            }
            .width('100%')
            .margin({ bottom: 12 })
          })
        }
        .width('100%')
        .padding(16)
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius(12)
        .margin({ bottom: 12 })
        .shadow({ radius: 4, color: '#0A000000', offsetX: 0, offsetY: 2 })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
  }

  @Builder
  NotesListBuilder() {
    Column() {
      if (this.getNotesOnSelectedDate().length > 0) {
        Row() {
          Text('当日笔记')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })

        Column() {
          ForEach(this.getNotesOnSelectedDate(), (note: NoteItem) => {
            Row() {
              Image($r('app.media.ic_book_list'))
                .width(20)
                .height(20)
                .fillColor($r('app.color.primary'))
                .margin({ right: 12 })
              
              Column() {
                Text(note.title)
                  .fontSize(14)
                  .fontColor($r('app.color.text_primary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius(12)
            .margin({ bottom: 12 })
            .shadow({ radius: 4, color: '#0A000000', offsetX: 0, offsetY: 2 })
            .onClick(() => {
              router.pushUrl({
                url: 'pages/NoteEditor',
                params: {
                  noteId: note.id,
                  bookId: note.bookId,
                  fileName: note.fileName
                }
              });
            })
          })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }
    }
    .width('100%')
  }

  build() {
    Column() {
      // Top Navigation
      Row() {
        Image($r('app.media.ic_back'))
          .width(24).height(24)
          .fillColor($r('app.color.text_primary'))
          .onClick(() => this.changeMonth(-1))
        
        Text(`${this.currentYear}年 ${this.currentMonth}月`)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .margin({ left: 16, right: 16 })
          
        Image($r('app.media.ic_back'))
          .width(24).height(24)
          .rotate({ angle: 180 })
          .fillColor($r('app.color.text_primary'))
          .onClick(() => this.changeMonth(1))
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: 16, bottom: 16 })

      // 1. Calendar View (Fixed position)
      this.CalendarGrid()

      Scroll() {
        Column() {

          // 2. Daily Stats Title
          Row() {
            Text('当日详情')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 12 })

          // 3. Books List
          this.BooksListBuilder()

          // 4. Notes List
          this.NotesListBuilder()
          
          Blank().height(40)
        }
        .width('100%')
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }
}
