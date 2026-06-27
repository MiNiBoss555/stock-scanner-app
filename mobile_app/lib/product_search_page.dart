import "dart:async";
import "dart:io";

import "package:excel/excel.dart" hide Border;
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:mobile_scanner/mobile_scanner.dart" hide Barcode;
import "package:path_provider/path_provider.dart";
import "package:share_plus/share_plus.dart";
import "package:shared_preferences/shared_preferences.dart";

import "api_service.dart";
import "models.dart";
import "product_timeline_page.dart";
import "theme/app_theme.dart";

enum ProductSearchGuidanceMode {
  stockIn,
  stockOut,
  timeline,
}

class ProductSearchPage extends StatefulWidget {
  const ProductSearchPage({
    super.key,
    required this.api,
    required this.currentUser,
    this.onOpenProductDetails,
    this.guidanceMode,
  });

  final StockApiService api;
  final AppUser currentUser;
  final void Function(BuildContext context, Product product)? onOpenProductDetails;
  final ProductSearchGuidanceMode? guidanceMode;

  @override
  State<ProductSearchPage> createState() => _ProductSearchPageState();
}

class _ProductSearchPageState extends State<ProductSearchPage> {
  final TextEditingController _controller = TextEditingController();
  String _query = "";
  List<Product> _allProducts = [];
  bool _isLoading = true;
  List<String> _history = [];
  bool _showSearchTip = false;
  ProductSearchGuidanceMode? _activeGuidanceMode;

  @override
  void initState() {
    super.initState();
    _load();
    _loadHistory();
    _checkSearchTip();
    _activeGuidanceMode = widget.guidanceMode;
  }

