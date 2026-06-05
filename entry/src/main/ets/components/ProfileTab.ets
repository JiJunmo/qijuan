import { BookItem } from '../model/BookData';
import promptAction from '@ohos.promptAction';

class ChartSegment {
  name: string;
  value: number;
  color: string;
  percentage: string;

  constructor(name: string, value: number, color: string, percentage: string) {
    this.name = name;
    this.value = value;
    this.color = color;
    this.percentage = percentage;
  }
}

class CategoryCount {
  name: string;
  count: number;
  constructor(name: string, count: number) {
    this.name = name;
    this.count = count;
  }
}

class ChartPoint {
  label: string;
  value: number;
  constructor(label: string, value: number) {
    this.label = label;
    this.value = value;
  }
}

class DrawPoint {
  x: number;
  y: number;
  val: number;
  label: string;
  constructor(x: number, y: number, val: number, label: string) {
    this.x = x;
    this.y = y;
    this.val = val;
    this.label = label;
  }
}

@Component
export struct ProfileTab {
  @Link @Watch('drawTimeChart') books: BookItem[];
  @Link @Watch('drawTimeChart') timeFilter: string; // 'year' | 'all'
  @Link showSettingsOverlay: boolean;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  // Get reading count stats
  getStats(status: string): number {
    return this.books.filter(b => b.status === status).length;
  }

  // Get reading status stats array for charts
  getReadingStatusChartData(): ChartSegment[] {
    const reading = this.getStats('reading');
    const read = this.getStats('read');
    const unread = this.getStats('unread');
    const total = this.books.length;

    if (total === 0) {
      return [];
    }

    const data: ChartSegment[] = [];
    if (reading > 0) {
      data.push(new ChartSegment('在读', reading, '#D99B26', ((reading / total) * 100).toFixed(1) + '%'));
    }
    if (read > 0) {
      data.push(new ChartSegment('已读', read, '#4E8975', ((read / total) * 100).toFixed(1) + '%'));
    }
    if (unread > 0) {
      data.push(new ChartSegment('未读', unread, '#8C9D96', ((unread / total) * 100).toFixed(1) + '%'));
    }
    return data;
  }

  // Get category stats array for charts
  getCategoryChartData(): ChartSegment[] {
    const total = this.books.length;
    if (total === 0) {
      return [];
    }

    const list: CategoryCount[] = [];
    for (let i = 0; i < this.books.length; i++) {
      let cat = this.books[i].category || '未分类';
      cat = cat.trim();
      if (!cat) {
        cat = '未分类';
      }
      let found = false;
      for (let j = 0; j < list.length; j++) {
        if (list[j].name === cat) {
          list[j].count++;
          found = true;
          break;
        }
      }
      if (!found) {
        list.push(new CategoryCount(cat, 1));
      }
    }

    // Sort by count desc
    list.sort((a, b) => b.count - a.count);

    const chartColors = ['#5F8575', '#4A6B82', '#BFA76F', '#7D6B88', '#7F5E5E', '#684C58', '#8C9D96'];

    const data: ChartSegment[] = [];
    const limit = 4;
    let otherCount = 0;

    for (let i = 0; i < list.length; i++) {
      if (i < limit) {
        const name = list[i].name;
        const val = list[i].count;
        const color = chartColors[i % chartColors.length];
        const pct = ((val / total) * 100).toFixed(1) + '%';
        data.push(new ChartSegment(name, val, color, pct));
      } else {
        otherCount += list[i].count;
      }
    }

    if (otherCount > 0) {
      const color = '#A0A0A0';
      const pct = ((otherCount / total) * 100).toFixed(1) + '%';
      data.push(new ChartSegment('其他', otherCount, color, pct));
    }

    return data;
  }

