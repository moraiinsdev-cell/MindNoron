/// Curated, offline tax reference for a Vietnamese freelancer billing foreign
/// clients — the regulations in force from 1/7/2025 and 1/1/2026, plus legal
/// ways to reduce the bill. All content is static (no LLM, no network), written
/// to be read alongside, not instead of, a licensed advisor.
///
/// ⚠️ Tối ưu thuế HỢP PHÁP only: dùng đúng ngưỡng miễn thuế, thuế suất 0% cho
/// dịch vụ xuất khẩu, giảm trừ gia cảnh, chọn hình thức đăng ký phù hợp. Đây
/// KHÔNG phải là hướng dẫn giấu doanh thu hay không kê khai tiền từ nước ngoài
/// — những việc đó là trốn thuế và rủi ro rất cao.
library;

/// A regulation / knowledge card.
class TaxNote {
  const TaxNote({
    required this.icon,
    required this.title,
    required this.body,
    this.effective,
    this.source,
  });

  final String icon;
  final String title;
  final String body;

  /// When it takes effect, e.g. '1/1/2026'. Null = background/ongoing rule.
  final String? effective;

  /// The legal instrument this comes from, e.g. 'Điều 200 BLHS 2015 (sđ 2017)'.
  /// Anything that states a penalty, a rate or a threshold MUST cite one — a
  /// number without a source is not something a user can act on or verify.
  final String? source;
}

/// A legal optimization strategy card.
class TaxStrategy {
  const TaxStrategy({
    required this.icon,
    required this.title,
    required this.summary,
    required this.steps,
  });

  final String icon;
  final String title;
  final String summary;
  final List<String> steps;
}

/// A statutory tax deadline, materialised for a specific year so it can be
/// dropped onto the Calendar as an all-day reminder.
class TaxDeadline {
  const TaxDeadline({
    required this.date,
    required this.title,
    required this.detail,
  });

  final DateTime date;
  final String title;
  final String detail;
}

/// The key filing deadlines that fall within calendar [year] for an individual
/// who self-declares (quarterly declaration + annual PIT finalisation). Dates
/// follow the general rule (quý: cuối tháng đầu quý sau; quyết toán: cuối tháng
/// thứ 4); if a date lands on a holiday it rolls to the next working day.
List<TaxDeadline> taxDeadlines(int year) => [
      TaxDeadline(
        date: DateTime(year, 1, 31),
        title: '[Thuế] Hạn khai thuế Quý 4/${year - 1}',
        detail: 'Hạn nộp tờ khai & tiền thuế Quý 4 năm ${year - 1} '
            '(nếu khai theo quý).',
      ),
      TaxDeadline(
        date: DateTime(year, 4, 30),
        title: '[Thuế] Quyết toán TNCN năm ${year - 1} + khai Quý 1',
        detail: 'Hạn quyết toán thuế TNCN năm ${year - 1} và khai thuế '
            'Quý 1/$year. Chuẩn bị chứng từ thu nhập, người phụ thuộc, thuế đã '
            'nộp ở nước ngoài (nếu có).',
      ),
      TaxDeadline(
        date: DateTime(year, 7, 31),
        title: '[Thuế] Hạn khai thuế Quý 2/$year',
        detail: 'Hạn nộp tờ khai & tiền thuế Quý 2/$year (nếu khai theo quý).',
      ),
      TaxDeadline(
        date: DateTime(year, 10, 31),
        title: '[Thuế] Hạn khai thuế Quý 3/$year',
        detail: 'Hạn nộp tờ khai & tiền thuế Quý 3/$year (nếu khai theo quý).',
      ),
    ];

/// Compliance risk band for a given approach.
enum RiskLevel {
  safe, // 🟢 hợp pháp, chỉ cần làm đúng + giữ chứng từ
  grey, // 🟡 vùng xám: hợp pháp nếu đúng thực chất, sai một chút thành trốn thuế
  illegal; // 🔴 trốn thuế — rủi ro truy thu + phạt + hình sự

  String get emoji => switch (this) {
        RiskLevel.safe => '🟢',
        RiskLevel.grey => '🟡',
        RiskLevel.illegal => '🔴',
      };

  String get label => switch (this) {
        RiskLevel.safe => 'Hợp pháp',
        RiskLevel.grey => 'Vùng xám',
        RiskLevel.illegal => 'Trốn thuế — không nên',
      };
}

/// An approach to reducing tax, honestly rated by legal risk. The point of the
/// list is to draw the line clearly: what is safe, what needs care, and what is
/// outright evasion (with the penalty attached), so the user optimizes legally.
class TaxRiskItem {
  const TaxRiskItem({
    required this.level,
    required this.title,
    required this.what,
    required this.consequence,
    this.source,
  });

  final RiskLevel level;
  final String title;
  final String what;

  /// For safe items: how to keep it defensible. For illegal: the penalty, with
  /// the actual figures — a vague "có thể bị xử lý hình sự" tells the user
  /// nothing about where they stand.
  final String consequence;