  Future<void> _checkSearchTip() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool("product_search_tip_seen") ?? false;
    if (!seen && mounted) {
      setState(() {
        _showSearchTip = true;
      });
    }
  }

  Future<void> _dismissSearchTip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("product_search_tip_seen", true);
    if (mounted) {
      setState(() {
        _showSearchTip = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _history = prefs.getStringList("recent_search_history") ?? [];
    });
  }

  Future<void> _addToHistory(String term) async {
    final t = term.trim();
    if (t.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final List<String> current = prefs.getStringList("recent_search_history") ?? [];
    
    current.removeWhere((e) => e.toLowerCase() == t.toLowerCase());
    current.insert(0, t);
    
    final updated = current.take(10).toList();
    await prefs.setStringList("recent_search_history", updated);
    
    if (mounted) {
      setState(() {
        _history = updated;
      });
    }
  }

  Future<void> _scanBarcode() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_scanner, color: brandPrimary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "สแกนบาร์โค้ดสินค้า",
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  height: 300,
                  child: MobileScanner(
                    controller: MobileScannerController(
                      detectionSpeed: DetectionSpeed.noDuplicates,
                      returnImage: false,
                    ),
                    onDetect: (capture) {
                      final value = capture.barcodes.first.rawValue;
                      if (value != null && value.isNotEmpty) {
                        unawaited(HapticFeedback.lightImpact());
                        Navigator.of(sheetContext).pop(value);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );

    if (result != null && mounted) {
      _controller.text = result;
      setState(() {
        _query = result;
      });
      _addToHistory(result);

      // Exact Match Auto-Select for barcode scan
      final trimmedResult = result.trim().toLowerCase();
      final exactMatches = _allProducts.where((p) {
        return p.barcode.toLowerCase() == trimmedResult ||
            (p.sku?.toLowerCase() == trimmedResult);
      }).toList();

      if (exactMatches.length == 1) {
        if (widget.onOpenProductDetails != null) {
          widget.onOpenProductDetails!(context, exactMatches.first);
        }
      }
    }
  }

  Future<void> _load() async {
    try {
      final products = await widget.api.getProducts();
      if (mounted) {
        setState(() {
          _allProducts = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showAppSnack(context, e.toString(), isError: true);
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _adjustStock(Product product, String action) async {
    final title = action == "in" ? "เพิ่มสต็อก (${product.name})" : "ลดสต็อก (${product.name})";
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final qty = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "จำนวนที่ต้องการปรับ",
                hintText: "กรอกจำนวนเต็มบวก",
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return "กรุณากรอกจำนวน";
                }
                final parsed = int.tryParse(val);
                if (parsed == null || parsed <= 0) {
                  return "จำนวนต้องมากกว่า 0";
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("ยกเลิก"),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(context).pop(int.parse(controller.text));
                }
              },
              child: const Text("ตกลง"),
            ),
          ],
        );
      },
    );

    if (qty == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await widget.api.submitScan(
        barcode: product.barcode,
        action: action,
        quantity: qty,
        actorId: widget.currentUser.userId,
        actorName: widget.currentUser.userName,
        note: "ปรับจากหน้าค้นหาสินค้า",
        reference: "ปรับจากหน้าค้นหาสินค้า",
      );

      if (mounted) {
        showAppSnack(context, "ปรับสต็อกสำเร็จ");
        await _load();
      }
    } catch (e) {
      if (mounted) {
        showAppSnack(context, "เกิดข้อผิดพลาด: ${e.toString().replaceAll('Exception: ', '')}", isError: true);
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("ต้องการซ่อนสินค้านี้ใช่หรือไม่?"),
          content: const Text("สินค้าจะไม่แสดงในหน้าค้นหาและรายการสินค้าปกติ แต่ประวัติเดิมจะยังคงอยู่"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("ยกเลิก"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("ซ่อนสินค้า", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final msg = await widget.api.deleteProduct(
        requesterId: widget.currentUser.userId,
        barcode: product.barcode,
      );

      if (mounted) {
        showAppSnack(context, msg);
        await _load();
      }
    } catch (e) {
      if (mounted) {
        showAppSnack(context, "เกิดข้อผิดพลาด: ${e.toString().replaceAll('Exception: ', '')}", isError: true);
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<Product> _filteredProducts() {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _allProducts;
    return _allProducts.where((p) {
      return p.name.toLowerCase().contains(q) ||
          p.barcode.toLowerCase().contains(q) ||
          (p.sku?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Future<void> _exportProductsExcel() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final products = await widget.api.getProducts();
      final excel = Excel.createExcel();
      final sheetName = "Products";
      final sheet = excel[sheetName];
      excel.setDefaultSheet(sheetName);

      // Headers
      final headers = [
        "Barcode",
        "SKU",
        "Name",
        "Category",
        "Unit",
        "Current Stock",
        "Minimum Stock"
      ];
      for (var i = 0; i < headers.length; i++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .value = TextCellValue(headers[i]);
      }

      // Data
      for (var i = 0; i < products.length; i++) {
        final p = products[i];
        final row = i + 1;
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
            .value = TextCellValue(p.barcode);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
            .value = TextCellValue(p.sku ?? "");
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
            .value = TextCellValue(p.name);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
            .value = TextCellValue(p.category ?? "");
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
            .value = TextCellValue(p.unit);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
            .value = IntCellValue(p.currentStock);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
            .value = IntCellValue(p.minimumStock);
      }

      final fileBytes = excel.save();
      if (fileBytes == null) throw Exception("สร้างไฟล์ Excel ไม่สำเร็จ");

      final directory = await getTemporaryDirectory();
      final path = "${directory.path}/products.xlsx";
      final file = File(path);
      await file.writeAsBytes(fileBytes, flush: true);

      await Share.shareXFiles(
        [XFile(path)],
        text: "รายการสินค้าทั้งหมด (${products.length} รายการ)",
      );
    } catch (e) {
      if (mounted) {
        showAppSnack(context, "ส่งออกไม่สำเร็จ: $e", isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildSearchTipCard() {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      color: theme.colorScheme.primaryContainer.withOpacity(0.4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  "เริ่มต้นที่นี่",
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "ค้นหาสินค้า แล้วใช้ + เพื่อรับเข้า หรือ - เพื่อเบิกออก",
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key("dismiss_search_tip"),
                onPressed: _dismissSearchTip,
                child: const Text("เข้าใจแล้ว"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuidanceTipCard() {
    final theme = Theme.of(context);
    String tipText = "";
    if (_activeGuidanceMode == ProductSearchGuidanceMode.stockIn) {
      tipText = "ค้นหาสินค้า แล้วกด + รับเข้า เพื่อเพิ่มจำนวนสินค้า";
    } else if (_activeGuidanceMode == ProductSearchGuidanceMode.stockOut) {
      tipText = "ค้นหาสินค้า แล้วกด - เบิกออก เพื่อลดจำนวนสินค้า";
    } else if (_activeGuidanceMode == ProductSearchGuidanceMode.timeline) {
      tipText = "ค้นหาสินค้า แล้วกด ไทม์ไลน์ เพื่อดูประวัติสินค้า";
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      color: theme.colorScheme.secondaryContainer.withOpacity(0.4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.secondary.withOpacity(0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.help_outline,
                  color: theme.colorScheme.secondary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  "คำแนะนำการใช้งาน",
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              tipText,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key("dismiss_guidance_tip"),
                onPressed: () {
                  setState(() {
                    _activeGuidanceMode = null;
                  });
                },
                child: const Text("เข้าใจแล้ว"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final results = _filteredProducts();

    return Scaffold(
      backgroundColor: brandSurface,
      appBar: AppBar(
        titleSpacing: 0,
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.table_view_outlined),
              onPressed: _exportProductsExcel,
              tooltip: "ส่งออก Excel",
            ),
        ],
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextField(
            controller: _controller,
            autofocus: true,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: "ค้นหาชื่อสินค้า บาร์โค้ด หรือ SKU...",
              prefixIcon: const Icon(Icons.search),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_query.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _controller.clear();
                        setState(() => _query = "");
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: _scanBarcode,
                  ),
                ],
              ),
              border: InputBorder.none,
              filled: false,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_activeGuidanceMode != null) _buildGuidanceTipCard(),
                if (_showSearchTip) _buildSearchTipCard(),
                if (_query.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Text(
                          "พบ ${results.length} รายการ",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _query.isEmpty
                      ? (_history.isNotEmpty
                          ? ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                Text(
                                  "ประวัติการค้นหาล่าสุด",
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: brandDeep,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                ..._history.map((term) => ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(Icons.history, size: 20),
                                      title: Text(term),
                                      trailing: const Icon(Icons.north_west, size: 16, color: Colors.grey),
                                      onTap: () {
                                        _controller.text = term;
                                        setState(() {
                                          _query = term;
                                        });
                                      },
                                    )),
                              ],
                            )
                          : const _EmptyTile(message: "ไม่มีรายการสินค้า"))
                      : results.isEmpty
                          ? const _EmptyTile(message: "ไม่พบสินค้าที่ตรงกับคำค้นหา")
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: results.length,
                              itemBuilder: (context, index) {
                                final product = results[index];
                                return _ProductSearchTile(
                                  product: product,
                                  query: _query,
                                  currentUser: widget.currentUser,
                                  isAdmin: widget.currentUser.role.toLowerCase() == "admin",
                                  onStockIn: () => _adjustStock(product, "in"),
                                  onStockOut: () => _adjustStock(product, "out"),
                                  onDelete: () => _deleteProduct(product),
                                  onTimeline: () async {
                                    final prefs = await SharedPreferences.getInstance();
                                    final seen = prefs.getBool("timeline_tip_seen") ?? false;
                                    if (!seen) {
                                      if (context.mounted) {
                                        await showDialog<void>(
                                          context: context,
                                          builder: (dialogContext) {
                                            return AlertDialog(
                                              title: const Text("ไทม์ไลน์สินค้า"),
                                              content: const Text("ใช้ดูประวัติของสินค้านี้ เช่น รับเข้า เบิกออก ซ่อน และกู้คืน"),
                                              actions: [
                                                TextButton(
                                                  key: const Key("dismiss_timeline_tip"),
                                                  onPressed: () async {
                                                    await prefs.setBool("timeline_tip_seen", true);
                                                    if (dialogContext.mounted) {
                                                      Navigator.of(dialogContext).pop();
                                                    }
                                                  },
                                                  child: const Text("เข้าใจแล้ว"),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      }
                                    }
                                    if (context.mounted) {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) => ProductTimelinePage(
                                            api: widget.api,
                                            currentUser: widget.currentUser,
                                            barcode: product.barcode,
                                            productName: product.name,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  onTap: () {
                                    _addToHistory(_query);
                                    if (widget.onOpenProductDetails != null) {
                                      widget.onOpenProductDetails!(context, product);
                                    }
                                  },
                                );
                              },
                            ),
                ),
              ],
            ),
    );
  }
}

class _ProductSearchTile extends StatelessWidget {
  const _ProductSearchTile({
    required this.product,
    required this.query,
    required this.onTap,
    required this.onStockIn,
    required this.onStockOut,
    required this.onDelete,
    required this.onTimeline,
    required this.isAdmin,
    required this.currentUser,
  });

  final Product product;
  final String query;
  final VoidCallback onTap;
  final VoidCallback onStockIn;
  final VoidCallback onStockOut;
  final VoidCallback onDelete;
  final VoidCallback onTimeline;
  final bool isAdmin;
  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    String statusText;

    if (product.currentStock <= 0) {
      badgeColor = Colors.red;
      statusText = "หมด";
    } else if (product.currentStock <= product.minimumStock) {
      badgeColor = Colors.orange;
      statusText = "ใกล้หมด";
    } else {
      badgeColor = Colors.green;
      statusText = "ปกติ";
    }

    final bool isLongUnit = product.unit.length > 4;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            onTap: onTap,
            title: Text(
              product.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text("${product.barcode} | ${product.category ?? 'ทั่วไป'}"),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isLongUnit
                        ? "${product.currentStock}"
                        : "${product.currentStock} ${product.unit}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isLongUnit ? "$statusText (${product.unit})" : statusText,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      key: Key("stock_in_${product.barcode}"),
                      icon: const Icon(Icons.add, size: 16, color: Colors.green),
                      label: const Text("+ เพิ่ม", style: TextStyle(color: Colors.green, fontSize: 13)),
                      onPressed: onStockIn,
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      key: Key("stock_out_${product.barcode}"),
                      icon: const Icon(Icons.remove, size: 16, color: Colors.orange),
                      label: const Text("- ลด", style: TextStyle(color: Colors.orange, fontSize: 13)),
                      onPressed: onStockOut,
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      key: Key("timeline_${product.barcode}"),
                      icon: const Icon(Icons.history, size: 16, color: Colors.blue),
                      label: const Text("ไทม์ไลน์", style: TextStyle(color: Colors.blue, fontSize: 13)),
                      onPressed: onTimeline,
                    ),
                    if (isAdmin) ...[
                      const SizedBox(width: 4),
                      TextButton.icon(
                        key: Key("delete_${product.barcode}"),
                        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                        label: const Text("ซ่อน", style: TextStyle(color: Colors.red, fontSize: 13)),
                        onPressed: onDelete,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: brandInk.withOpacity(0.60),
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
