import "dart:async";
import "dart:convert";
import "dart:io";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:image_picker/image_picker.dart";
import "package:image_cropper/image_cropper.dart";
import "package:url_launcher/url_launcher.dart";
import "package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart";
import "package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart";
import "package:image/image.dart" as img;

import "api_service.dart";
import "models.dart";
import "order_chat_page.dart";
import "theme/app_theme.dart";

class OrdersPage extends StatefulWidget {
  const OrdersPage({
    super.key,
    required this.api,
    required this.currentUser,
    this.refreshSignal,
  });

  final StockApiService api;
  final AppUser currentUser;
  final ValueListenable<int>? refreshSignal;

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final ImagePicker _proofImagePicker = ImagePicker();
  final Map<String, List<String>> _orderProofPhotos = {};
  final GlobalKey<FormState> _createOrderFormKey = GlobalKey<FormState>();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController =
      TextEditingController();
  final TextEditingController _customerAddressController =
      TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String? _selectedAssigneeId;
  String? _selectedProductionUserId;
  String? _selectedQcUserId;
  String? _selectedDeliveryUserId;
  DateTime? _scheduledDeliveryAt;
  bool _showAdvancedTeam = false;
  AutovalidateMode _createOrderAutovalidate = AutovalidateMode.disabled;
  bool _isSaving = false;
  String? _orderPickerId;
  late Future<_OrdersPageData> _future;
  late List<_DraftOrderItem> _draftItems;