  /// The legal instrument behind [consequence].
  final String? source;
}

const taxRisks = <TaxRiskItem>[
  TaxRiskItem(
    level: RiskLevel.safe,
    title: 'Đăng ký cá nhân kinh doanh dịch vụ xuất khẩu (VAT 0% + 2%)',
    what:
        'Khai đúng bản chất công việc là dịch vụ cho khách nước ngoài, tiêu '
        'dùng ngoài VN. Đây là ưu đãi luật cho, không phải lách.',
    consequence:
        'An toàn nếu giữ hợp đồng, invoice, sao kê thanh toán quốc tế chứng '
        'minh dịch vụ xuất khẩu.',
  ),
  TaxRiskItem(
    level: RiskLevel.safe,
    title: 'Tận dụng ngưỡng miễn thuế 500 triệu/năm & giảm trừ gia cảnh',
    what:
        'Doanh thu ≤ 500tr/năm được miễn; đăng ký đủ người phụ thuộc để giảm '
        'thu nhập tính thuế.',
    consequence:
        'Hoàn toàn hợp pháp. Chỉ cần kê khai trung thực và đăng ký người phụ '
        'thuộc đúng điều kiện.',
  ),
  TaxRiskItem(
    level: RiskLevel.safe,
    title: 'Áp dụng hiệp định tránh đánh thuế hai lần (DTA)',
    what:
        'Xin khấu trừ phần thuế đã nộp ở nước ngoài theo hiệp định để không '
        'nộp trùng.',
    consequence:
        'Hợp pháp; cần chứng từ khấu trừ thuế nước ngoài và hồ sơ áp dụng hiệp '
        'định khi quyết toán.',
  ),
  TaxRiskItem(
    level: RiskLevel.grey,
    title: 'Để Robux tồn trong tài khoản, DevEx sang năm sau',
    what:
        'Chưa cash-out thì chưa có USD về, nên chưa ghi nhận doanh thu. Hợp '
        'pháp nếu bạn thực sự chưa rút và ghi nhận nhất quán theo tiền thực '
        'nhận qua các năm.',
    consequence:
        'Chỉ HOÃN chứ không xóa thuế — khi rút vẫn phải khai. Rủi ro thêm: rate '
        'DevEx hoặc chính sách Roblox đổi, và nếu năm sau bạn dồn hai năm doanh '
        'thu vào một năm thì có thể vọt qua ngưỡng, thuế còn cao hơn. Đừng đổi '
        'cách ghi nhận qua lại từng năm cho tiện — đó là dấu hiệu bị soi.',
  ),
  TaxRiskItem(
    level: RiskLevel.grey,
    title: 'Nhận Robux vào tài khoản Roblox của bạn bè / nhóm rồi chia lại',
    what:
        'Group payout hoặc nhờ người khác giữ hộ Robux. Chỉ hợp pháp nếu người '
        'đó THỰC SỰ tham gia dự án và nhận đúng phần việc của họ.',
    consequence:
        'Nếu chỉ mượn tài khoản để chia nhỏ doanh thu → là che giấu doanh thu, '
        'bị coi là trốn thuế. Ngoài ra còn vi phạm ToS của Roblox, có thể bị '
        'khóa tài khoản và mất toàn bộ Robux — mất nhiều hơn số thuế né được.',
  ),
  TaxRiskItem(
    level: RiskLevel.grey,
    title: 'Chia doanh thu qua nhiều người/hộ để ở dưới ngưỡng',
    what:
        'Phân bổ doanh thu giữa các thành viên gia đình cùng làm. Chỉ hợp pháp '
        'nếu MỖI người thực sự tham gia và nhận đúng phần việc của mình.',
    consequence:
        'Nếu là chia khống (người kia không thực làm) → bị coi là trốn thuế, '
        'truy thu + phạt. Ranh giới rất mong manh, cần tư vấn đại lý thuế.',
  ),
  TaxRiskItem(
    level: RiskLevel.grey,
    title: 'Giữ doanh thu quanh mốc 500tr để né bậc thuế',
    what:
        'Điều tiết thời điểm nhận tiền/xuất hóa đơn giữa các năm. Hợp pháp nếu '
        'phản ánh đúng thời điểm hoàn thành dịch vụ.',
    consequence:
        'Dời doanh thu sang năm sau một cách giả tạo (đã hoàn thành nhưng ghi '
        'nhận muộn) là sai lệch kỳ kê khai → rủi ro bị điều chỉnh + phạt.',
  ),
  TaxRiskItem(
    level: RiskLevel.illegal,
    title: 'Không kê khai / khai thiếu tiền nhận từ nước ngoài',
    what:
        'Nhận tiền về tài khoản nhưng không khai, hoặc chỉ khai một phần.',
    consequence:
        'TRỐN THUẾ. Cơ quan thuế có quyền yêu cầu ngân hàng cung cấp sao kê, '
        'nên dòng tiền PayPal về VN đối chiếu được. Hậu quả cụ thể: truy thu đủ '
        'số thuế + phạt 1–3 lần số thuế trốn + tiền chậm nộp 0,03%/ngày. Nếu số '
        'thuế trốn từ 100 TRIỆU trở lên → chuyển sang hình sự: 100–300 triệu bị '
        'phạt tù 3 tháng–1 năm; 300 triệu–dưới 1 tỷ: tù 1–3 năm; từ 1 tỷ: tù '
        '2–7 năm (hoặc phạt tiền tương ứng). Với mức 2% dịch vụ xuất khẩu, 100 '
        'triệu tiền thuế tương ứng khoảng 5 tỷ doanh thu giấu — nhưng nếu bạn bị '
        'ép khai theo lũy tiến 35% thì ngưỡng đó đến nhanh hơn nhiều.',
    source: 'NĐ 125/2020 Điều 17; Điều 200 BLHS 2015 (sđ 2017); '
        'Luật QLT 38/2019 Điều 59, 98',
  ),
  TaxRiskItem(
    level: RiskLevel.illegal,
    title: 'Nhận tiền qua tài khoản người khác / ví lạ để giấu nguồn',
    what:
        'Dùng tài khoản người thân, ví điện tử nước ngoài hay crypto để tiền '
        'không hiện trên tài khoản của mình.',
    consequence:
        'TRỐN THUẾ (phạt 1–3 lần số thuế trốn; từ 100 triệu tiền thuế trốn là '
        'ngưỡng hình sự theo Điều 200 BLHS) và có thể vi phạm quy định ngoại '
        'hối, chống rửa tiền. Rủi ro pháp lý cao hơn nhiều so với số thuế tiết '
        'kiệm được — không đáng.',
    source: 'NĐ 125/2020 Điều 17; Điều 200 BLHS; Pháp lệnh Ngoại hối; '
        'Luật Phòng, chống rửa tiền 2022',
  ),
  TaxRiskItem(
    level: RiskLevel.illegal,
    title: 'Bán Robux "chợ đen" / trao đổi ngoài nền tảng để tiền không lộ',
    what:
        'Bán Robux cho người khác lấy tiền mặt, chuyển qua ví/crypto, hoặc nhận '
        'thanh toán vòng qua bên thứ ba thay vì DevEx chính thức.',
    consequence:
        'TRỐN THUẾ, cộng thêm vi phạm điều khoản Roblox (khóa tài khoản vĩnh '
        'viễn, mất sạch Robux) và có thể chạm quy định ngoại hối/rửa tiền. Đây '
        'là cách nhanh nhất để mất cả nghề lẫn tiền — không đáng với vài phần '
        'trăm thuế.',
  ),
  TaxRiskItem(
    level: RiskLevel.illegal,
    title: 'Lập hóa đơn/chi phí khống để giảm thu nhập tính thuế',
    what:
        'Mua hóa đơn, kê chi phí không có thật để giảm lợi nhuận chịu thuế.',
    consequence:
        'TRỐN THUẾ + vi phạm về hóa đơn. Chi phí bị loại, truy thu thuế, phạt '
        '1–3 lần số thuế trốn. Riêng hành vi mua bán hóa đơn trái phép còn là '
        'tội độc lập: phạt tiền 50–200 triệu, cải tạo không giam giữ đến 3 năm '
        'hoặc tù 6 tháng–5 năm (Điều 203 BLHS).',
    source: 'NĐ 125/2020 Điều 17; Điều 200 & Điều 203 BLHS 2015 (sđ 2017)',
  ),
];

