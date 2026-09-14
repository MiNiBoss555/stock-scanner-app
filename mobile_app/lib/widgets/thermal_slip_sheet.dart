import "dart:io";
import "dart:typed_data";
import "dart:ui" as ui;

import "package:barcode_widget/barcode_widget.dart";
import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:path_provider/path_provider.dart";
import "package:pdf/pdf.dart";
import "package:pdf/widgets.dart" as pw;
import "package:printing/printing.dart";
import "package:share_plus/share_plus.dart";

import "../models.dart";
import "../theme/app_theme.dart";

Future<void> showThermalReceiptSlipSheet({
  required BuildContext context,
  required DeliveryOrder order,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ThermalReceiptSlipSheet(order: order),
  );
}

class _ThermalReceiptSlipSheet extends StatefulWidget {
  const _ThermalReceiptSlipSheet({required this.order});

  final DeliveryOrder order;

  @override
  State<_ThermalReceiptSlipSheet> createState() =>
      __ThermalReceiptSlipSheetState();
}

class __ThermalReceiptSlipSheetState extends State<_ThermalReceiptSlipSheet> {
  final GlobalKey _captureKey = GlobalKey();
  bool _isPrinting = false;
  bool _isSharing = false;
  int _paperWidthMm = 80;

  Future<Uint8List> _captureSlipBytes() async {
    final boundary = _captureKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      throw Exception("ไม่พบสลิปสำหรับพิมพ์");
    }

    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData?.buffer.asUint8List();
    if (bytes == null) {
      throw Exception("สร้างภาพสลิปไม่สำเร็จ");
    }
    return bytes;
  }

  Future<void> _printSlip(int widthMm) async {
    try {
      setState(() {
        _isPrinting = true;
      });

      final bytes = await _captureSlipBytes();
      final image = pw.MemoryImage(bytes);
      final pdfWidth = widthMm * PdfPageFormat.mm;

      await Printing.layoutPdf(
        onLayout: (format) async {
          final doc = pw.Document();
          doc.addPage(
            pw.Page(
              pageFormat: PdfPageFormat(
                pdfWidth,
                pdfWidth * 2.2,
                marginAll: 4,
              ),
              build: (context) => pw.Center(
                child: pw.Image(image, fit: pw.BoxFit.contain),
              ),
            ),
          );
          return doc.save();
        },
        name: "Slip-${widget.order.id.substring(0, widget.order.id.length < 8 ? widget.order.id.length : 8)}",
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

  Future<void> _shareSlip() async {
    try {
      setState(() {
        _isSharing = true;
      });

      final bytes = await _captureSlipBytes();
      final tempDir = await getTemporaryDirectory();
      final file = File("${tempDir.path}/slip-${widget.order.id}.png");
      await file.writeAsBytes(bytes, flush: true);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: "ใบส่งของ ออเดอร์ ${widget.order.customerName} (${widget.order.id})",
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
          _isSharing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final shortId = order.id.length < 8 ? order.id : order.id.substring(0, 8);
    final phone = order.customerPhone ?? "";
    final address = order.customerAddress ?? "";
    final totalQty = order.items.fold<int>(0, (sum, item) => sum + item.quantity);

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.receipt_long_rounded, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "ใบส่งของอย่างย่อ (Thermal Slip)",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment<int>(
                    value: 58,
                    label: Text("สลิป 58mm"),
                    icon: Icon(Icons.print_outlined, size: 16),
                  ),
                  ButtonSegment<int>(
                    value: 80,
                    label: Text("สลิป 80mm"),
                    icon: Icon(Icons.print_rounded, size: 16),
                  ),
                ],
                selected: {_paperWidthMm},
                onSelectionChanged: (val) {
                  setState(() {
                    _paperWidthMm = val.first;
                  });
                },
              ),
              const SizedBox(height: 16),
              RepaintBoundary(
                key: _captureKey,
                child: Container(
                  width: _paperWidthMm == 58 ? 260 : 340,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        "STOCK SCANNER",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Text(
                        "ใบจัดส่งสินค้าอย่างย่อ",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "----------------------------------------",
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "เลขที่ออเดอร์: #$shortId",
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "ลูกค้า: ${order.customerName}",
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (phone.isNotEmpty)
                              Text(
                                "โทร: $phone",
                                style: const TextStyle(fontSize: 11),
                              ),
                            if (address.isNotEmpty)
                              Text(
                                "ที่อยู่: $address",
                                style: const TextStyle(fontSize: 11),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "----------------------------------------",
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                      ),
                      const SizedBox(height: 6),
                      const Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              "สินค้า",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            "จำนวน",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (order.items.isEmpty)
                        const Text(
                          "- ไม่มีรายการสินค้า -",
                          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                        )
                      else
                        ...order.items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    item.productName,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                                Text(
                                  "x${item.quantity}",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        "----------------------------------------",
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "สถานะ: ${order.status.toUpperCase()}",
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "รวม $totalQty ชิ้น",
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 40,
                        width: 180,
                        child: BarcodeWidget(
                          barcode: Barcode.code128(),
                          data: order.id,
                          drawText: true,
                          style: const TextStyle(fontSize: 9),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "ขอบคุณที่ใช้บริการครับ",
                        style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSharing ? null : _shareSlip,
                      icon: _isSharing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.share_rounded, size: 18),
                      label: const Text("แชร์สลิป"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isPrinting
                          ? null
                          : () => _printSlip(_paperWidthMm),
                      icon: _isPrinting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.print_rounded, size: 18),
                      label: Text("พิมพ์ ${_paperWidthMm}mm"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
