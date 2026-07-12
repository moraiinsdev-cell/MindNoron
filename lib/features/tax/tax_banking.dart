/// Where the money physically lives: which bank receives it, which one holds
/// the tax that isn't yours, which one you spend from, and which one invests.
///
/// Two things this file is careful about:
///
/// 1. **Fees and rates move.** Anything numeric here is a *typical range to
///    verify*, never a quoted price. The durable value is the comparison
///    criteria and the questions to ask — not a fee table that rots.
/// 2. **A bank converting your USD is not a tax authority withholding tax.**
///    That confusion is the single most expensive misunderstanding a freelancer
///    receiving foreign money can have, so it gets the top card.
///
/// Offline and curated — no LLM, no network.
library;

/// The direct answer to: "DevEx trả về, tôi thấy tiền đi qua Vietcombank rồi
/// vào MBBank bằng VNĐ — vậy là đã bị khấu trừ thuế chưa?"
const withholdingAnswer =
    'KHÔNG. Đó là chuyển tiền, không phải khấu trừ thuế — và bạn vẫn phải tự '
    'kê khai đủ.\n\n'
    'Chuyện thật sự xảy ra: Roblox/PayPal gửi USD về Việt Nam. USD đi qua một '
    'ngân hàng trung gian có quan hệ đại lý (correspondent bank) — Vietcombank '
    'là một trong số ngân hàng hay đóng vai trò đó. Vì cá nhân nhận tiền dịch '
    'vụ từ nước ngoài không được giữ ngoại tệ tự do trên tài khoản thanh toán '
    'thông thường, ngân hàng BẮT BUỘC quy đổi sang VNĐ rồi mới ghi có vào tài '
    'khoản MBBank của bạn.\n\n'
    'Phần "hao" bạn thấy KHÔNG phải là thuế. Nó gồm: phí PayPal, phí chuyển '
    'tiền/điện phí, và quan trọng nhất là CHÊNH LỆCH TỶ GIÁ (ngân hàng mua USD '
    'của bạn theo giá mua vào, thấp hơn giá thị trường). Không đồng nào trong '
    'số đó chạy vào ngân sách nhà nước dưới danh nghĩa thuế của bạn, và bạn '
    'không có chứng từ khấu trừ thuế nào để trừ khi quyết toán.\n\n'
    'Khấu trừ tại nguồn CHỈ xảy ra khi một tổ chức chi trả (thường là công ty '
    'Việt Nam trả thù lao cho bạn) giữ lại thuế TNCN và nộp thay bạn — và họ '
    'phải đưa bạn chứng từ khấu trừ. Roblox không làm việc đó. Ngân hàng cũng '
    'không. Nên: tiền về = doanh thu chưa nộp thuế, nghĩa vụ khai vẫn nguyên.';

/// The trap that follows from the above: what you see in MBBank is NOT the
/// number to declare.
const taxBaseAnchor =
    'Doanh thu tính thuế NEO VÀO SỐ USD trên statement của DevEx/PayPal, không '
    'phải số VNĐ ghi có ở MBBank. Số VNĐ về tài khoản đã bị trừ phí PayPal và '
    'ăn chênh lệch tỷ giá — khai theo nó là bạn tự khai thiếu doanh thu. Hãy '
    'lấy số USD gộp, quy đổi theo tỷ giá MUA VÀO của ngân hàng nơi tiền về '
    '(MBBank) tại ngày nhận, và khai con số đó. Chênh lệch giữa hai số chính là '
    'chi phí — ghi nhận nó để biết kênh nào đang ăn của bạn nhiều nhất.';

/// One role in the account architecture. The point is separation: money with
/// different jobs should not sit in the same place, because it always gets spent.
class AccountRole {
  const AccountRole({
    required this.icon,
    required this.name,
    required this.job,
    required this.wants,
    required this.avoid,
  });

  final String icon;
  final String name;

  /// What this account is *for*.
  final String job;

  /// What to optimise the bank choice for, in this role.
  final List<String> wants;

  /// The failure mode this account exists to prevent.
  final String avoid;
}

