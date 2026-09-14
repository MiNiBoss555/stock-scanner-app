import "dart:io";
import "dart:typed_data";
import "dart:ui" as ui;

import "package:barcode_widget/barcode_widget.dart";
import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:pdf/pdf.dart";
import "package:pdf/widgets.dart" as pw;
import "package:printing/printing.dart";

import "../models.dart";
import "../services/bartender_print_service.dart";
import "../theme/app_theme.dart";

Future<void> showShippingLabelSheet({
  required BuildContext context,
  required DeliveryOrder order,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ShippingLabelSheet(order: order),
  );
}

class _ShippingLabelSheet extends StatefulWidget {
  const _ShippingLabelSheet({required this.order});

  final DeliveryOrder order;

  @override
  State<_ShippingLabelSheet> createState() => _ShippingLabelSheetState();
}

enum ShippingPaperSize { thermal100x150, thermal100x100, a4 }

class _ShippingLabelSheetState extends State<_ShippingLabelSheet> {
  final GlobalKey _captureKeyOriginal = GlobalKey();
  final GlobalKey _captureKeyCopy = GlobalKey();

  bool _includeCopy = true; // Default: include copy sheet
  ShippingPaperSize _paperSize = ShippingPaperSize.thermal100x150; // Default: 100x150mm sticker
  bool _isPrinting = false;
  bool _isExporting = false;

