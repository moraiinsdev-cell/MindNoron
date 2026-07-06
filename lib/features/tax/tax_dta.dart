/// Offline lookup of Vietnam's double-taxation agreements (Hiệp định tránh đánh
/// thuế hai lần — DTA) for the countries a freelancer most often bills. The data
/// is curated and deliberately conservative: it points the user to the right
/// question and paperwork, not a definitive treaty rate (those depend on income
/// type and the specific article). Always confirm the current article/rate with
/// the treaty text or an advisor.
library;

enum DtaStatus {
  inForce, // đang có hiệu lực
  signedNotInForce, // đã ký nhưng chưa hiệu lực
  none; // chưa có hiệp định

  String get emoji => switch (this) {
        DtaStatus.inForce => '✅',
        DtaStatus.signedNotInForce => '🕓',
        DtaStatus.none => '❌',
      };

  String get label => switch (this) {
        DtaStatus.inForce => 'Có hiệu lực',
        DtaStatus.signedNotInForce => 'Đã ký, chưa hiệu lực',
        DtaStatus.none => 'Chưa có hiệp định',
      };
}

class DtaCountry {
  const DtaCountry({
    required this.flag,
    required this.name,
    required this.status,
    required this.note,
  });

  final String flag;
  final String name;
  final DtaStatus status;
  final String note;
}

const dtaIntro =
    'Hiệp định tránh đánh thuế hai lần (DTA) giúp bạn không bị đánh thuế cả ở '
    'nước trả tiền lẫn ở Việt Nam. Với freelancer, thu nhập từ dịch vụ độc lập '
    'thường chỉ bị đánh thuế ở nơi cư trú (Việt Nam) trừ khi bạn có cơ sở cố '
    'định tại nước đó. Nếu nước ngoài đã khấu trừ thuế, bạn có thể xin miễn/giảm '
    'theo hiệp định hoặc khấu trừ phần đã nộp khi quyết toán tại VN.';

/// Practical steps to actually claim relief — the same regardless of country.
const dtaSteps = <String>[
  'Xin Giấy chứng nhận cư trú thuế (residency certificate) của VN để nộp cho '
      'khách/nước ngoài, chứng minh bạn là đối tượng cư trú VN.',
  'Nộp biểu mẫu miễn/giảm khấu trừ cho bên chi trả (ví dụ W-8BEN với khách Mỹ) '
      'để không bị giữ thuế tại nguồn khi đủ điều kiện.',
  'Lưu chứng từ đã bị khấu trừ thuế ở nước ngoài (nếu có) để xin khấu trừ khi '
      'quyết toán TNCN tại VN.',
  'Với khoản lớn/phức tạp, hỏi đại lý thuế về điều khoản áp dụng (dịch vụ độc '
      'lập, tiền bản quyền, lợi tức…) vì thuế suất khác nhau theo loại thu nhập.',
];