const accountRoles = <AccountRole>[
  AccountRole(
    icon: '📥',
    name: '1. Tài khoản NHẬN (tiền nghề về đây)',
    job: 'Chỉ nhận tiền từ PayPal/DevEx và khách. Không tiêu, không quẹt thẻ, '
        'không liên kết ví. Đây là tài khoản mà sao kê của nó sẽ được đem ra '
        'đối chiếu với tờ khai thuế của bạn — nên nó phải sạch tuyệt đối.',
    wants: [
      'Nhận kiều hối/chuyển tiền quốc tế tốt, ít bị treo giao dịch.',
      'Tỷ giá mua vào USD tốt và công bố minh bạch (đây là khoản "phí ẩn" lớn '
          'nhất — hơn cả phí chuyển tiền).',
      'Sao kê xuất được PDF/Excel theo tháng, ghi rõ nội dung & tỷ giá quy đổi.',
      'Hỗ trợ liên kết PayPal ổn định.',
    ],
    avoid: 'Trộn tiền nghề với tiền cá nhân → sao kê rối, không chứng minh được '
        'doanh thu nào là của nghề khi bị thanh tra.',
  ),
  AccountRole(
    icon: '🏦',
    name: '2. Tài khoản QUỸ THUẾ (tiền không phải của bạn)',
    job: 'Mỗi lần tiền về, chuyển ngay % thuế sang đây. Đến kỳ khai quý thì rút '
        'ra nộp. Tuyệt đối không tiêu.',
    wants: [
      'Lãi suất tiền gửi không kỳ hạn / tiết kiệm linh hoạt tốt — tiền nằm chờ '
          'vài tháng thì nên sinh lãi.',
      'KHÔNG gắn thẻ ATM, không đăng nhập app thường xuyên — càng khó tiêu càng tốt.',
      'Rút được đúng ngày cần nộp thuế mà không mất lãi toàn bộ.',
    ],
    avoid: 'Tiêu vào tiền thuế rồi đến hạn phải đi vay để nộp — kèm tiền chậm '
        'nộp 0,03%/ngày nếu nộp trễ.',
  ),
  AccountRole(
    icon: '💳',
    name: '3. Tài khoản CHI TIÊU (lương tự trả cho mình)',
    job: 'Mỗi tháng tự trả cho mình một khoản cố định từ tài khoản NHẬN. Sống '
        'bằng số này. Thu nhập nghề freelance lên xuống thất thường, nhưng chi '
        'tiêu thì nên đều — đó là cách hết chao đảo.',
    wants: [
      'Miễn phí chuyển khoản, app tốt, thẻ dùng thoải mái.',
      'Hoàn tiền/ưu đãi thẻ nếu bạn chi nhiều qua thẻ.',
    ],
    avoid: 'Tháng nào kiếm nhiều thì tiêu nhiều, tháng ế thì cháy túi.',
  ),
  AccountRole(
    icon: '📈',
    name: '4. Tài khoản ĐỆM & ĐẦU TƯ (phần còn lại mới là của bạn)',
    job: 'Sau khi trích quỹ thuế và trả lương cho mình, phần dư mới thật sự là '
        'lợi nhuận. Ưu tiên: quỹ dự phòng 3–6 tháng chi phí sống trước, rồi mới '
        'đến đầu tư.',
    wants: [
      'Quỹ dự phòng: tiết kiệm kỳ hạn ngắn, rút được khi cần.',
      'Đầu tư: tài khoản chứng khoán/quỹ mở tách bạch, không dính tài khoản '
          'nhận tiền nghề.',
      'Nếu chưa có kinh nghiệm: chứng chỉ quỹ/ETF định kỳ đơn giản hơn cổ phiếu '
          'lẻ — và không tốn thời gian làm 3D.',
    ],
    avoid: 'Đầu tư bằng tiền thuế hoặc tiền quỹ dự phòng. Nghề freelance đã đủ '
        'rủi ro thu nhập rồi — đừng chồng thêm rủi ro tài sản lên trên.',
  ),
];

/// A way to get the money home. Fee figures are *ranges to verify*, because they
/// change and depend on your account tier and the sender.
class PayoutChannel {
  const PayoutChannel({
    required this.icon,
    required this.name,
    required this.how,
    required this.costHint,
    required this.pros,
    required this.cons,
  });

  final String icon;
  final String name;
  final String how;

  /// Typical all-in cost (fee + FX spread) as a % of the payout — to verify.
  final String costHint;
  final List<String> pros;
  final List<String> cons;
}

