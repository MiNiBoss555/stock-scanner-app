import "dart:async";
import "dart:io";
import "package:http/http.dart" as http;
import "config.dart";

class ServerScanResult {
  final String url;
  final String message;
  final bool isSuccess;

  ServerScanResult({
    required this.url,
    required this.message,
    required this.isSuccess,
  });
}

class ServerScanner {
  /// Fast probe to test if a given URL is a working Stock Scanner server.
  static Future<bool> pingServer(String baseUrl) async {
    try {
      final cleanUrl = baseUrl.trim().replaceAll(RegExp(r"/+$"), "");
      final uri = Uri.parse("$cleanUrl/health");
      final response = await http.get(uri).timeout(const Duration(milliseconds: 1200));
      if (response.statusCode == 200) {
        final body = response.body.toLowerCase();
        return body.contains("ok") || body.contains("status") || body.contains("stock");
      }
    } catch (_) {}
    return false;
  }

  /// Automatically scan local network IPs to find the Stock Scanner server.
  static Future<ServerScanResult> autoDiscoverServer({
    void Function(String statusMessage)? onProgress,
  }) async {
    onProgress?.call("กำลังเริ่มค้นหาเซิร์ฟเวอร์ในเครือข่าย...");

    // 1. First test current configured URL
    final currentUrl = AppConfig.baseUrl;
    onProgress?.call("กำลังทดสอบ: $currentUrl");
    if (await pingServer(currentUrl)) {
      return ServerScanResult(
        url: currentUrl,
        message: "เชื่อมต่อเซิร์ฟเวอร์สำเร็จ: $currentUrl",
        isSuccess: true,
      );
    }

    // 2. Test common local IP fallbacks
    final priorityCandidates = [
      "http://127.0.0.1:8000",
    ];

    for (final candidate in priorityCandidates) {
      if (candidate == currentUrl) continue;
      onProgress?.call("กำลังทดสอบ: $candidate");
      if (await pingServer(candidate)) {
        await AppConfig.setCustomServerUrl(candidate);
        return ServerScanResult(
          url: candidate,
          message: "พบเซิร์ฟเวอร์แล้ว: $candidate",
          isSuccess: true,
        );
      }
    }

    // 3. Obtain local network IP prefix (e.g. 192.168.1.x)
    List<String> prefixesToScan = ["192.168.1.", "192.168.0.", "10.0.0."];

    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          final ip = addr.address;
          if (ip.startsWith("192.168.") || ip.startsWith("10.") || ip.startsWith("172.")) {
            final parts = ip.split(".");
            if (parts.length == 4) {
              final prefix = "${parts[0]}.${parts[1]}.${parts[2]}.";
              if (!prefixesToScan.contains(prefix)) {
                prefixesToScan.insert(0, prefix);
              }
            }
          }
        }
      }
    } catch (_) {}

    // 4. Batch scan subnet IPs in parallel (e.g., 25 requests per batch)
    for (final prefix in prefixesToScan) {
      onProgress?.call("กำลังสแกนวงเครือข่าย $prefix* (พอร์ต 8000)...");

      final candidateIps = List.generate(254, (i) => "http://$prefix${i + 1}:8000");
      const batchSize = 25;

      for (int i = 0; i < candidateIps.length; i += batchSize) {
        final batch = candidateIps.sublist(
          i,
          i + batchSize > candidateIps.length ? candidateIps.length : i + batchSize,
        );

        final completer = Completer<String?>();

        final futures = batch.map((url) async {
          if (await pingServer(url)) {
            if (!completer.isCompleted) {
              completer.complete(url);
            }
          }
        });

        // Timeout each batch fast (1.5s max per batch)
        final foundUrl = await Future.any([
          completer.future,
          Future.delayed(const Duration(milliseconds: 1500), () => null),
        ]);

        if (foundUrl != null) {
          await AppConfig.setCustomServerUrl(foundUrl);
          return ServerScanResult(
            url: foundUrl,
            message: "ค้นหาเซิร์ฟเวอร์เจออัตโนมัติ: $foundUrl",
            isSuccess: true,
          );
        }
      }
    }

    return ServerScanResult(
      url: currentUrl,
      message: "ไม่พบเซิร์ฟเวอร์ในเครือข่าย Wi-Fi กรุณาตรวจสอบว่าคอมพิวเตอร์เปิดโปรแกรม Stock Scanner อยู่ และต่อ Wi-Fi วงเดียวกัน",
      isSuccess: false,
    );
  }
}
