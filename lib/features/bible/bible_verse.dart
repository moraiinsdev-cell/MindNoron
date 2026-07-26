import 'package:flutter/material.dart';

/// Curated, offline library for the Holy Bible ("Kinh Thánh") feature.
///
/// Every verse is stored bilingually: a Vietnamese rendering (following the
/// public-domain *Bản Truyền Thống* 1926) and the English King James Version
/// (also public domain), each with its own chapter/verse reference. A short
/// Vietnamese `reflection` is our own devotional note — clearly separate from
/// Scripture, never presented as the text itself.
///
/// No network, no LLM: the daily verse is chosen deterministically from the
/// calendar day, so "câu của Chúa mỗi ngày" is stable through the day and moves
/// on tomorrow. See [verseOfDay].

/// The devotional theme a verse belongs to. Labels are Vietnamese; the glyph is
/// used on chips and topic cards.
enum BibleTopic {
  hope('Hy vọng', '🌅'),
  peace('Bình an', '🕊️'),
  faith('Đức tin', '✝️'),
  love('Tình yêu thương', '❤️'),
  strength('Sức mạnh', '💪'),
  comfort('An ủi', '🤲'),
  wisdom('Khôn ngoan', '🦉'),
  guidance('Dẫn dắt', '🧭'),
  gratitude('Tạ ơn', '🙏'),
  forgiveness('Tha thứ', '🕯️');

  const BibleTopic(this.label, this.emoji);

  final String label;
  final String emoji;
}

/// A single verse (or short passage), rendered in two languages.
@immutable
class BibleVerse {
  const BibleVerse({
    required this.refVi,
    required this.refEn,
    required this.vi,
    required this.en,
    required this.topic,
    required this.reflection,
  });

  /// Vietnamese reference, e.g. "Giăng 3:16".
  final String refVi;

  /// English reference, e.g. "John 3:16" — also the stable id for favourites.
  final String refEn;

  /// Vietnamese text (Bản Truyền Thống style).
  final String vi;

  /// English text (KJV).
  final String en;

  final BibleTopic topic;

  /// A short Vietnamese devotional line — our words, not Scripture.
  final String reflection;

  /// Stable identifier used for persistence (favourites).
  String get id => refEn;

  String textFor({required bool english}) => english ? en : vi;
  String refFor({required bool english}) => english ? refEn : refVi;
}

