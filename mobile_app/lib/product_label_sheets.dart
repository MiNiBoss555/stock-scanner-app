import "dart:io";
import "dart:typed_data";
import "dart:ui" as ui;

import "package:barcode_widget/barcode_widget.dart";
import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:flutter/services.dart";
import "package:path_provider/path_provider.dart";
import "package:pdf/pdf.dart";
import "package:pdf/widgets.dart" as pw;
import "package:printing/printing.dart";
import "package:qr_flutter/qr_flutter.dart";
import "package:share_plus/share_plus.dart";

import "models.dart";
import "theme/app_theme.dart";

Future<void> showProductCodeSheet(BuildContext context, Product product) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ProductCodeSheet(product: product),
  );
}

Future<void> showCustomLabelSheet(BuildContext context, String label) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _CustomLabelSheet(label: label),
  );
}

Future<void> showProductListSheet({
  required BuildContext context,
  required List<Product> products,
  required String title,
  required IconData icon,
  required Color color,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.48,
      maxChildSize: 0.94,
      builder: (context, controller) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "$title: ${products.length} รายการ",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: brandDeep,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: "ปิด",
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "แตะสินค้าเพื่อดู barcode/QR และพิมพ์ป้ายได้ทันที",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: brandInk.withOpacity(0.72),
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return Material(
                    color: Colors.white,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: color.withOpacity(0.10),
                        child: Icon(
                          product.currentStock <= 0
                              ? Icons.error_outline
                              : Icons.warning_amber_rounded,
                          color: color,
                        ),
                      ),
                      title: Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        "${product.barcode} • คงเหลือ ${product.currentStock} ${product.unit}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => showProductCodeSheet(context, product),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ProductCodeSheet extends StatefulWidget {
  const _ProductCodeSheet({required this.product});

  final Product product;

  @override
  State<_ProductCodeSheet> createState() => _ProductCodeSheetState();
}

class _ProductCodeSheetState extends State<_ProductCodeSheet> {
  final GlobalKey _captureKey = GlobalKey();
  bool _isSharing = false;
  bool _isPrinting = false;

  Future<Uint8List> _captureLabelBytes() async {
    final boundary = _captureKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      throw Exception("ไม่พบภาพสำหรับสร้างป้ายสินค้า");
    }

    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData?.buffer.asUint8List();
    if (bytes == null) {
      throw Exception("สร้างไฟล์ภาพป้ายสินค้าไม่สำเร็จ");
    }
    return bytes;
  }

  Future<void> _shareLabel() async {
    try {
      setState(() {
        _isSharing = true;
      });

      final bytes = await _captureLabelBytes();

      final tempDir = await getTemporaryDirectory();
      final file = File("${tempDir.path}/${widget.product.barcode}-label.png");
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: "${widget.product.name} (${widget.product.barcode})",
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

  Future<void> _printLabel() async {
    final chosenFormat = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text("เลือกขนาดกระดาษป้ายสินค้า"),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, "roll_50_30"),
            child: const Row(
              children: [
                Icon(Icons.label_outlined),
                SizedBox(width: 10),
                Text("สติ๊กเกอร์ม้วน (50x30 mm)"),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, "a4_grid"),
            child: const Row(
              children: [
                Icon(Icons.grid_on_rounded),
                SizedBox(width: 10),
                Text("แผ่น A4 (แผ่นละ 24 ป้าย)"),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, "a6_single"),
            child: const Row(
              children: [
                Icon(Icons.crop_portrait_rounded),
                SizedBox(width: 10),
                Text("ป้ายเดี่ยวมาตรฐาน (A6)"),
              ],
            ),
          ),
        ],
      ),
    );

    if (chosenFormat == null) return;

    try {
      setState(() {
        _isPrinting = true;
      });

      final bytes = await _captureLabelBytes();
      final image = pw.MemoryImage(bytes);

      await Printing.layoutPdf(
        onLayout: (format) async {
          final doc = pw.Document();

          if (chosenFormat == "roll_50_30") {
            doc.addPage(
              pw.Page(
                pageFormat: PdfPageFormat(
                  50 * PdfPageFormat.mm,
                  30 * PdfPageFormat.mm,
                  marginAll: 2,
                ),
                build: (context) => pw.Center(
                  child: pw.Image(image, fit: pw.BoxFit.contain),
                ),
              ),
            );
          } else if (chosenFormat == "a4_grid") {
            doc.addPage(
              pw.Page(
                pageFormat: PdfPageFormat.a4,
                margin: const pw.EdgeInsets.all(12),
                build: (context) => pw.GridView(
                  crossAxisCount: 3,
                  childAspectRatio: 50 / 30,
                  children: List.generate(
                    24,
                    (_) => pw.Container(
                      padding: const pw.EdgeInsets.all(3),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                      ),
                      child: pw.Image(image, fit: pw.BoxFit.contain),
                    ),
                  ),
                ),
              ),
            );
          } else {
            doc.addPage(
              pw.Page(
                pageFormat: PdfPageFormat.a6,
                margin: const pw.EdgeInsets.all(16),
                build: (context) => pw.Center(
                  child: pw.Image(image, fit: pw.BoxFit.contain),
                ),
              ),
            );
          }

          return doc.save();
        },
        name: "${widget.product.name}-${widget.product.barcode}",
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

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Container(
          decoration: BoxDecoration(
            color: brandCard,
            borderRadius: BorderRadius.circular(28),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Barcode \u0e41\u0e25\u0e30 QR \u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                RepaintBoundary(
                  key: _captureKey,
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border:
                          Border.all(color: brandPrimary.withOpacity(0.10)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          product.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    height: 1.25,
                                  ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          product.barcode,
                          style: const TextStyle(
                            color: brandPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 18),
                        BarcodeWidget(
                          barcode: Barcode.code128(),
                          data: product.barcode,
                          width: 280,
                          height: 90,
                          drawText: false,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          product.barcode,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: brandInk,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                  ),
                        ),
                        const SizedBox(height: 20),
                        QrImageView(
                          data: product.barcode,
                          size: 180,
                          backgroundColor: Colors.white,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "\u0e2a\u0e41\u0e01\u0e19\u0e44\u0e14\u0e49\u0e17\u0e31\u0e49\u0e07 Barcode \u0e41\u0e25\u0e30 QR",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isPrinting ? null : _printLabel,
                        icon: _isPrinting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.print_outlined),
                        label: const Text("พิมพ์ป้ายสินค้า"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isSharing ? null : _shareLabel,
                        icon: _isSharing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.ios_share_outlined),
                        label: const Text(
                            "\u0e41\u0e0a\u0e23\u0e4c / \u0e2a\u0e48\u0e07\u0e2d\u0e2d\u0e01\u0e1b\u0e49\u0e32\u0e22"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filledTonal(
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: product.barcode));
                        if (context.mounted) {
                          showAppSnack(
                            context,
                            "\u0e04\u0e31\u0e14\u0e25\u0e2d\u0e01 barcode \u0e41\u0e25\u0e49\u0e27",
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_all_outlined),
                      tooltip:
                          "\u0e04\u0e31\u0e14\u0e25\u0e2d\u0e01\u0e23\u0e2b\u0e31\u0e2a",
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomLabelSheet extends StatefulWidget {
  const _CustomLabelSheet({required this.label});

  final String label;

  @override
  State<_CustomLabelSheet> createState() => _CustomLabelSheetState();
}

class _CustomLabelSheetState extends State<_CustomLabelSheet> {
  final GlobalKey _captureKey = GlobalKey();
  bool _isSharing = false;
  bool _isPrinting = false;

  Future<Uint8List> _captureLabelBytes() async {
    final boundary = _captureKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      throw Exception("ไม่พบภาพสำหรับสร้างป้ายชื่อสินค้า");
    }

    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData?.buffer.asUint8List();
    if (bytes == null) {
      throw Exception("สร้างไฟล์ภาพป้ายชื่อสินค้าไม่สำเร็จ");
    }
    return bytes;
  }

  Future<void> _shareLabel() async {
    try {
      setState(() {
        _isSharing = true;
      });

      final bytes = await _captureLabelBytes();
      final tempDir = await getTemporaryDirectory();
      final safeName =
          widget.label.trim().replaceAll(RegExp(r"[^a-zA-Z0-9ก-๙_-]+"), "_");
      final file = File("${tempDir.path}/$safeName-custom-label.png");
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: widget.label,
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

  Future<void> _printLabel() async {
    try {
      setState(() {
        _isPrinting = true;
      });

      final bytes = await _captureLabelBytes();
      final image = pw.MemoryImage(bytes);
      await Printing.layoutPdf(
        onLayout: (format) async {
          final doc = pw.Document();
          doc.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a6,
              margin: const pw.EdgeInsets.all(16),
              build: (context) => pw.Center(
                child: pw.Image(
                  image,
                  fit: pw.BoxFit.contain,
                ),
              ),
            ),
          );
          return doc.save();
        },
        name: widget.label,
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Container(
          decoration: BoxDecoration(
            color: brandCard,
            borderRadius: BorderRadius.circular(28),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "พิมพ์ชื่อสินค้า",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                RepaintBoundary(
                  key: _captureKey,
                  child: Container(
                    width: double.infinity,
                    constraints:
                        const BoxConstraints(maxWidth: 420, minHeight: 220),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border:
                          Border.all(color: brandPrimary.withOpacity(0.10)),
                    ),
                    child: Center(
                      child: Text(
                        widget.label,
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: brandInk,
                                  fontWeight: FontWeight.w800,
                                  height: 1.25,
                                ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isPrinting ? null : _printLabel,
                        icon: _isPrinting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.print_outlined),
                        label: const Text("พิมพ์ชื่อสินค้า"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isSharing ? null : _shareLabel,
                        icon: _isSharing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.ios_share_outlined),
                        label: const Text("แชร์ / ส่งออกป้าย"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
