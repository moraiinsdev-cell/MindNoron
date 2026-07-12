/// Offline, Roblox-specific tax reference for a Vietnamese 3D artist who sells
/// models/assets to Roblox game studios and gets paid in USD (PayPal) or in
/// Robux cashed out through DevEx.
///
/// This is the part of the Tax hub that knows *this* freelancer's money: how
/// Robux becomes dollars, which paperwork proves it, and where the money is
/// quietly lost. Curated content only — no LLM, no network.
///
/// ⚠️ Rates and platform rules move. Everything numeric here is also editable in
/// the calculator; re-check the DevEx page before relying on a figure.
library;

import 'tax_knowledge.dart' show TaxNote;

const robloxIntro =
    'Bạn làm 3D cho game Roblox và nhận tiền theo hai đường: USD trực tiếp từ '
    'studio qua PayPal, và Robux đổi ra USD qua DevEx. Cả hai đều là doanh thu '
    'từ nước ngoài và đều tính vào cùng một ngưỡng 500 triệu/năm — không có '
    'đường nào "vô hình" với cơ quan thuế, vì cuối cùng tiền vẫn phải về tài '
    'khoản ngân hàng Việt Nam của bạn.';

/// The mechanics + the tax consequences, ordered by how much money they move.
const robloxFacts = <TaxNote>[
  TaxNote(
    icon: '🧾',
    title: 'Thuế tính trên USD gộp, KHÔNG phải tiền về tay',
    effective: 'Quan trọng nhất',
    body:
        'Khi khai theo cá nhân kinh doanh (2%), thuế tính trên DOANH THU — tức '
        'số USD DevEx/PayPal trả cho bạn, trước khi PayPal trừ phí nhận tiền và '
        'ăn chênh lệch tỷ giá. Phí PayPal + phí quy đổi (thường 4–5%) KHÔNG được '
        'trừ khỏi doanh thu tính thuế ở phương pháp này. Nghĩa là bạn nộp thuế '
        'trên cả phần tiền chưa từng chạm tay. Hãy tính "giá net" khi báo giá '
        'cho studio, đừng để phí ăn vào lợi nhuận.',
  ),
  TaxNote(
    icon: '💱',
    title: 'DevEx: Robux → USD',
    effective: 'Kiểm tra rate hiện hành',
    body:
        'Rate DevEx công bố lâu nay là ~0,0035 USD/Robux (100.000 Robux ≈ 350 '
        'USD), tối thiểu 30.000 Robux mỗi lần rút và cần tài khoản đủ điều kiện '
        '(Premium, xác minh danh tính/email). Roblox có thể đổi rate — app để '
        'bạn tự sửa trong tab Máy tính. Lưu ý Robux bạn nhận ĐÃ là phần sau khi '
        'Roblox chia sẻ doanh thu, nên doanh thu của bạn là số USD DevEx trả, '
        'không phải giá bán item trên marketplace.',
  ),
  TaxNote(
    icon: '🇺🇸',
    title: 'Roblox là công ty Mỹ — mà VN–Mỹ chưa có hiệp định hiệu lực',
    effective: 'Đừng trông chờ DTA',
    body:
        'Hiệp định tránh đánh thuế hai lần Việt–Mỹ đã ký (2015) nhưng CHƯA có '
        'hiệu lực. Nếu Roblox/Mỹ có khấu trừ thuế tại nguồn, bạn không có cơ chế '
        'hiệp định để xin miễn/giảm như với Singapore hay Nhật. Vì vậy việc nộp '
        'W-8BEN (khai bạn là cá nhân nước ngoài, không phải US person) và mô tả '
        'đúng bản chất công việc là rất đáng giá — xem thẻ dưới.',
  ),
  TaxNote(
    icon: '⚖️',
    title: 'Dịch vụ hay tiền bản quyền? — khác nhau rất lớn',
    effective: 'Cách ghi hợp đồng',
    body:
        'Làm model theo đơn đặt hàng (commission) cho studio = DỊCH VỤ, thực '
        'hiện tại Việt Nam → thường không bị Mỹ khấu trừ tại nguồn, và ở VN là '
        'dịch vụ xuất khẩu (GTGT 0% + TNCN 2%). Ngược lại, cấp phép asset để ăn '
        '% doanh thu dài hạn dễ bị coi là TIỀN BẢN QUYỀN (royalty) — loại thu '
        'nhập này có thể bị khấu trừ tại nguồn ở Mỹ và ở VN được tính theo cách '
        'khác. Hãy ghi rõ trong hợp đồng/invoice: "3D modeling & asset creation '
        'services, performed in Vietnam, full ownership transferred on payment". '
        'Ranh giới này nên hỏi đại lý thuế nếu khoản tiền lớn.',
  ),
  TaxNote(
    icon: '⏳',
    title: 'Robux còn nằm trong tài khoản Roblox thì sao?',
    effective: 'Thời điểm ghi nhận',
    body:
        'Thực tế phổ biến và an toàn: ghi nhận doanh thu khi DevEx trả tiền về '
        '(cơ sở tiền thực nhận), vì đó là lúc có chứng từ USD rõ ràng. Việc để '
        'Robux tồn trong tài khoản làm CHẬM thời điểm ghi nhận, chứ không xóa '
        'nghĩa vụ thuế — khi cash out bạn vẫn phải khai. Đừng dùng nó như cách '
        'né thuế vĩnh viễn; nhưng dùng nó để điều tiết doanh thu giữa hai năm '
        'một cách trung thực là hợp lý (xem tab Rủi ro, mục vùng xám).',
  ),
  TaxNote(
    icon: '🏷️',
    title: 'Ngành nghề nên đăng ký',
    effective: 'Khi lập hộ/cá nhân KD',
    body:
        'Công việc của bạn khớp với "hoạt động thiết kế chuyên dụng" (thiết kế '
        'đồ họa/3D) và/hoặc "dịch vụ phần mềm, nội dung số". Khi khách hàng là '
        'tổ chức nước ngoài và sản phẩm được tiêu dùng ngoài VN, đây là dịch vụ '
        'xuất khẩu → GTGT 0%, TNCN 2%. Chọn đúng ngành khi đăng ký để phần GTGT '
        'không bị áp nhầm 5% như dịch vụ trong nước.',
  ),
  TaxNote(
    icon: '🧩',
    title: 'Gom hết mọi nguồn khi tính ngưỡng 500 triệu',
    effective: 'Dễ quên',
    body:
        'Commission trực tiếp (PayPal) + DevEx + bán UGC/asset trên Creator '
        'Store + group payout + job lẻ trong nước — tất cả cộng vào một ngưỡng '
        '500 triệu/năm của bạn. Nhiều freelancer chỉ nhớ nguồn lớn nhất rồi vô '
        'tình vượt ngưỡng. Tab "Doanh thu" tồn tại chính để cộng hộ bạn.',
  ),
  TaxNote(
    icon: '🏦',
    title: 'Đường tiền sạch: PayPal → ngân hàng VN, ghi rõ nội dung',
    effective: 'Bảo hiểm khi bị đối chiếu',
    body:
        'Rút PayPal về tài khoản ngân hàng chính chủ, nội dung ghi rõ kiểu '
        '"thanh toan dich vu thiet ke 3D". Doanh thu ngoại tệ quy đổi theo tỷ '
        'giá MUA VÀO của ngân hàng thương mại nơi bạn nhận tiền, tại thời điểm '
        'nhận. Ngân hàng và cơ quan thuế đối chiếu được dòng tiền — hồ sơ khớp '
        'sao kê là thứ bảo vệ bạn, không phải việc giấu.',
  ),
];

