import "dart:io";
import "dart:convert";
import "package:flutter/foundation.dart";
import "package:path_provider/path_provider.dart";
import "package:share_plus/share_plus.dart";

import "../models.dart";

class BarTenderPrintService {
  /// Default Sender Information
  static const String defaultSenderName = "ร้านค้า Stock Scanner (คลังสินค้าหลัก)";
  static const String defaultSenderAddress = "123/45 ถนนพัฒนาการ แขวงสวนหลวง เขตสวนหลวง กรุงเทพมหานคร 10250";
  static const String defaultSenderPhone = "02-123-4567";

  /// Generate CSV data formatted for BarTender UltraLite template
  /// Uses UTF-8 with BOM (\uFEFF) so Thai text displays correctly in BarTender and Excel
  static String generateCsvData({
    required DeliveryOrder order,
    required bool includeCopy,
    String senderName = defaultSenderName,
    String senderAddress = defaultSenderAddress,
    String senderPhone = defaultSenderPhone,
  }) {
    final buffer = StringBuffer();
    // Write UTF-8 BOM
    buffer.write('\u{FEFF}');

    // CSV Headers
    final headers = [
      "CopyType",
      "OrderID",
      "OrderBarcode",
      "OrderDate",
      "SenderName",
      "SenderAddress",
      "SenderPhone",
      "CustomerName",
      "CustomerAddress",
      "CustomerPhone",
      "ItemListText",
      "TotalQty",
      "TotalItemsCount",
      "Note"
    ];
    buffer.writeln(headers.map(_escapeCsv).join(","));

    final copyTypes = <String>["ต้นฉบับ"];
    if (includeCopy) {
      copyTypes.add("สำเนา");
    }

    final dateStr = "${order.createdAt.day.toString().padLeft(2, '0')}/${order.createdAt.month.toString().padLeft(2, '0')}/${order.createdAt.year} ${order.createdAt.hour.toString().padLeft(2, '0')}:${order.createdAt.minute.toString().padLeft(2, '0')}";
    final totalQty = order.items.fold<int>(0, (sum, item) => sum + item.quantity);

    // Format item summary string: "Product Name (Barcode) xQty Unit; ..."
    final itemListText = order.items
        .map((item) => "${item.productName} (${item.barcode}) x${item.quantity} ${item.unit}")
        .join(" | ");

    for (final copyType in copyTypes) {
      final row = [
        copyType,
        order.id,
        order.id,
        dateStr,
        senderName,
        senderAddress,
        senderPhone,
        order.customerName,
        order.customerAddress ?? "-",
        order.customerPhone ?? "-",
        itemListText,
        totalQty.toString(),
        order.items.length.toString(),
        order.note ?? "",
      ];
      buffer.writeln(row.map(_escapeCsv).join(","));
    }

    return buffer.toString();
  }

  static String _escapeCsv(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  /// Save CSV file locally and share/export
  static Future<File> saveCsvFile({
    required DeliveryOrder order,
    required bool includeCopy,
    String senderName = defaultSenderName,
    String senderAddress = defaultSenderAddress,
    String senderPhone = defaultSenderPhone,
  }) async {
    final csvContent = generateCsvData(
      order: order,
      includeCopy: includeCopy,
      senderName: senderName,
      senderAddress: senderAddress,
      senderPhone: senderPhone,
    );

    final tempDir = await getTemporaryDirectory();
    final shortId = order.id.length < 8 ? order.id : order.id.substring(0, 8);
    final file = File("${tempDir.path}/bartender_order_$shortId.csv");

    // Write bytes with utf8 encoding
    final bytes = utf8.encode(csvContent);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Share CSV Data Source for BarTender UltraLite
  static Future<void> shareCsvForBarTender({
    required DeliveryOrder order,
    required bool includeCopy,
  }) async {
    final file = await saveCsvFile(order: order, includeCopy: includeCopy);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: "text/csv")],
      text: "BarTender UltraLite Data Source - ออเดอร์ ${order.customerName} (${order.id})",
    );
  }

  /// Execute BarTender command line on Windows Desktop if BarTender is installed
  /// Command: BarTend.exe /F="template.btw" /D="data.csv" /P /X
  static Future<bool> launchBarTenderPrint({
    required DeliveryOrder order,
    required bool includeCopy,
    String? btwTemplatePath,
  }) async {
    if (!kIsWeb && Platform.isWindows) {
      try {
        final csvFile = await saveCsvFile(order: order, includeCopy: includeCopy);

        final possibleExePaths = [
          r"C:\Program Files\Seagull\BarTender UltraLite\BarTend.exe",
          r"C:\Program Files\Seagull\BarTender Suite\BarTend.exe",
          r"C:\Program Files (x86)\Seagull\BarTender UltraLite\BarTend.exe",
          r"C:\Program Files (x86)\Seagull\BarTender Suite\BarTend.exe",
          "BarTend.exe",
        ];

        String? foundExe;
        for (final path in possibleExePaths) {
          if (File(path).existsSync()) {
            foundExe = path;
            break;
          }
        }

        final exe = foundExe ?? "BarTend.exe";
        final args = <String>[];
        if (btwTemplatePath != null && File(btwTemplatePath).existsSync()) {
          args.add('/F="$btwTemplatePath"');
        }
        args.add('/D="${csvFile.path}"');
        args.add('/P'); // Print
        args.add('/X'); // Close after printing

        final result = await Process.run(exe, args, runInShell: true);
        return result.exitCode == 0;
      } catch (e) {
        return false;
      }
    }
    return false;
  }
}
