import "package:flutter_test/flutter_test.dart";
import "package:stock_scanner_mobile/orders_page.dart";

void main() {
  group("Thai OCR Parser Tests", () {
    test("normal Thai shipping/order text", () {
      const text = """
ใบส่งของ
ชื่อผู้รับ: คุณสมเกียรติ รักงานดี
เบอร์โทร: 081-234-5678
ที่อยู่: 123/45 หมู่ 2 ต.ศิลา อ.เมือง จ.ขอนแก่น 40000
เสร็จสิ้น
""";
      final result = parseCustomerOcr(text);
      expect(result["name"], "คุณสมเกียรติ รักงานดี");
      expect(result["phone"], "0812345678");
      expect(result["address"], "123/45 หมู่ 2 ต.ศิลา อ.เมือง จ.ขอนแก่น 40000");
    });

    test("noisy browser/screenshot text", () {
      const text = """
localhost:8080/dashboard
ใบสั่งซื้อ
ชื่อลูกค้า: สมหญิง จริงใจ
ที่อยู่: 99/9 ต.ตลาด อ.เมือง จ.สุราษฎร์ธานี 84000 โทร. 098-765-4321
Activate Windows
Go to Settings to activate Windows
""";
      final result = parseCustomerOcr(text);
      expect(result["name"], "สมหญิง จริงใจ");
      expect(result["phone"], "0987654321");
      expect(result["address"], "99/9 ต.ตลาด อ.เมือง จ.สุราษฎร์ธานี 84000");
    });

    test("mojibake text repair", () {
      const text = """
à¸ªà¸¡à¸ à¸²à¸¢ à¸”à¸µà¹€à¸¥à¸´à¸”
เบอร์ +66 89 123 4567
ที่อยู่ 55/12 ม.5 ต.ท่าทราย อ.เมือง นนทบุรี 11000
""";
      final result = parseCustomerOcr(text);
      expect(result["name"], "สมภาย ดีเลิด");
      expect(result["phone"], "0891234567");
      expect(result["address"], "55/12 ม.5 ต.ท่าทราย อ.เมือง นนทบุรี 11000");
    });

    test("Thai phone formats 0xxxxxxxxx", () {
      const text = """
ชื่อ: สมชาย ดี
เบอร์: 081-234-5678
ที่อยู่: 123 หมู่ 1 นนทบุรี
""";
      final result = parseCustomerOcr(text);
      expect(result["phone"], "0812345678");
    });

    test("Thai phone formats 66xxxxxxxxx", () {
      const text = """
ชื่อ: สมชาย ดี
เบอร์: 66891234567
ที่อยู่: 123 หมู่ 1 นนทบุรี
""";
      final result = parseCustomerOcr(text);
      expect(result["phone"], "0891234567");
    });

    test("Thai phone formats +66xxxxxxxxx", () {
      const text = """
ชื่อ: สมชาย ดี
เบอร์: +66 89 123 4567
ที่อยู่: 123 หมู่ 1 นนทบุรี
""";
      final result = parseCustomerOcr(text);
      expect(result["phone"], "0891234567");
    });

    test("Thai landline phone formats 02xxxxxxx", () {
      const text = """
ชื่อ: บจก. พลังงานไทย
เบอร์: 02-123-4567
ที่อยู่: 123 ถนนวิภาวดีรังสิต กรุงเทพฯ
""";
      final result = parseCustomerOcr(text);
      expect(result["phone"], "021234567");
    });
  });
}