  Future<void> _showOrderPreview(DeliveryOrder order) async {
    final statusLabel = order.status == "new"
        ? "ใหม่"
        : order.status == "assigned"
            ? "มอบหมายแล้ว"
            : order.status == "preparing"
                ? "กำลังจัดสินค้า"
                : order.status == "out_for_delivery"
                    ? "กำลังส่ง"
                    : order.status == "delivered"
                        ? "ส่งแล้ว"
                        : order.status == "cancelled"
                            ? "ยกเลิก"
                            : order.status;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.52,
        child: SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        Text(
                          "ใบสรุปออเดอร์",
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.customerName,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const _ReceiptDivider(),
                  const SizedBox(height: 8),
                  _receiptRow("สถานะ", statusLabel),
                  _receiptRow("ผู้รับออเดอร์", order.createdByName),
                  _receiptRow(
                      "ผู้ส่ง", order.assignedToName ?? "ยังไม่มอบหมาย"),
                  if (order.customerPhone != null &&
                      order.customerPhone!.isNotEmpty)
                    _receiptRow("โทร", order.customerPhone!),
                  if (order.customerAddress != null &&
                      order.customerAddress!.isNotEmpty)
                    _receiptRow("ที่อยู่", order.customerAddress!),
                  if (order.scheduledDeliveryAt != null)
                    _receiptRow(
                        "กำหนดส่ง", _fmtDateTime(order.scheduledDeliveryAt!)),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _openOrder(order);
                    },
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text("เปิดออเดอร์นี้"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black.withOpacity(0.60),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  void _openOrder(DeliveryOrder order) {
    // Keep this lightweight: the order is already visible in the list.
    setState(() {
      _orderPickerId = order.id;
    });
    showAppSnack(context, "เลือกออเดอร์แล้ว เลื่อนลงเพื่อจัดการได้เลย");
  }

  @override
  void initState() {
    super.initState();
    _draftItems = [_DraftOrderItem()];
    _future = _load();
    widget.refreshSignal?.addListener(_handleRealtimeRefresh);
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_handleRealtimeRefresh);
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerAddressController.dispose();
    _noteController.dispose();
    for (final item in _draftItems) {
      item.dispose();
    }
    super.dispose();
  }

  void _handleRealtimeRefresh() {
    if (!mounted) {
      return;
    }
    setState(() {
      _future = _load();
    });
  }

  Future<_OrdersPageData> _load() async {
    final results = await Future.wait([
      widget.api.getOrders(requesterId: widget.currentUser.userId, limit: 400),
      widget.api.getUsers(activeOnly: true),
      widget.api.getProducts(),
    ]);
    return _OrdersPageData(
      orders: results[0] as List<DeliveryOrder>,
      users: results[1] as List<AppUser>,
      products: results[2] as List<Product>,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _loadProofPhotosForOrder(String orderId) async {
    try {
      final photos = await widget.api.getOrderProofPhotos(
        requesterId: widget.currentUser.userId,
        orderId: orderId,
      );
      if (!mounted) return;
      setState(() {
        _orderProofPhotos[orderId] = photos;
      });
    } catch (_) {}
  }

  Product? _resolveDraftProduct(_DraftOrderItem item, List<Product> products) {
    if (item.barcode != null) {
      for (final product in products) {
        if (product.barcode == item.barcode) {
          return product;
        }
      }
    }

    final query = item.productController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return null;
    }

    for (final product in products) {
      if (product.name.toLowerCase() == query ||
          product.barcode.toLowerCase() == query ||
          (product.sku?.toLowerCase() == query)) {
        return product;
      }
    }

    final partialMatches = products
        .where((product) {
          return product.name.toLowerCase().contains(query) ||
              product.barcode.toLowerCase().contains(query) ||
              (product.sku?.toLowerCase().contains(query) ?? false);
        })
        .take(2)
        .toList();
    if (partialMatches.length == 1) {
      return partialMatches.first;
    }
    return null;
  }

  Future<void> _createOrder(_OrdersPageData data) async {
    final formState = _createOrderFormKey.currentState;
    if (formState != null) {
      setState(() {
        _createOrderAutovalidate = AutovalidateMode.onUserInteraction;
      });
      if (!formState.validate()) {
        showAppSnack(context, "กรุณากรอก ชื่อ/เบอร์โทร/ที่อยู่ ให้ครบ",
            isError: true);
        return;
      }
    }

    final customerName = _customerNameController.text.trim();
    final items = <Map<String, dynamic>>[];
    for (final item in _draftItems) {
      final resolvedProduct = _resolveDraftProduct(item, data.products);
      final qty = int.tryParse(item.quantityController.text.trim());
      if (resolvedProduct == null || qty == null || qty <= 0) {
        showAppSnack(context, "กรุณาเลือกสินค้าและจำนวนให้ครบทุกแถว");
        return;
      }
      item.barcode = resolvedProduct.barcode;
      item.productController.text = resolvedProduct.name;
      items.add({
        "barcode": resolvedProduct.barcode,
        "quantity": qty,
      });
    }
    if (customerName.isEmpty || items.isEmpty) {
      showAppSnack(context, "กรุณากรอกชื่อลูกค้าและรายการสินค้า");
      return;
    }
    if (_customerPhoneController.text.trim().isEmpty ||
        _customerAddressController.text.trim().isEmpty) {
      showAppSnack(context, "กรุณากรอก ชื่อ/เบอร์โทร/ที่อยู่ ให้ครบ",
          isError: true);
      return;
    }

    setState(() {
      _isSaving = true;
    });
    showAppSnack(context, "กำลังสร้างออเดอร์...");
    try {
      await widget.api.createOrder(
        requesterId: widget.currentUser.userId,
        customerName: customerName,
        customerPhone: _customerPhoneController.text.trim(),
        customerAddress: _customerAddressController.text.trim(),
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        assignedToId: _selectedAssigneeId,
        productionUserId: _selectedProductionUserId,
        qcUserId: _selectedQcUserId,
        deliveryUserId: _selectedDeliveryUserId,
        scheduledDeliveryAt: _scheduledDeliveryAt,
        items: items,
      );
      setState(() {
        _customerNameController.clear();
        _customerPhoneController.clear();
        _customerAddressController.clear();
        _noteController.clear();
        _createOrderFormKey.currentState?.reset();
        _createOrderAutovalidate = AutovalidateMode.disabled;
        _selectedAssigneeId = null;
        _selectedProductionUserId = null;
        _selectedQcUserId = null;
        _selectedDeliveryUserId = null;
        _scheduledDeliveryAt = null;
        for (final item in _draftItems) {
          item.dispose();
        }
        _draftItems = [_DraftOrderItem()];
      });
      if (mounted) {
        showAppSnack(context, "สร้างออเดอร์เรียบร้อย");
      }
      await _refresh();
    } catch (error) {
      final message = error.toString().replaceFirst("Exception: ", "");
      if (mounted) {
        showAppSnack(context, message, isError: true);
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text("สร้างออเดอร์ไม่สำเร็จ"),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text("ปิด"),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _addDraftItem() {
    setState(() {
      _draftItems = [..._draftItems, _DraftOrderItem()];
    });
  }

  void _removeDraftItem(int index) {
    if (_draftItems.length == 1) {
      showAppSnack(context, "ออเดอร์ต้องมีสินค้าอย่างน้อย 1 รายการ");
      return;
    }
    setState(() {
      final target = _draftItems[index];
      target.dispose();
      _draftItems = [
        ..._draftItems.sublist(0, index),
        ..._draftItems.sublist(index + 1),
      ];
    });
  }

  String _fmtDateTime(DateTime value) {
    final d = value;
    final dd = d.day.toString().padLeft(2, "0");
    final mm = d.month.toString().padLeft(2, "0");
    final yy = d.year;
    final hh = d.hour.toString().padLeft(2, "0");
    final mi = d.minute.toString().padLeft(2, "0");
    return "$dd/$mm/$yy $hh:$mi";
  }

  Map<String, String> _parseCustomerFromText(String raw) {
    final cleaned = raw.replaceAll("\r\n", "\n").replaceAll("\r", "\n").trim();
    if (cleaned.isEmpty) {
      return {"name": "", "phone": "", "address": "", "note": ""};
    }

    final lines = cleaned
        .split("\n")
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String name = "";
    String phone = "";
    String address = "";
    String note = "";

    int? sendIndex;
    int? phoneIndex;

    String stripPrefix(String line, List<String> prefixes) {
      var out = line.trim();
      for (final prefix in prefixes) {
        if (out.toLowerCase().startsWith(prefix.toLowerCase())) {
          out = out.substring(prefix.length).trim();
        }
      }
      return out;
    }

    for (var i = 0; i < lines.length; i++) {
      if (lines[i] == "ส่ง") {
        sendIndex = i;
        break;
      }
    }

    for (final line in lines) {
      final lower = line.toLowerCase();
      final digits = line.replaceAll(RegExp(r"\D"), "");

      if (phone.isEmpty &&
          (lower.startsWith("โทร") ||
              lower.startsWith("tel") ||
              lower.startsWith("phone") ||
              digits.length >= 9)) {
        final candidate = stripPrefix(
            line, ["โทร:", "โทร", "tel:", "tel", "phone:", "phone"]);
        final phoneDigits = candidate.replaceAll(RegExp(r"\D"), "");
        if (phoneDigits.length >= 9) {
          phone = phoneDigits;
          phoneIndex = lines.indexOf(line);
          continue;
        }
      }

      if (address.isEmpty &&
          (lower.startsWith("ที่อยู่") ||
              lower.startsWith("addr") ||
              lower.startsWith("address"))) {
        address = stripPrefix(line,
            ["ที่อยู่:", "ที่อยู่", "addr:", "addr", "address:", "address"]);
        continue;
      }

      if (note.isEmpty &&
          (lower.startsWith("หมายเหตุ") || lower.startsWith("note"))) {
        note = stripPrefix(line, ["หมายเหตุ:", "หมายเหตุ", "note:", "note"]);
        continue;
      }
    }

    // Pattern: "ส่ง" then name, then multi-line address, then phone.
    if (sendIndex != null) {
      if (sendIndex! + 1 < lines.length && name.isEmpty) {
        name = lines[sendIndex! + 1];
      }
      final startAddr = (sendIndex! + 2).clamp(0, lines.length);
      final endAddr = phoneIndex == null
          ? lines.length
          : phoneIndex!.clamp(0, lines.length);
      if (startAddr < endAddr) {
        final addrLines =
            lines.sublist(startAddr, endAddr).where((l) => l != "ส่ง").toList();
        if (addrLines.isNotEmpty && address.isEmpty) {
          address = addrLines.join(" ");
        }
      }
      // Everything before "ส่ง" is usually items; keep in note if note not provided.
      if (note.isEmpty && sendIndex! > 0) {
        note = lines.sublist(0, sendIndex!).join(" | ");
      }
    }

    if (name.isEmpty) {
      for (final line in lines) {
        final lower = line.toLowerCase();
        if (lower.startsWith("โทร") ||
            lower.startsWith("tel") ||
            lower.startsWith("phone") ||
            lower.startsWith("ที่อยู่") ||
            lower.startsWith("addr") ||
            lower.startsWith("address") ||
            lower.startsWith("หมายเหตุ") ||
            lower.startsWith("note")) {
          continue;
        }
        final digits = line.replaceAll(RegExp(r"\D"), "");
        if (digits.length >= 9 && digits.length >= (line.length * 0.7)) {
          continue;
        }
        if (line == "ส่ง") {
          continue;
        }
        name = line;
        break;
      }
    }

    if (address.isEmpty && lines.length >= 2) {
      final ignored = <String>{};
      if (name.isNotEmpty) ignored.add(name);
      if (note.isNotEmpty) ignored.add(note);
      final phoneDigits = phone;
      final candidates = lines.where((l) {
        if (ignored.contains(l)) return false;
        final digits = l.replaceAll(RegExp(r"\D"), "");
        if (phoneDigits.isNotEmpty && digits == phoneDigits) return false;
        final lower = l.toLowerCase();
        if (lower.startsWith("โทร") ||
            lower.startsWith("tel") ||
            lower.startsWith("phone") ||
            lower.startsWith("หมายเหตุ") ||
            lower.startsWith("note")) return false;
        return true;
      }).toList();
      if (candidates.isNotEmpty) {
        address = candidates.join(" ");
      }
    }

    return {"name": name, "phone": phone, "address": address, "note": note};
  }

  Future<void> _pasteCustomerFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text ?? "";
      final parsed = _parseCustomerFromText(text);
      if (!mounted) return;
      setState(() {
        if (parsed["name"]!.trim().isNotEmpty)
          _customerNameController.text = parsed["name"]!.trim();
        if (parsed["phone"]!.trim().isNotEmpty)
          _customerPhoneController.text = parsed["phone"]!.trim();
        if (parsed["address"]!.trim().isNotEmpty)
          _customerAddressController.text = parsed["address"]!.trim();
        if (parsed["note"]!.trim().isNotEmpty)
          _noteController.text = parsed["note"]!.trim();
      });
      if (mounted) showAppSnack(context, "วางข้อมูลลูกค้าแล้ว");
    } catch (e) {
      if (mounted) {
        showAppSnack(context, "วางจากคลิปบอร์ดไม่สำเร็จ", isError: true);
      }
    }
  }

  String _normalizePhone(String raw) {
    var phone = raw.replaceAll(RegExp(r'[\s\-()]+'), '');
    if (phone.startsWith('+66')) {
      phone = '0${phone.substring(3)}';
    } else if (phone.startsWith('66')) {
      phone = '0${phone.substring(2)}';
    }
    return phone;
  }

  Future<String?> _runManualCrop(String sourcePath) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: sourcePath,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'ครอบตัดรูปภาพ',
            toolbarColor: brandPrimary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'ครอบตัดรูปภาพ',
            aspectRatioLockEnabled: false,
          ),
        ],
      );
      return croppedFile?.path;
    } catch (e) {
      debugPrint("Manual crop failed: $e");
      if (mounted) {
        showAppSnack(context, "การครอบตัดขัดข้อง ใช้รูปภาพต้นฉบับแทน");
      }
      return sourcePath;
    }
  }

  Future<String?> _autoCropGalleryImage(String sourcePath) async {
    try {
      final inputImage = InputImage.fromFilePath(sourcePath);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      if (recognizedText.text.trim().isEmpty) {
        return null;
      }

      double? minX;
      double? minY;
      double? maxX;
      double? maxY;

      for (final block in recognizedText.blocks) {
        final rect = block.boundingBox;
        if (minX == null || rect.left < minX) minX = rect.left;
        if (minY == null || rect.top < minY) minY = rect.top;
        if (maxX == null || rect.right > maxX) maxX = rect.right;
        if (maxY == null || rect.bottom > maxY) maxY = rect.bottom;
      }

      if (minX == null || minY == null || maxX == null || maxY == null) {
        return null;
      }

      final bytes = await File(sourcePath).readAsBytes();
      final decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) {
        return null;
      }

      const int padding = 24;
      final int left = (minX.toInt() - padding).clamp(0, decodedImage.width);
      final int top = (minY.toInt() - padding).clamp(0, decodedImage.height);
      final int right = (maxX.toInt() + padding).clamp(0, decodedImage.width);
      final int bottom = (maxY.toInt() + padding).clamp(0, decodedImage.height);

      final int width = right - left;
      final int height = bottom - top;

      if (width <= 50 || height <= 50) {
        return null;
      }

      final croppedImage = img.copyCrop(decodedImage, x: left, y: top, width: width, height: height);

      final tempDir = Directory.systemTemp;
      final croppedFile = File('${tempDir.path}/autocropped_${DateTime.now().millisecondsSinceEpoch}.png');
      await croppedFile.writeAsBytes(img.encodePng(croppedImage));

      return croppedFile.path;
    } catch (e) {
      debugPrint("Auto-crop gallery image failed: $e");
      return null;
    }
  }

  Future<String?> _showCropPreviewDialog(String croppedPath, String originalPath) async {
    return showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "ตรวจพบเอกสาร/ใบปะหน้า",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "ระบบครอบตัดให้อัตโนมัติ คุณต้องการใช้รูปภาพนี้หรือปรับแต่งเอง?",
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 280),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Platform.environment.containsKey('FLUTTER_TEST')
                    ? const Center(child: Text("Image Preview Placeholder"))
                    : Image.file(
                        File(croppedPath),
                        fit: BoxFit.contain,
                      ),
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context, "manual");
            },
            icon: const Icon(Icons.crop),
            label: const Text("ปรับแต่งเอง"),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context, croppedPath);
            },
            icon: const Icon(Icons.check),
            label: const Text("ดำเนินการต่อ"),
          ),
        ],
      ),
    );
  }

  Future<void> _scanCustomerInfo() async {
    try {
      final String? selection = await showModalBottomSheet<String?>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => SafeArea(
          child: Wrap(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  "ครอบตัดให้เหลือเฉพาะใบปะหน้า/เอกสารก่อนสแกน เพื่อความแม่นยำสูงสุด",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text("ถ่ายรูป (สแกนอัตโนมัติ)"),
                onTap: () {
                  Navigator.pop(context, "camera");
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text("เลือกจากคลังภาพ"),
                onTap: () {
                  Navigator.pop(context, "gallery");
                },
              ),
            ],
          ),
        ),
      );

      if (selection == null) return;

      String? targetPath;
      String? selectedImagePath;

      if (selection == "camera") {
        try {
          final docScanner = DocumentScanner(
            options: DocumentScannerOptions(
              documentFormats: {DocumentFormat.jpeg},
              mode: ScannerMode.filter,
              isGalleryImport: false,
            ),
          );
          final DocumentScanningResult result = await docScanner.scanDocument();
          await docScanner.close();

          if (result.images != null && result.images!.isNotEmpty) {
            selectedImagePath = result.images!.first;
            targetPath = result.images!.first;
          } else {
            // Cancelled scanning activity
            return;
          }
        } catch (e) {
          debugPrint("Document scanner failed, falling back to camera: $e");
          final XFile? file = await _proofImagePicker.pickImage(
            source: ImageSource.camera,
            imageQuality: 80,
          );
          if (file == null) return;
          selectedImagePath = file.path;
          targetPath = await _runManualCrop(file.path);
          if (targetPath == null) return;
        }
      } else if (selection == "gallery") {
        final XFile? file = await _proofImagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 80,
        );
        if (file == null) return;
        selectedImagePath = file.path;

        setState(() {
          _isSaving = true;
        });

        final autoCroppedPath = await _autoCropGalleryImage(file.path);

        setState(() {
          _isSaving = false;
        });

        if (autoCroppedPath != null) {
          if (mounted) {
            final previewResult = await _showCropPreviewDialog(autoCroppedPath, file.path);
            if (previewResult == null) {
              return;
            }
            if (previewResult == "manual") {
              targetPath = await _runManualCrop(file.path);
              if (targetPath == null) return;
            } else {
              targetPath = previewResult;
            }
          }
        } else {
          targetPath = await _runManualCrop(file.path);
          if (targetPath == null) return;
        }
      }

      if (targetPath == null) return;

      debugPrint("SELECTED IMAGE PATH: $selectedImagePath");
      debugPrint("CROPPED/FINAL OCR IMAGE PATH: $targetPath");

      setState(() {
        _isSaving = true;
      });

      Map<String, String?> parsed = {};
      bool isComplete = false;
      bool isQuotaExceeded = false;
      String ocrSource = "Unknown";

      try {
        debugPrint("CALLING AI OCR");
        final geminiParsed = await widget.api.ocrShippingLabel(
          requesterId: widget.currentUser.userId,
          filePath: targetPath,
        );
        debugPrint("AI OCR RESPONSE MAP: $geminiParsed");
        
        final name = geminiParsed["name"]?.trim() ?? "";
        final phone = geminiParsed["phone"]?.trim() ?? "";
        final address = geminiParsed["address"]?.trim() ?? "";

        if (name.isNotEmpty && phone.isNotEmpty && address.isNotEmpty) {
          parsed = {
            "name": name,
            "phone": phone,
            "address": address,
          };
          isComplete = true;
          ocrSource = "Gemini";
          debugPrint("USING AI OCR");
        } else {
          parsed = {
            "name": name.isEmpty ? null : name,
            "phone": phone.isEmpty ? null : phone,
            "address": address.isEmpty ? null : address,
          };
          ocrSource = "Gemini rejected low quality";
        }
      } catch (e) {
        final errStr = e.toString().toLowerCase();
        isQuotaExceeded = errStr.contains("429") || errStr.contains("quota") || errStr.contains("resource exceeded");
        debugPrint("Gemini OCR failed or timed out: $e (quota exceeded: $isQuotaExceeded)");
        ocrSource = isQuotaExceeded ? "Gemini Quota Exceeded" : "MLKit fallback";
        if (mounted) {
          showAppSnack(
            context,
            isQuotaExceeded
                ? "ระบบสแกนใบปะหน้าด้วย AI ใช้งานเกินโควตาชั่วคราว กรุณาลองใหม่อีกครั้ง"
                : "สแกนด้วย Gemini ไม่สำเร็จ: ${e.toString().replaceAll('Exception: ', '')}",
            isError: true,
          );
        }
        if (isQuotaExceeded) {
          return;
        }
      }

      if (isQuotaExceeded) {
        return;
      }

      if (!isComplete) {
        debugPrint("USING MLKIT FALLBACK");
        try {
          final inputImage = InputImage.fromFilePath(targetPath);
          final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
          final RecognizedText recognizedText =
              await textRecognizer.processImage(inputImage);
          await textRecognizer.close();

          final rawText = recognizedText.text;
          if (rawText.trim().isNotEmpty) {
            final mlKitParsed = parseCustomerOcr(rawText);
            
            final nameVal = mlKitParsed["name"];
            if (nameVal != null && !_isPseudoLatinSoup(nameVal)) {
              parsed["name"] ??= nameVal;
            }
            
            parsed["phone"] ??= mlKitParsed["phone"];
            
            final addressVal = mlKitParsed["address"];
            if (addressVal != null && !_isPseudoLatinSoup(addressVal)) {
              parsed["address"] ??= addressVal;
            }
          }
        } catch (e) {
          debugPrint("Local ML Kit OCR failed: $e");
        }
      }

      final finalName = parsed["name"]?.trim() ?? "";
      final finalPhone = parsed["phone"]?.trim() ?? "";
      final finalAddress = parsed["address"]?.trim() ?? "";

      debugPrint("FINAL NAME: $finalName");
      debugPrint("FINAL PHONE: $finalPhone");
      debugPrint("FINAL ADDRESS: $finalAddress");

      if (finalName.isEmpty && finalPhone.isEmpty && finalAddress.isEmpty) {
        if (mounted) {
          showAppSnack(context, "ไม่พบข้อความในรูปภาพ", isError: true);
        }
        return;
      }

      final normalizedPhone = finalPhone.isNotEmpty ? _normalizePhone(finalPhone) : "";

      if (!mounted) return;

      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("ยืนยันข้อมูลที่สแกนได้"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Text("ชื่อ: ${finalName.isEmpty ? "-" : finalName}"),
              Text("เบอร์โทร: ${normalizedPhone.isEmpty ? "-" : normalizedPhone}"),
              Text("ที่อยู่: ${finalAddress.isEmpty ? "-" : finalAddress}"),
              const Divider(height: 24),
              Text(
                "* เคล็ดลับ: ครอบตัดรูปภาพให้เหลือเฉพาะบริเวณใบปะหน้า/เอกสารก่อนสแกน เพื่อความแม่นยำสูงสุด",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("ยกเลิก"),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("ใช้ข้อมูลนี้"),
            ),
          ],
        ),
      );

      if (confirm == true && mounted) {
        setState(() {
          if (finalName.isNotEmpty) _customerNameController.text = finalName;
          if (normalizedPhone.isNotEmpty) {
            _customerPhoneController.text = normalizedPhone;
          }
          if (finalAddress.isNotEmpty) {
            _customerAddressController.text = finalAddress;
          }
        });
        showAppSnack(context, "เติมข้อมูลลูกค้าเรียบร้อย");
      }
    } catch (e) {
      if (mounted) showAppSnack(context, "สแกนไม่สำเร็จ: $e", isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _openCancelledOrders(
    List<DeliveryOrder> cancelled,
    List<AppUser> activeStaff,
    _OrdersPageData data,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _CancelledOrdersPage(
          orders: cancelled,
          currentUser: widget.currentUser,
          api: widget.api,
          proofPhotos: _orderProofPhotos,
          onLoadProofPhotos: _loadProofPhotosForOrder,
          staff: activeStaff,
          onAssign: _assignOrder,
          onOpenProofGallery: _openProofGallery,
        ),
      ),
    );
  }

  String _userLabelById(List<AppUser> users, String? id, String fallback) {
    if (id == null) return fallback;
    for (final user in users) {
      if (user.userId == id) return "${user.userName} (${user.userId})";
    }
    return fallback;
  }

  Future<void> _updateStatus(DeliveryOrder order, String status) async {
    try {
      await widget.api.updateOrderStatus(
        requesterId: widget.currentUser.userId,
        orderId: order.id,
        status: status,
      );
      if (status == "delivered" && mounted) {
        await _showDeliveredCatAnimation();
      }
      showAppSnack(context, "อัปเดตสถานะแล้ว");
      await _refresh();
    } catch (error) {
      showAppSnack(
        context,
        error.toString().replaceFirst("Exception: ", ""),
        isError: true,
      );
    }
  }

  Future<void> _showDeliveredCatAnimation() {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: "delivery_success",
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) => const _DeliverySuccessOverlay(),
    );
  }

  Future<void> _uploadProofPhoto(DeliveryOrder order) async {
    try {
      final file = await _proofImagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1800,
      );
      if (file == null) return;
      await widget.api.uploadOrderProofPhoto(
        requesterId: widget.currentUser.userId,
        orderId: order.id,
        filePath: file.path,
      );
      await _loadProofPhotosForOrder(order.id);
      showAppSnack(context, "อัปโหลดรูปหลักฐานแล้ว");
    } catch (error) {
      showAppSnack(context, error.toString().replaceFirst("Exception: ", ""));
    }
  }

  Future<void> _deliverPartial(DeliveryOrder order) async {
    final qtyValues = <String, String>{
      for (final item in order.items)
        item.barcode:
            "${(item.quantity - item.deliveredQuantity).clamp(0, item.quantity)}",
    };
    String note = "";
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("ส่งสินค้า (บางส่วน)"),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...order.items.map((item) {
                        final remaining =
                            item.quantity - item.deliveredQuantity;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                  child: Text(
                                      "${item.productName} (ค้าง $remaining)")),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 72,
                                child: TextFormField(
                                  initialValue: qtyValues[item.barcode] ?? "0",
                                  keyboardType: TextInputType.number,
                                  decoration:
                                      const InputDecoration(labelText: "ส่ง"),
                                  onChanged: (value) =>
                                      qtyValues[item.barcode] = value,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      TextField(
                        onChanged: (value) => note = value,
                        decoration:
                            const InputDecoration(labelText: "หมายเหตุ"),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text("ยกเลิก")),
                FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text("บันทึก")),
              ],
            );
          },
        );
      },
    );
    if (confirmed != true) return;
    try {
      final items = <Map<String, dynamic>>[];
      for (final item in order.items) {
        final qty = int.tryParse((qtyValues[item.barcode] ?? "0").trim()) ?? 0;
        if (qty > 0) {
          items.add({"barcode": item.barcode, "quantity": qty});
        }
      }
      if (items.isEmpty) {
        showAppSnack(context, "กรุณาใส่จำนวนที่ส่งอย่างน้อย 1 รายการ");
        return;
      }
      final updated = await widget.api.deliverOrderPartial(
        requesterId: widget.currentUser.userId,
        orderId: order.id,
        items: items,
        note: note.isEmpty ? null : note,
      );
      if (updated.status == "delivered") {
        await widget.api.updateOrderStatus(
          requesterId: widget.currentUser.userId,
          orderId: order.id,
          status: "out_for_delivery",
        );
      }
      showAppSnack(context, "บันทึกการส่งบางส่วนแล้ว");
      await _loadProofPhotosForOrder(order.id);
      if (!mounted) return;
      setState(() {
        _future = _load();
      });
      await _future;
    } catch (error) {
      showAppSnack(context, error.toString().replaceFirst("Exception: ", ""));
    }
  }

  Future<void> _fixDeliveryStatus(DeliveryOrder order) async {
    final targetValues = <String, String>{
      for (final item in order.items)
        item.barcode: "${item.deliveredQuantity}",
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("แก้ไขจำนวนส่ง (แอดมิน)"),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...order.items.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  "${item.productName} (ทั้งหมด ${item.quantity})",
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 72,
                                child: TextFormField(
                                  initialValue:
                                      targetValues[item.barcode] ?? "0",
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      labelText: "ส่งแล้ว"),
                                  onChanged: (value) =>
                                      targetValues[item.barcode] = value,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          "ใส่จำนวน 'ส่งแล้ว' ทั้งหมดที่ต้องการให้เป็นระบบจะคำนวณส่วนต่างให้อัตโนมัติ",
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text("ยกเลิก")),
                FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text("บันทึกการแก้ไข")),
              ],
            );
          },
        );
      },
    );
    if (confirmed != true) return;
    try {
      final items = <Map<String, dynamic>>[];
      final List<String> correctionLogs = [];
      for (final item in order.items) {
        final target =
            int.tryParse((targetValues[item.barcode] ?? "0").trim()) ?? 0;
        final delta = target - item.deliveredQuantity;
        if (delta != 0) {
          items.add({"barcode": item.barcode, "quantity": delta});
          correctionLogs.add("${item.productName}: ${item.deliveredQuantity} -> $target");
        }
      }

      if (items.isEmpty) {
        showAppSnack(context, "ไม่มีการเปลี่ยนแปลง");
        return;
      }

      final auditNote =
          "[Correction] Admin: ${widget.currentUser.userName} | ${correctionLogs.join(', ')}";

      await widget.api.deliverOrderPartial(
        requesterId: widget.currentUser.userId,
        orderId: order.id,
        items: items,
        note: auditNote,
      );
      showAppSnack(context, "แก้ไขจำนวนส่งเรียบร้อยแล้ว");
      if (!mounted) return;
      setState(() {
        _future = _load();
      });
      await _future;
    } catch (error) {
      showAppSnack(context, error.toString().replaceFirst("Exception: ", ""));
    }
  }

  void _openProofGallery(DeliveryOrder order) {
    final photos = _orderProofPhotos[order.id] ?? const <String>[];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.7,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("รูปหลักฐานการส่ง",
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (photos.isEmpty)
                const Expanded(child: Center(child: Text("ยังไม่มีรูปหลักฐาน")))
              else
                Expanded(
                  child: GridView.builder(
                    itemCount: photos.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemBuilder: (context, index) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          photos[index],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color:
                                  brandSurfaceStrong.withOpacity(0.35),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.all(12),
                              child: const Text(
                                "ดูรูปไม่ได้",
                                textAlign: TextAlign.center,
                              ),
                            );
                          },
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

  Future<void> _assignOrder(DeliveryOrder order, List<AppUser> users) async {
    String? production = order.productionUserId;
    String? qc = order.qcUserId;
    String? delivery = order.deliveryUserId ?? order.assignedToId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("มอบหมายทีมงาน"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String?>(
                      value: production,
                      decoration: const InputDecoration(labelText: "ฝ่ายผลิต"),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text("ยังไม่กำหนด")),
                        ...users.map((u) => DropdownMenuItem<String?>(
                            value: u.userId,
                            child: Text("${u.userName} (${u.userId})"))),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => production = value),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String?>(
                      value: qc,
                      decoration: const InputDecoration(labelText: "QC"),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text("ยังไม่กำหนด")),
                        ...users.map((u) => DropdownMenuItem<String?>(
                            value: u.userId,
                            child: Text("${u.userName} (${u.userId})"))),
                      ],
                      onChanged: (value) => setDialogState(() => qc = value),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String?>(
                      value: delivery,
                      decoration: const InputDecoration(labelText: "จัดส่ง"),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text("ยังไม่กำหนด")),
                        ...users.map((u) => DropdownMenuItem<String?>(
                            value: u.userId,
                            child: Text("${u.userName} (${u.userId})"))),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => delivery = value),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text("ยกเลิก"),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text("บันทึก"),
                ),
              ],
            );
          },
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    try {
      await widget.api.assignOrderTeam(
        requesterId: widget.currentUser.userId,
        orderId: order.id,
        productionUserId: production,
        qcUserId: qc,
        deliveryUserId: delivery,
      );
      showAppSnack(context, "บันทึกทีมงานเรียบร้อย");
      await _refresh();
    } catch (error) {
      showAppSnack(context, error.toString().replaceFirst("Exception: ", ""));
    }
  }

  Future<void> _resolveBackorder(DeliveryOrder order) async {
    try {
      await widget.api.resolveBackorder(
        requesterId: widget.currentUser.userId,
        orderId: order.id,
      );
      showAppSnack(context, "ปิดค้างจ่ายแล้ว");
      await _refresh();
    } catch (error) {
      showAppSnack(context, error.toString().replaceFirst("Exception: ", ""),
          isError: true);
    }
  }

  void _openBackorderReport(List<DeliveryOrder> orders) {
    final backorders = orders.where((order) {
      return order.items.any((item) => item.deliveredQuantity < item.quantity);
    }).toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.82,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: _BackorderReportSheet(
            backorders: backorders,
            currentUser: widget.currentUser,
            onFixStatus: _fixDeliveryStatus,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ColoredBox(
        color: brandSurface,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<_OrdersPageData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _ErrorState(message: snapshot.error.toString());
              }
              final data = snapshot.data!;
              for (final order in data.orders) {
                if (!_orderProofPhotos.containsKey(order.id)) {
                  unawaited(_loadProofPhotosForOrder(order.id));
                }
              }
              final backorderOrders = data.orders.where((order) {
                if (order.status == "cancelled") {
                  return false;
                }
                return order.items
                    .any((item) => item.deliveredQuantity < item.quantity);
              }).toList();
              final activeStaff =
                  data.users.where((item) => item.active).toList();

              final listPadding = kIsWeb
                  ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
                  : const EdgeInsets.all(16);
              return ListView(
                padding: listPadding,
                children: [
                  const _PageHeader(
                    title: "ออเดอร์และจัดส่ง",
                    subtitle:
                        "รับออเดอร์จากลูกค้า มอบหมายคนส่ง และติดตามสถานะงาน",
                    showBackButton: true,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Card(
                            color: Colors.red.withOpacity(0.05),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "รายงานค้างจ่าย (${backorderOrders.length} ออเดอร์)",
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: Colors.red.shade700,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          _openBackorderReport(data.orders),
                                      icon: const Icon(Icons.list_alt_outlined),
                                      label: const Text("เปิดรายงานแบบเต็ม"),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (backorderOrders.isEmpty)
                                    const Text("ไม่มีออเดอร์ค้างจ่ายตอนนี้")
                                  else
                                    ...backorderOrders.take(6).map((order) {
                                      final pendingItems = order.items.where(
                                        (item) =>
                                            item.deliveredQuantity <
                                            item.quantity,
                                      );
                                      final summary = pendingItems
                                          .map(
                                            (item) =>
                                                "${item.productName} ค้าง ${item.quantity - item.deliveredQuantity}",
                                          )
                                          .join(", ");
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 6),
                                        child: Text(
                                            "โดย ${order.customerName}: $summary"),
                                      );
                                    }),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "สร้างออเดอร์ใหม่",
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Wrap(
                                      spacing: 8,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: _pasteCustomerFromClipboard,
                                          icon: const Icon(
                                              Icons.content_paste_go_outlined),
                                          label:
                                              const Text("วางข้อมูลลูกค้าจากแชท"),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: _scanCustomerInfo,
                                          icon: const Icon(
                                              Icons.document_scanner_outlined),
                                          label: const Text("สแกนข้อมูลลูกค้า"),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Form(
                                    key: _createOrderFormKey,
                                    autovalidateMode: _createOrderAutovalidate,
                                    child: Column(
                                      children: [
                                        TextFormField(
                                          controller: _customerNameController,
                                          decoration: const InputDecoration(
                                            labelText: "ชื่อลูกค้า",
                                            helperText: "จำเป็น",
                                          ),
                                          validator: (value) {
                                            if (value == null ||
                                                value.trim().isEmpty) {
                                              return "กรุณากรอกชื่อลูกค้า";
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 10),
                                        TextFormField(
                                          controller: _customerPhoneController,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
                                          decoration: const InputDecoration(
                                            labelText: "เบอร์โทร",
                                            helperText: "จำเป็น",
                                          ),
                                          validator: (value) {
                                            final v = value?.trim() ?? "";
                                            if (v.isEmpty)
                                              return "กรุณากรอกเบอร์โทร";
                                            if (v.length < 9)
                                              return "เบอร์โทรสั้นเกินไป";
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 10),
                                        TextFormField(
                                          controller:
                                              _customerAddressController,
                                          maxLines: 2,
                                          decoration: const InputDecoration(
                                            labelText: "ที่อยู่",
                                            helperText: "จำเป็น",
                                          ),
                                          validator: (value) {
                                            if (value == null ||
                                                value.trim().isEmpty) {
                                              return "กรุณากรอกที่อยู่";
                                            }
                                            return null;
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    "รายการสินค้า",
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 10),
                                  ...List.generate(_draftItems.length, (index) {
                                    final draftItem = _draftItems[index];
                                    Product? selectedProduct;
                                    if (draftItem.barcode != null) {
                                      for (final product in data.products) {
                                        if (product.barcode ==
                                            draftItem.barcode) {
                                          selectedProduct = product;
                                          break;
                                        }
                                      }
                                    }
                                    final query = draftItem
                                        .productController.text
                                        .trim()
                                        .toLowerCase();
                                    final showSuggestions = query.isNotEmpty &&
                                        selectedProduct == null;
                                    final matchedProducts = showSuggestions
                                        ? data.products
                                            .where((product) {
                                              return product.name
                                                      .toLowerCase()
                                                      .contains(query) ||
                                                  product.barcode
                                                      .toLowerCase()
                                                      .contains(query) ||
                                                  (product.sku
                                                          ?.toLowerCase()
                                                          .contains(query) ??
                                                      false);
                                            })
                                            .take(6)
                                            .toList()
                                        : const <Product>[];
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          TextField(
                                            controller:
                                                draftItem.productController,
                                            decoration: InputDecoration(
                                              labelText: "สินค้า ${index + 1}",
                                              hintText:
                                                  "พิมพ์ชื่อสินค้า บาร์โค้ด หรือ SKU",
                                              prefixIcon:
                                                  const Icon(Icons.search),
                                            ),
                                            onChanged: (_) {
                                              setState(() {
                                                draftItem.barcode = null;
                                              });
                                            },
                                          ),
                                          if (matchedProducts.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Container(
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                    color: brandPrimary
                                                        .withOpacity(0.16)),
                                              ),
                                              child: Column(
                                                children: matchedProducts
                                                    .map((product) {
                                                  return ListTile(
                                                    dense: true,
                                                    title: Text(
                                                      product.name,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    subtitle: Text(
                                                      "${product.barcode} · คงเหลือ ${product.currentStock} ${product.unit}",
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    onTap: () {
                                                      setState(() {
                                                        draftItem.barcode =
                                                            product.barcode;
                                                        draftItem
                                                            .productController
                                                            .text = product.name;
                                                      });
                                                    },
                                                    trailing: const Icon(
                                                        Icons
                                                            .north_west_rounded,
                                                        size: 18),
                                                  );
                                                }).toList(),
                                              ),
                                            ),
                                          ],
                                          if (selectedProduct != null) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              "บาร์โค้ด: ${selectedProduct.barcode} · คงเหลือ ${selectedProduct.currentStock} ${selectedProduct.unit}",
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: brandInk
                                                        .withOpacity(0.72),
                                                  ),
                                            ),
                                          ],
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: TextField(
                                                  controller: draftItem
                                                      .quantityController,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  decoration:
                                                      const InputDecoration(
                                                          labelText: "จำนวน"),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              IconButton.filledTonal(
                                                onPressed: () =>
                                                    _removeDraftItem(index),
                                                icon: const Icon(
                                                    Icons.delete_outline),
                                                tooltip: "ลบรายการ",
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: OutlinedButton.icon(
                                      onPressed: _addDraftItem,
                                      icon: const Icon(Icons.add),
                                      label: const Text("เพิ่มสินค้าอีกตัว"),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text("ทีมงานออเดอร์"),
                                    subtitle: Text(
                                      "ผลิต: ${_userLabelById(activeStaff, _selectedProductionUserId, "-")} · "
                                      "QC: ${_userLabelById(activeStaff, _selectedQcUserId, "-")} · "
                                      "ส่ง: ${_userLabelById(activeStaff, _selectedDeliveryUserId ?? _selectedAssigneeId, "-")}",
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: TextButton(
                                      onPressed: () => setState(
                                        () => _showAdvancedTeam =
                                            !_showAdvancedTeam,
                                      ),
                                      child: Text(
                                          _showAdvancedTeam ? "ย่อ" : "กำหนด"),
                                    ),
                                  ),
                                  if (_showAdvancedTeam) ...[
                                    DropdownButtonFormField<String?>(
                                      value: _selectedProductionUserId,
                                      decoration: const InputDecoration(
                                          labelText: "ฝ่ายผลิต"),
                                      items: [
                                        const DropdownMenuItem<String?>(
                                          value: null,
                                          child: Text("-"),
                                        ),
                                        ...activeStaff.map(
                                          (user) => DropdownMenuItem<String?>(
                                            value: user.userId,
                                            child: Text(
                                                "${user.userName} (${user.userId})"),
                                          ),
                                        ),
                                      ],
                                      onChanged: (value) => setState(
                                        () => _selectedProductionUserId = value,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String?>(
                                      value: _selectedQcUserId,
                                      decoration: const InputDecoration(
                                          labelText: "QC"),
                                      items: [
                                        const DropdownMenuItem<String?>(
                                          value: null,
                                          child: Text("-"),
                                        ),
                                        ...activeStaff.map(
                                          (user) => DropdownMenuItem<String?>(
                                            value: user.userId,
                                            child: Text(
                                                "${user.userName} (${user.userId})"),
                                          ),
                                        ),
                                      ],
                                      onChanged: (value) => setState(
                                          () => _selectedQcUserId = value),
                                    ),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String?>(
                                      value: _selectedDeliveryUserId ??
                                          _selectedAssigneeId,
                                      decoration: const InputDecoration(
                                          labelText: "จัดส่ง"),
                                      items: [
                                        const DropdownMenuItem<String?>(
                                          value: null,
                                          child: Text("-"),
                                        ),
                                        ...activeStaff.map(
                                          (user) => DropdownMenuItem<String?>(
                                            value: user.userId,
                                            child: Text(
                                                "${user.userName} (${user.userId})"),
                                          ),
                                        ),
                                      ],
                                      onChanged: (value) => setState(() {
                                        _selectedDeliveryUserId = value;
                                        _selectedAssigneeId = value;
                                      }),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      final now = DateTime.now();
                                      final pickedDate = await showDatePicker(
                                        context: context,
                                        initialDate:
                                            _scheduledDeliveryAt ?? now,
                                        firstDate: now
                                            .subtract(const Duration(days: 1)),
                                        lastDate:
                                            now.add(const Duration(days: 365)),
                                      );
                                      if (pickedDate == null || !mounted)
                                        return;
                                      final pickedTime = await showTimePicker(
                                        context: context,
                                        initialTime: TimeOfDay.fromDateTime(
                                          _scheduledDeliveryAt ?? now,
                                        ),
                                      );
                                      if (pickedTime == null || !mounted)
                                        return;
                                      setState(() {
                                        _scheduledDeliveryAt = DateTime(
                                          pickedDate.year,
                                          pickedDate.month,
                                          pickedDate.day,
                                          pickedTime.hour,
                                          pickedTime.minute,
                                        );
                                      });
                                    },
                                    icon: const Icon(Icons.schedule_outlined),
                                    label: Text(
                                      _scheduledDeliveryAt == null
                                          ? "กำหนดเวลาจัดส่ง"
                                          : "เวลาจัดส่ง: ${_fmtDateTime(_scheduledDeliveryAt!)}",
                                    ),
                                  ),
                                  TextField(
                                    controller: _noteController,
                                    maxLines: 2,
                                    decoration: const InputDecoration(
                                        labelText: "หมายเหตุ"),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed: _isSaving
                                          ? null
                                          : () => _createOrder(data),
                                      icon: _isSaving
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2),
                                            )
                                          : const Icon(Icons.add_task_outlined),
                                      label: const Text("สร้างออเดอร์"),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "รายการออเดอร์",
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          if (data.orders.isEmpty)
                            const _EmptyTile(message: "ยังไม่มีออเดอร์ในระบบ")
                          else
                            ...(() {
                              final cancelled = data.orders
                                  .where((o) => o.status == "cancelled")
                                  .toList();
                              final active = data.orders
                                  .where((o) => o.status != "cancelled")
                                  .toList();
                              return <Widget>[
                                if (active.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Material(
                                      type: MaterialType.transparency,
                                      child: DropdownMenu<String>(
                                        initialSelection: _orderPickerId,
                                        expandedInsets: EdgeInsets.zero,
                                        enableFilter: true,
                                        enableSearch: true,
                                        leadingIcon:
                                            const Icon(Icons.search_rounded),
                                        label: const Text("เลือกออเดอร์"),
                                        hintText:
                                            "พิมพ์ชื่อ/เบอร์/รหัสออเดอร์เพื่อค้นหา",
                                        dropdownMenuEntries: active
                                            .map(
                                              (order) =>
                                                  DropdownMenuEntry<String>(
                                                value: order.id,
                                                label:
                                                    "${order.customerName} • ${order.id.substring(0, 8)} • ${order.status}",
                                              ),
                                            )
                                            .toList(),
                                        onSelected: (value) async {
                                          if (value == null) return;
                                          setState(() {
                                            _orderPickerId = value;
                                          });
                                          final target = active.firstWhere(
                                            (o) => o.id == value,
                                            orElse: () => active.first,
                                          );
                                          await _showOrderPreview(target);
                                        },
                                      ),
                                    ),
                                  ),
                                if (cancelled.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: OutlinedButton.icon(
                                      onPressed: () => _openCancelledOrders(
                                          cancelled, activeStaff, data),
                                      icon: const Icon(Icons.archive_outlined),
                                      label: Text(
                                          "ดูออเดอร์ที่ยกเลิก (${cancelled.length})"),
                                    ),
                                  ),
                                ...active.map(
                                  (order) => _OrderTile(
                                    order: order,
                                    api: widget.api,
                                    currentUser: widget.currentUser,
                                    printUrl: widget.api.orderPrintUrl(
                                      orderId: order.id,
                                      requesterId: widget.currentUser.userId,
                                    ),
                                    packingSlipUrl:
                                        widget.api.orderPackingSlipUrl(
                                      orderId: order.id,
                                      requesterId: widget.currentUser.userId,
                                    ),
                                    pdfUrl: widget.api.orderPdfUrl(
                                      orderId: order.id,
                                      requesterId: widget.currentUser.userId,
                                    ),
                                    onAssign: () =>
                                        _assignOrder(order, activeStaff),
                                    onUploadProof: () =>
                                        _uploadProofPhoto(order),
                                    onOpenProofGallery: () =>
                                        _openProofGallery(order),
                                    onResolveBackorder: () =>
                                        _resolveBackorder(order),
                                    proofCount: (_orderProofPhotos[order.id] ??
                                             const <String>[])
                                        .length,
                                    onDeliverPartial: () =>
                                        _deliverPartial(order),
                                    onFixDeliveryStatus: () =>
                                        _fixDeliveryStatus(order),
                                    onStatusChanged: (status) =>
                                        _updateStatus(order, status),
                                    onChatUpdated: _refresh,
                                  ),
                                ),
                              ];
                            })(),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OrdersPageData {
  _OrdersPageData({
    required this.orders,
    required this.users,
    required this.products,
  });

  final List<DeliveryOrder> orders;
  final List<AppUser> users;
  final List<Product> products;
}

class _CancelledOrdersPage extends StatelessWidget {
  const _CancelledOrdersPage({
    required this.orders,
    required this.currentUser,
    required this.api,
    required this.proofPhotos,
    required this.onLoadProofPhotos,
    required this.staff,
    required this.onAssign,
    required this.onOpenProofGallery,
  });

  final List<DeliveryOrder> orders;
  final AppUser currentUser;
  final StockApiService api;
  final Map<String, List<String>> proofPhotos;
  final Future<void> Function(String orderId) onLoadProofPhotos;
  final List<AppUser> staff;
  final Future<void> Function(DeliveryOrder order, List<AppUser> users)
      onAssign;
  final void Function(DeliveryOrder order) onOpenProofGallery;

  @override
  Widget build(BuildContext context) {
    final sorted = [...orders]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return Scaffold(
      appBar: AppBar(
        title: const Text("ออเดอร์ที่ยกเลิก"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (sorted.isEmpty)
            const Center(child: Text("ยังไม่มีออเดอร์ที่ยกเลิก"))
          else
            ...sorted.map(
              (order) => _OrderTile(
                order: order,
                api: api,
                currentUser: currentUser,
                printUrl: api.orderPrintUrl(
                    orderId: order.id, requesterId: currentUser.userId),
                packingSlipUrl: api.orderPackingSlipUrl(
                    orderId: order.id, requesterId: currentUser.userId),
                pdfUrl: api.orderPdfUrl(
                    orderId: order.id, requesterId: currentUser.userId),
                onAssign: () => onAssign(order, staff),
                onUploadProof: () {},
                onOpenProofGallery: () => onOpenProofGallery(order),
                onResolveBackorder: () {},
                proofCount: (proofPhotos[order.id] ?? const <String>[]).length,
                onDeliverPartial: () {},
                onFixDeliveryStatus: () {},
                onStatusChanged: (_) {},
                onChatUpdated: () {},
              ),
            ),
        ],
      ),
    );
  }
}

class _BackorderReportSheet extends StatefulWidget {
  const _BackorderReportSheet({
    required this.backorders,
    required this.currentUser,
    required this.onFixStatus,
  });

  final List<DeliveryOrder> backorders;
  final AppUser currentUser;
  final Function(DeliveryOrder) onFixStatus;

  @override
  State<_BackorderReportSheet> createState() => _BackorderReportSheetState();
}

class _BackorderReportSheetState extends State<_BackorderReportSheet> {
  String _assigneeFilter = "all";
  String _dateFilter = "all";

  List<DeliveryOrder> _filteredOrders() {
    final now = DateTime.now();
    DateTime? from;
    if (_dateFilter == "today") {
      from = DateTime(now.year, now.month, now.day);
    } else if (_dateFilter == "7d") {
      from = now.subtract(const Duration(days: 7));
    } else if (_dateFilter == "30d") {
      from = now.subtract(const Duration(days: 30));
    }

    return widget.backorders.where((order) {
      final byAssignee = _assigneeFilter == "all" ||
          (_assigneeFilter == "unassigned" &&
              (order.assignedToId == null || order.assignedToId!.isEmpty)) ||
          order.assignedToId == _assigneeFilter;
      if (!byAssignee) return false;
      if (from == null) return true;
      return order.createdAt.isAfter(from) ||
          order.createdAt.isAtSameMomentAs(from);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final assignees = <String, String>{};
    for (final o in widget.backorders) {
      if (o.assignedToId != null && o.assignedToId!.isNotEmpty) {
        assignees[o.assignedToId!] = o.assignedToName ?? o.assignedToId!;
      }
    }
    final filtered = _filteredOrders();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("รายงานค้างจ่าย", style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text("ทั้งหมด ${filtered.length} ออเดอร์"),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                value: _assigneeFilter,
                decoration: const InputDecoration(labelText: "พนักงานส่ง"),
                items: [
                  const DropdownMenuItem(value: "all", child: Text("ทั้งหมด")),
                  const DropdownMenuItem(
                      value: "unassigned", child: Text("ยังไม่มอบหมาย")),
                  ...assignees.entries.map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ),
                ],
                onChanged: (v) => setState(() => _assigneeFilter = v ?? "all"),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                value: _dateFilter,
                decoration: const InputDecoration(labelText: "ช่วงวันที่"),
                items: const [
                  DropdownMenuItem(value: "all", child: Text("ทั้งหมด")),
                  DropdownMenuItem(value: "today", child: Text("วันนี้")),
                  DropdownMenuItem(value: "7d", child: Text("7 วัน")),
                  DropdownMenuItem(value: "30d", child: Text("30 วัน")),
                ],
                onChanged: (v) => setState(() => _dateFilter = v ?? "all"),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (filtered.isEmpty)
          const Expanded(
              child: Center(child: Text("ไม่มีออเดอร์ค้างจ่ายตามตัวกรอง")))
        else
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 18),
              itemBuilder: (context, index) {
                final order = filtered[index];
                final pending = order.items
                    .where((item) => item.deliveredQuantity < item.quantity)
                    .map((item) =>
                        "${item.productName} ค้าง ${item.quantity - item.deliveredQuantity}")
                    .join(", ");
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(order.customerName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              Text(
                                  "ผู้ส่ง: ${order.assignedToName ?? "ยังไม่มอบหมาย"}"),
                            ],
                          ),
                        ),
                        if (widget.currentUser.isAdmin)
                          IconButton.filledTonal(
                            onPressed: () => widget.onFixStatus(order),
                            icon: const Icon(Icons.edit_note_rounded, size: 20),
                            tooltip: "แก้ไขจำนวนส่ง",
                          ),
                      ],
                    ),
                    Text(pending, style: const TextStyle(color: Colors.red)),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}

class _DraftOrderItem {
  _DraftOrderItem({
    this.barcode,
    String productQuery = "",
    String quantity = "1",
  })  : productController = TextEditingController(text: productQuery),
        quantityController = TextEditingController(text: quantity);

  String? barcode;
  final TextEditingController productController;
  final TextEditingController quantityController;

  void dispose() {
    productController.dispose();
    quantityController.dispose();
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({
    required this.order,
    required this.api,
    required this.currentUser,
    required this.printUrl,
    required this.packingSlipUrl,
    required this.pdfUrl,
    required this.onAssign,
    required this.onUploadProof,
    required this.onOpenProofGallery,
    required this.onResolveBackorder,
    required this.proofCount,
    required this.onDeliverPartial,
    required this.onFixDeliveryStatus,
    required this.onStatusChanged,
    required this.onChatUpdated,
  });

  final DeliveryOrder order;
  final StockApiService api;
  final AppUser currentUser;
  final String printUrl;
  final String packingSlipUrl;
  final String pdfUrl;
  final VoidCallback onAssign;
  final VoidCallback onUploadProof;
  final VoidCallback onOpenProofGallery;
  final VoidCallback onResolveBackorder;
  final int proofCount;
  final VoidCallback onDeliverPartial;
  final VoidCallback onFixDeliveryStatus;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onChatUpdated;

  String _fmtOrderDateTime(DateTime value) {
    final dd = value.day.toString().padLeft(2, "0");
    final mm = value.month.toString().padLeft(2, "0");
    final yy = value.year;
    final hh = value.hour.toString().padLeft(2, "0");
    final mi = value.minute.toString().padLeft(2, "0");
    return "$dd/$mm/$yy $hh:$mi";
  }

  Future<void> _openUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      return;
    }
    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  Color _statusTone() {
    switch (order.status) {
      case "assigned":
        return profileTeal;
      case "preparing":
        return profileAccent;
      case "out_for_delivery":
        return brandPrimary;
      case "delivered":
        return brandDeep;
      case "cancelled":
        return Colors.redAccent;
      default:
        return brandInk;
    }
  }

  String _statusLabel() {
    switch (order.status) {
      case "assigned":
        return "กำลังจัดคิว";
      case "in_production":
        return "กำลังผลิต";
      case "qc_pending":
        return "รอ QC";
      case "rework_required":
        return "ตีกลับแก้";
      case "qc_passed":
        return "QC ผ่าน";
      case "preparing":
        return "กำลังจัดสินค้า";
      case "out_for_delivery":
        return "กำลังส่ง";
      case "delivered":
        return "ส่งแล้ว";
      case "cancelled":
        return "ยกเลิก";
      default:
        return "รอดำเนินการ";
    }
  }

  @override
  Widget build(BuildContext context) {
    String _roleNorm(String? value) => (value ?? "").trim().toLowerCase();
    bool _hasThaiWord(String haystack, String needle) =>
        haystack.contains(needle);
    String _nameNorm(String? value) =>
        (value ?? "").trim().toLowerCase().replaceAll(RegExp(r"\s+"), " ");

    final canAssign =
        currentUser.isAdmin || currentUser.userId == order.createdById;
    final role = _roleNorm(currentUser.role);
    final position = _roleNorm(currentUser.position);
    final isProducerRole =
        role.contains("production") || _hasThaiWord(role, "ผลิต") ||
        position.contains("production") || _hasThaiWord(position, "ผลิต");
    final isQcRole =
        role == "qc" || role.contains("quality") || role.contains("ตรวจ");
    final isDeliveryRole =
        role.contains("delivery") || _hasThaiWord(role, "ส่ง");

    final isProducerNameMatch =
        _nameNorm(currentUser.userName) == _nameNorm(order.productionUserName);
    final isQcNameMatch =
        _nameNorm(currentUser.userName) == _nameNorm(order.qcUserName);
    final isDeliveryNameMatch =
        _nameNorm(currentUser.userName) == _nameNorm(order.deliveryUserName);

    final isProducer = currentUser.userId == (order.productionUserId ?? "") ||
        isProducerNameMatch ||
        isProducerRole;
    final isQc = currentUser.userId == (order.qcUserId ?? "") ||
        isQcNameMatch ||
        isQcRole;
    final isDelivery = currentUser.userId == (order.deliveryUserId ?? "") ||
        currentUser.userId == (order.assignedToId ?? "") ||
        isDeliveryNameMatch ||
        isDeliveryRole;
    final canOperate = currentUser.isAdmin ||
        currentUser.userId == order.createdById ||
        isProducer ||
        isQc ||
        isDelivery;
    final hasProduction = (order.productionUserId ?? "").isNotEmpty ||
        (order.productionUserName ?? "").trim().isNotEmpty;
    final qcAssigned = (order.qcUserId ?? "").isNotEmpty ||
        (order.qcUserName ?? "").trim().isNotEmpty;
    // If the team didn't explicitly assign QC, still allow QC-role staff/admin
    // to see and claim QC steps.
    final qcEnabled = qcAssigned || currentUser.isAdmin || isQcRole;
    final canMarkDelivered = proofCount > 0;
    final deliveredCount = order.items
        .where((item) => item.deliveredQuantity >= item.quantity)
        .length;
    final hasBackorder = (order.note ?? "").contains("ค้างจ่าย");
    final canCancel =
        (currentUser.isAdmin || currentUser.userId == order.createdById) &&
            order.status != "delivered" &&
            order.status != "cancelled";
    final isCancelled = order.status == "cancelled";
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.customerName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (order.unreadCount > 0)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      "${order.unreadCount}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (hasBackorder)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.red.withOpacity(0.35)),
                    ),
                    child: const Text(
                      "ค้างจ่าย",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _statusTone().withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _statusLabel(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _statusTone(),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "สถานะการส่งสินค้า: ส่งแล้ว $deliveredCount/${order.items.length} รายการ",
            ),
            const SizedBox(height: 6),
            ...order.items.map((item) {
              final isDone = item.deliveredQuantity >= item.quantity;
              final remaining = (item.quantity - item.deliveredQuantity)
                  .clamp(0, item.quantity);
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isDone
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 16,
                      color:
                          isDone ? Colors.green : brandInk.withOpacity(0.55),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isDone
                            ? "${item.productName} x${item.quantity} (ส่งแล้ว)"
                            : "${item.productName} x${item.quantity} (ค้าง $remaining)",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDone ? Colors.green.shade700 : brandInk,
                              fontWeight:
                                  isDone ? FontWeight.w700 : FontWeight.w500,
                            ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (order.customerPhone != null && order.customerPhone!.isNotEmpty)
              Text("โทร: ${order.customerPhone}"),
            if (order.customerAddress != null &&
                order.customerAddress!.isNotEmpty)
              Text("ที่อยู่: ${order.customerAddress}"),
            Text("ผู้รับออเดอร์: ${order.createdByName}"),
            Text(
              "ผู้ส่ง (ผู้รับผิดชอบ): ${order.assignedToName ?? "ยังไม่ระบุ"}${(order.assignedToId ?? "").isNotEmpty ? " (${order.assignedToId})" : ""}",
            ),
            if (order.lastHandoffFrom != null &&
                order.lastHandoffTo != null &&
                order.lastHandoffAt != null)
              Text(
                "ล่าสุด: ${order.lastHandoffFrom} -> ${order.lastHandoffTo} · ${_fmtOrderDateTime(order.lastHandoffAt!)}",
              ),
            Text(
              "ฝ่ายผลิต: ${(order.productionUserName ?? "-")}${(order.productionUserId ?? "").isNotEmpty ? " (${order.productionUserId})" : ""}",
            ),
            Text(
              "QC: ${(order.qcUserName ?? "-")}${(order.qcUserId ?? "").isNotEmpty ? " (${order.qcUserId})" : ""}",
            ),
            Text(
              "จัดส่ง: ${(order.deliveryUserName ?? "-")}${(order.deliveryUserId ?? "").isNotEmpty ? " (${order.deliveryUserId})" : ""}",
            ),
            if (order.scheduledDeliveryAt != null)
              Text(
                "กำหนดส่ง: ${_fmtOrderDateTime(order.scheduledDeliveryAt!)}",
              ),
            if (order.note != null && order.note!.isNotEmpty)
              Text("หมายเหตุ: ${order.note}"),
            const SizedBox(height: 10),
            if (order.status == "delivered")
              OutlinedButton.icon(
                onPressed: onOpenProofGallery,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text("รูปหลักฐาน ($proofCount)"),
              )
            else if (isCancelled)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => OrderChatPage(
                            api: api,
                            currentUser: currentUser,
                            order: order,
                          ),
                        ),
                      );
                      onChatUpdated();
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text("แชทติดตามงาน"),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openUrl(printUrl),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text("พิมพ์ใบออเดอร์"),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openUrl(packingSlipUrl),
                    icon: const Icon(Icons.inventory_2_rounded),
                    label: const Text("ใบปะหน้าจัดของ"),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpenProofGallery,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text("รูปหลักฐาน ($proofCount)"),
                  ),
                ],
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _openUrl(printUrl),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text("พิมพ์ใบออเดอร์"),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openUrl(packingSlipUrl),
                    icon: const Icon(Icons.inventory_2_rounded),
                    label: const Text("ใบปะหน้าจัดของ"),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => OrderChatPage(
                            api: api,
                            currentUser: currentUser,
                            order: order,
                          ),
                        ),
                      );
                      onChatUpdated();
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text("แชทติดตามงาน"),
                  ),
                  OutlinedButton.icon(
                    onPressed: canOperate ? onUploadProof : null,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: const Text("ถ่ายรูปหลักฐาน"),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpenProofGallery,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text("รูปหลักฐาน ($proofCount)"),
                  ),
                  if (hasBackorder)
                    OutlinedButton.icon(
                      onPressed: onResolveBackorder,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text("ปิดค้างจ่าย"),
                    ),
                  FilledButton.tonal(
                    onPressed: canOperate ? onDeliverPartial : null,
                    child: const Text("ส่งบางส่วน"),
                  ),
                  OutlinedButton.icon(
                    onPressed: canOperate ? onFixDeliveryStatus : null,
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text("แก้ไขจำนวนส่ง"),
                  ),
                  if (canCancel)
                    OutlinedButton.icon(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text("ยกเลิกออเดอร์"),
                            content:
                                const Text("ต้องการยกเลิกออเดอร์นี้ใช่ไหม"),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(false),
                                child: const Text("ไม่ยกเลิก"),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(true),
                                child: const Text("ยกเลิกออเดอร์"),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          onStatusChanged("cancelled");
                        }
                      },
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text("ยกเลิกออเดอร์"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                    ),
                  // If production/QC aren't configured, skip those steps and move to delivery flow.
                  if (hasProduction &&
                      (currentUser.isAdmin || isProducer) &&
                      (order.status == "new" ||
                          order.status == "assigned" ||
                          order.status == "rework_required"))
                    FilledButton.tonal(
                      onPressed: () => onStatusChanged("in_production"),
                      child: const Text("เริ่มผลิต"),
                    ),
                  // Allow sending to QC even if production wasn't assigned (some teams skip the production step).
                  if (qcEnabled &&
                      (currentUser.isAdmin || isProducer) &&
                      (order.status == "in_production" ||
                          ((!hasProduction) &&
                              (order.status == "new" ||
                                  order.status == "assigned" ||
                                  order.status == "rework_required"))))
                    FilledButton.tonal(
                      onPressed: () => onStatusChanged("qc_pending"),
                      child: const Text("ส่ง QC"),
                    ),
                  if (qcEnabled &&
                      (currentUser.isAdmin || isQc) &&
                      order.status == "qc_pending")
                    FilledButton.tonal(
                      onPressed: () => onStatusChanged("rework_required"),
                      child: const Text("ตีกลับแก้"),
                    ),
                  if (qcEnabled &&
                      (currentUser.isAdmin || isQc) &&
                      order.status == "qc_pending")
                    FilledButton.tonal(
                      onPressed: () => onStatusChanged("qc_passed"),
                      child: const Text("QC ผ่าน"),
                    ),
                  if ((currentUser.isAdmin || isDelivery) &&
                      ((hasProduction &&
                              qcAssigned &&
                              order.status == "qc_passed") ||
                          (hasProduction &&
                              !qcAssigned &&
                              order.status == "in_production") ||
                          (!hasProduction &&
                              !qcAssigned &&
                              (order.status == "new" ||
                                  order.status == "assigned"))))
                    FilledButton.tonal(
                      onPressed: () => onStatusChanged("preparing"),
                      child: const Text("กำลังจัด"),
                    ),
                  if ((currentUser.isAdmin || isDelivery) &&
                      order.status == "preparing")
                    FilledButton.tonal(
                      onPressed: () => onStatusChanged("out_for_delivery"),
                      child: const Text("กำลังส่ง"),
                    ),
                  FilledButton.tonal(
                    onPressed: (canOperate && canMarkDelivered)
                        ? () => onStatusChanged("delivered")
                        : null,
                    child: const Text("ส่งแล้ว"),
                  ),
                  if (!canMarkDelivered)
                    Text(
                      "ต้องมีรูปหลักฐานก่อนกดส่งแล้ว",
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: brandPrimary),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _DeliverySuccessOverlay extends StatefulWidget {
  const _DeliverySuccessOverlay();

  @override
  State<_DeliverySuccessOverlay> createState() =>
      _DeliverySuccessOverlayState();
}

class _DeliverySuccessOverlayState extends State<_DeliverySuccessOverlay> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: 330,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 170,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: brandPrimary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    Align(
                      alignment: const Alignment(0, 0.65),
                      child: Container(
                        width: 220,
                        height: 8,
                        decoration: BoxDecoration(
                          color: brandPrimary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: -1.2, end: 1.2),
                      duration: const Duration(milliseconds: 1800),
                      curve: Curves.easeInOutCubic,
                      builder: (context, value, child) => Align(
                        alignment: Alignment(value, 0.25),
                        child: child,
                      ),
                      child: Icon(
                        Icons.local_shipping_rounded,
                        size: 34,
                        color: brandPrimary.withOpacity(0.85),
                      ),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: -1.35, end: 1.0),
                      duration: const Duration(milliseconds: 1600),
                      curve: Curves.easeInOutCubic,
                      builder: (context, value, child) => Align(
                        alignment: Alignment(value, -0.1),
                        child: child,
                      ),
                      child: Icon(
                        Icons.inventory_2_rounded,
                        size: 46,
                        color: brandDeep.withOpacity(0.88),
                      ),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: -1.55, end: 0.8),
                      duration: const Duration(milliseconds: 1700),
                      curve: Curves.easeInOutCubic,
                      builder: (context, value, child) => Align(
                        alignment: Alignment(value, 0.15),
                        child: child,
                      ),
                      child: Icon(
                        Icons.all_inbox_rounded,
                        size: 42,
                        color: profileAccent.withOpacity(0.92),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "ส่งสินค้าเรียบร้อย!",
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: brandDeep),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyTile extends StatelessWidget {
  const _EmptyTile({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: spaceLg, vertical: 22),
      decoration: softPanelDecoration(surfaceStrength: 0.45),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: brandPrimary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              color: brandPrimary.withOpacity(0.82),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "ยังไม่มีรายการ",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: brandInk,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: brandInk.withOpacity(0.70),
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: pagePadding,
      children: [
        const SizedBox(height: 80),
        Container(
          padding: cardPadding,
          decoration: softPanelDecoration(
            tone: profileAccent,
            surfaceStrength: 0.30,
          ),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: profileAccent.withOpacity(0.28),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  color: brandTextOnLight,
                  size: 26,
                ),
              ),
              const SizedBox(height: spaceSm),
              Text(
                "เชื่อมต่อ API ไม่สำเร็จ",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: spaceXs),
              Text(
                message.replaceFirst("Exception: ", ""),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: brandInk.withOpacity(0.72),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    required this.subtitle,
    this.showBackButton = false,
  });

  final String title;
  final String subtitle;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final headerColor = Color.lerp(brandSurfaceStrong, brandPrimary, 0.34)!;
    return Container(
      padding:
          const EdgeInsets.fromLTRB(spaceLg, spaceLg, spaceLg, spaceMd),
      decoration: BoxDecoration(
        color: headerColor,
        borderRadius: BorderRadius.circular(radiusXl),
        border: Border.all(color: brandPrimary.withOpacity(0.16)),
        boxShadow: [
          BoxShadow(
            color: brandPrimary.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showBackButton) ...[
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
              color: brandDeep,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.82),
              ),
            ),
            const SizedBox(height: spaceXs),
          ],
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: brandDeep,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: brandInk.withOpacity(0.82),
                ),
          ),
          const SizedBox(height: spaceSm),
          Container(
            width: 64,
            height: 4,
            decoration: BoxDecoration(
              color: brandPrimary,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptDivider extends StatelessWidget {
  const _ReceiptDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dashCount = (constraints.maxWidth / 10).floor().clamp(12, 60);
        return Row(
          children: List.generate(
            dashCount,
            (_) => Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                height: 1.4,
                color: brandPrimary.withOpacity(0.35),
              ),
            ),
          ),
        );
      },
    );
  }
}

// --- OCR Parsing Helpers ---

bool _isPseudoLatinSoup(String? text) {
  if (text == null || text.isEmpty) return false;
  // 1. Detect characters from Latin-1 Supplement/Extended (like accented letters)
  // output by Latin OCR when scanning Thai text.
  final soupPattern = RegExp(r'[àáâãäåæçèéêëìíîïðñòóôõöøùúûüýþÿāăąćĉ¢ĉċčďđēĕėęěĝğġģĥħĩīĭįıĵķĺļľŀłńņňŉŋōŏőœŕŗřśŝşšţťŧũūŭůűųŵŷźżžſƀƁƂƃƄƅƆƇƈƉƊɖɗƎǝǏǐǑǒǓǔǕǖǗǘǙǚǛǜ]');
  if (soupPattern.hasMatch(text)) return true;

  // 2. Since local ML Kit only recognizes Latin, any name/address it detects
  // on a Thai label will consist of English letters/gibberish (like 'Lai 509/20').
  // If the text contains Latin letters but absolutely no Thai characters, it is soup.
  final hasLatinLetters = RegExp(r'[a-zA-Z]').hasMatch(text);
  final hasThaiCharacters = RegExp(r'[\u0e00-\u0e7f]').hasMatch(text);
  if (hasLatinLetters && !hasThaiCharacters) {
    return true;
  }

  return false;
}

Map<String, String?> parseCustomerOcr(String rawText) {
  if (rawText.trim().isEmpty) {
    return {"name": null, "phone": null, "address": null};
  }

  final initialLines = rawText
      .split("\n")
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .map((e) => repairThaiMojibakeSafe(e))
      .toList();

  String? phone;
  String? name;
  final processedLines = <String>[];

  // First pass: extract phone and remove phone text from lines
  for (final line in initialLines) {
    if (phone == null) {
      final detectedPhone = extractThaiPhone(line);
      if (detectedPhone != null) {
        phone = detectedPhone;
        
        // Strip the phone number pattern from the line
        final phoneRegex = RegExp(r"(?:0|\+?66)[-() \d]{8,15}");
        var cleanedLine = line.replaceAll(phoneRegex, "").trim();
        
        // Also strip common phone prefixes from the remaining line (starts and ends)
        final phonePrefixes = ["เบอร์โทรศัพท์", "เบอร์โทร", "เบอร์", "โทรศัพท์", "โทร", "tel:", "tel", "phone:", "phone", "mobile:"];
        final lowerCleaned = cleanedLine.toLowerCase();
        for (final prefix in phonePrefixes) {
          if (lowerCleaned.startsWith(prefix)) {
            cleanedLine = cleanedLine.substring(prefix.length).trim();
            if (cleanedLine.startsWith(":") || cleanedLine.startsWith("-")) {
              cleanedLine = cleanedLine.substring(1).trim();
            }
            break;
          }
        }
        
        // Strip trailing phone label/connective words and punctuation
        cleanedLine = cleanedLine.replaceAll(RegExp(r'(?:เบอร์โทรศัพท์|เบอร์โทร|เบอร์|โทรศัพท์|โทร\.?|tel\.?|phone|mobile)\s*[:\-]?\s*$', caseSensitive: false), '').trim();
        // Strip trailing punctuation
        cleanedLine = cleanedLine.replaceAll(RegExp(r'[\s\-:.,#]+$'), '').trim();

        if (cleanedLine.isNotEmpty && !isNoiseLine(cleanedLine)) {
          processedLines.add(stripLabelPrefixes(cleanedLine));
        }
        continue;
      }
    }
    processedLines.add(stripLabelPrefixes(line));
  }

  // Second pass: filter noise lines
  final cleanLines = processedLines.where((l) => !isNoiseLine(l)).toList();

  // Third pass: find Name
  final addressKeywords = ["ต.", "ตำบล", "อ.", "อำเภอ", "จ.", "จังหวัด", "ถนน", "ซอย", "หมู่", "ม.", "เลขที่"];
  for (final line in cleanLines) {
    final hasAddressKeyword = addressKeywords.any((kw) => line.contains(kw));
    final startsWithDigit = RegExp(r"^\d").hasMatch(line);
    final hasPostalCode = RegExp(r"\b\d{5}\b").hasMatch(line);

    if (!hasAddressKeyword && !startsWithDigit && !hasPostalCode && line.length < 50) {
      name = line;
      break;
    }
  }

  // Remaining lines as address
  final addressLines = cleanLines.where((line) => line != name).toList();
  final address = addressLines.join(" ");

  return {
    "name": name,
    "phone": phone,
    "address": address.isEmpty ? "" : address,
  };
}

String repairThaiMojibakeSafe(String value) {
  var repaired = value;
  bool looksMojibake(String s) {
    return RegExp(r"(à¸|à¹|Ã)").hasMatch(s);
  }

  int cp1252Map(int code) {
    if (code <= 255) return code;
    switch (code) {
      case 0x20ac: return 0x80; // €
      case 0x201a: return 0x82; // ‚
      case 0x0192: return 0x83; // ƒ
      case 0x201e: return 0x84; // „
      case 0x2026: return 0x85; // …
      case 0x2020: return 0x86; // †
      case 0x2021: return 0x87; // ‡
      case 0x02c6: return 0x88; // ˆ
      case 0x2030: return 0x89; // ‰
      case 0x0160: return 0x8a; // Š
      case 0x2039: return 0x8b; // ‹
      case 0x0152: return 0x8c; // Œ
      case 0x017d: return 0x8e; // Ž
      case 0x2018: return 0x91; // ‘
      case 0x2019: return 0x92; // ’
      case 0x201c: return 0x93; // “
      case 0x201d: return 0x94; // ”
      case 0x2022: return 0x95; // •
      case 0x2013: return 0x96; // –
      case 0x2014: return 0x97; // —
      case 0x02dc: return 0x98; // ˜
      case 0x2122: return 0x99; // ™
      case 0x0161: return 0x9a; // š
      case 0x203a: return 0x9b; // ›
      case 0x0153: return 0x9c; // œ
      case 0x017e: return 0x9e; // ž
      case 0x0178: return 0x9f; // Ÿ
      default: return 0x3f; // ?
    }
  }

  List<int> safeLatin1Encode(String s) {
    final bytes = <int>[];
    for (var i = 0; i < s.length; i++) {
      bytes.add(cp1252Map(s.codeUnitAt(i)));
    }
    return bytes;
  }

  for (var i = 0; i < 2; i++) {
    if (!looksMojibake(repaired)) {
      break;
    }
    try {
      repaired = utf8.decode(safeLatin1Encode(repaired), allowMalformed: true);
    } catch (_) {
      break;
    }
  }
  return repaired;
}

String? extractThaiPhone(String line) {
  final cleaned = line.replaceAll(RegExp(r'[\s\-()]+'), '');
  final match = RegExp(r'(?:(?:\+?66|0)[2-9]\d{7,8})').firstMatch(cleaned);
  if (match != null) {
    var num = match.group(0)!;
    if (num.startsWith('+66')) {
      num = '0${num.substring(3)}';
    } else if (num.startsWith('66')) {
      num = '0${num.substring(2)}';
    }
    return num;
  }
  return null;
}

bool isNoiseLine(String line) {
  final clean = line.trim();
  if (clean.isEmpty) return true;

  final lower = clean.toLowerCase();

  // 1. URLs, emails and domains
  if (lower.contains("http://") ||
      lower.contains("https://") ||
      lower.contains("www.") ||
      RegExp(r"\b[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}\b").hasMatch(lower) ||
      RegExp(r"\b[a-z0-9.-]+\.(com|co|net|org|th|info|biz|edu|gov)\b").hasMatch(lower)) {
    return true;
  }

  // 2. App Stores
  if (lower.contains("play.google.com") ||
      lower.contains("apps.apple.com") ||
      lower.contains("app store") ||
      lower.contains("google play") ||
      lower.contains("กูเกิล เพลย์") ||
      lower.contains("แอปสโตร์")) {
    return true;
  }

  // 3. OpenAI & Adobe
  if (lower.contains("openai") ||
      lower.contains("chatgpt") ||
      lower.contains("gpt-") ||
      lower.contains("adobe") ||
      lower.contains("photoshop") ||
      lower.contains("acrobat") ||
      lower.contains("creative cloud")) {
    return true;
  }

  // 4. Browser UI & local addresses
  if (lower.contains("localhost") ||
      lower.contains("127.0.0.1") ||
      lower.contains("chrome://") ||
      lower.contains("file://") ||
      lower.contains("bookmark") ||
      lower.contains("history") ||
      lower.contains("extensions")) {
    return true;
  }

  // 5. Windows Activation
  if (lower.contains("activate windows") ||
      lower.contains("settings to activate") ||
      lower.contains("เปิดใช้งาน windows") ||
      lower.contains("การตั้งค่าเพื่อเปิดใช้งาน")) {
    return true;
  }

  // Document Headers & Common noise titles (Starts-with and exact matches)
  if (lower.startsWith("ใบสั่ง") ||
      lower.startsWith("ใบเสร็จ") ||
      lower.startsWith("ใบส่ง") ||
      lower.startsWith("ใบกำกับ") ||
      lower.startsWith("ใบปะหน้า") ||
      lower.startsWith("ใบนำส่ง") ||
      lower.startsWith("สำเนา") ||
      lower.startsWith("ต้นฉบับ") ||
      lower.contains("เลขที่ใบ") ||
      lower.startsWith("วันที่")) {
    return true;
  }

  // 6. Navigation and generic UI Labels
  final uiLabels = {
    "ยกเลิก", "ใช้ข้อมูลนี้", "เสร็จสิ้น", "แก้ไข", "ลบ", "ย้อนกลับ", "ตกลง", "บันทึก", 
    "ถัดไป", "ยืนยัน", "ปิด", "เปิด", "หน้าแรก", "เมนู", "ตั้งค่า", "ค้นหา", "พิมพ์", 
    "แชร์", "ดาวน์โหลด", "ยกเลิกการสั่งซื้อ", "สร้างออเดอร์", "สแกน",
    "cancel", "confirm", "ok", "close", "edit", "delete", "settings", "profile", 
    "search", "print", "share", "download", "save", "next", "previous", "done", 
    "menu", "home", "back", "forward", "refresh", "reload", "status", "loading", 
    "error", "success", "info", "warning", "help", "about", "contact",
    "customer", "order", "receipt", "invoice", "recipient", "sender"
  };
  if (uiLabels.contains(lower)) {
    return true;
  }

  // 7. System status line (e.g. clock, battery, network strength)
  if (RegExp(r"^\d{1,2}[:.]\d{2}\s*(?:am|pm)?$", caseSensitive: false).hasMatch(clean) ||
      RegExp(r"^\d{1,3}\s*%$").hasMatch(clean) ||
      RegExp(r"^(?:lte|5g|4g|3g|gprs|wifi|volte)$", caseSensitive: false).hasMatch(clean)) {
    return true;
  }

  // 8. Lines that are purely punctuation or symbols (contains no alphanumeric characters)
  if (!RegExp(r"[a-zA-Z0-9\u0e00-\u0e7f]").hasMatch(clean)) {
    return true;
  }

  return false;
}

String stripLabelPrefixes(String line) {
  final lower = line.toLowerCase();
  final prefixes = [
    "ชื่อลูกค้า:", "ชื่อลูกค้า", "ชื่อผู้รับ:", "ชื่อผู้รับ", "ชื่อ:", "ชื่อ",
    "ที่อยู่ลูกค้า:", "ที่อยู่ลูกค้า", "ที่อยู่ผู้รับ:", "ที่อยู่ผู้รับ", "ที่อยู่:", "ที่อยู่",
    "เบอร์โทรศัพท์:", "เบอร์โทรศัพท์", "เบอร์โทร:", "เบอร์โทร", "เบอร์:", "เบอร์",
    "โทรศัพท์:", "โทรศัพท์", "โทร:", "โทร", "tel:", "tel", "phone:", "phone", "contact:", "contact",
    "name:", "address:", "mobile:"
  ];
  for (final prefix in prefixes) {
    if (lower.startsWith(prefix)) {
      var rest = line.substring(prefix.length).trim();
      if (rest.startsWith(":") || rest.startsWith("-")) {
        rest = rest.substring(1).trim();
      }
      return rest;
    }
  }
  return line;
}
