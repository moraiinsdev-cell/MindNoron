/// The answer to "khai theo tháng hay theo quý?" and the dated path from today
/// to a clean 31/12 — the part of the Tax hub that turns a pile of rules into a
/// sequence of things to actually do, each with a real deadline.
///
/// Everything is derived from a `DateTime` so the dates are live, not hardcoded.
/// Offline and curated — no LLM, no network.
library;

/// How often an individual has to file. The short answer for a freelancer:
/// **quý** (quarterly). Monthly filing is for businesses above the revenue
/// ceiling; per-occurrence filing is for one-off, irregular income.
class FilingOption {
  const FilingOption({
    required this.name,
    required this.who,
    required this.deadline,
    required this.appliesToYou,
  });

  final String name;
  final String who;
  final String deadline;

  /// True for the one this freelancer actually falls under.
  final bool appliesToYou;
}

const filingOptions = <FilingOption>[
  FilingOption(
    name: 'Khai theo QUÝ',
    who: 'Cá nhân/hộ kinh doanh kê khai, và cá nhân có thu nhập do nước ngoài '
        'chi trả (không có tổ chức VN khấu trừ thay) — tức là bạn.',
    deadline: 'Chậm nhất ngày cuối cùng của tháng đầu tiên của quý sau '
        '(31/1 · 30/4 · 31/7 · 31/10).',
    appliesToYou: true,
  ),
  FilingOption(
    name: 'Khai theo THÁNG',
    who: 'Chủ yếu dành cho doanh nghiệp/hộ kinh doanh có doanh thu năm trước '
        'trên ngưỡng lớn (mức phổ biến: trên 50 tỷ). Freelancer gần như không '
        'rơi vào diện này.',
    deadline: 'Chậm nhất ngày 20 của tháng sau.',
    appliesToYou: false,
  ),
  FilingOption(
    name: 'Khai theo TỪNG LẦN phát sinh',
    who: 'Thu nhập lẻ, không thường xuyên, không đăng ký kinh doanh. Nếu bạn '
        'nhận DevEx/PayPal đều đặn hàng tháng thì đây không phải diện của bạn.',
    deadline: 'Chậm nhất 10 ngày kể từ ngày phát sinh nghĩa vụ.',
    appliesToYou: false,
  ),
];

const filingFrequencyNote =
    'Bạn nhận tiền trực tiếp từ nước ngoài, đều đặn, không qua tổ chức VN nào '
    'khấu trừ thay → bạn TỰ khai, và khai theo QUÝ. Mỗi quý nộp tờ khai + tiền '
    'thuế của quý đó; hết năm làm thêm một lần QUYẾT TOÁN để chốt lại cả năm '
    '(bù trừ nếu nộp thừa/thiếu). Không có chuyện "cuối năm khai một lần cho '
    'gọn" — nộp muộn bị tính tiền chậm nộp 0,03%/ngày.';

/// Where a step sits in the arc: get set up → keep it clean → file on time →
/// close the year.
enum RoadmapPhase {
  setup,
  track,
  file,
  close;

  String get label => switch (this) {
        RoadmapPhase.setup => 'Giai đoạn 1 — Dựng nền (làm ngay)',
        RoadmapPhase.track => 'Giai đoạn 2 — Vận hành hằng tháng',
        RoadmapPhase.file => 'Giai đoạn 3 — Khai thuế đúng hạn',
        RoadmapPhase.close => 'Giai đoạn 4 — Chốt năm 2026',
      };

  String get blurb => switch (this) {
        RoadmapPhase.setup =>
          'Làm một lần, xong là yên. Chưa có mấy thứ này thì mọi tối ưu thuế '
              'đều đứng trên cát.',
        RoadmapPhase.track =>
          'Thói quen 5 phút mỗi lần tiền về. Đây là thứ quyết định bạn có kiểm '
              'soát được dòng tiền hay không.',
        RoadmapPhase.file =>
          'Có ngày cụ thể, có hạn cứng. Nộp đúng hạn gần như luôn rẻ hơn mọi '
              'mẹo trì hoãn.',
        RoadmapPhase.close =>
          'Quyết định cuối năm: nhận thêm việc hay dừng lại — và quyết toán.',
      };
}

/// One actionable step. [due] is null for habits that have no single deadline.
class RoadmapStep {
  const RoadmapStep({
    required this.id,
    required this.phase,
    required this.icon,
    required this.title,
    required this.why,
    required this.actions,
    this.due,
  });

  /// Stable id — persisted in the profile when the user ticks it off, so it must
  /// not change between releases.
  final String id;
  final RoadmapPhase phase;
  final String icon;
  final String title;

  /// The one-line reason this step exists, so it never feels like busywork.
  final String why;
  final List<String> actions;
  final DateTime? due;
}