/// Penalties & audit triggers — with the actual numbers and where they come
/// from. "Số tiền lớn thì đi tù" is useless advice; the thresholds below are
/// exact, so you can see precisely how far the line is from where you stand.
const taxPenalties = <TaxNote>[
  TaxNote(
    icon: '⏰',
    title: 'Chậm nộp TIỀN thuế → 0,03%/ngày',
    body:
        'Tiền chậm nộp = 0,03%/ngày × số thuế nộp muộn (≈ 10,95%/năm). Tính '
        'liên tục từ ngày kế tiếp hạn nộp cho tới ngày nộp thật. Ví dụ: chậm '
        '10 triệu tiền thuế trong 90 ngày → 270.000 ₫. Không có mức trần theo '
        'thời gian, nên để càng lâu càng đắt.',
    effective: 'Hiện hành',
    source: 'Luật Quản lý thuế 38/2019/QH14, Điều 59 khoản 2',
  ),
  TaxNote(
    icon: '📄',
    title: 'Chậm nộp HỒ SƠ khai thuế → 2 đến 25 triệu',
    body:
        'Phạt theo số ngày trễ, độc lập với tiền thuế: cảnh cáo (trễ 1–5 ngày '
        'và có tình tiết giảm nhẹ); 2–5 triệu (trễ 1–30 ngày); 5–8 triệu (31–60 '
        'ngày); 8–15 triệu (61–90 ngày, hoặc trễ trên 90 ngày mà không phát sinh '
        'thuế phải nộp); 15–25 triệu (trễ trên 90 ngày VÀ có thuế phải nộp). '
        'Nghĩa là quên nộp tờ khai vẫn bị phạt kể cả khi bạn không nợ đồng thuế nào.',
    effective: 'Hiện hành',
    source: 'Nghị định 125/2020/NĐ-CP, Điều 13',
  ),
  TaxNote(
    icon: '📉',
    title: 'Khai sai dẫn đến thiếu thuế → phạt 20% số thuế thiếu',
    body:
        'Áp dụng khi khai sai nhưng KHÔNG bị coi là trốn thuế (ví dụ ghi nhầm, '
        'quên một khoản, nhưng nghiệp vụ vẫn phản ánh trên sổ sách/chứng từ). '
        'Phải nộp đủ số thuế thiếu + 20% phạt + tiền chậm nộp 0,03%/ngày trên '
        'phần thiếu. Đây là mức "nhẹ" — và là lý do khai trung thực rồi sửa sau '
        'vẫn hơn hẳn giấu.',
    effective: 'Hiện hành',
    source: 'Nghị định 125/2020/NĐ-CP, Điều 16',
  ),
  TaxNote(
    icon: '⚠️',
    title: 'Trốn thuế — phạt hành chính 1 đến 3 lần số thuế trốn',
    body:
        'Mức phạt tăng theo tình tiết: 1 lần số thuế trốn (có ít nhất 1 tình '
        'tiết giảm nhẹ, không có tăng nặng); 1,5 lần (không tăng nặng, không '
        'giảm nhẹ); 2 lần (1 tình tiết tăng nặng); 2,5 lần (2 tình tiết); 3 lần '
        '(từ 3 tình tiết tăng nặng trở lên). Cộng thêm buộc nộp đủ số thuế trốn '
        'và tiền chậm nộp. Trốn 100 triệu, tình tiết trung bình → mất khoảng '
        '250 triệu.',
    effective: 'Hiện hành',
    source: 'Nghị định 125/2020/NĐ-CP, Điều 17',
  ),
  TaxNote(
    icon: '🚨',
    title: 'Trốn thuế — HÌNH SỰ: lằn ranh bắt đầu từ 100 triệu',
    body:
        'Đây là con số cụ thể của chữ "lớn". Khung hình phạt với cá nhân:\n\n'
        '• Trốn từ 100 triệu đến dưới 300 triệu → phạt tiền 100–500 triệu HOẶC '
        'phạt tù 3 tháng – 1 năm.\n'
        '• Từ 300 triệu đến dưới 1 tỷ (hoặc dưới 300 triệu nhưng có tình tiết '
        'tăng nặng: có tổ chức, phạm tội 2 lần trở lên, tái phạm nguy hiểm…) → '
        'phạt tiền 500 triệu – 1,5 tỷ HOẶC phạt tù 1 – 3 năm.\n'
        '• Từ 1 tỷ trở lên → phạt tiền 1,5 – 4,5 tỷ HOẶC phạt tù 2 – 7 năm.\n\n'
        'Dưới 100 triệu vẫn có thể bị xử lý hình sự NẾU đã từng bị xử phạt hành '
        'chính về trốn thuế, hoặc đã bị kết án về tội này (hay một số tội kinh '
        'tế khác) mà chưa được xóa án tích. Ngoài ra còn có thể bị phạt bổ sung '
        '20–100 triệu, cấm hành nghề 1–5 năm, tịch thu tài sản.',
    effective: 'Ngưỡng cần nhớ',
    source: 'Điều 200 Bộ luật Hình sự 2015, sửa đổi bổ sung 2017',
  ),
  TaxNote(
    icon: '⏳',
    title: 'Sai sót bị truy ngược bao xa? → 10 năm',
    body:
        'Thời hiệu xử phạt vi phạm hành chính về thuế (trốn thuế, khai thiếu) '
        'là 5 năm kể từ ngày thực hiện hành vi. NHƯNG nghĩa vụ truy thu tiền '
        'thuế và tiền chậm nộp thì tính tới 10 năm trở về trước. Nếu chưa đăng '
        'ký thuế thì bị truy thu không giới hạn thời gian. Nói cách khác: "để '
        'lâu cho nó qua" không phải là một chiến lược.',
    effective: 'Hiện hành',
    source: 'Luật Quản lý thuế 38/2019/QH14, Điều 8 & Điều 137; '
        'Nghị định 125/2020/NĐ-CP, Điều 8',
  ),
  TaxNote(
    icon: '🔍',
    title: 'Điều gì kích hoạt thanh tra',
    body:
        'Dòng tiền vào lớn/bất thường không khớp tờ khai; nhận nhiều lần từ '
        'nước ngoài mà không đăng ký thuế; kê khai giảm đột ngột so với các kỳ '
        'trước; ngành rủi ro cao. Cơ quan thuế được quyền yêu cầu ngân hàng cung '
        'cấp thông tin tài khoản và giao dịch của người nộp thuế — nên dòng tiền '
        'PayPal về ngân hàng VN không hề "vô hình". Hồ sơ sạch, khớp sao kê là '
        '"bảo hiểm" tốt nhất khi bị đối chiếu.',
    source: 'Luật Quản lý thuế 38/2019/QH14, Điều 27 & Điều 98 '
        '(nghĩa vụ cung cấp thông tin của ngân hàng thương mại)',
  ),
];