/// Curated country list, alphabetical-ish by relevance. Statuses reflect the
/// general position; the US treaty in particular was signed (2015) but has not
/// entered into force, which changes what relief is available today.
const dtaCountries = <DtaCountry>[
  DtaCountry(
    flag: '🇺🇸',
    name: 'Hoa Kỳ (Mỹ)',
    status: DtaStatus.signedNotInForce,
    note:
        'Hiệp định đã ký năm 2015 nhưng CHƯA có hiệu lực → hiện chưa áp dụng '
        'miễn/giảm theo hiệp định. Thực tế khách Mỹ thường không khấu trừ nếu '
        'bạn nộp W-8BEN (freelancer nước ngoài). Nếu bị giữ thuế, cân nhắc khấu '
        'trừ theo luật trong nước khi quyết toán.',
  ),
  DtaCountry(
    flag: '🇸🇬',
    name: 'Singapore',
    status: DtaStatus.inForce,
    note:
        'Có hiệu lực. Thu nhập dịch vụ độc lập thường chỉ chịu thuế tại VN nếu '
        'bạn không có cơ sở cố định ở Singapore. Nộp giấy cư trú để tránh khấu '
        'trừ tại nguồn.',
  ),
  DtaCountry(
    flag: '🇯🇵',
    name: 'Nhật Bản',
    status: DtaStatus.inForce,
    note:
        'Có hiệu lực. Áp dụng miễn/giảm khấu trừ với dịch vụ và tiền bản quyền '
        'theo điều khoản tương ứng; cần giấy chứng nhận cư trú VN.',
  ),
  DtaCountry(
    flag: '🇰🇷',
    name: 'Hàn Quốc',
    status: DtaStatus.inForce,
    note:
        'Có hiệu lực. Thu nhập dịch vụ độc lập nhìn chung chịu thuế tại VN; '
        'tiền bản quyền có thuế suất trần theo hiệp định.',
  ),
  DtaCountry(
    flag: '🇬🇧',
    name: 'Anh (UK)',
    status: DtaStatus.inForce,
    note:
        'Có hiệu lực. Dịch vụ độc lập thường chỉ chịu thuế tại nơi cư trú (VN) '
        'khi không có cơ sở cố định tại Anh.',
  ),
  DtaCountry(
    flag: '🇩🇪',
    name: 'Đức',
    status: DtaStatus.inForce,
    note:
        'Có hiệu lực. Nộp giấy cư trú VN để xin miễn/giảm khấu trừ với thu nhập '
        'dịch vụ, bản quyền.',
  ),
  DtaCountry(
    flag: '🇫🇷',
    name: 'Pháp',
    status: DtaStatus.inForce,
    note: 'Có hiệu lực. Nguyên tắc đánh thuế theo nơi cư trú với dịch vụ độc lập.',
  ),
  DtaCountry(
    flag: '🇦🇺',
    name: 'Úc (Australia)',
    status: DtaStatus.inForce,
    note:
        'Có hiệu lực. Dịch vụ độc lập chịu thuế tại VN nếu không có cơ sở cố '
        'định ở Úc; giữ chứng từ khấu trừ nếu bị giữ thuế.',
  ),
  DtaCountry(
    flag: '🇨🇦',
    name: 'Canada',
    status: DtaStatus.inForce,
    note: 'Có hiệu lực. Áp dụng theo nơi cư trú với thu nhập dịch vụ độc lập.',
  ),
  DtaCountry(
    flag: '🇳🇱',
    name: 'Hà Lan',
    status: DtaStatus.inForce,
    note: 'Có hiệu lực. Có điều khoản trần thuế suất với tiền bản quyền.',
  ),
  DtaCountry(
    flag: '🇨🇳',
    name: 'Trung Quốc',
    status: DtaStatus.inForce,
    note: 'Có hiệu lực. Cần giấy cư trú VN để xin miễn/giảm khấu trừ tại nguồn.',
  ),
  DtaCountry(
    flag: '🇭🇰',
    name: 'Hồng Kông',
    status: DtaStatus.inForce,
    note: 'Có hiệu lực. Thu nhập dịch vụ độc lập chủ yếu chịu thuế tại VN.',
  ),
  DtaCountry(
    flag: '🇦🇪',
    name: 'UAE',
    status: DtaStatus.inForce,
    note:
        'Có hiệu lực. UAE gần như không đánh thuế TNCN, nên rủi ro bị đánh hai '
        'lần thấp; vẫn phải kê khai thu nhập tại VN.',
  ),
  DtaCountry(
    flag: '🇨🇭',
    name: 'Thụy Sĩ',
    status: DtaStatus.inForce,
    note: 'Có hiệu lực. Áp dụng theo nơi cư trú với dịch vụ độc lập.',
  ),
  DtaCountry(
    flag: '🇲🇾',
    name: 'Malaysia',
    status: DtaStatus.inForce,
    note: 'Có hiệu lực. Nộp giấy cư trú để tránh khấu trừ tại nguồn.',
  ),
  DtaCountry(
    flag: '🇹🇭',
    name: 'Thái Lan',
    status: DtaStatus.inForce,
    note: 'Có hiệu lực. Thu nhập dịch vụ độc lập chủ yếu chịu thuế tại VN.',
  ),
  DtaCountry(
    flag: '🇮🇳',
    name: 'Ấn Độ',
    status: DtaStatus.inForce,
    note:
        'Có hiệu lực. Lưu ý điều khoản "phí dịch vụ kỹ thuật" có thể cho phép '
        'khấu trừ tại nguồn — kiểm tra loại thu nhập.',
  ),
];