/// The full path, with deadlines resolved against the year [now] falls in.
///
/// The filing steps deliberately run past 31/12: the year isn't really closed
/// until Q4 is filed (31/1) and the annual finalisation is in (30/4).
List<RoadmapStep> taxRoadmap(DateTime now) {
  final y = now.year;
  return [
    const RoadmapStep(
      id: 'register',
      phase: RoadmapPhase.setup,
      icon: '🪪',
      title: 'Đăng ký hộ/cá nhân kinh doanh (ngành thiết kế/dịch vụ phần mềm)',
      why: 'Đây là đòn bẩy lớn nhất: cùng một khoản tiền, khai theo tiền lương '
          'chịu lũy tiến tới 35%, còn cá nhân kinh doanh dịch vụ xuất khẩu chỉ '
          '~2%. Không đăng ký thì không được hưởng mức 2%.',
      actions: [
        'Nộp hồ sơ tại UBND phường/xã nơi cư trú hoặc qua cổng dịch vụ công.',
        'Chọn ngành: hoạt động thiết kế chuyên dụng (thiết kế đồ họa/3D) '
            'và/hoặc dịch vụ phần mềm, nội dung số.',
        'Dùng số định danh cá nhân (CCCD) — từ 1/7/2025 nó thay cho mã số thuế.',
        'Đăng ký phương pháp kê khai (thuế khoán đã bị bỏ từ 1/1/2026).',
      ],
    ),
    const RoadmapStep(
      id: 'w8ben',
      phase: RoadmapPhase.setup,
      icon: '🇺🇸',
      title: 'Nộp W-8BEN trên Roblox (Tipalti)',
      why: 'Khẳng định bạn là cá nhân nước ngoài, không phải US person. VN–Mỹ '
          'chưa có hiệp định thuế hiệu lực, nên nếu bị khấu trừ tại nguồn thì '
          'bạn gần như không có đường đòi lại.',
      actions: [
        'Roblox → Settings → DevEx / Tipalti → điền W-8BEN.',
        'Ghi đúng địa chỉ cư trú Việt Nam và số định danh cá nhân.',
        'Lưu lại bản PDF đã nộp vào hồ sơ.',
      ],
    ),
    const RoadmapStep(
      id: 'accounts',
      phase: RoadmapPhase.setup,
      icon: '🏦',
      title: 'Tách 2 tài khoản: "tiền nghề" và "quỹ thuế"',
      why: 'Lý do freelancer sốc thuế cuối năm không phải vì thuế cao, mà vì đã '
          'tiêu mất phần tiền chưa bao giờ thuộc về mình.',
      actions: [
        'Một tài khoản ngân hàng chỉ để nhận tiền từ PayPal → sao kê sạch, dễ '
            'chứng minh khi bị đối chiếu.',
        'Một tài khoản tiết kiệm đặt tên "QUY THUE" — không gắn thẻ, khó tiêu.',
        'Rút PayPal ghi rõ nội dung: "thanh toan dich vu thiet ke 3D".',
      ],
    ),
    RoadmapStep(
      id: 'backfill',
      phase: RoadmapPhase.setup,
      icon: '📂',
      title: 'Gom lại chứng từ từ đầu năm $y đến nay',
      why: 'Bạn đã đi được nửa năm. Dựng lại lịch sử bây giờ dễ hơn nhiều so '
          'với việc lục lại vào tháng 4 sang năm.',
      actions: [
        'Xuất lịch sử DevEx trên Roblox (Transactions → DevEx) từ 1/1/$y.',
        'Tải sao kê PayPal từng tháng từ 1/1/$y.',
        'Nhập tất cả vào tab "Doanh thu" — app sẽ tự cộng dồn và canh ngưỡng.',
      ],
    ),
    const RoadmapStep(
      id: 'log',
      phase: RoadmapPhase.track,
      icon: '📝',
      title: 'Ghi mọi khoản DevEx/PayPal ngay khi tiền về',
      why: 'Cơ quan thuế đối chiếu được dòng tiền qua ngân hàng. Sổ của bạn '
          'khớp sao kê là "bảo hiểm" tốt nhất — và là thứ duy nhất cho bạn biết '
          'mình đang ở đâu so với mốc 500 triệu.',
      actions: [
        'Ghi số Robux gốc, số USD, và tỷ giá thực tế hôm đó.',
        'Ghi theo tiền GỘP (trước phí PayPal) — đó mới là doanh thu tính thuế.',
      ],
    ),
    const RoadmapStep(
      id: 'reserve',
      phase: RoadmapPhase.track,
      icon: '💰',
      title: 'Trích quỹ thuế mỗi lần tiền về',
      why: 'Đến kỳ khai, bạn nộp từ quỹ này thay vì đi vay. Tab "Doanh thu" '
          'tính sẵn % cần trích và tự nâng lên khi bạn tiến gần ngưỡng.',
      actions: [
        'Chuyển đúng % gợi ý sang tài khoản "QUY THUE" TRƯỚC khi tiêu gì khác.',
        'Không đụng vào quỹ này kể cả khi kẹt tiền — nó không phải tiền của bạn.',
      ],
    ),
    const RoadmapStep(
      id: 'invoice',
      phase: RoadmapPhase.track,
      icon: '🧾',
      title: 'Xuất invoice cho mọi job, kể cả khi khách không đòi',
      why: 'Invoice ghi rõ "3D modeling services performed in Vietnam" là thứ '
          'chứng minh đây là DỊCH VỤ (GTGT 0%) chứ không phải tiền bản quyền — '
          'ranh giới quyết định cả thuế Mỹ lẫn thuế VN.',
      actions: [
        'Ghi: mô tả dịch vụ, số tiền USD, ngày, tên studio, "performed in '
            'Vietnam", "full ownership transferred on payment".',
        'Từ 2026 hộ/cá nhân kinh doanh dùng hóa đơn điện tử — hỏi cơ quan thuế '
            'về nhà cung cấp hóa đơn điện tử khi đăng ký.',
      ],
    ),
    RoadmapStep(
      id: 'q2',
      phase: RoadmapPhase.file,
      icon: '📅',
      title: 'Khai & nộp thuế Quý 2/$y',
      why: 'Hạn cứng đầu tiên bạn gặp. Nộp muộn tính tiền chậm nộp '
          '0,03%/ngày trên số thuế.',
      actions: [
        'Khai trên thuedientu.gdt.gov.vn hoặc app eTax Mobile (đăng nhập bằng '
            'CCCD).',
        'Doanh thu quý = tổng tiền GỘP nhận trong tháng 4, 5, 6.',
        'Nộp tiền thuế từ quỹ thuế đã trích sẵn.',
      ],
      due: DateTime(y, 7, 31),
    ),
    RoadmapStep(
      id: 'q3',
      phase: RoadmapPhase.file,
      icon: '📅',
      title: 'Khai & nộp thuế Quý 3/$y',
      why: 'Doanh thu tháng 7, 8, 9. Đây cũng là lúc nhìn lại xem cả năm có '
          'sắp vượt 500 triệu không, để còn kịp xoay.',
      actions: [
        'Đối chiếu sổ trong app với sao kê PayPal + lịch sử DevEx trước khi khai.',
        'Kiểm tra tab "Doanh thu": còn bao nhiêu dư địa trước mốc 500 triệu.',
      ],
      due: DateTime(y, 10, 31),
    ),
    RoadmapStep(
      id: 'decide',
      phase: RoadmapPhase.close,
      icon: '⚖️',
      title: 'Quyết định cuối năm: nhận thêm job hay dời sang ${y + 1}?',
      why: 'Vượt 500 triệu thì thuế đánh trên TOÀN BỘ doanh thu, không chỉ phần '
          'vượt. Có một dải (500 → ~510,2 triệu) mà làm thêm lại còn ít tiền '
          'hơn là dừng lại.',
      actions: [
        'Xem cảnh báo "vùng chết" ở tab Máy tính / Doanh thu.',
        'Nếu sắp chạm dải đó: hoặc nhận đủ việc để vượt hẳn, hoặc thỏa thuận '
            'với studio để job hoàn thành & thanh toán sang năm sau.',
        'Chỉ dời khi việc THẬT SỰ hoàn thành ở năm sau — dời khống là sai lệch '
            'kỳ kê khai.',
      ],
      due: DateTime(y, 12, 31),
    ),
    RoadmapStep(
      id: 'q4',
      phase: RoadmapPhase.close,
      icon: '📅',
      title: 'Khai & nộp thuế Quý 4/$y',
      why: 'Quý cuối của năm $y, nhưng hạn rơi vào tháng 1 năm sau — rất dễ '
          'quên giữa kỳ nghỉ Tết.',
      actions: [
        'Doanh thu tháng 10, 11, 12.',
        'Chốt sổ cả năm trong app trước khi khai.',
      ],
      due: DateTime(y + 1, 1, 31),
    ),
    RoadmapStep(
      id: 'finalize',
      phase: RoadmapPhase.close,
      icon: '🏁',
      title: 'Quyết toán thuế TNCN năm $y',
      why: 'Chốt lại cả năm: bù trừ phần đã nộp thừa/thiếu, áp giảm trừ gia '
          'cảnh và người phụ thuộc. Đây là lúc hồ sơ sạch trả công cho bạn.',
      actions: [
        'Chuẩn bị: tổng doanh thu $y, chứng từ thuế đã nộp, đăng ký người phụ '
            'thuộc (mẫu 20-ĐK-TCT).',
        'Nộp qua thuedientu.gdt.gov.vn; giữ lại biên lai.',
        'Nếu số tiền lớn hoặc có khấu trừ thuế ở nước ngoài — thuê đại lý thuế, '
            'phí đó rẻ hơn một lần bị truy thu.',
      ],
      due: DateTime(y + 1, 4, 30),
    ),
  ];
}