const payoutChannels = <PayoutChannel>[
  PayoutChannel(
    icon: '💸',
    name: 'PayPal → rút về ngân hàng VN',
    how: 'Kênh mặc định của DevEx và của phần lớn studio. USD vào ví PayPal, '
        'bạn rút về tài khoản VNĐ.',
    costHint: 'Tổng thường ~4–6% (phí nhận tiền quốc tế + chênh lệch tỷ giá khi '
        'PayPal/ngân hàng quy đổi). Chênh lệch tỷ giá thường ĐẮT hơn phí — đó là '
        'phần người ta hay quên đếm.',
    pros: [
      'Studio nào cũng dùng được, DevEx hỗ trợ sẵn.',
      'Có sao kê rõ ràng, dễ làm chứng từ thuế.',
    ],
    cons: [
      'Đắt nhất trong các kênh phổ biến.',
      'Có thể bị giữ/kiểm tra giao dịch nếu số tiền lớn bất thường.',
    ],
  ),
  PayoutChannel(
    icon: '🌐',
    name: 'Payoneer',
    how: 'Nhận USD vào tài khoản Payoneer rồi rút về ngân hàng VN. Nhiều nền '
        'tảng và studio hỗ trợ trả thẳng qua Payoneer.',
    costHint: 'Thường rẻ hơn PayPal một chút (phí rút + chênh lệch tỷ giá ~2–3%). '
        'Phải tự kiểm chứng theo biểu phí hiện hành và hạng tài khoản của bạn.',
    pros: [
      'Chi phí thường thấp hơn PayPal → giữ lại thêm vài % doanh thu.',
      'Giữ được số dư USD, chủ động chọn thời điểm quy đổi.',
    ],
    cons: [
      'Phải kiểm tra xem Roblox/Tipalti và studio của bạn có hỗ trợ không.',
      'Thêm một lớp trung gian → thêm một bộ sao kê phải lưu.',
    ],
  ),
  PayoutChannel(
    icon: '🏛️',
    name: 'Chuyển khoản quốc tế thẳng (SWIFT / wire)',
    how: 'Studio chuyển thẳng USD về tài khoản ngân hàng VN của bạn.',
    costHint: 'Phí cố định mỗi lệnh (thường vài chục USD, cả bên gửi và ngân '
        'hàng trung gian có thể thu) + chênh lệch tỷ giá. Rẻ tương đối khi số '
        'tiền LỚN, rất đắt khi số tiền nhỏ.',
    pros: [
      'Chứng từ đẹp nhất cho hồ sơ thuế: điện chuyển tiền ghi rõ người trả, nội dung.',
      'Không qua ví trung gian → ít rủi ro bị khóa tài khoản.',
    ],
    cons: [
      'Phí cố định giết các khoản nhỏ.',
      'Studio nhỏ thường ngại làm; cần nhiều thông tin (SWIFT code, địa chỉ).',
    ],
  ),
];

/// What to actually go and check — because the right answer depends on numbers
/// only the user can pull up, and a stale fee table in an app is worse than no
/// table at all.
const bankSelectionChecklist = <String>[
  'Hỏi/tra tỷ giá MUA VÀO USD của ngân hàng bạn định nhận tiền, so với vài ngân '
      'hàng khác trong cùng một ngày. Chênh 100–200 ₫/USD nghe nhỏ, nhưng trên '
      '20.000 USD/năm là vài triệu đồng.',
  'Hỏi phí nhận tiền từ nước ngoài (phí báo có / phí kiều hối) — có ngân hàng '
      'miễn, có nơi thu theo % kèm mức tối thiểu.',
  'Hỏi ngân hàng có cho phép NHẬN và GIỮ ngoại tệ trên tài khoản không, hay bắt '
      'buộc quy đổi VNĐ ngay (với thu nhập dịch vụ thì thường là bắt buộc quy đổi).',
  'Kiểm tra sao kê có ghi rõ tỷ giá quy đổi và nội dung chuyển tiền không — thiếu '
      'thông tin này thì hồ sơ thuế của bạn yếu đi.',
  'Thử một khoản NHỎ trước khi chuyển toàn bộ dòng tiền sang kênh/ngân hàng mới.',
  'Ghi lại chi phí thật của mỗi lần nhận (tab "Doanh thu" có ô phí) — sau 3–4 '
      'lần bạn sẽ biết chắc kênh nào rẻ hơn, thay vì đoán.',
];

/// The honest caveat that must sit under any bank comparison.
const bankDisclaimer =
    'App này offline nên KHÔNG tra được biểu phí và tỷ giá hiện hành. Các mức '
    'phí nêu trên là khoảng tham khảo để bạn biết đường mà hỏi, không phải báo '
    'giá. Biểu phí, tỷ giá và chính sách nhận ngoại tệ thay đổi thường xuyên và '
    'khác nhau theo từng ngân hàng, từng hạng tài khoản — hãy tự kiểm chứng trên '
    'website ngân hàng hoặc hỏi trực tiếp trước khi chuyển dòng tiền.';
