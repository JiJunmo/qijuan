export class BookItem {
  id: string;
  title: string;
  author: string;
  cover: string | Resource;
  coverColor: string; // Used to paint a custom minimalist cover background
  status: 'unread' | 'reading' | 'read'; // 'unread' = 未读, 'reading' = 在读, 'read' = 已读
  summary: string;
  publisher: string;
  publishDate: string;
  pages: number;
  isbn: string;
  category: string;

  constructor(
    id: string,
    title: string,
    author: string,
    cover: string | Resource,
    coverColor: string,
    status: 'unread' | 'reading' | 'read',
    summary: string,
    publisher: string,
    publishDate: string,
    pages: number,
    isbn: string,
    category: string
  ) {
    this.id = id;
    this.title = title;
    this.author = author;
    this.cover = cover;
    this.coverColor = coverColor;
    this.status = status;
    this.summary = summary;
    this.publisher = publisher;
    this.publishDate = publishDate;
    this.pages = pages;
    this.isbn = isbn;
    this.category = category;
  }
}

export const MOCK_BOOKS: BookItem[] = [
  new BookItem(
    '1',
    '瓦尔登湖',
    '亨利·戴维·梭罗',
    $r('app.media.cover_placeholder'),
    '#5F8575',
    'reading',
    '本书收录了梭罗独居瓦尔登湖畔时期的散文作品，展现了他对自然、简单生活以及人类精神本源的深刻思考与感悟。',
    '译林出版社',
    '2020-03',
    324,
    '9787544781206',
    '哲学/散文'
  ),
  new BookItem(
    '2',
    '月亮与六便士',
    '威廉·萨默塞特·毛姆',
    $r('app.media.cover_placeholder'),
    '#4A6B82',
    'read',
    '讲述了一个原本平凡的证券经纪人思特里克兰德，突然抛妻弃子，奔赴巴黎去追寻艺术梦想，并最终在塔希提岛上找到灵魂归宿的故事。',
    '上海译文出版社',
    '2018-06',
    286,
    '9787532777174',
    '外国文学'
  ),
  new BookItem(
    '3',
    '小王子',
    '安托万·德·圣-埃克苏佩里',
    $r('app.media.cover_placeholder'),
    '#BFA76F',
    'read',
    '以一位飞行员作为叙述者，讲述了小王子从自己星球出发前往地球历险的旅程。这是一部关于爱与责任、童真与迷失的治愈系寓言。',
    '人民文学出版社',
    '2017-05',
    118,
    '9787020126742',
    '儿童文学/寓言'
  ),
  new BookItem(
    '4',
    '三体',
    '刘慈欣',
    $r('app.media.cover_placeholder'),
    '#2E3A3B',
    'unread',
    '中国当代科幻小说的巅峰之作，讲述了地球文明与三体文明之间的接触、博弈以及宇宙中生死存亡的森林法则。',
    '重庆出版社',
    '2012-01',
    302,
    '9787536692930',
    '科幻小说'
  ),
  new BookItem(
    '5',
    '人类简史',
    '尤瓦尔·赫拉利',
    $r('app.media.cover_placeholder'),
    '#826C5F',
    'reading',
    '理清了人类从一种不起眼的哺乳动物走向统治地球的霸主的演变历程，探讨了认知革命、农业革命和科学革命对人类历史的巨大重塑。',
    '中信出版社',
    '2014-11',
    440,
    '9787508647357',
    '历史/科普'
  ),
  new BookItem(
    '6',
    '非暴力沟通',
    '马歇尔·卢森堡',
    $r('app.media.cover_placeholder'),
    '#7D6B88',
    'read',
    '提出了一种非暴力的沟通方式（简称NVC），指导人们通过表达观察、感受、需要和请求，建立起真诚、和谐、充满关爱的人际关系。',
    '华夏出版社',
    '2009-01',
    196,
    '9787508048612',
    '心理学/沟通'
  ),
  new BookItem(
    '7',
    '百年孤独',
    '加西亚·马尔克斯',
    $r('app.media.cover_placeholder'),
    '#7F5E5E',
    'unread',
    '魔幻现实主义的代表作，描写了布恩迪亚家族七代人在马孔多小镇的兴衰与百年沧桑，生动反映了拉丁美洲历史的孤独与变迁。',
    '南海出版公司',
    '2011-06',
    360,
    '9787544253994',
    '世界名著'
  ),
  new BookItem(
    '8',
    '金锁记',
    '张爱玲',
    $r('app.media.cover_placeholder'),
    '#684C58',
    'unread',
    '讲述了小商人家庭出身的曹七巧，在金钱利诱下嫁入豪门，在一生扭曲的封建枷锁折磨下，最终导致自己以及儿女命运悲剧的凄惨故事。',
    '北京十月文艺出版社',
    '2012-08',
    215,
    '9787530211755',
    '中国文学'
  )
];