  // Get line chart data based on timeFilter
  getLineChartData(): ChartPoint[] {
    const data: ChartPoint[] = [];
    const date = new Date();
    const currentYear = date.getFullYear();
    const currentMonth = date.getMonth() + 1;

    if (this.timeFilter === 'year') {
      const monthsList: string[] = [];

      for (let i = 11; i >= 0; i--) {
        let y = currentYear;
        let m = currentMonth - i;
        if (m <= 0) {
          m += 12;
          y -= 1;
        }
        const mStr = m < 10 ? '0' + m : '' + m;
        monthsList.push(`${y}-${mStr}`);
      }

      for (let i = 0; i < monthsList.length; i++) {
        let total = 0;
        for (let j = 0; j < this.books.length; j++) {
          const book = this.books[j];
          if (book.addTime && book.addTime.length >= 7) {
            const ym = book.addTime.substring(0, 7);
            if (ym <= monthsList[i]) {
              total++;
            }
          }
        }
        const label = monthsList[i].substring(5) + '月';
        data.push(new ChartPoint(label, total));
      }
    } else {
      const yearsList: string[] = [];

      for (let i = 4; i >= 0; i--) {
        yearsList.push((currentYear - i).toString());
      }

      // "更早": books added before the 5-year window
      const earliestYear = yearsList[0];
      let earlierTotal = 0;
      for (let j = 0; j < this.books.length; j++) {
        const book = this.books[j];
        if (book.addTime && book.addTime.length >= 4) {
          if (book.addTime.substring(0, 4) < earliestYear) {
            earlierTotal++;
          }
        }
      }
      data.push(new ChartPoint('更早', earlierTotal));

      // Each year: cumulative total of all books added up to end of that year
      for (let i = 0; i < yearsList.length; i++) {
        let total = 0;
        for (let j = 0; j < this.books.length; j++) {
          const book = this.books[j];
          if (book.addTime && book.addTime.length >= 4) {
            if (book.addTime.substring(0, 4) <= yearsList[i]) {
              total++;
            }
          }
        }
        data.push(new ChartPoint(yearsList[i] + '年', total));
      }
    }

    return data;
  }

  // Draw time line chart dynamically on Canvas
  drawTimeChart() {
    try {
      const data = this.getLineChartData();
      if (data.length === 0) {
        return;
      }

      const width = this.context.width || 300;
      const height = this.context.height || 130;

      this.context.clearRect(0, 0, width, height);

      const leftPad = 25;
      const rightPad = 15;
      const topPad = 20;
      const bottomPad = 20;

      const chartW = width - leftPad - rightPad;
      const chartH = height - topPad - bottomPad;

      let maxVal = 0;
      for (let i = 0; i < data.length; i++) {
        if (data[i].value > maxVal) {
          maxVal = data[i].value;
        }
      }
      if (maxVal === 0) {
        maxVal = 4;
      } else {
        maxVal = Math.ceil(maxVal / 2) * 2;
      }

      this.context.beginPath();
      this.context.strokeStyle = '#F0F0F0';
      this.context.lineWidth = 1;
      
      const gridLines = 2;
      for (let i = 0; i <= gridLines; i++) {
        const y = topPad + chartH * (1 - i / gridLines);
        this.context.moveTo(leftPad, y);
        this.context.lineTo(width - rightPad, y);
      }
      this.context.stroke();

      this.context.fillStyle = '#9E9E9E';
      this.context.font = '36px sans-serif';
      this.context.textAlign = 'right';
      this.context.textBaseline = 'middle';
      for (let i = 0; i <= gridLines; i++) {
        const val = Math.round((maxVal / gridLines) * i);
        const y = topPad + chartH * (1 - i / gridLines);
        this.context.fillText(val.toString(), leftPad - 8, y);
      }

      const points: DrawPoint[] = [];
      for (let i = 0; i < data.length; i++) {
        const x = leftPad + (chartW / (data.length - 1)) * i;
        const y = topPad + chartH * (1 - data[i].value / maxVal);
        points.push(new DrawPoint(x, y, data[i].value, data[i].label));
      }

      this.context.beginPath();
      this.context.strokeStyle = '#4E8975';
      this.context.lineWidth = 2;
      for (let i = 0; i < points.length; i++) {
        if (i === 0) {
          this.context.moveTo(points[i].x, points[i].y);
        } else {
          this.context.lineTo(points[i].x, points[i].y);
        }
      }
      this.context.stroke();

      this.context.beginPath();
      this.context.moveTo(points[0].x, topPad + chartH);
      for (let i = 0; i < points.length; i++) {
        this.context.lineTo(points[i].x, points[i].y);
      }
      this.context.lineTo(points[points.length - 1].x, topPad + chartH);
      this.context.closePath();
      this.context.fillStyle = 'rgba(78, 137, 117, 0.08)';
      this.context.fill();

      for (let i = 0; i < points.length; i++) {
        const pt = points[i];

        this.context.beginPath();
        this.context.fillStyle = '#4E8975';
        this.context.arc(pt.x, pt.y, 5, 0, 2 * Math.PI);
        this.context.fill();

        this.context.beginPath();
        this.context.fillStyle = '#FFFFFF';
        this.context.arc(pt.x, pt.y, 2.5, 0, 2 * Math.PI);
        this.context.fill();

        if (pt.val > 0) {
          this.context.fillStyle = '#2A3A35';
          this.context.font = 'bold 36px sans-serif';
          this.context.textAlign = 'center';
          this.context.fillText(pt.val.toString(), pt.x, pt.y - 16);
        }

        if (this.timeFilter === 'year' && i % 2 !== 0) {
          continue;
        }
        this.context.fillStyle = '#9E9E9E';
        this.context.font = '36px sans-serif';
        this.context.textAlign = 'center';
        this.context.textBaseline = 'top';
        this.context.fillText(pt.label, pt.x, topPad + chartH + 10);
      }
    } catch (e) {
      console.error('Failed to draw line chart: ' + JSON.stringify(e));
    }
  }