/// The evidence pack. If a tax officer ever asks "chứng minh đi", this is the
/// list — and every item is something the user can export today, not
/// reconstruct in a panic next April.
const robloxDocChecklist = <String>[
  'Hợp đồng / thỏa thuận với studio — kể cả khi chỉ chốt qua Discord hay '
      'Trello: xuất PDF, có scope, giá, ngày, tên bên thuê.',
  'Invoice bạn xuất cho khách (dù họ không đòi) — ghi rõ "3D modeling services '
      'performed in Vietnam", số tiền USD, ngày.',
  'Lịch sử DevEx trên Roblox (Transactions → DevEx): số Robux, số USD, ngày '
      'duyệt — chụp/xuất lại theo tháng.',
  'Sao kê PayPal hàng tháng (Activity → Statements) thể hiện tiền vào và phí.',
  'Sao kê ngân hàng VN thể hiện khoản rút về và tỷ giá quy đổi thực tế.',
  'W-8BEN đã nộp cho Roblox/Tipalti — bản lưu, để chứng minh bạn khai đúng tư '
      'cách cá nhân nước ngoài.',
  'Bảng đối chiếu theo tháng: Robux → USD → VNĐ (chính là tab "Doanh thu" của '
      'app — xuất báo cáo khi quyết toán).',
];