/// A closing note the risk tab shows under the penalty list: these are curated
/// summaries, and the law moves.
const penaltySourceNote =
    'Các mức phạt trên trích từ văn bản pháp luật hiện hành tại thời điểm biên '
    'soạn (2026). Đây là bản tóm tắt rút gọn, không thay thế văn bản gốc — tra '
    'toàn văn tại thuvienphapluat.vn hoặc cổng thông tin của Bộ Tài chính, và '
    'xác nhận với đại lý thuế trước khi dựa vào để ra quyết định.';

const taxDisclaimer =
    'Công cụ tham khảo, KHÔNG phải tư vấn thuế. Số liệu dựa trên quy định áp '
    'dụng từ 2026 và có thể thay đổi. Chỉ tối ưu thuế hợp pháp — luôn kê khai '
    'đầy đủ nguồn tiền từ nước ngoài và xác nhận với đại lý thuế/cơ quan thuế '
    'trước khi quyết toán.';

/// What changed, ordered newest/most-relevant first.
const taxNotes = <TaxNote>[
  TaxNote(
    icon: '🌍',
    title: 'Nhận tiền trực tiếp từ nước ngoài → bạn tự kê khai',
    effective: 'Hiện hành',
    body:
        'Khi khách nước ngoài trả tiền thẳng cho bạn (không qua tổ chức VN chi '
        'trả và khấu trừ), bạn là người phải tự đăng ký, kê khai và nộp thuế. '
        'Cá nhân có thu nhập từ tiền lương/tiền công do nước ngoài chi trả khai '
        'trực tiếp theo quý và quyết toán năm; hộ/cá nhân kinh doanh khai theo '
        'kỳ. Tiền về tài khoản ngân hàng VN đều để lại dấu vết — hãy kê khai '
        'đúng, đừng để thành truy thu + phạt sau này.',
  ),
  TaxNote(
    icon: '🧾',
    title: 'Bỏ thuế khoán với hộ/cá nhân kinh doanh',
    effective: '1/1/2026',
    body:
        'Phương pháp thuế khoán bị xóa bỏ. Hộ và cá nhân kinh doanh chuyển sang '
        'kê khai theo doanh thu thực tế và dùng hóa đơn điện tử (nhiều trường '
        'hợp là hóa đơn điện tử khởi tạo từ máy tính tiền). Nghĩa là phải ghi '
        'nhận doanh thu minh bạch — bù lại cách tính rõ ràng và có thể thấp hơn '
        'mức khoán cũ nếu doanh thu thật biến động.',
  ),
  TaxNote(
    icon: '📈',
    title: 'Ngưỡng miễn thuế nâng lên 500 triệu/năm',
    effective: '1/1/2026',
    body:
        'Doanh thu của hộ/cá nhân kinh doanh không phải nộp thuế GTGT & TNCN '
        'được nâng từ 100 triệu lên 500 triệu đồng/năm. Dưới ngưỡng này gần như '
        'không phát sinh thuế kinh doanh — một khoảng đệm lớn cho freelancer '
        'thu nhập vừa phải. Trên 500 triệu đến 3 tỷ: nộp theo phương pháp trực '
        'tiếp (% trên doanh thu).',
  ),
  TaxNote(
    icon: '👨‍👩‍👧',
    title: 'Giảm trừ gia cảnh tăng ~41%',
    effective: 'Kỳ tính thuế 2026',
    body:
        'Giảm trừ bản thân: 15,5 triệu/tháng (186 triệu/năm). Mỗi người phụ '
        'thuộc: 6,2 triệu/tháng (74,4 triệu/năm). Áp dụng cho thu nhập tính '
        'thuế theo tiền lương/tiền công (biểu lũy tiến) — KHÔNG áp dụng khi bạn '
        'nộp theo cá nhân kinh doanh 2% trên doanh thu. Đăng ký đầy đủ người '
        'phụ thuộc là cách giảm thuế đơn giản mà nhiều người quên (xem thẻ điều '
        'kiện bên dưới).',
    source: 'Nghị quyết về mức giảm trừ gia cảnh; Luật Thuế TNCN',
  ),
  TaxNote(
    icon: '🎂',
    title: '"Cha mẹ hết tuổi lao động" là bao nhiêu tuổi? — 2026: nam 61 tuổi '
        '6 tháng, nữ 57 tuổi',
    effective: 'Con số cụ thể',
    body:
        'Tuổi nghỉ hưu KHÔNG còn cố định 60/55 nữa — nó tăng dần theo lộ trình: '
        'nam mỗi năm +3 tháng (từ 60 tuổi 3 tháng năm 2021 đến đủ 62 tuổi vào '
        '2028); nữ mỗi năm +4 tháng (từ 55 tuổi 4 tháng năm 2021 đến đủ 60 tuổi '
        'vào 2035).\n\n'
        'Tra nhanh cho năm 2026: NAM 61 tuổi 6 tháng · NỮ 57 tuổi. '
        '(2027: nam 61t9m, nữ 57t4m. 2028: nam 62t, nữ 57t8m.)\n\n'
        'Nhưng tuổi CHƯA đủ — điều kiện thu nhập mới là thứ hay đánh trượt hồ sơ:\n'
        '• Cha mẹ NGOÀI độ tuổi lao động: phải không có thu nhập, HOẶC có thu '
        'nhập bình quân tháng từ mọi nguồn ≤ 1.000.000 ₫. Lương hưu, tiền cho '
        'thuê nhà, lãi tiết kiệm đều tính. Bố mẹ có lương hưu 3 triệu/tháng thì '
        'KHÔNG đủ điều kiện.\n'
        '• Cha mẹ TRONG độ tuổi lao động: phải đồng thời (a) bị khuyết tật, '
        'không có khả năng lao động, VÀ (b) thu nhập ≤ 1.000.000 ₫/tháng.\n'
        '• Con: dưới 18 tuổi (tính đủ theo tháng); hoặc từ 18 tuổi trở lên bị '
        'khuyết tật không có khả năng lao động; hoặc đang học đại học/cao đẳng/'
        'trung cấp/dạy nghề và có thu nhập ≤ 1.000.000 ₫/tháng.\n\n'
        'Lưu ý: mỗi người phụ thuộc chỉ được tính giảm trừ MỘT LẦN vào MỘT người '
        'nộp thuế trong năm — anh chị em không cùng khai một bố/mẹ.',
    source: 'Bộ luật Lao động 2019, Điều 169 (lộ trình tuổi nghỉ hưu) & Nghị '
        'định 135/2020/NĐ-CP; Thông tư 111/2013/TT-BTC, Điều 9 khoản 1.d '
        '(điều kiện người phụ thuộc)',
  ),
  TaxNote(
    icon: '💻',
    title: 'Dịch vụ xuất khẩu hưởng VAT 0%, phần mềm miễn VAT',
    effective: 'Luật GTGT sửa đổi',
    body:
        'Dịch vụ cung cấp cho tổ chức/cá nhân nước ngoài và tiêu dùng ngoài VN '
        'thuộc diện thuế suất GTGT 0%. Sản phẩm và dịch vụ phần mềm thuộc diện '
        'không chịu/miễn thuế GTGT. Với freelancer IT/thiết kế/nội dung làm cho '
        'khách ngoại, phần GTGT gần như bằng 0 — chỉ còn phần thuế TNCN.',
  ),
  TaxNote(
    icon: '🛒',
    title: 'Sàn TMĐT khấu trừ, nộp thuế thay',
    effective: '1/7/2025',
    body:
        'Theo Nghị định 117/2025, sàn thương mại điện tử (trong và ngoài nước) '
        'phải khấu trừ và nộp thay thuế cho hộ/cá nhân kinh doanh trên sàn: '
        'TNCN 0,5–5% và GTGT 1–5% tùy loại giao dịch. Nếu bạn nhận việc qua các '
        'nền tảng/marketplace, phần thuế có thể đã bị giữ lại — nhớ đối chiếu để '
        'không nộp trùng khi quyết toán.',
  ),
  TaxNote(
    icon: '🆔',
    title: 'Mã số định danh thay mã số thuế',
    effective: '1/7/2025',
    body:
        'Số định danh cá nhân (CCCD) chính thức thay cho mã số thuế trong giao '
        'dịch với cơ quan thuế. Thuận tiện khi đăng ký, kê khai, tra cứu trên '
        'thuedientu.gdt.gov.vn hoặc app eTax Mobile.',
  ),
  TaxNote(
    icon: '📅',
    title: 'Thời hạn kê khai & quyết toán',
    effective: 'Ghi nhớ',
    body:
        'Cá nhân tự quyết toán TNCN: chậm nhất là ngày cuối cùng của tháng thứ '
        '4 sau năm dương lịch (thường là 30/4, được gia hạn nếu trùng nghỉ lễ). '
        'Khai theo quý: chậm nhất ngày cuối tháng đầu của quý sau. Nộp muộn/thiếu '
        'bị tính tiền chậm nộp và có thể bị phạt — đặt nhắc lịch trước hạn.',
  ),
];