/// The full offline verse library. Well-known verses only, so both the
/// Vietnamese and English wording can be trusted; grouped loosely by topic.
const List<BibleVerse> bibleVerses = <BibleVerse>[
  // ── Hy vọng ────────────────────────────────────────────────────────────
  BibleVerse(
    refVi: 'Giê-rê-mi 29:11',
    refEn: 'Jeremiah 29:11',
    vi: 'Ðức Giê-hô-va phán: Vì ta biết ý tưởng ta nghĩ đối cùng các ngươi, '
        'là ý tưởng bình an, không phải tai họa, để cho các ngươi được sự '
        'trông cậy trong lúc cuối cùng của mình.',
    en: 'For I know the thoughts that I think toward you, saith the LORD, '
        'thoughts of peace, and not of evil, to give you an expected end.',
    topic: BibleTopic.hope,
    reflection: 'Kế hoạch của Chúa dành cho bạn là bình an và hy vọng — ngay '
        'cả khi hôm nay bạn chưa nhìn thấy trọn con đường.',
  ),
  BibleVerse(
    refVi: 'Ca-thương 3:22-23',
    refEn: 'Lamentations 3:22-23',
    vi: 'Ấy là nhờ sự nhân từ Ðức Giê-hô-va mà chúng ta chưa tuyệt. Mỗi buổi '
        'sáng thì lại mới luôn, sự thành tín Ngài là lớn lắm.',
    en: 'It is of the LORD\'s mercies that we are not consumed, because his '
        'compassions fail not. They are new every morning: great is thy '
        'faithfulness.',
    topic: BibleTopic.hope,
    reflection: 'Ơn thương xót của Chúa mới lại mỗi sáng. Hôm nay là một khởi '
        'đầu tinh khôi.',
  ),
  BibleVerse(
    refVi: 'Rô-ma 8:28',
    refEn: 'Romans 8:28',
    vi: 'Vả, chúng ta biết rằng mọi sự hiệp lại làm ích cho kẻ yêu mến Ðức '
        'Chúa Trời, tức là cho kẻ được gọi theo ý muốn Ngài đã định.',
    en: 'And we know that all things work together for good to them that love '
        'God, to them who are the called according to his purpose.',
    topic: BibleTopic.hope,
    reflection: 'Cả những điều khó hiểu hôm nay, Chúa vẫn đang dệt lại thành '
        'điều tốt lành.',
  ),
  BibleVerse(
    refVi: 'Rô-ma 15:13',
    refEn: 'Romans 15:13',
    vi: 'Vậy xin Ðức Chúa Trời của sự trông cậy, làm cho anh em đầy dẫy mọi '
        'sự vui vẻ và mọi sự bình an trong đức tin, hầu cho anh em nhờ quyền '
        'phép Ðức Thánh Linh được dư dật sự trông cậy!',
    en: 'Now the God of hope fill you with all joy and peace in believing, '
        'that ye may abound in hope, through the power of the Holy Ghost.',
    topic: BibleTopic.hope,
    reflection: 'Xin cho hôm nay của bạn dư dật niềm vui, bình an và hy vọng.',
  ),
  BibleVerse(
    refVi: 'Phi-líp 4:19',
    refEn: 'Philippians 4:19',
    vi: 'Ðức Chúa Trời tôi sẽ làm cho đầy đủ mọi sự cần dùng của anh em y theo '
        'sự giàu có của Ngài ở nơi vinh hiển trong Ðức Chúa Jêsus Christ.',
    en: 'But my God shall supply all your need according to his riches in '
        'glory by Christ Jesus.',
    topic: BibleTopic.hope,
    reflection: 'Điều bạn thật sự cần, Chúa biết và sẽ chu cấp đủ đầy.',
  ),

  // ── Bình an ────────────────────────────────────────────────────────────
  BibleVerse(
    refVi: 'Phi-líp 4:6-7',
    refEn: 'Philippians 4:6-7',
    vi: 'Chớ lo phiền chi hết, nhưng trong mọi sự hãy dùng lời cầu nguyện, '
        'nài xin, và sự tạ ơn mà trình các sự cầu xin của mình cho Ðức Chúa '
        'Trời. Sự bình an của Ðức Chúa Trời vượt quá mọi sự hiểu biết, sẽ giữ '
        'gìn lòng và ý tưởng anh em trong Ðức Chúa Jêsus Christ.',
    en: 'Be careful for nothing; but in every thing by prayer and supplication '
        'with thanksgiving let your requests be made known unto God. And the '
        'peace of God, which passeth all understanding, shall keep your hearts '
        'and minds through Christ Jesus.',
    topic: BibleTopic.peace,
    reflection: 'Đổi lo lắng lấy lời cầu nguyện, và nhận lại sự bình an giữ '
        'gìn lòng bạn.',
  ),
  BibleVerse(
    refVi: 'Giăng 14:27',
    refEn: 'John 14:27',
    vi: 'Ta để sự bình an lại cho các ngươi; ta ban sự bình an ta cho các '
        'ngươi; ta cho các ngươi sự bình an chẳng phải như thế gian cho. Lòng '
        'các ngươi chớ bối rối và đừng sợ hãi.',
    en: 'Peace I leave with you, my peace I give unto you: not as the world '
        'giveth, give I unto you. Let not your heart be troubled, neither let '
        'it be afraid.',
    topic: BibleTopic.peace,
    reflection: 'Bình an của Chúa sâu hơn hoàn cảnh — nó ở lại dù xung quanh '
        'chao đảo.',
  ),
  BibleVerse(
    refVi: 'Ê-sai 26:3',
    refEn: 'Isaiah 26:3',
    vi: 'Người nào để trí mình nương dựa nơi Ngài, thì Ngài sẽ gìn giữ người '
        'trong sự bình yên trọn vẹn, vì người nhờ cậy Ngài.',
    en: 'Thou wilt keep him in perfect peace, whose mind is stayed on thee: '
        'because he trusteth in thee.',
    topic: BibleTopic.peace,
    reflection: 'Hướng tâm trí về Chúa, và bình an trọn vẹn sẽ gìn giữ bạn.',
  ),
  BibleVerse(
    refVi: 'Ma-thi-ơ 11:28',
    refEn: 'Matthew 11:28',
    vi: 'Hỡi những kẻ mệt mỏi và gánh nặng, hãy đến cùng ta, ta sẽ cho các '
        'ngươi được yên nghỉ.',
    en: 'Come unto me, all ye that labour and are heavy laden, and I will give '
        'you rest.',
    topic: BibleTopic.peace,
    reflection: 'Bạn không cần gánh một mình. Hãy đến, và được nghỉ ngơi.',
  ),
  BibleVerse(
    refVi: 'Thi-thiên 4:8',
    refEn: 'Psalm 4:8',
    vi: 'Hỡi Ðức Giê-hô-va, tôi sẽ nằm và ngủ bình an; vì chỉ một mình Ngài '
        'làm cho tôi được ở yên ổn.',
    en: 'I will both lay me down in peace, and sleep: for thou, LORD, only '
        'makest me dwell in safety.',
    topic: BibleTopic.peace,
    reflection: 'Cuối ngày, hãy đặt mọi sự vào tay Chúa và an giấc.',
  ),

  // ── Đức tin ────────────────────────────────────────────────────────────
  BibleVerse(
    refVi: 'Hê-bơ-rơ 11:1',
    refEn: 'Hebrews 11:1',
    vi: 'Vả, đức tin là sự biết chắc vững vàng của những điều mình đương trông '
        'mong, là bằng cớ của những điều mình chẳng xem thấy.',
    en: 'Now faith is the substance of things hoped for, the evidence of '
        'things not seen.',
    topic: BibleTopic.faith,
    reflection: 'Đức tin nhìn thấy điều mắt thường chưa thấy — hãy bước tới.',
  ),
  BibleVerse(
    refVi: 'Châm-ngôn 3:5-6',
    refEn: 'Proverbs 3:5-6',
    vi: 'Hãy hết lòng tin cậy Ðức Giê-hô-va, chớ nương cậy nơi sự thông sáng '
        'của con; phàm trong các việc làm của con, khá nhận biết Ngài, thì '
        'Ngài sẽ chỉ dẫn các nẻo của con.',
    en: 'Trust in the LORD with all thine heart; and lean not unto thine own '
        'understanding. In all thy ways acknowledge him, and he shall direct '
        'thy paths.',
    topic: BibleTopic.faith,
    reflection: 'Khi bạn chưa hiểu hết, hãy tin cậy Đấng hiểu trọn con đường.',
  ),
  BibleVerse(
    refVi: 'II Cô-rinh-tô 5:7',
    refEn: '2 Corinthians 5:7',
    vi: 'Vì chúng ta bước đi bởi đức tin, chớ chẳng phải bởi mắt thấy.',
    en: 'For we walk by faith, not by sight.',
    topic: BibleTopic.faith,
    reflection: 'Một bước đức tin hôm nay đáng giá hơn cả một bản đồ trọn vẹn.',
  ),
  BibleVerse(
    refVi: 'Mác 9:23',
    refEn: 'Mark 9:23',
    vi: 'Ðức Chúa Jêsus phán rằng: Sao ngươi nói: Nếu thầy làm được? Kẻ nào '
        'tin thì mọi việc đều được cả.',
    en: 'Jesus said unto him, If thou canst believe, all things are possible '
        'to him that believeth.',
    topic: BibleTopic.faith,
    reflection: 'Đừng giới hạn Chúa bằng nỗi nghi ngờ của mình. Hãy tin.',
  ),
  BibleVerse(
    refVi: 'Ma-thi-ơ 6:33',
    refEn: 'Matthew 6:33',
    vi: 'Nhưng trước hết, hãy tìm kiếm nước Ðức Chúa Trời và sự công bình của '
        'Ngài, thì Ngài sẽ cho thêm các ngươi mọi điều ấy nữa.',
    en: 'But seek ye first the kingdom of God, and his righteousness; and all '
        'these things shall be added unto you.',
    topic: BibleTopic.faith,
    reflection: 'Đặt Chúa lên hàng đầu, mọi điều khác sẽ vào đúng chỗ.',
  ),

  // ── Tình yêu thương ────────────────────────────────────────────────────
  BibleVerse(
    refVi: 'Giăng 3:16',
    refEn: 'John 3:16',
    vi: 'Vì Ðức Chúa Trời yêu thương thế gian, đến nỗi đã ban Con một của '
        'Ngài, hầu cho hễ ai tin Con ấy không bị hư mất mà được sự sống đời '
        'đời.',
    en: 'For God so loved the world, that he gave his only begotten Son, that '
        'whosoever believeth in him should not perish, but have everlasting '
        'life.',
    topic: BibleTopic.love,
    reflection: 'Tình yêu lớn nhất trong lịch sử dành cho chính bạn.',
  ),
  BibleVerse(
    refVi: 'I Cô-rinh-tô 13:4-5',
    refEn: '1 Corinthians 13:4-5',
    vi: 'Tình yêu thương hay nhịn nhục; tình yêu thương hay nhân từ; tình yêu '
        'thương chẳng ghen tị, chẳng khoe mình, chẳng lên mình kiêu ngạo, '
        'chẳng kiếm tư lợi, chẳng nóng giận, chẳng nghi ngờ sự dữ.',
    en: 'Charity suffereth long, and is kind; charity envieth not; charity '
        'vaunteth not itself, is not puffed up, seeketh not her own, is not '
        'easily provoked, thinketh no evil.',
    topic: BibleTopic.love,
    reflection: 'Yêu thương là điều bạn làm, không chỉ điều bạn cảm thấy.',
  ),
  BibleVerse(
    refVi: 'I Giăng 4:19',
    refEn: '1 John 4:19',
    vi: 'Chúng ta yêu, vì Chúa đã yêu chúng ta trước.',
    en: 'We love him, because he first loved us.',
    topic: BibleTopic.love,
    reflection: 'Bạn được yêu trước khi biết cách đáp lại. Hãy để tình yêu ấy '
        'chảy tràn.',
  ),
  BibleVerse(
    refVi: 'Rô-ma 8:38-39',
    refEn: 'Romans 8:38-39',
    vi: 'Vì tôi chắc rằng bất kỳ sự chết, sự sống, việc bây giờ, việc hầu đến, '
        'quyền phép, bề cao, hay là bề sâu, hoặc một vật nào, chẳng có thể '
        'phân rẽ chúng ta khỏi sự yêu thương của Ðức Chúa Trời trong Ðức Chúa '
        'Jêsus Christ, là Chúa chúng ta.',
    en: 'For I am persuaded, that neither death, nor life, nor things present, '
        'nor things to come, nor height, nor depth, nor any other creature, '
        'shall be able to separate us from the love of God, which is in Christ '
        'Jesus our Lord.',
    topic: BibleTopic.love,
    reflection: 'Không điều gì — không một điều gì — cắt đứt được tình yêu Chúa '
        'dành cho bạn.',
  ),

  // ── Sức mạnh ───────────────────────────────────────────────────────────
  BibleVerse(
    refVi: 'Phi-líp 4:13',
    refEn: 'Philippians 4:13',
    vi: 'Tôi làm được mọi sự nhờ Ðấng ban thêm sức cho tôi.',
    en: 'I can do all things through Christ which strengtheneth me.',
    topic: BibleTopic.strength,
    reflection: 'Sức bạn cần cho hôm nay đến từ Đấng ở cùng bạn.',
  ),
  BibleVerse(
    refVi: 'Ê-sai 41:10',
    refEn: 'Isaiah 41:10',
    vi: 'Ðừng sợ, vì ta ở với ngươi; chớ kinh khiếp, vì ta là Ðức Chúa Trời '
        'ngươi! Ta sẽ bổ sức cho ngươi; phải, ta sẽ giúp đỡ ngươi, lấy tay '
        'hữu công bình ta mà nâng đỡ ngươi.',
    en: 'Fear thou not; for I am with thee: be not dismayed; for I am thy God: '
        'I will strengthen thee; yea, I will help thee; yea, I will uphold thee '
        'with the right hand of my righteousness.',
    topic: BibleTopic.strength,
    reflection: 'Bạn không đối diện hôm nay một mình — Chúa nâng đỡ bạn.',
  ),
  BibleVerse(
    refVi: 'Giô-suê 1:9',
    refEn: 'Joshua 1:9',
    vi: 'Ta há chẳng từng phán dặn ngươi sao? Hãy vững lòng bền chí, chớ run '
        'sợ, chớ kinh khủng; vì Giê-hô-va Ðức Chúa Trời ngươi vẫn ở cùng ngươi '
        'trong mọi nơi ngươi đi.',
    en: 'Have not I commanded thee? Be strong and of a good courage; be not '
        'afraid, neither be thou dismayed: for the LORD thy God is with thee '
        'whithersoever thou goest.',
    topic: BibleTopic.strength,
    reflection: 'Can đảm không phải là không sợ, mà là bước đi vì biết Chúa ở '
        'cùng.',
  ),
  BibleVerse(
    refVi: 'Thi-thiên 46:1',
    refEn: 'Psalm 46:1',
    vi: 'Ðức Chúa Trời là nơi nương náu và sức lực của chúng tôi, Ngài sẵn '
        'giúp đỡ trong cơn gian truân.',
    en: 'God is our refuge and strength, a very present help in trouble.',
    topic: BibleTopic.strength,
    reflection: 'Trong cơn khó, Chúa không ở xa — Ngài luôn sẵn sàng giúp.',
  ),
  BibleVerse(
    refVi: 'II Ti-mô-thê 1:7',
    refEn: '2 Timothy 1:7',
    vi: 'Vì Ðức Chúa Trời chẳng ban cho chúng ta tâm thần nhút nhát, bèn là '
        'tâm thần mạnh mẽ, có tình thương yêu và dè giữ.',
    en: 'For God hath not given us the spirit of fear; but of power, and of '
        'love, and of a sound mind.',
    topic: BibleTopic.strength,
    reflection: 'Nỗi sợ không đến từ Chúa. Ngài ban sức mạnh, tình yêu và sự '
        'tỉnh táo.',
  ),
  BibleVerse(
    refVi: 'Ê-sai 40:31',
    refEn: 'Isaiah 40:31',
    vi: 'Nhưng ai trông đợi Ðức Giê-hô-va thì chắc được sức mới, cất cánh bay '
        'cao như chim ưng; chạy mà không mệt nhọc, đi mà không mòn mỏi.',
    en: 'But they that wait upon the LORD shall renew their strength; they '
        'shall mount up with wings as eagles; they shall run, and not be '
        'weary; and they shall walk, and not faint.',
    topic: BibleTopic.strength,
    reflection: 'Chờ đợi Chúa không phải là dừng lại — đó là nạp lại sức mới.',
  ),
  BibleVerse(
    refVi: 'Thi-thiên 121:1-2',
    refEn: 'Psalm 121:1-2',
    vi: 'Tôi ngước mắt lên trên núi: Sự tiếp trợ tôi đến từ đâu? Sự tiếp trợ '
        'tôi đến từ Ðức Giê-hô-va, là Ðấng đã dựng nên trời và đất.',
    en: 'I will lift up mine eyes unto the hills, from whence cometh my help. '
        'My help cometh from the LORD, which made heaven and earth.',
    topic: BibleTopic.strength,
    reflection: 'Đấng dựng nên trời đất là Đấng bạn có thể ngước trông cầu '
        'cứu.',
  ),

  // ── An ủi ──────────────────────────────────────────────────────────────
  BibleVerse(
    refVi: 'Thi-thiên 23:1',
    refEn: 'Psalm 23:1',
    vi: 'Ðức Giê-hô-va là Ðấng chăn giữ tôi; tôi sẽ chẳng thiếu thốn gì.',
    en: 'The LORD is my shepherd; I shall not want.',
    topic: BibleTopic.comfort,
    reflection: 'Người Chăn nhân lành biết rõ điều bạn cần và dẫn bạn đi.',
  ),
  BibleVerse(
    refVi: 'Thi-thiên 23:4',
    refEn: 'Psalm 23:4',
    vi: 'Dầu khi tôi đi trong trũng bóng chết, tôi sẽ chẳng sợ tai họa nào; '
        'vì Chúa ở cùng tôi; cây trượng và cây gậy của Chúa an ủi tôi.',
    en: 'Yea, though I walk through the valley of the shadow of death, I will '
        'fear no evil: for thou art with me; thy rod and thy staff they '
        'comfort me.',
    topic: BibleTopic.comfort,
    reflection: 'Ngay giữa thung lũng tối, bạn không đi một mình.',
  ),
  BibleVerse(
    refVi: 'Thi-thiên 34:18',
    refEn: 'Psalm 34:18',
    vi: 'Ðức Giê-hô-va ở gần những người có lòng đau thương, và cứu kẻ nào có '
        'tâm hồn thống hối.',
    en: 'The LORD is nigh unto them that are of a broken heart; and saveth '
        'such as be of a contrite spirit.',
    topic: BibleTopic.comfort,
    reflection: 'Khi lòng tan vỡ, Chúa lại đến gần nhất.',
  ),
  BibleVerse(
    refVi: 'Thi-thiên 147:3',
    refEn: 'Psalm 147:3',
    vi: 'Ngài chữa lành người có lòng đau thương, và bó vít của họ.',
    en: 'He healeth the broken in heart, and bindeth up their wounds.',
    topic: BibleTopic.comfort,
    reflection: 'Chúa không xem nhẹ vết thương của bạn — Ngài chữa lành nó.',
  ),
  BibleVerse(
    refVi: 'I Phi-e-rơ 5:7',
    refEn: '1 Peter 5:7',
    vi: 'Lại hãy trao mọi điều lo lắng mình cho Ngài, vì Ngài hay săn sóc anh '
        'em.',
    en: 'Casting all your care upon him; for he careth for you.',
    topic: BibleTopic.comfort,
    reflection: 'Điều khiến bạn thao thức, Chúa mời bạn trao lại cho Ngài.',
  ),
  BibleVerse(
    refVi: 'Thi-thiên 55:22',
    refEn: 'Psalm 55:22',
    vi: 'Hãy trao gánh nặng ngươi cho Ðức Giê-hô-va, Ngài sẽ nâng đỡ ngươi; '
        'Ngài sẽ chẳng hề cho người công bình bị rúng động.',
    en: 'Cast thy burden upon the LORD, and he shall sustain thee: he shall '
        'never suffer the righteous to be moved.',
    topic: BibleTopic.comfort,
    reflection: 'Đặt gánh nặng xuống. Chúa đủ mạnh để nâng cả bạn lẫn nó.',
  ),
  BibleVerse(
    refVi: 'Ma-thi-ơ 5:4',
    refEn: 'Matthew 5:4',
    vi: 'Phước cho những kẻ than khóc, vì sẽ được yên ủi!',
    en: 'Blessed are they that mourn: for they shall be comforted.',
    topic: BibleTopic.comfort,
    reflection: 'Nước mắt của bạn không vô nghĩa — sự an ủi đang đến.',
  ),

  // ── Khôn ngoan ─────────────────────────────────────────────────────────
  BibleVerse(
    refVi: 'Gia-cơ 1:5',
    refEn: 'James 1:5',
    vi: 'Ví bằng trong anh em có kẻ kém khôn ngoan, hãy cầu xin Ðức Chúa Trời, '
        'là Ðấng ban cho mọi người cách rộng rãi, không trách móc ai, thì kẻ '
        'ấy sẽ được ban cho.',
    en: 'If any of you lack wisdom, let him ask of God, that giveth to all men '
        'liberally, and upbraideth not; and it shall be given him.',
    topic: BibleTopic.wisdom,
    reflection: 'Khi phân vân, hãy hỏi Chúa trước — Ngài ban cách rộng rãi.',
  ),
  BibleVerse(
    refVi: 'Châm-ngôn 1:7',
    refEn: 'Proverbs 1:7',
    vi: 'Sự kính sợ Ðức Giê-hô-va là khởi đầu sự tri thức; còn kẻ ngu muội '
        'khinh bỉ sự khôn ngoan và lời khuyên dạy.',
    en: 'The fear of the LORD is the beginning of knowledge: but fools despise '
        'wisdom and instruction.',
    topic: BibleTopic.wisdom,
    reflection: 'Khôn ngoan thật bắt đầu từ lòng tôn kính Chúa.',
  ),
  BibleVerse(
    refVi: 'Châm-ngôn 16:3',
    refEn: 'Proverbs 16:3',
    vi: 'Hãy phó các việc mình cho Ðức Giê-hô-va, thì những mưu ý mình sẽ được '
        'thành công.',
    en: 'Commit thy works unto the LORD, and thy thoughts shall be '
        'established.',
    topic: BibleTopic.wisdom,
    reflection: 'Giao việc hôm nay cho Chúa trước khi bắt tay vào làm.',
  ),
  BibleVerse(
    refVi: 'Truyền-đạo 3:1',
    refEn: 'Ecclesiastes 3:1',
    vi: 'Phàm sự gì có thì tiết; mọi việc dưới trời có kỳ định.',
    en: 'To every thing there is a season, and a time to every purpose under '
        'the heaven.',
    topic: BibleTopic.wisdom,
    reflection: 'Mọi mùa đều có kỳ hạn của nó. Hãy tin vào thời điểm của Chúa.',
  ),

  // ── Dẫn dắt ────────────────────────────────────────────────────────────
  BibleVerse(
    refVi: 'Thi-thiên 119:105',
    refEn: 'Psalm 119:105',
    vi: 'Lời Chúa là ngọn đèn cho chân tôi, ánh sáng cho đường lối tôi.',
    en: 'Thy word is a lamp unto my feet, and a light unto my path.',
    topic: BibleTopic.guidance,
    reflection: 'Lời Chúa soi đủ một bước — cứ đi, ánh sáng sẽ soi bước kế '
        'tiếp.',
  ),
  BibleVerse(
    refVi: 'Thi-thiên 32:8',
    refEn: 'Psalm 32:8',
    vi: 'Ta sẽ dạy dỗ ngươi, chỉ cho ngươi con đường phải đi; mắt ta sẽ chăm '
        'chú ngươi mà khuyên dạy ngươi.',
    en: 'I will instruct thee and teach thee in the way which thou shalt go: '
        'I will guide thee with mine eye.',
    topic: BibleTopic.guidance,
    reflection: 'Chúa không bỏ bạn tự dò đường — Ngài đích thân chỉ lối.',
  ),
  BibleVerse(
    refVi: 'Ê-sai 30:21',
    refEn: 'Isaiah 30:21',
    vi: 'Khi các ngươi xê qua bên hữu hoặc bên tả, tai các ngươi sẽ nghe có '
        'tiếng đằng sau mình rằng: Nầy là đường đây, hãy noi theo!',
    en: 'And thine ears shall hear a word behind thee, saying, This is the '
        'way, walk ye in it, when ye turn to the right hand, and when ye turn '
        'to the left.',
    topic: BibleTopic.guidance,
    reflection: 'Lắng nghe — Chúa vẫn hướng dẫn từng ngã rẽ của bạn.',
  ),
  BibleVerse(
    refVi: 'Thi-thiên 37:5',
    refEn: 'Psalm 37:5',
    vi: 'Hãy phó thác đường lối mình cho Ðức Giê-hô-va, và nhờ cậy nơi Ngài, '
        'thì Ngài sẽ làm thành việc ấy.',
    en: 'Commit thy way unto the LORD; trust also in him; and he shall bring '
        'it to pass.',
    topic: BibleTopic.guidance,
    reflection: 'Giao con đường cho Chúa, rồi bước đi trong tin cậy.',
  ),

  // ── Tạ ơn ──────────────────────────────────────────────────────────────
  BibleVerse(
    refVi: 'Thi-thiên 118:24',
    refEn: 'Psalm 118:24',
    vi: 'Nầy là ngày Ðức Giê-hô-va làm nên, chúng tôi sẽ mừng rỡ và vui vẻ '
        'trong ngày ấy.',
    en: 'This is the day which the LORD hath made; we will rejoice and be glad '
        'in it.',
    topic: BibleTopic.gratitude,
    reflection: 'Hôm nay là món quà. Hãy nhận lấy nó với lòng vui mừng.',
  ),
  BibleVerse(
    refVi: 'I Tê-sa-lô-ni-ca 5:16-18',
    refEn: '1 Thessalonians 5:16-18',
    vi: 'Hãy vui mừng mãi mãi, cầu nguyện không thôi, phàm việc gì cũng phải '
        'tạ ơn Chúa; vì ý muốn của Ðức Chúa Trời trong Ðức Chúa Jêsus Christ '
        'đối với anh em là như vậy.',
    en: 'Rejoice evermore. Pray without ceasing. In every thing give thanks: '
        'for this is the will of God in Christ Jesus concerning you.',
    topic: BibleTopic.gratitude,
    reflection: 'Tạ ơn không phải vì mọi sự đều tốt, mà vì Chúa tốt lành trong '
        'mọi sự.',
  ),
  BibleVerse(
    refVi: 'Thi-thiên 100:4',
    refEn: 'Psalm 100:4',
    vi: 'Hãy cảm tạ mà vào các cửa Ngài, hãy ngợi khen mà vào hành lang Ngài; '
        'khá cảm tạ Ngài, chúc tụng danh của Ngài.',
    en: 'Enter into his gates with thanksgiving, and into his courts with '
        'praise: be thankful unto him, and bless his name.',
    topic: BibleTopic.gratitude,
    reflection: 'Bắt đầu ngày mới bằng lòng biết ơn — nó đổi cả góc nhìn.',
  ),
  BibleVerse(
    refVi: 'Thi-thiên 103:2',
    refEn: 'Psalm 103:2',
    vi: 'Hỡi linh hồn ta, khá ngợi khen Ðức Giê-hô-va, chớ quên các ân huệ '
        'của Ngài.',
    en: 'Bless the LORD, O my soul, and forget not all his benefits.',
    topic: BibleTopic.gratitude,
    reflection: 'Kể lại những ơn lành đã nhận — đừng để quên lãng đánh cắp '
        'niềm vui.',
  ),

  // ── Tha thứ ────────────────────────────────────────────────────────────
  BibleVerse(
    refVi: 'I Giăng 1:9',
    refEn: '1 John 1:9',
    vi: 'Còn nếu chúng ta xưng tội mình, thì Ngài là thành tín công bình để '
        'tha tội cho chúng ta, và làm cho chúng ta sạch mọi điều gian ác.',
    en: 'If we confess our sins, he is faithful and just to forgive us our '
        'sins, and to cleanse us from all unrighteousness.',
    topic: BibleTopic.forgiveness,
    reflection: 'Không lỗi lầm nào quá lớn cho ơn tha thứ của Chúa.',
  ),
  BibleVerse(
    refVi: 'Ê-phê-sô 4:32',
    refEn: 'Ephesians 4:32',
    vi: 'Hãy ở với nhau cách nhân từ, đầy dẫy lòng thương xót, tha thứ nhau '
        'như Ðức Chúa Trời đã tha thứ anh em trong Ðấng Christ vậy.',
    en: 'And be ye kind one to another, tenderhearted, forgiving one another, '
        'even as God for Christ\'s sake hath forgiven you.',
    topic: BibleTopic.forgiveness,
    reflection: 'Bạn tha thứ được, vì bạn đã được tha thứ nhiều hơn.',
  ),
  BibleVerse(
    refVi: 'Thi-thiên 103:12',
    refEn: 'Psalm 103:12',
    vi: 'Phương đông xa cách phương tây bao nhiêu, thì Ngài đã đem sự vi phạm '
        'chúng tôi khỏi xa chúng tôi bấy nhiêu.',
    en: 'As far as the east is from the west, so far hath he removed our '
        'transgressions from us.',
    topic: BibleTopic.forgiveness,
    reflection: 'Điều Chúa đã tha, đừng nhặt lên lại. Nó đã đi thật xa rồi.',
  ),
  BibleVerse(
    refVi: 'Cô-lô-se 3:13',
    refEn: 'Colossians 3:13',
    vi: 'Nếu một người trong anh em có sự gì phàn nàn với kẻ khác, thì hãy '
        'nhường nhịn nhau và tha thứ nhau: như Chúa đã tha thứ anh em thể '
        'nào, thì anh em cũng phải tha thứ thể ấy.',
    en: 'Forbearing one another, and forgiving one another, if any man have a '
        'quarrel against any: even as Christ forgave you, so also do ye.',
    topic: BibleTopic.forgiveness,
    reflection: 'Tha thứ là món quà bạn cũng tự trao cho chính mình.',
  ),
];

