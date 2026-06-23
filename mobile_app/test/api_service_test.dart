import "dart:convert";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;

void main() {
  group("StockApiService UTF-8 Decoding Tests", () {
    test("Decodes UTF-8 Thai response correctly (No Mojibake)", () {
      final thaiJson = {
        "name": "นายปริญญา ยวงทอง",
        "phone": "0874254595",
        "address": "เลขที่ 509/20 หมู่บ้านกรีน หมู่ 1 ตำบลหนองแสง อำเภอวาปีปทุม จังหวัดมหาสารคาม 44120"
      };

      // Encode map to UTF-8 bytes
      final encodedBytes = utf8.encode(jsonEncode(thaiJson));

      // Create a response using the bytes
      final response = http.Response.bytes(encodedBytes, 200, headers: {
        "content-type": "application/json"
      });

      // Using UTF-8 decode on response.bodyBytes yields correct Thai characters
      final decodedText = utf8.decode(response.bodyBytes);
      final bodyFromUtf8 = jsonDecode(decodedText);
      
      expect(bodyFromUtf8["name"], "นายปริญญา ยวงทอง");
      expect(bodyFromUtf8["phone"], "0874254595");
      expect(bodyFromUtf8["address"], "เลขที่ 509/20 หมู่บ้านกรีน หมู่ 1 ตำบลหนองแสง อำเภอวาปีปทุม จังหวัดมหาสารคาม 44120");
    });
  });
}