/// Legal ways to lower the bill on foreign income, strongest lever first.
const taxStrategies = <TaxStrategy>[
  TaxStrategy(
    icon: '🎯',
    title: 'Đăng ký cá nhân kinh doanh dịch vụ xuất khẩu (đòn bẩy lớn nhất)',
    summary:
        'Cùng một khoản thu từ nước ngoài: khai theo tiền lương chịu lũy tiến '
        'tới 35%; đăng ký cá nhân kinh doanh dịch vụ xuất khẩu chỉ ~2% (GTGT 0% '
        '+ TNCN 2%). Với thu nhập cao, chênh lệch là rất lớn — dùng tab "Máy '
        'tính" để so sánh bằng số của bạn.',
    steps: [
      'Xác định bản chất công việc là cung cấp dịch vụ cho khách nước ngoài, '
          'tiêu dùng ngoài VN (đủ điều kiện hưởng GTGT 0%).',
      'Đăng ký hộ/cá nhân kinh doanh với ngành nghề phù hợp tại phường/xã hoặc '
          'qua cổng dịch vụ công.',
      'Giữ hợp đồng, invoice, chứng từ thanh toán qua ngân hàng để chứng minh '
          'dịch vụ xuất khẩu.',
      'Kê khai theo phương pháp trực tiếp; xuất hóa đơn điện tử theo quy định '
          'mới từ 2026.',
    ],
  ),
  TaxStrategy(
    icon: '💸',
    title: 'Báo giá "net" — đừng để phí PayPal + thuế ăn vào công của bạn',
    summary:
        'Với phương pháp 2%, thuế tính trên USD GỘP mà DevEx/PayPal trả, còn phí '
        'nhận tiền và chênh lệch tỷ giá (4–5%) thì bạn tự chịu và KHÔNG được '
        'trừ. Tổng cộng ~6–7% doanh thu biến mất trước khi bạn thấy tiền. Giải '
        'pháp không phải là né thuế — mà là đưa nó vào giá.',
    steps: [
      'Tính giá sàn: giá bạn muốn thực nhận ÷ (1 − phí% − thuế%). Ví dụ muốn '
          'net 1.000 USD với phí 4,4% và thuế 2% → báo ~1.070 USD.',
      'Ưu tiên gom payout thành đợt lớn thay vì rút lắt nhắt — phí cố định và '
          'ngưỡng tối thiểu 30.000 Robux khiến rút nhỏ rất đắt.',
      'Hỏi studio xem họ chịu phí chuyển tiền được không (nhiều studio lớn '
          'đồng ý) và ghi rõ "fees borne by payer" trong invoice.',
      'So sánh kênh nhận tiền: PayPal, Payoneer, wire — chênh 1–2% phí trên '
          'doanh thu năm là con số lớn hơn bạn nghĩ.',
    ],
  ),
  TaxStrategy(
    icon: '🏦',
    title: 'Quỹ thuế: tách tiền thuế ra khỏi tiền của bạn ngay khi nhận',
    summary:
        'Lý do freelancer "sốc thuế" cuối năm không phải vì thuế cao, mà vì đã '
        'tiêu mất phần tiền chưa bao giờ thuộc về mình. Mỗi lần DevEx/PayPal về, '
        'chuyển ngay phần thuế sang một tài khoản riêng — phần còn lại mới là '
        'thu nhập thật của bạn.',
    steps: [
      'Mở một tài khoản tiết kiệm riêng, đặt tên "QUY THUE" để không tiêu nhầm.',
      'Mỗi payout, trích đúng % mà tab "Doanh thu" gợi ý (thuế dự kiến + đệm an '
          'toàn) và chuyển ngay, trước khi tiêu bất cứ đồng nào.',
      'Khi doanh thu tiến gần 500 triệu, app tự nâng % trích — vì vượt ngưỡng '
          'thì thuế đánh trên TOÀN BỘ doanh thu, không chỉ phần vượt.',
      'Đến kỳ khai, nộp từ quỹ này. Tiền dư sau quyết toán mới là thưởng cho '
          'bạn — không phải tiền tiêu trước.',
    ],
  ),
  TaxStrategy(
    icon: '🧮',
    title: 'Tận dụng ngưỡng miễn thuế 500 triệu/năm',
    summary:
        'Doanh thu kinh doanh ≤ 500 triệu/năm không phát sinh thuế GTGT & TNCN. '
        'Nếu thu nhập của bạn quanh ngưỡng này, việc chọn đúng hình thức kê khai '
        'có thể đưa toàn bộ về diện miễn.',
    steps: [
      'Cộng dồn doanh thu cả năm dương lịch để biết mình ở dưới hay trên '
          'ngưỡng.',
      'Nếu là hộ gia đình, cân nhắc phân bổ hợp lý, đúng thực chất giữa các '
          'thành viên cùng tham gia kinh doanh (không được lập khống).',
      'Theo dõi doanh thu theo thời gian thực để không vô tình vượt ngưỡng vào '
          'cuối năm mà không chuẩn bị.',
    ],
  ),
  TaxStrategy(
    icon: '👨‍👩‍👧‍👦',
    title: 'Đăng ký đủ người phụ thuộc',
    summary:
        'Mỗi người phụ thuộc giảm 6,2 triệu/tháng (74,4 triệu/năm) khỏi thu '
        'nhập tính thuế. CẢNH BÁO QUAN TRỌNG: giảm trừ này CHỈ áp dụng cho cách '
        'khai theo tiền lương/tiền công (biểu lũy tiến). Nếu bạn đăng ký cá '
        'nhân kinh doanh nộp 2% trên doanh thu — phương án tối ưu cho hầu hết '
        'trường hợp — thì người phụ thuộc KHÔNG giảm được đồng thuế nào. Đừng '
        'chọn cách khai đắt hơn chỉ vì muốn dùng giảm trừ gia cảnh.',
    steps: [
      'Kiểm tra điều kiện chính xác: cha/mẹ ngoài tuổi lao động (2026: nam từ '
          '61 tuổi 6 tháng, nữ từ 57 tuổi) VÀ thu nhập bình quân ≤ 1.000.000 '
          '₫/tháng — lương hưu cũng tính vào ngưỡng này.',
      'Con dưới 18 tuổi thì mặc nhiên đủ; con trên 18 phải đang đi học và thu '
          'nhập ≤ 1.000.000 ₫/tháng.',
      'Chuẩn bị hồ sơ chứng minh quan hệ (giấy khai sinh, sổ hộ khẩu/CCCD) và '
          'điều kiện (xác nhận không có thu nhập của địa phương, giấy tờ khuyết '
          'tật nếu có).',
      'Đăng ký mẫu 20-ĐK-TCT qua thuedientu.gdt.gov.vn; mỗi người phụ thuộc chỉ '
          'được một người nộp thuế kê khai trong năm.',
      'Đăng ký sớm trong năm để được giảm trừ cho các tháng phát sinh; bổ sung '
          'khi quyết toán nếu còn thiếu.',
    ],
  ),
  TaxStrategy(
    icon: '💻',
    title: 'Cấu trúc công việc thành dịch vụ phần mềm / xuất khẩu',
    summary:
        'Sản phẩm & dịch vụ phần mềm không chịu GTGT; dịch vụ xuất khẩu hưởng '
        '0%. Mô tả và lập hóa đơn công việc đúng bản chất (lập trình, phát '
        'triển phần mềm, dịch vụ số cho khách ngoại) giúp phần GTGT về 0 một '
        'cách hợp pháp.',
    steps: [
      'Ghi rõ trong hợp đồng phạm vi là phát triển/cung cấp phần mềm hoặc dịch '
          'vụ số cho bên nước ngoài.',
      'Lưu bằng chứng nơi tiêu dùng dịch vụ là ngoài VN (khách hàng, máy chủ, '
          'người dùng cuối ở nước ngoài).',
      'Tách bạch phần dịch vụ phần mềm với phần hàng hóa/dịch vụ khác nếu có, '
          'để áp đúng thuế suất từng phần.',
    ],
  ),
  TaxStrategy(
    icon: '🌐',
    title: 'Tránh đánh thuế hai lần (Hiệp định thuế - DTA)',
    summary:
        'Việt Nam có hiệp định tránh đánh thuế hai lần với nhiều nước. Nếu thu '
        'nhập đã bị khấu trừ thuế ở nước ngoài, bạn có thể được khấu trừ tương '
        'ứng hoặc miễn theo hiệp định, tránh nộp trùng.',
    steps: [
      'Xác định quốc gia nguồn thu và kiểm tra có DTA với VN không.',
      'Xin chứng từ khấu trừ thuế tại nước ngoài (withholding statement) từ '
          'khách hàng/nền tảng.',
      'Nộp hồ sơ áp dụng hiệp định kèm quyết toán để được khấu trừ số thuế đã '
          'nộp ở nước ngoài.',
    ],
  ),
  TaxStrategy(
    icon: '📚',
    title: 'Ghi nhận chi phí hợp lệ (nếu kê khai theo lợi nhuận)',
    summary:
        'Khi áp dụng phương pháp kê khai theo thu nhập/lợi nhuận, các chi phí '
        'phục vụ công việc có hóa đơn hợp lệ được trừ khỏi doanh thu tính thuế: '
        'thiết bị, phần mềm, phí nền tảng, internet, thuê chỗ làm việc…',
    steps: [
      'Lấy hóa đơn điện tử/hợp lệ cho mọi chi phí liên quan công việc.',
      'Lưu chứng từ có hệ thống theo tháng (dùng tab Chi tiêu của app để đối '
          'chiếu).',
      'Chỉ khấu trừ chi phí thực tế, phục vụ trực tiếp hoạt động tạo ra doanh '
          'thu — không kê khống.',
    ],
  ),
  TaxStrategy(
    icon: '🏦',
    title: 'Minh bạch dòng tiền, giữ chứng từ',
    summary:
        'Tối ưu thuế bền vững đến từ hồ sơ sạch, không phải giấu tiền. Dòng '
        'tiền rõ ràng giúp bạn chứng minh đủ điều kiện hưởng 0%/2% và tránh bị '
        'ấn định thuế cao khi thanh tra.',
    steps: [
      'Nhận tiền qua tài khoản ngân hàng/kênh chính thức, ghi rõ nội dung.',
      'Lưu hợp đồng, invoice, sao kê khớp với tờ khai thuế.',
      'Kê khai đầy đủ, đúng hạn; đặt lịch nhắc quyết toán để không bị phạt chậm '
          'nộp.',
    ],
  ),
];