/// Verses filtered to a single [topic].
List<BibleVerse> versesForTopic(BibleTopic topic) =>
    bibleVerses.where((v) => v.topic == topic).toList(growable: false);

/// Look up a verse by its stable [BibleVerse.id]; null if unknown.
BibleVerse? verseById(String id) {
  for (final v in bibleVerses) {
    if (v.id == id) return v;
  }
  return null;
}

/// The deterministic "verse of the day": stable through the whole calendar day,
/// advancing by one each day and cycling through the entire library. Using the
/// day count since the Unix epoch keeps it independent of time zone drift within
/// a day.
BibleVerse verseOfDay([DateTime? now]) {
  final date = now ?? DateTime.now();
  final daysSinceEpoch =
      DateTime(date.year, date.month, date.day).millisecondsSinceEpoch ~/
          Duration.millisecondsPerDay;
  final index = daysSinceEpoch % bibleVerses.length;
  return bibleVerses[index];
}

/// Short, honest provenance note shown on the screen — mirrors the app's habit
/// of citing where its content comes from (see the Tax hub).
const String bibleSourceNote =
    'Bản tiếng Việt tham khảo Bản Truyền Thống (1926); bản tiếng Anh là King '
    'James Version. Cả hai đều thuộc phạm vi công cộng. Suy niệm là lời gợi ý, '
    'không phải Kinh Thánh — hãy tra cứu trọn văn cảnh trong một quyển Kinh '
    'Thánh đầy đủ.';
