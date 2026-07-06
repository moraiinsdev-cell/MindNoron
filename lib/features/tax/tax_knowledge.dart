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
  });

  final String icon;
  final String title;
  final String body;

  /// When it takes effect, e.g. '1/1/2026'. Null = background/ongoing rule.
  final String? effective;
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
  });

  final RiskLevel level;
  final String title;
  final String what;

  /// For safe items: how to keep it defensible. For illegal: the penalty.
  final String consequence;
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
        'TRỐN THUẾ. Ngân hàng và cơ quan thuế đối chiếu được dòng tiền; bị '
        'truy thu + phạt 1–3 lần số thuế trốn + tiền chậm nộp, số lớn có thể bị '
        'truy cứu hình sự (Điều 200 BLHS).',
  ),
  TaxRiskItem(
    level: RiskLevel.illegal,
    title: 'Nhận tiền qua tài khoản người khác / ví lạ để giấu nguồn',
    what:
        'Dùng tài khoản người thân, ví điện tử nước ngoài hay crypto để tiền '
        'không hiện trên tài khoản của mình.',
    consequence:
        'TRỐN THUẾ và có thể vi phạm quy định ngoại hối/rửa tiền. Rủi ro pháp '
        'lý cao hơn nhiều so với số thuế tiết kiệm được — không đáng.',
  ),
  TaxRiskItem(
    level: RiskLevel.illegal,
    title: 'Lập hóa đơn/chi phí khống để giảm thu nhập tính thuế',
    what:
        'Mua hóa đơn, kê chi phí không có thật để giảm lợi nhuận chịu thuế.',
    consequence:
        'TRỐN THUẾ + vi phạm về hóa đơn. Bị loại chi phí, truy thu, phạt nặng '
        'và có thể xử lý hình sự.',
  ),
];

/// Penalties & audit triggers — the downside the risk tab quantifies.
const taxPenalties = <TaxNote>[
  TaxNote(
    icon: '⏰',
    title: 'Chậm nộp tiền thuế',
    body:
        'Tính tiền chậm nộp 0,03%/ngày trên số thuế nộp muộn (~10,95%/năm). '
        'Nộp đúng hạn gần như luôn rẻ hơn mọi mẹo trì hoãn.',
  ),
  TaxNote(
    icon: '📉',
    title: 'Khai sai dẫn đến thiếu thuế',
    body:
        'Phạt 20% trên số thuế khai thiếu, cộng tiền chậm nộp trên phần thiếu. '
        'Áp dụng cả khi "quên" chứ không chủ đích trốn.',
  ),
  TaxNote(
    icon: '🚨',
    title: 'Trốn thuế (hành chính & hình sự)',
    body:
        'Phạt từ 1 đến 3 lần số thuế trốn. Số tiền trốn lớn (theo ngưỡng Bộ '
        'luật Hình sự) có thể bị truy cứu trách nhiệm hình sự — phạt tù và cấm '
        'hành nghề. Đây là lằn ranh không nên thử.',
  ),
  TaxNote(
    icon: '🔍',
    title: 'Điều gì kích hoạt thanh tra',
    body:
        'Dòng tiền vào lớn/bất thường không khớp tờ khai; nhận nhiều lần từ '
        'nước ngoài mà không đăng ký thuế; kê khai giảm đột ngột; ngành rủi ro '
        'cao. Hồ sơ sạch, khớp sao kê là "bảo hiểm" tốt nhất khi bị đối chiếu.',
  ),
];

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
        'thuộc: 6,2 triệu/tháng. Áp dụng cho thu nhập tính thuế theo tiền '
        'lương/tiền công (biểu lũy tiến). Đăng ký đầy đủ người phụ thuộc (con, '
        'cha mẹ hết tuổi lao động/không thu nhập…) là cách giảm thuế đơn giản '
        'mà nhiều người quên.',
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
        'nhập tính thuế theo tiền lương. Con nhỏ, cha mẹ hết tuổi lao '
        'động/không có thu nhập, người bạn trực tiếp nuôi dưỡng… đều có thể là '
        'người phụ thuộc nếu đủ điều kiện.',
    steps: [
      'Chuẩn bị hồ sơ chứng minh quan hệ và điều kiện của người phụ thuộc.',
      'Đăng ký mẫu 20-ĐK-TCT (tờ khai đăng ký người phụ thuộc) qua '
          'thuedientu.gdt.gov.vn hoặc nơi làm việc.',
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