  build() {
    Column() {
      Scroll() {
        Column() {
          // 1. Profile Info Header Card
          Row() {
            Image($r('app.media.ic_user'))
              .width(64)
              .height(64)
              .margin({ right: 16 })
              .borderRadius(32)
              .backgroundColor($r('app.color.primary_light'))
              .padding(12)
            
            Column() {
              Text('我的书房')
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
                .margin({ bottom: 4 })
              Text(`已坚持阅读 ${this.books.filter(b => b.status === 'read').length} 本书籍`)
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Image($r('app.media.ic_settings'))
              .width(24)
              .height(24)
              .fillColor($r('app.color.text_primary'))
              .onClick(() => {
                this.showSettingsOverlay = true;
              })
          }
          .width('100%')
          .padding({ top: 24, bottom: 24, left: 16, right: 16 })
          .margin({ bottom: 16 })

          // 2. Statistics Section Card
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
          .width('100%')
          .padding({ top: 16, bottom: 16 })
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(16)
          .margin({ bottom: 16 })

          // 3. Charts Section
          if (this.books.length > 0) {
            // Chart 1 Card
            Column() {
              Row() {
                Text('阅读状态')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                Blank()
              }
              .width('100%')
              .margin({ bottom: 16 })

              Row() {
                // Left: Pie Chart
                Stack() {
                  DataPanel({
                    values: this.getReadingStatusChartData().map(item => item.value),
                    max: this.books.length,
                    type: DataPanelType.Circle
                  })
                    .width(100)
                    .height(100)
                    .strokeWidth(10)
                    .valueColors(this.getReadingStatusChartData().map(item => item.color))

                  Column() {
                    Text(this.books.length.toString())
                      .fontSize(16)
                      .fontWeight(FontWeight.Bold)
                      .fontColor($r('app.color.text_primary'))
                    Text('总藏书')
                      .fontSize(8)
                      .fontColor($r('app.color.text_secondary'))
                  }
                }
                .width(100)
                .height(100)
                .margin({ right: 24 })

                // Right: Legends
                Column() {
                  ForEach(this.getReadingStatusChartData(), (item: ChartSegment) => {
                    Row() {
                      Circle({ width: 8, height: 8 })
                        .fill(item.color)
                        .margin({ right: 8 })
                      Text(`${item.name}`)
                        .fontSize(13)
                        .fontWeight(FontWeight.Medium)
                        .fontColor($r('app.color.text_primary'))
                        .margin({ right: 8 })
                      Text(`${item.value}本 (${item.percentage})`)
                        .fontSize(12)
                        .fontColor($r('app.color.text_secondary'))
                    }
                    .margin({ bottom: 8 })
                  })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
              }
              .width('100%')
              .justifyContent(FlexAlign.Start)
              .alignItems(VerticalAlign.Center)
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius(16)
            .margin({ bottom: 16 })

            // Chart 2 Card
            Column() {
              Row() {
                Text('图书分类')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                Blank()
              }
              .width('100%')
              .margin({ bottom: 16 })

              Row() {
                // Left: Pie Chart
                Stack() {
                  DataPanel({
                    values: this.getCategoryChartData().map(item => item.value),
                    max: this.books.length,
                    type: DataPanelType.Circle
                  })
                    .width(100)
                    .height(100)
                    .strokeWidth(10)
                    .valueColors(this.getCategoryChartData().map(item => item.color))

                  Column() {
                    Text(this.getCategoryChartData().length.toString())
                      .fontSize(16)
                      .fontWeight(FontWeight.Bold)
                      .fontColor($r('app.color.text_primary'))
                    Text('分类数')
                      .fontSize(8)
                      .fontColor($r('app.color.text_secondary'))
                  }
                }
                .width(100)
                .height(100)
                .margin({ right: 24 })

                // Right: Legends
                Column() {
                  ForEach(this.getCategoryChartData(), (item: ChartSegment) => {
                    Row() {
                      Circle({ width: 8, height: 8 })
                        .fill(item.color)
                        .margin({ right: 8 })
                      Text(`${item.name}`)
                        .fontSize(13)
                        .fontWeight(FontWeight.Medium)
                        .fontColor($r('app.color.text_primary'))
                        .margin({ right: 8 })
                      Text(`${item.value}本 (${item.percentage})`)
                        .fontSize(12)
                        .fontColor($r('app.color.text_secondary'))
                    }
                    .margin({ bottom: 8 })
                  })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
              }
              .width('100%')
              .justifyContent(FlexAlign.Start)
              .alignItems(VerticalAlign.Center)
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius(16)
            .margin({ bottom: 16 })

            // Line Chart Card for Add Trends
            Column() {
              Row() {
                Text('藏书趋势')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                
                Blank()

                // Filter pills
                Row() {
                  Text('近1年')
                    .fontSize(11)
                    .fontColor(this.timeFilter === 'year' ? '#FFFFFF' : $r('app.color.text_secondary'))
                    .backgroundColor(this.timeFilter === 'year' ? $r('app.color.primary') : 'transparent')
                    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                    .borderRadius(12)
                    .onClick(() => {
                      this.timeFilter = 'year';
                      setTimeout((): void => { this.drawTimeChart(); }, 50);
                    })

                  Text('累计')
                    .fontSize(11)
                    .fontColor(this.timeFilter === 'all' ? '#FFFFFF' : $r('app.color.text_secondary'))
                    .backgroundColor(this.timeFilter === 'all' ? $r('app.color.primary') : 'transparent')
                    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                    .borderRadius(12)
                    .margin({ left: 4 })
                    .onClick(() => {
                      this.timeFilter = 'all';
                      setTimeout((): void => { this.drawTimeChart(); }, 50);
                    })
                }
                .backgroundColor($r('app.color.background'))
                .borderRadius(14)
                .padding(2)
              }
              .width('100%')
              .margin({ bottom: 16 })

              // Canvas for Custom Line Chart
              Canvas(this.context)
                .width('100%')
                .height(130)
                .onReady(() => {
                  this.drawTimeChart();
                })
            }
            .width('calc(100% - 32px)')
            .padding(16)
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius(16)
            .margin({ bottom: 24 })
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
  }
}
