import router from '@ohos.router';
import dataPreferences from '@ohos.data.preferences';
import { BookItem, MOCK_BOOKS } from '../model/BookData';
import { BookshelfTab } from '../components/BookshelfTab';
import { ScanTab } from '../components/ScanTab';
import { ProfileTab } from '../components/ProfileTab';
import { CalendarTab } from '../components/CalendarTab';
import { SettingsOverlay } from '../components/SettingsOverlay';
import { NoteItem } from '../model/NoteData';
import { ReadingSession } from '../model/ReadingSessionData';

@Entry
@Component
struct Index {
  @StorageLink('globalBooks') @Watch('onBooksChange') books: BookItem[] = [];
  @StorageLink('globalNotes') @Watch('onNotesChange') notes: NoteItem[] = [];
  @StorageLink('globalReadingSessions') @Watch('onReadingSessionsChange') readingSessions: ReadingSession[] = [];
  @State timeFilter: string = 'year'; // 'year' | 'all'
  @State searchText: string = '';
  @State filterStatus: string = 'all'; // 'all' | 'unread' | 'reading' | 'read'
  @State currentIndex: number = 0;
  @State customApiUrl: string = '';
  @State customApiToken: string = '';
  @State showSettingsOverlay: boolean = false;
  @State showAboutOverlay: boolean = false;
  
  private tabsController: TabsController = new TabsController();

  aboutToAppear() {
    this.loadBooksFromPreferences();
    this.loadNotesFromPreferences();
    this.loadReadingSessionsFromPreferences();
    this.loadServerConfigs();
  }

  onPageShow() {
    try {
      let params = router.getParams() as Record<string, Object>;
      if (params) {
        if (params.deleteBookId) {
          let idToDelete = params.deleteBookId as string;
          this.books = this.books.filter(book => book.id !== idToDelete);
          params.deleteBookId = '';
        } else if (params.updatedBookId) {
          let idToUpdate = params.updatedBookId as string;
          let newStatus = params.updatedStatus as 'unread' | 'reading' | 'read';
          let newCategory = params.updatedCategory as string;
          this.books = this.books.map(book => {
            if (book.id === idToUpdate) {
              if (newStatus) book.status = newStatus;
              if (newCategory) book.category = newCategory;
            }
            return book;
          });
          params.updatedBookId = '';
        }
      }
    } catch (err) {
      console.error('onPageShow sync error: ' + JSON.stringify(err));
    }
  }

  // Load user API configurations from preferences
  loadServerConfigs() {
    try {
      let pref = dataPreferences.getPreferencesSync(getContext(this), { name: 'myBookStorePrefs' });
      let storedUrl = pref.getSync('customApiUrl', '') as string;
      if (storedUrl === 'http://118.25.58.73:11221/api/book') {
        storedUrl = ''; // Force override old default
        pref.putSync('customApiUrl', 'https://jixiaokui.icu/api/book');
        pref.flush();
      }
      this.customApiUrl = storedUrl ? storedUrl : 'https://jixiaokui.icu/api/book';
      this.customApiToken = pref.getSync('customApiToken', '') as string;
    } catch (err) {
      console.error('Failed to load server configs: ' + JSON.stringify(err));
    }
  }

  // Handle book changes: persist data
  onBooksChange() {
    this.saveBooksToPreferences();
  }

  onNotesChange() {
    this.saveNotesToPreferences();
  }

  onReadingSessionsChange() {
    this.saveReadingSessionsToPreferences();
  }

  // Save books list to preferences
  saveBooksToPreferences() {
    try {
      let pref = dataPreferences.getPreferencesSync(getContext(this), { name: 'myBookStorePrefs' });
      pref.putSync('booksList', JSON.stringify(this.books));
      pref.flushSync();
    } catch (err) {
      console.error('Failed to save books: ' + JSON.stringify(err));
    }
  }

  loadBooksFromPreferences() {
    try {
      let pref = dataPreferences.getPreferencesSync(getContext(this), { name: 'myBookStorePrefs' });
      let booksStr = pref.getSync('booksList', '') as string;
      if (booksStr) {
        let parsedBooks = JSON.parse(booksStr) as BookItem[];
        this.books = parsedBooks.map(book => {
          if (book.currentPage === undefined) {
            book.currentPage = 0;
          }
          return book;
        });
      }
    } catch (err) {
      console.error('Failed to load books: ' + JSON.stringify(err));
    }
  }

  saveNotesToPreferences() {
    try {
      let pref = dataPreferences.getPreferencesSync(getContext(this), { name: 'myBookStorePrefs' });
      pref.putSync('notesList', JSON.stringify(this.notes));
      pref.flushSync();
    } catch (err) {
      console.error('Failed to save notes: ' + JSON.stringify(err));
    }
  }

  loadNotesFromPreferences() {
    try {
      let pref = dataPreferences.getPreferencesSync(getContext(this), { name: 'myBookStorePrefs' });
      let notesStr = pref.getSync('notesList', '') as string;
      if (notesStr) {
        this.notes = JSON.parse(notesStr) as NoteItem[];
      }
    } catch (err) {
      console.error('Failed to load notes: ' + JSON.stringify(err));
    }
  }

  saveReadingSessionsToPreferences() {
    try {
      let pref = dataPreferences.getPreferencesSync(getContext(this), { name: 'myBookStorePrefs' });
      pref.putSync('readingSessionsList', JSON.stringify(this.readingSessions));
      pref.flushSync();
    } catch (err) {
      console.error('Failed to save reading sessions: ' + JSON.stringify(err));
    }
  }

  loadReadingSessionsFromPreferences() {
    try {
      let pref = dataPreferences.getPreferencesSync(getContext(this), { name: 'myBookStorePrefs' });
      let sessionsStr = pref.getSync('readingSessionsList', '') as string;
      if (sessionsStr) {
        this.readingSessions = JSON.parse(sessionsStr) as ReadingSession[];
      }
    } catch (err) {
      console.error('Failed to load reading sessions: ' + JSON.stringify(err));
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

  build() {
    Stack() {
      Column() {
        Tabs({ barPosition: BarPosition.End, controller: this.tabsController }) {
          TabContent() {
            BookshelfTab({
              books: $books,
              searchText: $searchText,
              filterStatus: $filterStatus
            })
          }
          .tabBar(this.TabBuilder(0, '图书', $r('app.media.ic_book_list')))

          TabContent() {
            ScanTab({
              books: $books,
              customApiUrl: $customApiUrl,
              customApiToken: $customApiToken,
              currentIndex: $currentIndex
            })
          }
          .tabBar(this.TabBuilder(1, '扫码录入', $r('app.media.ic_scan')))

          TabContent() {
            CalendarTab()
          }
          .tabBar(this.TabBuilder(2, '日历', $r('app.media.ic_calendar')))

          TabContent() {
            ProfileTab({
              books: $books,
              timeFilter: $timeFilter,
              showSettingsOverlay: $showSettingsOverlay
            })
          }
          .tabBar(this.TabBuilder(3, '我', $r('app.media.ic_user')))
        }
        .width('100%')
        .height('100%')
        .onChange((index: number) => {
          this.currentIndex = index;
        })
        .backgroundColor($r('app.color.card_bg'))
      }
      .width('100%')
      .height('100%')

      SettingsOverlay({
        books: $books,
        customApiUrl: $customApiUrl,
        customApiToken: $customApiToken,
        showSettingsOverlay: $showSettingsOverlay,
        showAboutOverlay: $showAboutOverlay
      })
    }
    .width('100%')
    .height('100%')
  }
}