  Future<Uint8List> _captureWidgetBytes(GlobalKey key) async {
    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw Exception("ไม่พบมุมมองเอกสารสำหรับพิมพ์");
    }

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData?.buffer.asUint8List();
    if (bytes == null) {
      throw Exception("เรนเดอร์เอกสารไม่สำเร็จ");
    }
    return bytes;
  }

  PdfPageFormat get _selectedPdfPageFormat {
    switch (_paperSize) {
      case ShippingPaperSize.thermal100x150:
        return PdfPageFormat(100 * PdfPageFormat.mm, 150 * PdfPageFormat.mm, marginAll: 2 * PdfPageFormat.mm);
      case ShippingPaperSize.thermal100x100:
        return PdfPageFormat(100 * PdfPageFormat.mm, 100 * PdfPageFormat.mm, marginAll: 2 * PdfPageFormat.mm);
      case ShippingPaperSize.a4:
        return PdfPageFormat.a4;
    }
  }

  Future<void> _printDirectPdf() async {
    try {
      setState(() {
        _isPrinting = true;
      });

      final originalBytes = await _captureWidgetBytes(_captureKeyOriginal);
      Uint8List? copyBytes;
      if (_includeCopy) {
        // Wait a frame if copy key needs render
        await Future<void>.delayed(const Duration(milliseconds: 50));
        copyBytes = await _captureWidgetBytes(_captureKeyCopy);
      }

      final doc = pw.Document();
      final imgOriginal = pw.MemoryImage(originalBytes);
      final pdfFormat = _selectedPdfPageFormat;

      // Add Page 1: Original
      doc.addPage(
        pw.Page(
          pageFormat: pdfFormat,
          margin: const pw.EdgeInsets.all(2),
          build: (pw.Context context) {
            return pw.FullPage(
              ignoreMargins: false,
              child: pw.Center(
                child: pw.FittedBox(
                  fit: pw.BoxFit.contain,
                  child: pw.Image(imgOriginal),
                ),
              ),
            );
          },
        ),
      );

      // Add Page 2: Copy (if selected)
      if (_includeCopy && copyBytes != null) {
        final imgCopy = pw.MemoryImage(copyBytes);
        doc.addPage(
          pw.Page(
            pageFormat: pdfFormat,
            margin: const pw.EdgeInsets.all(2),
            build: (pw.Context context) {
              return pw.FullPage(
                ignoreMargins: false,
                child: pw.Center(
                  child: pw.FittedBox(
                    fit: pw.BoxFit.contain,
                    child: pw.Image(imgCopy),
                  ),
                ),
              );
            },
          ),
        );
      }

      final shortId = widget.order.id.length < 8
          ? widget.order.id
          : widget.order.id.substring(0, 8);

      await Printing.layoutPdf(
        onLayout: (format) async => doc.save(),
        name: "ShippingLabel-$shortId",
      );
    } catch (error) {
      if (mounted) {
        showAppSnack(
          context,
          error.toString().replaceFirst("Exception: ", ""),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPrinting = false;
        });
      }
    }
  }

  Future<void> _exportBarTenderCsv() async {
    try {
      setState(() {
        _isExporting = true;
      });

      await BarTenderPrintService.shareCsvForBarTender(
        order: widget.order,
        includeCopy: _includeCopy,
      );
    } catch (error) {
      if (mounted) {
        showAppSnack(context, "เกิดข้อผิดพลาดในการส่งออก CSV: $error");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _printWithBarTender() async {
    if (!Platform.isWindows) {
      // On mobile/mac/web, share CSV instead
      await _exportBarTenderCsv();
      return;
    }

    try {
      setState(() {
        _isPrinting = true;
      });

      final success = await BarTenderPrintService.launchBarTenderPrint(
        order: widget.order,
        includeCopy: _includeCopy,
      );

      if (mounted) {
        if (success) {
          showAppSnack(context, "ส่งคำสั่งพิมพ์ไปยัง BarTender UltraLite เรียบร้อยแล้ว");
        } else {
          // Fallback to CSV share/export if BarTender.exe is not found in standard paths
          showAppSnack(context, "ไม่พบโปรแกรม BarTender.exe ในระบบ ส่งออกเป็นไฟล์ CSV แทน");
          await _exportBarTenderCsv();
        }
      }
    } catch (error) {
      if (mounted) {
        showAppSnack(context, "ไม่สามารถสั่งพิมพ์ผ่าน BarTender ได้: $error");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPrinting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final shortId = order.id.length < 8 ? order.id : order.id.substring(0, 8);

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: brandDeep.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.print_rounded, color: brandDeep),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "ใบปะหน้า & ใบส่งสินค้า",
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: brandDeep,
                              ),
                        ),
                        Text(
                          "ออเดอร์ #${order.customerName} ($shortId)",
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Switch Copy Option
              Container(
                decoration: BoxDecoration(
                  color: brandSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: brandPrimary.withValues(alpha: 0.3)),
                ),
                child: SwitchListTile(
                  title: const Text(
                    "พิมพ์สำเนาด้วย (รวมเป็น 2 แผ่น)",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    _includeCopy
                        ? "ระบบจะพิมพ์ 2 แผ่น: [ต้นฉบับ] + [สำเนา]"
                        : "ระบบจะพิมพ์เฉพาะ 1 แผ่น: [ต้นฉบับ]",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  value: _includeCopy,
                  activeThumbColor: brandDeep,
                  onChanged: (val) {
                    setState(() {
                      _includeCopy = val;
                    });
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Paper Size Selection
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "ขนาดสติ๊กเกอร์ / กระดาษ (Paper Size)",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SegmentedButton<ShippingPaperSize>(
                    segments: const [
                      ButtonSegment(
                        value: ShippingPaperSize.thermal100x150,
                        icon: Icon(Icons.style_rounded, size: 16),
                        label: Text("100x150มม (4x6\")", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      ButtonSegment(
                        value: ShippingPaperSize.thermal100x100,
                        icon: Icon(Icons.crop_square_rounded, size: 16),
                        label: Text("100x100มม", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      ButtonSegment(
                        value: ShippingPaperSize.a4,
                        icon: Icon(Icons.description_rounded, size: 16),
                        label: Text("A4 Full", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                    selected: {_paperSize},
                    onSelectionChanged: (Set<ShippingPaperSize> selected) {
                      if (selected.isNotEmpty) {
                        setState(() {
                          _paperSize = selected.first;
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Document Preview Card
              Text(
                "ตัวอย่างเอกสาร (Preview Layout)",
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
              ),
              const SizedBox(height: 8),

              // Render Original Sheet
              RepaintBoundary(
                key: _captureKeyOriginal,
                child: _buildPrintDocumentCard(
                  order: order,
                  copyLabel: "ต้นฉบับ (ORIGINAL)",
                  badgeColor: Colors.blue.shade700,
                ),
              ),

              // Render Copy Sheet (Hidden offscreen or shown if enabled)
              if (_includeCopy) ...[
                const SizedBox(height: 16),
                RepaintBoundary(
                  key: _captureKeyCopy,
                  child: _buildPrintDocumentCard(
                    order: order,
                    copyLabel: "สำเนา (COPY)",
                    badgeColor: Colors.orange.shade800,
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  // Button BarTender Print / Export
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (_isPrinting || _isExporting) ? null : _printWithBarTender,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.sell_rounded, size: 18),
                      label: const Text(
                        "BarTender UltraLite",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Button Export CSV
                  OutlinedButton.icon(
                    onPressed: (_isPrinting || _isExporting) ? null : _exportBarTenderCsv,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: brandDeep,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.file_download_rounded, size: 18),
                    label: const Text(
                      "CSV",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Direct PDF Print Button
              FilledButton.icon(
                onPressed: (_isPrinting || _isExporting) ? null : _printDirectPdf,
                style: FilledButton.styleFrom(
                  backgroundColor: brandDeep,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: _isPrinting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.picture_as_pdf_rounded, size: 18),
                label: Text(
                  _isPrinting
                      ? "กำลังสร้าง PDF..."
                      : "พิมพ์ผ่านแอป / ดูตัวอย่าง PDF (${_paperSize == ShippingPaperSize.thermal100x150 ? '100x150มม' : _paperSize == ShippingPaperSize.thermal100x100 ? '100x100มม' : 'A4'})",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build Printable Document Card (1 Page divided into Upper Half & Lower Half)
  Widget _buildPrintDocumentCard({
    required DeliveryOrder order,
    required String copyLabel,
    required Color badgeColor,
  }) {
    final shortId = order.id.length < 8 ? order.id : order.id.substring(0, 8);
    final dateStr =
        "${order.createdAt.day.toString().padLeft(2, '0')}/${order.createdAt.month.toString().padLeft(2, '0')}/${order.createdAt.year}";
    final totalQty = order.items.fold<int>(0, (sum, item) => sum + item.quantity);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400, width: 1.2),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---------------- UPPER HALF: SENDER & RECIPIENT ----------------
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.local_shipping_rounded, size: 18, color: brandDeep),
                  SizedBox(width: 6),
                  Text(
                    "ใบปะหน้าสินค้า (SHIPPING LABEL)",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: brandDeep,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeColor, width: 1),
                ),
                child: Text(
                  copyLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Order Barcode & Metadata Header
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "เลขที่ออเดอร์: #$shortId",
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "วันที่: $dateStr",
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 130,
                  height: 38,
                  child: BarcodeWidget(
                    barcode: Barcode.code128(),
                    data: order.id,
                    drawText: true,
                    style: const TextStyle(fontSize: 9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Sender & Recipient Boxes Side by Side
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sender Box (ผู้ส่ง)
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.storefront_rounded, size: 14, color: Colors.grey.shade800),
                          const SizedBox(width: 4),
                          const Text(
                            "ผู้ส่ง (SENDER)",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Divider(height: 8),
                      Text(
                        BarTenderPrintService.defaultSenderName,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        BarTenderPrintService.defaultSenderAddress,
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "โทร: ${BarTenderPrintService.defaultSenderPhone}",
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade800),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Recipient Box (ผู้รับ - Highlighted)
              Expanded(
                flex: 6,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50.withValues(alpha: 0.5),
                    border: Border.all(color: Colors.blue.shade400, width: 1.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person_pin_circle_rounded, size: 15, color: Colors.blue.shade900),
                          const SizedBox(width: 4),
                          Text(
                            "ผู้รับ (RECIPIENT)",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 8),
                      Text(
                        order.customerName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        order.customerAddress ?? "ไม่ระบุที่อยู่จัดส่ง",
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "โทร: ${order.customerPhone ?? '-'}",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ---------------- DIVIDER LINE ----------------
          Row(
            children: [
              Expanded(child: Container(height: 1, color: Colors.grey.shade400)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  "✂️ รายการสินค้าสำหรับจัดส่ง (PACKING LIST)",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              Expanded(child: Container(height: 1, color: Colors.grey.shade400)),
            ],
          ),
          const SizedBox(height: 10),

          // ---------------- LOWER HALF: PACKING LIST TABLE ----------------
          Table(
            border: TableBorder.all(color: Colors.grey.shade300, width: 1),
            columnWidths: const {
              0: FixedColumnWidth(30), // No.
              1: FlexColumnWidth(2.2), // Barcode
              2: FlexColumnWidth(4), // Product Name
              3: FixedColumnWidth(40), // Qty
              4: FixedColumnWidth(35), // Checkbox box
            },
            children: [
              // Header Row
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade100),
                children: const [
                  Padding(
                    padding: EdgeInsets.all(4),
                    child: Text(
                      "#",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(4),
                    child: Text(
                      "บาร์โค้ด",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(4),
                    child: Text(
                      "รายการสินค้า",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(4),
                    child: Text(
                      "จำนวน",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(4),
                    child: Text(
                      "เช็ก",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              // Item Rows
              ...order.items.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final item = entry.value;
                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        "$idx",
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        item.barcode,
                        style: const TextStyle(fontSize: 10, fontFamily: "Monospace"),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        item.productName,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        "${item.quantity} ${item.unit}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(4),
                      child: Center(
                        child: Icon(Icons.check_box_outline_blank_rounded, size: 12, color: Colors.grey),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
          const SizedBox(height: 8),

          // Total Summary & Signatures
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "รวมทั้งสิ้น: ${order.items.length} รายการ ($totalQty ชิ้น)",
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              if (order.note != null && order.note!.isNotEmpty)
                Text(
                  "หมายเหตุ: ${order.note}",
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Signatures Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    "...................................................",
                    style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                  ),
                  const Text("ผู้จัดสินค้า / Packer", style: TextStyle(fontSize: 9)),
                ],
              ),
              Column(
                children: [
                  Text(
                    "...................................................",
                    style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                  ),
                  const Text("ผู้ตรวจรับ / Receiver", style: TextStyle(fontSize: 9)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
