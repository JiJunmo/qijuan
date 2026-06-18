export class ReadingSession {
  id: string;
  bookId: string;
  startTime: number; // Unix timestamp in milliseconds
  duration: number; // Duration in seconds

  constructor(id: string, bookId: string, startTime: number, duration: number) {
    this.id = id;
    this.bookId = bookId;
    this.startTime = startTime;
    this.duration = duration;
  }
}