/// A deductible-expense catalogue written for a 3D artist specifically. These
/// only bite under a profit-based method (công ty TNHH / kê khai theo lợi
/// nhuận) — under the flat 2% method nothing here is deductible, which is
/// itself the point the calculator is making.
class ExpenseItem {
  const ExpenseItem({
    required this.icon,
    required this.name,
    required this.note,
  });

  final String icon;
  final String name;
  final String note;
}

const modelerExpenses = <ExpenseItem>[
  ExpenseItem(
    icon: '🖥️',
    name: 'Máy trạm, GPU, màn hình, bảng vẽ',
    note:
        'Tài sản phục vụ trực tiếp việc dựng model. Giá trị lớn thì phân bổ '
        'khấu hao theo năm thay vì trừ hết một lần.',
  ),
  ExpenseItem(
    icon: '🎨',
    name: 'Bản quyền phần mềm: Maya, 3ds Max, ZBrush, Substance, Marmoset',
    note:
        'Hóa đơn/biên lai subscription là chi phí hợp lệ. Blender miễn phí nên '
        'không có gì để trừ — đừng kê khống.',
  ),
  ExpenseItem(
    icon: '📦',
    name: 'Mua asset, texture, HDRI, plugin (Quixel, ArtStation, Gumroad…)',
    note: 'Nguyên liệu đầu vào của sản phẩm — giữ receipt email.',
  ),
  ExpenseItem(
    icon: '💸',
    name: 'Phí PayPal, phí DevEx, chênh lệch tỷ giá',
    note:
        'Chi phí thật và lớn (4–5%). CHỈ trừ được khi kê khai theo lợi nhuận; '
        'phương pháp 2% trực tiếp không cho trừ.',
  ),
  ExpenseItem(
    icon: '🌐',
    name: 'Internet, điện, thuê chỗ làm việc / coworking',
    note:
        'Nếu làm tại nhà, chỉ phân bổ phần thực sự dùng cho công việc — kê 100% '
        'tiền điện cả nhà là điểm dễ bị bác.',
  ),
  ExpenseItem(
    icon: '🎓',
    name: 'Khóa học, tài liệu chuyên môn, phí render farm',
    note: 'Phục vụ trực tiếp việc tạo doanh thu → hợp lệ nếu có hóa đơn.',
  ),
  ExpenseItem(
    icon: '📣',
    name: 'Phí quảng bá portfolio, phí nền tảng, hoa hồng môi giới',
    note: 'Chi phí bán hàng — giữ hợp đồng/biên lai với bên nhận tiền.',
  ),
];

/// The set-up sequence — what to actually go do, in order, to be both legal and
/// in control of the cash flow.
const robloxSetupSteps = <String>[
  'Chốt bản chất công việc: dịch vụ 3D cho khách nước ngoài, thực hiện tại VN. '
      'Ghi câu đó vào mọi hợp đồng và invoice.',
  'Nộp/ cập nhật W-8BEN trên Roblox (Tipalti) để không bị coi là US person.',
  'Đăng ký hộ/cá nhân kinh doanh, ngành thiết kế chuyên dụng / dịch vụ phần '
      'mềm — để hưởng dịch vụ xuất khẩu GTGT 0% + TNCN 2%.',
  'Mở một tài khoản ngân hàng RIÊNG chỉ để nhận tiền nghề — sao kê sạch, dễ '
      'đối chiếu, dễ chứng minh.',
  'Mở thêm một tài khoản tiết kiệm làm QUỸ THUẾ: mỗi lần tiền về, chuyển ngay '
      '% mà tab "Doanh thu" gợi ý sang đó. Không tiêu vào tiền thuế của người '
      'khác — nó chưa bao giờ là tiền của bạn.',
  'Ghi doanh thu vào app ngay khi DevEx/PayPal về, kèm số Robux và tỷ giá thực '
      'tế hôm đó.',
  'Đặt nhắc lịch khai quý & quyết toán (tab "Quy định" → nút Thêm) và nộp đúng '
      'hạn — tiền chậm nộp 0,03%/ngày đắt hơn mọi mẹo trì hoãn.',
];
